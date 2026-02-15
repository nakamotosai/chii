#!/usr/bin/env bash
set -euo pipefail

WS="$HOME/.openclaw/workspace"
JOBDIR="$WS/logs/codex/jobs"
MAX_NOTIFY_RETRIES="${CODEX_NOTIFY_MAX_RETRIES:-3}"

[[ -d "$JOBDIR" ]] || exit 0

mark_notified() {
  local jf="$1"
  local state="$2"
  local note="${3:-}"
  python3 - "$jf" "$state" "$note" <<'PY'
import json, sys, time
from pathlib import Path
p = Path(sys.argv[1])
state = sys.argv[2]
note = sys.argv[3]
obj = json.loads(p.read_text(encoding='utf-8'))
obj['notified'] = True
obj['notifyState'] = state
obj['notifiedAtUtc'] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
if note:
    obj['notifyNote'] = note
p.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding='utf-8')
PY
}

record_failure() {
  local jf="$1"
  local err="$2"
  python3 - "$jf" "$err" <<'PY'
import json, sys, time
from pathlib import Path
p = Path(sys.argv[1])
err = sys.argv[2]
obj = json.loads(p.read_text(encoding='utf-8'))
attempts = int(obj.get('notifyAttempts', 0) or 0) + 1
obj['notifyAttempts'] = attempts
obj['notifyLastError'] = err[:300]
obj['notifyLastAtUtc'] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
p.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding='utf-8')
print(attempts)
PY
}

for jf in "$JOBDIR"/codex-*.json; do
  [[ -f "$jf" ]] || continue

  status=$(python3 - "$jf" <<'PY'
import json, sys
from pathlib import Path
obj=json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
print(obj.get('status',''))
PY
)

  notified=$(python3 - "$jf" <<'PY'
import json, sys
from pathlib import Path
obj=json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
print(str(obj.get('notified','')))
PY
)

  if [[ "$status" != "done" || "$notified" == "True" || "$notified" == "true" ]]; then
    continue
  fi

  chat_id=$(python3 - "$jf" <<'PY'
import json, sys
from pathlib import Path
obj=json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
print(obj.get('chatId',''))
PY
)

  last_msg=$(python3 - "$jf" <<'PY'
import json, sys
from pathlib import Path
obj=json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
print(obj.get('lastMsg',''))
PY
)

  job_id=$(python3 - "$jf" <<'PY'
import json, sys
from pathlib import Path
obj=json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
print(obj.get('jobId',''))
PY
)

  # Treat missing/invalid chat target as permanently skipped to avoid retry storms.
  if [[ -z "$chat_id" || "$chat_id" == "0" ]]; then
    mark_notified "$jf" "skipped_invalid_chat" "chat_id_empty_or_zero"
    continue
  fi

  if [[ -z "$last_msg" || ! -f "$last_msg" ]]; then
    mark_notified "$jf" "skipped_missing_message" "last_message_file_missing"
    continue
  fi

  sum=$(python3 - "$last_msg" <<'PY'
import sys
from pathlib import Path
s=Path(sys.argv[1]).read_text(encoding='utf-8', errors='replace')
print(s[:3500])
PY
)

  msg=$(printf "[Codex 完成] %s\n\n%s\n\n(文件: %s)" "$job_id" "$sum" "$last_msg")

  if send_err=$(bash "$WS/scripts/telegram_send.sh" "$chat_id" "$msg" 2>&1); then
    mark_notified "$jf" "sent"
    echo "SENT: $job_id"
  else
    attempts=$(record_failure "$jf" "$send_err")
    # Permanent telegram errors should stop retries immediately.
    if echo "$send_err" | rg -qi 'chat not found|bot was blocked by the user|user is deactivated|PEER_ID_INVALID'; then
      mark_notified "$jf" "dropped_permanent_error" "telegram_permanent_error"
      echo "DROP_PERMANENT: $job_id" >&2
      continue
    fi
    if (( attempts >= MAX_NOTIFY_RETRIES )); then
      mark_notified "$jf" "dropped_max_retries" "notify_attempts_exceeded"
      echo "DROP_MAX_RETRIES: $job_id attempts=$attempts" >&2
      continue
    fi
    printf '%s\n' "$send_err" >&2
    echo "SEND_FAILED: $job_id" >&2
  fi

done
