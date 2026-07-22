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


# ---------------------------------------------------------------------------
# I/O あり関数（arbiter は import / call しない — AC-6）
# ---------------------------------------------------------------------------

def sha256_of_file(path) -> str:
    """ファイル内容の sha256 を `sha256:<64hex>` 形式で返す（契約 §2）。"""
    return "sha256:" + hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()
