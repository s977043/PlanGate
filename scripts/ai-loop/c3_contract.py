"""c3-prime 契約の共通契約層（TASK-0896 / #896）。

契約正本: docs/workflows/ai-loop/c3-prime-contract.md（本モジュールは実装集約のみ・
規則は不変）。arbiter.py（入力ブロック検証）/ plan_package.py（producer）/
c3prime_verify.py（record 受理器）の 3 消費者が import 参照する単一定義。

層区分（AC-6）:
- 契約定数: I/O なし。全消費者が参照可
- I/O なし純関数: canonical_hash / check_snapshot_trio。arbiter が import してよいのは
  この層まで（arbiter は「入力 dict のみで決定論裁定」の設計を維持し、共通層から
  新たなファイル読取依存を持ち込まない）
- I/O あり関数: sha256_of_file。producer / 受理器のみが使用し、arbiter は
  import / call しない（test_c3_contract.py が回帰検査）
"""
from __future__ import annotations

import hashlib
import json
import pathlib

# ---------------------------------------------------------------------------
# 契約定数（契約 §1/§2）
# ---------------------------------------------------------------------------

# 契約 §1: Plan Package 6 要素（key 順は artifact_hashes の表示順にも使う）
ARTIFACTS = (
    "pbi-input.md",
    "plan.md",
    "todo.md",
    "test-cases.md",
    "review-self.md",
    "review-external.md",
)

# 契約 §2: decision の 3 値 allowlist（#887 レビュー / 両 Codex major 指摘反映）。
VALID_DECISIONS = ("AUTO_APPROVED", "HUMAN_ESCALATED", "BLOCKED")
VALID_VERDICTS = ("approve", "reject")

# 契約 §3: reviewer snapshot の 5 キー（三つ組照合の対象は plan_hash /
# source_sha / plan_package_hash）。
SNAPSHOT_KEYS = ("verdict", "plan_hash", "source_sha", "plan_package_hash", "evidence_ref")

# 契約 §2: c3-prime record トップレベルの必須キー（受理器 allowlist の中核）。
RECORD_REQUIRED_KEYS = (
    "task_id", "approval_kind", "phase", "decision", "source_sha", "plan_hash",
    "plan_package_hash", "artifact_hashes", "c1_evidence_ref", "c2_evidence_ref",
    "reviewers", "policy_ref", "issued_at", "issued_by",
)
# 任意で許容する追加キー（それ以外の未知キーは reject。`c3_status` は §5 で明示禁止）。
RECORD_OPTIONAL_KEYS = ("derived_loopspec_hash",)
RECORD_ALLOWED_KEYS = set(RECORD_REQUIRED_KEYS) | set(RECORD_OPTIONAL_KEYS)

# 契約 §2/§3: arbiter 入力 `plan_package` ブロックの必須キー。
PLAN_PACKAGE_REQUIRED_KEYS = (
    "plan_hash",
    "source_sha",
    "plan_package_hash",
    "c1_evidence_ref",
    "c2_evidence_ref",
    "reviewers",
)

# 三つ組照合の対象キー（snapshot 値 = container トップレベル値の一致要求）。
TRIO_KEYS = ("plan_hash", "source_sha", "plan_package_hash")


# ---------------------------------------------------------------------------
# I/O なし純関数
# ---------------------------------------------------------------------------

def canonical_hash(obj) -> str:
    """正規化 JSON（sort_keys・区切り最小）の sha256 を返す（契約 §2）。"""
    canon = json.dumps(obj, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return "sha256:" + hashlib.sha256(canon).hexdigest()


def check_snapshot_trio(container, reviewers, strict_keys) -> list[str]:
    """reviewer snapshot の 5 キー整合 + 三つ組一致を検査し理由リストを返す。

    空リスト = OK。判定・終端制御（arbiter の tuple 部分成功 / c3prime_verify の
    即時 reject）は呼び出し側の責務。理由リストの生成順序は検査順で契約固定:
    reviewer 順（model_a → model_b）× reviewer 内は
    (1) snapshot 型 / キー集合 → (2) 空値 → (3) 三つ組不一致（TASK-0896 R-004）。

    strict_keys の非対称は #889 R2 由来の意図的設計を保存する（TASK-0896 R-005）:
    - strict_keys=True（c3prime_verify）: snapshot はちょうど 5 キー（余剰 reject）
    - strict_keys=False（arbiter）: 欠落・空値のみ検査（余剰キー許容）

    本関数が検査しないもの（呼び出し側残置）: verdict 語彙 / evidence_ref 独立性 /
    AUTO_APPROVED 整合 / reviewers ちょうど 2 者（strict 側）/ 余剰 reviewer 許容
    （lenient 側）/ PLAN_PACKAGE_REQUIRED_KEYS 構造検査 / source_sha vs target_sha。
    """
    reasons: list[str] = []
    for model in ("model_a", "model_b"):
        snap = reviewers.get(model) if isinstance(reviewers, dict) else None
        if not isinstance(snap, dict):
            reasons.append(f"reviewers.{model} の snapshot が欠落（契約 §3: fail-closed）")
            continue
        if strict_keys and set(snap) != set(SNAPSHOT_KEYS):
            reasons.append(f"reviewers.{model} の snapshot キーが規定 5 キーと不一致")
            continue
        missing = [k for k in SNAPSHOT_KEYS if not snap.get(k)]
        if missing:
            reasons.append(
                f"reviewers.{model} の snapshot キー欠落または空値: {', '.join(missing)}")
            continue
        for key in TRIO_KEYS:
            if snap.get(key) != (container.get(key) if isinstance(container, dict) else None):
                reasons.append(
                    f"reviewers.{model}.{key} がトップレベル値と不一致"
                    "（同一 Plan Package を観ていない = AC-5 違反）")
    return reasons


# ---------------------------------------------------------------------------
# I/O あり関数（arbiter は import / call しない — AC-6）
# ---------------------------------------------------------------------------

def sha256_of_file(path) -> str:
    """ファイル内容の sha256 を `sha256:<64hex>` 形式で返す（契約 §2）。"""
    return "sha256:" + hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()
