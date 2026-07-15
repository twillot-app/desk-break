# desk-break

[![npm version](https://img.shields.io/npm/v/desk-break?logo=npm&color=cb3837)](https://www.npmjs.com/package/desk-break)
[![node](https://img.shields.io/node/v/desk-break?logo=node.js&logoColor=white)](https://www.npmjs.com/package/desk-break)
[![license: MIT](https://img.shields.io/npm/l/desk-break?color=blue)](./LICENSE)
[![platform: macOS](https://img.shields.io/badge/platform-macOS-000000?logo=apple&logoColor=white)](#依赖)

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
- 一个 agent 宿主 —— **[Claude Code](https://claude.com/claude-code)**(体验最完整),或 **Codex / Cursor / 其他**(见[安装](#安装))。完全不用 agent?`npx desk-break` CLI 也能直接装。
- **[music-cli](https://github.com/luongnv89/music-cli)**(可选;没装则跳过音乐,提醒照常)。

## 安装

### Claude Code —— 插件市场(推荐)

```
/plugin marketplace add twillot-app/desk-break
/plugin install desk-break@twillot
/desk-break setup
```

`setup` 会引导你选择语言、周期、提醒方式、音乐、人格以及好玩包开关,然后注册 launchd 定时任务。

### Codex —— 一条命令

无需 clone 仓库 —— 已发布的 npm CLI 会完成整套安装(拷贝运行脚本 + 本地化数据、写配置、注册 launchd 定时任务,并试跑一次):

```bash
npx desk-break setup
# 选项:--interval 45  --locale auto|en|zh  --style dialog|notification|say|dialog+say  --no-music
npx desk-break setup --dry-run   # 预览每一步,什么都不改
```

把 Codex 指向本仓库时,它会读取 [`AGENTS.md`](./AGENTS.md),于是你也能用对话方式驱动 setup/status/stats。日常:`npx desk-break test | stats | disable | enable | uninstall`。

### Cursor 及其他 agent

技能本体就是 shell 脚本 + 数据文件,任何 agent 都能驱动。Cursor 读 [`.cursor/rules/desk-break.mdc`](./.cursor/rules/desk-break.mdc),其他 agent 读 [`AGENTS.md`](./AGENTS.md)。或者直接用上面的 `npx desk-break setup`。

### 手动安装(从仓库检出)

```bash
install -m 0755 skills/health/desk-break/reminder.sh ~/.local/bin/desk-break.sh
mkdir -p ~/.config/desk-break/i18n
cp -Rn skills/health/desk-break/i18n/. ~/.config/desk-break/i18n/
# 再创建 ~/.config/desk-break/config.env 和 launchd plist —— 见 AGENTS.md / SKILL.md
```

## 使用

### 一次提醒长什么样

到点触发时(除非你已空闲 ≥ 15 分钟,判定不在座位则静默跳过):

1. **弹窗**:标题 + 一句文案(人格 / 行业 / roast)+ 动作名,两个按钮:
   - **知道了** — 关闭。
   - **看示范** — 打开浏览器动图卡(动图 + 分步骤 + © Gym visual 署名)。**点了才加载,不点不联网**。
2. **语音**朗读(若开了 `say`)。
3. **锻炼音乐**播放约 5 分钟后自动停(若 `ENABLE_MUSIC=1`)。
4. 之后进入观察窗口,「悄悄」判断你是否真的离开了桌面。

### 连续打卡怎么算

- 提醒后有个**观察窗口**(`DETECT_WINDOW`,默认 180 秒)。
- 若你键鼠**连续空闲**达到 `COMPLETE_IDLE`(默认 90 秒)→ 记「**完成一次**」→ 🔥 连续打卡 +1,弹「✅ 完成!」。
- 若你一直在用电脑 → 记「**忽略**」,连续忽略累加。
- ⚠️ **关键**:必须「真的离开」—— 期间碰一下键鼠就会**重置空闲计时**。所以**边操作电脑边测,必然算忽略**。
- 连续忽略达到 `ESCALATE_AFTER`(默认 3)次 → 提醒**升级**:强制弹窗 + 语音 + 更燃音乐 + **逐级加狠的 roast**(档 1→2→3)。
- 战绩随时查:`/desk-break:stats`(或 `npx desk-break stats`)。

### 关注部位 & 防重复

- `FOCUS_PARTS` 选想练的部位:`core`(核心/腰)、`legs`(腿/臀)、`back`(背)、`chest`(胸)、`arms`(手臂)、`shoulders`(肩颈)、`cardio`(有氧)。
- 关注部位优先(概率 ×`FOCUS_WEIGHT`,默认 3),但连续 `FOCUS_COOLDOWN`(默认 2)次后**强制换非关注**,避免老练同一块。
- 最近 `EXERCISE_RECENT_K`(默认 6)个动作**不重复**。
- 动作全部为**无器材**(259 个,已剔除需单杠/长凳/吊环/悬挂带等的)。臀部动作在数据集里归 `legs` 组。

### 时段自适应 & 深夜

- `TIME_ADAPTIVE=1`:早上 happy、下午 excited、晚上 relaxed(会**覆盖**固定的 `MOOD`)。
- 深夜(`NIGHT_HOUR` 之后,默认 23 点)自动切「🌙 该休息了」,不出运动 / 音乐 / 打卡。

## 命令

作为插件安装后,命令都在 `desk-break:` 命名空间下。用 npm CLI 时,同样的操作是 `npx desk-break <命令>`。

| 插件命令 | `npx` 等价 | 作用 |
|---|---|---|
| `/desk-break:setup` | `npx desk-break setup` | 交互式配置 + 安装 |
| `/desk-break:status` | — | 状态、配置、最近日志 |
| `/desk-break:test` | `npx desk-break test` | 立即触发一次(~8 秒演示,不计入战绩) |
| `/desk-break:stats` | `npx desk-break stats` | 连续打卡、完成率、最近 7 天图表 |
| `/desk-break:report` | `npx desk-break report "…"` | 打开预填好的问题反馈邮件 |
| `/desk-break:disable` · `enable` | `npx desk-break disable` · `enable` | 停用 / 恢复 |
| `/desk-break:uninstall` | `npx desk-break uninstall [--purge]` | 移除定时任务和文件 |

`desk-break` 技能本身也可用 `/desk-break` 调用(引导式配置)。底层都对应 `~/.local/bin/desk-break.sh [--test|--stats|--report "…"]` 与 `launchctl`。

## 配置

所有偏好在 `~/.config/desk-break/config.env`(下次触发即生效;**改周期**需重跑 `setup`)。动作卡与文案按语言放在 `~/.config/desk-break/i18n/<lang>/`。完整字段见 [`SKILL.md`](./skills/health/desk-break/SKILL.md)。

| 配置 | 默认 | 作用 |
|---|---|---|
| `LOCALE` | auto | 语言:auto(跟随系统)/ zh / en |
| `REMINDER_STYLE` | dialog | dialog / notification / say 任意组合 |
| `ENABLE_MUSIC` / `MOOD` | 1 / energetic | 是否放音乐 / 风格(TIME_ADAPTIVE=1 时被覆盖) |
| `IDLE_LIMIT_SECONDS` | 900 | 空闲 ≥ 此秒数则跳过(你不在) |
| `MUSIC_SECONDS` | 300 | 音乐 / 运动窗口时长 |
| `PERSONA` | random | hype / funny / savage / random / off |
| `TIME_ADAPTIVE` | 1 | 按时段切 mood + 倾向 |
| `NIGHT_MODE` / `NIGHT_HOUR` | 1 / 23 | 深夜切「该睡了」 |
| `TRACK_STATS` / `DETECT_WINDOW` / `COMPLETE_IDLE` | 1 / 180 / 90 | 打卡与完成检测 |
| `ESCALATE` / `ESCALATE_AFTER` | 1 / 3 | 连续忽略后升级 + roast |
| `FOCUS_PARTS` / `FOCUS_WEIGHT` / `FOCUS_COOLDOWN` | 空 / 3 / 2 | 关注部位与优先 |
| `EXERCISE_RECENT_K` | 6 | 最近 K 个动作不重复 |
| `INDUSTRY` | none | dev/design/pm/marketing/writing/sales/finance/student |
| `REPORT_EMAIL` | 维护者 | `/report` 收件人 |

数据文件(可自行增删):`~/.config/desk-break/i18n/<lang>/` 下的 `exercises.tsv`(动作)、`phrases.txt`(人格)、`industry.txt`(行业)、`roast.txt`(升级)、`moves.txt`(文字回退)、`strings.env`(界面文案)。

## 工作原理

`setup` 安装 `~/.local/bin/desk-break.sh` 和一个 launchd 定时任务(`~/Library/LaunchAgents/com.<user>.desk-break.plist`)按 `StartInterval` 运行。脚本解析语言、检查空闲、弹出提醒 / 放音乐,并把打卡数据写入 `~/.local/share/desk-break/`。

## 数据与文件位置

所有数据都在本机(不上云)。

**运行状态 / 日志:`~/.local/share/desk-break/`**

| 文件 | 内容 |
|---|---|
| `reminder.log` | 主日志:每次触发 / 跳过 / 结果 / 音乐 / 错误 |
| `stats.env` | 打卡汇总:连续天数、最佳、今日/累计、当前连续忽略 |
| `history.log` | 每次结果一行(`日期⇥时间⇥completed/ignored⇥动作`),`/stats` 图表来源 |
| `recent.log` | 最近抽到的动作(防重复) |
| `card.html` | 上次「看示范」生成的动图卡(会被覆盖) |
| `stdout.log` / `stderr.log` | launchd 标准输出 / 错误 |

**配置 + 数据** —— `~/.config/desk-break/`:`config.env` 与 `i18n/<lang>/…`
**程序 / 定时任务** —— `~/.local/bin/desk-break.sh`、`~/Library/LaunchAgents/com.<user>.desk-break.plist`

> 动图 / 图片**不存本地**,只有点「看示范」时才按 URL 加载(© Gym visual)。

## 常见问题

- **为什么总记成「忽略」?** 观察窗口内你的连续空闲没到 90 秒,或你一直在碰键鼠(碰一下就清零)。要打卡成功就**真的走开** 90 秒以上。
- **太吵 / 不想放音乐?** `ENABLE_MUSIC=0`(或 `npx desk-break setup --no-music`)。
- **不想每次开浏览器?** 不点「看示范」就不会开;它是可选的。
- **临时不想被打扰?** `/desk-break:disable`(或 `npx desk-break disable`),回头 `enable`。
- **改了配置多久生效?** 下次触发即生效;唯独**改周期**要重跑 `setup`。
- **动图打不开?** 需要联网(raw.githubusercontent);断网只显示步骤文字。
- **想只练臀 / 更细的肌群?** 目前按大部位(数据集粒度),暂不支持 target 级(如 glutes)细分。
- **彻底卸载?** `/desk-break:uninstall`(或 `npx desk-break uninstall --purge`)。

## 说明

- **仅 macOS + 本地**:依赖 launchd,无法在 claude.ai 网页版或 API 云端运行。
- 弹窗文案通过 `osascript … on run argv` 传递,中文 / emoji 不会乱码。

## 数据与媒体来源

- **动作数据**(名称、部位、分步骤说明)是 **[hasaneyldrm/exercises-dataset](https://github.com/hasaneyldrm/exercises-dataset)**(MIT)的筛选子集,由 `tools/build-exercises.py` 生成。
- **演示动图/图片版权归 [Gym visual](https://gymvisual.com/)**,**未**打包进本仓库 —— desk-break 仅按 URL 引用,每张卡片标注署名,且**只有你点「看示范」时才会加载**(否则不发任何请求)。其使用受 [Gym visual 使用条款](https://gymvisual.com/content/3-terms-and-conditions-of-use)约束;按 URL 引用不等于获得授权。详见 [`DATA_NOTICE.md`](./skills/health/desk-break/DATA_NOTICE.md)。

## License

[MIT](./LICENSE) © twillot —— 适用于 desk-break 自身代码。打包的动作**数据**为 MIT(见上方来源);演示**媒体**版权归 Gym visual,另行授权。
