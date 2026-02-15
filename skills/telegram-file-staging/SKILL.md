---
name: telegram-file-staging
description: Stage files into Telegram-allowed media directories before sending. Use when a requested file path is outside Telegram whitelist paths (for example under hidden workspaces like ~/.openclaw/workspace), when Telegram upload fails due to path restrictions, or when a user asks for a reusable "copy-then-send" workflow.
---

# Telegram File Staging

Stage files from non-whitelisted paths into a safe directory and optionally send them directly to Telegram.

## Workflow
1. Confirm the source file path exists.
2. For copy-only mode, run:
```bash
bash scripts/stage_for_telegram.sh "<source-file-path>"
```
3. For one-step copy-and-send mode, run:
```bash
bash scripts/stage_and_send_telegram.sh "<source-file-path>"
```
4. Read output fields and return status to the user.

## Script Behavior
- Script: `scripts/stage_for_telegram.sh`
- Script: `scripts/stage_and_send_telegram.sh`
- Default whitelist target priority:
  1. `/home/ubuntu`
  2. `/tmp`
- Optional target override:
```bash
bash scripts/stage_for_telegram.sh "<source-file-path>" --target-dir /home/ubuntu
```
- If destination filename already exists, auto-add timestamp suffix to avoid overwrite.
- Output format is stable for automation:
  - `SOURCE=...`
  - `STAGED_PATH=...`
  - `CHAT_ID=...` (send script)
  - `SENT=0|1` (send script)

## Send Mode
- `stage_and_send_telegram.sh` uses:
  - Sender: `~/.openclaw/workspace/scripts/telegram_send_document.sh`
  - Default chat ID:
    1. `--chat-id` if provided
    2. `TELEGRAM_CHAT_ID` env if set
    3. fallback `8138445887`
- Optional caption:
```bash
bash scripts/stage_and_send_telegram.sh "<source-file-path>" --caption "文件已生成"
```
- Dry run (copy but do not send):
```bash
bash scripts/stage_and_send_telegram.sh "<source-file-path>" --dry-run
```

## Failure Handling
- If source path does not exist, report the exact missing path.
- If copy to first target fails, auto-fallback to next target.
- If all targets fail, return non-zero and ask user which directory is allowed for Telegram uploads.
- If sender script or Telegram token is unavailable, return non-zero with explicit reason.

## Usage Examples
```bash
bash scripts/stage_for_telegram.sh "/home/ubuntu/.openclaw/workspace/output/polymarket-full.md"
```

```bash
bash scripts/stage_for_telegram.sh "/home/ubuntu/.openclaw/workspace/output/report.pdf" --target-dir /tmp
```

```bash
bash scripts/stage_and_send_telegram.sh "/home/ubuntu/.openclaw/workspace/output/polymarket-full.md"
```

```bash
bash scripts/stage_and_send_telegram.sh "/home/ubuntu/.openclaw/workspace/output/polymarket-full.md" --chat-id 8138445887 --caption "polymarket 报告"
```
