---
description: Configure cc-squirrel-auto-switch statusline
allowed-tools: Bash, Read, Edit, AskUserQuestion
---

Configure settings.json so the statusline pipes squirrel-auto-switch before your display command.

## 1. Run install.sh

```bash
bash ${CLAUDE_PLUGIN_ROOT}/install.sh
```

This writes the version-aware launcher to `~/.claude/squirrel-auto-switch.sh`.

## 2. Read current settings.json

Read `~/.claude/settings.json` to get the existing `statusLine.command` value (if any).

If the file doesn't exist, create it with `{}`.

## 3. Build the new command

The launcher path is `bash $HOME/.claude/squirrel-auto-switch.sh`.

| Existing statusLine.command | New statusLine.command |
|---|---|
| (empty or missing) | `bash ~/.claude/squirrel-auto-switch.sh > /dev/null` |
| `bash ~/.claude/claude-hud.sh` | `bash ~/.claude/squirrel-auto-switch.sh \| bash ~/.claude/claude-hud.sh` |
| anything else | `bash ~/.claude/squirrel-auto-switch.sh \| <existing>` |

If the existing command already contains `squirrel-auto-switch.sh`, stop — already configured.

## 4. Ask the user if replacing an existing statusline

If there's an existing non-squirrel statusLine, use AskUserQuestion:

- header: "Existing statusline"
- question: "Found `{existing}`. Pipe squirrel-switch before it?"
- options: "Yes", "Replace", "Cancel"

If "Replace": set command to `bash ~/.claude/squirrel-auto-switch.sh > /dev/null`.
If "Cancel": stop.

## 5. Backup and write

Create a timestamped backup: `cp ~/.claude/settings.json ~/.claude/settings.json.bak.{timestamp}`.

Use Edit to write the new `statusLine`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "<new command>"
  }
}
```

## 6. Done

Tell the user to restart Claude Code. After restart: `i` → Chinese, `Esc` → ABC.
