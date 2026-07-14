#!/bin/bash
# desk-break — reminder runner (installed to ~/.local/bin/desk-break.sh).
#
# Managed by the "desk-break" Claude Code skill. On each launchd fire it reads
# ~/.config/desk-break/config.env and, unless you've been idle past the limit,
# shows a movement-break reminder and optionally plays workout music, then
# stops it. v2 adds: random exercise cards, persona/time-adaptive copy, a
# night "go to sleep" mode, and streak tracking with completion detection.
#
# Usage:
#   desk-break.sh          normal run (used by launchd)
#   desk-break.sh --test   fast dry-run (ignore idle; ~8s; does NOT touch stats)
#   desk-break.sh --stats  print streak / completion report and exit

set -u
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

CONFIG="${DESK_BREAK_CONFIG:-$HOME/.config/desk-break/config.env}"
DATA_DIR="$HOME/.config/desk-break"
STATE_DIR="$HOME/.local/share/desk-break"
MOVES_FILE="$DATA_DIR/moves.txt"
PHRASES_FILE="$DATA_DIR/phrases.txt"
STATS_FILE="$STATE_DIR/stats.env"
LOG="$STATE_DIR/reminder.log"
LOCK="/tmp/desk-break.lock"

# ---- defaults (overridden by config.env) ----
IDLE_LIMIT_SECONDS=900
MUSIC_SECONDS=300
DIALOG_TIMEOUT=300
MOOD="energetic"
ENABLE_MUSIC=1
REMINDER_STYLE="dialog"
TITLE="🏃 该动一动了"
MESSAGE="离开桌面,动几分钟 💪"
BUTTON="知道了"
SPEAK_TEXT="起来活动一下"
# v2 fun pack
SHOW_MOVE=1
MOVE_CATEGORIES=""
PERSONA="random"          # 励志 | 搞笑 | 毒舌 | random | off
TIME_ADAPTIVE=1
NIGHT_MODE=1
NIGHT_HOUR=23
TRACK_STATS=1
DETECT_WINDOW=180
COMPLETE_IDLE=90
ESCALATE=1
ESCALATE_AFTER=3

[ -f "$CONFIG" ] && . "$CONFIG"

MC="$(command -v music-cli 2>/dev/null || echo "$HOME/.local/bin/music-cli")"
mkdir -p "$STATE_DIR" "$DATA_DIR"
ts() { date '+%Y-%m-%d %H:%M:%S'; }
idle_now() { local n; n=$(ioreg -c IOHIDSystem 2>/dev/null | awk '/HIDIdleTime/ {print $NF; exit}'); echo $(( ${n:-0} / 1000000000 )); }

# osascript via `on run argv` — UTF-8 safe (env-var + system attribute mangles it).
dialog_box() { # $1=message $2=title $3=button $4=giveup-seconds
  osascript \
    -e 'on run {m, t, b, g}' \
    -e 'display dialog m with title t buttons {b} default button b giving up after (g as integer)' \
    -e 'end run' "$1" "$2" "$3" "$4" >/dev/null 2>&1
}
notify_box() { # $1=message $2=title $3=sound
  osascript \
    -e 'on run {m, t, s}' \
    -e 'display notification m with title t sound name s' \
    -e 'end run' "$1" "$2" "${3:-Ping}" >/dev/null 2>&1
}

# pick a random non-comment, non-blank line; optional ERE filter (falls back to all).
pick_line() { # $1=file $2=filter-ERE
  local f="$1" filt="${2:-}" lines sub n p
  [ -f "$f" ] || return 1
  lines=$(grep -vE '^[[:space:]]*#' "$f" | grep -vE '^[[:space:]]*$')
  if [ -n "$filt" ]; then
    sub=$(printf '%s\n' "$lines" | grep -E "$filt"); [ -n "$sub" ] && lines="$sub"
  fi
  [ -z "$lines" ] && return 1
  n=$(printf '%s\n' "$lines" | wc -l | tr -d ' ')
  p=$(( (RANDOM % n) + 1 ))
  printf '%s\n' "$lines" | sed -n "${p}p"
}

# ---- stats ----
load_stats() {
  TOTAL_FIRED=0; TOTAL_COMPLETED=0; TOTAL_IGNORED=0
  STREAK=0; BEST_STREAK=0; LAST_COMPLETE_DATE=""
  IGNORE_RUN=0; TODAY_DATE=""; TODAY_COMPLETED=0; TODAY_FIRED=0
  [ -f "$STATS_FILE" ] && . "$STATS_FILE"
}
save_stats() {
  cat > "$STATS_FILE" <<EOF
TOTAL_FIRED=$TOTAL_FIRED
TOTAL_COMPLETED=$TOTAL_COMPLETED
TOTAL_IGNORED=$TOTAL_IGNORED
STREAK=$STREAK
BEST_STREAK=$BEST_STREAK
LAST_COMPLETE_DATE="$LAST_COMPLETE_DATE"
IGNORE_RUN=$IGNORE_RUN
TODAY_DATE="$TODAY_DATE"
TODAY_COMPLETED=$TODAY_COMPLETED
TODAY_FIRED=$TODAY_FIRED
EOF
}
effective_streak() { # streak counts only if last completion was today or yesterday
  local today yday; today=$(date +%Y-%m-%d); yday=$(date -v-1d +%Y-%m-%d 2>/dev/null)
  if [ "$LAST_COMPLETE_DATE" = "$today" ] || [ "$LAST_COMPLETE_DATE" = "$yday" ]; then echo "$STREAK"; else echo 0; fi
}

# ---- --stats report ----
if [ "${1:-}" = "--stats" ]; then
  load_stats; es=$(effective_streak)
  rate=0; [ "$TOTAL_FIRED" -gt 0 ] && rate=$(( TOTAL_COMPLETED * 100 / TOTAL_FIRED ))
  echo "🏃 desk-break 战绩"
  echo "  🔥 连续打卡:${es} 天   (历史最佳 ${BEST_STREAK} 天)"
  echo "  📅 今天:完成 ${TODAY_COMPLETED} / 提醒 ${TODAY_FIRED}"
  echo "  📈 累计:完成 ${TOTAL_COMPLETED} / 提醒 ${TOTAL_FIRED}  (完成率 ${rate}%)"
  echo "  😴 当前连续忽略:${IGNORE_RUN} 次"
  exit 0
fi

TEST=0
[ "${1:-}" = "--test" ] && TEST=1
if [ "$TEST" = 1 ]; then MUSIC_SECONDS=8; DIALOG_TIMEOUT=8; DETECT_WINDOW=8; COMPLETE_IDLE=3; fi

# ---- lock ----
if ! mkdir "$LOCK" 2>/dev/null; then echo "$(ts) skip: already running" >> "$LOG"; exit 0; fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

# ---- idle skip ----
idle_sec=$(idle_now)
if [ "$TEST" != 1 ] && [ "$idle_sec" -ge "$IDLE_LIMIT_SECONDS" ]; then
  echo "$(ts) skip: idle ${idle_sec}s (>= ${IDLE_LIMIT_SECONDS}s)" >> "$LOG"; exit 0
fi

# ---- time of day ----
hour=$((10#$(date +%H)))
if   [ "$hour" -lt 5 ]; then period="night"
elif [ "$hour" -lt 11 ]; then period="morning"
elif [ "$hour" -lt 18 ]; then period="afternoon"
elif [ "$hour" -lt "$NIGHT_HOUR" ]; then period="evening"
else period="night"; fi
night=0; { [ "$NIGHT_MODE" = 1 ] && [ "$period" = "night" ]; } && night=1

# time-adaptive mood + move category
cat_filter=""
if [ "$TIME_ADAPTIVE" = 1 ]; then
  case "$period" in
    morning)   MOOD="happy";   cat_filter="stretch|lazy|eyes" ;;
    afternoon) MOOD="excited"; cat_filter="cardio|legs|core" ;;
    evening)   MOOD="relaxed"; cat_filter="stretch|eyes" ;;
    night)     MOOD="relaxed"; cat_filter="stretch|eyes" ;;
  esac
fi
[ -n "$MOVE_CATEGORIES" ] && cat_filter=$(echo "$MOVE_CATEGORIES" | tr ',' '|')

# ---- pick a move card ----
move=""
if [ "$SHOW_MOVE" = 1 ]; then
  mfilt=""; [ -n "$cat_filter" ] && mfilt="^(${cat_filter})\\|"
  msel=$(pick_line "$MOVES_FILE" "$mfilt") && move="${msel#*|}"
fi

# ---- load stats + daily reset (needed for header) ----
load_stats
today=$(date +%Y-%m-%d)
if [ "$TODAY_DATE" != "$today" ]; then TODAY_DATE="$today"; TODAY_COMPLETED=0; TODAY_FIRED=0; fi

# ---- persona + message body ----
persona="$PERSONA"
if [ "$persona" = "random" ]; then
  parr=("励志" "搞笑" "毒舌"); persona="${parr[$((RANDOM % 3))]}"
fi
phrase=""
if [ "$PERSONA" != "off" ]; then
  psel=$(pick_line "$PHRASES_FILE" "^${persona}\\|") && phrase="${psel#*|}"
fi
if [ -n "$phrase" ]; then
  if [[ "$phrase" == *"{move}"* ]]; then body="${phrase//\{move\}/$move}"
  else body="$phrase"; [ -n "$move" ] && body="${phrase}"$'\n'"👉 ${move}"; fi
else
  body="$MESSAGE"; [ -n "$move" ] && body="${MESSAGE}"$'\n'"👉 ${move}"
fi

# ---- escalation (too many ignores in a row) ----
escalated=0
if [ "$ESCALATE" = 1 ] && [ "$night" != 1 ] && [ "$IGNORE_RUN" -ge "$ESCALATE_AFTER" ]; then
  escalated=1; REMINDER_STYLE="dialog+say"; MOOD="excited"
fi

# ---- night override ----
if [ "$night" = 1 ]; then
  TITLE="🌙 该休息了"
  body="夜深了 😴 别练了,去睡吧。今天已完成 ${TODAY_COMPLETED} 次,辛苦了。"
  SPEAK_TEXT="夜深了,去休息吧"
fi

# ---- header (streak / count / escalation flag) ----
header=""
if [ "$TRACK_STATS" = 1 ] && [ "$night" != 1 ]; then
  es=$(effective_streak)
  [ "$es" -gt 0 ] && header="🔥 连续 ${es} 天 · "
  header="${header}今天第 $((TODAY_FIRED + 1)) 次"
  [ "$escalated" = 1 ] && header="⚠️ 已连续忽略 ${IGNORE_RUN} 次!${header}"
fi
if [ -n "$header" ]; then final_msg="${header}"$'\n'"${body}"; else final_msg="$body"; fi

# ---- spoken line ----
spoken="$SPEAK_TEXT"
if [ "$night" != 1 ] && [ -n "$move" ]; then
  spoken="${SPEAK_TEXT},${move%%[:,，]*}"   # lead-in + first segment of the move
fi

# ---- count this fire ----
TOTAL_FIRED=$((TOTAL_FIRED + 1)); TODAY_FIRED=$((TODAY_FIRED + 1))
echo "$(ts) fire: idle ${idle_sec}s period=$period night=$night persona=$persona style=$REMINDER_STYLE mood=$MOOD esc=$escalated move='${move}'" >> "$LOG"

# ---- start music ----
music_on=0
if [ "$ENABLE_MUSIC" = 1 ] && [ -x "$MC" ]; then
  "$MC" mood "$MOOD" >> "$LOG" 2>&1 &
  music_on=1
fi

# ---- reminders ----
SAY_PID=""
case "$REMINDER_STYLE" in *notification*) notify_box "$final_msg" "$TITLE" "Ping" ;; esac
case "$REMINDER_STYLE" in *say*) [ -n "$spoken" ] && { say "$spoken" >/dev/null 2>&1 & SAY_PID=$!; } ;; esac

# dialog window (also bounds how long the backgrounded dialog lingers)
dialog_secs=$DIALOG_TIMEOUT
[ "$music_on" = 1 ] && dialog_secs=$MUSIC_SECONDS
if [ "$TRACK_STATS" = 1 ] && [ "$night" != 1 ] && [ "$DETECT_WINDOW" -gt "$dialog_secs" ]; then dialog_secs=$DETECT_WINDOW; fi
case "$REMINDER_STYLE" in *dialog*) dialog_box "$final_msg" "$TITLE" "$BUTTON" "$dialog_secs" & ;; esac

# ---- hold window: play music + watch idle for completion ----
hold=0
[ "$music_on" = 1 ] && hold=$MUSIC_SECONDS
if [ "$TRACK_STATS" = 1 ] && [ "$night" != 1 ] && [ "$DETECT_WINDOW" -gt "$hold" ]; then hold=$DETECT_WINDOW; fi
if [ "$hold" -eq 0 ]; then case "$REMINDER_STYLE" in *dialog*) hold=$dialog_secs ;; esac; fi

max_idle=0; music_stopped=0; elapsed=0
STEP=15; [ "$TEST" = 1 ] && STEP=2
while [ "$elapsed" -lt "$hold" ]; do
  cur=$(idle_now); [ "$cur" -gt "$max_idle" ] && max_idle=$cur
  if [ "$music_on" = 1 ] && [ "$music_stopped" = 0 ] && [ "$elapsed" -ge "$MUSIC_SECONDS" ]; then
    "$MC" stop >> "$LOG" 2>&1; music_stopped=1
  fi
  sleep "$STEP"; elapsed=$(( elapsed + STEP ))
done
if [ "$music_on" = 1 ] && [ "$music_stopped" = 0 ]; then "$MC" stop >> "$LOG" 2>&1; fi
[ -n "$SAY_PID" ] && wait "$SAY_PID" 2>/dev/null

# ---- completion detection + stats ----
if [ "$TRACK_STATS" = 1 ] && [ "$night" != 1 ]; then
  completed=0; [ "$max_idle" -ge "$COMPLETE_IDLE" ] && completed=1
  if [ "$TEST" = 1 ]; then
    echo "$(ts) result(test): completed=$completed max_idle=${max_idle}s (stats not saved)" >> "$LOG"
  else
    if [ "$completed" = 1 ]; then
      TOTAL_COMPLETED=$((TOTAL_COMPLETED + 1)); TODAY_COMPLETED=$((TODAY_COMPLETED + 1)); IGNORE_RUN=0
      yday=$(date -v-1d +%Y-%m-%d 2>/dev/null)
      if   [ "$LAST_COMPLETE_DATE" = "$today" ]; then :
      elif [ "$LAST_COMPLETE_DATE" = "$yday" ];  then STREAK=$((STREAK + 1))
      else STREAK=1; fi
      LAST_COMPLETE_DATE="$today"; [ "$STREAK" -gt "$BEST_STREAK" ] && BEST_STREAK=$STREAK
      es=$(effective_streak)
      notify_box "今天第 ${TODAY_COMPLETED} 次 · 🔥 连续 ${es} 天,继续保持!" "✅ 完成!" "Glass"
    else
      TOTAL_IGNORED=$((TOTAL_IGNORED + 1)); IGNORE_RUN=$((IGNORE_RUN + 1))
    fi
    save_stats
    echo "$(ts) result: completed=$completed max_idle=${max_idle}s streak=$STREAK ignore_run=$IGNORE_RUN" >> "$LOG"
  fi
else
  [ "$TEST" != 1 ] && save_stats
fi
exit 0
