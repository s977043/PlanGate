#!/usr/bin/env python3
# scripts/batch-acknowledge-skip-decisions.py — TASK-0110 (#301)
#
# docs/working/_audit/skip-decision-log.jsonl の未追認 EH-3_SKIP entry に
# acknowledged_by / acknowledged_at を一括追記する。
#
# 設計原則 (TASK-0110 C-2 review 反映):
#   R-001: --apply は PR ブランチで Human が実行、PR 内に commit を含める
#          (CI "SKIP_REASON 追認" 通過確認 → PR merge の順)
#   R-002: raw-line-preserving (json.loads/dumps しない、既存 key 順・
#          spacing を保持)
#   R-003: --acknowledged-by 必須、commit message に Human 名記録
#   R-004: C-3 同期固定 (mode=light でも非同期降格なし)
#   R-005: dry-run で event:EH-3_SKIP 優先スキャン + reason 集計
#   R-006: acknowledged_at は ISO 8601 UTC (YYYY-MM-DDTHH:MM:SSZ)
#
# 使用例:
#   python3 scripts/batch-acknowledge-skip-decisions.py --dry-run
#   python3 scripts/batch-acknowledge-skip-decisions.py --apply --acknowledged-by s977043
#
# 関連:
#   - scripts/check-skip-acknowledged.sh: CI required "SKIP_REASON 追認"
#   - docs/working/_audit/skip-decision-log.jsonl: 監査ログ正本
#   - docs/ai/skip-acknowledge-cli.md: Human 適用ガイド

import argparse
import datetime
import json
import os
import re
import shutil
import sys
import tempfile
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_LOG = REPO_ROOT / "docs/working/_audit/skip-decision-log.jsonl"


def iso8601_utc_now() -> str:
    """R-006: ISO 8601 UTC (YYYY-MM-DDTHH:MM:SSZ) 形式"""
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_line(line: str) -> dict:
    """JSON parse (validation 用、書き込みには使わない)"""
    return json.loads(line)


def is_eh3_skip_unack(d: dict) -> bool:
    """R-005: event:EH-3_SKIP かつ未追認"""
    return (
        d.get("event") == "EH-3_SKIP"
        and (not d.get("acknowledged_by") or not d.get("acknowledged_at"))
    )


def raw_line_preserving_update(
    line: str, acknowledged_by: str, acknowledged_at: str
) -> str:
    """R-002: raw line を JSON parse/dump せず、2 field のみ regex で置換/追加

    既存 key 順・spacing・escape を破壊しない。
    - `"acknowledged_by":null` → `"acknowledged_by":"<name>"`
    - `"acknowledged_at":null` → `"acknowledged_at":"<ts>"`
    - 両方未存在 (古い entry) → line 末尾 `}` の直前に追加
    """
    # 末尾 newline を保持
    if line.endswith("\n"):
        body = line[:-1]
        nl = "\n"
    else:
        body = line
        nl = ""

    # 置換 1: acknowledged_by
    new_by = '"acknowledged_by":"' + acknowledged_by + '"'
    if '"acknowledged_by":null' in body:
        body = body.replace('"acknowledged_by":null', new_by, 1)
    elif '"acknowledged_by"' not in body:
        # field 不在 → 末尾 } の直前に追加
        body = body[:-1] + "," + new_by + "}"

    # 置換 2: acknowledged_at
    new_at = '"acknowledged_at":"' + acknowledged_at + '"'
    if '"acknowledged_at":null' in body:
        body = body.replace('"acknowledged_at":null', new_at, 1)
    elif '"acknowledged_at"' not in body:
        body = body[:-1] + "," + new_at + "}"

    return body + nl


def atomic_rmw(log_path: Path, new_content: str) -> Path:
    """R-002: .bak 保持 + os.replace の atomic write

    Returns: backup path
    """
    backup = log_path.with_suffix(log_path.suffix + ".bak")
    # backup
    shutil.copy2(log_path, backup)
    # tmp file in same dir (for atomic os.replace)
    fd, tmp_path = tempfile.mkstemp(
        dir=log_path.parent, prefix=log_path.name + ".tmp."
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(new_content)
        # atomic move (POSIX rename)
        os.replace(tmp_path, log_path)
    except Exception:
        # cleanup tmp on error
        if Path(tmp_path).exists():
            os.unlink(tmp_path)
        raise
    return backup


def dry_run(log_path: Path) -> int:
    """R-005: dry-run で EH-3_SKIP 優先スキャン + reason 分布集計"""
    if not log_path.exists():
        print(f"[batch-ack] skip-decision-log なし: {log_path}")
        return 0

    unack_eh3 = []
    other_unack = []
    valid_total = 0
    parse_errors = []

    with open(log_path, encoding="utf-8") as f:
        for i, line in enumerate(f, 1):
            line = line.rstrip("\n")
            if not line:
                continue
            try:
                d = parse_line(line)
                valid_total += 1
            except json.JSONDecodeError as e:
                parse_errors.append((i, str(e)))
                continue

            if is_eh3_skip_unack(d):
                if d.get("event") == "EH-3_SKIP":
                    unack_eh3.append((i, d))
                else:
                    other_unack.append((i, d))

    # Report
    print(f"[batch-ack] dry-run: {log_path}")
    print(f"  valid entries: {valid_total}")
    print(f"  EH-3_SKIP unack: {len(unack_eh3)}")
    print(f"  other unack (event != EH-3_SKIP): {len(other_unack)}")
    print(f"  parse errors: {len(parse_errors)}")

    if unack_eh3:
        print("\n  EH-3_SKIP reason 分布 (上位 10):")
        reasons = Counter(d.get("skip_reason", "<none>") for _, d in unack_eh3)
        for reason, count in reasons.most_common(10):
            print(f"    {count:3d}  {reason}")

        print("\n  sample (先頭 3):")
        for i, d in unack_eh3[:3]:
            print(
                f"    L{i}: target={d.get('target', '<none>')} "
                f"reason={d.get('skip_reason', '<none>')} "
                f"ts={d.get('ts', '<none>')}"
            )

    if parse_errors:
        print("\n  parse errors (上位 5):")
        for i, msg in parse_errors[:5]:
            print(f"    L{i}: {msg}")

    return len(unack_eh3)


def apply_acknowledge(log_path: Path, acknowledged_by: str) -> int:
    """R-002: --apply で atomic update。raw-line-preserving。"""
    if not log_path.exists():
        print(f"[batch-ack] skip-decision-log なし: {log_path}")
        return 0

    if not acknowledged_by or not acknowledged_by.strip():
        print(
            "[batch-ack] FAIL: --acknowledged-by が空文字。Human 名を必須指定",
            file=sys.stderr,
        )
        return -1

    acknowledged_at = iso8601_utc_now()
    updated_count = 0
    new_lines = []

    with open(log_path, encoding="utf-8") as f:
        for line in f:
            stripped = line.rstrip("\n")
            if not stripped:
                new_lines.append(line)
                continue
            try:
                d = parse_line(stripped)
            except json.JSONDecodeError:
                # 不正 entry は触らない
                new_lines.append(line)
                continue

            if is_eh3_skip_unack(d):
                # R-002: raw line update (json.dumps しない)
                new_line = raw_line_preserving_update(
                    line, acknowledged_by, acknowledged_at
                )
                new_lines.append(new_line)
                updated_count += 1
            else:
                new_lines.append(line)

    new_content = "".join(new_lines)

    # R-002: atomic RMW with .bak
    backup = atomic_rmw(log_path, new_content)

    print(f"[batch-ack] apply 完了: {log_path}")
    print(f"  updated entries: {updated_count}")
    print(f"  acknowledged_by: {acknowledged_by}")
    print(f"  acknowledged_at: {acknowledged_at}")
    print(f"  backup: {backup}")

    return updated_count


def main():
    parser = argparse.ArgumentParser(
        description="batch-acknowledge skip-decision-log.jsonl entries (TASK-0110 / #301)"
    )
    parser.add_argument("--dry-run", action="store_true", help="変更せず検出のみ")
    parser.add_argument(
        "--apply", action="store_true", help="実際に追記 (--acknowledged-by 必須)"
    )
    parser.add_argument(
        "--acknowledged-by",
        type=str,
        default="",
        help="Human 名 (例: s977043) (--apply 時必須)",
    )
    parser.add_argument(
        "--log",
        type=str,
        default=str(DEFAULT_LOG),
        help=f"対象 jsonl (default: {DEFAULT_LOG})",
    )
    args = parser.parse_args()

    if not (args.dry_run or args.apply):
        parser.error("--dry-run か --apply のいずれかを指定")

    log_path = Path(args.log).resolve()

    if args.dry_run:
        unack = dry_run(log_path)
        # dry-run は常に exit 0 (検出は通常動作)
        sys.exit(0)

    if args.apply:
        result = apply_acknowledge(log_path, args.acknowledged_by)
        if result < 0:
            sys.exit(1)
        # apply 後の検証 (任意)
        print(
            f"\n[batch-ack] 次のステップ: sh scripts/check-skip-acknowledged.sh で "
            f"CI required \"SKIP_REASON 追認\" PASS を確認"
        )
        sys.exit(0)


if __name__ == "__main__":
    main()
