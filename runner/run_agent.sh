#!/usr/bin/env bash
# run_agent.sh - Execute agentic coding task via LLM API (autonomous, headless)
set -euo pipefail

PACKET_FILE="${1:?Usage: run_agent.sh <packet.json> <target-root>}"
TARGET_ROOT="${2:?Usage: run_agent.sh <packet.json> <target-root>}"

# Extract task details from packet
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

# =============================================================================
# PRIMARY: Direct LLM API (reliable for headless use)
# =============================================================================
echo ">>> Calling LLM API..."
python3 /dev/stdin "$TASK_TEXT" << 'PYEOF' 2>&1 | tee .runner-log.txt
import json, os, re, sys, urllib.request

task = sys.argv[1]

prompt = f"""You are a coding agent running in a CI/CD pipeline.
Implement the following task in the CURRENT directory.

TASK:
{task}

IMPORTANT RULES:
- Create ONLY the files specified in the task
- Keep it simple - no unnecessary files
- Include a README.md with usage instructions
- Respond with ONLY valid JSON in this format:
{{"files": [{{"path": "filename.txt", "content": "file content here"}}]}}"""

endpoints = []

# Groq (from environment)
gk = os.environ.get("GROQ_API_KEY", "")
if gk:
    endpoints.append(("https://api.groq.com/openai/v1/chat/completions", gk, "llama-3.3-70b-versatile"))

# VPS gateway (from environment)
pk = os.environ.get("PROXY_API_KEY", "")
if pk and pk != "poop96":
    endpoints.append(("http://40.233.101.233:8000/v1/chat/completions", pk, "coding-elite"))

for url, api_key, model in endpoints:
    try:
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
        data = json.dumps({
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": 4000,
            "temperature": 0.3
        }).encode()
        req = urllib.request.Request(url, data, headers)
        resp = urllib.request.urlopen(req, timeout=180)
        result = json.loads(resp.read())
        content = result["choices"][0]["message"]["content"]
        print(f"OK {url} ({model})")

        match = re.search(r'\{[\s\S]*"files"[\s\S]*?\}', content)
        if match:
            files_data = json.loads(match.group())
            for f in files_data.get("files", []):
                path = f["path"]
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with open(path, "w") as fp:
                    fp.write(f["content"])
                print(f"  created: {path}")
            break
        else:
            print(f"no JSON in response: {content[:200]}")
    except Exception as e:
        print(f"  {url} failed: {e}")
        continue
else:
    print("All endpoints failed")
PYEOF

echo "=== Agent run complete ==="
ls -la
