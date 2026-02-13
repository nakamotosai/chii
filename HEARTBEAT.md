# HEARTBEAT.md (Casper)

目标：Telegram 主渠道下，做到“有事主动、没事不扰”。

## 执行顺序（每次 heartbeat 严格按序，最多做 3 件事）

### 1) 快速自检（10 秒内）
- 只读：看是否有需要你确认的高风险事项、是否有失败的 cron。

命令：
- `cd ~/.openclaw/workspace && openclaw cron status`（如果超时就跳过）

### 2) 记忆维护（轻量）
触发条件：当日 `memory/*.md` 有新增或变更。

命令：
- `qmd update`

### 3) GitHub 自动同步（只在有变更时）
触发条件：`git status` 有改动。

规则：
- 只 push 到 `main`。
- commit message 固定：`"auto: heartbeat sync" + 日期时间`。
- 如果 push 失败（远端冲突/权限），记录到 daily 并停止，不反复重试。

命令：
- `cd ~/.openclaw/workspace && git status --porcelain`
- `cd ~/.openclaw/workspace && git add -A && git commit -m "auto: heartbeat sync $(date -u +%Y-%m-%dT%H:%M:%SZ)" || true`
- `cd ~/.openclaw/workspace && git push origin main`

### 4) TODO 维护（可选）
只在发现“明确下一步”时追加 1 条。

命令：
- `cd ~/.openclaw/workspace && mcporter call tasks.add_todo text="..." --output text`

## 对外发言规则（Telegram）
- 如果本次 heartbeat 没产生新信息：回复 `HEARTBEAT_OK`。
- 如果产生了可执行的重要结论：只发一条，包含：结论 + 1-3 个 next steps。

