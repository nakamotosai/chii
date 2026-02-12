#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${CODEX_HOOK_CONFIG:-/home/ubuntu/.openclaw/workspace/config/codex-hook.env}"
if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

HOOK_SCRIPT="${CODEX_HOOK_SCRIPT:-/home/ubuntu/.openclaw/workspace/scripts/codex_hook.sh}"
AGENT_ID="${1:-agent}"
TASK="${2:-}"
TARGET="${3:-${CHII_OWNER_TELEGRAM_TARGET:-8138445887}}"

if [[ -z "$TASK" ]]; then
  echo "ERROR: task required" >&2
  exit 2
fi

mkdir -p "${CODEX_HOOK_JOB_DIR:-/tmp/codex-hook-jobs}"
"$HOOK_SCRIPT" --start --task "$TASK" --from-agent "$AGENT_ID" --target "$TARGET" >"${CODEX_HOOK_JOB_DIR:-/tmp/codex-hook-jobs}/last-delegate.out" 2>&1 || true

echo "NO_REPLY"
