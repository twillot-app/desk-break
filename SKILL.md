---
name: desk-break
description: Set up or manage a recurring "get up and move" break reminder on macOS. A per-user launchd agent fires on an interval and, unless you've been away past an idle limit, pops a reminder (forced dialog, notification, and/or spoken) and optionally plays workout music via music-cli for a few minutes, then stops it. Includes random exercise cards, persona/time-adaptive copy, a night "go to sleep" mode, and streak tracking with completion detection. Use when the user wants to create, configure, test, check stats for, or disable a movement / exercise / stretch / break reminder, or types /desk-break.
---

# desk-break

A recurring movement-break reminder for macOS, implemented as a per-user **launchd** agent that runs a config-driven script. On each fire it checks how long the Mac has been idle; if you've been away past the idle limit it skips silently, otherwise it shows a reminder and (optionally) plays energetic music via `music-cli` for a few minutes, then stops it.

The runner is **config-driven**: all preferences live in `~/.config/desk-break/config.env`, so re-running setup just rewrites that file — the script itself never changes.

## Subcommands

The user may type `/desk-break <subcommand>`; with no argument, show `status`, then offer `setup` if it isn't installed yet.

- `setup` — interactive (re)configuration, then install/reload. (Default flow below.)
- `status` — is it installed/loaded, current config, and recent log.
- `test` — fire one reminder right now (fast ~8s dry-run; does not touch stats).
- `stats` — show streak / completion report: `~/.local/bin/desk-break.sh --stats`.
- `disable` — unload but keep files. `enable` — reload. `uninstall` — remove everything.

## Paths

Compute `UID=$(id -u)` and `LABEL="com.$(id -un).desk-break"`.

- Bundled source: `<this skill dir>/{reminder.sh, moves.txt, phrases.txt}`
- Installed runner: `~/.local/bin/desk-break.sh`
- Config: `~/.config/desk-break/config.env`
- Data (user-editable): `~/.config/desk-break/moves.txt` (exercise cards `类别|动作`), `~/.config/desk-break/phrases.txt` (copy `人格|文案`, `{move}` placeholder)
- Stats: `~/.local/share/desk-break/stats.env` (streak/completion counters)
- Plist: `~/Library/LaunchAgents/$LABEL.plist`
- Logs: `~/.local/share/desk-break/reminder.log` (plus stdout/stderr logs)

## setup flow

1. If `~/.config/desk-break/config.env` exists, read it first and use its values as the defaults/pre-selection.

2. Gather the knobs in **one `AskUserQuestion` call** (offer an "Other" for custom where noted). The first four are the core; include the "fun pack" ones too when the user wants them:
   - **周期 / interval (minutes)** → plist `StartInterval = minutes * 60`. Options: `20`, `30`, `45`, `60`, Other.
   - **提醒方式 / reminder style** → `REMINDER_STYLE`. Options map to: `强制弹窗`→`dialog`, `通知横幅+提示音`→`notification`, `弹窗+语音`→`dialog+say`, `只语音`→`say`.
   - **音乐风格 / music** → `MOOD` + `ENABLE_MUSIC`. Options: `energetic`, `excited`, `happy`, `不放音乐`→`ENABLE_MUSIC=0`. (Moods: happy sad excited focus relaxed energetic melancholic peaceful.) Note: overridden by `TIME_ADAPTIVE=1`.
   - **文案人格 / copy persona** → `PERSONA`. Options: `随机`→`random`, `励志`, `搞笑`, `毒舌`, `固定文案`→`off` (then use `MESSAGE`). Cards come from `phrases.txt`.
   - **动作卡 / exercise cards** → `SHOW_MOVE` (+ optional `MOVE_CATEGORIES`). Options: `开(随机)`→`SHOW_MOVE=1`, `关`→`SHOW_MOVE=0`. Cards come from `moves.txt`.
   - **时段自适应 + 打卡 / adaptive + streak** → `TIME_ADAPTIVE`, `NIGHT_MODE`, `TRACK_STATS`. Usually all `1`; let the user turn off time-adaptive to pin a fixed `MOOD`.

3. Write `~/.config/desk-break/config.env` (plain bash assignments) with the chosen values plus the tunable defaults. Full var reference is in **Config reference** below; tell the user they can edit any of it there later (changes apply on the next fire; interval changes need a reload).

4. Install runner + data files (don't overwrite the user's edited data files):
   - `install -m 0755 "<skill dir>/reminder.sh" ~/.local/bin/desk-break.sh`
   - `mkdir -p ~/.config/desk-break`
   - `[ -f ~/.config/desk-break/moves.txt ] || cp "<skill dir>/moves.txt" ~/.config/desk-break/moves.txt`
   - `[ -f ~/.config/desk-break/phrases.txt ] || cp "<skill dir>/phrases.txt" ~/.config/desk-break/phrases.txt`

5. Generate the plist from the template below (substitute `$LABEL` and `INTERVAL_SECONDS`), then `plutil -lint` it.

6. Load and dedupe: `launchctl bootout gui/$UID/$LABEL 2>/dev/null; launchctl bootstrap gui/$UID ~/Library/LaunchAgents/$LABEL.plist`. Also bootout + remove any legacy `com.$(id -un).exercise-reminder` agent/script/plist so you don't get **double** reminders.

7. Verify: run `~/.local/bin/desk-break.sh --test` and show the tail of `reminder.log`. Confirm the interval and remind the user of `/desk-break test|status|disable`.

## plist template

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>__LABEL__</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>__HOME__/.local/bin/desk-break.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>__INTERVAL_SECONDS__</integer>
    <key>RunAtLoad</key>
    <false/>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>__HOME__/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
    <key>StandardOutPath</key>
    <string>__HOME__/.local/share/desk-break/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>__HOME__/.local/share/desk-break/stderr.log</string>
</dict>
</plist>
```

## Config reference (`config.env`)

Base: `REMINDER_STYLE` (dialog/notification/say combos), `ENABLE_MUSIC`, `MOOD`, `TITLE`, `MESSAGE` (used when `PERSONA=off`), `BUTTON`, `SPEAK_TEXT` (spoken lead-in; the move card is auto-appended), `IDLE_LIMIT_SECONDS` (skip if idle ≥ this), `MUSIC_SECONDS`, `DIALOG_TIMEOUT`.

Fun pack:
- `SHOW_MOVE` (1/0) + `MOVE_CATEGORIES` (comma list like `core,legs,cardio`; empty = all / time-based) — random card from `moves.txt`.
- `PERSONA` (`励志`|`搞笑`|`毒舌`|`random`|`off`) — random copy from `phrases.txt`; `{move}` is replaced by the card.
- `TIME_ADAPTIVE` (1/0) — auto-switch `MOOD` + move category by time of day (morning→happy/stretch, afternoon→excited/cardio, evening→relaxed/stretch). Overrides fixed `MOOD` when on.
- `NIGHT_MODE` (1/0) + `NIGHT_HOUR` — after that hour, show a "go to sleep" reminder instead (no streak counted).
- `TRACK_STATS` (1/0) + `DETECT_WINDOW` (seconds watched after the reminder) + `COMPLETE_IDLE` (idle seconds within the window that count as "you got up") — powers streak + `--stats`.
- `ESCALATE` (1/0) + `ESCALATE_AFTER` — after N consecutive ignores, force `dialog+say` and a high-energy mood until the next completion.

Editing `moves.txt` / `phrases.txt` / most of `config.env` takes effect on the next fire (no reload). Changing the interval needs a plist regen + reload (re-run `setup`).

## status

- `launchctl print gui/$(id -u)/$LABEL 2>/dev/null | grep -iE 'state|runs' ` or `launchctl list | grep desk-break`.
- `cat ~/.config/desk-break/config.env`, `~/.local/bin/desk-break.sh --stats`, and `tail -n 20 ~/.local/share/desk-break/reminder.log`.

## test

- Fast dry-run (recommended): `~/.local/bin/desk-break.sh --test`.
- Real fire now: `launchctl kickstart gui/$(id -u)/$LABEL`.

## disable / enable / uninstall

- Disable (keep files): `launchctl bootout gui/$(id -u)/$LABEL`.
- Enable again: `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/$LABEL.plist`.
- Uninstall: bootout, then `rm` the plist and `~/.local/bin/desk-break.sh`; optionally remove `~/.config/desk-break` and `~/.local/share/desk-break`.

## Notes

- macOS only: relies on `launchd`, `ioreg` (HIDIdleTime), `osascript`, and `say`.
- Music needs `music-cli` (aka `mc`) on PATH; if it's missing, reminders still fire and music is skipped.
- LaunchAgents run in the user's GUI (Aqua) session, so dialogs/notifications appear. Changing `config.env` takes effect on the next fire — no reload needed. Changing the interval requires regenerating the plist and reloading (re-run `setup`).
