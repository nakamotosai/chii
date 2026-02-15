#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  stage_and_send_telegram.sh <source-file> [--chat-id <id>] [--caption <text>] [--target-dir <dir>] [--dry-run]

Description:
  Stage a file into Telegram-friendly directory, then send it via Telegram bot.
  Stable output:
    SOURCE=<absolute-source-path>
    STAGED_PATH=<absolute-staged-path>
    CHAT_ID=<chat-id>
    SENT=<0|1>
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 1 ]]; then
    usage
    exit $(( $# < 1 ? 1 : 0 ))
fi

source_file="$1"
shift

chat_id="${TELEGRAM_CHAT_ID:-}"
caption=""
target_dir=""
dry_run=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --chat-id)
            [[ $# -ge 2 ]] || { echo "Missing value for --chat-id" >&2; exit 2; }
            chat_id="$2"
            shift 2
            ;;
        --caption)
            [[ $# -ge 2 ]] || { echo "Missing value for --caption" >&2; exit 2; }
            caption="$2"
            shift 2
            ;;
        --target-dir)
            [[ $# -ge 2 ]] || { echo "Missing value for --target-dir" >&2; exit 2; }
            target_dir="$2"
            shift 2
            ;;
        --dry-run)
            dry_run=1
            shift
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ -z "$chat_id" ]]; then
    # Keep this fallback aligned with workspace/scripts/codex_dispatch.sh default.
    chat_id="8138445887"
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stage_script="$script_dir/stage_for_telegram.sh"
sender_script="$HOME/.openclaw/workspace/scripts/telegram_send_document.sh"

[[ -x "$stage_script" ]] || { echo "Missing or non-executable stage script: $stage_script" >&2; exit 3; }
[[ -x "$sender_script" ]] || { echo "Missing or non-executable telegram sender script: $sender_script" >&2; exit 3; }

stage_output=""
if [[ -n "$target_dir" ]]; then
    stage_output="$(bash "$stage_script" "$source_file" --target-dir "$target_dir")"
else
    stage_output="$(bash "$stage_script" "$source_file")"
fi

staged_path="$(printf '%s\n' "$stage_output" | awk -F= '/^STAGED_PATH=/{print $2}')"
source_abs="$(printf '%s\n' "$stage_output" | awk -F= '/^SOURCE=/{print $2}')"
[[ -n "$staged_path" ]] || { echo "Failed to parse STAGED_PATH from stage output" >&2; exit 4; }
[[ -n "$source_abs" ]] || { echo "Failed to parse SOURCE from stage output" >&2; exit 4; }

echo "SOURCE=$source_abs"
echo "STAGED_PATH=$staged_path"
echo "CHAT_ID=$chat_id"

if [[ "$dry_run" -eq 1 ]]; then
    echo "SENT=0"
    exit 0
fi

if send_err="$(bash "$sender_script" "$chat_id" "$staged_path" "$caption" 2>&1)"; then
    echo "SENT=1"
else
    echo "SENT=0"
    echo "ERROR=$send_err" >&2
    exit 5
fi
