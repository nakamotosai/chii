#!/usr/bin/env bash
set -euo pipefail
TASK="${1:?task required}"
FROM_AGENT="${2:-manual}"
TARGET="${3:-8138445887}"
exec /home/ubuntu/.openclaw/workspace/scripts/codex_hook.sh --start --task "$TASK" --from-agent "$FROM_AGENT" --target "$TARGET"
