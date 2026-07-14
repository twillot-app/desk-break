# desk-break

> macOS「起身活动一下」休息提醒,为 AI 编程 agent 打造 —— 随机运动卡片、锻炼音乐、连续打卡。支持 **Claude Code**、**Codex**、**Cursor** 等。

[English](./README.md) · **中文**

一个 per-user 的 `launchd` 定时任务,按周期提醒你离开电脑桌面动一动。每次触发会先判断你是否真的在座位上,然后弹出随机运动卡片、播放锻炼音乐、记录连续打卡 —— 如果你已经离开,则保持安静不打扰。

## 特性

- ⏰ **定时提醒**:`launchd` 按周期触发(默认每 30 分钟),重启后依旧生效。
- 😴 **智能跳过**:空闲 ≥ 15 分钟(你不在座位)自动跳过。
- 🃏 **随机动作卡**:从 `moves.txt` 抽取(拉伸 / 核心 / 腿 / 有氧 / 懒人 / 护眼)。
- 🎭 **文案人格**:hype 励志 / funny 搞笑 / savage 毒舌,随机切换(`phrases.txt` 可改)。
- 🌤️ **时段自适应**:早上拉伸、下午有氧、晚上放松;深夜自动切「该睡了」提醒。
- 🎵 **锻炼音乐**:通过 [music-cli](https://github.com/luongnv89/music-cli) 播放,运动窗口结束后自动停止。
- 🔥 **连续打卡**:提醒后观察空闲判断你是否真起身,连续忽略会升级提醒。
- 🗣️ **提醒方式**:强制弹窗 / 系统通知 / 语音朗读,可任意组合。
- 🌐 **国际化**:中文 + 英文,按系统语言自动选择。

## 依赖

- **macOS**(用到 `launchd`、`ioreg`、`osascript`、`say`)。
- 一个 agent 宿主 —— **[Claude Code](https://claude.com/claude-code)**(体验最完整),或 **Codex / Cursor / 其他**(见[其他 agent](#其他-agent))。
- **[music-cli](https://github.com/luongnv89/music-cli)**(可选;没装则跳过音乐,提醒照常)。

## 安装

### Claude Code —— 插件市场(推荐)

```
/plugin marketplace add twillot-app/desk-break
/plugin install desk-break@twillot
/desk-break setup
```

`setup` 会引导你选择语言、周期、提醒方式、音乐、人格以及好玩包开关,然后注册 launchd 定时任务。

### 其他 agent

技能本体就是 shell 脚本 + 数据文件,任何 agent 都能驱动。见 [`AGENTS.md`](./AGENTS.md)(Codex 等会读取)和 [`.cursor/rules/desk-break.mdc`](./.cursor/rules/desk-break.mdc)(Cursor)。手动安装:

```bash
install -m 0755 plugins/desk-break/skills/desk-break/reminder.sh ~/.local/bin/desk-break.sh
mkdir -p ~/.config/desk-break/i18n
cp -Rn plugins/desk-break/skills/desk-break/i18n/. ~/.config/desk-break/i18n/
# 再创建 ~/.config/desk-break/config.env 和 launchd plist —— 见 AGENTS.md / SKILL.md
```

## 命令

| 命令 | 作用 |
|---|---|
| `/desk-break setup` | 交互式配置 + 安装 |
| `/desk-break status` | 状态、配置、最近日志 |
| `/desk-break test` | 立即触发一次(~8 秒演示,不计入战绩) |
| `/stats` | 连续打卡、完成率、最近 7 天图表 |
| `/report` | 打开预填好的问题反馈邮件给维护者 |
| `/desk-break disable` · `uninstall` | 停用 / 移除 |

底层都对应 `~/.local/bin/desk-break.sh [--test|--stats|--report "…"]`。

## 配置

所有偏好在 `~/.config/desk-break/config.env`(下次触发即生效;改周期需重跑 `setup`)。动作卡与文案按语言放在 `~/.config/desk-break/i18n/<lang>/`。完整字段见 [`SKILL.md`](./plugins/desk-break/skills/desk-break/SKILL.md)。

常用:`LOCALE`(auto/en/zh)、`REMINDER_STYLE`、`MOOD`、`PERSONA`(hype/funny/savage/random/off)、`TIME_ADAPTIVE`、`NIGHT_MODE`、`TRACK_STATS`、`IDLE_LIMIT_SECONDS`、`MUSIC_SECONDS`、`REPORT_EMAIL`。

## 工作原理

`setup` 安装 `~/.local/bin/desk-break.sh` 和一个 launchd 定时任务(`~/Library/LaunchAgents/com.<user>.desk-break.plist`)按 `StartInterval` 运行。脚本解析语言、检查空闲、弹出提醒 / 放音乐,并把打卡数据写入 `~/.local/share/desk-break/`。

## 说明

- **仅 macOS + 本地**:依赖 launchd,无法在 claude.ai 网页版或 API 云端运行。
- 弹窗文案通过 `osascript … on run argv` 传递,中文 / emoji 不会乱码。

## License

[MIT](./LICENSE) © twillot
