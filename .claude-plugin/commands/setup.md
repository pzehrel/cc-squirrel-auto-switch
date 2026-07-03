---
description: Configure cc-squirrel-auto-switch statusline
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

Configure cc-squirrel-auto-switch to auto-switch Squirrel input method based on vim mode.

## Step 1: Verify prerequisites

Check that Squirrel CLI and jq are available:

```bash
# Check jq
command -v jq || echo "MISSING: jq"

# Check Squirrel
SQUIRREL="/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel"
if [ -x "$SQUIRREL" ]; then
  echo "OK: Squirrel CLI"
else
  echo "MISSING: Squirrel CLI at $SQUIRREL"
fi
```

If anything is MISSING, tell the user to install it and stop.

## Step 2: Find the plugin

Locate the latest installed version in the CC plugin cache:

```bash
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
PLUGIN_DIR=$(ls -d "$CLAUDE_DIR"/plugins/cache/*/cc-squirrel-auto-switch/*/ 2>/dev/null \
  | awk -F/ '{ print $(NF-1) "\t" $0 }' \
  | grep -E '^[0-9]+\.[0-9]+\.[0-9]+[[:space:]]' \
  | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n \
  | tail -1 \
  | cut -f2-) || true

if [ -z "${PLUGIN_DIR:-}" ]; then
  echo "NOT_FOUND"
else
  echo "FOUND: $PLUGIN_DIR"
fi
```

If NOT_FOUND, the plugin is not installed. Tell the user to install it first via `/plugins`, then re-run `/cc-squirrel-auto-switch:setup`.

## Step 3: Generate the launcher

Write the version-aware launcher to `~/.claude/squirrel-auto-switch.sh`:

```bash
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
LAUNCHER="$HOME/.claude/squirrel-auto-switch.sh"

cat > "$LAUNCHER" << 'LAUNCHER_EOF'
#!/usr/bin/env bash
# cc-squirrel-auto-switch launcher — finds the latest installed version.
set -euo pipefail

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

plugin_dir=$(ls -d "$CLAUDE_DIR"/plugins/cache/*/cc-squirrel-auto-switch/*/ 2>/dev/null \
  | awk -F/ '{ print $(NF-1) "\t" $0 }' \
  | grep -E '^[0-9]+\.[0-9]+\.[0-9]+[[:space:]]' \
  | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n \
  | tail -1 \
  | cut -f2-) || true

if [ -z "${plugin_dir:-}" ]; then
  exit 0
fi

exec bash "${plugin_dir}scripts/statusline.sh"
LAUNCHER_EOF

chmod +x "$LAUNCHER"
echo "Launcher written: $LAUNCHER"
```

## Step 4: Read existing statusLine

```bash
SETTINGS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"

EXISTING=""
if [ -f "$SETTINGS" ]; then
  EXISTING=$(jq -r '(.statusLine.command // .statusLine // "")' "$SETTINGS" 2>/dev/null || true)
fi
echo "EXISTING: ${EXISTING:-(none)}"
```

## Step 5: Ask the user if a non-squirrel statusline is already configured

If `EXISTING` is non-empty AND does NOT contain `squirrel-auto-switch`, use AskUserQuestion:

- header: "Existing statusline"
- question: "Your settings.json already has a statusLine configured:\n\n  `${EXISTING}`\n\nThe squirrel-switch launcher will be piped before it:\n\n  `bash ~/.claude/squirrel-auto-switch.sh | ${EXISTING}`\n\nContinue?"
- options:
  - "Install (pipe before existing statusline)"
  - "Install (replace completely)"
  - "Cancel"

**If "Cancel"**: stop. No changes made.

**If "Install (pipe before)"**: set `PIPE_MODE=before`.

**If "Install (replace)"**: set `PIPE_MODE=replace`.

**If EXISTING is empty or already squirrel**: set `PIPE_MODE=before` (no prompt needed).

## Step 6: Create backup

```bash
SETTINGS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
BACKUP="${SETTINGS}.bak.$(date +%Y%m%d-%H%M%S)"

if [ -f "$SETTINGS" ]; then
  cp "$SETTINGS" "$BACKUP"
  echo "Backup: $BACKUP"
fi
```

## Step 7: Write the new statusLine

Based on `PIPE_MODE`:

**If `before` and EXISTING is non-empty:**
```bash
SWITCH_CMD="bash $HOME/.claude/squirrel-auto-switch.sh"
NEW_CMD="$SWITCH_CMD | $EXISTING"
```

**If `before` and EXISTING is empty:**
```bash
NEW_CMD="bash $HOME/.claude/squirrel-auto-switch.sh > /dev/null"
```

**If `replace`:**
```bash
NEW_CMD="bash $HOME/.claude/squirrel-auto-switch.sh > /dev/null"
```

Then write:

```bash
SETTINGS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"

# Ensure settings.json exists
mkdir -p "$(dirname "$SETTINGS")"
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

# Merge the new statusLine
jq --arg cmd "$NEW_CMD" '.statusLine = { "type": "command", "command": $cmd }' \
  "$SETTINGS" > "${SETTINGS}.tmp" \
  && mv "${SETTINGS}.tmp" "$SETTINGS"

echo "statusLine.command = $NEW_CMD"
```

## Step 8: Verify

Run the launcher to confirm it works:

```bash
echo '{"vim":{"mode":"NORMAL"},"model":{"display_name":"test"},"session_id":"x","transcript_path":"/dev/null","cwd":"/tmp"}' \
  | bash "$HOME/.claude/squirrel-auto-switch.sh" 2>&1
echo "Exit code: $?"
```

If exit code is not 0, report the error and keep the backup path for recovery.

## Step 9: Done

Tell the user:

> **Restart Claude Code** for the change to take effect.
>
> After restart, test: press `i` to enter INSERT mode → Squirrel should switch to Chinese. Press `Esc` → should switch back to ABC.
>
> Backup saved at `{BACKUP}`. To restore: `cp {BACKUP} ~/.claude/settings.json`
>
> Environment variables (add to shell profile if needed):
> - `CC_SQUIRREL_DISABLE=1` — temporarily disable
> - `CC_SQUIRREL_DEFAULT_INSERT_STATE=nascii|ascii` — default insert mode
> - `CC_SQUIRREL_AUTO_ACTIVATE=0` — skip input source activation
>
> To uninstall: delete `~/.claude/squirrel-auto-switch.sh` and restore settings from backup.
