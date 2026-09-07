#!/usr/bin/env python3
"""Flip a task's `passes` flag in prd.json.

Usage: python3 scripts/mark-task.py <task-id> [true|false]
Rewrites prd.json with the same 2-space indentation so diffs stay one line.
"""
import json
import sys
from pathlib import Path

task_id = sys.argv[1]
value = (sys.argv[2] if len(sys.argv) > 2 else "true").lower() == "true"
path = Path(__file__).resolve().parent.parent / "prd.json"
prd = json.loads(path.read_text())
for task in prd["tasks"]:
    if task["id"] == task_id:
        if task["passes"] == value:
            sys.exit(f"task {task_id}: passes already {value}")
        task["passes"] = value
        path.write_text(json.dumps(prd, indent=2, ensure_ascii=False) + "\n")
        print(f"task {task_id}: passes={value}")
        break
else:
    sys.exit(f"task {task_id} not found in prd.json")
