#!/usr/bin/env python3
"""run_evidence.py — RunEvidence 決定論 producer（TASK-0874 / issue 874）。

契約正本: docs/workflows/ai-loop/run-evidence-contract.md
schema:   docs/schemas/run-evidence.schema.json
受理器:   scripts/ai-loop/run_evidence_verify.py（本 producer の出力を再検証する）

設計原則（delivery.py / plan_package.py / c3prime_verify.py と同型）:
- 決定論: timestamp は --now / --started-at 注入（時刻を内部参照しない）。
  serialization は sort_keys=True。同一入力 + 同一注入値なら byte 一致する。
- 純判定器: ネットワーク・外部プロセスを一切呼ばない。読むのは入力ソース
  allowlist（task_dir 配下の Plan Package / approvals / delivery と
  runs_dir 配下の arbiter record）のみ。transcript / session log / hidden CoT /
  環境変数は読まない（契約 §3-1）。
- fail-closed: 判定不能はすべてエラー側に倒す。取得不能は "unavailable" で
  明示し、0 や空配列で埋めない（契約 §5）。
- 非終端 run は EV を発行しない（契約 §4）。

使い方:
  run_evidence.py <task_dir> --now <ISO> --started-at <ISO> --repository <name>
                  --run-id <id> --harness-version '<json>'
                  [--harness-version-end '<json>'] [--pr-number <n>]
                  [--runs-dir <dir>] [--routing-decisions '<json>']
                  [--observation <text>] [--cause-hypothesis <text>]
                  [--evidence-ref <repo 相対パス>]... [--out <path.json>]
  exit 0 = 生成成功（既定は stdout へ 1 record）
  exit 1 = 生成拒否（理由を stderr に全数出力）
"""
from __future__ import annotations

import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
REPO_ROOT = HERE.parent.parent

sys.path.insert(0, str(HERE))
import c3_contract  # noqa: E402  canonical_hash / sha256_of_file の単一定義
import delivery  # noqa: E402  record 読込・round 再計算・c3-prime 再検証の再利用

# ---------------------------------------------------------------------------
# 契約定数（schema と 1:1。束縛は test_run_evidence_verify.py TC-62 が機械照合）
# ---------------------------------------------------------------------------

SCHEMA_VERSION = "1.0"

#: 「取得不能」を表す唯一の語彙。0 とも空配列とも区別する（契約 §5-1）。
UNAVAILABLE = "unavailable"

#: producer 出力キーの全集合（契約 §2 の 24 行 = schema の properties と 1:1）。
OUTPUT_KEYS = (
    "run_id", "task_id", "started_at", "completed_at", "repository",
    "source_sha", "final_head_sha", "plan_hash", "c3_prime_decision_ref",
    "harness_version", "routing_decisions", "ci_outcomes", "review_findings",
    "repair_rounds", "replan_count", "human_interventions", "terminal_state",
    "quality_metrics", "cost_metrics", "evidence_refs", "schema_version",
    "observation", "cause_hypothesis", "escalation",
)

#: 出力に 1 つも現れてはならないキー（契約 §7-1・EH-8 と同一集合）。
FORBIDDEN_KEYS = (
    "file_path", "file_paths", "stack_trace", "stacktrace", "command_output",
    "stdout", "stderr", "raw_response", "raw_request", "api_key",
    "user_prompt", "system_prompt", "prompt_text", "absolute_path",
)

#: account 識別子を運びうる入力キー（EH-8 の禁止キーに含まれず素通りする）。
ACCOUNT_KEYS = (
    "account", "actor", "author", "github_user", "login", "owner", "user",
    "username",
)

#: delivery.assess() が生成する既知 kind（これ以外は escalation に記録する）。
KNOWN_RECORD_KINDS = ("intent", "merge_ready", "receipt", "state")

#: Phase 1 で供給元が main に存在しないフィールド（契約 §5-1 (a)）。
PHASE1_UNAVAILABLE = ("replan_count", "cost_metrics")

#: 非終端状態（delivery の STATES + EXITS から 3 値 terminal を除いた残り）。
NON_TERMINAL_STATES = tuple(sorted(
    (set(delivery.STATES) | set(delivery.EXITS)) - {"MERGE_READY", "HUMAN_ESCALATED"}))

#: repeat 可能な CLI フラグ。
MULTI_FLAGS = ("evidence-ref",)

_ISO_UTC = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")
_COMMIT = re.compile(r"^[0-9a-f]{7,40}$")
_TASK_ID = re.compile(r"^TASK-[0-9]{4}$")
_SHA256 = re.compile(r"^sha256:[0-9a-f]{64}$")
_URL = re.compile(r"https?://[^\s\"']+")
_PR_IN_URL = re.compile(r"/pull/([0-9]+)")
_COMMENT_IN_URL = re.compile(r"#issuecomment-([0-9]+)")
_ABSOLUTE = re.compile(r"(^/|/Users/)")
_HANDLE = re.compile(r"(?<![A-Za-z0-9])@[A-Za-z0-9][A-Za-z0-9-]+")
_ACCOUNT_VALUE = re.compile(r"(github\.com|://|(?<![A-Za-z0-9])@[A-Za-z0-9][A-Za-z0-9-]+)")


class RunEvidenceError(Exception):
    """理由を全件保持する生成拒否（plan_package.PlanPackageError と同型）。"""

    def __init__(self, errors):
        self.errors = list(errors)
        super().__init__("; ".join(self.errors))


# ---------------------------------------------------------------------------
# 純関数ユーティリティ
# ---------------------------------------------------------------------------

def _parse_kv(argv):
    """delivery._parse_kv の転写（repeat 可能フラグと位置引数を追加）。"""
    opts = {}
    positional = []
    it = iter(argv)
    for a in it:
        if a.startswith("--"):
            key = a[2:]
            value = next(it, None)
            if key in MULTI_FLAGS:
                opts.setdefault(key, []).append(value)
            else:
                opts[key] = value
        else:
            positional.append(a)
    opts["_positional"] = positional
    return opts


def _rel_to_repo(path) -> str:
    """repo 相対パスへ還元する（絶対パスは出力しない = 契約 §7-2）。"""
    p = pathlib.Path(path).resolve()
    try:
        return str(p.relative_to(REPO_ROOT))
    except ValueError:
        parts = p.parts
        for i, part in enumerate(parts):
            if _TASK_ID.fullmatch(part):
                return "/".join(parts[i:])
        return p.name


def _reduce_refs(text, escalation):
    """URL を「PR 番号 / コメント ID」へ還元する（契約 §7-3 / U-5）。"""
    def _repl(match):
        url = match.group(0)
        pr = _PR_IN_URL.search(url)
        comment = _COMMENT_IN_URL.search(url)
        parts = []
        if pr:
            parts.append(f"pr:{pr.group(1)}")
        if comment:
            parts.append(f"comment:{comment.group(1)}")
        escalation.append({"kind": "privacy_url_reduced",
                           "detail": "URL を番号参照へ還元した"})
        return "#".join(parts) if parts else "ref:redacted"
    return _URL.sub(_repl, text)


def _redact(text, escalation):
    """入力由来の文字列を出力に載せる前に還元する（契約 §7-2 / §7-3）。

    URL は番号参照へ還元し、絶対パスは token へ置換する。**握り潰さず**
    `escalation` に記録する（黙って落とすと privacy 違反の入力が検出されない）。
    """
    reduced = _reduce_refs(str(text), escalation)
    if _ABSOLUTE.search(reduced):
        escalation.append({"kind": "privacy_absolute_path",
                           "detail": "絶対パスを含む入力値を還元した"})
        reduced = re.sub(r"(?<![A-Za-z0-9])/[^\s\"']*", "path:redacted", reduced)
    if _HANDLE.search(reduced):
        escalation.append({"kind": "privacy_account_handle",
                           "detail": "account handle を含む入力値を還元した"})
        reduced = _HANDLE.sub("account:redacted", reduced)
    return reduced


def _walk(node, prefix=""):
    """(dotted path, key, value) を深さ優先で列挙する。"""
    if isinstance(node, dict):
        for key in sorted(node):
            path = f"{prefix}.{key}" if prefix else key
            yield path, key, node[key]
            yield from _walk(node[key], path)
    elif isinstance(node, list):
        for i, item in enumerate(node):
            path = f"{prefix}[{i}]"
            yield path, None, item
            yield from _walk(item, path)


def scan_input_privacy(node, label):
    """入力側の privacy 異常を escalation エントリとして列挙する（握り潰さない）。"""
    found = []
    for _path, key, _value in _walk(node):
        if key is None:
            continue
        if key in FORBIDDEN_KEYS:
            found.append({"kind": "privacy_forbidden_key",
                          "detail": f"{label}: {key}"})
        elif key in ACCOUNT_KEYS:
            found.append({"kind": "privacy_account_key",
                          "detail": f"{label}: {key}"})
    return found


def check_output_privacy(record) -> list:
    """出力側 privacy の最終検査（契約 §7・fail-closed）。"""
    errors = []
    for path, key, value in _walk(record):
        if key in FORBIDDEN_KEYS:
            errors.append(f"禁止キーが出力に現れた: {path}（契約 §7-1）")
        if key in ACCOUNT_KEYS:
            errors.append(f"account 識別子キーが出力に現れた: {path}（契約 §7-2）")
        if isinstance(value, str):
            if _ABSOLUTE.search(value):
                errors.append(f"絶対パスが出力に現れた: {path}（契約 §7-2）")
            if _ACCOUNT_VALUE.search(value):
                errors.append(f"URL / account 識別子が値に現れた: {path}（契約 §7-3）")
    return errors


def serialize(record) -> str:
    """契約 §1: plan_package.serialize_c3_prime() と byte 互換の serialization。"""
    return json.dumps(record, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


# ---------------------------------------------------------------------------
# 入力読込（allowlist の外を open しない）
# ---------------------------------------------------------------------------

def _load_c3(task_dir, errors):
    path = task_dir / "approvals" / "c3.json"
    if not path.is_file():
        errors.append(f"approvals/c3.json が存在しない: {_rel_to_repo(path)}")
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (ValueError, OSError) as exc:
        errors.append(f"approvals/c3.json を strict JSON として読めない: {exc}")
        return None
    if not isinstance(data, dict):
        errors.append("approvals/c3.json が JSON object でない")
        return None
    return data


def _decision_only_failure(captured: str) -> bool:
    """c3prime_verify の NG 理由が「decision 値のみ」に起因するかを判定する。

    契約 §6-5: rc==0 は decision=="AUTO_APPROVED" を含意するため、
    「rc==0 を要求」を文字どおり実装すると BLOCKED / HUMAN_ESCALATED の EV が
    構造的に発行できない。decision の値は**検証結果ではなく terminal_state の
    供給元**として扱い、束縛不整合（hash / artifact / reviewer）は fail-closed に
    保つ。この判定は c3prime_verify.py の
    `_fail(f"decision={decision}（exec 不可。AUTO_APPROVED のみ受理）")` を
    記号アンカーとする。
    """
    return captured.strip().startswith("c3-prime: decision=")


def _recheck_bindings(task_dir, c3) -> list:
    """decision-only NG のときに c3prime_verify が到達しなかった束縛を再検証する。

    c3prime_verify は decision 判定で return するため、その後段（source_sha /
    plan_hash / artifact_hashes / plan_package_hash / reviewer snapshot）が
    未検証のまま残る。ここを空けると BLOCKED な c3.json 経由で改竄 provenance が
    通るため、**c3_contract の同一プリミティブを import して**同じ照合を行う
    （検証ロジックを再実装しない）。
    """
    errors = []
    source_sha = c3.get("source_sha")
    if not isinstance(source_sha, str) or not _COMMIT.fullmatch(source_sha):
        errors.append(f"source_sha が commit SHA 形式でない: {source_sha!r}")
    plan_md = task_dir / "plan.md"
    if not plan_md.is_file():
        errors.append("plan.md が存在しない")
    elif c3.get("plan_hash") != c3_contract.sha256_of_file(plan_md):
        errors.append("plan_hash が現 plan.md と不一致（stale）")
    ah = c3.get("artifact_hashes")
    if not isinstance(ah, dict) or set(ah) != set(c3_contract.ARTIFACTS):
        errors.append("artifact_hashes のキーが Plan Package 6 要素と一致しない")
    else:
        for name in c3_contract.ARTIFACTS:
            f = task_dir / name
            if not f.is_file():
                errors.append(f"artifact 欠落: {name}")
            elif ah[name] != c3_contract.sha256_of_file(f):
                errors.append(f"artifact_hashes 不一致: {name}（stale）")
        if c3.get("plan_package_hash") != c3_contract.canonical_hash(ah):
            errors.append("plan_package_hash が artifact_hashes の再計算値と不一致")
    reviewers = c3.get("reviewers")
    if not isinstance(reviewers, dict) or set(reviewers) != {"model_a", "model_b"}:
        errors.append("reviewers は model_a / model_b のちょうど 2 者")
    else:
        errors.extend(c3_contract.check_snapshot_trio(c3, reviewers, strict_keys=True))
    return errors


def verify_c3_prime(task_dir, errors) -> None:
    """契約 §4 全規則の fail-closed 再検証（delivery.verify_c3 を再利用）。"""
    rc, captured = delivery.verify_c3(task_dir)
    if rc == 10:
        errors.append("legacy c3.json（approval_kind 無し）— EV を発行しない")
        return
    if rc == 0:
        return
    if not _decision_only_failure(captured):
        errors.append(f"c3-prime 再検証 NG（fail-closed）: {captured.strip()}")


def load_arbiter_records(runs_dir, errors) -> list:
    """arbiter record（runs_dir/*.json）を読む。破損は理由付きで skip する。"""
    records = []
    if runs_dir is None:
        return records
    path = pathlib.Path(runs_dir)
    if not path.is_dir():
        errors.append(f"--runs-dir が存在しない: {_rel_to_repo(path)}")
        return records
    for f in sorted(path.glob("*.json")):
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
        except (ValueError, OSError):
            continue
        if isinstance(data, dict):
            records.append(data)
    return records


# ---------------------------------------------------------------------------
# legacy 互換（AC-15）
# ---------------------------------------------------------------------------

def _has_valid_run_id(run_meta) -> bool:
    """run メタが非空文字列の run_id を持つか（metrics.py の同名判定の転写）。"""
    if not isinstance(run_meta, dict):
        return False
    run_id = run_meta.get("run_id")
    return isinstance(run_id, str) and bool(run_id.strip())


def _has_valid_round_index(run_meta) -> bool:
    """round_index が欠落 or 厳密な int か（bool は int のサブクラスだが不正）。"""
    if "round_index" not in run_meta:
        return True
    return type(run_meta["round_index"]) is int


def classify_records(runs_dir) -> dict:
    """arbiter record を legacy / invalid run meta / run record / skipped に分類する。

    metrics.py の `_load_records()` + `collect()` の分類ロジックを**転写**する
    （`metrics.py` は不変対象のため import しない = 依存を増やさない）。

    - `total_records`: metrics.py と同じ定義（3 分類の合計）。同値性の照合に使う
    - `loaded_records`: ファイルから読めた record 数の**独立カウント**。
      これが無いと `total_records` の恒等式が右辺と同式になり空振りする
    - `skipped[].file`: **repo 相対パスへ正規化**する（metrics.py の `skipped` は
      絶対パスになりうるが、キー名が `file` のため EH-8 では捕捉されない）
    """
    path = pathlib.Path(runs_dir)
    loaded = []
    skipped = []
    for f in sorted(path.glob("*.json")):
        rel = _rel_to_repo(f)
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            skipped.append({"file": rel, "reason": f"JSON parse error: {exc}"})
            continue
        if not isinstance(data, dict):
            skipped.append({"file": rel,
                            "reason": "top-level JSON value is not an object"})
            continue
        if "decision" not in data:
            skipped.append({"file": rel,
                            "reason": "missing required key 'decision'"})
            continue
        loaded.append((rel, data))

    legacy_records, invalid_meta_records, run_records = [], [], []
    round_index_skipped = 0
    for rel, record in loaded:
        if "run" not in record:
            legacy_records.append(record)
            continue
        if not _has_valid_run_id(record.get("run")):
            invalid_meta_records.append(record)
            continue
        if not _has_valid_round_index(record["run"]):
            bad = record["run"]["round_index"]
            skipped.append({
                "file": rel,
                "reason": (f"invalid round_index type: {type(bad).__name__} "
                           f"({bad!r}) — int のみ許容")})
            round_index_skipped += 1
            continue
        run_records.append(record)

    run_ids = {r["run"]["run_id"] for r in run_records}
    return {
        "total_records": (len(legacy_records) + len(invalid_meta_records)
                          + len(run_records)),
        "loaded_records": len(loaded),
        "round_index_skipped": round_index_skipped,
        "legacy_count": len(legacy_records),
        "invalid_run_meta_count": len(invalid_meta_records),
        "run_count": len(run_ids),
        "skipped_count": len(skipped),
        "legacy_records": legacy_records,
        "invalid_meta_records": invalid_meta_records,
        "run_records": run_records,
        "skipped": skipped,
    }


# ---------------------------------------------------------------------------
# 派生（delivery 層 / c3-prime 層 → RunEvidence）
# ---------------------------------------------------------------------------

def derive_terminal_state(decision, entries, record_exists, errors):
    """契約 §4 の正規化マッピング（MERGE_READY は物理存在のみが条件）。"""
    states = [e for e in entries if e.get("kind") == "state"]
    last_state = states[-1].get("state") if states else None
    if decision == "BLOCKED":
        return "BLOCKED", last_state
    if decision == "HUMAN_ESCALATED" or last_state == "HUMAN_ESCALATED":
        return "HUMAN_ESCALATED", last_state
    if any(e.get("kind") == "merge_ready" for e in entries):
        return "MERGE_READY", last_state
    errors.append(
        "非終端 run は RunEvidence を発行しない"
        f"（state={last_state or 'なし'} / kind=merge_ready entry なし"
        f" / record.jsonl={'あり' if record_exists else 'なし'}）"
        f"。非終端 7 状態: {', '.join(NON_TERMINAL_STATES)}")
    return None, last_state


def _merge_ready_record(entries) -> dict:
    mr = [e for e in entries if e.get("kind") == "merge_ready"]
    record = mr[-1].get("record") if mr else None
    return record if isinstance(record, dict) else {}


def derive_delivery_fields(entries, record_exists, injected_pr, errors) -> dict:
    """final_head_sha / ci_outcomes / review_findings / repair_rounds を導出する。

    PR 番号は **kind=merge_ready entry の record.pr_number からのみ**解決する。
    注入 --pr-number は cross-check 専用であり、注入だけを根拠に実値化しない
    （受理器は record からしか再計算できず、実値化すると生成側の自己申告を
    信頼する構造になる = 契約 §6-2 の trust boundary）。
    """
    out = {f: UNAVAILABLE for f in
           ("final_head_sha", "ci_outcomes", "review_findings", "repair_rounds")}
    if not record_exists:
        return out

    mr_record = _merge_ready_record(entries)
    states = [e for e in entries if e.get("kind") == "state"]
    head = mr_record.get("head_sha")
    if head is None and states:
        head = states[-1].get("head_sha")
    if isinstance(head, str) and _COMMIT.fullmatch(head):
        out["final_head_sha"] = head
    elif head is not None:
        errors.append(f"final_head_sha が commit SHA 形式でない: {head!r}")

    pr = mr_record.get("pr_number")
    if injected_pr is not None and pr is not None and injected_pr != pr:
        errors.append(
            f"--pr-number({injected_pr}) が record の pr_number({pr}) と不一致")
    if pr is None:
        return out

    checks = mr_record.get("check_summary")
    if isinstance(checks, dict):
        out["ci_outcomes"] = [{"name": k, "conclusion": str(checks[k])}
                              for k in sorted(checks)]
    disposition = mr_record.get("review_disposition")
    if isinstance(disposition, dict):
        findings = [{"id": k, "disposition": str(disposition[k])}
                    for k in sorted(disposition)]
        seen = {f["id"] for f in findings}
        for ft in sorted({e.get("finding_type") for e in entries
                          if e.get("kind") == "receipt"
                          and e.get("action_kind") == "repair_review"
                          and e.get("finding_type")}):
            if ft not in seen:
                findings.append({"id": ft, "disposition": "repaired"})
        out["review_findings"] = findings
    out["repair_rounds"] = delivery._completed_rounds(entries, pr)
    return out


def derive_human_interventions(decision, entries, arbiter_records, run_id, escalation):
    """c3-prime 層 + delivery 層 + arbiter record からの介入痕跡を集約する。"""
    items = []
    if decision in ("HUMAN_ESCALATED", "BLOCKED"):
        items.append({"kind": "c3_prime_decision", "detail": decision})
    for e in entries:
        if e.get("kind") == "state" and e.get("state") == "HUMAN_ESCALATED":
            items.append({"kind": "delivery_state", "detail": "HUMAN_ESCALATED"})
        if e.get("kind") not in KNOWN_RECORD_KINDS:
            detail = _redact(e.get("comment_url") or "", escalation)
            items.append({"kind": "record_notice", "detail": detail})
    for rec in arbiter_records:
        run = rec.get("run")
        if not isinstance(run, dict) or run.get("run_id") != run_id:
            continue
        if rec.get("decision") == "HUMAN_ESCALATED":
            items.append({"kind": "arbiter_decision", "detail": "HUMAN_ESCALATED"})
    return items


def derive_quality_metrics(terminal_state, repair_rounds):
    """当該 run の events だけで閉じる指標のみ（corpus 集計値は禁止 / 契約 §3-3）。"""
    if repair_rounds == UNAVAILABLE:
        return UNAVAILABLE
    return {
        "first_pass": terminal_state == "MERGE_READY" and repair_rounds == 0,
        "rounds": repair_rounds + 1,
    }


def derive_observation(terminal_state, delivery_fields, entries, unknown_kinds,
                       escalation):
    """観測事実のみ（推定を混ぜない / AC-5）。入力由来の文字列は還元して載せる。"""
    parts = [f"terminal_state={terminal_state}",
             f"repair_rounds={delivery_fields['repair_rounds']}"]
    reasons = sorted({_redact(r, escalation) for e in entries
                      if e.get("kind") == "state"
                      for r in (e.get("reasons") or [])})
    if reasons:
        parts.append("reasons=" + ",".join(reasons))
    if unknown_kinds:
        parts.append("unknown_record_kinds=" + ",".join(sorted(unknown_kinds)))
    return "; ".join(parts)


# ---------------------------------------------------------------------------
# 組み立て
# ---------------------------------------------------------------------------

def _require_injected(opts, errors):
    """fail-closed な注入値（契約 §3-2）。--pr-number だけは unavailable に倒す。"""
    for flag, pattern, label in (
        ("now", _ISO_UTC, "ISO 8601 UTC"),
        ("started-at", _ISO_UTC, "ISO 8601 UTC"),
    ):
        value = opts.get(flag)
        if not value:
            errors.append(f"--{flag} は必須（注入値。時刻を内部参照しない）")
        elif not pattern.fullmatch(value):
            errors.append(f"--{flag} が {label} でない: {value!r}")
    repository = opts.get("repository")
    if not repository:
        errors.append("--repository は必須（注入値。git remote を呼ばない）")
    elif "/" in repository:
        errors.append(
            f"--repository は owner 除去済み repo 名: {repository!r}（契約 §7-3）")
    if not opts.get("run-id"):
        errors.append("--run-id は必須（注入値）")


def _parse_harness(opts, errors):
    """harness_version（object 3 値）の注入と run 中不変（AC-12）を検査する。"""
    raw = opts.get("harness-version")
    if not raw:
        errors.append("--harness-version は必須（object 3 値の注入 / 契約 §4-1）")
        return UNAVAILABLE
    try:
        start = json.loads(raw)
    except ValueError as exc:
        errors.append(f"--harness-version が JSON でない: {exc}")
        return UNAVAILABLE
    keys = {"plugin_version", "cli_version", "corpus_hash"}
    if not isinstance(start, dict) or set(start) != keys:
        errors.append(f"--harness-version は {sorted(keys)} の 3 値 object")
        return UNAVAILABLE
    if not _SHA256.fullmatch(str(start["corpus_hash"])):
        errors.append(
            f"harness_version.corpus_hash が sha256:+64hex でない: "
            f"{start['corpus_hash']!r}")
    raw_end = opts.get("harness-version-end")
    if raw_end:
        try:
            end = json.loads(raw_end)
        except ValueError as exc:
            errors.append(f"--harness-version-end が JSON でない: {exc}")
            return start
        for key in sorted(keys):
            if start.get(key) != (end or {}).get(key):
                errors.append(
                    f"harness_version が run 中に変化した（fail-closed）: "
                    f"{key} 開始時={start.get(key)!r} 終了時={(end or {}).get(key)!r}")
    return start


def _parse_routing(opts, errors):
    """未供給 = unavailable / 明示 [] = 空配列（両者を同値にしない / TC-52）。"""
    raw = opts.get("routing-decisions")
    if raw is None:
        return UNAVAILABLE
    try:
        value = json.loads(raw)
    except ValueError as exc:
        errors.append(f"--routing-decisions が JSON でない: {exc}")
        return UNAVAILABLE
    if not isinstance(value, list):
        errors.append("--routing-decisions は array")
        return UNAVAILABLE
    return value


def _parse_pr_number(opts, errors):
    raw = opts.get("pr-number")
    if raw is None:
        return None
    if not re.fullmatch(r"[0-9]+", str(raw)):
        errors.append(f"--pr-number が整数でない: {raw!r}")
        return None
    return int(raw)


def _evidence_refs(opts, task_dir, record_exists, errors):
    """注入値と record 由来のみ。ディスク走査で列挙しない（契約 §3-3）。"""
    refs = {_rel_to_repo(task_dir / "approvals" / "c3.json")}
    if record_exists:
        refs.add(_rel_to_repo(delivery.record_path(task_dir)))
    for ref in opts.get("evidence-ref") or []:
        if not ref:
            errors.append("--evidence-ref が空")
            continue
        if ref.startswith("/") or "/Users/" in ref:
            errors.append(f"--evidence-ref が絶対パス: {ref!r}（契約 §7-2）")
            continue
        refs.add(ref)
    return sorted(refs)


def build(task_dir, opts) -> dict:
    """RunEvidence を組み立てる。判定不能・不整合は RunEvidenceError で全件返す。"""
    task_dir = pathlib.Path(task_dir)
    errors = []
    escalation = []

    _require_injected(opts, errors)
    harness = _parse_harness(opts, errors)
    routing = _parse_routing(opts, errors)
    injected_pr = _parse_pr_number(opts, errors)

    if not task_dir.is_dir():
        errors.append(f"task_dir が存在しない: {_rel_to_repo(task_dir)}")
        raise RunEvidenceError(errors)

    verify_c3_prime(task_dir, errors)
    c3 = _load_c3(task_dir, errors)
    if c3 is None:
        raise RunEvidenceError(errors)
    decision = c3.get("decision")
    if decision not in c3_contract.VALID_DECISIONS:
        errors.append(f"decision が契約の 3 値以外: {decision!r}")
        raise RunEvidenceError(errors)
    if decision != "AUTO_APPROVED":
        # c3prime_verify が decision で return したため後段の束縛が未検証。
        errors.extend(_recheck_bindings(task_dir, c3))

    task_id = str(c3.get("task_id", ""))
    if not _TASK_ID.fullmatch(task_id):
        errors.append(f"task_id が TASK-XXXX 形式でない: {task_id!r}")
    elif task_dir.name != task_id:
        errors.append(f"task_id ({task_id}) が task_dir 名 ({task_dir.name}) と不一致")

    record_file = delivery.record_path(task_dir)
    record_exists = record_file.is_file()
    try:
        entries = delivery.load_entries(record_file)
    except delivery.RecordError as exc:
        errors.append(f"delivery/record.jsonl の再計算照合に失敗（fail-closed）: {exc}")
        raise RunEvidenceError(errors)

    unknown_kinds = {str(e.get("kind")) for e in entries
                     if e.get("kind") not in KNOWN_RECORD_KINDS}
    for kind in sorted(unknown_kinds):
        escalation.append({"kind": "unknown_record_kind", "detail": kind})
    escalation.extend(scan_input_privacy(entries, "record.jsonl"))
    escalation.extend(scan_input_privacy(c3, "c3.json"))

    arbiter_records = load_arbiter_records(opts.get("runs-dir"), errors)
    escalation.extend(scan_input_privacy(arbiter_records, "arbiter-record"))

    terminal_state, _last = derive_terminal_state(
        decision, entries, record_exists, errors)
    delivery_fields = derive_delivery_fields(
        entries, record_exists, injected_pr, errors)
    if errors:
        raise RunEvidenceError(errors)

    run_id = opts["run-id"]
    record = {
        "run_id": run_id,
        "task_id": task_id,
        "started_at": opts["started-at"],
        "completed_at": opts["now"],
        "repository": opts["repository"],
        "source_sha": c3["source_sha"],
        "final_head_sha": delivery_fields["final_head_sha"],
        "plan_hash": c3["plan_hash"],
        "c3_prime_decision_ref": {
            "path": _rel_to_repo(task_dir / "approvals" / "c3.json"),
            "plan_package_hash": c3.get("plan_package_hash"),
        },
        "harness_version": harness,
        "routing_decisions": routing,
        "ci_outcomes": delivery_fields["ci_outcomes"],
        "review_findings": delivery_fields["review_findings"],
        "repair_rounds": delivery_fields["repair_rounds"],
        "replan_count": UNAVAILABLE,
        "human_interventions": derive_human_interventions(
            decision, entries, arbiter_records, run_id, escalation),
        "terminal_state": terminal_state,
        "quality_metrics": derive_quality_metrics(
            terminal_state, delivery_fields["repair_rounds"]),
        "cost_metrics": UNAVAILABLE,
        "evidence_refs": _evidence_refs(opts, task_dir, record_exists, errors),
        "schema_version": SCHEMA_VERSION,
        "observation": _redact(opts["observation"], escalation)
        if opts.get("observation") else derive_observation(
            terminal_state, delivery_fields, entries, unknown_kinds, escalation),
        # 推定は自動生成しない（AC-5）。注入されたときのみ格納する。
        "cause_hypothesis": opts.get("cause-hypothesis"),
        "escalation": sorted(
            {(e["kind"], e["detail"]) for e in escalation},
            key=lambda pair: pair),
    }
    record["escalation"] = [{"kind": k, "detail": d} for k, d in record["escalation"]]

    if set(record) != set(OUTPUT_KEYS):
        errors.append(
            f"出力キー集合が契約 §2 と不一致: "
            f"余剰={sorted(set(record) - set(OUTPUT_KEYS))} "
            f"欠落={sorted(set(OUTPUT_KEYS) - set(record))}")
    errors.extend(check_output_privacy(record))
    if errors:
        raise RunEvidenceError(errors)
    return record


# ---------------------------------------------------------------------------
# 下流 adapter（provenance の橋渡しのみ。clustering / decision table は作らない）
# ---------------------------------------------------------------------------

#: shadow candidate を作るために必要な同型 run の最小件数（契約 §8-1）。
MIN_EVIDENCE_RUNS = 3

#: improvement TASK 記述子のキー allowlist（迂回フラグを構造的に持たせない）。
IMPROVEMENT_TASK_KEYS = (
    "task_kind", "candidate_id", "source_run_ids",
    "plan_package_required", "c3_prime_required", "merge_by_ai",
)

_PR_REF = re.compile(r"^[0-9]+$")
_COMMIT_REF = re.compile(r"^[0-9a-f]{7,40}$")


def to_shadow_candidate_input(evidences) -> dict:
    """RunEvidence 群 → shadow candidate 入力（契約 §8-1 / AC-7 / AC-8）。

    **EV 以外の I/O を持たない**（引数が唯一の入力）。clustering は下流の責務で
    あり本 adapter は provenance の橋渡しのみを行う。
    """
    evs = list(evidences)
    if len(evs) < MIN_EVIDENCE_RUNS:
        return {"status": "insufficient_evidence",
                "evidence_count": len(evs),
                "required_evidence_count": MIN_EVIDENCE_RUNS}
    baselines = {c3_contract.canonical_hash(e.get("harness_version")) for e in evs}
    if len(baselines) != 1:
        # baseline が定義できない run 群から候補を作らない。
        return {"status": "mixed_baseline", "evidence_count": len(evs)}
    run_ids = [e.get("run_id") for e in evs]
    baseline_version = evs[0].get("harness_version")
    return {
        "status": "ok",
        "candidate_id": c3_contract.canonical_hash(
            {"source_run_ids": sorted(run_ids), "baseline_version": baseline_version}),
        "source_run_ids": run_ids,
        "baseline_version": baseline_version,
        "observed_pattern": sorted({str(e.get("observation") or "") for e in evs}),
        "cause_hypothesis": sorted({str(e["cause_hypothesis"]) for e in evs
                                    if e.get("cause_hypothesis")}),
    }


def _normalize_improvement_refs(refs) -> list:
    """PR 番号 / commit SHA のみを保持する（URL・絶対パスは reject / 契約 §7-3）。"""
    out = []
    for ref in refs or ():
        text = str(ref)
        if _PR_REF.fullmatch(text):
            out.append({"kind": "pr", "ref": text})
        elif _COMMIT_REF.fullmatch(text):
            out.append({"kind": "commit", "ref": text})
        else:
            raise RunEvidenceError(
                [f"improvement_ref は PR 番号か commit SHA のみ: {text!r}"])
    return out


def to_promotion_provenance(candidate, decision=None, *, improvement_refs=(),
                            promoted_to=None, canary_scope=None) -> dict:
    """candidate + promotion 判断 → Trust Ledger provenance（契約 §8-2）。

    **AC-13 fail-closed**: `blocked_by` が非空、または**キーが物理的に存在しない**
    （未注入 = 判定不能）ときは `BLOCKED`。非 `BLOCKED` と解釈するのは
    **明示的に `[]` を注入した場合のみ**。issue 番号はハードコードしない。
    """
    refs = _normalize_improvement_refs(improvement_refs)
    blocked_by = candidate.get("blocked_by")
    unresolved = "blocked_by" not in candidate or bool(blocked_by)
    final_decision = "BLOCKED" if unresolved else (decision or "BLOCKED")
    return {
        "candidate_id": candidate.get("candidate_id"),
        "decision": final_decision,
        "promoted_to": None if final_decision == "BLOCKED" else promoted_to,
        "evidence_count": len(candidate.get("source_run_ids") or []),
        "canary_scope": canary_scope if canary_scope else UNAVAILABLE,
        "rollback_count": candidate.get("rollback_count", 0),
        "improvement_refs": refs,
        "source_run_ids": list(candidate.get("source_run_ids") or []),
        "blocked_by": list(blocked_by) if isinstance(blocked_by, list) else UNAVAILABLE,
    }


def to_improvement_task_descriptor(candidate) -> dict:
    """candidate 由来 improvement TASK の記述子（AC-9 / 契約 §8-3）。

    通常ゲート（Plan-first / C-3' / PR 収束）を迂回するフラグを構造的に持たない。
    """
    return {
        "task_kind": "improvement",
        "candidate_id": candidate.get("candidate_id"),
        "source_run_ids": list(candidate.get("source_run_ids") or []),
        "plan_package_required": True,
        "c3_prime_required": True,
        "merge_by_ai": False,
    }


def to_paired_replay(candidate, baseline_evidences, candidate_evidences,
                     grader_ref=None, activation_check=None) -> dict:
    """baseline / candidate の paired replay 橋渡し（AC-10 / 契約 §8）。"""
    baseline_ids = [e.get("run_id") for e in baseline_evidences]
    candidate_ids = [e.get("run_id") for e in candidate_evidences]
    overlap = sorted(set(baseline_ids) & set(candidate_ids))
    if overlap:
        return {"status": "overlapping_runs", "overlap": overlap,
                "candidate_id": candidate.get("candidate_id")}
    return {
        "status": "ok",
        "candidate_id": candidate.get("candidate_id"),
        "baseline_run_ids": baseline_ids,
        "candidate_run_ids": candidate_ids,
        "grader_ref": grader_ref if grader_ref else UNAVAILABLE,
        "activation_check": activation_check if activation_check else UNAVAILABLE,
    }


def apply_canary_rollback(candidate, canary_result) -> dict:
    """failed canary を source candidate へ戻す（AC-10 / AC-13）。純関数（入力不変）。"""
    updated = dict(candidate)
    if (canary_result or {}).get("result") == "failed":
        updated["status"] = "rolled_back"
        updated["rollback_count"] = int(candidate.get("rollback_count", 0)) + 1
        updated["canary_scope"] = (canary_result or {}).get("canary_scope", UNAVAILABLE)
    return updated


def main(argv):
    opts = _parse_kv(argv[1:])
    positional = opts.get("_positional") or []
    if len(positional) != 1:
        print("usage: run_evidence.py <task_dir> --now <ISO> --started-at <ISO> "
              "--repository <name> --run-id <id> --harness-version <json> "
              "[--pr-number <n>] [--runs-dir <dir>] [--out <path.json>]",
              file=sys.stderr)
        return 1
    out_path = opts.get("out")
    if out_path is not None and not str(out_path).endswith(".json"):
        print("run-evidence: --out の拡張子は .json 固定"
              "（.jsonl は EH-8 の走査対象から外れる / 契約 §7-4）", file=sys.stderr)
        return 1
    try:
        record = build(positional[0], opts)
    except RunEvidenceError as exc:
        for line in exc.errors:
            print(f"run-evidence: {line}", file=sys.stderr)
        return 1
    text = serialize(record)
    if out_path:
        path = pathlib.Path(out_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
