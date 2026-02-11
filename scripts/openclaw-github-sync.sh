#!/usr/bin/env bash
set -euo pipefail

WS="/home/ubuntu/.openclaw/workspace"
SNAP="$WS/github-backup"
BRANCH="${BACKUP_BRANCH:-master}"
REMOTE_URL="${BACKUP_REMOTE_URL:-https://github.com/nakamotosai/chii}"
LOCK="/tmp/openclaw-github-sync.lock"

EXCLUDES=(
  .git
  github-backup
  github-backup.broken-*
  venv
  node_modules
  __pycache__
  '*.pyc'
  '*.pyo'
  .cache
  output
  .cleanup_archive
  '*.mp4'
  '*.mov'
  '*.zip'
  '*.tar'
  '*.tar.gz'
)

exec 9>"$LOCK"
flock -n 9 || { echo "status: skipped (lock busy)"; exit 0; }

mkdir -p "$SNAP"
if [[ ! -d "$SNAP/.git" ]]; then
  git -C "$SNAP" init -b "$BRANCH" >/dev/null
fi

# Rebuild when repository metadata is corrupted.
if ! git -C "$SNAP" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  rm -rf "$SNAP"
  mkdir -p "$SNAP"
  git -C "$SNAP" init -b "$BRANCH" >/dev/null
fi

git -C "$SNAP" config user.name "nakamotosai"
git -C "$SNAP" config user.email "nakamotosai@users.noreply.github.com"
if git -C "$SNAP" remote get-url origin >/dev/null 2>&1; then
  git -C "$SNAP" remote set-url origin "$REMOTE_URL"
else
  git -C "$SNAP" remote add origin "$REMOTE_URL"
fi

RSYNC_ARGS=( -a --delete )
for ex in "${EXCLUDES[@]}"; do
  RSYNC_ARGS+=( --exclude="$ex" )
done
rsync "${RSYNC_ARGS[@]}" "$WS/" "$SNAP/"

# Remove nested .git dirs to prevent accidental embedded repositories/submodule ghosts.
find "$SNAP" -mindepth 2 -type d -name .git -prune -exec rm -rf {} +

# Maintain backup-specific ignores.
if [[ ! -f "$SNAP/.gitignore" ]]; then
  : > "$SNAP/.gitignore"
fi
for line in \
  "venv/" "node_modules/" "__pycache__/" "*.pyc" "*.pyo" ".cache/" "output/" ".cleanup_archive/" \
  "context7/.git" "mcp-ffmpeg-helper/.git" "mcp-image-extractor/.git" "podcastfy-clawdbot-skill/.git" "qmd/.git"
do
  grep -qxF "$line" "$SNAP/.gitignore" || echo "$line" >> "$SNAP/.gitignore"
done

git -C "$SNAP" add -A

# Guardrail: drop files >95MB from index to satisfy GitHub 100MB hard limit.
python3 - <<'PY'
import os, subprocess
snap = "/home/ubuntu/.openclaw/workspace/github-backup"
limit = 95 * 1024 * 1024
out = subprocess.check_output(["git", "-C", snap, "ls-files", "-z"])
files = [p for p in out.decode("utf-8", "ignore").split("\x00") if p]
large = []
for rel in files:
    path = os.path.join(snap, rel)
    try:
        size = os.path.getsize(path)
    except OSError:
        continue
    if size > limit:
        large.append((size, rel))
for size, rel in sorted(large, reverse=True):
    print(f"drop_large: {size/1024/1024:.2f}MB {rel}")
    subprocess.run(["git", "-C", snap, "rm", "-f", "--cached", rel], check=False)
    with open(os.path.join(snap, ".gitignore"), "a", encoding="utf-8") as f:
        f.write(rel + "\n")
PY

git -C "$SNAP" add -A
if ! git -C "$SNAP" diff --cached --quiet; then
  git -C "$SNAP" commit -m "backup: workspace snapshot $(date -u +%Y-%m-%dT%H:%M:%SZ)" --no-gpg-sign >/dev/null
fi

git -C "$SNAP" push origin "HEAD:$BRANCH" --force >/dev/null

LOCAL_SHA="$(git -C "$SNAP" rev-parse --short HEAD)"
REMOTE_SHA="$(git -C "$SNAP" ls-remote origin "refs/heads/$BRANCH" | awk '{print substr($1,1,7)}')"

echo "status: success"
echo "repo: $REMOTE_URL"
echo "branch: $BRANCH"
echo "local_sha: $LOCAL_SHA"
echo "remote_sha: $REMOTE_SHA"
if [[ "$LOCAL_SHA" == "$REMOTE_SHA" ]]; then
  echo "sha_match: yes"
else
  echo "sha_match: no"
  exit 2
fi
