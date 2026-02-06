#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="/home/ubuntu/.openclaw/workspace/telegram-5283834340-workspace"
cd "$WORKSPACE"

REMOTE="origin"
BRANCH="master"

OUTPUT="$(git status --short)"
if [[ -n "$OUTPUT" ]]; then
  git add -A
  TIMESTAMP="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  git commit -m "[auto] hourly sync $TIMESTAMP"
else
  echo "[github-upload-hourly] no changes detected"
fi

git push "$REMOTE" "$BRANCH"
