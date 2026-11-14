"""Runs Claudito's shared scripts (claudito-hook, claudito-statusline,
claudito-usage, in the repository root) on Windows without changing them.

Those scripts were written for Linux: they keep their files in
$XDG_RUNTIME_DIR/claudito, lock with fcntl and fall back to os.getuid().
On Windows this module:
  - points XDG_RUNTIME_DIR and XDG_CACHE_HOME at %LOCALAPPDATA%, so every
    file lives in %LOCALAPPDATA%\\claudito
  - provides a small fcntl.flock() built on msvcrt.locking()
  - retries os.replace() while another process has the target open
  - fixes the bits of claudito-usage that assume POSIX paths or commands
On Linux and macOS it changes nothing, so the app can also be tried there.
"""
import importlib.machinery
import importlib.util
import os
import runpy
import shutil
import subprocess
import sys
import time
import types

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
IS_WINDOWS = os.name == "nt"
CREATE_NO_WINDOW = 0x08000000


def setup_env():
    """Must run before any shared script is loaded."""
    if IS_WINDOWS:
        base = os.environ.get("LOCALAPPDATA") or os.path.join(os.path.expanduser("~"), "AppData", "Local")
        # Forced, not setdefault: the app and the hook must agree on the folder.
        os.environ["XDG_RUNTIME_DIR"] = base
        os.environ["XDG_CACHE_HOME"] = base
        _install_fcntl_shim()
        _patch_os_replace()


def data_dir():
    runtime = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    return os.path.join(runtime, "claudito")


def state_file():
    return os.path.join(data_dir(), "state.json")


def utf8_stdio():
    """Claude Code talks UTF-8; the Windows console default may not be."""
    for stream in (sys.stdin, sys.stdout):
        try:
            stream.reconfigure(encoding="utf-8")
        except (AttributeError, ValueError):
            pass


def run_script(name):
    """Run a shared script as if it were started directly."""
    runpy.run_path(os.path.join(ROOT, name), run_name="__main__")


def load_script(name):
    """Import a shared script (no .py extension) as a module."""
    path = os.path.join(ROOT, name)
    modname = name.replace("-", "_")
    loader = importlib.machinery.SourceFileLoader(modname, path)
    spec = importlib.util.spec_from_loader(modname, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


def load_usage():
    """claudito-usage as a module, with its POSIX assumptions fixed."""
    mod = load_script("claudito-usage")
    roots = {}

    def project_of(cwd):
        """Name of the git repo containing cwd, or the folder itself."""
        cwd = (cwd or "").rstrip("/\\")
        if not cwd:
            return "?"
        if cwd not in roots:
            d, found = cwd, None
            while True:
                if os.path.exists(os.path.join(d, ".git")):
                    found = d
                    break
                parent = os.path.dirname(d)
                if not parent or parent == d:   # "/" or "C:\"
                    break
                d = parent
            roots[cwd] = os.path.basename((found or cwd).rstrip("/\\")) or cwd
        return roots[cwd]

    mod.project_of = project_of
    mod.subprocess = _Subprocess()
    return mod


class _Subprocess:
    """subprocess for claudito-usage: finds claude.exe / claude.cmd on PATH
    and never flashes a console window from the tray app."""

    def __getattr__(self, name):
        return getattr(subprocess, name)

    def run(self, args, **kw):
        args = list(args)
        args[0] = shutil.which(args[0]) or args[0]
        if IS_WINDOWS:
            kw.setdefault("creationflags", CREATE_NO_WINDOW)
        return subprocess.run(args, **kw)


def _install_fcntl_shim():
    if "fcntl" in sys.modules:
        return
    import msvcrt

    m = types.ModuleType("fcntl")
    m.LOCK_SH, m.LOCK_EX, m.LOCK_NB, m.LOCK_UN = 1, 2, 4, 8

    def flock(f, op):
        fd = f.fileno() if hasattr(f, "fileno") else f
        os.lseek(fd, 0, os.SEEK_SET)
        if op & m.LOCK_UN:
            msvcrt.locking(fd, msvcrt.LK_UNLCK, 1)
        elif op & m.LOCK_NB:
            msvcrt.locking(fd, msvcrt.LK_NBLCK, 1)
        else:
            msvcrt.locking(fd, msvcrt.LK_LOCK, 1)   # retries for ~10 s, then OSError

    m.flock = flock
    sys.modules["fcntl"] = m


def _patch_os_replace():
    """On Windows os.replace() fails while a reader has the target open
    (the tray app polls state.json twice a second). Retry briefly."""
    original = os.replace
    if getattr(original, "_claudito", False):
        return

    def replace(src, dst, *a, **kw):
        for _ in range(40):
            try:
                return original(src, dst, *a, **kw)
            except PermissionError:
                time.sleep(0.025)
        return original(src, dst, *a, **kw)

    replace._claudito = True
    os.replace = replace
