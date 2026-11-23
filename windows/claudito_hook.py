"""Claude Code hook for Claudito on Windows.

Runs the shared ../claudito-hook with the Windows compatibility layer.
Like the original, it never prints anything and always exits 0.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    import compat

    compat.setup_env()
    compat.utf8_stdio()
    compat.run_script("claudito-hook")
except SystemExit:
    pass
except Exception:  # never break Claude Code (the shared hook logs its own errors)
    try:
        import time
        import traceback

        folder = os.path.join(os.environ["LOCALAPPDATA"], "claudito")
        os.makedirs(folder, exist_ok=True)
        path = os.path.join(folder, "hook.log")
        big = os.path.exists(path) and os.path.getsize(path) > 100_000
        with open(path, "w" if big else "a", encoding="utf-8") as f:
            f.write(time.strftime("%Y-%m-%d %H:%M:%S ") + traceback.format_exc() + "\n")
    except Exception:
        pass
sys.exit(0)
