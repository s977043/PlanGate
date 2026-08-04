#!/usr/bin/env python3
"""RunEvidence 受理検証（TASK-0874 / #874）。

契約正本: docs/workflows/ai-loop/run-evidence-contract.md §6。
schema:   docs/schemas/run-evidence.schema.json（**唯一の正**。必須キー・許可キー・
          型 / enum / pattern は本スクリプトにハードコードせず schema から導出する）。

trust boundary: 生成側（run_evidence.py）の申告を信頼せず、受理側が
<task_dir> の approvals/c3.json と delivery/record.jsonl を**再読込して照合**する
（c3-prime-contract.md §7 の転写）。EV 単体入力にしないのはこのため
（sha256:+64hex の形式を保った 1 文字改変は EV 単体では検出できない）。
照合は「c3.json 由来の 2 値」に留めず、**delivery 層の派生値・terminal_state・
privacy も受理側で再導出**する（producer の純関数を import して再実装しない）。

使い方: run_evidence_verify.py <ev.json> <task_dir>
  exit 0  = RunEvidence として受理（evidence_status=complete・全束縛整合）
  exit 1  = 検証 NG（fail-closed。理由を stderr に出力）
  exit 2  = **起動不能**（schema を読めない = 検査自体が実行できていない）。
            NG（exit 1）と区別する: 1 に混ぜると「改竄兆候」と「同梱漏れ」を
            呼び出し側が判別できない（契約 §6-4）
  exit 10 = legacy（EV ではなく arbiter record を渡された）→ 呼び出し側が legacy 経路へ委譲
            ※ 値・意味は c3prime_verify.py の `return 10  # legacy` と同一
  exit 11 = partial（必須フィールドは揃うが unavailable、または「検査そのものが未実行」
            を示す escalation（harness_drift_unchecked / 契約 §4-1）を含む = ready 扱いしない）

⚠️ 本受理器の rc を bin/plangate の _plangate_c3_dispatch 経路へ流してはならない
（同経路は 0/1 以外を catch-all で legacy にフォールバックするため 2 / 11 を誤読する）。
"""
from __future__ import annotations

import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
REPO_ROOT = HERE.parent.parent

#: schema の探索順（先に見つかったものを使う）。
#: 1 本目は repo レイアウト（scripts/ai-loop/ → <repo>/docs/schemas/）。
#: 2 本目は plugin の bundled resources レイアウト
#: （skills/ai-loop-cycle/scripts/ → skills/ai-loop-cycle/schemas/）。
#: 1 本目だけだと導入先 plugin で `skills/docs/schemas/` を指して**常に起動不能**に
#: なる（R1 major M-4。実測 exit 1 + stderr に絶対パス）。
SCHEMA_NAME = "run-evidence.schema.json"
SCHEMA_CANDIDATES = (
    REPO_ROOT / "docs" / "schemas" / SCHEMA_NAME,
    HERE.parent / "schemas" / SCHEMA_NAME,
)


def _resolve_schema_path():
    for candidate in SCHEMA_CANDIDATES:
        if candidate.is_file():
            return candidate
    return SCHEMA_CANDIDATES[0]


SCHEMA_PATH = _resolve_schema_path()

sys.path.insert(0, str(HERE))
import delivery  # noqa: E402  record.jsonl の再計算照合を再実装しない
import run_evidence  # noqa: E402  派生 / privacy 検査の純関数を再実装しない

#: 「取得不能」を表す唯一の語彙。0 とも空配列とも区別する（契約 §5-1）。
UNAVAILABLE = run_evidence.UNAVAILABLE

#: 「検証していない」ことを表す escalation kind（契約 §4-1）。
#: 検査済み EV と未検査 EV を受理側が区別できなければ AC-12 は caller の善意に
#: 依存する。未検査は complete にせず partial 理由として列挙する。
UNVERIFIED_ESCALATION_KINDS = ("harness_drift_unchecked",)

#: legacy 判別子: arbiter record（9 キー世代 / 14 キー世代）の共通キー集合（実測）。
#: EV の properties とは 1 キーも重複しないため、EV から必須キーが欠落しても
#: legacy には落ちない（欠落は exit 1 のまま = fail-closed）。
ARBITER_MARKER_KEYS = frozenset((
    "boundary_check", "class_check", "decision", "issued_by", "lite_check",
    "policy_ref", "target_sha", "timestamp", "w_check",
))

#: 受理器が record.jsonl から再導出する delivery 層フィールド（契約 §6-2）。
DELIVERY_FIELDS = ("final_head_sha", "ci_outcomes", "review_findings", "repair_rounds")

#: schema 起動不能の exit code（NG と区別する / 契約 §6-4）。
EXIT_SCHEMA_UNAVAILABLE = 2

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


# ---------------------------------------------------------------------------
# schema 構造検証（type / enum / pattern / minLength / minimum）
# ---------------------------------------------------------------------------
#
# 契約 §6-3 は「schema を唯一の正として読む」と規定するが、キー名だけを取り出す
# 実装では schema の `type` / `enum` / `pattern` / `minLength` が **どの層からも
# 強制されない**（R1 major M-5）。`.github/workflows/schema-validate.yml` は
# `docs/schemas/**` を対象外にしており、jsonschema を使う唯一の test は未導入環境で
# skip される。したがって受理器が本 subset validator で強制する。
#
# 対応語彙は本 schema が実際に使う範囲に限定する（未知キーワードは無視ではなく
# 「解釈できない = 検査していない」を避けるため、下の _UNSUPPORTED で検出して NG）。
_SUPPORTED_KEYWORDS = frozenset((
    "$ref", "$schema", "$id", "$defs", "title", "description",
    "type", "enum", "const", "pattern", "minLength", "minimum",
    "required", "properties", "additionalProperties", "patternProperties",
    "items", "anyOf",
))

#: 対応する JSON Schema の `type` 語彙。
_TYPE_NAMES = ("object", "array", "string", "boolean", "null", "integer", "number")


def _matches_type(name, value) -> bool:
    """JSON Schema の `type` 判定（dict + 添字呼び出しにしない = INDIRECT_EXEC 回避）。"""
    if name == "object":
        return isinstance(value, dict)
    if name == "array":
        return isinstance(value, list)
    if name == "string":
        return isinstance(value, str)
    if name == "boolean":
        return isinstance(value, bool)
    if name == "null":
        return value is None
    # bool は int のサブクラスだが JSON Schema では integer / number ではない。
    if name == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if name == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    return False


def _deref(node, root):
    seen = 0
    while isinstance(node, dict) and "$ref" in node:
        ref = node["$ref"]
        if not str(ref).startswith("#/$defs/"):
            raise ValueError(f"未対応の $ref: {ref!r}")
        node = root["$defs"][str(ref).split("/")[-1]]
        seen += 1
        if seen > 8:
            raise ValueError("$ref が循環している")
    return node


def _check_node(node, value, path, root) -> list:
    """1 ノードを検証して理由リストを返す（純関数・呼び出し側の状態を持たない）。"""
    try:
        node = _deref(node, root)
    except ValueError as exc:
        return [f"{path or '<root>'}: schema を解釈できない（{exc}）"]
    if not isinstance(node, dict):
        return [f"{path or '<root>'}: schema ノードが object でない"]
    unsupported = sorted(set(node) - _SUPPORTED_KEYWORDS)
    if unsupported:
        return [f"{path or '<root>'}: 未対応の schema キーワード {unsupported}"
                "（検査できないため fail-closed）"]

    if "anyOf" in node:
        for branch in node["anyOf"]:
            if not _check_node(branch, value, path, root):
                return []
        return [f"{path or '<root>'}: anyOf のどの分岐にも適合しない（値={value!r}）"]

    errors = []
    types = node.get("type")
    if types is not None:
        wanted = types if isinstance(types, list) else [types]
        unknown_types = [n for n in wanted if n not in _TYPE_NAMES]
        if unknown_types:
            return [f"{path or '<root>'}: 未対応の type {unknown_types}"]
        if not any(_matches_type(n, value) for n in wanted):
            return [f"{path or '<root>'}: type が {wanted} でない（値={value!r}）"]
    if "const" in node and value != node["const"]:
        return [f"{path or '<root>'}: const {node['const']!r} と不一致（値={value!r}）"]
    if "enum" in node and value not in node["enum"]:
        return [f"{path or '<root>'}: enum {node['enum']} 以外（値={value!r}）"]
    if isinstance(value, str):
        pattern = node.get("pattern")
        if pattern is not None and not re.search(pattern, value):
            return [f"{path or '<root>'}: pattern {pattern!r} に適合しない（値={value!r}）"]
        if "minLength" in node and len(value) < node["minLength"]:
            return [f"{path or '<root>'}: minLength {node['minLength']} 未満（値={value!r}）"]
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if "minimum" in node and value < node["minimum"]:
            return [f"{path or '<root>'}: minimum {node['minimum']} 未満（値={value!r}）"]
    if isinstance(value, dict):
        for key in node.get("required", ()):
            if key not in value:
                errors.append(f"{path}.{key}".lstrip(".") + ": 必須キーが無い")
        props = node.get("properties", {})
        patterns = node.get("patternProperties", {})
        for key in sorted(value):
            child = f"{path}.{key}" if path else key
            if key in props:
                errors.extend(_check_node(props[key], value[key], child, root))
                continue
            matched = sorted(p for p in patterns if re.search(p, key))
            if matched:
                for p in matched:
                    errors.extend(_check_node(patterns[p], value[key], child, root))
                continue
            if node.get("additionalProperties") is False:
                errors.append(f"{child}: additionalProperties=false で未登録")
    if isinstance(value, list) and "items" in node:
        for i, item in enumerate(value):
            errors.extend(_check_node(node["items"], item, f"{path}[{i}]", root))
    return errors


def validate_against_schema(data, schema=None) -> list:
    """schema（本 repo が使う subset）に対する構造検証。理由リストを返す。

    空リスト = OK。**未対応キーワードを黙って無視しない**（無視すると「検査した」と
    「検査できていない」が区別できなくなる = 本 PBI が最も避ける失敗様式）。
    """
    root = schema if schema is not None else _schema()
    return _check_node(root, data, "", root)


# ---------------------------------------------------------------------------
# partial 理由の列挙
# ---------------------------------------------------------------------------

def _unavailable_paths(data: dict) -> list:
    """unavailable の位置を dotted path で**全数**列挙する（契約 §5-1）。

    partial の理由は (a) Phase 1 固定 3 件と (b) terminal_state 依存 最大 5 件の
    2 分類（+ §4-1 の未検証 escalation）にまたがる。曖昧化しない担保は
    「理由が 1 種類であること」ではなく「理由が機械可読に全数列挙されること」に置く。

    ⚠️ 走査は **list 内・任意の深さまで**降りる（R1 minor m-1）。深さ 1 の dict まで
    しか見ないと `ci_outcomes[0].conclusion = "unavailable"` のような入れ子が
    partial にならず **exit 0（complete）で通る**。producer の `_walk` を再利用する。
    """
    return sorted({path for path, _key, value in run_evidence._walk(data)
                   if value == UNAVAILABLE})


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


# ---------------------------------------------------------------------------
# 束縛の再検証
# ---------------------------------------------------------------------------

def _load_c3(task_dir: pathlib.Path):
    """approvals/c3.json を読む。(dict, None) または (None, 理由) を返す。"""
    c3_path = task_dir / "approvals" / "c3.json"
    if not c3_path.is_file():
        return None, f"approvals/c3.json が存在しない: {c3_path}"
    try:
        c3 = json.loads(c3_path.read_text(encoding="utf-8"))
    except (ValueError, OSError) as exc:
        return None, f"approvals/c3.json を strict JSON として読めない: {exc}"
    if not isinstance(c3, dict):
        return None, "approvals/c3.json が JSON object でない"
    return c3, None


def _check_c3_binding(data: dict, task_dir: pathlib.Path, c3: dict):
    """approvals/c3.json との束縛を再検証する。エラー文字列 or None を返す。"""
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


def _check_record_binding(data: dict, task_dir: pathlib.Path, c3: dict):
    """delivery/record.jsonl の再導出値との束縛を検証する。

    再導出は **producer の純関数を import** して行う（`delivery._completed_rounds` を
    再実装しないのと同じ理由。受理器が別実装を持つと producer と drift する）。
    入力は `task_dir` 配下の実ファイルのみで、EV の申告値は一切使わない
    ＝ trust boundary は保たれる（契約 §6-2）。

    ⚠️ 従来は final_head_sha / repair_rounds しか照合しておらず、
    `ci_outcomes` / `review_findings` / `quality_metrics` / `terminal_state` は
    **どこからも検証されていなかった**（R1 critical C-1 / major M-3。実測で
    CI 失敗を success に、レビュー指摘を dismissed に、修理 1 回を first_pass=true に
    書き換えた EV が complete で受理された）。`mr_record` / `entries` は本関数が
    既に持っているため **追加 I/O ゼロ**で再導出できる。
    """
    rec_path = delivery.record_path(task_dir)
    record_exists = rec_path.is_file()
    entries = []
    if record_exists:
        try:
            entries = delivery.load_entries(rec_path)
        except Exception as exc:              # delivery.RecordError（entry_id 改竄等）
            return f"delivery/record.jsonl の再計算照合に失敗（fail-closed）: {exc}"

    derive_errors = []
    derived = run_evidence.derive_delivery_fields(
        entries, record_exists, None, derive_errors)
    if derive_errors:
        return ("delivery/record.jsonl から delivery 層フィールドを再導出できない"
                f"（fail-closed）: {'; '.join(derive_errors)}")

    problems = []
    for field in DELIVERY_FIELDS:
        if data[field] != derived[field]:
            problems.append(
                f"{field} が record.jsonl の再導出値と不一致"
                f"（EV={data[field]!r} / 再導出={derived[field]!r}）")

    expected_qm = run_evidence.derive_quality_metrics(
        data.get("terminal_state"), derived["repair_rounds"])
    if data["quality_metrics"] != expected_qm:
        problems.append(
            f"quality_metrics が再導出値と不一致"
            f"（EV={data['quality_metrics']!r} / 再導出={expected_qm!r}）")

    problems.extend(_terminal_state_problems(data, c3, entries, record_exists))
    return "; ".join(problems) if problems else None


def _terminal_state_problems(data, c3, entries, record_exists) -> list:
    """terminal_state を契約 §4 の正規化マッピングで再導出して照合する。

    schema の `enum: [MERGE_READY, HUMAN_ESCALATED, BLOCKED]` は
    `allowed_keys()` / `required_keys()` が**キー名しか取り出さない**ため、
    従来はどこからも強制されていなかった（R1 critical C-1。実測で
    `terminal_state="WAITING_FOR_CHECKS"` の EV が exit 0 で通過）。
    語彙 allowlist だけでなく **record / c3.json 由来の再導出値との一致**まで要求する
    （語彙内であれば `MERGE_READY` を `BLOCKED` と偽装できてしまうため）。
    """
    state = data.get("terminal_state")
    decision = c3.get("decision")
    derive_errors = []
    expected, _last = run_evidence.derive_terminal_state(
        decision, entries, record_exists, derive_errors)
    if expected is None:
        return [f"terminal_state を c3.json / record.jsonl から再導出できない"
                f"（EV={state!r}・非終端 run に EV は発行しない）: "
                + "; ".join(derive_errors)]
    if state != expected:
        return [f"terminal_state が再導出値と不一致"
                f"（EV={state!r} / 再導出={expected!r}・c3.json decision={decision!r}）"]
    return []


def _check_output_privacy(data: dict):
    """producer 側 backstop と**同一の純関数**を受理側でも掛ける（契約 §7-2）。

    契約 §7-2 は「producer 側の検査が唯一の防御線になる」と自認しているが、
    trust boundary の設計としては逆であり、producer を通さず手書きした EV が
    素通りする（R1 critical C-2。実測で owner 付き repository / 絶対パスの
    evidence_refs / escalation.detail の絶対パス / @handle 入り observation が
    いずれも exit 0）。`check_output_privacy()` は純関数なので **import して同じ検査**を
    掛ける（再実装しない）。owner 付き `repository` は schema の
    `pattern: ^[^/]+$` 側で捕捉する。
    """
    errors = run_evidence.check_output_privacy(data)
    if errors:
        return "privacy 違反（契約 §7 / 受理側 backstop）: " + "; ".join(sorted(errors))
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
        schema = _schema()
        allowed = set(schema["properties"])
        required = list(schema["required"])
    except (ValueError, OSError, KeyError) as exc:
        # NG（exit 1）と分ける: 1 に混ぜると「改竄兆候」と「schema 同梱漏れ」を
        # 呼び出し側が判別できない（R1 major M-4）。パスは repo 相対で出す。
        print(f"run-evidence: schema を読めないため検査を実行していない"
              f"（{SCHEMA_PATH.name} / 探索: "
              f"{', '.join(str(c.name) for c in SCHEMA_CANDIDATES)}）: {exc}",
              file=sys.stderr)
        return EXIT_SCHEMA_UNAVAILABLE

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

    schema_errors = validate_against_schema(data, schema)
    if schema_errors:
        return _fail("schema 不適合（type / enum / pattern / minLength）: "
                     + "; ".join(schema_errors))

    task_id = data["task_id"]
    if not isinstance(task_id, str) or not _TASK_ID.fullmatch(task_id):
        return _fail(f"task_id が TASK-XXXX 形式でない: {task_id!r}")
    if task_dir.name != task_id:
        return _fail(f"task_id ({task_id}) が task_dir 名 ({task_dir.name}) と不一致")

    if not _SHA256.fullmatch(str(data["plan_hash"])):
        return _fail(f"plan_hash が sha256:+64hex 形式でない: {data['plan_hash']!r}")
    if not _COMMIT.fullmatch(str(data["source_sha"])):
        return _fail(f"source_sha が commit SHA 形式でない: {data['source_sha']!r}")

    c3, err = _load_c3(task_dir)
    if err:
        return _fail(err)
    err = _check_c3_binding(data, task_dir, c3)
    if err:
        return _fail(err)
    err = _check_record_binding(data, task_dir, c3)
    if err:
        return _fail(err)
    err = _check_output_privacy(data)
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
