#!/usr/bin/env bash
set -euo pipefail

PACKET_FILE="${1:?Usage: push_branch_and_pr.sh <packet.json> <target-root>}"
TARGET_ROOT="${2:?Usage: push_branch_and_pr.sh <packet.json> <target-root>}"

TARGET_REPO=$(python3 - <<'PY' "$PACKET_FILE"
import json, sys
from pathlib import Path
packet = json.loads(Path(sys.argv[1]).read_text())
print(packet['target_repo'])
PY
)
TARGET_BRANCH=$(python3 - <<'PY' "$PACKET_FILE"
import json, sys
from pathlib import Path
packet = json.loads(Path(sys.argv[1]).read_text())
print(packet['target_branch'])
PY
)
WORK_BRANCH=$(python3 - <<'PY' "$PACKET_FILE"
import json, sys
from pathlib import Path
packet = json.loads(Path(sys.argv[1]).read_text())
print(packet['work_branch'])
PY
)
TASK_SUMMARY=$(python3 - <<'PY' "$PACKET_FILE"
import json, sys
from pathlib import Path
packet = json.loads(Path(sys.argv[1]).read_text())
print(packet['task_summary'])
PY
)
DRAFT_FLAG=$(python3 - <<'PY' "$PACKET_FILE"
import json, sys
from pathlib import Path
packet = json.loads(Path(sys.argv[1]).read_text())
print('--draft' if packet.get('draft_pr') else '')
PY
)

if [ -z "${TARGET_REPO_TOKEN:-}" ]; then
    echo "ERROR: TARGET_REPO_TOKEN must be set" >&2
    exit 1
fi

cd "$TARGET_ROOT"
git config user.name "${GIT_USER_NAME:-public-runner-bot}"
git config user.email "${GIT_USER_EMAIL:-bot@public-runner.local}"
git add -A
git commit -m "feat(runner): ${TASK_SUMMARY}" || true
git push origin HEAD
export GH_TOKEN="$TARGET_REPO_TOKEN"
PR_URL=$(gh pr create --repo "$TARGET_REPO" --title "$TASK_SUMMARY" --body "Automated change from public runner." --base "$TARGET_BRANCH" ${DRAFT_FLAG:+$DRAFT_FLAG})
printf '%s\n' "$PR_URL"
