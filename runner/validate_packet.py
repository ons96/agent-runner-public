#!/usr/bin/env python3

import json
import sys
from pathlib import Path
from typing import Any

REQUIRED_KEYS = {
    "task_id",
    "staging_repo",
    "target_repo",
    "target_branch",
    "work_branch",
    "task_summary",
    "allowed_paths",
    "acceptance_criteria",
    "merge_policy",
}


def load_packet(path: str) -> dict[str, Any]:
    packet = json.loads(Path(path).read_text())
    if not isinstance(packet, dict):
        raise SystemExit("Packet must be a JSON object")
    return packet


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: validate_packet.py <packet.json>")

    packet = load_packet(sys.argv[1])
    missing = sorted(REQUIRED_KEYS - set(packet))
    if missing:
        raise SystemExit(f"Packet missing keys: {', '.join(missing)}")

    if packet["merge_policy"] == "blocked":
        raise SystemExit("Packet is blocked by merge policy")

    print("Packet validation passed")


if __name__ == "__main__":
    main()
