#!/usr/bin/env python3
"""c3-prime 受理検証（bin/plangate validate / exec preflight 共有・#872 PR-2）。

契約正本: docs/workflows/ai-loop/c3-prime-contract.md §4。
approvals/c3.json の approval_kind を strict JSON で判別し、c3-prime なら
Plan Package への束縛を全数**再検証**する（trust boundary: decision 値を
無検証で信頼しない・#887 F-4/R-018）。legacy（approval_kind なし）は本
スクリプトの対象外（呼び出し側 shell の grep 経路が担う）。

使い方: c3prime_verify.py <task_dir>
  exit 0  = c3-prime として受理（AUTO_APPROVED・全束縛整合）
  exit 10 = legacy（approval_kind 無し）→ 呼び出し側が legacy 経路で処理
  exit 1  = c3-prime だが検証 NG（fail-closed。理由を stderr に出力）
"""
from __future__ import annotations

import hashlib
import json
import pathlib
import re
import sys

ARTIFACTS = (
    "pbi-input.md", "plan.md", "todo.md", "test-cases.md",
    "review-self.md", "review-external.md",
)
VALID_DECISIONS = ("AUTO_APPROVED", "HUMAN_ESCALATED", "BLOCKED")
VALID_VERDICTS = ("approve", "reject")
SNAPSHOT_KEYS = ("verdict", "plan_hash", "source_sha", "plan_package_hash", "evidence_ref")


def _sha256(path: pathlib.Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _fail(msg: str) -> int:
    print(f"c3-prime: {msg}", file=sys.stderr)
    return 1


def main(argv):
    if len(argv) != 2:
        print("usage: c3prime_verify.py <task_dir>", file=sys.stderr)
        return 1
    task_dir = pathlib.Path(argv[1])
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
        # legacy（キー無し）または未知値。未知値は明示 fail、無しは legacy 委譲。
        if "approval_kind" in data:
            return _fail(f"approval_kind が未知値: {data.get('approval_kind')!r}")
        return 10  # legacy → 呼び出し側 shell へ委譲

    # ここから c3-prime。契約 §4 の全規則を再検証する。
    # decision 3値 allowlist
    decision = data.get("decision")
    if decision not in VALID_DECISIONS:
        return _fail(f"decision が契約の 3 値以外: {decision!r}")
    if decision != "AUTO_APPROVED":
        return _fail(f"decision={decision}（exec 不可。AUTO_APPROVED のみ受理）")

    # source_sha 形式
    source_sha = data.get("source_sha", "")
    if not re.fullmatch(r"[0-9a-f]{7,40}", source_sha or ""):
        return _fail(f"source_sha が commit SHA 形式でない: {source_sha!r}")

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
    canon = json.dumps(ah, sort_keys=True, separators=(",", ":")).encode("utf-8")
    if data.get("plan_package_hash") != "sha256:" + hashlib.sha256(canon).hexdigest():
        return _fail("plan_package_hash が artifact_hashes から再計算した値と不一致")

    # reviewer snapshot 三つ組一致 + decision-verdict 整合
    reviewers = data.get("reviewers")
    if not isinstance(reviewers, dict) or set(reviewers) < {"model_a", "model_b"}:
        return _fail("reviewers に model_a / model_b が揃っていない")
    for m in ("model_a", "model_b"):
        snap = reviewers.get(m)
        if not isinstance(snap, dict) or any(not snap.get(k) for k in SNAPSHOT_KEYS):
            return _fail(f"reviewers.{m} の snapshot が不完全")
        if snap.get("verdict") not in VALID_VERDICTS:
            return _fail(f"reviewers.{m}.verdict が approve/reject 以外")
        for key in ("plan_hash", "source_sha", "plan_package_hash"):
            if snap.get(key) != data.get(key):
                return _fail(f"reviewers.{m}.{key} がトップレベル値と不一致（AC-5 違反）")
    # AUTO_APPROVED は両 reviewer approve のときのみ（改竄兆候の検出）
    if any(reviewers[m].get("verdict") != "approve" for m in ("model_a", "model_b")):
        return _fail("decision=AUTO_APPROVED だが reviewer verdict に reject を含む（改竄兆候）")

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
