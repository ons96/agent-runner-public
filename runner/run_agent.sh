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

echo ">>> Running task..."

# Write agent script to temp file to avoid heredoc issues
cat > /tmp/agent_task.py << 'PYEOF'
import json, os, re, sys, urllib.request

task = sys.argv[1]
created = []

gk = os.environ.get("GROQ_API_KEY", "")
if gk:
    prompt = f"""You are a coding agent. Implement this task in the current directory.
TASK: {task}
Respond with ONLY JSON: {{"files": [{{"path": "filename", "content": "text"}}]}}"""
    try:
        data = json.dumps({"model": "llama-3.3-70b-versatile", "messages": [{"role": "user", "content": prompt}], "max_tokens": 4000, "temperature": 0.3}).encode()
        req = urllib.request.Request("https://api.groq.com/openai/v1/chat/completions", data, {"Authorization": f"Bearer {gk}", "Content-Type": "application/json"})
        resp = json.loads(urllib.request.urlopen(req, timeout=180).read())
        content = resp["choices"][0]["message"]["content"]
        match = re.search(r'\{[\s\S]*"files"[\s\S]*?\}', content)
        if match:
            for f in json.loads(match.group()).get("files", []):
                os.makedirs(os.path.dirname(f["path"]), exist_ok=True)
                with open(f["path"], "w") as fp: fp.write(f["content"])
                created.append(f["path"])
            print(f"OK via Groq API: {', '.join(created)}")
        else:
            print(f"no JSON in response: {content[:200]}")
    except Exception as e:
        print(f"Groq failed: {e}")

if not created:
    m = re.search(r'(?:create|make|add|write)\s+(?:a\s+)?(?:file\s+)?(?:called\s+|named\s+)?["\']?([^"\'.,\s]+\.[^"\'.,\s]+)["\']?\s*(?:with\s+(?:the\s+)?(?:content|text)\s+)?["\']?(.+?)["\']?$', task, re.I | re.S)
    if m:
        path = m.group(1).strip()
        content = m.group(2).strip().rstrip('.')
        # Remove trailing "and create a PR" etc
        content = re.sub(r'\s+and\s+create\s+a\s+PR\.?\s*$', '', content, flags=re.I)
        dirn = os.path.dirname(path)
        if dirn: os.makedirs(dirn, exist_ok=True)
        with open(path, "w") as fp: fp.write(content)
        created.append(path)
        print(f"created: {path}")

if not created:
    with open("output.txt", "w") as fp: fp.write(f"Task: {task}\n")
    created.append("output.txt")
    print(f"created: output.txt (task summary)")

print(f"Done: {len(created)} file(s)")
PYEOF

python3 /tmp/agent_task.py "$TASK_TEXT" 2>&1 | tee .runner-log.txt

echo "=== Agent run complete ==="
ls -la
