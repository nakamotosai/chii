#!/usr/bin/env bash
set -euo pipefail

# Async Codex hook runner:
# - starts a Codex task in background
# - no polling
# - sends completion message directly to Telegram via openclaw CLI

OPENCLAW_BIN="${OPENCLAW_BIN:-/home/ubuntu/.npm-global/bin/openclaw}"
CODEX_BIN="${CODEX_BIN:-codex}"
DEFAULT_WORKSPACE="${CODEX_WORKSPACE:-/home/ubuntu/.openclaw/workspace}"
DEFAULT_MODEL="${CODEX_MODEL:-gpt-5.1-codex-mini}"
DEFAULT_TARGET="${CHII_OWNER_TELEGRAM_TARGET:-8138445887}"
JOB_DIR="${CODEX_HOOK_JOB_DIR:-/tmp/codex-hook-jobs}"

usage() {
  cat <<'EOF'
Usage:
  codex_hook.sh --start-hook "task" [model]
  codex_hook.sh --start --task "task" [--model MODEL] [--workspace DIR]
                [--target TELEGRAM_ID] [--from-agent NAME] [--notify-start]

Behavior:
  - Launches codex exec in background.
  - Does NOT poll from agent side.
  - Sends completion directly to Telegram using `openclaw message send`.
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

# Backward-compatible mode
if [[ "${1:-}" == "--start-hook" ]]; then
  TASK="${2:-}"
  MODEL="${3:-$DEFAULT_MODEL}"
  shift $(( $# > 2 ? 3 : $# )) || true
else
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --start)
        shift
        ;;
      --task)
        TASK="${2:-}"
        shift 2
        ;;
      --task-file)
        TASK="$(cat "${2:?missing task file}")"
        shift 2
        ;;
      --model)
        MODEL="${2:?missing model}"
        shift 2
        ;;
      --workspace)
        WORKSPACE="${2:?missing workspace}"
        shift 2
        ;;
      --target)
        TARGET="${2:?missing telegram target}"
        shift 2
        ;;
      --from-agent)
        FROM_AGENT="${2:?missing agent name}"
        shift 2
        ;;
      --notify-start)
        NOTIFY_START=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown arg: $1" >&2
        usage
        exit 2
        ;;
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

printf "%s\n" "$TASK" > "$PROMPT_FILE"
START_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

notify() {
  local text="$1"
  "$OPENCLAW_BIN" message send --channel "$CHANNEL" --target "$TARGET" --message "$text" >/dev/null
}

if [[ "$NOTIFY_START" -eq 1 ]]; then
  notify "[CodexHook] START job=$JOB_ID from=$FROM_AGENT model=$MODEL task=$(echo "$TASK" | tr '\n' ' ' | cut -c1-180)"
fi

(
  set +e
  RUN_START_EPOCH=$(date +%s)

  printf '%s\n' "$TASK" | "$CODEX_BIN" exec -m "$MODEL" --sandbox workspace-write -C "$WORKSPACE" >"$RESULT_FILE" 2>&1
  EXIT_CODE=$?

  RUN_END_EPOCH=$(date +%s)
  DURATION=$((RUN_END_EPOCH - RUN_START_EPOCH))
  END_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Telegram text hard limit is around 4096 chars; keep margin.
  PREVIEW="$(tail -n 80 "$RESULT_FILE" | sed 's/\x1b\[[0-9;]*m//g' | tr -d '\r' | sed 's/"/\\"/g')"
  PREVIEW_TRIMMED="$(printf '%s' "$PREVIEW" | tail -c 2600)"

  if [[ "$EXIT_CODE" -eq 0 ]]; then
    MSG="[CodexHook] DONE\njob=$JOB_ID\nfrom=$FROM_AGENT\nmodel=$MODEL\nseconds=$DURATION\nstatus=success\nresult_file=$RESULT_FILE\n---\n$PREVIEW_TRIMMED"
    NOTIFY_OK=1
    notify "$MSG" || NOTIFY_OK=0
    STATUS="success"
  else
    MSG="[CodexHook] DONE\njob=$JOB_ID\nfrom=$FROM_AGENT\nmodel=$MODEL\nseconds=$DURATION\nstatus=failed(exit=$EXIT_CODE)\nresult_file=$RESULT_FILE\n---\n$PREVIEW_TRIMMED"
    NOTIFY_OK=1
    notify "$MSG" || NOTIFY_OK=0
    STATUS="failed"
  fi

  cat > "$STATUS_FILE" <<JSON
{
  "job_id": "$JOB_ID",
  "from_agent": "$FROM_AGENT",
  "model": "$MODEL",
  "workspace": "$WORKSPACE",
  "target": "$TARGET",
  "start_ts": "$START_TS",
  "end_ts": "$END_TS",
  "duration_sec": $DURATION,
  "exit_code": $EXIT_CODE,
  "status": "$STATUS",
  "notify_ok": $NOTIFY_OK,
  "prompt_file": "$PROMPT_FILE",
  "result_file": "$RESULT_FILE"
}
JSON

  echo "job=$JOB_ID status=$STATUS exit=$EXIT_CODE notify_ok=$NOTIFY_OK" >> "$LOG_FILE"
) >/dev/null 2>&1 &

BG_PID=$!
disown "$BG_PID" || true

echo "status: accepted"
echo "job_id: $JOB_ID"
echo "pid: $BG_PID"
echo "result_file: $RESULT_FILE"
echo "status_file: $STATUS_FILE"
echo "next: no polling needed; codex will notify telegram on completion"
