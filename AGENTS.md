# Repository Guidelines

## 全局规则
- 所有交流必须使用中文，若需要跨技能协作或解释内容也统一用中文表达，并将此规则视为最高级别的语言约定。

## 项目结构与模块组织
- 根目录是 OpenClaw 运行态：`.openclaw.json`、`.env` 记录平台配置，`agents/` 存放活跃任务上下文，`memory/` 和 `memory_archive/` 保留长期/归档记忆。
- `skills/` 收录可调度的动作，每个技能都必须带 `SKILL.md`，修改前先确认 `TOOLS.md` 中的可用列表，不要自行创建未登记的目录。
- `workspace/` 里的子项目（比如 `MCP-*`、`mcp-*`）承载各类插件，脚本修改应保持单一职责并在文档（`docs/`、`quick_references/`）中补充说明。
- `scripts/`、`config/`、`core_files_*` 等目录仅存辅助工具和素材，提交前确认未包含大型二进制或日志。
- `logs/`、`output/`、`todo/` 等目录用于汇总执行结果、输出文件与待办事项，原则上不直接提交，必要时把具体路径写入 PR 便于追踪。

## 构建、测试与协作命令
- `openclaw agents list --json`：获取当前 agent 与 session 状态（必须在系统状态相关问题前运行）。
- `openclaw agent spawn <name>` / `openclaw run skill <skill-id>`：按照任务拆分调用指定子 agent 或技能，`mcporter-mcp` 接口可用于统一 MCP 工具调用。
- `cd workspace && source .venv/bin/activate && pip install -r MCP-Image-Processing-Tool/requirements.txt`：更新 Python 依赖。
- `python test_native_latest.py`、`bash test-mcp-image-tools.sh`：执行本地验证脚本，遇到 API Key 需先设置环境变量再运行。
- `openclaw agent status --json`（当查询 agent 状态时配合 `agents list` 输出）

## 代码风格与命名约定
- Python/agent 脚本遵循 4 空格缩进、PEP 8，函数和模块使用描述性命名，必要时加 docstring；JSON/配置文件保持 2 空格缩进。
- Bash 脚本需声明 `#!/usr/bin/env bash`，加上 `set -euo pipefail` 保证失败即时退出，注释说明非显而易见的流程。
- 变量/常量使用 camelCase、UPPER_SNAKE_CASE；字符串模板优先 f-string、不拼接硬编码路径。

## 测试指南
- 以 `test_*` 系列脚本验证与外部服务的连通性（比如 `verify_searxng.js`、`test_native_latest.py`）、`test-mcp-*.sh`，输出必须包含成功/失败标记以便复用，测试日志可同步到 `logs/` 供后续调查。
- 新增加的技能或功能必须补充执行命令、预期输出与失败处理步骤，并在 PR 描述或 `logs/` 路径中附上样例片段，便于 reviewer 复现。

## 提交与 Pull Request 指南
- 使用 Conventional Commit（`feat:`、`fix:`、`chore:` 等）且正文说明“why vs how”，PR 需列明已运行的验证命令、涉及的 config 变更以及需关注的多 agent 配置点。
- 当涉及技能、记忆或配置更新时，提示关联的文件（`skills/<name>/SKILL.md`、`memory/` 目录或 `config/mcporter`）。

## 多 Agent 协作细则
- 复杂任务由主 agent 统筹，常规逻辑交给 `codex-medium`，重构/排障交给 `codex-hard`，低成本批处理交给 `free-worker`；主 agent 负责路由、汇总、输出结果并在 `agents/` 记录子 agent 的执行状态。
- 每个阶段必须补 evidence：`openclaw agents list` / `ls` / 片段 `cat` 等输出，缺乏证据须用 `⚠️` 标记并说明原因。
- 遇到需要并行、长耗时或多阶段步骤时，优先使用 `group-agent-execution` 或 `persistent-child-agent-workflow`，避免多个 agent 操作同一目录；涉及 `rm`、配置或关键文件的修改前必须做预演并保存命令与输出。

## 安全与配置提示
- 不得将 API Key、私钥或 `.env` 内容写入提交或对话，`test_native_latest.py` 等脚本中的硬编码密钥必须用环境变量覆盖再运行。
- 任何对 `openclaw.json`、`config/` 目录的改动前先备份（可使用 `.bak` 模式）并在 PR 中说明用途。
- 所有外部 HTTP/SSH 请求需设置合理超时、异常捕获并记录日志摘要以便排查。
