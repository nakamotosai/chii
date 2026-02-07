#!/usr/bin/env python3
import json
import os
import shutil
import time
from pathlib import Path

SKILL_ROOT = Path(__file__).resolve().parents[1]
REFS_DIR = SKILL_ROOT / "references"
REFS_DIR.mkdir(parents=True, exist_ok=True)
WORKSPACE = Path("/home/ubuntu/.openclaw/workspace")
MEMORY_DIR = WORKSPACE / "memory"
MEMORY_DIR.mkdir(parents=True, exist_ok=True)
UPDATE_LOG = MEMORY_DIR / "docs_updates.log"
MANIFEST = REFS_DIR / "docs_manifest.json"
PREV_MANIFEST = REFS_DIR / "docs_manifest.prev.json"
LAST_SUMMARY = REFS_DIR / "last_summary.md"


def load_manifest(path: Path):
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def record_update(changes):
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
    with UPDATE_LOG.open("a", encoding="utf-8") as log:
        for url, info in changes.items():
            log.write(f"{timestamp} | UPDATED | {url} | {info['digest']}\n")

    summary_lines = ["# Latest Learner Docs Update", "", f"Time: {timestamp}", ""]
    for url, info in changes.items():
        summary_lines.append(f"- {url} → {info['path']} (digest {info['digest'][:8]}...)")
    summary_lines.append("\nUpdated-clips stored in learner-docs/docs/")
    LAST_SUMMARY.write_text("\n".join(summary_lines), encoding="utf-8")


def main():
    manifest = load_manifest(MANIFEST)
    prev = load_manifest(PREV_MANIFEST)
    changes = {}
    for url, info in manifest.items():
        prev_digest = prev.get(url, {}).get("digest")
        if info.get("digest") != prev_digest:
            changes[url] = info
    if changes:
        record_update(changes)
        shutil.copy2(MANIFEST, PREV_MANIFEST)
        print(f"Detected {len(changes)} changed entries, summary written.")
    else:
        print("No doc changes detected.")


if __name__ == "__main__":
    main()
