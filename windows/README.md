# Claudito for Windows 11

*[Leer en español](README.es.md)*

The same pixel buddy as the KDE Plasma widget, on the Windows desktop: a
transparent, frameless window with Claudito and its caption, and a tray icon
that opens the Claude usage panel.

Nothing is copied from the Plasma version. The app loads
`plasma/org.corico.claudito/contents/ui/Character.qml` (plus its hats, sprites
and strings) and the usage widget's `MiniClaudito.qml` and strings straight
from the repository, and runs the shared `claudito-hook`, `claudito-statusline`
and `claudito-usage` scripts through a small compatibility layer
(`compat.py`). Fix a hat once and both platforms get it.

## Install

Needs [Python 3.9+](https://www.python.org/downloads/windows/) and Claude Code.

```powershell
git clone https://github.com/coricogit/claudito.git $HOME\src\claudito
py $HOME\src\claudito\windows\install.py
```

The installer:

- installs PySide6 for that Python if it's missing
- adds `windows\claudito_hook.py` as an async Claude Code hook and
  `windows\claudito_statusline.py` as the status line to
  `%USERPROFILE%\.claude\settings.json` (your other settings and hooks are
  kept, an existing status line is left alone, and a backup goes to
  `settings.json.claudito-backup`)
- makes Claudito start when you log in (`--no-autostart` to skip)
- starts it (`--no-start` to skip)

New Claude Code sessions pick the hooks up on their own. In a session that is
already open, run `/hooks` once.

Update with `git pull` and run `install.py` again (the hook paths are stored
in `settings.json`, so keep the folder where it is or reinstall after moving
it). Remove everything with `py windows\install.py --uninstall`.

## Using it

**The buddy** sits above your other windows, bottom right at first.

- drag it anywhere: it remembers where you left it, even across reboots
- click it to make it hop
- right-click it for the menu

**The tray icon** is a mini Claudito whose face follows your 5-hour window:
happy, focused, sweating. An orange **!** appears when Claude Code is waiting
for you. Hover it to see what Claude is doing and your limits.

- **click**: the usage panel (plan limits with reset times, current session,
  tokens for today / 7 / 30 days, a 14-day chart, top projects and models).
  It closes when you click elsewhere.
- **middle-click**: show or hide the buddy
- **right-click**: show the buddy, usage, size (small / medium / large),
  always on top, start with Windows, quit

If the icon isn't visible, it's under the **^** arrow in the taskbar. Drag it
onto the taskbar, or turn it on in *Settings > Personalization > Taskbar >
Other system tray icons*.

## How it works

| Piece | Windows file | Shared code it runs |
|---|---|---|
| Hook | `windows\claudito_hook.py` | `claudito-hook` |
| Status line | `windows\claudito_statusline.py` | `claudito-statusline` |
| Usage data | in-process, in a thread | `claudito-usage` |
| Buddy window | `windows\qml\Buddy.qml` | `Character.qml`, `hats.js`, `sprites.js`, `strings.js` |
| Usage panel | `windows\qml\UsagePanel.qml` | `MiniClaudito.qml`, usage `strings.js` |
| App and tray | `windows\claudito.pyw` | — |

`compat.py` points the scripts' `$XDG_RUNTIME_DIR` and `$XDG_CACHE_HOME` at
`%LOCALAPPDATA%`, so everything lives in `%LOCALAPPDATA%\claudito`
(`state.json`, `statusline.json` and caches). It also stands in for `fcntl`
with `msvcrt` file locks, retries `os.replace` while the app is reading the
file, finds `claude.exe`/`claude.cmd` for `claude auth status` without
flashing a console, and understands `C:\` paths when naming projects. Nothing
is sent anywhere.

Qt Quick draws with its software renderer on Windows: it keeps the
transparent window reliable on every graphics card, and a 60 × 50 pixel
sprite costs nothing. Set `CLAUDITO_GRAPHICS=d3d11` or `opengl` to try
hardware rendering.

To run it by hand: double-click `claudito.pyw`, or `pyw windows\claudito.pyw`.
Run it with `py` instead to see QML errors in the console. Only one copy runs
at a time.

The app also runs on Linux and macOS (`python3 windows/claudito.pyw`), which is
handy for working on it, but there the Plasma widgets are the real thing.
