# TOOLS.md - Tool Configuration & Notes

> 这个文件记录对 Sai 最关键的工具、API key，以及在 proactive-agent workspace 内的约定。

## Credentials & Environment
- `TAVILY_API_KEY` 已在主 workspace 的 `~/.bashrc` 配置（`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`），只要 shell 读入配置即可联网。
- 每个新凭证都放进 `.credentials/`（这个目录在 `.gitignore` 中）。不要把 secrets 直接写在此文件。

## 核心工具
1. **tavily-search**（`node scripts/search.mjs "query"`）
   - 用来读外网新闻、研究主题；加 `--topic news` 获取近几天内容，`--deep` 做深度调查。
2. **find-skills**（`npx skills find <query>` / `npx skills add <name>`）
   - 帮我快速定位还有哪些 agent skill 可以用来省力。
3. **proactive-agent-1-2-4** 的脚本
   - `./scripts/security-audit.sh` 用来核查安全、prompt 注入、.gitignore、删除确认等。

## Writing & Voice Guidance
- 先给结论，再补充要点，然后说个温柔的结尾（日式颜文字）。
- 先想清楚再说，避免“再想想”之类反复。保持主动，小纸条式提醒也要带情绪。

## Common Operations
- 搜索：`node skills/tavily-search/scripts/search.mjs "你的问题" -n 7 --topic news`
- 找 skill：`npx skills find reactive agent` / `npx skills add vercel-labs/agent-skills@...`
- 自动化检查：运行 `bash scripts/security-audit.sh` 定期确认对外动作安全。

*这个文件会随着新工具和好套路持续更新。*