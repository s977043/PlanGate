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

__doc__ = """c3-prime 受理検証（bin/plangate validate / exec preflight 共有・#872 PR-2）。

契約正本: docs/workflows/ai-loop/c3-prime-contract.md §4。
approvals/c3.json の approval_kind を strict JSON で判別し、c3-prime なら
Plan Package への束縛を全数**再検証**する（trust boundary: decision 値を
無検証で信頼しない・#887 F-4/R-018）。legacy（approval_kind なし）は本
スクリプトの対象外（呼び出し側 shell の grep 経路が担う）。

使い方: c3prime_verify.py <task_dir> [expected_sha]
  expected_sha を渡すと source_sha との厳密一致を強制する（契約 §4・exec 時に
  bin/plangate が `git rev-parse HEAD` を渡す）。省略時は構造・束縛のみ検証。
  exit 0  = c3-prime として受理（AUTO_APPROVED・全束縛整合）
  exit 10 = legacy（approval_kind キー無し）→ 呼び出し側が legacy 経路で処理
  exit 1  = c3-prime だが検証 NG（fail-closed。理由を stderr に出力）
"""

import json
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import c3_contract  # noqa: E402  契約定数の単一定義（TASK-0896 / #896）
import plan_package  # noqa: E402  受理側でも evidence marker を再検証するため共有

# 契約定数は c3_contract が単一定義（値の契約固定は test_c3_contract.py）。
ARTIFACTS = c3_contract.ARTIFACTS
VALID_DECISIONS = c3_contract.VALID_DECISIONS
VALID_VERDICTS = c3_contract.VALID_VERDICTS
SNAPSHOT_KEYS = c3_contract.SNAPSHOT_KEYS
REQUIRED_KEYS = c3_contract.RECORD_REQUIRED_KEYS
OPTIONAL_KEYS = c3_contract.RECORD_OPTIONAL_KEYS
ALLOWED_KEYS = c3_contract.RECORD_ALLOWED_KEYS


_sha256 = c3_contract.sha256_of_file  # 単一実装（TASK-0896 AC-2）


def _fail(msg: str) -> int:
    print(f"c3-prime: {msg}", file=sys.stderr)
    return 1


def main(argv):
    if len(argv) not in (2, 3):
        print("usage: c3prime_verify.py <task_dir> [expected_sha]", file=sys.stderr)
        return 1
    task_dir = pathlib.Path(argv[1])
    expected_sha = argv[2] if len(argv) == 3 else None
    c3 = task_dir / "approvals" / "c3.json"
    if not c3.is_file():
        return _fail("approvals/c3.json not found")
    try:
        data = json.loads(c3.read_text(encoding="utf-8"))
    except (ValueError, OSError) as exc:
        return _fail(f"c3.json を strict JSON として読めない: {exc}")
    if not isinstance(data, dict):
        return _fail("c3.json が JSON object でない")

    if data.get("approval_kind") != "c3-prime":
        # legacy（キー無し）または未知値。未知値・型違いは明示 fail、
        # キーが物理的に存在しない場合のみ legacy 委譲（fail-closed / #889 high）。
        if "approval_kind" in data:
            return _fail(f"approval_kind が未知値/型違い: {data.get('approval_kind')!r}")
        return 10  # legacy → 呼び出し側 shell へ委譲

    # ここから c3-prime。契約 §2/§4/§5 の全規則を再検証する。
    # 構造 allowlist + 必須キー（#889 critical）。c3_status は §5 で明示禁止。
    if "c3_status" in data:
        return _fail("c3-prime に c3_status が含まれる（契約 §5 で禁止）")
    unknown = [k for k in data if k not in ALLOWED_KEYS and not k.startswith("_")]
    if unknown:
        return _fail(f"未知のトップレベルキー: {unknown}")
    missing = [k for k in REQUIRED_KEYS if k not in data]
    if missing:
        return _fail(f"必須キー欠落: {missing}")
    task_id = str(data.get("task_id", ""))
    if not re.fullmatch(r"TASK-[0-9]{4}", task_id):
        return _fail(f"task_id が TASK-XXXX 形式でない: {data.get('task_id')!r}")
    # task_id を task_dir に束縛（#889 R2 high: 別 task の record 流用を防ぐ）。
    if task_dir.name != task_id:
        return _fail(f"task_id ({task_id}) が task_dir 名 ({task_dir.name}) と不一致")
    if data.get("phase") != "C-3'":
        return _fail(f"phase が C-3' でない: {data.get('phase')!r}")
    for k in ("c1_evidence_ref", "c2_evidence_ref", "policy_ref", "issued_by"):
        if not isinstance(data.get(k), str) or not data.get(k):
            return _fail(f"{k} が非空 string でない")
    # issued_at は ISO 8601 UTC（#889 R2 medium: schema 同等の型検証）。
    if not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z",
                        str(data.get("issued_at", ""))):
        return _fail(f"issued_at が ISO 8601 UTC でない: {data.get('issued_at')!r}")
    # `_` 注釈キーは string のみ（schema patternProperties 相当）。
    for k, v in data.items():
        if k.startswith("_") and not isinstance(v, str):
            return _fail(f"注釈キー {k} が string でない")
    # C-1/C-2 evidence の内容を**受理側で再検証**（#889 R2 critical: build 時のみ
    # の検証を信頼せず、marker verdict / stale を再チェック。改竄 evidence を弾く）。
    ev_errors = plan_package.check_evidence(task_dir)
    if ev_errors:
        return _fail("evidence 再検証 NG: " + "; ".join(ev_errors))

    # decision 3値 allowlist
    decision = data.get("decision")
    if decision not in VALID_DECISIONS:
        return _fail(f"decision が契約の 3 値以外: {decision!r}")
    if decision != "AUTO_APPROVED":
        return _fail(f"decision={decision}（exec 不可。AUTO_APPROVED のみ受理）")

    # source_sha 形式 + 検証時点の対象 SHA との一致（契約 §4 / #889 critical）。
    source_sha = data.get("source_sha", "")
    if not isinstance(source_sha, str) or not re.fullmatch(r"[0-9a-f]{7,40}", source_sha):
        return _fail(f"source_sha が commit SHA 形式でない: {source_sha!r}")
    if expected_sha is not None:
        # HEAD は full SHA、record は短縮のこともあるため prefix 一致で照合。
        exp = expected_sha.strip()
        if not (exp == source_sha or exp.startswith(source_sha) or source_sha.startswith(exp)):
            return _fail(
                f"source_sha ({source_sha}) が検証時点の対象 SHA ({exp}) と不一致"
                "（BLOCK・再 C-1/C-2/C-3' が必要）")

    # plan_hash = plan.md 単体（legacy と同一契約）
    plan_md = task_dir / "plan.md"
    if not plan_md.is_file():
        return _fail("plan.md が存在しない")
    if data.get("plan_hash") != _sha256(plan_md):
        return _fail("plan_hash が現 plan.md と不一致（stale。再 C-1/C-2/C-3' が必要）")

    # artifact_hashes 全数照合（どのエントリの不一致かを明示）
    ah = data.get("artifact_hashes")
    if not isinstance(ah, dict) or set(ah) != set(ARTIFACTS):
        return _fail("artifact_hashes のキーが Plan Package 6 要素と一致しない")
    for name in ARTIFACTS:
        f = task_dir / name
        if not f.is_file():
            return _fail(f"artifact 欠落: {name}")
        if ah[name] != _sha256(f):
            return _fail(f"artifact_hashes 不一致: {name}（stale）")

    # plan_package_hash = artifact_hashes の正規化 JSON の sha256
    if data.get("plan_package_hash") != c3_contract.canonical_hash(ah):
        return _fail("plan_package_hash が artifact_hashes から再計算した値と不一致")

    # reviewer snapshot 三つ組一致 + decision-verdict 整合
    reviewers = data.get("reviewers")
    # model_a / model_b ちょうど 2 者（余剰 reviewer キーは reject / #889 R2 medium）。
    if not isinstance(reviewers, dict) or set(reviewers) != {"model_a", "model_b"}:
        return _fail(f"reviewers は model_a / model_b のちょうど 2 者: {sorted(reviewers) if isinstance(reviewers, dict) else reviewers!r}")
    # snapshot 5 キー整合（strict_keys=True = ちょうど 5 キー・未知ネストキーは
    # reject / #889 R2 medium）+ 三つ組一致は共通純関数。理由リスト非空 → reject。
    trio_reasons = c3_contract.check_snapshot_trio(data, reviewers, strict_keys=True)
    if trio_reasons:
        return _fail(trio_reasons[0])
    for m in ("model_a", "model_b"):
        if reviewers[m].get("verdict") not in VALID_VERDICTS:
            return _fail(f"reviewers.{m}.verdict が approve/reject 以外")
    # reviewer 独立性: 両者の evidence_ref が同一なら独立 2 者レビュー偽装
    # （#889 R2 high。snapshot hash は同一が正だが evidence は別根拠であるべき）。
    if reviewers["model_a"]["evidence_ref"] == reviewers["model_b"]["evidence_ref"]:
        return _fail("reviewers.model_a と model_b の evidence_ref が同一（独立性違反）")
    # AUTO_APPROVED は両 reviewer approve のときのみ（改竄兆候の検出）
    if any(reviewers[m].get("verdict") != "approve" for m in ("model_a", "model_b")):
        return _fail("decision=AUTO_APPROVED だが reviewer verdict に reject を含む（改竄兆候）")

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
