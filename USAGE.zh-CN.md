# desk-break 使用说明

[English](./USAGE.md) · **中文**

久坐提醒助手:每隔一段时间提醒你起身活动,弹出**无器材动作 + 动图演示**,并记录**连续打卡**。本文讲怎么用;完整字段参考见 [`SKILL.md`](./plugins/desk-break/skills/desk-break/SKILL.md)。

## 快速开始

Claude Code:

```
/plugin marketplace add twillot-app/desk-break
/plugin install desk-break@twillot
/desk-break:setup
```

`setup` 会引导你选:**语言 / 周期 / 提醒方式 / 音乐 / 人格 / 关注部位 / 行业**,然后注册 launchd 定时任务(重启后依旧生效)。

## 一次提醒长什么样

到点触发时(除非你已空闲 ≥ 15 分钟,判定不在座位则静默跳过):

1. **弹窗**:标题 + 一句文案(人格 / 行业 / roast)+ 动作名,两个按钮:
   - **知道了** — 关闭
   - **看示范** — 打开浏览器动图卡(动图 + 分步骤 + © Gym visual 署名)。**点了才加载,不点不联网**。
2. **语音**朗读(若开了 `say`)。
3. **锻炼音乐**播放约 5 分钟后自动停(若 `ENABLE_MUSIC=1`)。
4. 之后进入观察窗口,"悄悄"判断你是否真的离开了桌面。

## 连续打卡怎么算

- 提醒后有个**观察窗口**(`DETECT_WINDOW`,默认 180 秒)。
- 若你键鼠**连续空闲**达到 `COMPLETE_IDLE`(默认 90 秒)→ 记「**完成一次**」→ 🔥 连续打卡 +1,弹「✅ 完成!」。
- 若你一直在用电脑 → 记「**忽略**」,连续忽略累加。
- ⚠️ **关键**:必须"真的离开"—— 期间碰一下键鼠就会**重置空闲计时**。所以**边操作电脑边测,必然算忽略**。
- 连续忽略达到 `ESCALATE_AFTER`(默认 3)次 → 提醒**升级**:强制弹窗 + 语音 + 更燃音乐 + **逐级加狠的 roast**(档 1→2→3)。
- 战绩随时查:`/desk-break:stats`(连续天数、完成率、最近 7 天柱状图)。

## 关注部位 & 防重复

- `FOCUS_PARTS` 选想练的部位:`core`(核心/腰)、`legs`(腿/臀)、`back`(背)、`chest`(胸)、`arms`(手臂)、`shoulders`(肩颈)、`cardio`(有氧)。
- 关注部位优先(概率 ×`FOCUS_WEIGHT`,默认 3),但连续 `FOCUS_COOLDOWN`(默认 2)次后**强制换非关注**,避免老练同一块。
- 最近 `EXERCISE_RECENT_K`(默认 6)个动作**不重复**。
- 动作全部为**无器材**(259 个,已剔除需单杠/长凳/吊环/悬挂带等的)。臀部动作在数据集里归 `legs` 组。

## 时段自适应 & 深夜

- `TIME_ADAPTIVE=1`:早上 happy、下午 excited、晚上 relaxed(会**覆盖**固定的 `MOOD`)。
- 深夜(`NIGHT_HOUR` 之后,默认 23 点)自动切「🌙 该休息了」,不出运动 / 音乐 / 打卡。

## 常用命令

| 命令 | 作用 |
|---|---|
| `/desk-break:setup` | 交互式配置 + 安装 |
| `/desk-break:status` | 状态、当前配置、最近日志 |
| `/desk-break:test` | 立即触发一次(~8 秒演示,不计入战绩) |
| `/desk-break:stats` | 连续打卡、完成率、最近 7 天图表 |
| `/desk-break:report` | 打开预填好的问题反馈邮件 |
| `/desk-break:disable` · `/desk-break:enable` | 临时停用 / 恢复 |
| `/desk-break:uninstall` | 彻底移除 |

## 配置速查(`~/.config/desk-break/config.env`,改完下次触发即生效;改周期需重跑 setup)

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

## 数据与文件位置(都在本机,不上云)

**运行状态 / 日志:`~/.local/share/desk-break/`**

| 文件 | 内容 |
|---|---|
| `reminder.log` | 主日志:每次触发 / 跳过 / 结果 / 音乐 / 错误 |
| `stats.env` | 打卡汇总:连续天数、最佳、今日/累计、当前连续忽略 |
| `history.log` | 每次结果一行(`日期⇥时间⇥completed/ignored⇥动作`),`/stats` 图表来源 |
| `recent.log` | 最近抽到的动作(防重复) |
| `card.html` | 上次「看示范」生成的动图卡(会被覆盖) |
| `stdout.log` / `stderr.log` | launchd 标准输出 / 错误 |

**配置 + 数据:`~/.config/desk-break/`**(`config.env` + `i18n/<lang>/…`)
**程序 / 定时任务**:`~/.local/bin/desk-break.sh`、`~/Library/LaunchAgents/com.<user>.desk-break.plist`

> 动图 / 图片**不存本地**,是点「看示范」时按 URL 临时加载的(© Gym visual)。

## 常见问题

- **为什么总记成"忽略"?** 观察窗口内你的连续空闲没到 90 秒,或你一直在碰键鼠(碰一下就清零)。要打卡成功就**真的走开** 90 秒以上。
- **太吵 / 不想放音乐?** `ENABLE_MUSIC=0`。
- **不想每次开浏览器?** 不点「看示范」就不会开;它是可选的。
- **临时不想被打扰?** `/desk-break:disable`,回头 `/desk-break:enable`。
- **改了配置多久生效?** 下次触发即生效;唯独**改周期**要重跑 `/desk-break:setup` 重载。
- **动图打不开?** 需要联网(raw.githubusercontent);断网只显示步骤文字。
- **想只练臀 / 更细的肌群?** 目前按大部位(数据集粒度),暂不支持 target 级(如 glutes)细分。
- **彻底卸载?** `/desk-break:uninstall`。
