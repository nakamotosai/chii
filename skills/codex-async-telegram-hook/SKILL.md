---
name: codex-async-telegram-hook
description: Unified async Codex delegation for OpenClaw. Use when tasks are medium/complex and should be executed by Codex with completion pushed directly to Telegram, while agent returns NO_REPLY.
---

# Codex Async Telegram Hook

## Core Policy
- 稍复杂任务（中等及以上）默认交给 Codex 执行。
- agent 只做任务分配与转发，不做轮询，不做过程性聊天。

## Must-Use Entry
- `/home/ubuntu/.openclaw/workspace/scripts/codex_hook_delegate.sh "<agent_id>" "<task>"`

## Response Contract
- 当前会话只允许输出：`NO_REPLY`
- 最终结果由 Codex hook 直接发 Telegram 给主人。

## Unified Config
- 配置文件：`/home/ubuntu/.openclaw/workspace/config/codex-hook.env`
- 关键参数：
  - `CHII_OWNER_TELEGRAM_TARGET`
  - `CODEX_MODEL`
  - `CODEX_WORKSPACE`
  - `CODEX_PRIMARY_WORKSPACE`
  - `CODEX_HOOK_JOB_DIR`
  - `CODEX_HOOK_SCRIPT`
  - `CODEX_DELEGATE_SCRIPT`
  - `CODEX_SKIP_GIT_REPO_CHECK`

## Debug
- 快速自测：`/home/ubuntu/.openclaw/workspace/scripts/test_codex_hook.sh`
- 状态文件：`ls -t /tmp/codex-hook-jobs/*.status.json | head`
