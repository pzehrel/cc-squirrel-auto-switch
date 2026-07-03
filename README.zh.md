# cc-squirrel-auto-switch

[English](./README.md)

Claude Code 插件：根据 vim 模式自动切换 Squirrel（鼠须管 / Rime）输入法。

- **NORMAL / VISUAL** → ABC 英文 — 确保 `h` `j` `k` `l` 和快捷键不被中文输入法拦截
- **INSERT / REPLACE** → 恢复你上次编辑时使用的中/英文偏好

## 原理

脚本是一个 **pipe filter**：从 stdin 读取 statusline JSON → 处理 Squirrel 切换 → 原样输出 JSON 到 stdout。用 `|` 和任何 statusline 命令串联：

```
CC statusline JSON → squirrel-switch.sh → 你的 statusline → 显示
```

**Launcher**（`~/.claude/squirrel-auto-switch.sh`）动态找到最新安装版本，插件更新后自动生效。

## 安装

### 1. 添加市场（只需一次）

```
/marketplace add https://github.com/pzehrel/cc-squirrel-auto-switch
```

### 2. 安装插件

打开 `/plugins`，找到 **cc-squirrel-auto-switch**，安装。

### 3. 运行 Setup

```
/cc-squirrel-auto-switch:setup
```

Setup 会生成 launcher、备份 `settings.json`、配置 statusline。完成后重启 Claude Code。

### 与已有 statusline 共存

Setup 会把 squirrel-switch pipe 在你现有 statusline **前面**。如果使用 claude-hud，最终命令是：

```
bash ~/.claude/squirrel-auto-switch.sh | bash ~/.claude/claude-hud.sh
```

任意 statusline 都可以：
```
bash squirrel-auto-switch.sh | bash claude-hud.sh
bash squirrel-auto-switch.sh | bash my-statusline.sh
bash squirrel-auto-switch.sh | jq -r '"[\(.model.display_name)] \(.vim.mode)"'
bash squirrel-auto-switch.sh > /dev/null
```

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `CC_SQUIRREL_DISABLE` | (空) | 设为 `1` 禁用 |
| `CC_SQUIRREL_CLI` | `/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel` | Squirrel 可执行文件路径 |
| `CC_SQUIRREL_INPUT_SOURCE` | `im.rime.inputmethod.Squirrel.Hans` | macOS 输入源 ID |
| `CC_SQUIRREL_AUTO_ACTIVATE` | `1` | 切换前先激活 Squirrel 输入源 |
| `CC_SQUIRREL_DEFAULT_INSERT_STATE` | `nascii` | 首次进入 INSERT 的默认状态（`ascii` 或 `nascii`） |
| `CC_SQUIRREL_STATE_FILE` | `~/.claude/plugins/cc-squirrel-auto-switch/state.json` | 持久状态文件 |

## 依赖

- macOS
- [Squirrel（鼠须管）](https://github.com/rime/squirrel)
- [jq](https://jqlang.github.io/jq/)
- Claude Code（`editorMode: vim`）

## 行为逻辑

```
NORMAL / VISUAL / COMMAND  →  强制 --ascii（英文）
INSERT / REPLACE           →  恢复上次离开 INSERT 时的偏好
同一模式内                  →  不操作（尊重用户手动切换）
```

退出 INSERT 时，会先通过 `--getascii` 查询当前状态并记忆，再切换到英文。下次进入 INSERT 时恢复。

## 发布流程

```bash
# 1. 更新版本号
jq '.version = "0.2.0"' .claude-plugin/plugin.json > tmp && mv tmp .claude-plugin/plugin.json
jq '.metadata.version = "0.2.0"' marketplace.json > tmp && mv tmp marketplace.json

# 2. 提交、打 tag、推送
git add .claude-plugin/plugin.json marketplace.json
git commit -m "bump v0.2.0"
git tag v0.2.0
git push origin main --tags
```

推送 tag 会触发 Release CI —— 验证版本一致性，然后自动生成 GitHub Release。

## 同类项目

- Neovim 版：[squirrel-auto-switch.nvim](https://github.com/pzehrel/squirrel-auto-switch.nvim)

## License

MIT
