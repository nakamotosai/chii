---
name: github-uploader-workflow
description: Reliable GitHub backup upload workflow for OpenClaw. Use this skill whenever user asks to backup/upload workspace to GitHub, verify push success, or fix upload failures (submodule issues, >100MB files, repo mismatch).
---

# GitHub Uploader Workflow

## 触发条件
- 用户要求“上传 GitHub / 备份 workspace / 同步仓库 / 修复上传失败”。
- 任何涉及 `github-backup`、`openclaw-github-sync.sh`、SHA 校验的任务。

## 强制执行顺序
1. 执行固定脚本：
- `/home/ubuntu/.openclaw/workspace/scripts/openclaw-github-sync.sh`

2. 读取并按模板回报结果（不得自由发挥）：
- `status`
- `repo`
- `branch`
- `local_sha`
- `remote_sha`
- `sha_match`

3. 仅当 `status: success` 且 `sha_match: yes` 才能说“上传成功”。

## 禁止事项
- 禁止执行 `git submodule deinit` / `git rm` 清理子模块来“修复上传”。
- 禁止在 `workspace/agents/<agent>` 隔离目录冒充“全库上传”。
- 禁止在没有 `local_sha == remote_sha` 的证据时宣称成功。

## 失败时处理
- 原样贴出脚本错误输出关键行。
- 指明失败阶段：`sync` / `commit` / `push` / `sha_check`。
- 给出下一步可执行动作，不得虚构“已上传”。
