#!/bin/bash
# desk-break — reminder runner (installed to ~/.local/bin/desk-break.sh).
#
# Part of the "desk-break" skill/plugin. On each launchd fire it reads
# ~/.config/desk-break/config.env and, unless you've been idle past the limit,
# shows a movement-break reminder (localized) and optionally plays workout music,
# then stops it. Features: no-equipment exercises by body part with an animated
# demo card, body-part focus (with anti-repetition), persona/time-adaptive copy,
# industry-flavored lines, night mode, streak tracking with completion detection,
# escalating roast on repeated skips, and i18n (en/zh).
#
# Exercise DATA is the MIT-licensed subset of hasaneyldrm/exercises-dataset.
# Demo MEDIA is © Gym visual (https://gymvisual.com/) — referenced by URL only,
# never redistributed. See DATA_NOTICE.md.
#
# Usage:
#   desk-break.sh              normal run (used by launchd)
#   desk-break.sh --test       fast dry-run (ignore idle; ~8s; does NOT touch stats)
#   desk-break.sh --stats      print streak + last-7-days report and exit
#   desk-break.sh --report "<what went wrong>" [--print]

set -u
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
DB_VERSION="0.4.0"

CONFIG="${DESK_BREAK_CONFIG:-$HOME/.config/desk-break/config.env}"
DATA_DIR="$HOME/.config/desk-break"
STATE_DIR="$HOME/.local/share/desk-break"
STATS_FILE="$STATE_DIR/stats.env"
HISTORY_FILE="$STATE_DIR/history.log"
RECENT_FILE="$STATE_DIR/recent.log"
CARD_FILE="$STATE_DIR/card.html"
LOG="$STATE_DIR/reminder.log"
LOCK="/tmp/desk-break.lock"

# ---- built-in fallback defaults (localized strings.env overrides UI strings) ----
IDLE_LIMIT_SECONDS=900
MUSIC_SECONDS=300
DIALOG_TIMEOUT=300
MOOD="energetic"
ENABLE_MUSIC=1
REMINDER_STYLE="dialog"
LOCALE="auto"
REPORT_EMAIL="twillot@outlook.com"
MOVES_FILE=""
PHRASES_FILE=""
# fun pack
SHOW_MOVE=1
MOVE_CATEGORIES=""
PERSONA="random"              # hype | funny | savage | random | off
TIME_ADAPTIVE=1
NIGHT_MODE=1
NIGHT_HOUR=23
TRACK_STATS=1
DETECT_WINDOW=180
COMPLETE_IDLE=90
ESCALATE=1
ESCALATE_AFTER=3
# v0.4: media exercises, focus, industry
SHOW_MEDIA=1
MEDIA_BASE_URL="https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/main/"
FOCUS_PARTS=""                # comma list: core,legs,back,chest,arms,shoulders,cardio
FOCUS_WEIGHT=3
FOCUS_COOLDOWN=2
EXERCISE_RECENT_K=12
INDUSTRY="none"               # dev|design|pm|marketing|writing|sales|finance|student|none
# strings (english fallbacks; strings.env replaces per-locale)
TITLE="🏃 Time to move"
MESSAGE="Step away from the desk and move for a few minutes 💪"
BUTTON="Got it"
SPEAK_TEXT="Time to move"
STR_STREAK_FMT="🔥 {n}-day streak · "
STR_COUNT_FMT="#{n} today"
STR_ESC_FMT="⚠️ Ignored {n}x in a row! "
STR_MOVE_PREFIX="👉 "
STR_SEE_DEMO="↗ see the demo"
STR_CARD_STEPS="Steps"
STR_CARD_PART="Body part"
STR_NIGHT_TITLE="🌙 Time to rest"
STR_NIGHT_BODY_FMT="It's late 😴 Skip the workout and get some sleep. You moved {n} times today."
STR_NIGHT_SPEAK="It's late, time to rest"
STR_CELEBRATE_TITLE="✅ Done!"
STR_CELEBRATE_FMT="#{today} today · 🔥 {streak}-day streak. Keep it up!"
STR_STATS_TITLE="🏃 desk-break stats"
STR_STATS_STREAK="🔥 Streak"
STR_STATS_BEST="best"
STR_STATS_DAYS="days"
STR_STATS_TODAY="📅 Today"
STR_STATS_TODAY_FMT="{c} done / {f} prompts"
STR_STATS_TOTAL="📈 Total"
STR_STATS_TOTAL_FMT="{c} done / {f} prompts ({r}% completion)"
STR_STATS_IGNORE="😴 Current ignore streak"
STR_STATS_TIMES=""
STR_HISTORY_TITLE="📊 Last 7 days"
STR_REPORT_OPENED="Opened a draft email — review and send."
STR_REPORT_SUBJECT="desk-break feedback"

# ---- load config (pass 1: obtain LOCALE + user overrides) ----
[ -f "$CONFIG" ] && . "$CONFIG"

resolve_lang() {
  local l="$LOCALE"
  if [ "$l" = "auto" ] || [ -z "$l" ]; then
    l=$(defaults read -g AppleLocale 2>/dev/null || echo "${LANG:-en}")
  fi
  case "$l" in zh*|*zh_*|*Hans*|*Hant*) echo zh ;; *) echo en ;; esac
}
lang=$(resolve_lang)

# ---- load localized strings, then re-apply config so user overrides win ----
for p in "$DATA_DIR/i18n/$lang/strings.env" "$DATA_DIR/i18n/en/strings.env"; do
  [ -f "$p" ] && { . "$p"; break; }
done
[ -f "$CONFIG" ] && . "$CONFIG"

res_file() {
  local f="$1" p
  for p in "$DATA_DIR/i18n/$lang/$f" "$DATA_DIR/i18n/en/$f" "$DATA_DIR/$f"; do
    [ -f "$p" ] && { echo "$p"; return; }
  done
}
[ -z "$MOVES_FILE" ]   && MOVES_FILE=$(res_file moves.txt)
[ -z "$PHRASES_FILE" ] && PHRASES_FILE=$(res_file phrases.txt)
EXERCISES_FILE=$(res_file exercises.tsv)
INDUSTRY_FILE=$(res_file industry.txt)
ROAST_FILE=$(res_file roast.txt)

MC="$(command -v music-cli 2>/dev/null || echo "$HOME/.local/bin/music-cli")"
mkdir -p "$STATE_DIR" "$DATA_DIR"
ts() { date '+%Y-%m-%d %H:%M:%S'; }
idle_now() { local n; n=$(ioreg -c IOHIDSystem 2>/dev/null | awk '/HIDIdleTime/ {print $NF; exit}'); echo $(( ${n:-0} / 1000000000 )); }
tpl() { local s="$1"; shift; while [ $# -ge 2 ]; do s="${s//\{$1\}/$2}"; shift 2; done; printf '%s' "$s"; }

dialog_box() { osascript -e 'on run {m, t, b, g}' -e 'display dialog m with title t buttons {b} default button b giving up after (g as integer)' -e 'end run' "$1" "$2" "$3" "$4" >/dev/null 2>&1; }
notify_box() { osascript -e 'on run {m, t, s}' -e 'display notification m with title t sound name s' -e 'end run' "$1" "$2" "${3:-Ping}" >/dev/null 2>&1; }

pick_line() { # $1=file $2=filter-ERE (falls back to all)
  local f="$1" filt="${2:-}" lines sub n p
  [ -f "$f" ] || return 1
  lines=$(grep -vE '^[[:space:]]*#' "$f" | grep -vE '^[[:space:]]*$')
  if [ -n "$filt" ]; then sub=$(printf '%s\n' "$lines" | grep -E "$filt"); [ -n "$sub" ] && lines="$sub"; fi
  [ -z "$lines" ] && return 1
  n=$(printf '%s\n' "$lines" | wc -l | tr -d ' ')
  p=$(( (RANDOM % n) + 1 ))
  printf '%s\n' "$lines" | sed -n "${p}p"
}

# ---- exercise selection (focus weighting + anti-frequency) ----
ex_group=""; ex_name=""; ex_gif=""; ex_image=""; ex_steps=""
select_exercise() {
  local f="$EXERCISES_FILE"
  [ -f "$f" ] || return 1
  local cand; cand=$(grep -vE '^[[:space:]]*#' "$f" | grep -vE '^[[:space:]]*$')
  [ -z "$cand" ] && return 1
  # exclude recently shown (by unique gif path) unless that empties the pool
  if [ -f "$RECENT_FILE" ]; then
    local recent_ids; recent_ids=$(tail -n "$EXERCISE_RECENT_K" "$RECENT_FILE" | cut -f2 | grep .)
    if [ -n "$recent_ids" ]; then
      local filtered; filtered=$(printf '%s\n' "$cand" | grep -vF -f <(printf '%s\n' "$recent_ids"))
      [ -n "$filtered" ] && cand="$filtered"
    fi
  fi
  # anti-frequency: if the last FOCUS_COOLDOWN shown were all focus-group,
  # force a NON-focus pick this round so focus can't dominate long runs.
  if [ -n "$FOCUS_PARTS" ] && [ -f "$RECENT_FILE" ]; then
    local lastn cnt=0 total=0 g
    lastn=$(tail -n "$FOCUS_COOLDOWN" "$RECENT_FILE" | cut -f1)
    while IFS= read -r g; do
      [ -z "$g" ] && continue; total=$((total+1))
      case ",$FOCUS_PARTS," in *",$g,"*) cnt=$((cnt+1));; esac
    done <<< "$lastn"
    if [ "$total" -ge "$FOCUS_COOLDOWN" ] && [ "$cnt" -ge "$FOCUS_COOLDOWN" ]; then
      local nf; nf=$(printf '%s\n' "$cand" | grep -vE "^(${FOCUS_PARTS//,/|})$(printf '\t')")
      [ -n "$nf" ] && cand="$nf"
    fi
  fi
  # weighted pool (focus groups weighted up by FOCUS_WEIGHT)
  local -a pool=(); local line grp w i
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    grp="${line%%$'\t'*}"; w=1
    if [ -n "$FOCUS_PARTS" ]; then case ",$FOCUS_PARTS," in *",$grp,"*) w=$FOCUS_WEIGHT;; esac; fi
    i=0; while [ "$i" -lt "$w" ]; do pool+=("$line"); i=$((i+1)); done
  done <<< "$cand"
  local n=${#pool[@]}; [ "$n" -eq 0 ] && return 1
  local sel="${pool[$((RANDOM % n))]}" rest
  ex_group="${sel%%$'\t'*}"; rest="${sel#*$'\t'}"
  ex_name="${rest%%$'\t'*}"; rest="${rest#*$'\t'}"
  ex_gif="${rest%%$'\t'*}";  rest="${rest#*$'\t'}"
  ex_image="${rest%%$'\t'*}"; ex_steps="${rest#*$'\t'}"
  # record (skip in test so anti-frequency history stays clean)
  if [ "${TEST:-0}" != 1 ]; then
    printf '%s\t%s\n' "$ex_group" "$ex_gif" >> "$RECENT_FILE"
    local keep=$(( EXERCISE_RECENT_K * 3 )) totl; totl=$(wc -l < "$RECENT_FILE" 2>/dev/null || echo 0)
    if [ "$totl" -gt "$keep" ]; then tail -n "$keep" "$RECENT_FILE" > "$RECENT_FILE.tmp" && mv "$RECENT_FILE.tmp" "$RECENT_FILE"; fi
  fi
  return 0
}

# ---- animated demo card (browser) ----
media_card() {
  DB_NAME="$ex_name" DB_GIF="${MEDIA_BASE_URL}${ex_gif}" DB_STEPS="$ex_steps" \
  DB_PART="$ex_group" DB_L_STEPS="$STR_CARD_STEPS" DB_L_PART="$STR_CARD_PART" \
  python3 - "$CARD_FILE" <<'PY'
import os,sys,html
p=sys.argv[1]
name=html.escape(os.environ.get("DB_NAME","")); gif=html.escape(os.environ.get("DB_GIF",""))
part=html.escape(os.environ.get("DB_PART","")); steps=[s for s in os.environ.get("DB_STEPS","").split("¶") if s.strip()]
ls=html.escape(os.environ.get("DB_L_STEPS","Steps")); lp=html.escape(os.environ.get("DB_L_PART","Body part"))
li="".join("<li>%s</li>"%html.escape(s) for s in steps)
doc="""<!doctype html><html><head><meta charset=utf-8><title>%s · desk-break</title><style>
body{margin:0;background:#0d1117;color:#e6edf3;font:16px/1.6 -apple-system,system-ui,'PingFang SC',sans-serif;display:flex;justify-content:center}
.card{max-width:520px;padding:28px 24px;text-align:center}
h1{font-size:22px;margin:0 0 4px}.part{color:#7d8590;font-size:13px;margin-bottom:16px;text-transform:capitalize}
img{width:260px;height:260px;object-fit:contain;background:#161b22;border-radius:14px}
.err{display:none;color:#7d8590;font-size:13px;padding:24px}
ol{text-align:left;margin:18px auto 0;max-width:440px}li{margin:6px 0}
.h{text-align:left;color:#7d8590;font-size:12px;text-transform:uppercase;letter-spacing:.05em;margin:20px 0 6px}
footer{margin-top:24px;color:#6e7681;font-size:11px;line-height:1.8}a{color:#6e7681}
</style></head><body><div class=card>
<h1>%s</h1><div class=part>%s: %s</div>
<img src="%s" alt="%s" onerror="this.style.display='none';document.getElementById('e').style.display='block'">
<div id=e class=err>(animation needs a connection · 动图需联网 — steps below)</div>
<div class=h>%s</div><ol>%s</ol>
<footer>© Gym visual — <a href="https://gymvisual.com/">gymvisual.com</a><br>exercise data: hasaneyldrm/exercises-dataset (MIT)</footer>
</div></body></html>"""%(name,name,lp,part,gif,name,ls,li)
open(p,"w",encoding="utf-8").write(doc)
PY
  open "$CARD_FILE" >/dev/null 2>&1
}

# ---- --pick (debug: print one selected exercise as group<TAB>name) ----
if [ "${1:-}" = "--pick" ]; then
  if select_exercise; then printf '%s\t%s\n' "$ex_group" "$ex_name"; else echo "NONE"; fi
  exit 0
fi

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
effective_streak() {
  local today yday; today=$(date +%Y-%m-%d); yday=$(date -v-1d +%Y-%m-%d 2>/dev/null)
  if [ "$LAST_COMPLETE_DATE" = "$today" ] || [ "$LAST_COMPLETE_DATE" = "$yday" ]; then echo "$STREAK"; else echo 0; fi
}
print_stats() {
  load_stats; local es rate; es=$(effective_streak)
  rate=0; [ "$TOTAL_FIRED" -gt 0 ] && rate=$(( TOTAL_COMPLETED * 100 / TOTAL_FIRED ))
  echo "$STR_STATS_TITLE"
  echo "  $STR_STATS_STREAK: ${es} $STR_STATS_DAYS   (${STR_STATS_BEST} ${BEST_STREAK} $STR_STATS_DAYS)"
  echo "  $STR_STATS_TODAY: $(tpl "$STR_STATS_TODAY_FMT" c "$TODAY_COMPLETED" f "$TODAY_FIRED")"
  echo "  $STR_STATS_TOTAL: $(tpl "$STR_STATS_TOTAL_FMT" c "$TOTAL_COMPLETED" f "$TOTAL_FIRED" r "$rate")"
  echo "  $STR_STATS_IGNORE: ${IGNORE_RUN} $STR_STATS_TIMES"
  if [ -f "$HISTORY_FILE" ]; then
    echo; echo "$STR_HISTORY_TITLE"; local i day c bar
    for i in 6 5 4 3 2 1 0; do
      day=$(date -v-${i}d +%Y-%m-%d 2>/dev/null)
      c=$(awk -F'\t' -v d="$day" '$1==d && $3=="completed"{n++} END{print n+0}' "$HISTORY_FILE")
      bar=""; [ "$c" -gt 0 ] && bar=$(printf '█%.0s' $(seq 1 $(( c>20 ? 20 : c )) ))
      printf "  %s  %-20s %s\n" "$day" "$bar" "$c"
    done
  fi
}

# ---- --stats ----
if [ "${1:-}" = "--stats" ]; then print_stats; exit 0; fi

# ---- --report ----
if [ "${1:-}" = "--report" ]; then
  desc="${2:-}"; printonly=0
  [ "${2:-}" = "--print" ] && { desc=""; printonly=1; }
  [ "${3:-}" = "--print" ] && printonly=1
  os="$(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null)"
  cfg=$(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$CONFIG" 2>/dev/null | tr '\n' ';')
  logtail=$(tail -n 15 "$LOG" 2>/dev/null)
  body="[desk-break v$DB_VERSION report]

What happened:
${desc:-<describe the problem here>}

--- diagnostics (feel free to trim) ---
OS: $os
locale: $lang   (LOCALE=$LOCALE)
config: $cfg

recent log:
$logtail

stats:
$(print_stats)
"
  enc() { python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.stdin.read()))'; }
  subj=$(printf '%s' "$STR_REPORT_SUBJECT" | enc); bodye=$(printf '%s' "$body" | enc)
  url="mailto:${REPORT_EMAIL}?subject=${subj}&body=${bodye}"
  if [ "$printonly" = 1 ]; then echo "$url"; else open "$url" >/dev/null 2>&1 && echo "$STR_REPORT_OPENED ($REPORT_EMAIL)"; fi
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

# ---- choose exercise (dataset+media) or fall back to a text move card ----
move=""; have_media=0
if [ "$SHOW_MEDIA" = 1 ] && [ "$night" != 1 ] && select_exercise; then
  move="$ex_name"; have_media=1
fi
if [ -z "$move" ] && [ "$SHOW_MOVE" = 1 ]; then
  mfilt=""; [ -n "$cat_filter" ] && mfilt="^(${cat_filter})\\|"
  msel=$(pick_line "$MOVES_FILE" "$mfilt") && move="${msel#*|}"
fi

# ---- stats + daily reset ----
load_stats
today=$(date +%Y-%m-%d)
if [ "$TODAY_DATE" != "$today" ]; then TODAY_DATE="$today"; TODAY_COMPLETED=0; TODAY_FIRED=0; fi

# ---- escalation (+ roast tier) ----
escalated=0; roast_tier=0
if [ "$ESCALATE" = 1 ] && [ "$night" != 1 ] && [ "$IGNORE_RUN" -ge "$ESCALATE_AFTER" ]; then
  escalated=1; REMINDER_STYLE="dialog+say"; MOOD="excited"
  roast_tier=$(( IGNORE_RUN - ESCALATE_AFTER + 1 )); [ "$roast_tier" -gt 3 ] && roast_tier=3
fi

# ---- pick copy: roast > industry > persona > plain ----
persona="$PERSONA"
[ "$persona" = "random" ] && { parr=("hype" "funny" "savage"); persona="${parr[$((RANDOM % 3))]}"; }
phrase=""; copy_src="persona"
if [ "$escalated" = 1 ] && [ "$roast_tier" -ge 1 ]; then
  rsel=$(pick_line "$ROAST_FILE" "^${roast_tier}\\|") && { phrase="${rsel#*|}"; persona="savage"; copy_src="roast"; }
fi
if [ -z "$phrase" ] && [ "$INDUSTRY" != "none" ] && [ -n "$INDUSTRY" ] && [ $((RANDOM % 5)) -lt 2 ]; then
  isel=$(pick_line "$INDUSTRY_FILE" "^${INDUSTRY}\\|") && { phrase="${isel#*|}"; copy_src="industry"; }
fi
if [ -z "$phrase" ] && [ "$PERSONA" != "off" ]; then
  psel=$(pick_line "$PHRASES_FILE" "^${persona}\\|") && phrase="${psel#*|}"
fi
if [ -n "$phrase" ]; then
  if [[ "$phrase" == *"{move}"* ]]; then body="${phrase//\{move\}/$move}"
  else body="$phrase"; [ -n "$move" ] && body="${phrase}"$'\n'"${STR_MOVE_PREFIX}${move}"; fi
else
  body="$MESSAGE"; [ -n "$move" ] && body="${MESSAGE}"$'\n'"${STR_MOVE_PREFIX}${move}"
fi
[ "$have_media" = 1 ] && [ "$night" != 1 ] && body="${body}"$'\n'"${STR_SEE_DEMO}"

# ---- night override ----
if [ "$night" = 1 ]; then
  TITLE="$STR_NIGHT_TITLE"; body=$(tpl "$STR_NIGHT_BODY_FMT" n "$TODAY_COMPLETED"); SPEAK_TEXT="$STR_NIGHT_SPEAK"
fi

# ---- header ----
header=""
if [ "$TRACK_STATS" = 1 ] && [ "$night" != 1 ]; then
  es=$(effective_streak)
  [ "$es" -gt 0 ] && header=$(tpl "$STR_STREAK_FMT" n "$es")
  header="${header}$(tpl "$STR_COUNT_FMT" n "$((TODAY_FIRED + 1))")"
  [ "$escalated" = 1 ] && header="$(tpl "$STR_ESC_FMT" n "$IGNORE_RUN")${header}"
fi
if [ -n "$header" ]; then final_msg="${header}"$'\n'"${body}"; else final_msg="$body"; fi

# ---- spoken ----
spoken="$SPEAK_TEXT"
if [ "$night" != 1 ] && [ -n "$move" ]; then spoken="${SPEAK_TEXT},${move%%[:,，]*}"; fi

# ---- count this fire ----
TOTAL_FIRED=$((TOTAL_FIRED + 1)); TODAY_FIRED=$((TODAY_FIRED + 1))
echo "$(ts) fire: idle ${idle_sec}s lang=$lang period=$period night=$night persona=$persona copy=$copy_src style=$REMINDER_STYLE mood=$MOOD esc=$escalated tier=$roast_tier media=$have_media move='${move}'" >> "$LOG"

# ---- music ----
music_on=0
if [ "$ENABLE_MUSIC" = 1 ] && [ -x "$MC" ]; then "$MC" mood "$MOOD" >> "$LOG" 2>&1 & music_on=1; fi

# ---- reminders ----
[ "$have_media" = 1 ] && [ "$night" != 1 ] && media_card
SAY_PID=""
case "$REMINDER_STYLE" in *notification*) notify_box "$final_msg" "$TITLE" "Ping" ;; esac
case "$REMINDER_STYLE" in *say*) [ -n "$spoken" ] && { say "$spoken" >/dev/null 2>&1 & SAY_PID=$!; } ;; esac
dialog_secs=$DIALOG_TIMEOUT
[ "$music_on" = 1 ] && dialog_secs=$MUSIC_SECONDS
if [ "$TRACK_STATS" = 1 ] && [ "$night" != 1 ] && [ "$DETECT_WINDOW" -gt "$dialog_secs" ]; then dialog_secs=$DETECT_WINDOW; fi
case "$REMINDER_STYLE" in *dialog*) dialog_box "$final_msg" "$TITLE" "$BUTTON" "$dialog_secs" & ;; esac

# ---- hold window: music + idle watch ----
hold=0
[ "$music_on" = 1 ] && hold=$MUSIC_SECONDS
if [ "$TRACK_STATS" = 1 ] && [ "$night" != 1 ] && [ "$DETECT_WINDOW" -gt "$hold" ]; then hold=$DETECT_WINDOW; fi
if [ "$hold" -eq 0 ]; then case "$REMINDER_STYLE" in *dialog*) hold=$dialog_secs ;; esac; fi

max_idle=0; music_stopped=0; elapsed=0
STEP=15; [ "$TEST" = 1 ] && STEP=2
while [ "$elapsed" -lt "$hold" ]; do
  cur=$(idle_now); [ "$cur" -gt "$max_idle" ] && max_idle=$cur
  if [ "$music_on" = 1 ] && [ "$music_stopped" = 0 ] && [ "$elapsed" -ge "$MUSIC_SECONDS" ]; then "$MC" stop >> "$LOG" 2>&1; music_stopped=1; fi
  sleep "$STEP"; elapsed=$(( elapsed + STEP ))
done
if [ "$music_on" = 1 ] && [ "$music_stopped" = 0 ]; then "$MC" stop >> "$LOG" 2>&1; fi
[ -n "$SAY_PID" ] && wait "$SAY_PID" 2>/dev/null

# ---- completion detection + stats + history ----
if [ "$TRACK_STATS" = 1 ] && [ "$night" != 1 ]; then
  completed=0; [ "$max_idle" -ge "$COMPLETE_IDLE" ] && completed=1
  if [ "$TEST" = 1 ]; then
    echo "$(ts) result(test): completed=$completed max_idle=${max_idle}s (stats not saved)" >> "$LOG"
  else
    status="ignored"
    if [ "$completed" = 1 ]; then
      status="completed"
      TOTAL_COMPLETED=$((TOTAL_COMPLETED + 1)); TODAY_COMPLETED=$((TODAY_COMPLETED + 1)); IGNORE_RUN=0
      yday=$(date -v-1d +%Y-%m-%d 2>/dev/null)
      if   [ "$LAST_COMPLETE_DATE" = "$today" ]; then :
      elif [ "$LAST_COMPLETE_DATE" = "$yday" ];  then STREAK=$((STREAK + 1))
      else STREAK=1; fi
      LAST_COMPLETE_DATE="$today"; [ "$STREAK" -gt "$BEST_STREAK" ] && BEST_STREAK=$STREAK
      es=$(effective_streak)
      notify_box "$(tpl "$STR_CELEBRATE_FMT" today "$TODAY_COMPLETED" streak "$es")" "$STR_CELEBRATE_TITLE" "Glass"
    else
      TOTAL_IGNORED=$((TOTAL_IGNORED + 1)); IGNORE_RUN=$((IGNORE_RUN + 1))
    fi
    save_stats
    printf '%s\t%s\t%s\t%s\n' "$today" "$(date +%H:%M)" "$status" "$move" >> "$HISTORY_FILE"
    echo "$(ts) result: completed=$completed max_idle=${max_idle}s streak=$STREAK ignore_run=$IGNORE_RUN" >> "$LOG"
  fi
else
  [ "$TEST" != 1 ] && save_stats
fi
exit 0
