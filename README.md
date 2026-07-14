# desk-break

> A Claude Code skill for macOS: a recurring "get up and move" break reminder with random exercise cards, workout music, and streak tracking.

一个 Claude Code 技能(macOS 专用):按周期提醒你**离开电脑桌面动一动**,弹出随机运动卡片、播放锻炼音乐,还能连续打卡、检测你是否真的起身。用 `/desk-break` 一条命令引导配置。

## 特性

- ⏰ **定时提醒**:launchd 定时触发(默认每 30 分钟),重启后依旧生效。
- 😴 **智能跳过**:连续空闲 ≥ 15 分钟(你不在座位)自动跳过,不打扰。
- 🃏 **随机动作卡**:从 `moves.txt` 随机抽一张(拉伸 / 核心 / 腿 / 有氧 / 懒人 / 护眼),直接告诉你做什么。
- 🎭 **文案人格**:励志 / 搞笑 / 毒舌 三种语气随机切换(`phrases.txt`,可自定义)。
- 🌤️ **时段自适应**:早上拉伸、下午有氧、晚上放松;深夜自动切「该睡了」提醒。
- 🎵 **锻炼音乐**:通过 [music-cli](https://github.com/luongnv89/music-cli) 播放对应风格,运动窗口结束后自动停止。
- 🔥 **连续打卡**:提醒后观察空闲判断你是否真起身,记录 streak;连续忽略会升级提醒。
- 🗣️ **多种提醒方式**:强制弹窗 / 系统通知 / 语音朗读,可任意组合。

## 依赖

- **macOS**(用到 `launchd`、`ioreg`、`osascript`、`say`)。
- **[Claude Code](https://claude.com/claude-code)**(技能宿主)。
- **[music-cli](https://github.com/luongnv89/music-cli)**(可选;没装则跳过音乐,提醒照常)。

## 安装

把仓库直接克隆到 Claude Code 的技能目录:

```bash
git clone git@github.com:twillot-app/desk-break.git ~/.claude/skills/desk-break
```

然后在 Claude Code 里运行引导配置:

```
/desk-break setup
```

`setup` 会问你**周期 / 提醒方式 / 音乐风格 / 文案人格 / 动作卡 / 时段自适应**,写好配置并注册 launchd agent。

> 手动安装:也可把 `SKILL.md`、`reminder.sh`、`moves.txt`、`phrases.txt` 放到 `~/.claude/skills/desk-break/`,由 `setup` 负责把运行脚本装到 `~/.local/bin/`、数据装到 `~/.config/desk-break/`、注册 plist。

## 常用命令

| 命令 | 作用 |
|---|---|
| `/desk-break setup` | 交互式配置 + 安装 |
| `/desk-break status` | 查看运行状态、配置、最近日志 |
| `/desk-break test` | 立即触发一次(~8 秒快速演示,不计入战绩) |
| `/desk-break stats` | 查看连续打卡战绩 |
| `/desk-break disable` | 停用(保留文件) |
| `/desk-break uninstall` | 彻底移除 |

## 配置

所有偏好在 `~/.config/desk-break/config.env`,改完**下次触发即生效**(改周期需重跑 `setup` 重载 plist)。动作卡库 `moves.txt`、文案库 `phrases.txt` 也可自由增删。完整字段说明见 [`SKILL.md`](./SKILL.md) 的 *Config reference*。

## 工作原理

`setup` 生成一个 per-user launchd agent(`~/Library/LaunchAgents/com.<user>.desk-break.plist`),按 `StartInterval` 周期运行 `~/.local/bin/desk-break.sh`。脚本读取配置,检查空闲时间决定是否提醒,按需弹窗 / 朗读 / 放音乐,并把打卡数据写入 `~/.local/share/desk-break/stats.env`。

## 说明

- 仅支持在**本机运行的 Claude Code**;因为依赖 launchd 等本地能力,无法在 claude.ai 网页版或 API 云端运行。
- 弹窗文案通过 `osascript ... on run argv` 传递,中文 / emoji 不会乱码。

## License

[MIT](./LICENSE)
