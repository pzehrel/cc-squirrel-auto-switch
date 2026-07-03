#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# cc-squirrel-auto-switch  install script
#
# Usage:
#   bash install.sh           # install
#   bash install.sh --remove  # uninstall
#
# Generates the version-aware launcher and configures settings.json.
# No AI involvement needed — just run this script.
# ──────────────────────────────────────────────────────────────

set -euo pipefail

REMOVE=0
[ "${1:-}" = "--remove" ] && REMOVE=1

LAUNCHER="$HOME/.claude/squirrel-auto-switch.sh"
SETTINGS="$HOME/.claude/settings.json"

# ── Remove ───────────────────────────────────────────────────

if [ "$REMOVE" -eq 1 ]; then
    rm -f "$LAUNCHER"
    echo "[ok] Removed launcher: $LAUNCHER"

    if [ -f "$SETTINGS" ]; then
        EXISTING=$(jq -r '(.statusLine.command // "")' "$SETTINGS" 2>/dev/null || true)
        # Strip our launcher from the pipe chain
        CLEANED=$(echo "$EXISTING" \
            | sed 's/bash .*squirrel-auto-switch.sh *| *//' \
            | sed 's/ *| *bash .*squirrel-auto-switch.sh//' \
            | sed 's/ > \/dev\/null//' \
            | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        cp "$SETTINGS" "${SETTINGS}.bak.$(date +%Y%m%d-%H%M%S)"

        if [ -z "$CLEANED" ]; then
            jq 'del(.statusLine)' "$SETTINGS" > "${SETTINGS}.tmp" \
                && mv "${SETTINGS}.tmp" "$SETTINGS"
            echo "[ok] Removed statusLine (was squirrel-switch only)"
        else
            jq --arg cmd "$CLEANED" \
                '.statusLine = { "type": "command", "command": $cmd }' \
                "$SETTINGS" > "${SETTINGS}.tmp" \
                && mv "${SETTINGS}.tmp" "$SETTINGS"
            echo "[ok] Restored: $CLEANED"
        fi
    fi
    echo "[ok] Uninstall complete."
    exit 0
fi

# ── Prerequisites ────────────────────────────────────────────

if ! command -v jq >/dev/null 2>&1; then
    echo "[err] jq is required. Install: brew install jq"
    exit 1
fi

# ── Generate launcher ────────────────────────────────────────

cat > "$LAUNCHER" << 'EOF'
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
chmod +x "$LAUNCHER"
echo "[ok] Launcher: $LAUNCHER"

# ── Configure statusLine ─────────────────────────────────────

mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

EXISTING=$(jq -r '(.statusLine.command // "")' "$SETTINGS" 2>/dev/null || true)

# Strip old squirrel entries
EXISTING=$(echo "$EXISTING" \
    | sed 's/bash .*squirrel-auto-switch.*statusline.sh *| *//' \
    | sed 's/ *| *bash .*squirrel-auto-switch.*statusline.sh//' \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if echo "$EXISTING" | grep -qF "squirrel-auto-switch.sh"; then
    echo "[ok] Already configured:"
    jq '.statusLine' "$SETTINGS"
    exit 0
fi

# Build new command
if [ -z "$EXISTING" ]; then
    NEW_CMD="bash $LAUNCHER > /dev/null"
else
    NEW_CMD="bash $LAUNCHER | $EXISTING"
fi

# Backup
cp "$SETTINGS" "${SETTINGS}.bak.$(date +%Y%m%d-%H%M%S)"

# Write
jq --arg cmd "$NEW_CMD" '.statusLine = { "type": "command", "command": $cmd }' \
    "$SETTINGS" > "${SETTINGS}.tmp" \
    && mv "${SETTINGS}.tmp" "$SETTINGS"

echo "[ok] statusLine: $NEW_CMD"
echo ""
echo "  Restart Claude Code for the change to take effect."
