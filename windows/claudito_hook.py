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
except Exception:  # never break Claude Code
    pass
sys.exit(0)
