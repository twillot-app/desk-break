# AGENTS.md — desk-break

Guidance for coding agents (OpenAI Codex CLI, Cursor, and others) working with this
repo. Claude Code additionally reads the richer skill at
`plugins/desk-break/skills/desk-break/SKILL.md` — prefer that when running under Claude Code.

## What this is

`desk-break` is a **macOS-only** movement-break reminder. A per-user `launchd` agent
runs a config-driven shell script on an interval; unless the Mac has been idle past a
limit, it shows a reminder (dialog / notification / spoken), optionally plays workout
music via [`music-cli`](https://github.com/luongnv89/music-cli), and tracks a streak.
Everything is local shell — there is no service to deploy. English + 中文 (i18n).

## Core file (single source of truth)

`plugins/desk-break/skills/desk-break/reminder.sh` — the runner. Do not duplicate its
logic; other entry points just call it. It reads:
- `~/.config/desk-break/config.env` — settings
- `~/.config/desk-break/i18n/<lang>/{moves.txt,phrases.txt,strings.env}` — localized data

## Install (manual, any agent)

```bash
# 1. runner
install -m 0755 plugins/desk-break/skills/desk-break/reminder.sh ~/.local/bin/desk-break.sh
# 2. localized data (don't overwrite user edits)
mkdir -p ~/.config/desk-break/i18n
cp -Rn plugins/desk-break/skills/desk-break/i18n/. ~/.config/desk-break/i18n/
# 3. write ~/.config/desk-break/config.env  (see Config reference in SKILL.md)
# 4. register a launchd agent that runs ~/.local/bin/desk-break.sh on StartInterval
#    (see the plist template in SKILL.md), then:
#    launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.$(id -un).desk-break.plist
```

Under **Claude Code**, prefer the guided flow: run the `desk-break` skill's `setup`.
It handles the questions, install, plist, and a verification test.

## Commands / operations

```bash
~/.local/bin/desk-break.sh --test              # fast dry-run (no stats change)
~/.local/bin/desk-break.sh --stats             # streak + last 7 days
~/.local/bin/desk-break.sh --report "problem"  # open a pre-filled feedback email
```

## Key config keys

`LOCALE` (auto|en|zh), `REPORT_EMAIL`, `REMINDER_STYLE` (dialog/notification/say),
`ENABLE_MUSIC`, `MOOD`, `IDLE_LIMIT_SECONDS`, `MUSIC_SECONDS`, `FOCUS_PARTS`, `PERSONA`
(hype|funny|savage|random|off), `TIME_ADAPTIVE`, `NIGHT_MODE`, `TRACK_STATS`,
`DETECT_WINDOW`, `COMPLETE_IDLE`, `ESCALATE`. Full reference: `SKILL.md`.

## Constraints

- macOS only (`launchd`, `ioreg`, `osascript`, `say`). Don't add Linux/Windows paths silently.
- Keep `osascript` calls using `on run argv` (UTF-8 safe) — never env-var + `system attribute`.
- Never put secrets in `config.env` or the scripts.
