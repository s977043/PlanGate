#!/usr/bin/env python3
"""arbiter.py — ai-loop L2 裁定エンジン PoC（決定論のみ）。

適用ドメイン（Phase 1 / #807）: ①plangate 本体 = docs/workflows/ai-loop/ 配下のみ
（dogfooding 域）②導入先リポジトリ = ho-paths 確定 + LoopSpec scope.allowed_paths
宣言を前提に適用可。PlanGate 本番フロー（bin/plangate・scripts/hooks/）からは
一切呼ばれない隔離 PoC スクリプト。

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
      "allowed_paths": [str, ...],
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
      "target_sha": str,
      "run": {                          # 任意（#780 Slice D 後半 追加・additive）
        "run_id": str,                  #   非空 string（run 単位の連番識別子）
        "round_index": int,             #   bool 不可・必須（run 提供時）
        "task_id": str,
        "repair_action": str            #   任意（再試行時のみ）
      } | 省略可                        # 省略時は provenance に run キー自体を刻まない（null も出さない）
    }

`allowed_paths` は LoopSpec `scope.allowed_paths`（既存必須フィールド）宣言を
そのまま渡す非空の string リスト。必須。`changed_files` の各パスがこの
リストのいずれの glob にも一致しない場合、scope 逸脱として human escalate
する（#809）。ただし HO 接触判定（boundary=touches-HO）が常に先に評価され、
allowed_paths に HO パスを含めても HO escalate は免れない（design-philosophy
I-1 不変条件）。

`run`（#780 Slice D 後半 追加）は任意フィールド。指定すると全裁定経路の
provenance にそのまま刻まれ、`scripts/ai-loop/metrics.py`（#812）が run 単位の
集計（first-pass rate 等）に用いる。省略可・後方互換（既存呼び出しを壊さない）。
**省略時は provenance に `run` キー自体を刻まない**（`"run": null` を出さない）ため、
metrics.py は当該 record を legacy（run メタ未計装）に分類し invalid_run_meta へ
誤計上しない。gate 挙動は変えないため POLICY_REF のバージョンは進めない。

CLI:
    --input <file>      入力 JSON ファイル（省略時は stdin）
    --ho-paths <file>   HO パス一覧（ho-paths.md）の明示パス（#809）。
                        省略時は実行時解決（下記）。

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
import dataclasses
import functools
import json
import pathlib
import posixpath
import re
import sys
from datetime import datetime, timezone
from typing import Any

# ---------------------------------------------------------------------------
# boundary 判定: HO（Hardening Override）パス一覧（実行時解決 + fail-closed / #809）
# ---------------------------------------------------------------------------
# 出典: docs/ai/ai-loop/ho-paths.md（本リポジトリの正本）の「## HO パス一覧」表。
# ハードコード定数は持たず、実行時に ho-paths.md 本文をパースして
# (glob パターン, HO 分類) のリストを構築する（導入先リポジトリ固有の
# ho-paths.md にも同一コードで対応するため）。
#
# パターン記法（ho-paths.md の記法をそのまま踏襲）:
#   - `*`  : 1 パスセグメント内の任意文字列（"/" をまたがない）
#   - `**` : 0 個以上のパスセグメント（"/" をまたぐ再帰マッチ）
# fnmatch はパスセグメント非対応（`*` が "/" をまたいでしまう）ため、
# 本モジュールでは独自のセグメントベース matcher（_ho_pattern_to_regex）を
# 使用する。

#: ho-paths.md 本文の「## HO パス一覧」表の 1 行から第 1 列（バッククォート
#: 内のパターン文字列）を抽出する正規表現。列内に注釈括弧（例:
#: `` `docs/ai/*.md`（トップレベルの md のみ。`docs/ai/ai-loop/` 配下は対象外） ``）
#: が付随する場合も、**最初の** バッククォート区間のみを採用することで
#: 注釈中の入れ子バッククォート例を誤って拾わない。
_HO_TABLE_PATTERN_RE = re.compile(r"`([^`]+)`")

#: CLI 未指定時に解決を試みる既定候補（本リポジトリ本体配置）。
_DEFAULT_HO_PATHS_RELATIVE = ("docs", "ai", "ai-loop", "ho-paths.md")
#: CLI 未指定時に解決を試みる第 2 候補（plugin bundled 配置。スクリプト自身の
#: 配置ディレクトリの親 = スキルルート、その配下の references/ho-paths.md）。
_BUNDLED_HO_PATHS_RELATIVE = ("references", "ho-paths.md")


def parse_ho_paths_table(content: str) -> list[tuple[str, str]]:
    """ho-paths.md 本文の「## HO パス一覧」表から (pattern, classification) を抽出する。

    行が「`| `pattern`（backtick 区切り） | 分類 | 理由 |`」形式であることのみを前提とする
    （バッククォート付き第 1 列を持つ行のみが対象。見出し行・区切り行・
    「## 分類定義」等の他表はバッククォート付き第 1 列を持たないため自動的に
    除外される）。パース結果が 0 件の場合は空リストを返す（fail-closed の
    判断は呼び出し側 resolve_ho_patterns / arbitrate が担う）。
    """
    patterns: list[tuple[str, str]] = []
    for line in content.splitlines():
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue
        cells = stripped.split("|")
        if len(cells) < 4:
            continue
        match = _HO_TABLE_PATTERN_RE.search(cells[1])
        if not match:
            continue
        classification = cells[2].strip()
        if not classification:
            continue
        patterns.append((match.group(1), classification))
    return patterns


def _candidate_ho_paths_sources(cli_path: str | None) -> list[pathlib.Path]:
    """ho-paths.md の解決候補パスを優先順位順に返す。

    解決順（#809）: (1) CLI 明示指定 → (2) CWD の docs/ai/ai-loop/ho-paths.md
    → (3) スクリプト位置基準の ../references/ho-paths.md（plugin bundled 配置用）。
    CLI 指定時は他候補を一切試さない（明示指定を無条件優先）。
    """
    if cli_path:
        return [pathlib.Path(cli_path)]
    script_dir = pathlib.Path(__file__).resolve().parent
    return [
        pathlib.Path.cwd().joinpath(*_DEFAULT_HO_PATHS_RELATIVE),
        script_dir.parent.joinpath(*_BUNDLED_HO_PATHS_RELATIVE),
    ]


def resolve_ho_patterns(
    cli_path: str | None = None,
) -> tuple[list[tuple[str, str]], str | None, list[str]]:
    """HO パターンを実行時解決する（fail-closed / #809）。

    戻り値: (patterns, resolved_source_path or None, searched_paths)
    いずれの候補も存在しない、または存在するがパース結果が 0 件の場合は
    patterns=[] を返す（呼び出し側 arbitrate() が全件 HUMAN_ESCALATED に
    フォールバックする責務を持つ。fail-open は絶対に行わない）。
    """
    searched: list[str] = []
    for candidate in _candidate_ho_paths_sources(cli_path):
        searched.append(str(candidate))
        if not candidate.is_file():
            continue
        try:
            content = candidate.read_text(encoding="utf-8")
        except (OSError, ValueError):
            # UnicodeDecodeError（ValueError サブクラス。不正 UTF-8 / バイナリ）は
            # OSError で捕捉されない。fail-closed を維持するため当該候補を skip し
            # 次候補へ（全候補失敗なら patterns=[] → arbitrate が全件 escalate）。
            continue
        patterns = parse_ho_paths_table(content)
        if patterns:
            return patterns, str(candidate), searched
        # ファイルは存在するがパース結果 0 件 → このソースは不採用、次候補へ
        # （CLI 明示指定時は候補が 1 つのみのため、この分岐通過後は fail-closed）
    return [], None, searched


@functools.lru_cache(maxsize=None)
def _ho_pattern_to_regex(pattern: str) -> re.Pattern[str]:
    """HO パターン文字列をセグメント境界を尊重した正規表現へ変換する。

    `*` は 1 セグメント内、`**` は 0 個以上のセグメント（"/" をまたぐ）に
    マッチする。fnmatch / pathlib.PurePath.match はいずれもこの意味論を
    正しく提供しないため、自前で構築する。

    ho-paths.md の動的読み込み化（#809）で本関数は matches_ho_pattern /
    check_allowed_paths のループから同一パターンで繰り返し呼ばれるため、
    lru_cache でコンパイル済み regex をメモ化する（gemini medium・挙動不変）。
    入力はイミュータブルな str のみ・純関数のためキャッシュ安全。
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


def matches_ho_pattern(
    path: str, ho_patterns: list[tuple[str, str]]
) -> tuple[bool, str | None, str | None]:
    """path が ho_patterns のいずれかに一致するかを判定する。

    戻り値: (一致したか, 一致パターン文字列 or None, HO 分類 or None)
    """
    for pattern, classification in ho_patterns:
        if _ho_pattern_to_regex(pattern).match(path):
            return True, pattern, classification
    return False, None, None


def boundary_check(
    changed_files: list[str], ho_patterns: list[tuple[str, str]] | None = None
) -> tuple[str, list[dict[str, str]]]:
    """boundary 判定: touches-HO | clean。

    出典: docs/ai/ai-loop/ho-paths.md 判定アルゴリズム。
    1 つでも HO パターンに一致すれば touches-HO（即確定）。

    `ho_patterns` 省略時は resolve_ho_patterns() の既定解決（CLI 指定なし）
    を用いる。fail-closed（解決不能）の判定は呼び出し側（主に arbitrate()）
    の責務であり、本関数はパターン集合が空なら単に touches-HO 0 件
    （＝見かけ上 clean）を返す点に注意 — fail-closed を保証したい呼び出し元は
    resolve_ho_patterns() の戻り値を直接チェックしてから本関数を呼ぶこと。
    """
    if ho_patterns is None:
        ho_patterns, _source, _searched = resolve_ho_patterns()
    matched: list[dict[str, str]] = []
    for path in changed_files:
        norm, err = _safe_normalized_path(path)
        if err is not None:
            # 不正パス（ルート外 traversal 等）は判定不能＝安全側で touches-HO
            # 相当として扱う（本来は validate_input が exit 1 で拒否する第一
            # 防壁があるが、判定関数単体でも fail-open にしない第二防壁）。
            matched.append({"path": path, "pattern": "", "classification": f"unsafe-path（{err}）"})
            continue
        hit, pattern, classification = matches_ho_pattern(norm, ho_patterns)
        if hit:
            matched.append({"path": path, "pattern": pattern or "", "classification": classification or ""})
    return ("touches-HO" if matched else "clean"), matched


# ---------------------------------------------------------------------------
# パス正規化・安全性検査（#809 敵対的レビュー major 反映）
# ---------------------------------------------------------------------------
# changed_files / allowed_paths を素の文字列のまま正規表現に当てると、
# `./bin/plangate`（先頭 ./ 変種）や `docs/ai/ai-loop/../../../bin/plangate`
# （traversal）が HO パターンに一致せず boundary=clean となり、touches-HO
# 絶対条件（design-philosophy I-1）を迂回して AUTO_APPROVED に到達し得る。
# 2 層防御で封鎖する:
#   第一防壁（入力段）: validate_input が不正パス（正規化後も `..` 残存・
#     絶対パス・空セグメント //）を InputError（exit 1）で拒否
#   第二防壁（判定段）: boundary_check / check_allowed_paths がマッチ直前に
#     posixpath.normpath で畳み込んでから評価。判定関数単体に不正パスが
#     渡った場合も安全側（touches-HO 相当 / scope violation）に倒す
def _safe_normalized_path(path: str) -> tuple[str, str | None]:
    """パスを正規化し、リポジトリ相対として不正なら理由文字列を返す。

    戻り値: (正規化後パス, エラー理由 or None)
    エラー条件: 空 / バックスラッシュ（\\）/ 絶対パス（先頭 /）/ 空セグメント（//）/
    `..` セグメントを含む（traversal。normpath でルート内に畳み込める場合も
    含めて一律拒否 — 正規パス表現以外を受理しない）。
    先頭 `./` は normpath が畳み込むためエラーにしない（正規化後の実体で
    マッチ評価する）。

    バックスラッシュ拒否の根拠（gemini security-high / #809）: `.split("/")`
    は `/` でしか分割しないため、`foo\\..\\bar` のようなバックスラッシュ
    区切り path は `..` チェックをすり抜ける（Windows / 一部ツールが `\\` を
    セパレータ扱いする場合の traversal 迂回）。Git のパスは常に `/` 区切りの
    ため、`\\` を含む path は一律不正として拒否する。
    """
    stripped = path.strip()
    if stripped == "":
        return stripped, "空のパス"
    if "\\" in stripped:
        return stripped, "バックスラッシュ（\\）"
    if stripped.startswith("/"):
        return stripped, "絶対パス"
    if "//" in stripped:
        return stripped, "空セグメント（//）"
    if ".." in stripped.split("/"):
        return stripped, "`..` セグメント（traversal）"
    norm = posixpath.normpath(stripped)
    # 上の検査で `..` は既に拒否済みだが、normpath 結果にも残さない（防御的既定）
    if norm == ".." or norm.startswith("../"):
        return norm, "リポジトリルート外（.. セグメント残存）"
    return norm, None


# ---------------------------------------------------------------------------
# scope 判定: allowed_paths 逸脱チェック（#809）
# ---------------------------------------------------------------------------
def check_allowed_paths(changed_files: list[str], allowed_paths: list[str]) -> tuple[bool, list[str]]:
    """changed_files の各パスが allowed_paths のいずれかの glob に一致するか検証する。

    出典: LoopSpec scope.allowed_paths（既存必須フィールド）。パターン記法は
    ho-paths.md と同一のセグメント意味論（_ho_pattern_to_regex を再利用）。

    戻り値: (全件 in-scope か, 逸脱パスのリスト)
    優先順位注意: この関数は boundary_check（touches-HO 判定）より**後**に
    呼び出すこと。allowed_paths に HO パスを宣言していても HO escalate は
    免れない（design-philosophy.md I-1 不変条件）ため、呼び出し順序を
    入れ替えてはならない。
    """
    regexes = [_ho_pattern_to_regex(pattern) for pattern in allowed_paths]
    violations: list[str] = []
    for path in changed_files:
        norm, err = _safe_normalized_path(path)
        if err is not None:
            # 不正パスは定義上 scope 外（安全側）。第一防壁（validate_input）
            # を経ない直接呼び出しでも fail-open にしない。
            violations.append(path)
            continue
        if not any(rx.match(norm) for rx in regexes):
            violations.append(path)
    return (len(violations) == 0), violations


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
POLICY_REF = "auto-approve-lite-clean@v1"


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
    for path in changed_files:
        _norm, err = _safe_normalized_path(path)
        _require(
            err is None,
            f"changed_files に不正なパスがあります（{err}。リポジトリ相対の正規パスのみ受理）: {path!r}",
        )

    allowed_paths = data.get("allowed_paths")
    _require(
        isinstance(allowed_paths, list)
        and len(allowed_paths) > 0
        and all(isinstance(p, str) and p != "" for p in allowed_paths),
        "allowed_paths は非空の string リストである必要があります（LoopSpec scope.allowed_paths 宣言を渡す）",
    )
    for path in allowed_paths:
        _norm, err = _safe_normalized_path(path)
        _require(
            err is None,
            f"allowed_paths に不正なパターンがあります（{err}。リポジトリ相対の正規パターンのみ受理）: {path!r}",
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

    run = data.get("run")
    if run is not None:
        _require(isinstance(run, dict), "run は object または省略である必要があります")
        run_id = run.get("run_id")
        _require(
            isinstance(run_id, str) and run_id.strip() != "",
            "run.run_id は非空の string である必要があります",
        )
        _require(
            "round_index" in run and type(run.get("round_index")) is int,
            "run.round_index は int である必要があります（bool 不可・必須）",
        )
        task_id = run.get("task_id")
        _require(
            isinstance(task_id, str) and task_id.strip() != "",
            "run.task_id は非空の string である必要があります",
        )
        repair_action = run.get("repair_action")
        _require(
            repair_action is None or isinstance(repair_action, str),
            "run.repair_action は string または省略である必要があります",
        )

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
    reject_category: str | None = None,
    scope_check: str = "not_evaluated",
    ho_paths_source: str | None = None,
    ho_pattern_count: int = 0,
    run: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """decision-table.md §5 準拠の provenance JSON を構築する。

    `scope_check`（#809 追加フィールド）: allowed_paths 逸脱チェックの結果。
    - "in_scope": priority 1.5 の scope 検査を**実際に通過**した（合格）
    - "scope_violation": priority 1.5 で allowed_paths 逸脱を検出した
    - "unresolved": ho-paths 未解決（fail-closed）で boundary 判定自体に
      到達しなかった
    - "not_evaluated": scope 検査より前で return した経路（touches-HO 等）で
      scope が未評価。既定値はこれ（未評価を "in_scope" と誤読させないため
      #809 敵対的レビュー minor 反映で "in_scope" → "not_evaluated" に変更）

    `ho_paths_source`（#809 追加）: 解決された ho-paths.md のパス（未解決時は
    None）。`ho_pattern_count`（#809 追加）: 解決した HO パターン抽出件数。
    「boundary=clean だが ho_pattern_count=1」のような過少網羅を監査で
    検知できるようにする（fail-closed 閾値そのものは 0 のまま — 可視化に留める）。

    `run`（#780 Slice D 後半 追加・additive・任意）: 呼び出し側入力の
    `run`（{run_id, round_index, task_id, repair_action?}）をそのまま刻む。
    **run が None（未指定）のときは `run` キー自体を刻まない**（`"run": null` は
    出力しない）。これにより metrics.py（#812）は当該 record を legacy（run メタ
    未計装・集計対象外の正常レコード）に分類でき、invalid_run_meta（run メタを
    主張するが run_id が falsy＝要注意）への誤計上を避けられる。run が与えられた
    ときのみ 4 サブフィールドを刻む。metrics.py が run 単位の集計（first-pass
    rate 等）に用いる。gate 挙動（POLICY_REF）は変えない純粋な additive
    provenance 拡張。
    """
    w_check: dict[str, Any] = {"model_a": model_a, "model_b": model_b}
    if severity is not None:
        w_check["severity"] = severity
    if model_c is not None:
        w_check["model_c"] = model_c
    if model_d is not None:
        w_check["model_d"] = model_d
    if model_b == "reject" and reject_category is not None:
        w_check["reject_category"] = reject_category

    provenance: dict[str, Any] = {
        "decision": decision,
        "issued_by": ISSUED_BY,
        "policy_ref": POLICY_REF,
        "w_check": w_check,
        "target_sha": target_sha,
        "boundary_check": boundary,
        "lite_check": lite_result,
        "class_check": class_value,
        "scope_check": scope_check,
        "ho_paths_source": ho_paths_source,
        "ho_pattern_count": ho_pattern_count,
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    # run 未指定時は `run` キー自体を省略する（`"run": null` を出さない）。
    # metrics.py の legacy（キー欠落）/ invalid_run_meta（キー有だが run_id falsy）
    # 分類において、未計装を legacy に落とすため（#780 コーディネータ指摘）。
    if run is not None:
        provenance["run"] = run
    return provenance


# ---------------------------------------------------------------------------
# 判定前処理（TASK-0814 R2）: boundary / scope / lite / verdict の集約
# ---------------------------------------------------------------------------
@dataclasses.dataclass(frozen=True)
class Signals:
    """arbitrate() の priority 分岐に先立つ判定前処理の結果（TASK-0814 R2）。

    _evaluate_signals() の戻り値。boundary_check / check_allowed_paths /
    lite_check / verdict 正規化（model_a-model_b 文字列化）を 1 箇所に
    集約し、arbitrate() は本 dataclass を見て priority 分岐のみを行う。
    """

    boundary: str
    matched: list[dict[str, str]]
    scope_ok: bool
    violations: list[str]
    lite_result: bool
    verdict: str


def _evaluate_signals(data: dict[str, Any], ho_patterns: list[tuple[str, str]]) -> Signals:
    """priority 分岐に先立つ判定前処理をまとめて評価する（TASK-0814 R2）。

    出典: docs/workflows/ai-loop/decision-table.md §3。ここで評価する
    boundary_check（priority 1）/ check_allowed_paths（priority 1.5）/
    lite_check（priority 2）/ verdict 正規化（priority 4/6 判定用の
    "{model_a}-{model_b}" 文字列）は、いずれも純関数の組み合わせであり
    副作用を持たない。

    `ho_patterns` が空（resolve_ho_patterns 未解決・fail-closed 前提）でも
    本関数は呼び出し可能。その場合 `boundary_check` は仕様上 "clean"
    （touches-HO 0 件）を返すが、priority 0（ho-paths 未解決）は
    arbitrate() 側で本関数呼び出しより前に確定判断されるため、当該経路の
    provenance には boundary/scope_ok/violations の値は反映されない。
    `lite_result` は ho_patterns の解決可否と無関係に `data["lite"]` の
    4 軸判定のみで決まるため、priority 0 経路でも同じ値が使われる
    （元コードの計算順序と同一の観測結果）。
    """
    changed_files: list[str] = data["changed_files"]
    allowed_paths: list[str] = data["allowed_paths"]
    verdicts: dict[str, Any] = data["verdicts"]

    boundary, matched = boundary_check(changed_files, ho_patterns)
    scope_ok, violations = check_allowed_paths(changed_files, allowed_paths)
    lite_result = lite_check(data["lite"])
    verdict = f"{verdicts['model_a']}-{verdicts['model_b']}"

    return Signals(
        boundary=boundary,
        matched=matched,
        scope_ok=scope_ok,
        violations=violations,
        lite_result=lite_result,
        verdict=verdict,
    )


def arbitrate(
    data: dict[str, Any], *, ho_paths_path: str | None = None
) -> tuple[dict[str, Any], str]:
    """decision-table.md §3 priority 1〜6 を順に評価し、provenance と適用理由を返す。

    priority 0（#809 追加・decision-table.md 非記載の fail-closed 前置チェック）:
    ho-paths.md が実行時解決できない、またはパース結果が 0 件の場合、boundary
    判定そのものが実行不能なため、lite / class / verdict にかかわらず全件
    HUMAN_ESCALATED とする（fail-open 禁止・絶対条件）。

    priority 1.5（#809 追加・decision-table.md 非記載の scope チェック）:
    boundary=touches-HO の判定（priority 1）より**後**、priority 2（lite）より
    **前**に、changed_files が allowed_paths の宣言範囲内かを検証する。
    範囲外のパスが 1 つでもあれば human escalate とする。

    戻り値: (provenance dict, 人間可読の理由サマリ)
    """
    class_value: str = data["class"]
    verdicts: dict[str, Any] = data["verdicts"]
    target_sha: str = data["target_sha"]

    model_a: str = verdicts["model_a"]
    model_b: str = verdicts["model_b"]
    model_c: str | None = verdicts.get("model_c")
    model_d: str | None = verdicts.get("model_d")
    reject_category: str | None = verdicts.get("reject_category")
    run: dict[str, Any] | None = data.get("run")

    ho_patterns, ho_source, ho_searched = resolve_ho_patterns(ho_paths_path)
    ho_pattern_count = len(ho_patterns)

    # 判定前処理（boundary/scope/lite/verdict）を 1 箇所に集約（TASK-0814 R2）。
    # ho_patterns が空（fail-closed）でも呼び出し可能（lite_result はその場合も
    # 同一値。詳細は _evaluate_signals の docstring）。
    signals = _evaluate_signals(data, ho_patterns)

    # 全裁定経路の provenance に ho-paths の出典・抽出件数を刻む（#809 監査可視化）。
    # boundary/scope/decision 等の可変フィールドは呼び出し側で個別に渡す。
    def _mk(**kw: Any) -> dict[str, Any]:
        return build_provenance(
            lite_result=signals.lite_result,
            class_value=class_value,
            target_sha=target_sha,
            model_a=model_a,
            model_b=model_b,
            reject_category=reject_category,
            ho_paths_source=ho_source,
            ho_pattern_count=ho_pattern_count,
            run=run,
            **kw,
        )

    # priority 0/1/1.5/2/3/4/6 のデータ駆動テーブル（TASK-0814 R1）。
    # 各行は decision-table.md §3 の対応 priority 行 1 つに対応する
    # (label, guard, decision, boundary_value, scope_check, reason_fn)。
    # guard は「scope 検査を通過した以降は in_scope を刻む」という既存の
    # 優先順位（コメント参照）をそのまま反映しており、上から順に最初に
    # True になった行が採用される（元の if/return 連鎖と同一の短絡評価）。
    # priority 5（approve-reject の severity 分類 + C/D 裁定）は 2 段判定で
    # 分岐が複雑なため、無理にテーブルへ押し込まず本テーブルの後で個別処理
    # として残す（TASK-0814 plan の over-engineering 回避方針）。
    priority_table: list[tuple[str, bool, str, str, str, Any]] = [
        (
            "priority 0",
            not ho_patterns,
            DECISION_HUMAN_ESCALATED,
            "unresolved",
            "unresolved",
            lambda: f"priority 0: ho-paths unresolved (fail-closed)。探索パス: {', '.join(ho_searched)}",
        ),
        (
            # scope 検査（priority 1.5）より前で return するため scope_check は
            # not_evaluated。lite / class / verdict を問わず必ず human escalate 固定。
            "priority 1",
            signals.boundary == "touches-HO",
            DECISION_HUMAN_ESCALATED,
            signals.boundary,
            "not_evaluated",
            lambda: (
                "priority 1: boundary=touches-HO（絶対条件・固定）。一致パス: "
                + ", ".join(f"{m['path']} ({m['pattern']} / {m['classification']})" for m in signals.matched)
            ),
        ),
        (
            "priority 1.5",
            not signals.scope_ok,
            DECISION_HUMAN_ESCALATED,
            signals.boundary,
            "scope_violation",
            lambda: (
                "priority 1.5: boundary=clean だが scope_violation（allowed_paths 逸脱パス: "
                + ", ".join(signals.violations)
                + "）"
            ),
        ),
        (
            # ここに到達＝scope 検査を実際に通過（合格）。以降の全行は in_scope を刻む。
            "priority 2",
            not signals.lite_result,
            DECISION_HUMAN_ESCALATED,
            signals.boundary,
            "in_scope",
            lambda: "priority 2: boundary=clean だが lite=false（低リスク要件未充足）",
        ),
        (
            "priority 3",
            class_value == "merge",
            DECISION_HUMAN_ESCALATED,
            signals.boundary,
            "in_scope",
            lambda: "priority 3: class=merge（Human-owned 固定）",
        ),
        (
            "priority 4",
            signals.verdict in ("reject-reject", "reject-approve"),
            DECISION_BLOCKED,
            signals.boundary,
            "in_scope",
            lambda: f"priority 4: verdict={signals.verdict}（A が設計妥当性で NG、または両者合意で NG）",
        ),
        (
            "priority 6",
            signals.verdict == "approve-approve",
            DECISION_AUTO_APPROVED,
            signals.boundary,
            "in_scope",
            lambda: "priority 6: verdict=approve-approve（合意）",
        ),
    ]

    for _label, guard, decision, boundary_value, scope_check, reason_fn in priority_table:
        if guard:
            provenance = _mk(decision=decision, boundary=boundary_value, scope_check=scope_check)
            return provenance, reason_fn()

    # priority 5: approve-reject → severity 分類 → C/D 裁定。
    # (verdict は入力バリデーションで approve/reject の 2 値に限定済みのため、
    #  ここに到達する場合は必ず approve-reject。テーブル化しない理由は
    #  TASK-0814 plan 参照 — severity 分類 + C/D 裁定の 2 段判定で分岐が
    #  複雑なため個別処理のまま維持する）
    severity = classify_severity(reject_category)

    if severity in ("critical", "major"):
        provenance = _mk(
            decision=DECISION_HUMAN_ESCALATED,
            boundary=signals.boundary,
            scope_check="in_scope",
            severity=severity,
        )
        return (
            provenance,
            f"priority 5: verdict=approve-reject, severity={severity}（reject_category={reject_category!r}）→ human escalate 固定",
        )

    # severity=minor/low → Model C/D 裁定。
    # C か D が欠落している場合は安全側で human escalate。
    if model_c is None or model_d is None:
        provenance = _mk(
            decision=DECISION_HUMAN_ESCALATED,
            boundary=signals.boundary,
            scope_check="in_scope",
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

    provenance = _mk(
        decision=decision,
        boundary=signals.boundary,
        scope_check="in_scope",
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
    parser.add_argument(
        "--ho-paths",
        dest="ho_paths_path",
        default=None,
        help="HO パス一覧（ho-paths.md）の明示パス（省略時は実行時解決 / #809）",
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

    provenance, reason = arbitrate(validated, ho_paths_path=args.ho_paths_path)
    decision = provenance["decision"]

    print(json.dumps(provenance, ensure_ascii=False, indent=2, sort_keys=True))
    print(f"[arbiter] decision={decision} / {reason}", file=sys.stderr)

    return EXIT_CODES[decision]


if __name__ == "__main__":
    sys.exit(main())
