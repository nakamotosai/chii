#!/usr/bin/env bash
set -euo pipefail

CFG=/home/ubuntu/.openclaw/workspace/config/codex-hook.env
HOOK=/home/ubuntu/.openclaw/workspace/scripts/codex_hook.sh
DELEGATE=/home/ubuntu/.openclaw/workspace/scripts/codex_hook_delegate.sh

echo "[1] files"
[[ -f "$CFG" ]] || { echo "missing config"; exit 1; }
[[ -x "$HOOK" ]] || { echo "missing hook"; exit 1; }
[[ -x "$DELEGATE" ]] || { echo "missing delegate"; exit 1; }

echo "[2] codex"
command -v codex >/dev/null
codex --version

echo "[3] delegate (must print NO_REPLY)"
OUT="$($DELEGATE test-run 'Reply with HOOK_OK only')"
echo "$OUT"
[[ "$OUT" == "NO_REPLY" ]] || { echo "delegate contract broken"; exit 2; }

sleep 8

echo "[4] latest status"
LATEST=$(ls -t /tmp/codex-hook-jobs/*.status.json 2>/dev/null | head -n 1 || true)
if [[ -z "$LATEST" ]]; then
  echo "no status file yet"
  exit 3
fi
cat "$LATEST"
