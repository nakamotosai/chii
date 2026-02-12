#!/usr/bin/env bash
set -euo pipefail
LOCK=/tmp/moltbook_auto_cycle.lock
SCRIPT=/home/ubuntu/.openclaw/workspace/scripts/moltbook_auto_cycle.py
/usr/bin/flock -n "$LOCK" /usr/bin/python3 "$SCRIPT"
