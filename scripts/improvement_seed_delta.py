#!/usr/bin/env python3
"""Read-only inventory of confirmed improvement-seeds not indexed by the last digest.

This is evidence for a HUMAN review, not a hygiene classifier or promotion gate.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SEED_HEADING = re.compile(r"^## (\d{4}-\d{2}-\d{2} — .+)$", re.MULTILINE)
DIGEST_SECTION = re.compile(r"^## 対象エントリ\s*\n(.*?)(?=^## |\Z)", re.MULTILINE | re.DOTALL)


def read_confirmed_seeds(path: Path) -> list[str]:
    source = path.read_text(encoding="utf-8")
    matches = list(SEED_HEADING.finditer(source))
    if not matches:
        raise ValueError("no seed entries found")
    entries: list[str] = []
    for index, match in enumerate(matches):
        body = source[match.end():matches[index + 1].start() if index + 1 < len(matches) else len(source)]
        confirmations = re.findall(r"^- confirmed_by:\s*(.+)$", body, flags=re.MULTILINE)
        if len(confirmations) != 1 or not confirmations[0].strip():
            raise ValueError(f"seed has missing or ambiguous human confirmation: {match.group(1)}")
        entries.append(match.group(1))
    if len(entries) != len(set(entries)):
        raise ValueError("duplicate seed heading")
    return entries


def read_digest_index(path: Path) -> list[str]:
    digest = path.read_text(encoding="utf-8")
    section = DIGEST_SECTION.search(digest)
    if section is None:
        raise ValueError("digest is missing the target entry section")
    indexed = []
    for line in section.group(1).splitlines():
        line = line.strip()
        if not line:
            continue
        if not line.startswith("- "):
            raise ValueError("digest entry section contains an unrecognized record")
        title = line[2:].strip()
        if not SEED_HEADING.fullmatch("## " + title):
            raise ValueError("digest entry does not match the seed identity format")
        indexed.append(title)
    if not indexed or len(indexed) != len(set(indexed)):
        raise ValueError("digest index empty or contains duplicates")
    return indexed


def inventory(seeds_path: Path, digest_path: Path, threshold: int) -> dict:
    if threshold < 1:
        raise ValueError("threshold must be positive")
    seeds = read_confirmed_seeds(seeds_path)
    indexed = read_digest_index(digest_path)
    missing = set(indexed) - set(seeds)
    if missing:
        raise ValueError("digest refers to seeds that are absent or unconfirmed")
    new = [entry for entry in seeds if entry not in set(indexed)]
    return {
        "status": "REVIEW_CANDIDATE" if len(new) >= threshold else "BELOW_THRESHOLD",
        "total_confirmed": len(seeds),
        "already_indexed": len(indexed),
        "unindexed_count": len(new),
        "threshold": threshold,
        "unindexed_entries": new,
        "authority": "READ_ONLY_NO_PROMOTION",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seeds", type=Path, required=True)
    parser.add_argument("--digest", type=Path, required=True)
    parser.add_argument("--threshold", type=int, default=5)
    args = parser.parse_args()
    try:
        result = inventory(args.seeds, args.digest, args.threshold)
    except (OSError, ValueError, UnicodeError) as exc:
        print(f"improvement-seed inventory error: {exc}", file=sys.stderr)
        return 2
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
