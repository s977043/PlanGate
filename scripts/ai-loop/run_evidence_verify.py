#!/usr/bin/env python3
"""RunEvidence 受理検証（TASK-0874 / #874）。

契約正本: docs/workflows/ai-loop/run-evidence-contract.md §6。
schema:   docs/schemas/run-evidence.schema.json（**唯一の正**。必須キー・許可キーは
          本スクリプトにハードコードせず schema から導出する）。

trust boundary: 生成側（run_evidence.py）の申告を信頼せず、受理側が
<task_dir> の approvals/c3.json と delivery/record.jsonl を**再読込して照合**する
（c3-prime-contract.md §7 の転写）。EV 単体入力にしないのはこのため
（sha256:+64hex の形式を保った 1 文字改変は EV 単体では検出できない）。

使い方: run_evidence_verify.py <ev.json> <task_dir>
  exit 0  = RunEvidence として受理（evidence_status=complete・全束縛整合）
  exit 1  = 検証 NG（fail-closed。理由を stderr に出力）
  exit 10 = legacy（EV ではなく arbiter record を渡された）→ 呼び出し側が legacy 経路へ委譲
            ※ 値・意味は c3prime_verify.py の `return 10  # legacy` と同一
  exit 11 = partial（必須フィールドは揃うが unavailable、または「検査そのものが未実行」
            を示す escalation（harness_drift_unchecked / 契約 §4-1）を含む = ready 扱いしない）

⚠️ 本受理器の rc を bin/plangate の _plangate_c3_dispatch 経路へ流してはならない
（同経路は 0/1 以外を catch-all で legacy にフォールバックするため 11 を誤読する）。
"""
from __future__ import annotations

import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
REPO_ROOT = HERE.parent.parent
SCHEMA_PATH = REPO_ROOT / "docs" / "schemas" / "run-evidence.schema.json"

sys.path.insert(0, str(HERE))
import delivery  # noqa: E402  record.jsonl の再計算照合を再実装しない

# 「取得不能」を表す唯一の語彙。0 とも空配列とも区別する（契約 §5-1）。
UNAVAILABLE = "unavailable"

# 「検証していない」ことを表す escalation kind（契約 §4-1）。
# 検査済み EV と未検査 EV を受理側が区別できなければ AC-12 は caller の善意に
# 依存する。未検査は complete にせず partial 理由として列挙する。
UNVERIFIED_ESCALATION_KINDS = ("harness_drift_unchecked",)

# legacy 判別子: arbiter record（9 キー世代 / 14 キー世代）の共通キー集合（実測）。
# EV の properties とは 1 キーも重複しないため、EV から必須キーが欠落しても
# legacy には落ちない（欠落は exit 1 のまま = fail-closed）。
ARBITER_MARKER_KEYS = frozenset((
    "boundary_check", "class_check", "decision", "issued_by", "lite_check",
    "policy_ref", "target_sha", "timestamp", "w_check",
))

_SHA256 = re.compile(r"^sha256:[0-9a-f]{64}$")
_COMMIT = re.compile(r"^[0-9a-f]{7,40}$")
_TASK_ID = re.compile(r"^TASK-[0-9]{4}$")


def _schema() -> dict:
    return json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))


def required_keys() -> tuple:
    """必須キー集合を schema から導出する（ハードコードしない / TC-61）。"""
    return tuple(_schema()["required"])


def allowed_keys() -> tuple:
    """許可トップレベルキー集合を schema から導出する（^_ は別途 pattern 許容）。"""
    return tuple(_schema()["properties"])


def _fail(msg: str) -> int:
    print(f"run-evidence: {msg}", file=sys.stderr)
    return 1


def _unavailable_paths(data: dict) -> list:
    """unavailable の位置を dotted path で全数列挙する（契約 §5-1）。

    partial の理由は (a) Phase 1 固定 3 件と (b) terminal_state 依存 最大 5 件の
    2 分類（+ §4-1 の未検証 escalation）にまたがる。曖昧化しない担保は
    「理由が 1 種類であること」ではなく「理由が機械可読に全数列挙されること」に置く。
    """
    out = []
    for key in sorted(data):
        value = data[key]
        if value == UNAVAILABLE:
            out.append(key)
        elif isinstance(value, dict):
            for sub in sorted(value):
                if value[sub] == UNAVAILABLE:
                    out.append(f"{key}.{sub}")
    return out


def _unverified_kinds(data: dict) -> list:
    """「検査そのものが未実行」を示す escalation kind を列挙する（契約 §4-1）。

    `escalation` は optional のため欠落・非 list も安全側（未検証扱いにしない
    のではなく、読めた範囲で列挙する）に扱う。
    """
    entries = data.get("escalation")
    if not isinstance(entries, list):
        return []
    return sorted({str(e.get("kind")) for e in entries
                   if isinstance(e, dict)
                   and e.get("kind") in UNVERIFIED_ESCALATION_KINDS})


def _check_c3_binding(data: dict, task_dir: pathlib.Path):
    """approvals/c3.json との束縛を再検証する。エラー文字列 or None を返す。"""
    c3_path = task_dir / "approvals" / "c3.json"
    if not c3_path.is_file():
        return f"approvals/c3.json が存在しない: {c3_path}"
    try:
        c3 = json.loads(c3_path.read_text(encoding="utf-8"))
    except (ValueError, OSError) as exc:
        return f"approvals/c3.json を strict JSON として読めない: {exc}"
    if not isinstance(c3, dict):
        return "approvals/c3.json が JSON object でない"

    for field in ("plan_hash", "source_sha"):
        if field not in c3:
            return f"{field} を approvals/c3.json と照合できない（c3.json に {field} が無い）"
        if data[field] != c3[field]:
            return (f"{field} が approvals/c3.json と不一致"
                    f"（EV={data[field]!r} / c3.json={c3[field]!r}・改竄兆候）")

    ref = data["c3_prime_decision_ref"]
    if not isinstance(ref, dict) or set(ref) != {"path", "plan_package_hash"}:
        return "c3_prime_decision_ref が {path, plan_package_hash} の object でない"
    expected_suffix = f"{task_dir.name}/approvals/c3.json"
    if not str(ref["path"]).endswith(expected_suffix):
        return (f"c3_prime_decision_ref.path が {expected_suffix} を指していない: "
                f"{ref['path']!r}")
    if str(ref["path"]).startswith("/"):
        return f"c3_prime_decision_ref.path が絶対パス: {ref['path']!r}"
    if "plan_package_hash" not in c3:
        return "c3_prime_decision_ref.plan_package_hash を照合できない（c3.json に plan_package_hash が無い）"
    if ref["plan_package_hash"] != c3["plan_package_hash"]:
        return "c3_prime_decision_ref.plan_package_hash が approvals/c3.json と不一致（改竄兆候）"
    return None


def _check_record_binding(data: dict, task_dir: pathlib.Path):
    """delivery/record.jsonl の再計算値との束縛を検証する。"""
    delivery_fields = ("final_head_sha", "ci_outcomes", "review_findings", "repair_rounds")
    rec_path = delivery.record_path(task_dir)
    if not rec_path.is_file():
        # BLOCKED（exec 未到達）は record.jsonl 自体が存在しない。
        # delivery 層 4 フィールドは構造的に取得不能 = unavailable でなければならない
        # （ダミー sha・空文字・0 で埋めるのは fail-open / 契約 §5）。
        padded = [f for f in delivery_fields if data[f] != UNAVAILABLE]
        if padded:
            return (f"delivery/record.jsonl が存在しないのに実値が入っている: {padded}"
                    "（unavailable であるべき・ダミー値での穴埋めは fail-open）")
        return None

    try:
        entries = delivery.load_entries(rec_path)
    except Exception as exc:                      # delivery.RecordError（entry_id 改竄等）
        return f"delivery/record.jsonl の再計算照合に失敗（fail-closed）: {exc}"

    merge_ready = [e for e in entries if e.get("kind") == "merge_ready"]
    states = [e for e in entries if e.get("kind") == "state"]
    mr_record = merge_ready[-1].get("record", {}) if merge_ready else {}

    expected_head = mr_record.get("head_sha")
    if expected_head is None and states:
        expected_head = states[-1].get("head_sha")
    if expected_head is None:
        if data["final_head_sha"] != UNAVAILABLE:
            return ("final_head_sha を record.jsonl から再計算できないのに実値が入っている"
                    f"（{data['final_head_sha']!r}）")
    elif data["final_head_sha"] != expected_head:
        return (f"final_head_sha が record.jsonl の再計算値と不一致"
                f"（EV={data['final_head_sha']!r} / record={expected_head!r}）")

    pr = mr_record.get("pr_number")
    if pr is None:
        # PR 番号が解決できないとき delivery._completed_rounds(entries, None) は
        # 例外にならず 0 を返す。0 に倒すと修理 0 回として下流を汚染するため、
        # unavailable 以外は受理しない（契約 §3-2）。
        if data["repair_rounds"] != UNAVAILABLE:
            return ("repair_rounds: PR 番号が record.jsonl から解決できないのに実値が入っている"
                    f"（{data['repair_rounds']!r}・unavailable であるべき）")
    else:
        expected_rounds = delivery._completed_rounds(entries, pr)
        if data["repair_rounds"] != expected_rounds:
            return (f"repair_rounds が delivery._completed_rounds() の再計算値と不一致"
                    f"（EV={data['repair_rounds']!r} / 再計算={expected_rounds}）")
    return None


def main(argv):
    if len(argv) != 3:
        print("usage: run_evidence_verify.py <ev.json> <task_dir>", file=sys.stderr)
        return 1
    ev_path = pathlib.Path(argv[1])
    task_dir = pathlib.Path(argv[2])
    if not ev_path.is_file():
        return _fail(f"RunEvidence ファイルが存在しない: {ev_path}")
    try:
        data = json.loads(ev_path.read_text(encoding="utf-8"))
    except (ValueError, OSError) as exc:
        return _fail(f"RunEvidence を strict JSON として読めない: {exc}")
    if not isinstance(data, dict):
        return _fail("RunEvidence が JSON object でない")

    try:
        allowed = set(allowed_keys())
        required = list(required_keys())
    except (ValueError, OSError) as exc:
        return _fail(f"schema を読めない（{SCHEMA_PATH}）: {exc}")

    keys = set(data)
    # legacy 判別（arbiter record を渡された）。EV の properties と 1 キーも
    # 重複しない場合のみ委譲する（必須キー欠落を legacy に誤分類しない）。
    if ARBITER_MARKER_KEYS <= keys and not (keys & allowed):
        return 10

    unknown = sorted(k for k in keys if k not in allowed and not k.startswith("_"))
    if unknown:
        return _fail(f"未知のトップレベルキー: {unknown}")
    for k in sorted(keys):
        if k.startswith("_") and not isinstance(data[k], str):
            return _fail(f"注釈キー {k} が string でない")

    missing = [k for k in required if k not in data]
    if missing:
        return _fail(f"必須キー欠落: {sorted(missing)}")

    task_id = data["task_id"]
    if not isinstance(task_id, str) or not _TASK_ID.fullmatch(task_id):
        return _fail(f"task_id が TASK-XXXX 形式でない: {task_id!r}")
    if task_dir.name != task_id:
        return _fail(f"task_id ({task_id}) が task_dir 名 ({task_dir.name}) と不一致")

    if not _SHA256.fullmatch(str(data["plan_hash"])):
        return _fail(f"plan_hash が sha256:+64hex 形式でない: {data['plan_hash']!r}")
    if not _COMMIT.fullmatch(str(data["source_sha"])):
        return _fail(f"source_sha が commit SHA 形式でない: {data['source_sha']!r}")

    err = _check_c3_binding(data, task_dir)
    if err:
        return _fail(err)
    err = _check_record_binding(data, task_dir)
    if err:
        return _fail(err)

    reasons = [f"unavailable:{p}" for p in _unavailable_paths(data)]
    reasons += [f"unverified:{k}" for k in _unverified_kinds(data)]
    if reasons:
        print("run-evidence: partial（unavailable / 未検証を含むため ready 扱いしない）: "
              + ", ".join(reasons), file=sys.stderr)
        return 11
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
