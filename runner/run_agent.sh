#!/usr/bin/env bash
set -euo pipefail

PACKET_FILE="${1:?Usage: run_agent.sh <packet.json> <target-root>}"
TARGET_ROOT="${2:?Usage: run_agent.sh <packet.json> <target-root>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

read -r TARGET_REPO TASK_TEXT MODE < <(python3 - <<'PY' "$PACKET_FILE"
import json, sys
from pathlib import Path
packet = json.loads(Path(sys.argv[1]).read_text())
repo = packet.get('target_repo', packet.get('repo', ''))
task = packet.get('task_prompt') or packet.get('task') or packet.get('task_summary', 'implement the project')
mode = packet.get('mode', 'implement')
print(f"{repo}\t{task[:500]}\t{mode}")
PY
)

echo "=== Runner Agent ==="
echo "Repo: $TARGET_REPO"
echo "Task: ${TASK_TEXT:0:100}..."
echo "Mode: $MODE"

cd "$TARGET_ROOT"

cat > .runner-task.md << EOF
# Runner Task
**Repo:** $TARGET_REPO
**Mode:** $MODE
## Task
$TASK_TEXT
EOF

if [ -f "$SCRIPT_DIR/opencode-runner.json" ]; then
    cp "$SCRIPT_DIR/opencode-runner.json" .opencode.json
fi

echo ">>> Running OpenCode..."
if timeout 3600 env -i PATH="$PATH" HOME="$HOME" \
  opencode --dangerously-skip-permissions -m opencode/deepseek-v4-flash-free run "$TASK_TEXT" 2>&1 | tee .runner-log.txt; then
    echo ">>> OpenCode completed"
else
    echo ">>> OpenCode failed or timed out"
fi

echo "=== Agent run complete ==="
ls -la
