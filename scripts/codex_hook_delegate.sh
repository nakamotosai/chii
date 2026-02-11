#!/usr/bin/env bash
set -euo pipefail

AGENT_ID="${1:-agent}"
TASK="${2:-}"
TARGET="${3:-8138445887}"

if [[ -z "$TASK" ]]; then
  echo "ERROR: task required" >&2
  exit 2
fi

/home/ubuntu/.openclaw/workspace/scripts/codex_hook.sh --start --task "$TASK" --from-agent "$AGENT_ID" --target "$TARGET" >/tmp/codex-hook-jobs/last-delegate.out 2>&1 || true

# Contract for agent layer: no progress chatter, no polling.
echo "NO_REPLY"
