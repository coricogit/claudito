"""Works out what Claudito should show from what is on disk.

Two sources:
  - state.json, written by the hook: the last event of every session
  - <claude config>/sessions/<pid>.json, kept by Claude Code itself: whether
    each running session is busy, waiting or idle right now. No hook fires when
    you answer a permission prompt, press Esc or close the terminal, and this
    file is the only trace of that. It is internal to Claude Code and may
    change or go away, so everything here also works without it.
"""
import json
import os

TOOL_MODES = {"build", "terminal", "search", "explore", "lead", "plan", "create", "work"}
BUSY_MODES = TOOL_MODES | {"thinking", "oops"}

DONE_SECONDS = 6
WAKE_SECONDS = 3
OOPS_SECONDS = 3
IDLE_SECONDS = 600        # then it falls asleep
LOST_TOOL_SECONDS = 900   # a tool that never reported back
LOST_WAIT_SECONDS = 1800  # a request nobody answered, with no session file to ask
GONE_SECONDS = 5          # missing from the registry this long: it was closed
SETTLE_SECONDS = 1.5      # a session turns idle just before its Stop event lands
HAT_GAP_SECONDS = 1.5     # short "thinking" gaps between tools keep the hat on

# Which session is shown when there are several; the latest wins a tie.
RANK = {"waiting": 4, "done": 3, "wake": 1, "idle": 1, "sleep": 0}
BUSY_RANK = 2

# Sessions of the Claude desktop app, which has its own notifications for
# permissions. It has none for these tools, which also wait for you.
DESKTOP = {"claude-desktop", "claude-desktop-3p"}
QUESTIONS = {"AskUserQuestion", "ExitPlanMode"}

ASLEEP = {"mode": "sleep", "tool": "", "detail": "", "project": "", "ts": 0, "session": "", "turn": 0}


def sessions_dir():
    config = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.join(os.path.expanduser("~"), ".claude")
    return os.path.join(config, "sessions")


def _number(v):
    return v if isinstance(v, (int, float)) and not isinstance(v, bool) else 0


def read_registry(folder=None, alive=None):
    """{session id: {"status", "since", "desktop"}} of the sessions running now, or None
    if this Claude Code doesn't keep them."""
    folder = folder or sessions_dir()
    alive = alive or process_alive
    try:
        names = os.listdir(folder)
    except OSError:
        return None
    out = {}
    for name in names:
        stem, ext = os.path.splitext(name)
        if ext != ".json" or not stem.isdigit():
            continue
        try:
            with open(os.path.join(folder, name), encoding="utf-8") as f:
                d = json.load(f)
        except (OSError, ValueError):
            continue
        if not isinstance(d, dict) or not isinstance(d.get("sessionId"), str):
            continue
        if not alive(int(stem), d.get("procStart")):
            continue
        since = _number(d.get("statusUpdatedAt")) / 1000
        old = out.get(d["sessionId"])
        if not old or since >= old["since"]:
            out[d["sessionId"]] = {"status": d.get("status"), "since": since,
                                   "desktop": d.get("entrypoint") in DESKTOP}
    return out


def process_alive(pid, started=None):
    """Is it running, and is it the same process (Windows reuses pids)?
    Says yes when it can't tell."""
    if os.name != "nt":
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            return False
        except OSError:
            pass
        return True
    import ctypes
    from ctypes import wintypes
    k = ctypes.WinDLL("kernel32", use_last_error=True)
    k.OpenProcess.restype = wintypes.HANDLE
    k.OpenProcess.argtypes = (wintypes.DWORD, wintypes.BOOL, wintypes.DWORD)
    k.CloseHandle.argtypes = (wintypes.HANDLE,)
    k.GetExitCodeProcess.argtypes = (wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD))
    k.GetProcessTimes.argtypes = (wintypes.HANDLE,) + (ctypes.POINTER(wintypes.FILETIME),) * 4
    handle = k.OpenProcess(0x1000, False, pid)   # PROCESS_QUERY_LIMITED_INFORMATION
    if not handle:
        return ctypes.get_last_error() != 87     # 87: there is no such pid
    try:
        code = wintypes.DWORD()
        if k.GetExitCodeProcess(handle, ctypes.byref(code)) and code.value != 259:   # STILL_ACTIVE
            return False
        times = [wintypes.FILETIME() for _ in range(4)]
        if str(started or "").isdigit() and k.GetProcessTimes(handle, *map(ctypes.byref, times)):
            created = (times[0].dwHighDateTime << 32) | times[0].dwLowDateTime
            return abs(created - int(started)) < 20_000_000   # 2 s, in 100 ns units
        return True
    finally:
        k.CloseHandle(handle)


def session_mode(s, now, live=None, gone=False):
    """What one session is doing. `live` is its registry entry, if any; `gone`
    means it was in the registry and no longer is."""
    if gone:
        return "sleep"
    raw = s.get("mode") or "idle"
    ts = _number(s.get("ts"))
    age = now - ts
    status = (live or {}).get("status")
    moved_on = bool(live) and live["since"] > ts   # Claude Code changed state after the last event
    stopped = moved_on and status == "idle" and now - live["since"] >= SETTLE_SECONDS   # and no Stop came

    if raw == "waiting":
        if moved_on and status == "busy":     # you said yes
            return s.get("resume") or "thinking"
        if stopped:                           # you said no, or pressed Esc
            return _resting(now - live["since"])
        if status != "waiting" and age > LOST_WAIT_SECONDS:
            return "sleep"
        return "waiting"
    if raw in BUSY_MODES and stopped:         # Esc: no Stop event
        return _resting(now - live["since"])
    if raw == "done":
        return "done" if age < DONE_SECONDS else _resting(age)
    if raw == "wake":
        return "wake" if age < WAKE_SECONDS else _resting(age)
    if raw == "sleep":
        return "sleep"
    if raw == "idle":
        return _resting(age)
    if age > LOST_TOOL_SECONDS and status != "busy":
        return "sleep"
    if raw == "oops":
        return "oops" if age < OOPS_SECONDS else "thinking"
    return raw


def _resting(age):
    return "idle" if age < IDLE_SECONDS else "sleep"


class Tracker:
    """Follows every session and picks the one to show."""

    def __init__(self):
        self.seen = {}   # session -> when it was last in the registry
        self.shown = dict(ASLEEP)

    def update(self, state_text, registry, now):
        """Returns (what to show, {session id: the same for each session}).
        The second is None if state.json could not be read this time."""
        try:
            sessions = json.loads(state_text).get("sessions") if state_text else {}
        except (ValueError, AttributeError):
            return self.shown, None   # half-written: try again on the next poll
        if not isinstance(sessions, dict):
            sessions = {}
        for sid in registry or ():
            self.seen[sid] = now

        views = {}
        for sid, s in sessions.items():
            if not isinstance(s, dict):
                continue
            live = (registry or {}).get(sid)
            # Not at the first miss: its file may be half-written right now.
            gone = registry is not None and sid in self.seen and now - self.seen[sid] > GONE_SECONDS
            views[sid] = {
                "mode": session_mode(s, now, live, gone),
                "tool": str(s.get("tool") or ""),
                "detail": str(s.get("detail") or ""),
                "project": str(s.get("project") or ""),
                "ts": _number(s.get("ts")),
                "turn": _number(s.get("turn")),
                "session": sid,
                "desktop": bool((live or {}).get("desktop")),
            }
        best = max(views.values(), key=lambda v: (RANK.get(v["mode"], BUSY_RANK), v["ts"]),
                   default=dict(ASLEEP))
        old = self.shown
        if (best["mode"] == "thinking" and old["mode"] in TOOL_MODES
                and old["session"] == best["session"] and now - best["ts"] < HAT_GAP_SECONDS):
            best = {**best, "mode": old["mode"], "tool": old["tool"], "detail": old["detail"]}
        self.shown = best
        return best, views


class Notifier:
    """Decides when something deserves a Windows notification."""

    WAIT_DELAY = 5       # don't bother you about what you answer right away
    LONG_TASK = 60

    def __init__(self, now):
        self.started = now
        self.waiting = {}    # session -> [event ts, waiting since, told]
        self.done = {}       # session -> ts of the last "done" already handled

    def update(self, views, now):
        """[("waiting" | "done", view, seconds)] to tell the user about now."""
        out = []
        for sid, v in views.items():
            if v["mode"] == "waiting":
                w = self.waiting.get(sid)
                if not w or w[0] != v["ts"]:
                    # Older than this app: you already know, or it is stale.
                    w = self.waiting[sid] = [v["ts"], now, v["ts"] < self.started]
                if not w[2] and now - w[1] >= self.WAIT_DELAY:
                    w[2] = True
                    permission = v["tool"] and v["tool"] not in QUESTIONS
                    if not (permission and v.get("desktop")):   # the app tells you itself
                        out.append(("waiting", v, now - v["ts"]))
            else:
                self.waiting.pop(sid, None)
            if v["mode"] == "done" and self.done.get(sid) != v["ts"]:
                self.done[sid] = v["ts"]
                took = v["ts"] - v["turn"] if v["turn"] else 0
                if v["ts"] >= self.started and took >= self.LONG_TASK:
                    out.append(("done", v, took))
        return out
