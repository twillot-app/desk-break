# desk-break

> A macOS "get up and move" break reminder for AI coding agents — random exercise cards, workout music, and streak tracking. Works with **Claude Code**, **Codex**, **Cursor**, and more.

**English** · [中文](./README.zh-CN.md)

A per-user `launchd` agent reminds you to leave the desk and move on an interval. Each time it fires, it checks whether you're actually at the keyboard, then pops a reminder with a random exercise card, plays workout music, and tracks your streak — unless you've stepped away, in which case it stays quiet.

## Features

- ⏰ **Interval reminders** via `launchd` (default every 30 min); survives reboots.
- 😴 **Smart skip**: idle ≥ 15 min (you're away) → skips silently.
- 🏋️ **No-equipment exercises with animated demos**: 259 no-equipment moves by body part (from [exercises-dataset](https://github.com/hasaneyldrm/exercises-dataset)). Click the **See demo** button on the reminder to open a browser card with an animation GIF + step-by-step instructions. Falls back to lightweight text cards (`moves.txt`).
- 🎯 **Body-part focus**: pick the parts you want to work (core / legs / back / chest / arms / shoulders / cardio); they get priority — with anti-repetition so it never gets monotonous.
- 🎭 **Copy personas**: hype / funny / savage, picked at random (editable in `phrases.txt`).
- 💼 **Industry-flavored copy**: tell it your role (dev, design, PM, marketing, …) for reminders that speak your language.
- 🌶️ **Escalating roast**: skip too many in a row and the nudges get progressively more savage.
- 🌤️ **Time-adaptive**: stretch in the morning, cardio in the afternoon, wind-down in the evening; a **night mode** switches to a "go to sleep" nudge.
- 🎵 **Workout music** via [music-cli](https://github.com/luongnv89/music-cli), auto-stopped after the exercise window.
- 🔥 **Streak tracking** with completion detection (watches idle after the reminder); escalates after repeated ignores.
- 🗣️ **Reminder styles**: forced dialog / notification / spoken — combine freely.
- 🌐 **i18n**: English + 中文, auto-detected from your system locale.

## Requirements

- **macOS** (uses `launchd`, `ioreg`, `osascript`, `say`).
- An agent host — **[Claude Code](https://claude.com/claude-code)** (richest experience), or **Codex / Cursor / others** (see [Install](#install)). No agent at all? The `npx desk-break` CLI installs it directly.
- **[music-cli](https://github.com/luongnv89/music-cli)** (optional; without it, reminders still fire and music is skipped).

## Install

### Claude Code — plugin marketplace (recommended)

```
/plugin marketplace add twillot-app/desk-break
/plugin install desk-break@twillot
/desk-break setup
```

`setup` walks you through language, interval, reminder style, music, persona, and the fun-pack toggles, then registers the launchd agent.

### Codex — one command

There's no repo checkout to manage — the published npm CLI does the whole install (copy the runner + localized data, write config, register the launchd agent, and fire a test):

```bash
npx desk-break setup
# options: --interval 45  --locale auto|en|zh  --style dialog|notification|say|dialog+say  --no-music
npx desk-break setup --dry-run   # preview every step, change nothing
```

When you point Codex at this repo, it reads [`AGENTS.md`](./AGENTS.md) so you can also drive setup/status/stats conversationally. Day-to-day: `npx desk-break test | stats | disable | enable | uninstall`.

### Cursor & other agents

The skill is plain shell + data, so any agent can drive it. Cursor reads [`.cursor/rules/desk-break.mdc`](./.cursor/rules/desk-break.mdc); other agents read [`AGENTS.md`](./AGENTS.md). Or just use `npx desk-break setup` as above.

### Manual (from a repo checkout)

```bash
install -m 0755 skills/health/desk-break/reminder.sh ~/.local/bin/desk-break.sh
mkdir -p ~/.config/desk-break/i18n
cp -Rn skills/health/desk-break/i18n/. ~/.config/desk-break/i18n/
# then create ~/.config/desk-break/config.env and a launchd plist — see AGENTS.md / SKILL.md
```

## Usage

### What a reminder looks like

When it fires (unless you've been idle ≥ 15 min — then it skips silently):

1. **Dialog**: a title + one line of copy (persona / industry / roast) + the exercise name, with two buttons:
   - **Got it** — dismiss.
   - **See demo** — opens a browser card with the animation GIF + step-by-step instructions + © Gym visual attribution. **Nothing is fetched unless you click it.**
2. **Spoken** reminder (if `say` is enabled).
3. **Workout music** plays ~5 min, then auto-stops (if `ENABLE_MUSIC=1`).
4. A detection window then quietly checks whether you actually left the desk.

### How streaks work

- After the reminder there's a **detection window** (`DETECT_WINDOW`, default 180s).
- If your keyboard/mouse stays **idle** for `COMPLETE_IDLE` (default 90s) → it counts as **completed** → 🔥 streak +1, with a "✅ Done!" notification.
- If you keep using the computer → **ignored**, and the ignore streak grows.
- ⚠️ **Key point**: you must actually step away — touching the keyboard/mouse **resets the idle timer**. So testing while you operate the computer will always read as ignored.
- After `ESCALATE_AFTER` (default 3) ignores in a row, reminders **escalate**: forced dialog + speech + high-energy music + a **progressively harsher roast** (tiers 1→2→3).
- Check anytime with `/desk-break:stats` (or `npx desk-break stats`).

### Focus & anti-repetition

- `FOCUS_PARTS` picks what to work: `core`, `legs`, `back`, `chest`, `arms`, `shoulders`, `cardio`.
- Focus parts get priority (×`FOCUS_WEIGHT`, default 3), but after `FOCUS_COOLDOWN` (default 2) focus picks in a row it **forces a non-focus** one so it doesn't get monotonous.
- The last `EXERCISE_RECENT_K` (default 6) exercises won't repeat.
- Every exercise is **no-equipment** (259 of them, with pull-up-bar/bench/rings/strap moves filtered out). Glute moves live under the `legs` group.

### Time-adaptive & night mode

- `TIME_ADAPTIVE=1`: happy in the morning, excited in the afternoon, relaxed in the evening (this **overrides** a fixed `MOOD`).
- Late at night (after `NIGHT_HOUR`, default 23) it switches to a "🌙 time to rest" nudge — no exercise/music/streak.

## Commands

Installed as a plugin, commands are namespaced under `desk-break:`. With the npm CLI the same operations are `npx desk-break <cmd>`.

| Plugin command | `npx` equivalent | What it does |
|---|---|---|
| `/desk-break:setup` | `npx desk-break setup` | Interactive configuration + install |
| `/desk-break:status` | — | Loaded agent, current config, recent log |
| `/desk-break:test` | `npx desk-break test` | Fire once now (~8s dry-run, no stats change) |
| `/desk-break:stats` | `npx desk-break stats` | Streak, completion rate, and last-7-days chart |
| `/desk-break:report` | `npx desk-break report "…"` | Open a pre-filled problem-report email |
| `/desk-break:disable` · `enable` | `npx desk-break disable` · `enable` | Pause / resume the reminder |
| `/desk-break:uninstall` | `npx desk-break uninstall [--purge]` | Remove the agent and files |

The `desk-break` skill itself is also invocable as `/desk-break` for guided setup. Under the hood everything maps to `~/.local/bin/desk-break.sh [--test|--stats|--report "…"]` and `launchctl`.

## Configuration

Everything lives in `~/.config/desk-break/config.env` (applies on the next fire; **interval** changes need a `setup` re-run). Exercise cards and copy are per-language under `~/.config/desk-break/i18n/<lang>/`. Full reference: [`SKILL.md`](./skills/health/desk-break/SKILL.md).

| Key | Default | Purpose |
|---|---|---|
| `LOCALE` | auto | Language: auto (system) / zh / en |
| `REMINDER_STYLE` | dialog | Any combo of dialog / notification / say |
| `ENABLE_MUSIC` / `MOOD` | 1 / energetic | Play music / style (overridden when `TIME_ADAPTIVE=1`) |
| `IDLE_LIMIT_SECONDS` | 900 | Skip if idle ≥ this (you're away) |
| `MUSIC_SECONDS` | 300 | Music / exercise window length |
| `PERSONA` | random | hype / funny / savage / random / off |
| `TIME_ADAPTIVE` | 1 | Switch mood + bias by time of day |
| `NIGHT_MODE` / `NIGHT_HOUR` | 1 / 23 | Night "go to sleep" mode |
| `TRACK_STATS` / `DETECT_WINDOW` / `COMPLETE_IDLE` | 1 / 180 / 90 | Streak + completion detection |
| `ESCALATE` / `ESCALATE_AFTER` | 1 / 3 | Escalate + roast after ignores |
| `FOCUS_PARTS` / `FOCUS_WEIGHT` / `FOCUS_COOLDOWN` | "" / 3 / 2 | Body-part focus + priority |
| `EXERCISE_RECENT_K` | 6 | Don't repeat the last K exercises |
| `INDUSTRY` | none | dev/design/pm/marketing/writing/sales/finance/student |
| `REPORT_EMAIL` | maintainer | `/report` recipient |

Data files (edit freely) live under `~/.config/desk-break/i18n/<lang>/`: `exercises.tsv` (exercises), `phrases.txt` (personas), `industry.txt`, `roast.txt`, `moves.txt` (text fallback), `strings.env` (UI text).

## How it works

`setup` installs `~/.local/bin/desk-break.sh` and a launchd agent (`~/Library/LaunchAgents/com.<user>.desk-break.plist`) that runs it on `StartInterval`. The script resolves your locale, checks idle time, shows the reminder / plays music, and writes streak data to `~/.local/share/desk-break/`.

## Files & data

Everything is stored locally (nothing in the cloud).

**Runtime state / logs — `~/.local/share/desk-break/`**

| File | Contents |
|---|---|
| `reminder.log` | Main log: each fire / skip / result / music / errors |
| `stats.env` | Streak totals: streak, best, today/all-time, current ignore streak |
| `history.log` | One line per result (`date⇥time⇥completed/ignored⇥exercise`), source for `/stats` |
| `recent.log` | Recently shown exercises (anti-repetition) |
| `card.html` | Last "See demo" card (overwritten each time) |
| `stdout.log` / `stderr.log` | launchd stdout / stderr |

**Config + data** — `~/.config/desk-break/`: `config.env` and `i18n/<lang>/…`
**Program / agent** — `~/.local/bin/desk-break.sh`, `~/Library/LaunchAgents/com.<user>.desk-break.plist`

> Demo GIFs/images are **not stored locally** — they load by URL only when you click **See demo** (© Gym visual).

## FAQ

- **Why does it always say "ignored"?** Your continuous idle didn't reach 90s, or you kept touching the keyboard/mouse (which resets it). To score a completion, actually step away for 90s+.
- **Too loud / no music?** `ENABLE_MUSIC=0` (or `npx desk-break setup --no-music`).
- **Don't want a browser tab each time?** Just don't click **See demo** — it's optional.
- **Need quiet for a while?** `/desk-break:disable` (or `npx desk-break disable`), later `enable`.
- **When do config changes apply?** On the next fire; only **interval** changes need a `setup` re-run.
- **Demo won't load?** It needs a connection (raw.githubusercontent); offline shows the text steps only.
- **Only glutes / finer muscles?** Currently grouped by major body part (dataset granularity); target-level (e.g. `glutes`) isn't supported yet.
- **Fully uninstall?** `/desk-break:uninstall` (or `npx desk-break uninstall --purge`).

## Notes

- **macOS + local only** — it depends on `launchd`, so it can't run in claude.ai web or the API cloud sandbox.
- Dialog text is passed via `osascript … on run argv`, so Chinese and emoji never garble.

## Data & media credits

- **Exercise data** (names, body parts, step-by-step instructions) is a filtered subset of **[hasaneyldrm/exercises-dataset](https://github.com/hasaneyldrm/exercises-dataset)** (MIT), reshaped by `tools/build-exercises.py`.
- **Demo GIFs/images are © [Gym visual](https://gymvisual.com/)** and are **not redistributed** here — desk-break references them by URL, with attribution on every card, and **only fetches one when you click See demo** (no request otherwise). They're subject to [Gym visual's Terms of Use](https://gymvisual.com/content/3-terms-and-conditions-of-use); referencing a URL is not a license. See [`DATA_NOTICE.md`](./skills/health/desk-break/DATA_NOTICE.md).

## License

[MIT](./LICENSE) © twillot — applies to desk-break's own code. Bundled exercise **data** is MIT (see credits); demo **media** is © Gym visual and separately licensed.
