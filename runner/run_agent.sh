#!/usr/bin/env bash
set -euo pipefail

PACKET_FILE="${1:?Usage: run_agent.sh <packet.json> <target-root>}"
TARGET_ROOT="${2:?Usage: run_agent.sh <packet.json> <target-root>}"
TASK_SUMMARY=$(python3 - <<'PY' "$PACKET_FILE"
import json, sys
from pathlib import Path
packet = json.loads(Path(sys.argv[1]).read_text())
print(packet['task_summary'])
PY
)

cd "$TARGET_ROOT"
printf '%s\n' "$TASK_SUMMARY" > .runner-task-summary.txt
if [ ! -f README.md ]; then
  printf '# Runner target\n' > README.md
fi
printf '\n- Runner task: %s\n' "$TASK_SUMMARY" >> README.md
