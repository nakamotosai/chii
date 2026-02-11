#!/usr/bin/env bash
set -euo pipefail

HOOK=/home/ubuntu/.openclaw/workspace/scripts/codex_hook.sh
TARGET="${CHII_OWNER_TELEGRAM_TARGET:-8138445887}"

$HOOK --start --task "请总结最近一次 workspace 改动并给出 3 条下一步建议" --from-agent manual --target "$TARGET"
$HOOK --start --task "请检查 agents/backuper/AGENTS.md 是否与 github 上传流程一致" --from-agent manual --target "$TARGET"
$HOOK --start --task "请生成 codex hook 链路的故障排查清单" --from-agent manual --target "$TARGET"

printf 'submitted 3 jobs\n'
