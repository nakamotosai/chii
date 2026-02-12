#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${CODEX_HOOK_CONFIG:-/home/ubuntu/.openclaw/workspace/config/codex-hook.env}"
if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

OPENCLAW_BIN="${OPENCLAW_BIN:-/home/ubuntu/.npm-global/bin/openclaw}"
CODEX_BIN="${CODEX_BIN:-codex}"
DEFAULT_WORKSPACE="${CODEX_WORKSPACE:-/home/ubuntu/.openclaw/codex-worker}"
PRIMARY_WORKSPACE="${CODEX_PRIMARY_WORKSPACE:-/home/ubuntu/.openclaw/workspace}"
DEFAULT_MODEL="${CODEX_MODEL:-gpt-5.1-codex-mini}"
DEFAULT_TARGET="${CHII_OWNER_TELEGRAM_TARGET:-8138445887}"
JOB_DIR="${CODEX_HOOK_JOB_DIR:-/tmp/codex-hook-jobs}"
SKIP_GIT_REPO_CHECK="${CODEX_SKIP_GIT_REPO_CHECK:-1}"
NOTIFY_MODE="${CODEX_HOOK_NOTIFY_MODE:-detailed}"   # short | long | smart | detailed
SUMMARY_CHARS="${CODEX_HOOK_SUMMARY_CHARS:-180}"
DETAIL_CHARS="${CODEX_HOOK_DETAIL_CHARS:-12000}"
DETAIL_CHUNK_CHARS="${CODEX_HOOK_DETAIL_CHUNK_CHARS:-3200}"

usage() {
  cat <<'EOF'
Usage:
  codex_hook.sh --start-hook "task" [model]
  codex_hook.sh --start --task "task" [--model MODEL] [--workspace DIR]
                [--target TELEGRAM_ID] [--from-agent NAME] [--notify-start]
EOF
}

TASK=""
MODEL="$DEFAULT_MODEL"
WORKSPACE="$DEFAULT_WORKSPACE"
TARGET="$DEFAULT_TARGET"
CHANNEL="telegram"
FROM_AGENT="unknown-agent"
NOTIFY_START=0

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

if [[ "${1:-}" == "--start-hook" ]]; then
  TASK="${2:-}"
  MODEL="${3:-$DEFAULT_MODEL}"
  shift $(( $# > 2 ? 3 : $# )) || true
else
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --start) shift ;;
      --task) TASK="${2:-}"; shift 2 ;;
      --task-file) TASK="$(cat "${2:?missing task file}")"; shift 2 ;;
      --model) MODEL="${2:?missing model}"; shift 2 ;;
      --workspace) WORKSPACE="${2:?missing workspace}"; shift 2 ;;
      --target) TARGET="${2:?missing telegram target}"; shift 2 ;;
      --from-agent) FROM_AGENT="${2:?missing agent name}"; shift 2 ;;
      --notify-start) NOTIFY_START=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
    esac
  done
fi

if [[ -z "$TASK" ]]; then
  echo "ERROR: empty task" >&2
  exit 2
fi

command -v "$CODEX_BIN" >/dev/null 2>&1 || { echo "ERROR: codex not found" >&2; exit 3; }
command -v "$OPENCLAW_BIN" >/dev/null 2>&1 || { echo "ERROR: openclaw not found" >&2; exit 3; }
mkdir -p "$JOB_DIR"

JOB_ID="$(date -u +%Y%m%dT%H%M%SZ)-$RANDOM"
PROMPT_FILE="$JOB_DIR/$JOB_ID.prompt.txt"
RESULT_FILE="$JOB_DIR/$JOB_ID.result.txt"
STATUS_FILE="$JOB_DIR/$JOB_ID.status.json"
LOG_FILE="$JOB_DIR/$JOB_ID.log"
CLEAN_RESULT_FILE="$JOB_DIR/$JOB_ID.clean.txt"
BODY_FILE="$JOB_DIR/$JOB_ID.body.txt"

# Force codex to return only final deliverable text.
EXEC_TASK=$'请只输出最终可交付的正文内容。\n禁止输出任何思考过程、系统指令、工具调用记录、执行日志、模型/环境信息。\n\n任务如下：\n'"$TASK"
printf "%s\n" "$EXEC_TASK" > "$PROMPT_FILE"
START_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

notify() {
  local text="$1"
  "$OPENCLAW_BIN" message send --channel "$CHANNEL" --target "$TARGET" --message "$text" >/dev/null
}

if [[ "$NOTIFY_START" -eq 1 ]]; then
  notify "ちぃ收到任务，正在异步执行。"
fi

(
  set +e
  RUN_START_EPOCH=$(date +%s)

  if [[ "$SKIP_GIT_REPO_CHECK" == "1" ]]; then
    printf '%s\n' "$EXEC_TASK" | "$CODEX_BIN" exec -m "$MODEL" --sandbox workspace-write --skip-git-repo-check -C "$WORKSPACE" --add-dir "$PRIMARY_WORKSPACE" >"$RESULT_FILE" 2>&1
  else
    printf '%s\n' "$EXEC_TASK" | "$CODEX_BIN" exec -m "$MODEL" --sandbox workspace-write -C "$WORKSPACE" --add-dir "$PRIMARY_WORKSPACE" >"$RESULT_FILE" 2>&1
  fi
  EXIT_CODE=$?

  RUN_END_EPOCH=$(date +%s)
  DURATION=$((RUN_END_EPOCH - RUN_START_EPOCH))
  END_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  sed 's/\x1b\[[0-9;]*m//g' "$RESULT_FILE" | tr -d '\r' > "$CLEAN_RESULT_FILE"

  # Extract final body only: drop codex runtime banners/system-like lines.
  python3 - "$CLEAN_RESULT_FILE" "$BODY_FILE" "$PROMPT_FILE" <<'PY'
import re, sys
from pathlib import Path
src = Path(sys.argv[1]).read_text(encoding='utf-8', errors='ignore').splitlines()
prompt_lines = {ln.strip() for ln in Path(sys.argv[3]).read_text(encoding='utf-8', errors='ignore').splitlines() if ln.strip()}
out = []
skip_prefix = (
    'Reading prompt from stdin...',
    'OpenAI Codex',
    'workdir:',
    'model:',
    'provider:',
    'approval:',
    'sandbox:',
    'session id:',
    'tokens used:',
    'cost:',
    'mcp startup:',
)
skip_exact = {'user', 'assistant', 'tool', 'codex'}
for ln in src:
    s = ln.strip()
    if not s:
        out.append('')
        continue
    low = s.lower()
    if s == '--------':
        continue
    if s.startswith(skip_prefix):
        continue
    if low in skip_exact:
        continue
    if s in prompt_lines:
        continue
    if low.startswith('thinking') or low.startswith('reasoning'):
        continue
    if low.startswith('tokens used'):
        continue
    if 'token' in low and any(ch.isdigit() for ch in s):
        continue
    if low.startswith('usage:') or low.startswith('stats:') or low.startswith('duration:'):
        continue
    if low.startswith('**preparing'):
        continue
    if s.startswith('**') and s.endswith('**'):
        continue
    if 'error codex_core::rollout::list' in low:
        continue
    if s.startswith('🌐') or s.startswith('🔧') or s.startswith('⚠️'):
        continue
    if 'system prompt' in low or 'toolcall' in low or 'tool call' in low:
        continue
    out.append(ln)
# trim leading/trailing blank lines
while out and not out[0].strip():
    out.pop(0)
while out and not out[-1].strip():
    out.pop()
# remove standalone numeric telemetry lines
out = [ln for ln in out if not re.fullmatch(r'\s*[\d,]+(?:\.\d+)?\s*', ln)]

# trim again after numeric cleanup
while out and not out[0].strip():
    out.pop(0)
while out and not out[-1].strip():
    out.pop()

# collapse consecutive duplicate lines
collapsed = []
for ln in out:
    if collapsed and collapsed[-1] == ln:
        continue
    collapsed.append(ln)
out = collapsed

# if answer is duplicated as two identical halves, keep first half
if len(out) % 2 == 0 and len(out) > 2:
    half = len(out) // 2
    if out[:half] == out[half:]:
        out = out[:half]

# global de-dup for non-empty lines
seen = set()
uniq = []
for ln in out:
    key = ln.strip()
    if not key:
        uniq.append(ln)
        continue
    if key in seen:
        continue
    seen.add(key)
    uniq.append(ln)
out = uniq

text = '\n'.join(out).strip()

if not text:
    text = '(no output)'
Path(sys.argv[2]).write_text(text, encoding='utf-8')
PY

  SUMMARY_LINE="$(awk 'NF {print; exit}' "$BODY_FILE")"
  if [[ -z "$SUMMARY_LINE" ]]; then
    SUMMARY_LINE="(no output)"
  fi
  SUMMARY_TRIMMED="$(printf '%s' "$SUMMARY_LINE" | awk -v n="$SUMMARY_CHARS" '{ if (length($0)>n) print substr($0,1,n) "..."; else print $0 }')"

  if [[ "$EXIT_CODE" -eq 0 ]]; then
    STATUS="success"
  else
    STATUS="failed"
  fi

  EFFECTIVE_NOTIFY_MODE="$NOTIFY_MODE"
  if [[ "$NOTIFY_MODE" == "smart" ]]; then
    EFFECTIVE_NOTIFY_MODE="detailed"
  fi

  NOTIFY_OK=1
  DETAIL_PARTS=0

  if [[ "$EFFECTIVE_NOTIFY_MODE" == "short" ]]; then
    if [[ "$EXIT_CODE" -eq 0 ]]; then
      notify "$SUMMARY_TRIMMED" || NOTIFY_OK=0
    else
      notify "任务失败（exit=$EXIT_CODE）：$SUMMARY_TRIMMED" || NOTIFY_OK=0
    fi

  elif [[ "$EFFECTIVE_NOTIFY_MODE" == "long" || "$EFFECTIVE_NOTIFY_MODE" == "detailed" ]]; then
    python3 - "$BODY_FILE" "$JOB_DIR" "$JOB_ID" "$DETAIL_CHARS" "$DETAIL_CHUNK_CHARS" <<'PY'
import sys
from pathlib import Path
src = Path(sys.argv[1])
outdir = Path(sys.argv[2])
job = sys.argv[3]
detail_chars = int(sys.argv[4])
chunk_chars = int(sys.argv[5])
text = src.read_text(encoding='utf-8', errors='ignore')
if len(text) > detail_chars:
    text = text[-detail_chars:]
chunks = []
while text:
    chunks.append(text[:chunk_chars])
    text = text[chunk_chars:]
if not chunks:
    chunks = ['(no output)']
for i, c in enumerate(chunks, 1):
    p = outdir / f"{job}.part{i:03d}.txt"
    p.write_text(c, encoding='utf-8')
print(len(chunks))
PY

    DETAIL_PARTS=$(ls -1 "$JOB_DIR/$JOB_ID".part*.txt 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$DETAIL_PARTS" -eq 0 ]]; then
      DETAIL_PARTS=1
      echo "(no output)" > "$JOB_DIR/$JOB_ID.part001.txt"
    fi

    for f in "$JOB_DIR/$JOB_ID".part*.txt; do
      part_text="$(cat "$f")"
      notify "$part_text" || NOTIFY_OK=0
    done
  else
    notify "$SUMMARY_TRIMMED" || NOTIFY_OK=0
  fi

  SUMMARY_ESCAPED="$(printf '%s' "$SUMMARY_TRIMMED" | sed 's/\\/\\\\/g; s/"/\\"/g')"

  cat > "$STATUS_FILE" <<JSON
{
  "job_id": "$JOB_ID",
  "from_agent": "$FROM_AGENT",
  "model": "$MODEL",
  "workspace": "$WORKSPACE",
  "primary_workspace": "$PRIMARY_WORKSPACE",
  "target": "$TARGET",
  "start_ts": "$START_TS",
  "end_ts": "$END_TS",
  "duration_sec": $DURATION,
  "exit_code": $EXIT_CODE,
  "status": "$STATUS",
  "notify_ok": $NOTIFY_OK,
  "notify_mode": "$NOTIFY_MODE",
  "effective_notify_mode": "$EFFECTIVE_NOTIFY_MODE",
  "detail_parts": $DETAIL_PARTS,
  "summary": "$SUMMARY_ESCAPED",
  "prompt_file": "$PROMPT_FILE",
  "result_file": "$RESULT_FILE",
  "clean_result_file": "$CLEAN_RESULT_FILE",
  "body_file": "$BODY_FILE"
}
JSON

  echo "job=$JOB_ID status=$STATUS exit=$EXIT_CODE notify_ok=$NOTIFY_OK mode=$NOTIFY_MODE effective=$EFFECTIVE_NOTIFY_MODE detail_parts=$DETAIL_PARTS" >> "$LOG_FILE"
) >/dev/null 2>&1 &

BG_PID=$!
disown "$BG_PID" || true

echo "status: accepted"
echo "job_id: $JOB_ID"
echo "pid: $BG_PID"
echo "result_file: $RESULT_FILE"
echo "status_file: $STATUS_FILE"
echo "next: no polling needed; codex will notify telegram on completion"
