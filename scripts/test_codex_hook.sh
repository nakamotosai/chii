#!/usr/bin/env bash
set -euo pipefail

HOOK=/home/ubuntu/.openclaw/workspace/scripts/codex_hook.sh

echo "[1] hook file check"
[[ -x "$HOOK" ]] || { echo "hook missing"; exit 1; }

echo "[2] codex check"
command -v codex >/dev/null
codex --version

echo "[3] launch async job"
OUT="$($HOOK --start --task 'Reply with HOOK_OK only' --from-agent test-run --target 8138445887)"
echo "$OUT"

JOB_ID="$(echo "$OUT" | awk -F': ' '/^job_id:/ {print $2}')"
STATUS_FILE="$(echo "$OUT" | awk -F': ' '/^status_file:/ {print $2}')"

[[ -n "$JOB_ID" ]] || { echo "job id parse failed"; exit 2; }
[[ -n "$STATUS_FILE" ]] || { echo "status file parse failed"; exit 2; }

sleep 8

echo "[4] status file"
if [[ -f "$STATUS_FILE" ]]; then
  cat "$STATUS_FILE"
else
  echo "status file not yet created (job still running)"
fi

echo "[done]"
