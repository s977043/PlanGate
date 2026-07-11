#!/usr/bin/env python3
"""metrics.py — ai-loop 計測基盤: decision record 集計スクリプト。

適用ドメイン: ai-loop-workflow（docs/workflows/ai-loop/ 配下）のみ。
PlanGate 本番フロー（bin/plangate・scripts/hooks/）からは一切呼ばれない
隔離 PoC スクリプト（arbiter.py と同じ位置付け）。

入力: docs/working/ai-loop-runs/*.json（arbiter.py が発行する裁定 record）。
現行スキーマのキー: boundary_check / class_check / decision / issued_by /
lite_check / policy_ref / target_sha / timestamp / w_check。

将来スキーマ（#809 後に arbiter が刻印予定・additive）: 任意フィールド
`run` = {"run_id": str, "round_index": int, "task_id": str,
"repair_action": str（再試行時のみ・1 行）}。

record の分類（無言の合算・無言の除外の両方を禁止）:
- legacy: `run` フィールドの無い record。集計母数から除外し、除外件数を
  legacy_count として必ず出力へ明示する
- invalid run meta: `run` フィールドはあるが run_id が非空文字列でない
  record（None / "" / 空白のみ / 非 str）。run として集約せず
  invalid_run_meta_count として明示する（falsy run_id の誤集約により
  first-pass rate が歪むことを防ぐ）
- skipped: 破損 JSON / スキーマ外 / round_index の型不正（int 以外。
  bool も不正扱い）。skip 理由と件数を出力に含める（fail-silent 禁止）。
  round_index の型不正は当該 record のみ除外し、run 全体は残す
- run record: 上記以外。run_id 単位に集約し round_index 昇順に並べる。
  round_index 欠落は 0 として扱う（sort 上は先頭に来るが、first_pass 判定
  は round_index == 1 を要求するため欠落 record は first_pass にならない）

同一 run 内で round_index が重複した場合は warnings 配列
（例: "run-X: duplicate round_index 1"）として明示し、集計は継続する。

本モジュールは python3 標準ライブラリのみに依存する（外部依存なし）。

CLI:
    python3 scripts/ai-loop/metrics.py [--runs-dir docs/working/ai-loop-runs]
        [--format md|json]

exit code:
    0 = 正常（skip / warning があっても 0）
    1 = 入力ディレクトリ不在等の明示エラー（stderr にメッセージ必須）
"""

from __future__ import annotations

import argparse
import glob
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any


def _load_records(
    runs_dir: Path,
) -> tuple[list[tuple[str, dict[str, Any]]], list[dict[str, str]]]:
    """runs_dir 配下の *.json を読み込む。

    戻り値: ((file_path, record) のリスト, skip した file の {file, reason} のリスト)。
    破損 JSON・非 dict のトップレベル値・decision 欠落は skip する
    （fail-silent 禁止で理由を記録）。
    """
    entries: list[tuple[str, dict[str, Any]]] = []
    skipped: list[dict[str, str]] = []

    for file_path in sorted(glob.glob(str(runs_dir / "*.json"))):
        try:
            with open(file_path, "r", encoding="utf-8") as fh:
                data = json.load(fh)
        except (OSError, json.JSONDecodeError) as exc:
            skipped.append({"file": file_path, "reason": f"JSON parse error: {exc}"})
            continue

        if not isinstance(data, dict):
            skipped.append(
                {"file": file_path, "reason": "top-level JSON value is not an object"}
            )
            continue

        if "decision" not in data:
            skipped.append(
                {"file": file_path, "reason": "missing required key 'decision'"}
            )
            continue

        entries.append((file_path, data))

    return entries, skipped


def _has_valid_run_id(run_meta: Any) -> bool:
    """run メタが有効な run_id（非空文字列）を持つかを判定する。

    run_id が None / "" / 空白のみ / 非 str の場合は False（invalid run meta）。
    """
    if not isinstance(run_meta, dict):
        return False
    run_id = run_meta.get("run_id")
    return isinstance(run_id, str) and run_id.strip() != ""


def _has_valid_round_index(run_meta: dict[str, Any]) -> bool:
    """round_index が妥当（欠落 or 厳密な int）かを判定する。

    bool は int のサブクラスだが round_index として不正（type(x) is int で除外）。
    """
    if "round_index" not in run_meta:
        return True  # 欠落は 0 扱いで許容（module docstring 参照）
    return type(run_meta["round_index"]) is int


def _group_by_run(
    records: list[dict[str, Any]],
) -> dict[str, list[dict[str, Any]]]:
    """run_id ごとに record をグルーピングし、round_index 昇順に並べる。

    呼び出し前に round_index の型検証（_has_valid_round_index）が済んでいる
    前提（int のみ。欠落は 0 扱い）。
    """
    grouped: dict[str, list[dict[str, Any]]] = {}
    for record in records:
        run_id = record["run"]["run_id"]
        grouped.setdefault(run_id, []).append(record)

    for run_id, run_records in grouped.items():
        run_records.sort(key=lambda r: r["run"].get("round_index", 0))

    return grouped


def collect(runs_dir: Path) -> dict[str, Any]:
    """runs_dir 配下の decision record を集計する。

    仕様:
    - run グルーピング: 有効な run_id（非空文字列）を持つ record を run 単位に
      集約（round_index 昇順）
    - first_pass 導出: round_index == 1 の record が decision ==
      "AUTO_APPROVED" なら first_pass=true（集計側で計算・record には
      刻印しない）
    - failure_category: reject ラウンドの w_check.reject_category（存在すれば）
      を分類キーに使う（新フィールドは発明しない）
    - legacy / invalid run meta / skipped の分類は module docstring 参照。
      いずれも件数を出力へ明示する（無言の合算・無言の除外の両方を禁止）
    - 同一 run 内の round_index 重複は warnings として明示し集計は継続する
    """
    entries, skipped = _load_records(runs_dir)

    legacy_records: list[dict[str, Any]] = []
    invalid_meta_records: list[dict[str, Any]] = []
    run_records: list[dict[str, Any]] = []

    for file_path, record in entries:
        if "run" not in record:
            legacy_records.append(record)
            continue
        if not _has_valid_run_id(record.get("run")):
            invalid_meta_records.append(record)
            continue
        if not _has_valid_round_index(record["run"]):
            bad_value = record["run"]["round_index"]
            skipped.append(
                {
                    "file": file_path,
                    "reason": (
                        "invalid round_index type: "
                        f"{type(bad_value).__name__} ({bad_value!r}) — int のみ許容"
                    ),
                }
            )
            continue
        run_records.append(record)

    grouped = _group_by_run(run_records)

    decision_counts: Counter[str] = Counter()
    round_distribution: Counter[int] = Counter()
    failure_category_breakdown: Counter[str] = Counter()
    warnings: list[str] = []
    first_pass_numerator = 0
    first_pass_denominator = 0

    for run_id, rounds in grouped.items():
        round_distribution[len(rounds)] += 1
        first_pass_denominator += 1

        # 同一 run 内の round_index 重複検知（round 数の過大計上を明示）
        index_counter = Counter(r["run"].get("round_index", 0) for r in rounds)
        for index_value, count in sorted(index_counter.items()):
            if count > 1:
                warnings.append(f"{run_id}: duplicate round_index {index_value}")

        first_round = rounds[0]
        if (
            first_round["run"].get("round_index") == 1
            and first_round.get("decision") == "AUTO_APPROVED"
        ):
            first_pass_numerator += 1

        for rec in rounds:
            decision_counts[rec.get("decision", "UNKNOWN")] += 1
            if rec.get("decision") != "AUTO_APPROVED":
                w_check = rec.get("w_check")
                category = None
                if isinstance(w_check, dict):
                    category = w_check.get("reject_category")
                if category:
                    failure_category_breakdown[category] += 1

    # legacy / invalid run meta も decision 別件数には反映する（総件数の可視性
    # を保つため）。ただし first-pass rate 等の run 単位指標には一切含めない。
    for rec in legacy_records + invalid_meta_records:
        decision_counts[rec.get("decision", "UNKNOWN")] += 1

    rate = (
        first_pass_numerator / first_pass_denominator
        if first_pass_denominator > 0
        else None
    )

    return {
        "total_records": len(legacy_records)
        + len(invalid_meta_records)
        + len(run_records),
        "legacy_count": len(legacy_records),
        "invalid_run_meta_count": len(invalid_meta_records),
        "run_count": len(grouped),
        "first_pass": {
            "numerator": first_pass_numerator,
            "denominator": first_pass_denominator,
            "rate": rate,
        },
        "decision_counts": dict(decision_counts),
        "round_distribution": dict(round_distribution),
        "failure_category_breakdown": dict(failure_category_breakdown),
        "warnings": warnings,
        "skipped_count": len(skipped),
        "skipped": skipped,
    }


def render_markdown(report: dict[str, Any]) -> str:
    """report を Markdown 形式にレンダリングする。"""
    lines: list[str] = []
    lines.append("# ai-loop metrics report")
    lines.append("")
    lines.append(f"- total records: {report['total_records']}")
    lines.append(
        f"- legacy record {report['legacy_count']} 件（run メタ無し・集計対象外）"
    )
    lines.append(
        f"- invalid run meta {report['invalid_run_meta_count']} 件"
        "（run_id が非空文字列でない・run 集計対象外）"
    )
    lines.append(f"- run 数: {report['run_count']}")

    fp = report["first_pass"]
    if fp["denominator"] > 0:
        rate_pct = fp["rate"] * 100
        lines.append(
            f"- first-pass rate: {fp['numerator']}/{fp['denominator']}"
            f" ({rate_pct:.1f}%)（run メタ有り run のみ・分母={fp['denominator']}）"
        )
    else:
        lines.append(
            "- first-pass rate: N/A（run メタ有り record が 0 件のため算出不可・分母=0）"
        )

    lines.append("")
    lines.append("## decision 別件数")
    if report["decision_counts"]:
        for decision, count in sorted(report["decision_counts"].items()):
            lines.append(f"- {decision}: {count}")
    else:
        lines.append("- (該当データなし)")

    lines.append("")
    lines.append("## run あたり round 数分布")
    if report["round_distribution"]:
        for rounds, count in sorted(report["round_distribution"].items()):
            lines.append(f"- {rounds} round: {count} run")
    else:
        lines.append("- (該当データなし・run メタ有り record が 0 件)")

    lines.append("")
    lines.append("## failure_category 内訳")
    if report["failure_category_breakdown"]:
        for category, count in sorted(report["failure_category_breakdown"].items()):
            lines.append(f"- {category}: {count}")
    else:
        lines.append("- (該当データなし)")

    if report["warnings"]:
        lines.append("")
        lines.append("## warnings")
        for warning in report["warnings"]:
            lines.append(f"- {warning}")

    lines.append("")
    lines.append("## skip 件数")
    lines.append(f"- skipped: {report['skipped_count']} 件")
    for item in report["skipped"]:
        lines.append(f"  - {item['file']}: {item['reason']}")

    return "\n".join(lines)


def render_json(report: dict[str, Any]) -> str:
    """report を JSON 文字列にレンダリングする。"""
    return json.dumps(report, ensure_ascii=False, indent=2)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="ai-loop decision record 集計スクリプト（stdlib のみ）"
    )
    parser.add_argument(
        "--runs-dir",
        default="docs/working/ai-loop-runs",
        help="decision record (*.json) が置かれたディレクトリ（default: %(default)s）",
    )
    parser.add_argument(
        "--format",
        choices=("md", "json"),
        default="md",
        help="出力形式（default: %(default)s）",
    )
    args = parser.parse_args(argv)

    runs_dir = Path(args.runs_dir)
    if not runs_dir.is_dir():
        print(
            f"ERROR: --runs-dir が存在しないディレクトリです: {runs_dir}",
            file=sys.stderr,
        )
        return 1

    report = collect(runs_dir)

    if args.format == "json":
        print(render_json(report))
    else:
        print(render_markdown(report))

    return 0


if __name__ == "__main__":
    sys.exit(main())
