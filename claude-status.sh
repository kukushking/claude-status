#!/usr/bin/env bash
# claude-status — Live token burn status line for Claude Code
# https://github.com/kukushking/claude-status

INPUT=$(cat)

eval "$(echo "$INPUT" | python3 -c "
import json, sys, time

data = json.load(sys.stdin)
cw = data.get('context_window', {})
cost_data = data.get('cost', {})
current = cw.get('current_usage', {}) or {}

inp = current.get('input_tokens', 0)
out = current.get('output_tokens', 0)
cache_create = current.get('cache_creation_input_tokens', 0)
cache_read = current.get('cache_read_input_tokens', 0)

total_in = cw.get('total_input_tokens', 0)
total_out = cw.get('total_output_tokens', 0)
used_pct = cw.get('used_percentage', 0)
window_size = cw.get('context_window_size', 0)

total_cost = cost_data.get('total_cost_usd', 0)
duration_ms = cost_data.get('total_duration_ms', 0)
lines_added = cost_data.get('total_lines_added', 0)
lines_removed = cost_data.get('total_lines_removed', 0)

mins = int(duration_ms // 60000)
secs = int((duration_ms % 60000) // 1000)

def fmt(n):
    if n >= 1_000_000:
        return f'{n/1_000_000:.1f}M'
    elif n >= 1_000:
        return f'{n/1_000:.1f}K'
    return str(n)

def fmt_eta(target):
    if not target:
        return ''
    delta = int(target - time.time())
    if delta <= 0:
        return 'now'
    if delta < 60:
        return f'{delta}s'
    if delta < 3600:
        return f'{delta//60}m'
    if delta < 86400:
        h = delta // 3600
        m = (delta % 3600) // 60
        return f'{h}h{m:02d}m'
    d = delta // 86400
    h = (delta % 86400) // 3600
    return f'{d}d{h}h'

rl = data.get('rate_limits') or {}
fh = rl.get('five_hour') or {}
sd = rl.get('seven_day') or {}
fh_pct = fh.get('used_percentage')
sd_pct = sd.get('used_percentage')
fh_pct_s = '' if fh_pct is None else f'{fh_pct:.1f}'
sd_pct_s = '' if sd_pct is None else f'{sd_pct:.1f}'

print(f'INP={fmt(inp)}')
print(f'OUT={fmt(out)}')
print(f'CACHE_CREATE={fmt(cache_create)}')
print(f'CACHE_READ={fmt(cache_read)}')
print(f'TOTAL_IN={fmt(total_in)}')
print(f'TOTAL_OUT={fmt(total_out)}')
print(f'USED_PCT={used_pct:.1f}')
print(f'COST={total_cost:.4f}')
print(f'DURATION={mins}m{secs:02d}s')
print(f'LINES_ADDED={lines_added}')
print(f'LINES_REMOVED={lines_removed}')
print(f'WINDOW_SIZE={fmt(window_size)}')
print(f'USED_PCT_RAW={used_pct}')
print(f'RL_5H_PCT={fh_pct_s}')
print(f'RL_5H_ETA={fmt_eta(fh.get(\"resets_at\"))}')
print(f'RL_7D_PCT={sd_pct_s}')
print(f'RL_7D_ETA={fmt_eta(sd.get(\"resets_at\"))}')
" 2>/dev/null)"

if [ -z "$COST" ]; then
  echo "waiting for data..."
  exit 0
fi

# ── colors ──────────────────────────────────────────────
RST="\033[0m"
B="\033[1m"
D="\033[2m"
RED="\033[31m"
GRN="\033[32m"
YLW="\033[33m"
BLU="\033[34m"
MAG="\033[35m"
CYN="\033[36m"
WHT="\033[37m"
BRED="\033[91m"
BGRN="\033[92m"
BYLW="\033[93m"
BCYN="\033[96m"
BWHT="\033[97m"

# ── cost color ──────────────────────────────────────────
COST_NUM=$(echo "$COST" | sed 's/[^0-9.]//g')
if (( $(echo "$COST_NUM > 1.0" | bc -l 2>/dev/null || echo 0) )); then
  CC="$BRED"
elif (( $(echo "$COST_NUM > 0.25" | bc -l 2>/dev/null || echo 0) )); then
  CC="$BYLW"
else
  CC="$BGRN"
fi

# ── context bar ─────────────────────────────────────────
BAR_W=20
PCT_INT=$(echo "$USED_PCT_RAW" | cut -d. -f1)
FILLED=$(( (PCT_INT * BAR_W + 99) / 100 ))
[ "$FILLED" -gt "$BAR_W" ] && FILLED=$BAR_W

if [ "$PCT_INT" -ge 80 ]; then
  BC="$RED"
elif [ "$PCT_INT" -ge 50 ]; then
  BC="$YLW"
else
  BC="$GRN"
fi

BAR=""
for ((i=0; i<FILLED; i++)); do BAR+="▰"; done
for ((i=FILLED; i<BAR_W; i++)); do BAR+="▱"; done

# ── separator ───────────────────────────────────────────
S="${D}  ┊  ${RST}"

# ── line 1: current request ─────────────────────────────
printf "${B}${BCYN}▍${RST}"
printf "${D} in ${RST}${B}${BWHT}%-7s${RST}" "$INP"
printf "${D} out ${RST}${B}${BWHT}%-7s${RST}" "$OUT"
printf "$S"
printf "${D}cache ${RST}${BGRN}%s ${RST}${D}▾${RST}  ${MAG}%s ${RST}${D}▴${RST}" "$CACHE_READ" "$CACHE_CREATE"
printf "$S"
printf "${B}${CC}\$%s${RST}" "$COST"
printf "${D}  %s${RST}" "$DURATION"
echo ""

# ── line 2: session totals ──────────────────────────────
printf "${B}${BLU}▍${RST}"
printf "${D} Σ  ${RST}${BWHT}%-7s${RST}" "$TOTAL_IN"
printf "${D}     ${RST}${BWHT}%-7s${RST}" "$TOTAL_OUT"
printf "$S"
printf "${BC}%s${RST} ${B}%s%%${RST}${D} of %s${RST}" "$BAR" "$USED_PCT" "$WINDOW_SIZE"
printf "$S"
printf "${BGRN}+%s${RST} ${BRED}−%s${RST}" "$LINES_ADDED" "$LINES_REMOVED"
echo ""

# ── line 3: Claude.ai rate limits (when present) ────────
print_rl() {
  local label="$1" pct="$2" eta="$3"
  local pct_int="${pct%%.*}"
  [ -z "$pct_int" ] && pct_int=0
  local w=10
  local filled=$(( (pct_int * w + 99) / 100 ))
  [ "$filled" -gt "$w" ] && filled=$w
  local color
  if   [ "$pct_int" -ge 80 ]; then color="$RED"
  elif [ "$pct_int" -ge 50 ]; then color="$YLW"
  else color="$GRN"
  fi
  local bar="" i
  for ((i=0; i<filled; i++)); do bar+="▰"; done
  for ((i=filled; i<w; i++)); do bar+="▱"; done
  printf "${D}%s ${RST}${color}%s${RST} ${B}%s%%${RST}" "$label" "$bar" "$pct"
  [ -n "$eta" ] && printf "${D} ⟳%s${RST}" "$eta"
}

if [ -n "$RL_5H_PCT" ] || [ -n "$RL_7D_PCT" ]; then
  printf "${B}${MAG}▍${RST}"
  [ -n "$RL_5H_PCT" ] && { printf " "; print_rl "5h " "$RL_5H_PCT" "$RL_5H_ETA"; }
  [ -n "$RL_5H_PCT" ] && [ -n "$RL_7D_PCT" ] && printf "$S"
  [ -n "$RL_7D_PCT" ] && { [ -z "$RL_5H_PCT" ] && printf " "; print_rl "7d " "$RL_7D_PCT" "$RL_7D_ETA"; }
  echo ""
fi
