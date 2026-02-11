---
name: codex-async-telegram-hook
description: Delegate long tasks to VPS Codex CLI asynchronously with completion hook notifications sent directly to Telegram. Use when user asks to hand off tasks to codex without polling, and report results via Telegram directly from codex.
---

# Codex Async Telegram Hook

## 何时使用
- 用户要求“交给 codex 跑”“不要轮询”“完成后自动发 Telegram”。
- 任务较长、需要异步执行、agent 不应持续占用会话。

## 固定流程（必须）
1. 统一调用：
- `/home/ubuntu/.openclaw/workspace/scripts/codex_hook_delegate.sh "<agent_id>" "<任务>" "8138445887"`

2. 当前会话回复：
- 只允许返回：`NO_REPLY`
- 禁止任何“已启动/处理中/会通知你”的额外文本。

3. 完成通知：
- 由 codex hook 在任务结束时直接通过 Telegram 发送结果。

## 禁止事项
- 禁止 agent 自己轮询 codex 进度。
- 禁止把“已启动”当作“已完成”。
- 禁止省略结果证据（hook 自动含 job_id/result_file/预览）。

## 故障排查
- 自测：`/home/ubuntu/.openclaw/workspace/scripts/test_codex_hook.sh`
- 查看状态：`ls -lt /tmp/codex-hook-jobs/*.status.json | head`
- 查看结果：`tail -n 120 /tmp/codex-hook-jobs/<job_id>.result.txt`
