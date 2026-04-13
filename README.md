# Public Runner Scaffold

This directory is a scaffold for the future public runner repository used by Option B.

## Intended contents
- `.github/workflows/runner-dispatch.yml`
- `.github/workflows/runner-execute.yml`
- `runner/validate_packet.py`
- `runner/checkout_target.sh`
- `runner/run_agent.sh`
- `runner/push_branch_and_pr.sh`
- `runner/report_result.py`
- `runner/secret_guard.py`

## Purpose
The public runner repo should:
- receive sanitized task packets from the private staging repo
- validate packets
- checkout target repos with scoped credentials
- create branches and PRs in target repos
- report only result metadata back to staging

It should not contain planning/state files.
