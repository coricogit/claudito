#!/bin/bash
# Installs Claudito: the Claude Code hook and status line, and the two KDE
# Plasma 6 widgets (the desktop buddy and the usage panel).
#
#   ./install.sh              install (or update)
#   ./install.sh --uninstall  remove the hook entries, the script and the widget

set -euo pipefail

DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
ID=org.corico.claudito
USAGE_ID=org.corico.claudito.usage
BIN="$HOME/.local/bin/claudito-hook"
BINDIR="$HOME/.local/bin"
STATUS_CMD="~/.local/bin/claudito-statusline"
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
  [[ -f $SETTINGS ]] && edit_settings "$JQ_REMOVE"' | if (.statusLine.command // "") == $s then del(.statusLine) else . end' --arg s "$STATUS_CMD"
  for f in claudito-hook claudito-statusline claudito-usage; do [[ -L $BINDIR/$f ]] && rm -f "$BINDIR/$f"; done
  step "Removing the Plasma widgets"
  kpackagetool6 -t Plasma/Applet -r "$ID" || true
  kpackagetool6 -t Plasma/Applet -r "$USAGE_ID" || true
  rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/claudito"
  rm -rf "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/claudito"
  echo "Done. A backup of your settings is in $SETTINGS.claudito-backup"
  exit 0
fi

step "Scripts"
mkdir -p "$BINDIR"
for f in claudito-hook claudito-statusline claudito-usage; do
  chmod +x "$DIR/$f"
  ln -sfn "$DIR/$f" "$BINDIR/$f"
  echo "$BINDIR/$f -> $DIR/$f"
done

step "Claude Code hooks ($SETTINGS)"
events_json="$(printf '%s\n' "${EVENTS[@]}" | jq -R . | jq -s .)"
edit_settings "$JQ_REMOVE"' |
  reduce $events[] as $e (.;
    .hooks[$e] = ((.hooks[$e] // []) + [{
      "hooks": [{ "type": "command", "command": $cmd, "async": true, "timeout": 5 }]
    }]))' --arg cmd "$HOOK_CMD" --argjson events "$events_json"
echo "Hooked: ${EVENTS[*]}"
current_status="$(jq -r '.statusLine.command // ""' "$SETTINGS")"
if [[ -z $current_status || $current_status == "$STATUS_CMD" ]]; then
  edit_settings '.statusLine = {"type": "command", "command": $s}' --arg s "$STATUS_CMD"
  echo "Status line: claudito-statusline (model · context · 5h · 7d)"
else
  echo "You already have a status line ($current_status); left as is."
  echo "Without claudito-statusline the usage widget can't show plan limits or the live session."
fi
echo "(backup of the previous file: $SETTINGS.claudito-backup)"

step "Plasma widgets"
for id in "$ID" "$USAGE_ID"; do
  if kpackagetool6 -t Plasma/Applet -s "$id" &>/dev/null; then
    kpackagetool6 -t Plasma/Applet -u "$DIR/plasma/$id"
  else
    kpackagetool6 -t Plasma/Applet -i "$DIR/plasma/$id"
  fi
done
echo "Add them with right-click > Add Widgets:"
echo "  \"Claudito\" on the desktop, \"Claudito Usage\" in the panel."
echo "If they were already added, reload Plasma: systemctl --user restart plasma-plasmashell"

cat <<EOF

Claude Code sessions started from now on will drive Claudito.
In a session that is already open, run /hooks once to reload the hooks.
EOF
