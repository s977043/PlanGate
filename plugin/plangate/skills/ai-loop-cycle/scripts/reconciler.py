#!/usr/bin/env python3
"""reconciler.py — intent ↔ receipt を突合し **冪等** を担保する層
（TASK-0917 / #917 / AC-3・論点 D3）。

契約正本: docs/working/TASK-0917/plan.md 論点 D3（`findings[]` の
`disposition` 書き戻し / `conflict_resolution` の三点再構成）/
Work Breakdown Step 7。

## 責務

1. **冪等（AC-3）**: `record.jsonl` の `intent` / `receipt` を `action_id` で
   突合し、「receipt 済みの action を Executor へ二度渡さない」ことを保証する
   （`filter_unexecuted()`）。`action_id` は `c3_contract.canonical_hash()` を
   **import 再利用**し、独自実装しない（`delivery.action_id()` も同関数の
   ラッパであり、両者が同じ値を返すことがこの層の前提）。
2. **`disposition` の再構成（D3 `findings[]` 案 (b) ②）**: `delivery.py receipt
   --result-ref <str>` の**汎用文字列**に載せた convention
   （`adopted:<repair_commit_sha>` / `rejected:<evidence_ref_path>`）から
   `findings[].disposition` を組み立てる。**`delivery.py` 本体は不変**のまま
   `_resolved()` を満たせるようにするための橋渡し。
3. **`conflict_resolution` の再構成（R-026）**: `resolve_conflict` receipt から
   `base_sha` / `head_sha` / `result_sha` の**三点が揃うときのみ**出力する。
   常時出力すると `cr_incomplete` → `conflict_need = True` となり、どの PR も
   永久に `CONFLICT`（`MERGE_READY` 到達不能）になる。

## fail-closed

- `record.jsonl` の破損 / `entry_id` 改竄は `delivery.RecordError` を**握り潰さず**
  送出する（`safe_reconcile()` は明示的に `(None, error)` を返す形でのみ抑制）。
  破損ファイルを**書き直さない**（append-only 契約）。
- `intent` の無い `receipt`（記録なき実行の兆候）は `orphan_receipts` として
  明示する（黙って無視しない）。
- convention を満たさない `result_ref` からは disposition を**捏造しない**。

## 外部作用ゼロ

本モジュールはネットワーク・プロセス起動を一切行わない（`record.jsonl` の
読み取りのみ / `check_exec_boundary.py` の検査対象）。外部書き込みは
`executor.py` の 1 層に閉じる（AC-5）。
"""

from __future__ import annotations

import dataclasses
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import c3_contract  # noqa: E402  action_id の単一定義（再実装しない / TC-08）
import delivery  # noqa: E402  record I/O / disposition 契約の実物（AC-7: 変更しない）
import executor  # noqa: E402  result_ref convention の producer（規約の単一定義）

#: `disposition` を書き戻しうる action_kind（finding に 1:1 で紐づくもの）。
DISPOSITION_KINDS = ("repair_review", "record_disposition")

#: `disposition.kind` → `_resolved()` が要求する必須フィールド名。
DISPOSITION_FIELD = {"adopted": "repair_commit", "rejected": "evidence_ref"}

#: `conflict_resolution` の三点（`delivery.py` の `cr_incomplete` と同じ集合）。
CONFLICT_KEYS = ("base_sha", "head_sha", "result_sha")


@dataclasses.dataclass(frozen=True)
class Reconciliation:
    """1 回の突合結果（決定論・純データ）。"""

    entries: tuple
    intents: dict
    receipts: dict
    pending: tuple
    orphan_receipts: tuple
    dispositions: dict
    conflict_resolution: object = None


# ---------------------------------------------------------------------------
# action_id（canonical_hash の import 再利用）
# ---------------------------------------------------------------------------

def action_id(payload) -> str:
    """`delivery.action_id()` と**同一規則**の stable ID を返す。

    `c3_contract.canonical_hash()` を直接呼ぶ（独自実装ゼロ / TC-08）。
    """
    return c3_contract.canonical_hash(payload)


# ---------------------------------------------------------------------------
# 突合
# ---------------------------------------------------------------------------

def load_entries(task_dir):
    """`record.jsonl` を読む（破損は `delivery.RecordError` を送出 = 握り潰さない）。"""
    return delivery.load_entries(delivery.record_path(task_dir))


def _by_action_id(entries, kind) -> dict:
    found = {}
    for entry in entries or ():
        if not isinstance(entry, dict) or entry.get("kind") != kind:
            continue
        if entry.get("action_id"):
            found[entry["action_id"]] = entry
    return found


def is_applied(action_id_value, entries) -> bool:
    """当該 `action_id` の receipt が存在するか（= 外部作用は完了済み）。"""
    return action_id_value in executor.receipt_ids(entries)


def filter_unexecuted(actions, entries) -> list:
    """receipt 済みの action を落とす（AC-3: Executor へ二度渡さない）。

    `delivery.assess()` 側でも同じ除外が行われるが、**Executor の直前でも**
    独立に効かせる（手渡しの action 列や resume 経路で二重作用させないため）。
    """
    receipts = executor.receipt_ids(entries)
    return [a for a in actions or ()
            if isinstance(a, dict) and a.get("action_id") not in receipts]


# ---------------------------------------------------------------------------
# disposition / conflict_resolution の再構成
# ---------------------------------------------------------------------------

def _finding_id_of(receipt, intents):
    intent = intents.get(receipt.get("action_id"))
    payload = (intent or {}).get("payload") or {}
    finding_id = payload.get("finding_id")
    return finding_id if isinstance(finding_id, str) and finding_id else None


def reconstruct_disposition(result_ref):
    """`result_ref` convention から `disposition` を組み立てる（不成立は `None`）。"""
    parts = executor.parse_result_ref(result_ref)
    for kind, field in DISPOSITION_FIELD.items():
        value = parts.get(kind)
        if value:
            return {"kind": kind, field: value}
    return None


def reconstruct_dispositions(entries, pr_number) -> dict:
    """`finding_id` → `disposition` の対応表を再構成する（当該 PR のみ / A-06）。

    同一 `finding_id` に複数 receipt がある場合は **file 順で最後**（最新の追記）
    を採用する（`ci_taxonomy.manual_taxonomy()` と同じ規則）。
    """
    intents = _by_action_id(entries, "intent")
    dispositions: dict = {}
    for entry in entries or ():
        if not isinstance(entry, dict) or entry.get("kind") != "receipt":
            continue
        if entry.get("action_kind") not in DISPOSITION_KINDS:
            continue
        if entry.get("pr_number") != pr_number:
            continue
        finding_id = _finding_id_of(entry, intents)
        if finding_id is None:
            continue
        disposition = reconstruct_disposition(entry.get("result_ref"))
        if disposition is not None:
            dispositions[finding_id] = disposition
    return dispositions


def apply_dispositions(findings, dispositions) -> list:
    """`findings[]` に再構成済み `disposition` を載せた**新しいリスト**を返す。

    入力を破壊しない。対応する `finding_id` が無い finding は素通し
    （捏造しない = `_resolved()` は False のままで fail-closed）。
    """
    applied = []
    for finding in findings or ():
        if not isinstance(finding, dict):
            continue
        merged = dict(finding)
        disposition = (dispositions or {}).get(merged.get("id"))
        if disposition is not None:
            merged["disposition"] = dict(disposition)
        applied.append(merged)
    return applied


def reconstruct_conflict_resolution(entries, pr_number):
    """`resolve_conflict` receipt から三点を再構成する（揃わなければ `None`）。

    三点未満で dict を返すと `delivery.py` の `cr_incomplete` が立ち、どの PR も
    永久に `CONFLICT` になる（R-026）。したがって**揃うときのみ**返す。
    """
    latest = None
    for entry in entries or ():
        if not isinstance(entry, dict) or entry.get("kind") != "receipt":
            continue
        if entry.get("action_kind") != "resolve_conflict":
            continue
        if entry.get("pr_number") != pr_number:
            continue
        latest = entry
    if latest is None:
        return None
    parts = executor.parse_result_ref(latest.get("result_ref"))
    resolution = {
        "base_sha": parts.get(executor.PART_BASE),
        "head_sha": parts.get(executor.PART_HEAD),
        "result_sha": parts.get(executor.PART_ADOPTED),
    }
    if all(resolution.get(key) for key in CONFLICT_KEYS):
        return resolution
    return None


# ---------------------------------------------------------------------------
# 入口
# ---------------------------------------------------------------------------

def index_entries(entries, pr_number) -> Reconciliation:
    """entries を突合して `Reconciliation` を組み立てる **純関数**。"""
    entries = list(entries or ())
    intents = _by_action_id(entries, "intent")
    receipts = _by_action_id(entries, "receipt")
    pending = tuple(aid for aid in intents if aid not in receipts)
    orphans = tuple(aid for aid in receipts if aid not in intents)
    return Reconciliation(
        entries=tuple(entries), intents=intents, receipts=receipts,
        pending=pending, orphan_receipts=orphans,
        dispositions=reconstruct_dispositions(entries, pr_number),
        conflict_resolution=reconstruct_conflict_resolution(entries, pr_number))


def reconcile(task_dir, *, pr_number, entries=None) -> Reconciliation:
    """`record.jsonl` を読んで突合する。破損は `delivery.RecordError` を送出する。"""
    if entries is None:
        entries = load_entries(task_dir)
    return index_entries(entries, pr_number)


def safe_reconcile(task_dir, *, pr_number):
    """`reconcile()` の非例外版。破損時は `(None, 理由)` を返す（黙って空にしない）。"""
    try:
        return reconcile(task_dir, pr_number=pr_number), None
    except delivery.RecordError as exc:
        return None, str(exc)
