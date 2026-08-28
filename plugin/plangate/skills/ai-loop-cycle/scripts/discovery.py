#!/usr/bin/env python3
""":"
# --- PG-SH-GUARD (#1169): sh / bash 誤起動ガード ---
# sh はこのファイルの module docstring を二重引用符文字列として読むため、
# docstring 内のバッククォートがコマンド置換として評価され、repo を書き換える
# 副作用が起きる。python3 以外のインタプリタでは何も評価する前にここで止める。
echo "ERROR: $0 is a Python script; do not run it with sh/bash." >&2
echo "       Use: python3 $0 [args...]" >&2
exit 2
":"""

from __future__ import annotations

__doc__ = """discovery.py — ai-loop Triage discovery: read-only 候補提示 CLI（TASK-0818 D-2）。

適用ドメイン: ai-loop-workflow（docs/workflows/ai-loop/ 配下）のみ。
PlanGate 本番フロー（bin/plangate・scripts/hooks/）からは一切呼ばれない
隔離 PoC スクリプト（arbiter.py / metrics.py と同じ位置付け）。

目的: issue キューの中から「ai-loop で自動着手してよい低リスク候補」を
**スコアリングして提示するだけ**の read-only ツール。着手・実行・issue 変更・
git 操作は一切行わない。着手可否の最終判断は既存 Gate（arbiter）が別途行う
— discovery は Gate を bypass しない（正本: docs/working/TASK-0818/design-d1.md）。

入力: issue 配列 JSON ファイル（`gh issue list --json number,title,labels,body`
相当。各要素 `{"number": int, "title": str, "labels": [str,...], "body": str}`）。
discovery.py 自体はファイル入力を受けるだけで gh を直叩きしない
（ネットワーク非依存・決定論・テスト可能）。

スコアリング（opt-in ラベル必須。以下すべてを満たす issue のみ candidate）:
- optin_label: issue.labels に --label 値（既定 ai-loop-auto）を含む
- no_ho_risk: title+body が HO パス/語（.claude/rules・scripts/hooks・
  schema・settings・承認境界 等）を示唆しない
- is_lite: title+body に大規模語（アーキ・横断・リファクタ全体・移行・
  breaking 等）が無い
- deps_resolved: body に未解決依存の示唆（blocked・depends on #・後続 等）
  が無い

判定は安全側（AC-8）: 曖昧・判定不能な場合は「候補外」に倒す
（false-positive で自動対象に誤って入れない）。無言除外は禁止し、excluded
は全件理由付きで出力する。

CLI:
    python3 scripts/ai-loop/discovery.py --issues <path.json>
        [--label ai-loop-auto] [--format md|json] [--ho-paths <path>]
        [--emit-next-command]

exit code:
    0 = 正常（候補あり/なし両方）
    1 = 入力エラー（--issues ファイル不在・JSON 破損等。stderr にメッセージ必須）

禁止（read-only 保証）:
    git 操作 / subprocess での gh 呼び出し / ファイル書き込み（出力は stdout
    のみ）/ issue 変更 / Gate（arbiter）呼び出し・着手 は一切行わない。
"""

import argparse
import json
import re
import sys
import unicodedata
from pathlib import Path
from typing import Any

DEFAULT_LABEL = "ai-loop-auto"

# recommended_next 構造化オブジェクト（TASK-0818 D-3）。discovery は execしない・
# arbiterを呼ばない — human/orchestratorが既存 ai-loop-cycle を辿るための道しるべ。
RECOMMENDED_NEXT_ACTION = "propose-to-ai-loop-cycle"
RECOMMENDED_NEXT_ENTRY_POINT = "docs/workflows/ai-loop/execution-runbook.md"
RECOMMENDED_NEXT_STEP = (
    "human/orchestratorがissueを読み、通常のai-loop-cycle"
    "（W check→arbiter裁定）をこのissueに対して開始する"
)

# 「discoveryはGateをbypassしない」旨の明示（サマリ md/json 共通）。
NO_BYPASS_NOTICE = (
    "次にGateを通すのはHuman/orchestratorの判断であり、discoveryはbypassしない。"
)

# HO（Hardening Override）示唆語 — docs/ai/ai-loop/ho-paths.md の代表パス断片 +
# 承認境界を示す一般語。--ho-paths 指定時はここへ追加でパス断片を取り込む。
DEFAULT_HO_SIGNALS: tuple[str, ...] = (
    "scripts/hooks",
    "bin/plangate",
    ".claude/rules",
    ".claude/settings",
    ".claude/commands",
    ".claude/agents",
    "schemas/",
    ".github/workflows",
    "claude.md",
    "agents.md",
    "hook",
    "schema",
    "settings",
    "承認境界",
    # HO-plugin (ho-paths.md: `plugin/plangate/**`) 事前判定強化
    # (#839 / run-024 乖離是正)。_contains_any は substring 判定のため、
    # "plugin" 1 語のみで "plugin/" "plugin/plangate/" 等のパス断片を
    # すべて包含する（gemini medium 指摘反映・#841。冗長な複数語登録を
    # 廃し "plugin" に集約）。run-024 実測（#837）のように本文が
    # 「plugin 同梱」「plugin bundled」等スラッシュ無しで言及するケース
    # も同じ 1 語で拾う（fail-closed: 除外方向にのみ広げる。ASCII
    # "plugin" のみを対象とし、カタカナ「プラグイン」等の表記ゆれは
    # 非対応 = 偽陰性は後段 arbiter に委ねる）。
    "plugin",
)

# 大規模語（lite 帯を外れるシグナル）。
# 日本語語彙は既存を維持し、英語圏 issue がすり抜けないよう英語語彙を追加する
# （false-positive 修正: Refactor entire auth module / large migration...
# rewriting architecture 等が候補に混入していた実測に基づく）。
LARGE_SCALE_SIGNALS: tuple[str, ...] = (
    "アーキ",
    "横断",
    "リファクタ全体",
    "移行",
    "breaking",
    "破壊的変更",
    "全面書き換え",
    "大規模",
    "refactor",
    "rewrite",
    "migration",
    "migrate",
    "architecture",
    "architectural",
    "cross-cutting",
    "large-scale",
    "overhaul",
    "redesign",
)

# 未解決依存シグナル（直接一致で除外する固定フレーズ）。
# 「waiting on #55 / #90 の完了を待って」等の言い回しがすり抜けていた実測に
# 基づき追加（false-positive 修正）。
DEPENDENCY_SIGNALS: tuple[str, ...] = (
    "blocked",
    "block",
    "depends on #",
    "後続",
    "waiting on",
    "wait for",
    "待って",
    "待ち",
    "保留",
    "未完了",
    "pending #",
)

# #数字 と共存する場合にのみ依存ありと判定する語幹（over-exclusion回避:
# #数字単独では依存判定しない。DEPENDENCY_SIGNALS の固定フレーズより広い
# 語幹をここに限定し、#数字との共起を条件とすることで誤検出を抑える）。
DEPENDENCY_ISSUE_NUMBER_STEMS: tuple[str, ...] = (
    "waiting",
    "wait",
    "depends",
    "blocked",
    "block",
    "待",
    "保留",
    "後続",
    "pending",
)

_ISSUE_NUMBER_RE = re.compile(r"#\d+")


def _has_dependency_with_issue_number(text: str) -> bool:
    """text 内に #数字 と依存語幹が共存する場合に True を返す。

    #数字単独（依存語なし）は False のまま（over-exclusion回避 / AC-8 と対）。
    """
    if not _ISSUE_NUMBER_RE.search(text):
        return False
    return any(stem in text for stem in DEPENDENCY_ISSUE_NUMBER_STEMS)


_HO_PATH_CELL_RE = re.compile(r"`([^`]+)`")


def _load_issues(path: Path) -> list[dict[str, Any]]:
    """--issues ファイルを読み込み issue 配列を返す。

    入力エラー（不在・JSON 破損・配列でない）は ValueError を送出する。
    呼び出し側で exit 1 + stderr メッセージにマッピングする。
    """
    if not path.is_file():
        raise ValueError(f"--issues file not found: {path}")
    try:
        raw = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise ValueError(f"--issues file unreadable: {path} ({exc})") from exc
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ValueError(f"--issues file is not valid JSON: {path} ({exc})") from exc
    if not isinstance(data, list):
        raise ValueError(f"--issues file must contain a JSON array: {path}")
    return data


def _load_ho_signals(ho_paths_file: Path | None) -> tuple[str, ...]:
    """ho-paths.md からパス断片を抽出し、既定シグナル語に追加する。

    --ho-paths 未指定、またはファイルが読めない場合は既定シグナルのみを返す
    （安全側: 追加シグナルが取れなくても既定の判定は維持する）。
    """
    if ho_paths_file is None:
        return DEFAULT_HO_SIGNALS
    if not ho_paths_file.is_file():
        return DEFAULT_HO_SIGNALS
    try:
        text = ho_paths_file.read_text(encoding="utf-8")
    except OSError:
        return DEFAULT_HO_SIGNALS

    fragments: list[str] = []
    for cell in _HO_PATH_CELL_RE.findall(text):
        # 「変更禁止」「approvals」等の非パスバッククォートも混ざるため、
        # パスらしい断片（記号 / . を含む）だけを採用する。
        stripped = cell.strip().strip("*")
        if not stripped:
            continue
        if "/" not in stripped and "." not in stripped:
            continue
        fragments.append(stripped.lower())

    combined = list(DEFAULT_HO_SIGNALS)
    for frag in fragments:
        if frag not in combined:
            combined.append(frag)
    return tuple(combined)


def _contains_any(haystack: str, signals: tuple[str, ...]) -> str | None:
    """haystack（小文字化済み）に signals のいずれかが含まれれば、その語を返す。"""
    for signal in signals:
        if signal and signal.lower() in haystack:
            return signal
    return None


def evaluate_issue(
    issue: dict[str, Any],
    label: str,
    ho_signals: tuple[str, ...],
) -> dict[str, Any]:
    """1 issue を評価し、判定結果（candidate/excluded と理由）を返す。

    判定は安全側（AC-8）: number/title/body/labels の型が期待と異なる場合や
    判定不能な場合は「候補外」に倒す。
    """
    number = issue.get("number")
    title = issue.get("title")
    body = issue.get("body")
    labels = issue.get("labels")

    title_str = title if isinstance(title, str) else ""
    body_str = body if isinstance(body, str) else ""
    label_list = labels if isinstance(labels, list) else []
    label_names = {
        (entry if isinstance(entry, str) else entry.get("name", ""))
        for entry in label_list
        if isinstance(entry, (str, dict))
    }

    # 全角文字（全角英字・全角記号等）を NFKC で正規化してから小文字化する。
    # 正規化前は「ｓｃｒｉｐｔｓ／ｈｏｏｋｓ」等の全角表記が半角シグナルに
    # マッチせず no_ho_risk=true の false-positive になっていた（fix 3, minor）。
    text = unicodedata.normalize("NFKC", f"{title_str}\n{body_str}").lower()

    reasons: dict[str, bool] = {}

    has_label = label in label_names
    reasons["optin_label"] = has_label
    if not has_label:
        return {
            "number": number,
            "title": title_str,
            "candidate": False,
            "reason": "no-optin-label",
            "reasons": reasons,
        }

    ho_hit = _contains_any(text, ho_signals)
    reasons["no_ho_risk"] = ho_hit is None
    if ho_hit is not None:
        return {
            "number": number,
            "title": title_str,
            "candidate": False,
            "reason": "ho-risk",
            "reasons": reasons,
        }

    scale_hit = _contains_any(text, LARGE_SCALE_SIGNALS)
    reasons["is_lite"] = scale_hit is None
    if scale_hit is not None:
        return {
            "number": number,
            "title": title_str,
            "candidate": False,
            "reason": "not-lite",
            "reasons": reasons,
        }

    dep_hit = _contains_any(text, DEPENDENCY_SIGNALS)
    if dep_hit is None and _has_dependency_with_issue_number(text):
        dep_hit = "issue-number+dependency-word"
    reasons["deps_resolved"] = dep_hit is None
    if dep_hit is not None:
        return {
            "number": number,
            "title": title_str,
            "candidate": False,
            "reason": "dependency",
            "reasons": reasons,
        }

    return {
        "number": number,
        "title": title_str,
        "candidate": True,
        "reasons": reasons,
        "recommended_next": {
            "action": RECOMMENDED_NEXT_ACTION,
            "entry_point": RECOMMENDED_NEXT_ENTRY_POINT,
            "next_step": RECOMMENDED_NEXT_STEP,
        },
    }


def _build_next_command(number: Any) -> str:
    """人間がコピペ実行できる提案コマンド文字列を生成する（discovery自身は実行しない）。"""
    return f"# candidate #{number}: 'ai-loop-cycle' skill を issue #{number} に対して開始してください"


def run_discovery(
    issues: list[dict[str, Any]],
    label: str,
    ho_signals: tuple[str, ...],
    emit_next_command: bool = False,
) -> dict[str, Any]:
    """全 issue を評価し candidates/excluded/summary を構築する（read-only・純関数）。

    emit_next_command=True の場合、各 candidate に人間がコピペ実行できる
    提案コマンド文字列（next_command）を付加する。discovery 自身はこの
    コマンドを一切実行しない（文字列生成のみ・subprocess呼び出し禁止）。
    """
    candidates: list[dict[str, Any]] = []
    excluded: list[dict[str, Any]] = []
    no_label_count = 0

    for issue in issues:
        result = evaluate_issue(issue, label, ho_signals)
        if result["candidate"]:
            candidate: dict[str, Any] = {
                "number": result["number"],
                "title": result["title"],
                "reasons": result["reasons"],
                "recommended_next": result["recommended_next"],
            }
            if emit_next_command:
                candidate["next_command"] = _build_next_command(result["number"])
            candidates.append(candidate)
        else:
            excluded.append(
                {
                    "number": result["number"],
                    "title": result["title"],
                    "reason": result["reason"],
                }
            )
            if result["reason"] == "no-optin-label":
                no_label_count += 1

    return {
        "candidates": candidates,
        "excluded": excluded,
        "summary": {
            "candidate_count": len(candidates),
            "excluded_count": len(excluded),
            "no_label_count": no_label_count,
            "no_bypass_notice": NO_BYPASS_NOTICE,
        },
    }


def format_json(result: dict[str, Any]) -> str:
    return json.dumps(result, ensure_ascii=False, indent=2)


def format_md(result: dict[str, Any]) -> str:
    lines: list[str] = ["# ai-loop discovery 候補提示（read-only）", ""]

    summary = result["summary"]
    lines.append(
        "- candidate: {c} / excluded: {e} / no-optin-label: {n}".format(
            c=summary["candidate_count"],
            e=summary["excluded_count"],
            n=summary["no_label_count"],
        )
    )
    lines.append(f"- {summary['no_bypass_notice']}")
    lines.append("")

    lines.append("## Candidates")
    if not result["candidates"]:
        lines.append("")
        lines.append("候補なし。")
    else:
        lines.append("")
        lines.append("| number | title | recommended_next | reasons |")
        lines.append("|---|---|---|---|")
        for cand in result["candidates"]:
            reasons_str = ", ".join(
                f"{k}={'OK' if v else 'NG'}" for k, v in cand["reasons"].items()
            )
            next_action = cand["recommended_next"]["action"]
            lines.append(
                f"| #{cand['number']} | {cand['title']} | "
                f"{next_action} | {reasons_str} |"
            )
        if any("next_command" in cand for cand in result["candidates"]):
            lines.append("")
            lines.append("### 提案コマンド（人間がコピペ実行・discoveryは実行しない）")
            lines.append("")
            for cand in result["candidates"]:
                if "next_command" in cand:
                    lines.append(cand["next_command"])
    lines.append("")

    lines.append("## Excluded（無言除外なし・全件理由付き）")
    if not result["excluded"]:
        lines.append("")
        lines.append("除外なし。")
    else:
        lines.append("")
        lines.append("| number | title | reason |")
        lines.append("|---|---|---|")
        for exc in result["excluded"]:
            lines.append(f"| #{exc['number']} | {exc['title']} | {exc['reason']} |")
    lines.append("")

    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "ai-loop Triage discovery — read-only 候補提示 CLI（TASK-0818 D-2）。"
            "着手・実行・issue 変更・git 操作は一切行わない。"
        )
    )
    parser.add_argument(
        "--issues",
        required=True,
        type=Path,
        help="issue 配列 JSON ファイル（gh issue list --json ... 相当）",
    )
    parser.add_argument(
        "--label",
        default=DEFAULT_LABEL,
        help=f"opt-in ラベル（既定 {DEFAULT_LABEL}）",
    )
    parser.add_argument(
        "--format",
        choices=("md", "json"),
        default="md",
        help="出力形式（既定 md）",
    )
    parser.add_argument(
        "--ho-paths",
        type=Path,
        default=None,
        help="ho-paths.md パス（HO シグナル拡充用・任意）",
    )
    parser.add_argument(
        "--emit-next-command",
        action="store_true",
        default=False,
        help=(
            "候補ごとに人間がコピペ実行できる提案コマンド文字列を出力に含める"
            "（discovery自身は実行しない・read-only維持・既定false）"
        ),
    )
    args = parser.parse_args(argv)

    try:
        issues = _load_issues(args.issues)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    ho_signals = _load_ho_signals(args.ho_paths)
    result = run_discovery(
        issues, args.label, ho_signals, emit_next_command=args.emit_next_command
    )

    if args.format == "json":
        print(format_json(result))
    else:
        print(format_md(result))

    return 0


if __name__ == "__main__":
    sys.exit(main())
