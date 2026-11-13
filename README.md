# Claudito — Claude Code desktop buddy for KDE Plasma 6

A little character on your KDE Plasma desktop that shows what
[Claude Code](https://claude.com/claude-code) is doing, with a different hat
or helmet for each kind of work:

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

Click it to poke it. Under it, a caption says what it's doing and in which project.

## How it works

`claudito-hook` runs as an async [Claude Code hook](https://docs.claude.com/en/docs/claude-code/hooks)
on session, prompt, tool, notification and stop events. It writes the current
activity of each session to `$XDG_RUNTIME_DIR/claudito/state.json` (a RAM
folder only your user can read) and the Plasma widget polls that file. With
several sessions open, it follows the most recent one.

The caption shows file names, search patterns, web domains and the descriptions
of terminal commands, never file contents.

## Install

Needs KDE Plasma 6, Python 3 and `jq`.

```bash
git clone <this repo> ~/src/claudito
~/src/claudito/install.sh
```

It links `~/.local/bin/claudito-hook`, adds the hooks to
`~/.claude/settings.json` (your other settings and hooks are kept; a backup goes
to `settings.json.claudito-backup`) and installs the widget. Then right-click
the desktop > *Add Widgets* > **Claudito**. It also works in a panel.

New Claude Code sessions pick the hooks up on their own. In a session that is
already open, run `/hooks` once.

Remove it with `./install.sh --uninstall`.
