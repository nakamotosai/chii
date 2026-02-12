#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${CODEX_HOOK_CONFIG:-/home/ubuntu/.openclaw/workspace/config/codex-hook.env}"
if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

AGENT_ID="${1:?agent id required}"
TASK="${2:?task required}"
TARGET="${3:-}"
DELEGATE_SCRIPT="${CODEX_DELEGATE_SCRIPT:-/home/ubuntu/.openclaw/workspace/scripts/codex_hook_delegate.sh}"

if [[ -n "$TARGET" ]]; then
  exec "$DELEGATE_SCRIPT" "$AGENT_ID" "$TASK" "$TARGET"
else
  exec "$DELEGATE_SCRIPT" "$AGENT_ID" "$TASK"
fi
