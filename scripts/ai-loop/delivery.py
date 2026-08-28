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

__doc__ = """MERGE_READY 状態機械（TASK-0873 / #873）— 決定論・fail-closed・冪等の判定エンジン。

正本: docs/workflows/ai-loop/delivery-state-machine.md（サブステート・正規化
マッピング・record 契約）。c3-prime 入口再検証の契約は
docs/workflows/ai-loop/c3-prime-contract.md §7（trust boundary）。

設計原則（arbiter.py / plan_package.py / c3prime_verify.py と同型）:
- 決定論: 判定は snapshot + record entries のみに依存。timestamp は --now 注入
  （now() を直接参照しない）
- fail-closed: 独立検証不能な入力（未知 taxonomy / ancestry 不明 / 三点照合欠落）
  は成功扱いにしない
- 冪等: entry_id（timestamp 除外の正規化 hash）で append を重複抑止。
  アクションは stable action ID（canonical payload の sha256）+
  intent / receipt の 2 段記録で「一度だけ実行」に収束させる
- 純判定器: ネットワーク・外部プロセスを一切呼ばない（NO MERGE BY AI。
  `MERGED` への遷移は存在しない — ta-56 がソース走査でも固定）
"""

import json
import pathlib
import re
import sys
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import c3_contract  # noqa: E402  契約定数 + canonical_hash の単一定義（#896）
import c3prime_verify  # noqa: E402  c3-prime 受理器の再利用（再実装しない / §7）

# ---------------------------------------------------------------------------
# 状態機械契約（単一定義。emit = `delivery.py contract`）
# ---------------------------------------------------------------------------

TERMINAL = "MERGE_READY"
STATES = (
    "CHECKS_FAILED",
    "CONFLICT",
    "MERGE_READY",
    "MERGE_READY_CANDIDATE",
    "REVIEW_REPAIR",
    "WAITING_FOR_CHECKS",
    "WAITING_FOR_REVIEW",
)
EXITS = ("EXEC_RETURN", "HUMAN_ESCALATED")
# 優先度順（delivery-state-machine.md §3 と同順・上が勝つ）
PRIORITY_ORDER = (
    "invalid_snapshot",
    "plan_deviation",
    "escalation_flags",
    "ancestry_fail",
    "unknown_check_conclusion",
    "taxonomy_unverifiable",
    "round_limit",
    "same_type_recurrence",
    "ci_failed",
    "conflict",
    "review_findings",
    "waiting_checks",
    "waiting_review",
    "merge_ready_candidate",
    "merge_ready",
)

# assess は stateless（各回 snapshot 駆動で前状態に依存しない / A-07 是正）。
# したがって非終端状態からは次回 assess で任意の状態・exit へ到達し得る。
# 唯一の不変量は「MERGE_READY は終端（遷移なし）」= NO MERGE BY AI + C-4 待ち。
# TRANSITIONS はこの実到達グラフを正直に表現する（正本 doc §3 の優先度表が
# 「どの入力でどの状態に入るか」の意味論・本表は「到達可能性」を担う）。
_NON_TERMINAL = tuple(s for s in STATES if s != TERMINAL) + EXITS
_REACHABLE = sorted(STATES + EXITS)  # MERGE_READY 含む・全状態へ到達可
TRANSITIONS = {s: list(_REACHABLE) for s in _NON_TERMINAL if s in STATES}
TRANSITIONS["MERGE_READY"] = []

REPAIR_KINDS = ("repair_ci", "repair_review", "resolve_conflict")
ROUND_LIMIT = 3
VALID_TAXONOMY_REPAIR = ("code", "flaky", "environment")

# check conclusion の allowlist（RV-1 / River Review）。GitHub Checks API の
# conclusion を 3 群に分類し、**未知値は HUMAN_ESCALATED（fail-closed）**。
# cancelled / timed_out / action_required / startup_failure は terminal 失敗
# （pending 扱いにすると恒久 WAITING の livelock になる）。neutral / skipped は
# terminal 非失敗（例: 条件 skip の sync job）で green を block しない —
# required check の完全性担保は snapshot 供給者責務（doc §4 / RV-2）。
CHECK_FAILED = ("failure", "cancelled", "timed_out", "action_required",
                "startup_failure")
CHECK_PENDING = ("pending", "queued", "in_progress")
CHECK_NONBLOCKING = ("success", "neutral", "skipped")

# enum allowlist（未知値は fail-closed。良性の正規化漏れ / GitHub 実状態でも
# 成功側に倒さない — R1 A-02/B-01/B-02）。
MERGEABLE_VALID = ("MERGEABLE", "CONFLICTING", "UNKNOWN")
SEVERITY_VALID = ("critical", "major", "minor", "info")
SEVERITY_HARD = ("critical", "major")  # repair commit を要する（未知値もここへ倒す）
DISPOSITION_KINDS = ("adopted", "rejected")


def contract_dict() -> dict:
    return {
        "exits": sorted(EXITS),
        "priority_order": list(PRIORITY_ORDER),
        "states": sorted(STATES),
        "terminal": TERMINAL,
        "transitions": {k: sorted(v) for k, v in TRANSITIONS.items()},
    }


def contract_json() -> str:
    return json.dumps(contract_dict(), indent=2, sort_keys=True)


# ---------------------------------------------------------------------------
# snapshot 検証（TC-E2: fail-closed・対象キー名を明示）
# ---------------------------------------------------------------------------

class SnapshotError(ValueError):
    pass


def _is_sha(v) -> bool:
    return isinstance(v, str) and re.fullmatch(r"[0-9a-f]{7,40}", v) is not None


def validate_snapshot(snap) -> list[str]:
    reasons: list[str] = []
    if not isinstance(snap, dict):
        return ["snapshot が JSON object でない"]

    def need(key, pred, desc):
        if key not in snap:
            reasons.append(f"必須キー欠落: {key}")
        elif not pred(snap[key]):
            reasons.append(f"型/形式不一致: {key}（{desc}）")

    need("task_id", lambda v: isinstance(v, str) and re.fullmatch(r"TASK-[0-9]{4}", v),
         "TASK-XXXX")
    need("pr_number", lambda v: isinstance(v, int) and not isinstance(v, bool), "int")
    need("head_sha", _is_sha, "hex 7-40")
    need("source_sha_ancestry", lambda v: v in (True, False, None), "true/false/null")
    # mergeable は allowlist（未知値は fail-closed / A-02・B-01）。
    need("mergeable", lambda v: v in MERGEABLE_VALID,
         f"enum {MERGEABLE_VALID}（未知値は fail-closed）")
    need("checks", lambda v: isinstance(v, list) and all(
        isinstance(c, dict) and isinstance(c.get("name"), str)
        and _is_sha(c.get("sha")) and isinstance(c.get("conclusion"), str)
        for c in v), "list of {name, sha, conclusion}")
    need("review", lambda v: isinstance(v, dict) and isinstance(v.get("state"), str)
         and _is_sha(v.get("sha")), "{state, sha}")
    # findings: severity / disposition.kind を allowlist（未知値 fail-closed / A-02・B-02）。
    need("findings", lambda v: isinstance(v, list) and all(
        isinstance(f, dict) and isinstance(f.get("id"), str)
        and isinstance(f.get("finding_type"), str)
        and f.get("severity") in SEVERITY_VALID
        and (f.get("disposition") is None or (
            isinstance(f.get("disposition"), dict)
            and f["disposition"].get("kind") in DISPOSITION_KINDS))
        for f in v),
         "list of {id, finding_type, severity∈enum, disposition{kind∈enum}?}")
    need("changed_files", lambda v: isinstance(v, list) and all(
        isinstance(p, str) for p in v), "list of string")
    need("allowed_paths", lambda v: isinstance(v, list) and all(
        isinstance(p, str) for p in v), "list of string")
    need("escalation_flags", lambda v: isinstance(v, list), "list")
    need("dod_evaluated", lambda v: isinstance(v, bool), "bool")
    cr = snap.get("conflict_resolution")
    if cr is not None and not isinstance(cr, dict):
        reasons.append("型/形式不一致: conflict_resolution（object）")
    return reasons


# ---------------------------------------------------------------------------
# stable action ID / entry_id（冪等の基盤）
# ---------------------------------------------------------------------------

def action_id(payload: dict) -> str:
    return c3_contract.canonical_hash(payload)


def entry_id(entry: dict) -> str:
    core = {k: v for k, v in entry.items() if k not in ("at", "entry_id")}
    return c3_contract.canonical_hash(core)


def _action(kind: str, payload: dict) -> dict:
    body = dict(payload)
    body["action_kind"] = kind
    return {"action_kind": kind, "action_id": action_id(body), **payload}


# ---------------------------------------------------------------------------
# 判定エンジン（純関数: snapshot + entries → 判定）
# ---------------------------------------------------------------------------

def _resolved(f: dict) -> bool:
    d = f.get("disposition")
    if not isinstance(d, dict):
        return False
    if d.get("kind") == "adopted":
        return bool(d.get("repair_commit"))
    if d.get("kind") == "rejected":
        return bool(d.get("evidence_ref"))
    return False


def _pr_receipts(entries, pr):
    """当該 PR の receipt のみ（無関係 PR の receipt を round/recurrence に混ぜない
    — A-06）。receipt に pr_number が無い旧形式は集計対象外（fail-closed 寄り）。"""
    return [e for e in entries
            if e.get("kind") == "receipt" and e.get("pr_number") == pr]


def _completed_rounds(entries, pr) -> int:
    rounds = [e["round"] for e in _pr_receipts(entries, pr)
              if e.get("action_kind") in REPAIR_KINDS
              and isinstance(e.get("round"), int) and not isinstance(e.get("round"), bool)
              and e["round"] >= 0]
    return max(rounds, default=0)


def _receipt_ids(entries) -> set:
    return {e.get("action_id") for e in entries if e.get("kind") == "receipt"}


def _intent_ids(entries) -> set:
    return {e.get("action_id") for e in entries if e.get("kind") == "intent"}


def _past_repair_finding_types(entries, pr) -> set:
    return {e.get("finding_type") for e in _pr_receipts(entries, pr)
            if e.get("action_kind") == "repair_review" and e.get("finding_type")}


def _path_allowed(path: str, allowed) -> bool:
    """ディレクトリ許可は末尾 `/` 単位の境界一致・ファイル許可は完全一致（A-03:
    `scripts/foo` が `scripts/foobar.py` にマッチする prefix バグを排除）。"""
    for a in allowed:
        if a.endswith("/"):
            if path == a.rstrip("/") or path.startswith(a):
                return True
        elif path == a:
            return True
    return False


def assess(snapshot: dict, entries: list, plan_hash: str | None = None) -> dict:
    """判定エンジン本体（純関数・I/O なし）。

    返り値: {state, actions（receipt 未了の要求アクション）, new_entries
    （record へ append すべき未記録 entry）, reasons, record（MERGE_READY 時のみ）}
    """
    bad = validate_snapshot(snapshot)
    if bad:
        raise SnapshotError("; ".join(bad))

    head = snapshot["head_sha"]
    pr = snapshot["pr_number"]
    reasons: list[str] = []
    actions: list[dict] = []
    state = None
    record = None

    # 0b. Plan 逸脱（AC-6）→ EXEC_RETURN
    allowed = snapshot["allowed_paths"]
    deviated = [p for p in snapshot["changed_files"]
                if not _path_allowed(p, allowed)]
    if deviated:
        state = "EXEC_RETURN"
        reasons.append(f"Plan 逸脱: allowed_paths 外の変更 {deviated}")

    # 1. escalation_flags（HO / policy / irreversible）
    if state is None and snapshot["escalation_flags"]:
        state = "HUMAN_ESCALATED"
        reasons.append(f"escalation_flags: {snapshot['escalation_flags']}")

    # ancestry fail-closed（AC-2 前提。true 以外は成功扱いにしない）
    if state is None and snapshot["source_sha_ancestry"] is not True:
        state = "HUMAN_ESCALATED"
        reasons.append(
            "source_sha_ancestry が true でない（検証不能/不成立は fail-closed）")

    if state is None:
        checks_at_head = [c for c in snapshot["checks"] if c["sha"] == head]
        failed = [c for c in checks_at_head if c["conclusion"] in CHECK_FAILED]
        pending = [c for c in checks_at_head if c["conclusion"] in CHECK_PENDING]
        unknown_checks = [
            c for c in checks_at_head
            if c["conclusion"] not in CHECK_FAILED + CHECK_PENDING + CHECK_NONBLOCKING]
        review = snapshot["review"]
        review_ok = review["state"] == "approved" and review["sha"] == head
        findings = snapshot["findings"]
        unresolved = [f for f in findings if not _resolved(f)]
        unresolved_hard = [f for f in unresolved if f["severity"] in SEVERITY_HARD]
        completed = _completed_rounds(entries, pr)
        next_round = completed + 1

        cr = snapshot.get("conflict_resolution")
        cr_incomplete = isinstance(cr, dict) and not all(
            cr.get(k) for k in ("base_sha", "head_sha", "result_sha"))
        # mergeable は allowlist（validate_snapshot 済み）。MERGEABLE 以外は
        # conflict 側に倒す（UNKNOWN = GitHub 計算中も fail-closed / A-02・B-01）。
        conflict_need = snapshot["mergeable"] != "MERGEABLE" or cr_incomplete

        recurrence = [f for f in unresolved
                      if f["finding_type"] in _past_repair_finding_types(entries, pr)]

        # 4''. 未知の check conclusion → escalate（RV-1・allowlist 外は
        # pending 扱いにしない = livelock も成功側誤倒れも防ぐ fail-closed）
        if unknown_checks:
            state = "HUMAN_ESCALATED"
            reasons.append(
                "未知の check conclusion（fail-closed）: "
                f"{sorted({c['conclusion'] for c in unknown_checks})}")

        # 4'. taxonomy 検証不能（permission / unknown / 未知値）→ escalate（AC-9）
        if state is None and failed:
            tax = snapshot.get("ci_failure_taxonomy")
            if tax not in VALID_TAXONOMY_REPAIR:
                state = "HUMAN_ESCALATED"
                reasons.append(
                    f"ci_failure_taxonomy={tax!r} は repair 対象外（成功扱いにしない）")

        # repair 系の必要性を確定し、round 上限を先に判定（優先度 2）
        if state is None:
            repair_needed = bool(failed or conflict_need or unresolved_hard or recurrence)
            if repair_needed and next_round > ROUND_LIMIT:
                state = "HUMAN_ESCALATED"
                reasons.append(
                    f"repair round 上限超過（round {next_round} に進まない・上限 {ROUND_LIMIT}）")

        if state is None and recurrence:
            # 優先度 3: 同型指摘の再発 → 還元 + repair（独立 state にしない）
            state = "REVIEW_REPAIR"
            for f in recurrence:
                reasons.append(f"同型指摘の再発: {f['finding_type']}（{f['id']}）")
                actions.append(_action("feedback_loop_referral", {
                    "pr_number": pr, "head_sha": head,
                    "finding_type": f["finding_type"]}))
                actions.append(_action("repair_review", {
                    "pr_number": pr, "head_sha": head, "round": next_round,
                    "finding_id": f["id"], "finding_type": f["finding_type"],
                    "severity": f["severity"]}))

        if state is None and failed:
            # 優先度 4: CI failed（taxonomy = code/flaky/environment）
            state = "CHECKS_FAILED"
            actions.append(_action("repair_ci", {
                "pr_number": pr, "head_sha": head, "round": next_round,
                "taxonomy": snapshot["ci_failure_taxonomy"],
                "failed_checks": sorted(c["name"] for c in failed)}))
            reasons.append(f"CI failure: {sorted(c['name'] for c in failed)}")

        if state is None and conflict_need:
            # 優先度 5: conflict（三点照合欠落は解消と認めない）
            state = "CONFLICT"
            if cr_incomplete:
                reasons.append("conflict_resolution の三点照合フィールドが欠落")
            actions.append(_action("resolve_conflict", {
                "pr_number": pr, "head_sha": head, "round": next_round}))

        if state is None and unresolved:
            # 優先度 6: 未解決 finding（critical/major は修正・minor/info は記録要求）
            state = "REVIEW_REPAIR"
            for f in unresolved:
                kind = "repair_review" if f["severity"] in SEVERITY_HARD \
                    else "record_disposition"
                payload = {"pr_number": pr, "head_sha": head,
                           "finding_id": f["id"], "finding_type": f["finding_type"],
                           "severity": f["severity"]}
                if kind == "repair_review":
                    payload["round"] = next_round
                actions.append(_action(kind, payload))
                reasons.append(f"未解決 finding: {f['id']}（{f['severity']}）")

        if state is None and (pending or not checks_at_head):
            state = "WAITING_FOR_CHECKS"
            reasons.append("最新 head の CI が pending / 未着（stale checks は無効）")

        if state is None and not review_ok:
            state = "WAITING_FOR_REVIEW"
            reasons.append("required review が最新 head で未着弾")

        if state is None and not snapshot["dod_evaluated"]:
            # 優先度 7: candidate（終端に短絡しない）
            state = "MERGE_READY_CANDIDATE"
            actions.append(_action("dod_reevaluate", {"pr_number": pr, "head_sha": head}))
            reasons.append("minor/info 記録済み・DoD 未判定（candidate）")

        if state is None:
            # 優先度 8: DoD 充足 → MERGE_READY（唯一の到達経路）
            state = "MERGE_READY"
            record = {
                "pr_number": pr,
                "head_sha": head,
                "check_summary": {c["name"]: c["conclusion"] for c in checks_at_head},
                "review_disposition": {
                    f["id"]: f.get("disposition") for f in findings},
                "round": completed,
                "plan_hash": plan_hash,
            }

    # 冪等: receipt 済みアクションは要求から除外（intent 未 receipt は再要求）
    receipts = _receipt_ids(entries)
    actions = [a for a in actions if a["action_id"] not in receipts]

    new_entries: list[dict] = []
    state_entry = {"kind": "state", "state": state, "head_sha": head,
                   "pr_number": pr, "reasons": sorted(reasons)}
    known = {entry_id({k: v for k, v in e.items() if k not in ("at", "entry_id")})
             for e in entries}
    if entry_id(state_entry) not in known:
        new_entries.append(state_entry)
    intents = _intent_ids(entries)
    for a in actions:
        if a["action_id"] in intents:
            continue
        intent = {"kind": "intent", "action_id": a["action_id"],
                  "action_kind": a["action_kind"],
                  "payload": {k: v for k, v in a.items()
                              if k not in ("action_id", "action_kind")}}
        if a["action_kind"] == "repair_review":
            intent["finding_type"] = a.get("finding_type")
        if entry_id(intent) not in known:
            new_entries.append(intent)
    if record is not None:
        mr_entry = {"kind": "merge_ready", "record": record}
        if entry_id(mr_entry) not in known:
            new_entries.append(mr_entry)

    result = {"state": state, "actions": actions, "new_entries": new_entries,
              "reasons": sorted(reasons)}
    if record is not None:
        result["record"] = record
    return result


# ---------------------------------------------------------------------------
# record I/O（append-only・冪等・timestamp 注入）
# ---------------------------------------------------------------------------

def record_path(task_dir) -> pathlib.Path:
    return pathlib.Path(task_dir) / "delivery" / "record.jsonl"


class RecordError(ValueError):
    pass


def load_entries(path) -> list:
    """record.jsonl を読み込む。破損行 / 記録済み entry_id の改竄は fail-closed で
    RecordError（B-04: 生 traceback を避け制御された停止。A-05: 攻撃者が予測 entry_id を
    先行投入して append を抑止する手を封じるため、保存 entry_id を信用せず再計算照合）。"""
    p = pathlib.Path(path)
    if not p.is_file():
        return []
    entries = []
    for i, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            row = json.loads(line)
        except ValueError as exc:
            raise RecordError(f"record.jsonl の {i} 行目が壊れている（fail-closed）: {exc}")
        if not isinstance(row, dict):
            raise RecordError(f"record.jsonl の {i} 行目が object でない（fail-closed）")
        stored = row.get("entry_id")
        recomputed = entry_id(row)
        if stored is not None and stored != recomputed:
            raise RecordError(
                f"record.jsonl の {i} 行目の entry_id が本体と不一致"
                "（改竄兆候・fail-closed）")
        entries.append(row)
    return entries


def append_entries(path, entries, now: str) -> int:
    p = pathlib.Path(path)
    # 保存 entry_id は信用せず本体から再計算（A-05）。
    existing = {entry_id(e) for e in load_entries(p)}
    p.parent.mkdir(parents=True, exist_ok=True)
    n = 0
    with open(p, "a", encoding="utf-8") as f:
        for e in entries:
            eid = entry_id(e)
            if eid in existing:
                continue
            row = {**e, "at": now, "entry_id": eid}
            f.write(json.dumps(row, sort_keys=True, ensure_ascii=False) + "\n")
            existing.add(eid)
            n += 1
    return n


# ---------------------------------------------------------------------------
# c3-prime 入口再検証（契約 §7 / R-009: legacy も BLOCK）
# ---------------------------------------------------------------------------

def verify_c3(task_dir, expected_sha=None) -> tuple[int, str]:
    argv = ["c3prime_verify.py", str(task_dir)]
    if expected_sha:
        argv.append(expected_sha)
    buf = StringIO()
    with redirect_stderr(buf):
        rc = c3prime_verify.main(argv)
    return rc, buf.getvalue()


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _parse_kv(argv):
    opts = {}
    it = iter(argv)
    for a in it:
        if a.startswith("--"):
            opts[a[2:]] = next(it, None)
    return opts


def _cmd_assess(opts) -> int:
    # expected-sha を必須化（A-08: 呼び出し側が渡し忘れると source_sha 照合が
    # 弱体化する。信頼済み実行層が解決した対象 SHA の注入を強制）。
    for k in ("task-dir", "snapshot", "now", "expected-sha"):
        if not opts.get(k):
            print(f"delivery: --{k} は必須", file=sys.stderr)
            return 2
    task_dir = pathlib.Path(opts["task-dir"])
    rc, captured = verify_c3(task_dir, opts["expected-sha"])
    if rc == 10:
        print("delivery: BLOCK — legacy c3.json（ai-loop Delivery は c3-prime 必須）",
              file=sys.stderr)
        return 3
    if rc != 0:
        print(f"delivery: BLOCK — c3-prime 再検証 NG: {captured.strip()}",
              file=sys.stderr)
        return 3
    c3 = json.loads((task_dir / "approvals" / "c3.json").read_text(encoding="utf-8"))
    try:
        snapshot = json.loads(pathlib.Path(opts["snapshot"]).read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        print(f"delivery: snapshot を読めない: {exc}", file=sys.stderr)
        return 2
    # snapshot.task_id を c3 の task_id / task_dir に束縛（A-01/B-03: 別 TASK の
    # snapshot をこの承認へ流し込む手を封じる）。task_id が存在して不一致のときのみ
    # BLOCK（欠落/形式不正は後続の validate_snapshot が fail-closed で報告する）。
    if isinstance(snapshot, dict) and snapshot.get("task_id") is not None \
            and snapshot.get("task_id") != c3.get("task_id"):
        print(f"delivery: BLOCK — snapshot.task_id ({snapshot.get('task_id')!r}) が "
              f"c3-prime の task_id ({c3.get('task_id')!r}) と不一致", file=sys.stderr)
        return 3
    try:
        entries = load_entries(record_path(task_dir))
    except RecordError as exc:
        print(f"delivery: BLOCK — {exc}", file=sys.stderr)
        return 3
    try:
        result = assess(snapshot, entries, plan_hash=c3.get("plan_hash"))
    except SnapshotError as exc:
        print(f"delivery: snapshot 不正（fail-closed）: {exc}", file=sys.stderr)
        return 2
    append_entries(record_path(task_dir), result["new_entries"], opts["now"])
    out = {k: v for k, v in result.items() if k != "new_entries"}
    print(json.dumps(out, indent=2, sort_keys=True, ensure_ascii=False))
    return 0


def _cmd_receipt(opts) -> int:
    for k in ("task-dir", "action-id", "result-ref", "now"):
        if not opts.get(k):
            print(f"delivery: --{k} は必須", file=sys.stderr)
            return 2
    path = record_path(opts["task-dir"])
    try:
        entries = load_entries(path)
    except RecordError as exc:
        print(f"delivery: {exc}", file=sys.stderr)
        return 3
    intent = next((e for e in entries
                   if e.get("kind") == "intent" and e.get("action_id") == opts["action-id"]),
                  None)
    if intent is None:
        print(f"delivery: intent が存在しない action_id: {opts['action-id']}"
              "（fail-closed: 記録なき実行は受理しない）", file=sys.stderr)
        return 2
    payload = intent.get("payload") or {}
    # receipt に pr_number / head_sha を intent から束縛（A-06: round/recurrence の
    # 集計を対象 PR に限定するため）。
    receipt = {"kind": "receipt", "action_id": opts["action-id"],
               "action_kind": intent.get("action_kind"),
               "pr_number": payload.get("pr_number"),
               "head_sha": payload.get("head_sha"),
               "round": payload.get("round", 0),
               "result_ref": opts["result-ref"]}
    ft = payload.get("finding_type")
    if ft:
        receipt["finding_type"] = ft
    append_entries(path, [receipt], opts["now"])
    print(json.dumps({"receipt": receipt["action_id"]}, sort_keys=True))
    return 0


def main(argv) -> int:
    if len(argv) < 2:
        print("usage: delivery.py {contract|assess|receipt} [--opts]", file=sys.stderr)
        return 2
    cmd = argv[1]
    if cmd == "contract":
        print(contract_json())
        return 0
    opts = _parse_kv(argv[2:])
    if cmd == "assess":
        return _cmd_assess(opts)
    if cmd == "receipt":
        return _cmd_receipt(opts)
    print(f"delivery: 未知のサブコマンド: {cmd}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
