#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="/home/ubuntu/.openclaw/workspace"
BRANCH="master"

cd "$REPO_DIR"

git add -A

# Force a commit even if there are no content changes so we always push each hour
git commit --allow-empty -m "chii: auto sync $(date -u +'%Y-%m-%dT%H:%M:%SZ')" --no-gpg-sign

git push origin "$BRANCH"
