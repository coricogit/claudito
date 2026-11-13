#!/bin/bash
# Installs Claudito: the Claude Code hook and the KDE Plasma 6 widget.
#
#   ./install.sh              install (or update)
#   ./install.sh --uninstall  remove the hook entries, the script and the widget

set -euo pipefail

DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
ID=org.corico.claudito
BIN="$HOME/.local/bin/claudito-hook"
SETTINGS="$HOME/.claude/settings.json"
HOOK_CMD="~/.local/bin/claudito-hook"
EVENTS=(SessionStart UserPromptSubmit PreToolUse PostToolUse PostToolUseFailure
        PermissionRequest Notification Stop SessionEnd)

step() { printf '\n\e[1m==> %s\e[0m\n' "$*"; }
need() { command -v "$1" >/dev/null || { echo "Missing: $1" >&2; exit 1; }; }
need jq
need kpackagetool6

# Drop every hook entry that runs claudito-hook, leaving everything else alone.
JQ_REMOVE='
  if .hooks then
    .hooks |= (with_entries(
      .value |= (map(.hooks |= map(select((.command // "") | contains("claudito-hook") | not)))
                 | map(select((.hooks | length) > 0)))
    ) | with_entries(select((.value | length) > 0)))
    | if (.hooks | length) == 0 then del(.hooks) else . end
  else . end'

edit_settings() {   # $1 = jq program, extra args after
  local prog="$1"; shift
  mkdir -p "$(dirname "$SETTINGS")"
  [[ -f $SETTINGS ]] || echo '{}' > "$SETTINGS"
  cp "$SETTINGS" "$SETTINGS.claudito-backup"
  local tmp; tmp="$(mktemp)"
  jq "$@" "$prog" "$SETTINGS" > "$tmp"
  jq -e . "$tmp" >/dev/null   # never write broken JSON
  mv "$tmp" "$SETTINGS"
}

if [[ ${1:-} == "--uninstall" ]]; then
  step "Removing the Claude Code hooks"
  [[ -f $SETTINGS ]] && edit_settings "$JQ_REMOVE"
  [[ -L $BIN ]] && rm -f "$BIN"
  step "Removing the Plasma widget"
  kpackagetool6 -t Plasma/Applet -r "$ID" || true
  rm -rf "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/claudito"
  echo "Done. A backup of your settings is in $SETTINGS.claudito-backup"
  exit 0
fi

step "Hook script"
mkdir -p "$(dirname "$BIN")"
chmod +x "$DIR/claudito-hook"
ln -sfn "$DIR/claudito-hook" "$BIN"
echo "$BIN -> $DIR/claudito-hook"

step "Claude Code hooks ($SETTINGS)"
events_json="$(printf '%s\n' "${EVENTS[@]}" | jq -R . | jq -s .)"
edit_settings "$JQ_REMOVE"' |
  reduce $events[] as $e (.;
    .hooks[$e] = ((.hooks[$e] // []) + [{
      "hooks": [{ "type": "command", "command": $cmd, "async": true, "timeout": 5 }]
    }]))' --arg cmd "$HOOK_CMD" --argjson events "$events_json"
echo "Hooked: ${EVENTS[*]}"
echo "(backup of the previous file: $SETTINGS.claudito-backup)"

step "Plasma widget"
if kpackagetool6 -t Plasma/Applet -s "$ID" &>/dev/null; then
  kpackagetool6 -t Plasma/Applet -u "$DIR/plasma/$ID"
  echo "Updated. If Claudito is already on the desktop, reload Plasma:"
  echo "  systemctl --user restart plasma-plasmashell"
else
  kpackagetool6 -t Plasma/Applet -i "$DIR/plasma/$ID"
  echo "Add it: right-click the desktop > Add Widgets > \"Claudito\"."
fi

cat <<EOF

Claude Code sessions started from now on will drive Claudito.
In a session that is already open, run /hooks once to reload the hooks.
EOF
