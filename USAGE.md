# desk-break — Usage guide

**English** · [中文](./USAGE.zh-CN.md)

A sitting-break assistant: on an interval it reminds you to get up and move, shows a **no-equipment exercise with an animated demo**, and tracks your **streak**. This is the how-to; the full field reference is in [`SKILL.md`](./plugins/desk-break/skills/desk-break/SKILL.md).

## Quick start

Claude Code:

```
/plugin marketplace add twillot-app/desk-break
/plugin install desk-break@twillot
/desk-break:setup
```

`setup` walks you through **language / interval / reminder style / music / persona / focus body parts / industry**, then registers a launchd agent (survives reboots).

## What a reminder looks like

When it fires (unless you've been idle ≥ 15 min — then it skips silently):

1. **Dialog**: a title + one line of copy (persona / industry / roast) + the exercise name, with two buttons:
   - **Got it** — dismiss.
   - **See demo** — opens a browser card with the animation GIF + step-by-step instructions + © Gym visual attribution. **Nothing is fetched unless you click it.**
2. **Spoken** reminder (if `say` is enabled).
3. **Workout music** plays ~5 min, then auto-stops (if `ENABLE_MUSIC=1`).
4. A detection window then quietly checks whether you actually left the desk.

## How streaks work

- After the reminder there's a **detection window** (`DETECT_WINDOW`, default 180s).
- If your keyboard/mouse stays **idle** for `COMPLETE_IDLE` (default 90s) → it counts as **completed** → 🔥 streak +1, with a "✅ Done!" notification.
- If you keep using the computer → **ignored**, and the ignore streak grows.
- ⚠️ **Key point**: you must actually step away — touching the keyboard/mouse **resets the idle timer**. So testing while you operate the computer will always read as ignored.
- After `ESCALATE_AFTER` (default 3) ignores in a row, reminders **escalate**: forced dialog + speech + high-energy music + a **progressively harsher roast** (tiers 1→2→3).
- Check anytime: `/desk-break:stats` (streak, completion rate, last-7-days chart).

## Focus & anti-repetition

- `FOCUS_PARTS` picks what to work: `core`, `legs`, `back`, `chest`, `arms`, `shoulders`, `cardio`.
- Focus parts get priority (×`FOCUS_WEIGHT`, default 3), but after `FOCUS_COOLDOWN` (default 2) focus picks in a row it **forces a non-focus** one so it doesn't get monotonous.
- The last `EXERCISE_RECENT_K` (default 6) exercises won't repeat.
- Every exercise is **no-equipment** (259 of them, with pull-up-bar/bench/rings/strap moves filtered out). Glute moves live under the `legs` group.

## Time-adaptive & night mode

- `TIME_ADAPTIVE=1`: happy in the morning, excited in the afternoon, relaxed in the evening (this **overrides** a fixed `MOOD`).
- Late at night (after `NIGHT_HOUR`, default 23) it switches to a "🌙 time to rest" nudge — no exercise/music/streak.

## Commands

| Command | What it does |
|---|---|
| `/desk-break:setup` | Interactive configuration + install |
| `/desk-break:status` | Status, current config, recent log |
| `/desk-break:test` | Fire once now (~8s dry-run; no stats change) |
| `/desk-break:stats` | Streak, completion rate, last-7-days chart |
| `/desk-break:report` | Open a pre-filled problem-report email |
| `/desk-break:disable` · `/desk-break:enable` | Pause / resume |
| `/desk-break:uninstall` | Remove everything |

## Config quick reference (`~/.config/desk-break/config.env`; applies next fire; interval changes need a `setup` re-run)

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

## Files & data (all local, nothing in the cloud)

**Runtime state / logs — `~/.local/share/desk-break/`**

| File | Contents |
|---|---|
| `reminder.log` | Main log: each fire / skip / result / music / errors |
| `stats.env` | Streak totals: streak, best, today/all-time, current ignore streak |
| `history.log` | One line per result (`date⇥time⇥completed/ignored⇥exercise`), source for `/stats` |
| `recent.log` | Recently shown exercises (anti-repetition) |
| `card.html` | Last "See demo" card (overwritten each time) |
| `stdout.log` / `stderr.log` | launchd stdout / stderr |

**Config + data — `~/.config/desk-break/`** (`config.env` + `i18n/<lang>/…`)
**Program / agent** — `~/.local/bin/desk-break.sh`, `~/Library/LaunchAgents/com.<user>.desk-break.plist`

> Demo GIFs/images are **not stored locally** — they load by URL only when you click **See demo** (© Gym visual).

## FAQ

- **Why does it always say "ignored"?** Your continuous idle didn't reach 90s, or you kept touching the keyboard/mouse (which resets it). To score a completion, actually step away for 90s+.
- **Too loud / no music?** `ENABLE_MUSIC=0`.
- **Don't want a browser tab each time?** Just don't click **See demo** — it's optional.
- **Need quiet for a while?** `/desk-break:disable`, later `/desk-break:enable`.
- **When do config changes apply?** On the next fire; only **interval** changes need a `setup` re-run.
- **Demo won't load?** It needs a connection (raw.githubusercontent); offline shows the text steps only.
- **Only glutes / finer muscles?** Currently grouped by major body part (dataset granularity); target-level (e.g. `glutes`) isn't supported yet.
- **Fully uninstall?** `/desk-break:uninstall`.
