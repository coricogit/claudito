"""The plan limits Claude Code's status line last reported, for the tray icon."""
import time

STRAINED = 80   # percent from which Claudito looks worried
LABELS = (("five_hour", "5 h"), ("seven_day", "7 d"))
TOOLTIP_MAX = 127   # Windows cuts tray tooltips here


def rows(usage, now=None):
    """[(label, percent, when it resets or None)] from claudito-usage's output.
    Windows that have reset since the report count as 0."""
    now = time.time() if now is None else now
    live = usage.get("live") if isinstance(usage, dict) else None
    limits = (live or {}).get("limits") or {}
    out = []
    for key, label in LABELS:
        lim = limits.get(key) or {}
        pct, at = lim.get("percent"), lim.get("resetsAt")
        if not isinstance(pct, (int, float)):
            continue
        if not isinstance(at, (int, float)):
            at = None
        elif at <= now:
            pct, at = 0, None
        out.append((label, pct, at))
    return out


def strained(limit_rows):
    return any(pct >= STRAINED for _, pct, _ in limit_rows)


def text(limit_rows, when):
    """One line; `when` writes a reset time."""
    return " · ".join(f"{label} {pct:.0f} %" + (f" ({when(at)})" if at else "") for label, pct, at in limit_rows)


def fit(lines, limit=TOOLTIP_MAX):
    """Joins the lines, shortening the first so that the rest is never cut."""
    rest = "".join("\n" + line for line in lines[1:])
    room = max(0, limit - len(rest))
    first = lines[0]
    if len(first) > room:
        first = first[:max(0, room - 1)] + "…"
    return (first + rest)[:limit]
