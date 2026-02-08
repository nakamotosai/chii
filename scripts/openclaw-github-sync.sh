#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="/home/ubuntu/.openclaw/workspace"
BRANCH="master"
LOCK="/tmp/openclaw-github-sync.lock"
OPENCLAW_CLI="/home/ubuntu/.npm-global/bin/openclaw"
NOTIFY_TARGET="8138445887"

notify_fail() {
  local msg="$1"
  if [[ -x "$OPENCLAW_CLI" ]]; then
    "$OPENCLAW_CLI" message send --channel telegram --target "$NOTIFY_TARGET" --message "$msg" >/dev/null 2>&1 || true
  fi
}

notify_success() {
  local msg="$1"
  if [[ -x "$OPENCLAW_CLI" ]]; then
    "$OPENCLAW_CLI" message send --channel telegram --target "$NOTIFY_TARGET" --message "$msg" >/dev/null 2>&1 || true
  fi
}

exec 9>"$LOCK"
if ! flock -n 9; then
  exit 0
fi

cd "$REPO_DIR"

origin_url=$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null || echo "")

if ! git fetch origin "$BRANCH" >/dev/null 2>&1; then
  notify_fail "GitHub 同步失败：git fetch 出错。请手动检查网络/权限。"
  exit 1
fi

if git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
  counts=$(git rev-list --left-right --count "origin/$BRANCH...$BRANCH" 2>/dev/null || echo "0 0")
  behind=$(echo "$counts" | awk '{print $1}')
  ahead=$(echo "$counts" | awk '{print $2}')
  if [[ "$behind" -gt 0 ]] && [[ -n "$(git status --porcelain)" ]]; then
    notify_fail "GitHub 同步失败：远端有更新且本地有改动（behind=$behind,ahead=$ahead）。已停止自动同步，请先手动拉取。"
    exit 1
  fi
fi

if [[ -n "$(git status --porcelain)" ]]; then
  if ! git add -A; then
    notify_fail "GitHub 同步失败：git add 出错。"
    exit 1
  fi
  if ! git commit -m "chii: auto sync $(date -u +'%Y-%m-%dT%H:%M:%SZ')" --no-gpg-sign >/dev/null 2>&1; then
    notify_fail "GitHub 同步失败：git commit 出错。"
    exit 1
  fi
  if ! git push origin "$BRANCH" >/tmp/openclaw-github-sync.err 2>&1; then
    err_excerpt=$(tail -n 5 /tmp/openclaw-github-sync.err 2>/dev/null | tr "\n" " " | sed "s/  */ /g" | cut -c1-400)
    if [[ -n "$err_excerpt" ]]; then
      notify_fail "GitHub 上传失败：push 出错。原因：${err_excerpt}"
    else
      notify_fail "GitHub 上传失败：push 出错。请检查远端状态或权限。"
    fi
    exit 1
  fi
  short_hash=$(git -C "$REPO_DIR" log -1 --format=%h 2>/dev/null || echo "")
  if [[ -n "$short_hash" ]]; then
    notify_success "GitHub 上传成功：${origin_url}（commit ${short_hash}）"
  else
    notify_success "GitHub 上传成功：${origin_url}"
  fi
fi
