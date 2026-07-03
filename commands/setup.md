---
description: Configure cc-squirrel-auto-switch statusline
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

Run each step in order. Execute the bash commands directly — do not just display them.

## 1. Verify prerequisites

```bash
command -v jq || { echo "MISSING: jq — install: brew install jq"; exit 1; }
[ -x "/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel" ] || { echo "MISSING: Squirrel"; exit 1; }
echo "OK"
```

If any check fails, tell the user and stop.

## 2. Generate the launcher

```bash
cat > "$HOME/.claude/squirrel-auto-switch.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
plugin_dir=$(ls -d "$CLAUDE_DIR"/plugins/cache/*/cc-squirrel-auto-switch/*/ 2>/dev/null \
  | awk -F/ '{ print $(NF-1) "\t" $0 }' \
  | grep -E '^[0-9]+\.[0-9]+\.[0-9]+[[:space:]]' \
  | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n \
  | tail -1 | cut -f2-) || true
[ -z "${plugin_dir:-}" ] && exit 0
exec bash "${plugin_dir}scripts/statusline.sh"
EOF
chmod +x "$HOME/.claude/squirrel-auto-switch.sh"
echo "OK"
```

## 3. Read existing statusLine, build new command

```bash
SETTINGS="$HOME/.claude/settings.json"
EXISTING=$(jq -r '(.statusLine.command // "")' "$SETTINGS" 2>/dev/null || true)

# Strip old squirrel-switch entries (dev paths, previous installs)
EXISTING=$(echo "$EXISTING" \
  | sed 's/bash .*squirrel-auto-switch.*statusline.sh *| *//' \
  | sed 's/ *| *bash .*squirrel-auto-switch.*statusline.sh//' \
  | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

LAUNCHER="bash $HOME/.claude/squirrel-auto-switch.sh"

if [ -z "$EXISTING" ]; then
  NEW_CMD="$LAUNCHER > /dev/null"
  echo "NEW_CMD=$NEW_CMD"
else
  echo "EXISTING=$EXISTING"
  NEW_CMD="$LAUNCHER | $EXISTING"
  echo "NEW_CMD=$NEW_CMD"
fi
```

## 4. Confirm if replacing an existing statusline

If EXISTING was non-empty AND did not already contain `squirrel-auto-switch.sh`, use AskUserQuestion:

- header: "Existing statusline"
- question: "Found existing statusLine. Pipe squirrel-switch before it?\n\n  `${NEW_CMD}`"
- options: "Yes (pipe before)", "Replace completely", "Cancel"

If canceled: stop. If "replace": set `NEW_CMD="$LAUNCHER > /dev/null"`. Otherwise proceed.

## 5. Backup and write

```bash
SETTINGS="$HOME/.claude/settings.json"
cp "$SETTINGS" "${SETTINGS}.bak.$(date +%Y%m%d-%H%M%S)"

mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

jq --arg cmd "$NEW_CMD" '.statusLine = { "type": "command", "command": $cmd }' \
  "$SETTINGS" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"

echo "DONE"
jq '.statusLine' "$SETTINGS"
```

## 6. Verify

```bash
echo '{"vim":{"mode":"NORMAL"},"model":{"display_name":"test"},"session_id":"x","transcript_path":"/dev/null","cwd":"/tmp"}' \
  | bash "$HOME/.claude/squirrel-auto-switch.sh" 2>&1
echo "Exit: $?"
```

If exit is not 0, show the error and backup path.

## 7. Done

Tell the user:

> **Restart Claude Code**. After restart: `i` → Chinese, `Esc` → ABC.
> Backup: `~/.claude/settings.json.bak.*`
> Uninstall: delete `~/.claude/squirrel-auto-switch.sh` and restore settings from backup.
