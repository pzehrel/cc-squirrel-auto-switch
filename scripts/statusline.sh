#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# cc-squirrel-auto-switch  —  pipe filter for Claude Code statusline
#
# Reads the statusline JSON from stdin, switches Squirrel (Rime)
# input method based on `vim.mode`, then echoes the original JSON
# to stdout unchanged.  Designed to be chained with your actual
# statusline command via shell pipe:
#
#   bash squirrel-switch.sh | bash claude-hud.sh
#
# ---------------------------------------------------------------
# Installation  (~/.claude/settings.json)
#
#   "statusLine": {
#     "type": "command",
#     "command": "bash /path/to/cc-squirrel-auto-switch/scripts/statusline.sh | bash ~/.claude/claude-hud.sh"
#   }
#
# ---------------------------------------------------------------
# Environment variables (all prefixed CC_SQUIRREL_)
#
#   CC_SQUIRREL_DISABLE=1
#   CC_SQUIRREL_CLI=/path/to/Squirrel
#   CC_SQUIRREL_INPUT_SOURCE=im.rime.inputmethod.Squirrel.Hans
#   CC_SQUIRREL_AUTO_ACTIVATE=0|1       (default 1)
#   CC_SQUIRREL_DEFAULT_INSERT_STATE=ascii|nascii  (default nascii)
#   CC_SQUIRREL_STATE_FILE=/path        (default /tmp/cc-squirrel-switch.json)
# ──────────────────────────────────────────────────────────────

set -euo pipefail

# ── Configuration ────────────────────────────────────────────

SQUIRREL_CLI="${CC_SQUIRREL_CLI:-/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel}"
INPUT_SOURCE="${CC_SQUIRREL_INPUT_SOURCE:-im.rime.inputmethod.Squirrel.Hans}"
AUTO_ACTIVATE="${CC_SQUIRREL_AUTO_ACTIVATE:-1}"
DEFAULT_INSERT="${CC_SQUIRREL_DEFAULT_INSERT_STATE:-nascii}"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
STATE_DIR="${CC_SQUIRREL_STATE_DIR:-${TMPDIR:-/tmp}/cc-squirrel-auto-switch}"
STATE_FILE=""  # set per invocation based on session_id

# ── Helpers ──────────────────────────────────────────────────

squirrel()        { "$SQUIRREL_CLI" "$@" 2>/dev/null || true; }
squirrel_quiet()  { "$SQUIRREL_CLI" "$@" >/dev/null 2>&1 || true; }

get_state() {
    local s
    s=$(squirrel --getascii) || true
    case "$s" in
        ascii|nascii) echo "$s" ;;
        *) echo "nascii" ;;
    esac
}

set_state() {
    local target="$1"

    if [ "$AUTO_ACTIVATE" = "1" ]; then
        squirrel_quiet --select-input-source "$INPUT_SOURCE" || {
            squirrel_quiet --enable-input-source "$INPUT_SOURCE"
            squirrel_quiet --select-input-source "$INPUT_SOURCE"
        }
    fi

    case "$target" in
        ascii)  squirrel_quiet --ascii ;;
        nascii) squirrel_quiet --nascii ;;
        *) return 1 ;;
    esac
}

load_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE" 2>/dev/null || echo '{}'
    else
        echo '{}'
    fi
}

save_state() {
    local vim_mode="$1" insert_state="$2" now
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    now=$(date +%s)
    printf '{"lastVimMode":"%s","lastInsertState":"%s","updatedAt":%s}\n' \
        "$vim_mode" "$insert_state" "$now" > "$STATE_FILE"
}

# ── Main ─────────────────────────────────────────────────────

main() {
    # Read stdin once — we'll echo it back at the end.
    INPUT=$(cat)

    # Short-circuit if disabled or Squirrel CLI missing.
    if [ "${CC_SQUIRREL_DISABLE:-0}" = "1" ] || [ ! -x "$SQUIRREL_CLI" ]; then
        echo "$INPUT"
        return
    fi

    # Extract vim mode and session id.
    local vim_mode session_id
    vim_mode=$(echo "$INPUT" | jq -r '.vim.mode // empty' 2>/dev/null) || true
    if [ -z "$vim_mode" ]; then
        echo "$INPUT"
        return
    fi

    session_id=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null) || true
    STATE_FILE="${CC_SQUIRREL_STATE_FILE:-${STATE_DIR}/state_${session_id:-default}.json}"

    # Load previous state.
    local prev last_mode last_insert
    prev=$(load_state)
    last_mode=$(echo "$prev" | jq -r '.lastVimMode // empty' 2>/dev/null) || true
    last_insert=$(echo "$prev" | jq -r '.lastInsertState // empty' 2>/dev/null) || true
    if [ "$last_insert" != "ascii" ] && [ "$last_insert" != "nascii" ]; then
        last_insert="$DEFAULT_INSERT"
    fi

    # ── State machine ─────────────────────────────────────────

    local need_english=0 need_insert=0

    case "$vim_mode" in
        NORMAL|VISUAL|"VISUAL LINE"|COMMAND) need_english=1 ;;
        INSERT|REPLACE)                      need_insert=1  ;;
        *)                                   need_english=1 ;;  # unknown → safe
    esac

    if [ "$vim_mode" != "$last_mode" ]; then
        if [ "$need_english" -eq 1 ]; then
            # ── Entering non-insert mode ─────────────────────
            case "$last_mode" in
                INSERT|REPLACE) last_insert=$(get_state) ;;
            esac
            set_state ascii
            save_state "$vim_mode" "$last_insert"

        elif [ "$need_insert" -eq 1 ]; then
            # ── Entering insert mode ─────────────────────────
            set_state "$last_insert"
            save_state "$vim_mode" "$last_insert"
        fi
    fi

    # Always echo the original JSON — this script is a filter.
    echo "$INPUT"
}

main
