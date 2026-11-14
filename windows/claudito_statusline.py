"""Claude Code status line for Claudito on Windows.

Runs the shared ../claudito-statusline, which saves what Claude Code reports
(model, context, plan limits) for the usage panel and prints a short line.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    import compat

    compat.setup_env()
    compat.utf8_stdio()
    compat.run_script("claudito-statusline")
except SystemExit:
    raise
except Exception:
    print("Claudito")
