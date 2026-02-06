#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="/home/ubuntu/.openclaw/workspace"
MEMORY_DIR="$WORKSPACE/memory"
LAST_CHAT_FILE="$MEMORY_DIR/last_chat.ts"
FORCE_FILE="$MEMORY_DIR/force_heartbeat"

now_ts=$(date +%s)
active=false

if [[ -f "$LAST_CHAT_FILE" ]]; then
  last_ts=$(cat "$LAST_CHAT_FILE" 2>/dev/null || echo 0)
  if [[ $((now_ts - last_ts)) -le 600 ]]; then
    active=true
  fi
fi

if [[ -f "$FORCE_FILE" ]]; then
  active=true
  rm -f "$FORCE_FILE"
fi

if [[ "$active" != true ]]; then
  exit 0
fi

"$WORKSPACE/scripts/heartbeat_maintenance.sh" >/dev/null 2>&1 || true
