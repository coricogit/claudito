"""Installs Claudito on Windows.

    py windows\\install.py              install (or update) and start Claudito
    py windows\\install.py --uninstall  remove the hooks, status line and autostart

The .exe installer (installer/claudito.iss) runs this too, with the Python it
carries.

What it does:
  - installs PySide6 for this Python if it is missing
  - adds windows\\claudito_hook.py as an async Claude Code hook and
    windows\\claudito_statusline.py as the status line (unless you already
    have another one) in %USERPROFILE%\\.claude\\settings.json, keeping a
    backup in settings.json.claudito-backup
  - starts Claudito when you log in (HKCU ...\\CurrentVersion\\Run)
  - starts Claudito now
"""
import argparse
import copy
import json
import os
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(HERE, "claudito.pyw")
HOOK = os.path.join(HERE, "claudito_hook.py")
STATUS = os.path.join(HERE, "claudito_statusline.py")
REQUIREMENTS = os.path.join(HERE, "requirements.txt")

EVENTS = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure",
          "PermissionRequest", "Notification", "Stop", "SessionEnd"]
OURS_HOOK = ("claudito-hook", "claudito_hook")
OURS_STATUS = ("claudito-statusline", "claudito_statusline")

RUN_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run"
RUN_NAME = "Claudito"


def step(msg):
    print(f"\n==> {msg}")


def settings_path():
    config = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.join(os.path.expanduser("~"), ".claude")
    return os.path.join(config, "settings.json")


def console_python():
    """python.exe, never pythonw.exe: the status line has to print."""
    exe = sys.executable
    if os.path.basename(exe).lower() == "pythonw.exe":
        exe = os.path.join(os.path.dirname(exe), "python.exe")
    return exe


def gui_python():
    """pythonw.exe when there is one, so no console window opens."""
    exe = sys.executable
    w = os.path.join(os.path.dirname(exe), "pythonw.exe")
    return w if os.path.exists(w) else exe


def command(script):
    # Forward slashes work in both cmd and the Git Bash Claude Code uses.
    def q(p):
        return '"' + p.replace("\\", "/") + '"'
    return f"{q(console_python())} {q(script)}"


# ---------- settings.json ----------

def load_settings(path):
    try:
        with open(path, encoding="utf-8-sig") as f:   # some editors leave a BOM
            data = json.load(f)
    except FileNotFoundError:
        return {}
    except ValueError as e:
        raise SystemExit(f"{path} is not valid JSON ({e}); not touching it.")
    if not isinstance(data, dict):
        raise SystemExit(f"{path} is not a JSON object; not touching it.")
    return data


def save_settings(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path):
        shutil.copy2(path, path + ".claudito-backup")
    text = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    json.loads(text)   # never write broken JSON
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


def is_ours(cmd, names):
    return any(n in (cmd or "") for n in names)


def remove_hooks(data):
    """Drop every hook entry that runs a Claudito hook, leaving the rest alone."""
    hooks = data.get("hooks")
    if not isinstance(hooks, dict):
        return data
    for event in list(hooks):
        groups = []
        for group in hooks[event] or []:
            inner = [h for h in group.get("hooks", []) if not is_ours(h.get("command"), OURS_HOOK)]
            if inner:
                groups.append({**group, "hooks": inner})
        if groups:
            hooks[event] = groups
        else:
            del hooks[event]
    if not hooks:
        del data["hooks"]
    return data


def add_hooks(data, cmd):
    hooks = data.setdefault("hooks", {})
    for event in EVENTS:
        hooks.setdefault(event, []).append(
            {"hooks": [{"type": "command", "command": cmd, "async": True, "timeout": 5}]})
    return data


def install_settings(path):
    before = load_settings(path)
    data = remove_hooks(copy.deepcopy(before))
    add_hooks(data, command(HOOK))
    print("Hooked:", " ".join(EVENTS))
    current = (data.get("statusLine") or {}).get("command", "")
    if not current or is_ours(current, OURS_STATUS):
        data["statusLine"] = {"type": "command", "command": command(STATUS)}
        print("Status line: claudito_statusline.py (model · context · 5h · 7d)")
    else:
        print(f"You already have a status line ({current}); left as is.")
        print("Without Claudito's status line the usage panel can't show plan limits or the live session.")
    if data == before:   # an update, most likely: keep the older backup
        print("Nothing to change.")
        return
    save_settings(path, data)
    print(f"(backup of the previous file: {path}.claudito-backup)")


def uninstall_settings(path):
    if not os.path.exists(path):
        return
    data = remove_hooks(load_settings(path))
    if is_ours((data.get("statusLine") or {}).get("command"), OURS_STATUS):
        del data["statusLine"]
    save_settings(path, data)


# ---------- Autostart ----------

def autostart_command():
    return f'"{gui_python()}" "{APP}"'


def autostart_enabled():
    if os.name != "nt":
        return False
    import winreg
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, RUN_KEY) as key:
            winreg.QueryValueEx(key, RUN_NAME)
            return True
    except OSError:
        return False


def set_autostart(on):
    if os.name != "nt":
        return
    import winreg
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, RUN_KEY, 0, winreg.KEY_SET_VALUE) as key:
        if on:
            winreg.SetValueEx(key, RUN_NAME, 0, winreg.REG_SZ, autostart_command())
        else:
            try:
                winreg.DeleteValue(key, RUN_NAME)
            except FileNotFoundError:
                pass


# ---------- Main ----------

def ensure_pyside():
    try:
        import PySide6  # noqa: F401
        print("PySide6", PySide6.__version__)
    except ImportError:
        print("Installing PySide6 for", sys.executable)
        in_venv = sys.prefix != getattr(sys, "base_prefix", sys.prefix)
        user = [] if in_venv else ["--user"]
        subprocess.check_call([sys.executable, "-m", "pip", "install", *user, "-r", REQUIREMENTS])


def start_app():
    flags = 0
    if os.name == "nt":
        flags = subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP
    subprocess.Popen([gui_python(), APP], cwd=HERE, creationflags=flags, close_fds=True)


def stop_app():
    """Closes every copy of Claudito that is open."""
    if os.name != "nt":
        return
    script = ("Get-CimInstance Win32_Process -Filter \"Name like 'python%'\" | "
              "Where-Object { $_.CommandLine -like '*claudito.pyw*' } | "
              "ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }")
    subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", script],
                   creationflags=subprocess.CREATE_NO_WINDOW, stdin=subprocess.DEVNULL,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(0.5)   # Windows takes a moment to let go of its files


def purge():
    """Claudito's own files and settings; nothing of Claude Code's."""
    if os.name != "nt":
        return
    import winreg
    base = os.environ.get("LOCALAPPDATA")
    if base:
        shutil.rmtree(os.path.join(base, "claudito"), ignore_errors=True)
    try:
        winreg.DeleteKey(winreg.HKEY_CURRENT_USER, r"Software\corico\Claudito")
    except OSError:
        pass


def main():
    ap = argparse.ArgumentParser(description="Install Claudito for Windows.")
    ap.add_argument("--uninstall", action="store_true", help="remove hooks, status line and autostart")
    ap.add_argument("--no-autostart", action="store_true", help="don't start Claudito when you log in")
    ap.add_argument("--keep-autostart", action="store_true", help="don't change whether it starts when you log in")
    ap.add_argument("--no-start", action="store_true", help="don't start Claudito now")
    ap.add_argument("--stop", action="store_true", help="close Claudito first; alone, do nothing else")
    ap.add_argument("--purge", action="store_true", help="with --uninstall, also delete Claudito's data and settings")
    ap.add_argument("--log", metavar="FILE", help="write the output to a file")
    args = ap.parse_args()
    if args.log:
        sys.stdout = sys.stderr = open(args.log, "w", encoding="utf-8", buffering=1)
    path = settings_path()

    if args.stop:
        stop_app()
        if not (args.uninstall or args.log or args.no_start or args.no_autostart):
            return

    if args.uninstall:
        step(f"Removing the Claude Code hooks ({path})")
        uninstall_settings(path)
        step("Removing autostart")
        set_autostart(False)
        if args.purge:
            purge()
        print("Done. Quit Claudito from its tray icon if it is running.")
        print(f"A backup of your settings is in {path}.claudito-backup")
        return

    if sys.version_info < (3, 9):
        raise SystemExit("Claudito needs Python 3.9 or newer.")

    step("PySide6")
    ensure_pyside()

    step(f"Claude Code hooks ({path})")
    install_settings(path)

    if os.name == "nt" and not args.keep_autostart:
        step("Autostart")
        set_autostart(not args.no_autostart)
        print("Claudito starts when you log in." if not args.no_autostart else "Autostart off.")

    if not args.no_start:
        step("Starting Claudito")
        start_app()
        print("Look for the little coral face in the tray (it may be under the ^ arrow).")

    print("""
Claude Code sessions started from now on will drive Claudito.
In a session that is already open, run /hooks once to reload the hooks.""")


if __name__ == "__main__":
    main()
