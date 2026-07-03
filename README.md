# cc-squirrel-auto-switch

[中文](./README.zh.md)

Claude Code plugin: auto-switch Squirrel (鼠须管 / Rime) input method based on vim mode.

- **NORMAL / VISUAL** → ABC (English) — so `h` `j` `k` `l` and shortcuts work
- **INSERT / REPLACE** → restores your last Chinese/English preference

## How it works

The script acts as a **pipe filter**: reads the statusline JSON from stdin, switches Squirrel, then echoes the original JSON to stdout. Chain it with any statusline command via `|`:

```
CC statusline JSON → squirrel-switch.sh → your statusline → display
```

A **launcher** (`~/.claude/squirrel-auto-switch.sh`) dynamically finds the latest installed version, so plugin updates are picked up automatically.

## Install

### 1. Add marketplace (once)

```
/marketplace add https://github.com/pzehrel/cc-squirrel-auto-switch
```

### 2. Install the plugin

Open `/plugins`, find **cc-squirrel-auto-switch**, install.

### 3. Run setup

```
/cc-squirrel-auto-switch:setup
```

This generates the launcher, backs up your `settings.json`, and configures the statusline. Restart Claude Code afterwards.

### Coexistence with your statusline

Setup pipes squirrel-switch **before** your existing statusline. If you use claude-hud, the final command becomes:

```
bash ~/.claude/squirrel-auto-switch.sh | bash ~/.claude/claude-hud.sh
```

Any statusline works:
```
bash squirrel-auto-switch.sh | bash claude-hud.sh
bash squirrel-auto-switch.sh | bash my-statusline.sh
bash squirrel-auto-switch.sh | jq -r '"[\(.model.display_name)] \(.vim.mode)"'
bash squirrel-auto-switch.sh > /dev/null
```

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CC_SQUIRREL_DISABLE` | (unset) | Set to `1` to disable |
| `CC_SQUIRREL_CLI` | `/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel` | Squirrel binary path |
| `CC_SQUIRREL_INPUT_SOURCE` | `im.rime.inputmethod.Squirrel.Hans` | macOS input source ID |
| `CC_SQUIRREL_AUTO_ACTIVATE` | `1` | Activate Squirrel input source before switching |
| `CC_SQUIRREL_DEFAULT_INSERT_STATE` | `nascii` | Default insert state (`ascii` or `nascii`) |
| `CC_SQUIRREL_STATE_FILE` | `~/.claude/plugins/cc-squirrel-auto-switch/state.json` | Persistent state |

## Requirements

- macOS
- [Squirrel](https://github.com/rime/squirrel)
- [jq](https://jqlang.github.io/jq/)
- Claude Code with `editorMode: vim`

## Behavior

```
NORMAL / VISUAL / COMMAND  →  force --ascii (English)
INSERT / REPLACE           →  restore last INSERT preference
same mode                  →  do nothing (respect manual switches)
```

When leaving INSERT mode, the script queries `--getascii` to remember your current state, then switches to English. The saved preference is restored the next time you enter INSERT.

## Releasing

```bash
# 1. Update version
jq '.version = "0.2.0"' .claude-plugin/plugin.json > tmp && mv tmp .claude-plugin/plugin.json
jq '.metadata.version = "0.2.0"' marketplace.json > tmp && mv tmp marketplace.json

# 2. Commit, tag, push
git add .claude-plugin/plugin.json marketplace.json
git commit -m "bump v0.2.0"
git tag v0.2.0
git push origin main --tags
```

Pushing the tag triggers the Release workflow — it verifies version consistency, then creates a GitHub Release with auto-generated notes.

## Related

- Neovim counterpart: [squirrel-auto-switch.nvim](https://github.com/pzehrel/squirrel-auto-switch.nvim)

## License

MIT
