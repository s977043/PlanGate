#!/usr/bin/env python3
""":"
# --- PG-SH-GUARD (#1169): sh / bash 誤起動ガード ---
# sh はこのファイルの module docstring を二重引用符文字列として読むため、
# docstring 内のバッククォートがコマンド置換として評価され、repo を書き換える
# 副作用が起きる。python3 以外のインタプリタでは何も評価する前にここで止める。
echo "ERROR: $0 is a Python script; do not run it with sh/bash." >&2
echo "       Use: python3 $0 [args...]" >&2
exit 2

残存脅威モデル（本検査は多層防御の 1 層にすぎず、最終保証は C-4 の Human レビュー）
守るもの: 正規形でない見出し / 閉じていない fence / 確認マーカーの欠落・否定値・プレースホルダ
（先頭の BOM は utf-8-sig で除去する）。
守らないもの:
- HTML コメント内の seed も数える（過大計上の向きで fail-open ではない）
- BOM 以外の不可視文字（ZWSP 等）
- 先頭語が no / na の正当な人名を拒否する（安全側の誤り）
- Markdown を正規表現で検査しているという設計上の限界（パーサー化は follow-up）
":"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SEED_HEADING = re.compile(r"^## (\d{4}-\d{2}-\d{2} — .+)$", re.MULTILINE)
SEED_HEADING_LIKE = re.compile(r"^[^\S\n]{0,3}#{1,6}(?!#)[^\n]*\d{4}-\d{2}-\d{2}", re.MULTILINE)
FENCE = re.compile(r"^[ ]{0,3}(`{3,}|~{3,})")
DIGEST_SECTION = re.compile(r"^## 対象エントリ\s*\n(.*?)(?=^## |\Z)", re.MULTILINE | re.DOTALL)
UNCONFIRMED = {
    "<human>", "pending", "tbd", "none", "未確認",
    "no", "n", "false", "-", "n/a", "na", "null", "unconfirmed", "rejected", "なし", "未", "否", "保留",
}


def mask_code_blocks(source: str) -> str:
    lines = source.splitlines(keepends=True)
    fence = None
    for i, line in enumerate(lines):
        opening = FENCE.match(line)
        if fence is None and opening:
            fence = opening.group(1)
        elif (
            fence is not None
            and opening
            and opening.group(1)[0] == fence[0]
            and len(opening.group(1)) >= len(fence)
            and not line[opening.end():].strip()
        ):
            fence = None
        else:
            if fence is None:
                continue
        lines[i] = re.sub(r"[^\n]", " ", line)
    if fence is not None:
        raise ValueError(f"unclosed code fence '{fence}'")
    return "".join(lines)


def is_unconfirmed(value: str) -> bool:
    normalized = value.strip().lower()
    first = re.split(r"[\s（(:：,、]", normalized, maxsplit=1)[0]
    return not normalized or normalized in UNCONFIRMED or first in UNCONFIRMED


def read_declared_seeds(path: Path) -> list[str]:
    source = mask_code_blocks(path.read_text(encoding="utf-8-sig"))
    matches = list(SEED_HEADING.finditer(source))
    if not matches:
        raise ValueError("no seed entries found")
    if len(SEED_HEADING_LIKE.findall(source)) != len(matches):
        raise ValueError("seed heading does not match the canonical '## YYYY-MM-DD — <task_id>' format")
    entries: list[str] = []
    for index, match in enumerate(matches):
        body = source[match.end():matches[index + 1].start() if index + 1 < len(matches) else len(source)]
        confirmations = re.findall(r"^- confirmed_by:[ \t]*(.+)$", body, flags=re.MULTILINE)
        if len(confirmations) != 1 or is_unconfirmed(confirmations[0]):
            raise ValueError(f"seed has missing or ambiguous confirmation marker: {match.group(1)}")
        entries.append(match.group(1))
    if len(entries) != len(set(entries)):
        raise ValueError("duplicate seed heading")
    return entries


def read_digest_index(path: Path) -> list[str]:
    digest = path.read_text(encoding="utf-8-sig")
    sections = list(DIGEST_SECTION.finditer(digest))
    if not sections:
        raise ValueError("digest is missing the target entry section")
    if len(sections) != 1:
        raise ValueError("digest has more than one target entry section")
    section = sections[0]
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
    seeds = read_declared_seeds(seeds_path)
    indexed = read_digest_index(digest_path)
    missing = set(indexed) - set(seeds)
    if missing:
        raise ValueError("digest refers to seeds that are absent or lack a confirmation marker")
    indexed_set = set(indexed)
    new = [entry for entry in seeds if entry not in indexed_set]
    return {
        "status": "REVIEW_CANDIDATE" if len(new) >= threshold else "BELOW_THRESHOLD",
        "entries_with_confirmation_marker": len(seeds),
        "already_indexed": len(indexed),
        "unindexed_count": len(new),
        "threshold": threshold,
        "unindexed_entries": new,
        "authority": "READ_ONLY_UNVERIFIED_MARKER_NO_PROMOTION",
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
