# desk-break

> macOS「起身活动一下」休息提醒,为 AI 编程 agent 打造 —— 随机运动卡片、锻炼音乐、连续打卡。支持 **Claude Code**、**Codex**、**Cursor** 等。

[English](./README.md) · **中文**

一个 per-user 的 `launchd` 定时任务,按周期提醒你离开电脑桌面动一动。每次触发会先判断你是否真的在座位上,然后弹出随机运动卡片、播放锻炼音乐、记录连续打卡 —— 如果你已经离开,则保持安静不打扰。

## 特性

- ⏰ **定时提醒**:`launchd` 按周期触发(默认每 30 分钟),重启后依旧生效。
- 😴 **智能跳过**:空闲 ≥ 15 分钟(你不在座位)自动跳过。
- 🏋️ **无器材动作 + 动图演示**:259 个无器材动作按身体部位分类(来自 [exercises-dataset](https://github.com/hasaneyldrm/exercises-dataset)),点提醒上的**看示范**按钮才弹出动图 + 分步骤卡片;无媒体时回退到轻量文字卡(`moves.txt`)。
- 🎯 **关注部位**:自选想练的部位(核心 / 腿 / 背 / 胸 / 手臂 / 肩颈 / 有氧),优先推荐 —— 并做防重复,不会老是同一个。
- 🎭 **文案人格**:hype 励志 / funny 搞笑 / savage 毒舌,随机切换(`phrases.txt` 可改)。
- 💼 **行业针对性文案**:告诉它你的职业(开发、设计、产品、市场……),提醒更懂你。
- 🌶️ **升级 roast**:连续跳过越多,吐槽越狠。
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

作为插件安装后,命令都在 `desk-break:` 命名空间下。

| 命令 | 作用 |
|---|---|
| `/desk-break:setup` | 交互式配置 + 安装 |
| `/desk-break:status` | 状态、配置、最近日志 |
| `/desk-break:test` | 立即触发一次(~8 秒演示,不计入战绩) |
| `/desk-break:stats` | 连续打卡、完成率、最近 7 天图表 |
| `/desk-break:report` | 打开预填好的问题反馈邮件给维护者 |
| `/desk-break:disable` · `/desk-break:enable` | 停用 / 恢复 |
| `/desk-break:uninstall` | 移除定时任务和文件 |

`desk-break` 技能本身也可用 `/desk-break` 调用(引导式配置)。底层对应 `~/.local/bin/desk-break.sh [--test|--stats|--report "…"]` 与 `launchctl`。

## 配置

所有偏好在 `~/.config/desk-break/config.env`(下次触发即生效;改周期需重跑 `setup`)。动作卡与文案按语言放在 `~/.config/desk-break/i18n/<lang>/`。完整字段见 [`SKILL.md`](./plugins/desk-break/skills/desk-break/SKILL.md)。

常用:`LOCALE`(auto/en/zh)、`REMINDER_STYLE`、`MOOD`、`PERSONA`(hype/funny/savage/random/off)、`TIME_ADAPTIVE`、`NIGHT_MODE`、`TRACK_STATS`、`IDLE_LIMIT_SECONDS`、`MUSIC_SECONDS`、`REPORT_EMAIL`。

## 工作原理

`setup` 安装 `~/.local/bin/desk-break.sh` 和一个 launchd 定时任务(`~/Library/LaunchAgents/com.<user>.desk-break.plist`)按 `StartInterval` 运行。脚本解析语言、检查空闲、弹出提醒 / 放音乐,并把打卡数据写入 `~/.local/share/desk-break/`。

## 说明

- **仅 macOS + 本地**:依赖 launchd,无法在 claude.ai 网页版或 API 云端运行。
- 弹窗文案通过 `osascript … on run argv` 传递,中文 / emoji 不会乱码。

## 使用说明与文件位置

📖 完整使用说明:**[USAGE.zh-CN.md](./USAGE.zh-CN.md)** —— 提醒长什么样、连续打卡怎么算、关注部位、配置速查、常见问题。

所有数据都在本机(不上云):

- **日志 / 状态** —— `~/.local/share/desk-break/`:`reminder.log`(触发/结果)、`stats.env`(打卡汇总)、`history.log`(每次结果,`/stats` 数据源)、`recent.log`(防重复)、`card.html`(上次动图卡)。
- **配置 + 数据** —— `~/.config/desk-break/`:`config.env` 与 `i18n/<lang>/`(动作、人格、行业、roast、文字卡、界面文案)。
- **程序 / 定时任务** —— `~/.local/bin/desk-break.sh`、`~/Library/LaunchAgents/com.<user>.desk-break.plist`。

动图 / 图片**不存本地**,只有点「看示范」时才按 URL 加载。

## 数据与媒体来源

- **动作数据**(名称、部位、分步骤说明)是 **[hasaneyldrm/exercises-dataset](https://github.com/hasaneyldrm/exercises-dataset)**(MIT)的筛选子集,由 `tools/build-exercises.py` 生成。
- **演示动图/图片版权归 [Gym visual](https://gymvisual.com/)**,**未**打包进本仓库 —— desk-break 仅按 URL 引用,每张卡片标注署名,且**只有你点「看示范」时才会加载**(否则不发任何请求)。其使用受 [Gym visual 使用条款](https://gymvisual.com/content/3-terms-and-conditions-of-use)约束;按 URL 引用不等于获得授权。详见 [`DATA_NOTICE.md`](./plugins/desk-break/skills/desk-break/DATA_NOTICE.md)。

## License

[MIT](./LICENSE) © twillot —— 适用于 desk-break 自身代码。打包的动作**数据**为 MIT(见上方来源);演示**媒体**版权归 Gym visual,另行授权。
