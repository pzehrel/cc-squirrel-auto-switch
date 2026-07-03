#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# cc-squirrel-auto-switch  install script
#
# Writes the version-aware launcher to ~/.claude/.
# Settings.json configuration is handled by /cc-squirrel-auto-switch:setup.
#
# Usage:
#   bash install.sh           # install launcher
#   bash install.sh --remove  # remove launcher
# ──────────────────────────────────────────────────────────────

set -euo pipefail

LAUNCHER="$HOME/.claude/squirrel-auto-switch.sh"

if [ "${1:-}" = "--remove" ]; then
    rm -f "$LAUNCHER"
    echo "[ok] Removed: $LAUNCHER"
    exit 0
fi

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
