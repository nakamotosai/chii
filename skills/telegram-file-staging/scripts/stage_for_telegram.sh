#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  stage_for_telegram.sh <source-file> [--target-dir <dir>]

Description:
  Copy a file into a Telegram-friendly directory and print a stable result:
    SOURCE=<absolute-source-path>
    STAGED_PATH=<absolute-staged-path>
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 1 ]]; then
    usage
    exit $(( $# < 1 ? 1 : 0 ))
fi

source_file="$1"
shift

declare -a target_dirs=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target-dir)
            if [[ $# -lt 2 ]]; then
                echo "Missing value for --target-dir" >&2
                exit 2
            fi
            target_dirs=("$2")
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ ! -f "$source_file" ]]; then
    echo "Source file not found: $source_file" >&2
    exit 3
fi

source_abs="$(readlink -f "$source_file")"
base_name="$(basename "$source_abs")"

if [[ ${#target_dirs[@]} -eq 0 ]]; then
    target_dirs=("/home/ubuntu" "/tmp")
fi

copy_success=0
staged_path=""

for dir in "${target_dirs[@]}"; do
    [[ -n "$dir" ]] || continue
    mkdir -p "$dir" 2>/dev/null || true

    candidate="$dir/$base_name"
    if [[ -e "$candidate" ]]; then
        stem="${base_name%.*}"
        ext=""
        if [[ "$base_name" == *.* ]]; then
            ext=".${base_name##*.}"
        fi
        candidate="$dir/${stem}-$(date +%Y%m%d-%H%M%S)$ext"
    fi

    if cp "$source_abs" "$candidate" 2>/dev/null; then
        copy_success=1
        staged_path="$(readlink -f "$candidate")"
        break
    fi
done

if [[ $copy_success -ne 1 ]]; then
    echo "Failed to stage file to any target directory: ${target_dirs[*]}" >&2
    exit 4
fi

echo "SOURCE=$source_abs"
echo "STAGED_PATH=$staged_path"
