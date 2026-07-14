---
name: desk-break
description: Set up or manage a recurring "get up and move" break reminder on macOS. A per-user launchd agent fires on an interval and, unless you've been away past an idle limit, pops a reminder (forced dialog, notification, and/or spoken) and optionally plays workout music via music-cli for a few minutes, then stops it. Includes random exercise cards, persona/time-adaptive copy, a night "go to sleep" mode, streak tracking with completion detection, and English/中文 i18n. Use when the user wants to create, configure, test, check stats for, report a problem with, or disable a movement / exercise / stretch / break reminder, or types /desk-break.
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Write
license: MIT
version: 0.3.0
---

# desk-break

A recurring movement-break reminder for macOS, implemented as a per-user **launchd** agent that runs a config-driven, localized script. On each fire it checks idle time; if you've been away past the idle limit it skips silently, otherwise it shows a reminder and (optionally) plays music via `music-cli`, then stops it.

Config-driven + i18n: preferences live in `~/.config/desk-break/config.env`; user-facing text, exercise cards, and copy come from `~/.config/desk-break/i18n/<lang>/`. Re-running setup just rewrites config — the runner never changes.

## Subcommands / commands

- `/desk-break setup` — interactive (re)configuration, then install/reload. (Flow below.)
- `/desk-break status` — installed/loaded?, current config, recent log.
- `/desk-break test` — fire once now (fast ~8s dry-run; does not touch stats).
- `/stats` — streak + last-7-days report (`~/.local/bin/desk-break.sh --stats`). Shipped as a plugin command.
- `/report` — email a problem to the maintainer via a pre-filled draft (`--report`). Shipped as a plugin command.
- `/desk-break disable` — unload but keep files. `enable` — reload. `uninstall` — remove everything.

## Paths

Compute `UID=$(id -u)` and `LABEL="com.$(id -un).desk-break"`.

- Bundled source: `<this skill dir>/{reminder.sh, i18n/<lang>/{moves.txt,phrases.txt,strings.env}}`
- Installed runner: `~/.local/bin/desk-break.sh`
- Config: `~/.config/desk-break/config.env`
- Localized data (user-editable): `~/.config/desk-break/i18n/<lang>/{moves.txt,phrases.txt,strings.env}`
- Stats: `~/.local/share/desk-break/stats.env`; history: `.../history.log`
- Plist: `~/Library/LaunchAgents/$LABEL.plist`
- Logs: `~/.local/share/desk-break/reminder.log` (+ stdout/stderr)

## setup flow

1. If `~/.config/desk-break/config.env` exists, read it first and pre-select from it.

2. Gather knobs in **one `AskUserQuestion` call** (offer "Other" where noted):
   - **语言 / language** → `LOCALE`. Options: `自动/auto`→`auto`, `中文`→`zh`, `English`→`en`.
   - **周期 / interval (minutes)** → plist `StartInterval = minutes*60`. `20`, `30`, `45`, `60`, Other.
   - **提醒方式 / reminder style** → `REMINDER_STYLE`: `强制弹窗`→`dialog`, `通知横幅+提示音`→`notification`, `弹窗+语音`→`dialog+say`, `只语音`→`say`.
   - **音乐 / music** → `MOOD` + `ENABLE_MUSIC`: `energetic`, `excited`, `happy`, `不放/none`→`ENABLE_MUSIC=0`. (Moods: happy sad excited focus relaxed energetic melancholic peaceful.) Overridden by `TIME_ADAPTIVE=1`.
   - **文案人格 / persona** → `PERSONA`: `随机/random`, `hype`, `funny`, `savage`, `固定文案/off`.
   - **动作卡 + 时段 + 打卡 / cards + adaptive + streak** → `SHOW_MOVE`, `TIME_ADAPTIVE`, `NIGHT_MODE`, `TRACK_STATS` (usually all `1`).

3. Write `~/.config/desk-break/config.env`. Set `LOCALE` and the chosen knobs. **Do not** hard-set `TITLE`/`MESSAGE`/`SPEAK_TEXT` unless the user wants custom copy — leaving them unset lets the localized `strings.env` drive text so language switching works. Full var list in **Config reference**.

4. Install runner + localized data (don't overwrite user-edited files):
   - `install -m 0755 "<skill dir>/reminder.sh" ~/.local/bin/desk-break.sh`
   - `mkdir -p ~/.config/desk-break/i18n`
   - `cp -R "<skill dir>/i18n/." ~/.config/desk-break/i18n/` — but per-file, skip existing:
     for each `i18n/<lang>/<file>`, copy only if the destination doesn't exist.

5. Generate the plist from the template below (substitute `$LABEL`, `INTERVAL_SECONDS`), `plutil -lint` it.

6. Load + dedupe: `launchctl bootout gui/$UID/$LABEL 2>/dev/null; launchctl bootstrap gui/$UID ~/Library/LaunchAgents/$LABEL.plist`. Also bootout + remove any legacy `com.$(id -un).exercise-reminder`.

7. Verify: `~/.local/bin/desk-break.sh --test`, show the tail of `reminder.log`, remind the user of `/stats`, `/report`, `/desk-break status|disable`.

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

- **i18n**: `LOCALE` (`auto`|`en`|`zh`; auto = macOS system locale). `REPORT_EMAIL` (maintainer for `/report`).
- **Base**: `REMINDER_STYLE`, `ENABLE_MUSIC`, `MOOD`, `IDLE_LIMIT_SECONDS`, `MUSIC_SECONDS`, `DIALOG_TIMEOUT`. Optional copy overrides: `TITLE`, `MESSAGE` (used when `PERSONA=off`), `BUTTON`, `SPEAK_TEXT` — leave unset to use localized `strings.env`.
- **Fun pack**: `SHOW_MOVE` + `MOVE_CATEGORIES` (e.g. `core,legs,cardio`; empty = all/time-based); `PERSONA` (`hype`|`funny`|`savage`|`random`|`off`); `TIME_ADAPTIVE` (overrides `MOOD` + category by time); `NIGHT_MODE` + `NIGHT_HOUR`; `TRACK_STATS` + `DETECT_WINDOW` + `COMPLETE_IDLE`; `ESCALATE` + `ESCALATE_AFTER`.

Exercise cards `moves.txt` (`category|move`) and copy `phrases.txt` (`persona|line`, `{move}` placeholder; personas `hype`/`funny`/`savage`) live per-language under `i18n/<lang>/`. Editing config/data applies on the next fire; interval changes need a plist regen + reload (re-run `setup`).

## status / test / stats / report

- status: `launchctl print gui/$(id -u)/$LABEL 2>/dev/null | grep -iE 'state|runs'`; `cat config.env`; `desk-break.sh --stats`; `tail -n 20 reminder.log`.
- test: `~/.local/bin/desk-break.sh --test` (or `launchctl kickstart gui/$(id -u)/$LABEL` for a real fire).
- stats: `~/.local/bin/desk-break.sh --stats`.
- report: `~/.local/bin/desk-break.sh --report "<problem>"` (add `--print` to preview the mailto).

## disable / enable / uninstall

- Disable: `launchctl bootout gui/$(id -u)/$LABEL`. Enable: `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/$LABEL.plist`.
- Uninstall: bootout, then `rm` the plist and `~/.local/bin/desk-break.sh`; optionally `~/.config/desk-break` and `~/.local/share/desk-break`.

## Notes

- macOS only: `launchd`, `ioreg` (HIDIdleTime), `osascript`, `say`. Music needs `music-cli` (aka `mc`) on PATH; absent → reminders still fire, music skipped.
- osascript uses `on run argv` so Chinese/emoji never garble.
- Same skill content works in other agents via `AGENTS.md` and `.cursor/rules/` at the repo root.
