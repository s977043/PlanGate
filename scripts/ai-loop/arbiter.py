#!/usr/bin/env python3
"""arbiter.py — ai-loop L2 裁定エンジン PoC（決定論のみ）。

適用ドメイン: ai-loop-workflow（docs/workflows/ai-loop/ 配下）のみ。
PlanGate 本番フロー（bin/plangate・scripts/hooks/）からは一切呼ばれない
隔離 PoC スクリプト。

正本:
- docs/workflows/ai-loop/decision-table.md（§2 入力軸 / §3 Decision table / §5 provenance）
- docs/ai/ai-loop/ho-paths.md（boundary=touches-HO 判定の正本）
- docs/workflows/ai-loop/lite-criteria.md（lite 4 軸 / AC-8 安全側）
- docs/workflows/ai-loop/flow-detect.md（§3.2.1 severity マッピング / §3.3 C/D 裁定）

本モジュールは python3 標準ライブラリのみに依存する（外部依存なし）。
L2（本裁定器）は「決定論のみ」を担う。LLM 判断（W チェック: Model A/B/C/D）は
L1（呼び出し側）が別途取得し、その verdict を本モジュールへ入力として渡す。

入力（JSON、stdin または --input <file>）:
    {
      "changed_files": [str, ...],
      "lite": {
        "size_ok": bool,
        "no_new_design": bool,
        "follows_pattern": bool,
        "reversible": bool
      },
      "class": "merge" | "no-merge",
      "verdicts": {
        "model_a": "approve" | "reject",
        "model_b": "approve" | "reject",
        "reject_category": str | null,
        "model_c": "approve" | "reject" | null,
        "model_d": "approve" | "reject" | null
      },
      "target_sha": str
    }

出力:
    stdout — provenance JSON（decision-table.md §5 準拠）
    stderr — 人間可読の裁定サマリ（適用 priority と理由）

exit code:
    0 = AUTO_APPROVED
    2 = HUMAN_ESCALATED
    3 = BLOCKED
    1 = 入力エラー（stderr に理由メッセージ必須）
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from typing import Any

# ---------------------------------------------------------------------------
# boundary 判定: HO（Hardening Override）パス一覧
# ---------------------------------------------------------------------------
# 出典: docs/ai/ai-loop/ho-paths.md（本リポジトリの正本）。
# 各エントリは (glob パターン, HO 分類) のタプル。パターン文字列は
# ho-paths.md 本文の表記と 1 文字も違わず一致させること（test_arbiter.py の
# drift テストが本文中の存在を検証する）。
#
# パターン記法（ho-paths.md の記法をそのまま踏襲）:
#   - `*`  : 1 パスセグメント内の任意文字列（"/" をまたがない）
#   - `**` : 0 個以上のパスセグメント（"/" をまたぐ再帰マッチ）
# fnmatch はパスセグメント非対応（`*` が "/" をまたいでしまう）ため、
# 本モジュールでは独自のセグメントベース matcher（_ho_pattern_to_regex）を
# 使用する。
HO_PATTERNS: list[tuple[str, str]] = [
    ("bin/plangate", "HO-core"),  # 実行エンジン本体。AI 直接編集不可
    ("scripts/hooks/**", "HO-hook"),  # フック本体（全ファイル）
    ("schemas/**", "HO-schema"),  # バリデーション定義（全ファイル）
    (".claude/rules/*.md", "HO-rules"),  # L0 契約正本
    (".claude/settings*.json", "HO-settings"),  # Human-owned 設定
    (".claude/settings.local.json", "HO-settings"),  # ローカル設定
    ("CLAUDE.md", "HO-contract"),  # AI-Human 間の基本契約
    ("AGENTS.md", "HO-contract"),  # 同上（Codex 用）
    ("docs/ai/core-contract.md", "HO-contract"),  # Iron Law 正本
    ("docs/ai/*.md", "HO-contract"),  # トップレベルの md のみ（docs/ai/ai-loop/ 配下は対象外。単一セグメント matcher により自動的に除外される）
    (".github/workflows/*.yml", "HO-ci"),  # CI/CD 定義（yml）
    ("**/approvals/*.json", "HO-approval"),  # 人間承認トークン（全階層）
    (".claude/commands/*.md", "HO-rules"),  # コマンド定義
    (".claude/agents/*.md", "HO-rules"),  # Agent 行動契約
    (".claude/settings.example.json", "HO-settings"),  # settings 契約例
    (".github/workflows/*.yaml", "HO-ci"),  # CI/CD 定義（yaml）
    ("plugin/plangate/**", "HO-plugin"),  # プラグイン本体
]


def _ho_pattern_to_regex(pattern: str) -> re.Pattern[str]:
    """HO パターン文字列をセグメント境界を尊重した正規表現へ変換する。

    `*` は 1 セグメント内、`**` は 0 個以上のセグメント（"/" をまたぐ）に
    マッチする。fnmatch / pathlib.PurePath.match はいずれもこの意味論を
    正しく提供しないため、自前で構築する。
    """
    segments = pattern.split("/")
    n = len(segments)
    regex = "^"
    for idx, seg in enumerate(segments):
        is_last = idx == n - 1
        if seg == "**":
            # 0 個以上の "セグメント/" の繰り返しにマッチ。
            regex += "(?:[^/]+/)*"
            if is_last:
                # 末尾の ** は最低 1 セグメントの本体にもマッチさせる
                # （例: "plugin/plangate/**" は "plugin/plangate/index.js" に一致）
                regex += "[^/]+"
            continue

        seg_regex = ""
        for ch in seg:
            if ch == "*":
                seg_regex += "[^/]*"
            elif ch == "?":
                seg_regex += "[^/]"
            else:
                seg_regex += re.escape(ch)
        regex += seg_regex

        if not is_last:
            # 次のセグメントが "**" であっても "/" は必要
            # （"**" グループは先頭に "/" を含まないため）。
            regex += "/"
    regex += "$"
    return re.compile(regex)


_HO_REGEXES: list[tuple[re.Pattern[str], str, str]] = [
    (_ho_pattern_to_regex(pattern), pattern, classification)
    for pattern, classification in HO_PATTERNS
]


def matches_ho_pattern(path: str) -> tuple[bool, str | None, str | None]:
    """path がいずれかの HO パターンに一致するかを判定する。

    戻り値: (一致したか, 一致パターン文字列 or None, HO 分類 or None)
    """
    for regex, pattern, classification in _HO_REGEXES:
        if regex.match(path):
            return True, pattern, classification
    return False, None, None


def boundary_check(changed_files: list[str]) -> tuple[str, list[dict[str, str]]]:
    """boundary 判定: touches-HO | clean。

    出典: docs/ai/ai-loop/ho-paths.md 判定アルゴリズム。
    1 つでも HO パターンに一致すれば touches-HO（即確定）。
    """
    matched: list[dict[str, str]] = []
    for path in changed_files:
        hit, pattern, classification = matches_ho_pattern(path)
        if hit:
            matched.append({"path": path, "pattern": pattern or "", "classification": classification or ""})
    return ("touches-HO" if matched else "clean"), matched


# ---------------------------------------------------------------------------
# lite 判定: 4 軸 AND（AC-8 安全側: 欠落・null・非 bool は false）
# ---------------------------------------------------------------------------
LITE_AXES = ("size_ok", "no_new_design", "follows_pattern", "reversible")


def lite_check(lite_input: Any) -> bool:
    """出典: docs/workflows/ai-loop/lite-criteria.md §2・§3（AC-8 安全側）。

    4 軸すべてが bool 型の True であるときのみ true。
    キー欠落・None・非 bool（0/1/"true" 等含む）は安全側で false 扱いにする。
    """
    if not isinstance(lite_input, dict):
        return False
    for axis in LITE_AXES:
        value = lite_input.get(axis)
        # bool は int のサブクラスのため isinstance(value, bool) を先に確認する
        if not isinstance(value, bool) or value is not True:
            return False
    return True


# ---------------------------------------------------------------------------
# severity 分類（priority 5 時のみ使用）
# ---------------------------------------------------------------------------
# 出典: docs/workflows/ai-loop/flow-detect.md §3.2.1 カテゴリマッピング表。
# 未知カテゴリ・null は安全側既定により critical 扱いとする（本既定は
# マッピング表の改版によっても緩和しない）。
SEVERITY_MAP: dict[str, str] = {
    "ho_path_contact": "critical",
    "permission": "critical",
    "irreversible": "critical",
    "security_break": "critical",
    "public_api": "major",
    "data_integrity": "major",
    "migration": "major",
    "auth_change": "major",
    "logic": "minor",
    "performance": "minor",
    "test_shortage": "minor",
    "documentation": "low",
    "format": "low",
    "naming": "low",
}


def classify_severity(reject_category: str | None) -> str:
    """reject_category → severity。未知・null は critical（安全側既定）。"""
    if reject_category is None:
        return "critical"
    return SEVERITY_MAP.get(reject_category, "critical")


# ---------------------------------------------------------------------------
# 裁定値 → provenance decision 値の対応
# ---------------------------------------------------------------------------
DECISION_AUTO_APPROVED = "AUTO_APPROVED"
DECISION_HUMAN_ESCALATED = "HUMAN_ESCALATED"
DECISION_BLOCKED = "BLOCKED"

EXIT_CODES = {
    DECISION_AUTO_APPROVED: 0,
    DECISION_HUMAN_ESCALATED: 2,
    DECISION_BLOCKED: 3,
}

ISSUED_BY = "arbiter-v0.1"
POLICY_REF = "auto-approve-lite-clean@v0"


class InputError(ValueError):
    """入力 JSON のバリデーションエラー（exit code 1 に対応）。"""


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise InputError(message)


def validate_input(data: Any) -> dict[str, Any]:
    """入力 JSON の構造を検証し、明示的失敗（理由メッセージ付き）を返す。"""
    _require(isinstance(data, dict), "入力は JSON object である必要があります")

    changed_files = data.get("changed_files")
    _require(
        isinstance(changed_files, list) and all(isinstance(p, str) for p in changed_files),
        "changed_files は string のリストである必要があります",
    )

    lite = data.get("lite")
    _require(isinstance(lite, dict), "lite は object である必要があります")

    class_value = data.get("class")
    _require(
        class_value in ("merge", "no-merge"),
        'class は "merge" または "no-merge" である必要があります',
    )

    verdicts = data.get("verdicts")
    _require(isinstance(verdicts, dict), "verdicts は object である必要があります")
    model_a = verdicts.get("model_a")
    model_b = verdicts.get("model_b")
    _require(
        model_a in ("approve", "reject"),
        'verdicts.model_a は "approve" または "reject" である必要があります',
    )
    _require(
        model_b in ("approve", "reject"),
        'verdicts.model_b は "approve" または "reject" である必要があります',
    )

    reject_category = verdicts.get("reject_category")
    _require(
        reject_category is None or isinstance(reject_category, str),
        "verdicts.reject_category は string または null である必要があります",
    )

    for key in ("model_c", "model_d"):
        value = verdicts.get(key)
        _require(
            value is None or value in ("approve", "reject"),
            f'verdicts.{key} は "approve" / "reject" / null である必要があります',
        )

    target_sha = data.get("target_sha")
    _require(isinstance(target_sha, str) and target_sha != "", "target_sha は非空の string である必要があります")

    return data


def build_provenance(
    *,
    decision: str,
    boundary: str,
    lite_result: bool,
    class_value: str,
    target_sha: str,
    model_a: str,
    model_b: str,
    severity: str | None = None,
    model_c: str | None = None,
    model_d: str | None = None,
) -> dict[str, Any]:
    """decision-table.md §5 準拠の provenance JSON を構築する。"""
    w_check: dict[str, Any] = {"model_a": model_a, "model_b": model_b}
    if severity is not None:
        w_check["severity"] = severity
    if model_c is not None:
        w_check["model_c"] = model_c
    if model_d is not None:
        w_check["model_d"] = model_d

    return {
        "decision": decision,
        "issued_by": ISSUED_BY,
        "policy_ref": POLICY_REF,
        "w_check": w_check,
        "target_sha": target_sha,
        "boundary_check": boundary,
        "lite_check": lite_result,
        "class_check": class_value,
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }


def arbitrate(data: dict[str, Any]) -> tuple[dict[str, Any], str]:
    """decision-table.md §3 priority 1〜6 を順に評価し、provenance と適用理由を返す。

    戻り値: (provenance dict, 人間可読の理由サマリ)
    """
    changed_files: list[str] = data["changed_files"]
    lite_input = data["lite"]
    class_value: str = data["class"]
    verdicts: dict[str, Any] = data["verdicts"]
    target_sha: str = data["target_sha"]

    model_a: str = verdicts["model_a"]
    model_b: str = verdicts["model_b"]
    model_c: str | None = verdicts.get("model_c")
    model_d: str | None = verdicts.get("model_d")
    reject_category: str | None = verdicts.get("reject_category")

    boundary, matched = boundary_check(changed_files)
    lite_result = lite_check(lite_input)

    # priority 1: touches-HO は lite / class / verdict を問わず必ず human escalate 固定。
    if boundary == "touches-HO":
        provenance = build_provenance(
            decision=DECISION_HUMAN_ESCALATED,
            boundary=boundary,
            lite_result=lite_result,
            class_value=class_value,
            target_sha=target_sha,
            model_a=model_a,
            model_b=model_b,
        )
        matched_desc = ", ".join(f"{m['path']} ({m['pattern']} / {m['classification']})" for m in matched)
        reason = f"priority 1: boundary=touches-HO（絶対条件・固定）。一致パス: {matched_desc}"
        return provenance, reason

    # priority 2: lite=false は human escalate。
    if not lite_result:
        provenance = build_provenance(
            decision=DECISION_HUMAN_ESCALATED,
            boundary=boundary,
            lite_result=lite_result,
            class_value=class_value,
            target_sha=target_sha,
            model_a=model_a,
            model_b=model_b,
        )
        return provenance, "priority 2: boundary=clean だが lite=false（低リスク要件未充足）"

    # priority 3: class=merge は human escalate（merge=Human-owned 固定）。
    if class_value == "merge":
        provenance = build_provenance(
            decision=DECISION_HUMAN_ESCALATED,
            boundary=boundary,
            lite_result=lite_result,
            class_value=class_value,
            target_sha=target_sha,
            model_a=model_a,
            model_b=model_b,
        )
        return provenance, "priority 3: class=merge（Human-owned 固定）"

    verdict = f"{model_a}-{model_b}"

    # priority 4: reject-reject / reject-approve は blocked。
    if verdict in ("reject-reject", "reject-approve"):
        provenance = build_provenance(
            decision=DECISION_BLOCKED,
            boundary=boundary,
            lite_result=lite_result,
            class_value=class_value,
            target_sha=target_sha,
            model_a=model_a,
            model_b=model_b,
        )
        return provenance, f"priority 4: verdict={verdict}（A が設計妥当性で NG、または両者合意で NG）"

    # priority 6: approve-approve は auto-approve。
    if verdict == "approve-approve":
        provenance = build_provenance(
            decision=DECISION_AUTO_APPROVED,
            boundary=boundary,
            lite_result=lite_result,
            class_value=class_value,
            target_sha=target_sha,
            model_a=model_a,
            model_b=model_b,
        )
        return provenance, "priority 6: verdict=approve-approve（合意）"

    # priority 5: approve-reject → severity 分類 → C/D 裁定。
    # (verdict は入力バリデーションで approve/reject の 2 値に限定済みのため、
    #  ここに到達する場合は必ず approve-reject)
    severity = classify_severity(reject_category)

    if severity in ("critical", "major"):
        provenance = build_provenance(
            decision=DECISION_HUMAN_ESCALATED,
            boundary=boundary,
            lite_result=lite_result,
            class_value=class_value,
            target_sha=target_sha,
            model_a=model_a,
            model_b=model_b,
            severity=severity,
        )
        return (
            provenance,
            f"priority 5: verdict=approve-reject, severity={severity}（reject_category={reject_category!r}）→ human escalate 固定",
        )

    # severity=minor/low → Model C/D 裁定。
    # C か D が欠落している場合は安全側で human escalate。
    if model_c is None or model_d is None:
        provenance = build_provenance(
            decision=DECISION_HUMAN_ESCALATED,
            boundary=boundary,
            lite_result=lite_result,
            class_value=class_value,
            target_sha=target_sha,
            model_a=model_a,
            model_b=model_b,
            severity=severity,
            model_c=model_c,
            model_d=model_d,
        )
        return (
            provenance,
            f"priority 5: severity={severity} だが model_c/model_d のいずれかが欠落 → human escalate（安全側）",
        )

    cd_verdict = f"{model_c}-{model_d}"
    if cd_verdict == "approve-approve":
        decision = DECISION_AUTO_APPROVED
    elif cd_verdict == "reject-reject":
        decision = DECISION_BLOCKED
    else:
        decision = DECISION_HUMAN_ESCALATED

    provenance = build_provenance(
        decision=decision,
        boundary=boundary,
        lite_result=lite_result,
        class_value=class_value,
        target_sha=target_sha,
        model_a=model_a,
        model_b=model_b,
        severity=severity,
        model_c=model_c,
        model_d=model_d,
    )
    return (
        provenance,
        f"priority 5: severity={severity}, C/D 裁定={cd_verdict} → {decision}",
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="ai-loop L2 裁定エンジン PoC（決定論のみ）。入力は stdin または --input で受け取る。",
    )
    parser.add_argument(
        "--input",
        dest="input_path",
        default=None,
        help="入力 JSON ファイルのパス（省略時は stdin から読む）",
    )
    args = parser.parse_args(argv)

    try:
        if args.input_path is not None:
            with open(args.input_path, encoding="utf-8") as f:
                raw = f.read()
        else:
            raw = sys.stdin.read()
    except OSError as exc:
        print(f"[arbiter] 入力エラー: 入力ファイルを読み込めません: {exc}", file=sys.stderr)
        return 1

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        print(f"[arbiter] 入力エラー: JSON パースに失敗しました: {exc}", file=sys.stderr)
        return 1

    try:
        validated = validate_input(data)
    except InputError as exc:
        print(f"[arbiter] 入力エラー: {exc}", file=sys.stderr)
        return 1

    provenance, reason = arbitrate(validated)
    decision = provenance["decision"]

    print(json.dumps(provenance, ensure_ascii=False, indent=2, sort_keys=True))
    print(f"[arbiter] decision={decision} / {reason}", file=sys.stderr)

    return EXIT_CODES[decision]


if __name__ == "__main__":
    sys.exit(main())
