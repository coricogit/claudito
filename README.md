# Claudito — Claude Code desktop buddy for Windows 11

A little character on your Windows desktop that shows what
[Claude Code](https://claude.com/claude-code) is doing, with a different hat
or helmet for each kind of work.

*[Leer en español](README.es.md)* · Using KDE Plasma? The Plasma widgets are
on the [`main`](https://github.com/coricogit/claudito/tree/main) branch.

| Claude Code is… | Hat | Animation |
|---|---|---|
| Thinking about your message | Propeller beanie | Propeller spins, looks up, "…" |
| Editing or writing files | Construction hard hat | Hammers away |
| Running terminal commands | Miner's helmet | Types fast, lamp beam |
| Reading or searching code | Detective deerstalker | Magnifier sweep |
| Searching the web | Pith helmet | Walks in place |
| Running subagents | Captain's cap | Points ahead |
| Planning / tracking tasks | Wizard hat | Sparkles |
| Making artifacts, skills, MCP calls | Beret | Paints |
| Waiting for your permission or answer | (keeps its hat) | Waves, "!" bubble |
| A tool failed | — | Sweat drop |
| Finished | Party hat | Jumps with stars |
| Nothing going on for 10 min | Nightcap | Zzz |

Claudito lives in a transparent, frameless window that stays above your other
windows. Under it, a caption says what it's doing and in which project.

## Install

Needs [Python 3.9+](https://www.python.org/downloads/windows/) (tick **Add
python.exe to PATH**) and Claude Code running on this computer: the `claude`
command in a terminal, or a **Local** session in the Code tab of the Claude
desktop app. Cloud sessions don't run your local hooks, so Claudito can't see
them.

```powershell
git clone -b windows https://github.com/coricogit/claudito.git $HOME\src\claudito
py $HOME\src\claudito\windows\install.py
```

Or double-click `windows\instalar.bat`, which does the same and keeps the
output in `windows\install.log`.

The installer:

- installs PySide6 for that Python if it's missing
- adds `windows\claudito_hook.py` as an async Claude Code hook and
  `windows\claudito_statusline.py` as the status line to
  `%USERPROFILE%\.claude\settings.json` (your other settings and hooks are
  kept, an existing status line is left alone, and a backup goes to
  `settings.json.claudito-backup`)
- makes Claudito start when you log in (`--no-autostart` to skip)
- starts it (`--no-start` to skip)

New Claude Code sessions pick the hooks up on their own. In a terminal session
that is already open, run `/hooks` once; in the desktop app, start a new
session.

Update with `git pull` and run `install.py` again (the hook paths are stored
in `settings.json`, so keep the folder where it is or reinstall after moving
it). Remove everything with `py windows\install.py --uninstall`.

## Using it

**The buddy** starts in the bottom-right corner of your main screen.

- drag it anywhere: it remembers where you left it, even across reboots
- click it to make it hop
- right-click it for the menu

**The tray icon** is a mini Claudito whose face follows what Claude is doing:
asleep, focused while it works, happy when it's done, worried when something
fails. An orange **!** appears when Claude Code is waiting for you. Hover it to
see what Claude is doing and how many tokens it has written today.

- **click**: the usage panel
- **middle-click**: show or hide the buddy
- **right-click**: show the buddy, usage, size (small / medium / large),
  season, always on top, notifications, hide behind full-screen apps, start with
  Windows, quit

**Seasons**: Claudito dresses for the season where you live (from the country
in Windows settings, so it is right in both hemispheres). The hat shows when
it has no work hat on; the outfit, always. The tray icon wears both. *Season* in the menu picks another
one or takes either piece off.

| Season | Hat | Outfit |
|---|---|---|
| Spring | Flower crown | Gardening overalls |
| Summer | Straw hat | Hawaiian shirt |
| Autumn | Acorn cap with a leaf | Knitted sweater |
| Winter | Bobble hat | Scarf |

**Several sessions**: one that needs you always shows first, then the ones
working, then the idle ones.

**Notifications**: Windows tells you when Claude has been waiting for you for
more than 5 seconds and when a task of a minute or more ends.

**Full screen**: the buddy hides while a game, video or presentation covers
its screen.

If the icon isn't visible, it's under the **^** arrow in the taskbar. Drag it
onto the taskbar, or turn it on in *Settings > Personalization > Taskbar >
Other system tray icons*.

`windows\reiniciar.bat` closes Claudito and opens it again.

## Usage panel

Click the tray icon for:

- your plan and account (email hidden until you click it)
- tokens written/read, replies and sessions for today, 7 and 30 days
- a 14-day chart and the projects and models you use most
- a button to open your usage page on claude.ai

It closes when you click elsewhere. Everything comes from files Claude Code
keeps on your computer (`~/.claude.json` and the session histories in
`~/.claude\projects`); nothing is sent anywhere. Plan limits and the live
session aren't shown on Windows: Claude Code only reports them to its status
line, which the Code tab of the Claude desktop app doesn't run. Check them on
claude.ai.

## How it works

The Windows version shares its code with the KDE Plasma one instead of copying
it:

| Piece | Windows file | Shared code it runs |
|---|---|---|
| Hook | `windows\claudito_hook.py` | `claudito-hook` |
| Status line | `windows\claudito_statusline.py` | `claudito-statusline` |
| Usage data | in-process, in a thread | `claudito-usage` |
| Buddy window | `windows\qml\Buddy.qml` | `plasma/.../Character.qml`, `hats.js`, `sprites.js`, `strings.js` |
| Usage panel | `windows\qml\UsagePanel.qml` | `plasma/.../MiniClaudito.qml`, usage `strings.js` |
| What to show, notifications | `windows\activity.py` | — |
| Seasons | `windows\seasons.py` | `Character.qml`, `sprites.js` |
| Full-screen detection | `windows\fullscreen.py` | — |
| App and tray | `windows\claudito.pyw` | — |

`windows\compat.py` points the scripts' `$XDG_RUNTIME_DIR` and
`$XDG_CACHE_HOME` at `%LOCALAPPDATA%`, so everything lives in
`%LOCALAPPDATA%\claudito` (`state.json`, `statusline.json` and caches). It
also stands in for `fcntl` with `msvcrt` file locks, retries `os.replace`
while the app is reading the file, finds `claude.exe`/`claude.cmd` for
`claude auth status` without flashing a console, and understands `C:\` paths
when naming projects.

Qt Quick draws with its software renderer on Windows: it keeps the transparent
window reliable on every graphics card, and a 60 × 50 pixel sprite costs
nothing. Set `CLAUDITO_GRAPHICS=d3d11` or `opengl` to try hardware rendering.

To run it by hand: double-click `windows\claudito.pyw`, or
`pyw windows\claudito.pyw`. Run it with `py` instead to see QML errors in the
console. Only one copy runs at a time.

No hook fires when you answer a permission prompt, press Esc or close the
terminal, so `activity.py` also looks at the status Claude Code keeps in
`~/.claude\sessions`. That folder is internal to Claude Code: if it changes,
Claudito goes back to relying on the hooks alone.

Tests: `py -m unittest discover -s windows/tests`.

The caption shows file names, search patterns, web domains and the
descriptions of terminal commands, never file contents.
