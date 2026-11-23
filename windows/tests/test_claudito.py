"""py -m unittest discover -s windows/tests"""
import datetime as dt
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import unittest

WINDOWS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, WINDOWS)

import activity  # noqa: E402
import fullscreen  # noqa: E402
import limits  # noqa: E402
import seasons  # noqa: E402
import tray_sprites  # noqa: E402

HOOK = os.path.join(WINDOWS, "claudito_hook.py")
NOW = 1_000_000.0
BASH = {"tool_name": "Bash", "tool_input": {"command": "make", "description": "Build"}}
GREP = {"tool_name": "Grep", "tool_input": {"pattern": "x"}}


class Hook(unittest.TestCase):
    """Runs the real hook in a process of its own, in an empty folder."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dir = tmp.name
        self.env = {**os.environ, "LOCALAPPDATA": self.dir, "XDG_RUNTIME_DIR": self.dir}

    def send(self, event, **fields):
        ev = {"hook_event_name": event, "session_id": "s", "cwd": "/x/proj", **fields}
        self.run_hook(json.dumps(ev).encode())
        return self.state()

    def run_hook(self, data):
        r = subprocess.run([sys.executable, HOOK], input=data, env=self.env, capture_output=True, timeout=20)
        self.assertEqual((r.returncode, r.stdout, r.stderr), (0, b"", b""))

    def state(self):
        try:
            with open(os.path.join(self.dir, "claudito", "state.json"), encoding="utf-8") as f:
                return json.load(f)["sessions"]["s"]
        except FileNotFoundError:
            return {}

    def test_idle_notification_is_not_waiting(self):
        self.send("Stop")
        s = self.send("Notification", notification_type="idle_prompt", message="Claude is waiting for your input")
        self.assertEqual(s["mode"], "done")

    def test_idle_notification_without_type(self):
        self.send("Stop")
        self.assertEqual(self.send("Notification", message="Claude is waiting for your input")["mode"], "done")
        self.assertEqual(self.send("Notification", message="Claude needs your permission")["mode"], "waiting")

    def test_informative_notifications(self):
        self.send("UserPromptSubmit")
        for kind in ("auth_success", "agent_completed", "something_new"):
            self.assertEqual(self.send("Notification", notification_type=kind)["mode"], "thinking")

    def test_permission(self):
        self.send("PreToolUse", **BASH)
        s = self.send("PermissionRequest", **BASH)
        self.assertEqual((s["mode"], s["tool"], s["detail"], s["resume"]), ("waiting", "Bash", "Build", "terminal"))
        again = self.send("Notification", notification_type="permission_prompt", message="Claude needs permission")
        self.assertEqual(again, s)   # the reminder changes nothing
        self.assertEqual(self.send("PostToolUse", **BASH)["mode"], "thinking")

    def test_late_pretooluse_does_not_hide_permission(self):
        self.send("PermissionRequest", **BASH)
        self.assertEqual(self.send("PreToolUse", **BASH)["mode"], "waiting")

    def test_parallel_tool_does_not_hide_permission(self):
        self.send("PermissionRequest", **BASH)
        self.assertEqual(self.send("PostToolUse", **GREP)["mode"], "waiting")

    def test_subagent_does_not_hide_permission(self):
        self.send("PermissionRequest", **BASH)
        self.assertEqual(self.send("PreToolUse", agent_id="a1", **GREP)["mode"], "waiting")
        self.assertEqual(self.send("PreToolUse", **GREP)["mode"], "search")   # you said no; it went on

    def test_stop_and_prompt_always_win(self):
        self.send("PermissionRequest", agent_id="a1", **BASH)
        self.assertEqual(self.send("UserPromptSubmit")["mode"], "thinking")
        self.send("PermissionRequest", agent_id="a1", **BASH)
        self.assertEqual(self.send("Stop")["mode"], "done")

    def test_answered_question(self):
        q = {"tool_name": "AskUserQuestion", "tool_input": {"questions": []}}
        self.assertEqual(self.send("PreToolUse", **q)["mode"], "waiting")
        self.assertEqual(self.send("PostToolUse", **q)["mode"], "thinking")

    def test_turn_is_kept(self):
        turn = self.send("UserPromptSubmit")["turn"]
        self.send("PreToolUse", **GREP)
        self.assertEqual(self.send("Stop")["turn"], turn)


    def project(self, cwd, root=None):
        self.env.pop("CLAUDE_PROJECT_DIR", None)
        if root:
            self.env["CLAUDE_PROJECT_DIR"] = root
        return self.send("PreToolUse", **{**GREP, "cwd": cwd})["project"]

    def test_project_is_where_the_session_started(self):
        a = os.path.join(self.dir, "proj")
        os.makedirs(os.path.join(a, "src", "deep"))
        self.assertEqual(self.project(a, root=a), "proj")
        self.assertEqual(self.project(os.path.join(a, "src", "deep"), root=a), "proj")
        self.assertEqual(self.project(a + os.sep), "proj")   # older Claude Code: no variable

    def test_project_of_a_session_started_at_home(self):
        home = os.path.join(self.dir, "someone")
        repo, other = os.path.join(home, "src", "repo"), os.path.join(home, "notes")
        os.makedirs(os.path.join(repo, ".git"))
        os.makedirs(os.path.join(repo, "sub"))
        os.makedirs(other)
        os.makedirs(os.path.join(home, ".git"))   # dotfiles in git: not a project
        self.env.update(USERPROFILE=home, HOME=home)
        self.assertEqual(self.project(home, root=home), "someone")
        self.assertEqual(self.project(os.path.join(repo, "sub"), root=home), "repo")
        self.assertEqual(self.project(other, root=home), "repo")   # it stays
        self.assertEqual(self.project(home, root=home), "repo")

    def log(self):
        try:
            with open(os.path.join(self.dir, "claudito", "hook.log"), encoding="utf-8") as f:
                return f.read()
        except FileNotFoundError:
            return ""

    def test_errors_are_logged_without_the_event(self):
        self.send("Stop")
        self.assertEqual(self.log(), "")
        self.run_hook(b'{"secret-thing": ')
        self.run_hook(b'["secret-thing"]')
        self.assertIn("JSONDecodeError", self.log())
        self.assertIn("AttributeError", self.log())
        self.assertNotIn("secret-thing", self.log())


class StatusLine(unittest.TestCase):
    def test_many_at_once(self):
        with tempfile.TemporaryDirectory() as d:
            folder = os.path.join(d, "claudito")
            os.makedirs(folder)
            stale = os.path.join(folder, ".statusline-old.tmp")
            open(stale, "w").close()
            os.utime(stale, (time.time() - 600,) * 2)
            env = {**os.environ, "LOCALAPPDATA": d, "XDG_RUNTIME_DIR": d}
            script = os.path.join(WINDOWS, "claudito_statusline.py")
            running = [subprocess.Popen([sys.executable, script], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        stderr=subprocess.PIPE, env=env) for _ in range(12)]
            for i, p in enumerate(running):
                p.stdin.write(json.dumps({"session_id": str(i), "model": {"display_name": "M"}, "pad": "x" * 50_000}).encode())
                p.stdin.close()
            for p in running:
                self.assertEqual((p.stdout.read().strip(), p.stderr.read(), p.wait(20)), (b"M", b"", 0))
                p.stdout.close()
                p.stderr.close()
            self.assertEqual(os.listdir(folder), ["statusline.json"])
            with open(os.path.join(folder, "statusline.json"), encoding="utf-8") as f:
                self.assertEqual(len(json.load(f)["pad"]), 50_000)


class Limits(unittest.TestCase):
    def rows(self, **kw):
        return limits.rows({"live": {"limits": kw}}, NOW)

    def test_rows(self):
        self.assertEqual(self.rows(five_hour={"percent": 3, "resetsAt": NOW + 60},
                                   seven_day={"percent": 52.4, "resetsAt": None}),
                         [("5 h", 3, NOW + 60), ("7 d", 52.4, None)])
        self.assertEqual(self.rows(five_hour={"percent": 99, "resetsAt": NOW - 1}), [("5 h", 0, None)])
        for nothing in ({}, None, {"live": None}, {"live": {"limits": {"five_hour": {"percent": None}}}}):
            self.assertEqual(limits.rows(nothing, NOW), [])

    def test_strained(self):
        self.assertFalse(limits.strained([]))
        self.assertFalse(limits.strained([("5 h", 79.9, None)]))
        self.assertTrue(limits.strained([("5 h", 3, None), ("7 d", 80, None)]))

    def test_text(self):
        rows = [("5 h", 3, 5), ("7 d", 52.4, None)]
        self.assertEqual(limits.text(rows, lambda at: f"t{at}"), "5 h 3 % (t5) · 7 d 52 %")

    def test_fit(self):
        self.assertEqual(limits.fit(["a", "b"]), "a\nb")
        got = limits.fit(["x" * 200, "tokens", "plan"])
        self.assertEqual(len(got), 127)
        self.assertTrue(got.endswith("…\ntokens\nplan"))


class SessionMode(unittest.TestCase):
    def mode(self, mode, age, status=None, since=None, **kw):
        live = {"status": status, "since": NOW - since} if status else None
        extra = {k: kw.pop(k) for k in ("resume",) if k in kw}
        return activity.session_mode({"mode": mode, "ts": NOW - age, **extra}, NOW, live, **kw)

    def test_accepted_permission(self):
        self.assertEqual(self.mode("waiting", 20, "waiting", 19.9, resume="terminal"), "waiting")
        self.assertEqual(self.mode("waiting", 20, "busy", 5, resume="terminal"), "terminal")

    def test_stale_busy_is_not_an_answer(self):
        self.assertEqual(self.mode("waiting", 5, "busy", 60), "waiting")

    def test_rejected_or_escaped(self):
        self.assertEqual(self.mode("waiting", 20, "idle", 5), "idle")
        self.assertEqual(self.mode("thinking", 20, "idle", 5), "idle")
        self.assertEqual(self.mode("terminal", 900, "idle", 700), "sleep")

    def test_idle_just_before_stop_does_not_flicker(self):
        self.assertEqual(self.mode("thinking", 3, "idle", 0.5), "thinking")
        self.assertEqual(self.mode("waiting", 3, "idle", 0.5), "waiting")
        self.assertEqual(self.mode("thinking", 3, "idle", 1.6), "idle")

    def test_waiting_expires(self):
        self.assertEqual(self.mode("waiting", 1700), "waiting")
        self.assertEqual(self.mode("waiting", 1900), "sleep")
        self.assertEqual(self.mode("waiting", 9000, "waiting", 9000), "waiting")   # still there
        self.assertEqual(self.mode("waiting", 5, gone=True), "sleep")

    def test_long_tool(self):
        self.assertEqual(self.mode("terminal", 2000), "sleep")
        self.assertEqual(self.mode("terminal", 2000, "busy", 2100), "terminal")

    def test_ages(self):
        for mode, age, want in (("done", 3, "done"), ("done", 60, "idle"), ("done", 700, "sleep"),
                                ("wake", 1, "wake"), ("wake", 60, "idle"),
                                ("oops", 1, "oops"), ("oops", 10, "thinking"), ("sleep", 0, "sleep")):
            self.assertEqual(self.mode(mode, age), want, (mode, age))


class Tracker(unittest.TestCase):
    def show(self, t, now=NOW, registry=None, **sessions):
        return t.update(json.dumps({"sessions": sessions}), registry, now)[0]

    def test_desktop_session(self):
        s = {"mode": "waiting", "ts": NOW}
        live = {"status": "waiting", "since": NOW}
        self.assertTrue(self.show(activity.Tracker(), registry={"a": {**live, "desktop": True}}, a=s)["desktop"])
        self.assertFalse(self.show(activity.Tracker(), registry={"a": live}, a=s)["desktop"])
        self.assertFalse(self.show(activity.Tracker(), a=s)["desktop"])

    def test_waiting_beats_newer_work(self):
        v = self.show(activity.Tracker(), a={"mode": "waiting", "ts": NOW - 60, "project": "p"},
                      b={"mode": "build", "ts": NOW})
        self.assertEqual((v["mode"], v["project"]), ("waiting", "p"))

    def test_work_beats_idle(self):
        v = self.show(activity.Tracker(), a={"mode": "build", "ts": NOW - 60}, b={"mode": "done", "ts": NOW - 30})
        self.assertEqual(v["mode"], "build")

    def test_hat_gap(self):
        t = activity.Tracker()
        self.show(t, a={"mode": "build", "detail": "f", "ts": NOW - 1})
        self.assertEqual(self.show(t, a={"mode": "thinking", "ts": NOW})["mode"], "build")
        self.assertEqual(self.show(t, now=NOW + 2, a={"mode": "thinking", "ts": NOW})["mode"], "thinking")

    def test_closed_terminal(self):
        t = activity.Tracker()
        live = {"a": {"status": "waiting", "since": NOW}}
        s = {"mode": "waiting", "ts": NOW}
        self.assertEqual(self.show(t, registry=live, a=s)["mode"], "waiting")
        self.assertEqual(self.show(t, now=NOW + 1, registry={}, a=s)["mode"], "waiting")   # a blip
        self.assertEqual(self.show(t, now=NOW + 6, registry={}, a=s)["mode"], "sleep")

    def test_never_registered_is_not_closed(self):
        v = self.show(activity.Tracker(), registry={}, a={"mode": "build", "ts": NOW})
        self.assertEqual(v["mode"], "build")

    def test_bad_files(self):
        t = activity.Tracker()
        self.show(t, a={"mode": "build", "ts": NOW})
        self.assertEqual(t.update('{"sess', None, NOW)[0]["mode"], "build")
        self.assertEqual(t.update("[]", None, NOW)[0]["mode"], "build")
        self.assertEqual(t.update("", None, NOW)[0]["mode"], "sleep")
        self.assertEqual(t.update('{"sessions": {"a": 3, "b": {"ts": "x"}}}', None, NOW)[0]["mode"], "sleep")


class Registry(unittest.TestCase):
    def test_read(self):
        with tempfile.TemporaryDirectory() as d:
            def put(name, text):
                with open(os.path.join(d, name), "w", encoding="utf-8") as f:
                    f.write(text)
            put("1.json", json.dumps({"sessionId": "a", "status": "busy", "statusUpdatedAt": 5000}))
            put("2.json", json.dumps({"sessionId": "dead", "status": "busy"}))
            put("3.json", "{half")
            put("4.json", "[]")
            put("5.secret.key", "x")
            got = activity.read_registry(d, alive=lambda pid, started: pid != 2)
            self.assertEqual(got, {"a": {"status": "busy", "since": 5.0, "desktop": False}})
            put("1.json", json.dumps({"sessionId": "a", "entrypoint": "claude-desktop"}))
            self.assertTrue(activity.read_registry(d, alive=lambda pid, started: pid == 1)["a"]["desktop"])
        self.assertIsNone(activity.read_registry(os.path.join(d, "nope")))

    def test_process_alive(self):
        self.assertTrue(activity.process_alive(os.getpid()))
        p = subprocess.Popen([sys.executable, "-c", ""])
        p.wait()
        if os.name == "nt":
            self.assertFalse(activity.process_alive(p.pid))
            self.assertFalse(activity.process_alive(os.getpid(), "1"))   # reused pid


class Notify(unittest.TestCase):
    def view(self, mode, ts, turn=0):
        return {"s": {"mode": mode, "ts": ts, "turn": turn, "tool": "", "detail": "", "project": ""}}

    def test_waiting_once_after_a_while(self):
        n = activity.Notifier(NOW)
        v = self.view("waiting", NOW + 1)
        self.assertEqual(n.update(v, NOW + 1), [])
        self.assertEqual(n.update(v, NOW + 5), [])
        self.assertEqual([x[0] for x in n.update(v, NOW + 6)], ["waiting"])
        self.assertEqual(n.update(v, NOW + 60), [])

    def test_desktop_app_permissions(self):
        """The app has its own notifications for permissions, not for the rest."""
        for desktop, tool, told in ((True, "PowerShell", False), (True, "AskUserQuestion", True),
                                    (True, "ExitPlanMode", True), (True, "", True), (False, "PowerShell", True)):
            n = activity.Notifier(NOW)
            v = self.view("waiting", NOW + 1)
            v["s"].update(desktop=desktop, tool=tool)
            n.update(v, NOW + 1)
            self.assertEqual(bool(n.update(v, NOW + 9)), told, (desktop, tool))
        n = activity.Notifier(NOW)
        v = self.view("done", NOW + 200, NOW + 100)
        v["s"]["desktop"] = True
        self.assertEqual(len(n.update(v, NOW + 200)), 1)

    def test_answered_at_once(self):
        n = activity.Notifier(NOW)
        n.update(self.view("waiting", NOW + 1), NOW + 1)
        n.update(self.view("terminal", NOW + 1), NOW + 3)
        self.assertEqual(n.update(self.view("terminal", NOW + 1), NOW + 9), [])

    def test_nothing_about_the_past(self):
        n = activity.Notifier(NOW)
        n.update(self.view("waiting", NOW - 100), NOW)
        self.assertEqual(n.update(self.view("waiting", NOW - 100), NOW + 30), [])
        self.assertEqual(n.update(self.view("done", NOW - 2, NOW - 900), NOW), [])

    def test_only_long_tasks(self):
        n = activity.Notifier(NOW)
        self.assertEqual(n.update(self.view("done", NOW + 30, NOW + 1), NOW + 30), [])
        got = n.update(self.view("done", NOW + 200, NOW + 100), NOW + 200)
        self.assertEqual([(k, s) for k, _, s in got], [("done", 100)])
        self.assertEqual(n.update(self.view("done", NOW + 200, NOW + 100), NOW + 201), [])


class FakeApi:
    """Windows: name -> (monitor, rect, caption, class)."""
    SCREENS = {1: (0, 0, 1920, 1080), 2: (1920, 0, 3840, 1080)}

    def __init__(self):
        self.windows = {"buddy": (1, (1700, 900, 1900, 1080), 0, "Qt")}
        self.front = None

    def foreground(self): return self.front
    def monitor(self, h): return self.windows[h][0] if h in self.windows else 2
    def monitor_rect(self, m): return self.SCREENS[m]
    def rect(self, h): return self.windows[h][1]
    def style(self, h): return self.windows[h][2]
    def class_name(self, h): return self.windows[h][3]
    def shown(self, h): return h in self.windows
    def own(self, h): return h == "buddy"


class Fullscreen(unittest.TestCase):
    def setUp(self):
        self.api = FakeApi()
        self.api.windows.update({
            "game": (1, (0, 0, 1920, 1080), 0, "Game"),
            "maximized": (1, (-8, -8, 1928, 1088), fullscreen.WS_CAPTION, "Notepad"),
            "desktop": (1, (0, 0, 3840, 1080), 0, "WorkerW"),
            "other": (2, (1920, 0, 3840, 1080), 0, "Game"),
            "small": (2, (2000, 100, 2400, 500), fullscreen.WS_CAPTION, "Notepad"),
        })
        self.d = fullscreen.Detector(self.api)

    def covered(self, front):
        self.api.front = front
        return self.d.covered("buddy")

    def test_cases(self):
        for front, want in (("game", True), ("maximized", False), ("desktop", False),
                            ("other", False), (None, False), ("buddy", False)):
            self.assertEqual(self.covered(front), want, front)

    def test_game_stays_while_using_the_other_screen(self):
        self.assertTrue(self.covered("game"))
        self.assertTrue(self.covered("small"))
        del self.api.windows["game"]
        self.assertFalse(self.covered("small"))


class Seasons(unittest.TestCase):
    def test_dates(self):
        for month, day, want in ((1, 1, "winter"), (3, 19, "winter"), (3, 20, "spring"), (6, 20, "spring"),
                                 (6, 21, "summer"), (9, 21, "summer"), (9, 22, "autumn"), (11, 23, "autumn"),
                                 (12, 20, "autumn"), (12, 21, "winter"), (12, 31, "winter"), (2, 29, "winter")):
            self.assertEqual(seasons.season_on(dt.date(2028, month, day)), want, (month, day))

    def test_south(self):
        self.assertEqual(seasons.season_on(dt.date(2026, 11, 23), southern=True), "spring")
        self.assertEqual(seasons.season_on(dt.date(2026, 1, 1), southern=True), "summer")
        self.assertIn("AR", seasons.SOUTHERN)
        self.assertNotIn("MX", seasons.SOUTHERN)

    def test_tray_sprites(self):
        for sprites, top, last in ((tray_sprites.HATS, tray_sprites.HAT_TOP, 0),
                                   (tray_sprites.OUTFITS, tray_sprites.OUTFIT_TOP, 10)):
            self.assertEqual(set(sprites), set(seasons.SEASONS))
            for season, sprite in sprites.items():
                self.assertEqual({len(r) for r in sprite[1]}, {16}, season)
                self.assertEqual(top + len(sprite[1]) - 1, last, season)
                self.assertTrue(list(tray_sprites.pixels(sprite, top)))   # every color is known

    def test_sprites(self):
        """Every season has a hat and an outfit, with even rows and known colors."""
        path = os.path.join(os.path.dirname(WINDOWS), "plasma", "org.corico.claudito", "contents", "code", "sprites.js")
        with open(path, encoding="utf-8") as f:
            text = f.read()
        hats, outfits = text.split("var OUTFITS")
        for part in (hats, outfits.split("\n}\n")[0]):
            for season in seasons.SEASONS:
                m = re.search(r"\n  %s: \{(.*?)\n  \}" % season, part, re.S)
                self.assertTrue(m, season)
                colors = set(re.findall(r"(\w): \"#", m[1].split("palette", 1)[1]))
                rows = re.findall(r'^ +"([^"]+)",?$', m[1], re.M)
                self.assertTrue(rows)
                self.assertEqual({len(r) for r in rows}, {26}, season)
                self.assertLessEqual(set("".join(rows)) - {"."}, colors, season)


if __name__ == "__main__":
    unittest.main()
