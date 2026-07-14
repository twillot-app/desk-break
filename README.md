# desk-break

> A macOS "get up and move" break reminder for AI coding agents — random exercise cards, workout music, and streak tracking. Works with **Claude Code**, **Codex**, **Cursor**, and more.

**English** · [中文](./README.zh-CN.md)

A per-user `launchd` agent reminds you to leave the desk and move on an interval. Each time it fires, it checks whether you're actually at the keyboard, then pops a reminder with a random exercise card, plays workout music, and tracks your streak — unless you've stepped away, in which case it stays quiet.

## Features

- ⏰ **Interval reminders** via `launchd` (default every 30 min); survives reboots.
- 😴 **Smart skip**: idle ≥ 15 min (you're away) → skips silently.
- 🃏 **Random exercise cards** from `moves.txt` (stretch / core / legs / cardio / lazy / eyes).
- 🎭 **Copy personas**: hype / funny / savage, picked at random (editable in `phrases.txt`).
- 🌤️ **Time-adaptive**: stretch in the morning, cardio in the afternoon, wind-down in the evening; a **night mode** switches to a "go to sleep" nudge.
- 🎵 **Workout music** via [music-cli](https://github.com/luongnv89/music-cli), auto-stopped after the exercise window.
- 🔥 **Streak tracking** with completion detection (watches idle after the reminder); escalates after repeated ignores.
- 🗣️ **Reminder styles**: forced dialog / notification / spoken — combine freely.
- 🌐 **i18n**: English + 中文, auto-detected from your system locale.

## Requirements

- **macOS** (uses `launchd`, `ioreg`, `osascript`, `say`).
- An agent host — **[Claude Code](https://claude.com/claude-code)** (richest experience), or **Codex / Cursor / others** (see [Other agents](#other-agents)).
- **[music-cli](https://github.com/luongnv89/music-cli)** (optional; without it, reminders still fire and music is skipped).

## Install

### Claude Code — plugin marketplace (recommended)

```
/plugin marketplace add twillot-app/desk-break
/plugin install desk-break@twillot
/desk-break setup
```

`setup` walks you through language, interval, reminder style, music, persona, and the fun-pack toggles, then registers the launchd agent.

### Other agents

The skill is plain shell + data, so any agent can drive it. See [`AGENTS.md`](./AGENTS.md) (read by Codex and others) and [`.cursor/rules/desk-break.mdc`](./.cursor/rules/desk-break.mdc) (Cursor). Quick manual install:

```bash
install -m 0755 plugins/desk-break/skills/desk-break/reminder.sh ~/.local/bin/desk-break.sh
mkdir -p ~/.config/desk-break/i18n
cp -Rn plugins/desk-break/skills/desk-break/i18n/. ~/.config/desk-break/i18n/
# create ~/.config/desk-break/config.env and a launchd plist — see AGENTS.md / SKILL.md
```

## Commands

| Command | What it does |
|---|---|
| `/desk-break setup` | Interactive configuration + install |
| `/desk-break status` | Status, config, recent log |
| `/desk-break test` | Fire once now (~8s dry-run, no stats change) |
| `/stats` | Streak, completion rate, and last-7-days chart |
| `/report` | Open a pre-filled problem-report email to the maintainer |
| `/desk-break disable` · `uninstall` | Stop / remove |

Under the hood these map to `~/.local/bin/desk-break.sh [--test|--stats|--report "…"]`.

## Configuration

Everything lives in `~/.config/desk-break/config.env` (applies on the next fire; interval changes need a re-run of `setup`). Exercise cards and copy are per-language under `~/.config/desk-break/i18n/<lang>/`. Full reference: [`SKILL.md`](./plugins/desk-break/skills/desk-break/SKILL.md).

Highlights: `LOCALE` (auto/en/zh), `REMINDER_STYLE`, `MOOD`, `PERSONA` (hype/funny/savage/random/off), `TIME_ADAPTIVE`, `NIGHT_MODE`, `TRACK_STATS`, `IDLE_LIMIT_SECONDS`, `MUSIC_SECONDS`, `REPORT_EMAIL`.

## How it works

`setup` installs `~/.local/bin/desk-break.sh` and a launchd agent (`~/Library/LaunchAgents/com.<user>.desk-break.plist`) that runs it on `StartInterval`. The script resolves your locale, checks idle time, shows the reminder / plays music, and writes streak data to `~/.local/share/desk-break/`.

## Notes

- **macOS + local only** — it depends on `launchd`, so it can't run in claude.ai web or the API cloud sandbox.
- Dialog text is passed via `osascript … on run argv`, so Chinese and emoji never garble.

## License

[MIT](./LICENSE) © twillot
