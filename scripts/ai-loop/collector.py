#!/usr/bin/env python3
"""collector.py — `delivery.py` へ渡す snapshot の**供給者**（TASK-0917 / #917）。

契約正本: docs/working/TASK-0917/plan.md 論点 D1（`required_checks[]` ⊇ 照合）/
論点 D3（非 GitHub 由来キーの供給経路）/ 「⚠️ 設計を変えた実測: Collector の主経路は
REST GET」。担当 AC: **AC-1**（head SHA 束縛）/ **AC-2**（⊇ 照合）/ **AC-9**（raw
check evidence の同梱と導出照合）。

## なぜ REST GET なのか（設計を変えた実測）

`gh pr view --json statusCheckRollup` は **per-check の sha を持たない**
（キーは `__typename` / `completedAt` / `conclusion` / `detailsUrl` / `name` /
`startedAt` / `status` / `workflowName` のみ）。`latestReviews[].commit.oid` は
**空文字**。したがって AC-1（head SHA 束縛）を満たせない。本モジュールは
`gh_exec` の allowlist が許す **REST GET 4 本のみ**を主経路とする:

  1. `repos/{o}/{r}/pulls/{n}`                      → mergeable / head.sha / base.ref
  2. `repos/{o}/{r}/commits/{head_sha}/check-runs`  → checks[] と AC-9 の raw evidence
  3. `repos/{o}/{r}/pulls/{n}/reviews`              → review（縮約規則 6 点）
  4. `repos/{o}/{r}/rules/branches/{base_ref}`      → required checks（AC-2）

`changed_files` は 4 本ではなく**読み取り系 git allowlist**（`git diff --name-only
<base>...<head>`）で実測する（`gh api` の endpoint allowlist を広げない / R-017）。

## fail-closed の原則

pre-check / 取得の失敗は **snapshot を破棄せず・例外 exit せず**、
`escalation_flags` に理由コードを積んで `assess()` を通す（R-003）。
`record.jsonl` に state entry が残らないと #894 の no-progress 検知と接続できない
ため。唯一の例外は **head SHA が一切解決できない場合**（`CollectorError`）で、
head の無い snapshot は AC-1 の束縛対象そのものを欠くため構成できない
（呼び出し側は `expected_head_sha` を渡すことでこの経路を回避できる）。

## ⚠️ AC-9 の限界（scope 明示）

本モジュールの自己照合がカバーするのは「**Collector が生成した snapshot** の
内部整合」まで。**手作りの snapshot を `delivery.py` へ直接投入する経路は塞がない**
（Phase 1 の信頼境界は解消しきらない）。同じ限界が
`docs/workflows/ai-loop/delivery-state-machine.md` §4 と handoff にも記載される。

## 層の分離（`discovery.py` 慣習）

- **I/O 層**（`IO_LAYER_FUNCTIONS`): `gh_exec` 経由で外部プロセスを呼ぶ関数。
  失敗は `Fetched(value, error)` に包んで返し、例外を上位へ漏らさない。
- **純関数層**（`PURE_LAYER_FUNCTIONS`): raw JSON dict を受け取り snapshot を
  組み立てる。ネットワーク・ファイル・時刻に依存せず決定論（テスト可能）。

NO MERGE BY AI: 本モジュールは読み取りのみで、PR の状態を変える操作を一切行わない。
"""

from __future__ import annotations

import dataclasses
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import c3_contract  # noqa: E402  canonical_hash の単一定義（再実装しない / #896）
import ci_taxonomy  # noqa: E402  AC-8 の供給主体（taxonomy はここでしか作らない）
import delivery  # noqa: E402  enum / record 契約の単一定義（AC-7: 変更しない）
import gh_exec  # noqa: E402  唯一の外部作用境界（allowlist）
import plan_package  # noqa: E402  allowed_paths 抽出の単一実装（D3 (b)）

# ---------------------------------------------------------------------------
# 契約定数
# ---------------------------------------------------------------------------

#: `validate_snapshot()` の必須キー **12**（`conflict_resolution` は任意キーであり
#: 三点が揃うときのみ出力する / R-026。常時出力すると恒久 `CONFLICT` になる）。
REQUIRED_SNAPSHOT_KEYS = (
    "task_id", "pr_number", "head_sha", "source_sha_ancestry", "mergeable",
    "checks", "review", "findings", "changed_files", "allowed_paths",
    "escalation_flags", "dod_evaluated",
)

#: AC-9: check-run の生レスポンスを同梱するキー（`checks[]` の導出元）。
RAW_CHECK_RUNS_KEY = "raw_check_runs"

#: snapshot に載せる required checks の集合（監査用・`delivery.py` は参照しない）。
REQUIRED_CHECKS_KEY = "required_checks"

#: 取得の固定回数リトライ（backoff の既存実装は repo 内に無いため最小限に留める）。
#: `Denied` は再試行しない（allowlist 違反は決して transient ではない）。
FETCH_ATTEMPTS = 2

#: REST の `state` のうち縮約候補から除外するもの（R-018 ③）。
REVIEW_STATE_DISMISSED = "DISMISSED"

#: 承認 / 変更要求の REST 値（縮約規則の分岐に使う）。
REVIEW_STATE_APPROVED = "APPROVED"
REVIEW_STATE_BLOCKING = "CHANGES_REQUESTED"

#: `APPROVED` を候補として受理する投稿者権限（R1 B-7）。これ以外（`CONTRIBUTOR`
#: / `FIRST_TIME_CONTRIBUTOR` / `NONE` / bot / 欠落）の approve は縮約に採らない
#: （外部者の approve で `WAITING_FOR_REVIEW` を抜けさせない fail-closed）。
REVIEW_ELIGIBLE_ASSOCIATIONS = ("OWNER", "MEMBER", "COLLABORATOR")

#: review 該当ゼロのときの値（キー欠落にして `invalid_snapshot` に落とさない / R-018 ⑤）。
REVIEW_STATE_NONE = "none"

#: 全件取得のための per_page（`gh api` allowlist の query 形は 3 桁まで）。
PER_PAGE = 100

#: `findings` の**未供給**を表す番兵（`[]` の明示供給 = 指摘ゼロ と区別する）。
#: `None` を既定にすると「呼び出し側が明示的に None を渡した」ケースと
#: 区別できないため、専用オブジェクトを使う（R1 B-4）。
FINDINGS_UNSUPPLIED = object()

# 理由コード（`escalation_flags` に積む opaque な文字列 / AC-6 の接続点）。
FLAG_PULL_FETCH_FAILED = "pull_fetch_failed"
FLAG_CHECK_RUNS_FETCH_FAILED = "check_runs_fetch_failed"
FLAG_REVIEWS_FETCH_FAILED = "reviews_fetch_failed"
FLAG_REQUIRED_CHECKS_FETCH_FAILED = "required_checks_fetch_failed"
FLAG_REQUIRED_CHECKS_MISSING = "required_checks_missing"
#: required 集合が **空**（ruleset 未設定 / classic protection / required ルール無し）。
#: 空集合に対する ⊇ 照合は自明に成立するため、flag を積まないと「照合が無音で
#: 消える」（R1 B-3）。空は「required が無いこと」の証明ではなく「required を
#: 機械が確認できていないこと」であり fail-closed 側に倒す。
FLAG_REQUIRED_CHECKS_EMPTY = "required_checks_empty"
FLAG_CHANGED_FILES_UNAVAILABLE = "changed_files_unavailable"
#: 取得は成功したが差分が 0 件（PR に差分が無いのは正常状態ではない / R1 B-9）。
#: 封じないと `plan_deviation` が恒久的に不発になる（`allowed_paths` 0 件と対称）。
FLAG_CHANGED_FILES_EMPTY = "changed_files_empty"
#: `findings[]` が **供給されていない**（producer 未接続）。空リストの明示供給
#: （= 指摘ゼロ）とは区別する（R1 B-4）。
FLAG_FINDINGS_UNAVAILABLE = "findings_unavailable"
FLAG_ALLOWED_PATHS_EMPTY = "allowed_paths_empty"
FLAG_RAW_EVIDENCE_MISMATCH = "raw_evidence_mismatch"
FLAG_RAW_EVIDENCE_MISSING = "raw_evidence_missing"
#: raw に存在する head 一致の check-run が `checks[]` から**欠落**している
#: （failure な check-run を削って green に見せる fail-open 方向の改竄 / R1 B-8）。
FLAG_RAW_EVIDENCE_OMITTED = "raw_evidence_omitted"
FLAG_CHECK_RUN_UNPARSABLE = "check_run_unparsable"
FLAG_RECORD_UNREADABLE = "record_unreadable"
#: finding から安定 id を導出できない（本文・位置がすべて空 / R1 B-6）。
FLAG_FINDING_ID_UNDERIVABLE = "finding_id_underivable"
#: 複数 finding が同一 id に潰れている（1 件直すと N 件消える / R1 B-6）。
FLAG_FINDING_ID_COLLISION = "finding_id_collision"

# ---------------------------------------------------------------------------
# finding_type 語彙の**単一定数表**（T-51 / R-034）
# ---------------------------------------------------------------------------
#
# なぜ単一定数表なのか（実測に基づく理由）:
#   `delivery.py:229-231` の `_past_repair_finding_types()` は **receipt 側**の
#   `finding_type` 集合を作り、`delivery.py:304-305` の `recurrence` はそれと
#   **snapshot 側** `findings[]` の `finding_type` の積を取る。両者の語彙が
#   一致しないと積は**常に空**になり `same_type_recurrence`（優先度 3）が
#   恒久 fail-open になる。したがって Collector の変換アダプタ（snapshot 側）と
#   Executor の `repair_review` receipt（receipt 側）は **本表のみ**を参照する。
#   置き場を `collector.py` に固定するのは、新規モジュールを作らず
#   `allowed_paths` を増やさないため（executor.py は本表を import する）。
#
# 語彙の出典: `.claude/rules/review-principles.md` §2 の 5 つのレビュー観点。
# 未知値は **例外にせず** `other` へ倒す（決定論・両側が同じ値へ落ちるため
# 集合積は成立し、fail-open にならない）。

FINDING_TYPE_READABILITY = "readability"
FINDING_TYPE_EXTENSIBILITY = "extensibility"
FINDING_TYPE_PERFORMANCE = "performance"
FINDING_TYPE_SECURITY = "security"
FINDING_TYPE_MAINTAINABILITY = "maintainability"
FINDING_TYPE_OTHER = "other"

#: 正規語彙（この tuple 以外の値を snapshot / receipt に載せない）。
FINDING_TYPE_VOCABULARY = (
    FINDING_TYPE_READABILITY, FINDING_TYPE_EXTENSIBILITY,
    FINDING_TYPE_PERFORMANCE, FINDING_TYPE_SECURITY,
    FINDING_TYPE_MAINTAINABILITY, FINDING_TYPE_OTHER,
)

#: 入力語彙 → 正規語彙の写像（外部レビューアの表記ゆれの吸収）。
#: 短縮形（`sec` 等）は **意図的に載せない**（語彙不一致を alias で隠すと
#: R-034 の検出力そのものが失われるため）。
FINDING_TYPE_ALIASES = {
    "可読性": FINDING_TYPE_READABILITY,
    "拡張性": FINDING_TYPE_EXTENSIBILITY,
    "architecture": FINDING_TYPE_EXTENSIBILITY,
    "design": FINDING_TYPE_EXTENSIBILITY,
    "パフォーマンス": FINDING_TYPE_PERFORMANCE,
    "セキュリティ": FINDING_TYPE_SECURITY,
    "保守性": FINDING_TYPE_MAINTAINABILITY,
    "testing": FINDING_TYPE_MAINTAINABILITY,
    "test": FINDING_TYPE_MAINTAINABILITY,
}

#: `id` の接頭辞（アダプタ生成であることを監査から辿れるようにする）。
FINDING_ID_PREFIX = "F-"

#: `id` に使う canonical hash の桁数（衝突耐性と可読性の折衷）。
FINDING_ID_DIGEST_LEN = 12

#: `id` 導出に使うキー（**severity / disposition を含めない**。severity は
#: run 間で変わりうるため、含めると同一指摘の `id` が run ごとに変化し
#: `_resolved()` の disposition 突合が壊れて `unresolved_hard` が消えなくなる）。
#:
#: 本文・位置は **複数キーを受ける**（`finding_type` と同じ扱い / R1 B-6）。
#: 外部レビューアの実装ごとに `description` / `message` / `title`・`file` /
#: `path` が使われ、単一キーしか読まないと本文・位置が空文字に潰れて
#: **別々の指摘が同一 id になる**（`_resolved()` は id 突合であるため 1 件
#: 直すと N 件消える）。
FINDING_ID_BODY_KEYS = ("finding", "message", "description", "title")
FINDING_ID_LOCATION_KEYS = ("location", "file", "path")

#: 本文・位置が**すべて空**のときに与える id（導出しない目印）。同一値になるため
#: `build_snapshot()` の衝突検出（`FLAG_FINDING_ID_COLLISION`）と併せて
#: 「潰れ」が必ず flag として観測される。
FINDING_ID_UNDERIVABLE = FINDING_ID_PREFIX + "unidentified"

# --- result_ref convention の**最小共有部**（`executor.py` が producer）---------
#
# `executor.py` は `collector.py` を import する（finding_type 定数表）。したがって
# 逆向き（collector → executor）の import は循環になるため張れない。`result_ref`
# の区切りと `evidence` キー名だけを**ここで単一定義**し、`executor.py` 側が
# 本定数を参照する（drift を test で機械照合する / R1 B-1）。
RESULT_REF_SEP = "|"
RESULT_REF_KV = ":"
#: `dod_reevaluate` / `record_disposition` の receipt が実測根拠を載せるキー。
PART_EVIDENCE = "evidence"

#: 未知 severity の丸め先（`docs/ai/external-reviewer-interface.md` §3.2:
#: 「未知 severity は安全側で `major` に丸める」）。
SEVERITY_FALLBACK = "major"

#: I/O 層（`gh_exec` を呼んでよい関数）。テストが AST でこの境界を機械照合する。
IO_LAYER_FUNCTIONS = frozenset({
    "_run_gh_text", "_run_git_text", "fetch_pull", "fetch_check_runs",
    "fetch_reviews", "fetch_required_checks", "fetch_changed_files",
    "fetch_ancestry", "fetch_raw_inputs", "collect",
})

#: 純関数層（raw JSON dict のみを受け取り外部作用を持たない関数）。
PURE_LAYER_FUNCTIONS = frozenset({
    "conclusion_for", "normalize_raw_check_run", "checks_from_raw",
    "reduce_review", "verify_raw_evidence", "verify_snapshot_evidence",
    "missing_required_checks", "normalize_mergeable", "derive_dod_evaluated",
    "extract_allowed_paths", "build_snapshot",
    "normalize_finding_type", "normalize_severity", "finding_id",
    "adapt_finding", "adapt_findings",
    "parse_result_ref_parts", "receipt_evidence_ref", "finding_id_flags",
})


class CollectorError(RuntimeError):
    """snapshot を構成できない唯一のケース（head SHA が解決できない）。"""


# ---------------------------------------------------------------------------
# I/O 層のデータ構造
# ---------------------------------------------------------------------------

@dataclasses.dataclass(frozen=True)
class Fetched:
    """1 回の取得結果。`error` が非 None なら `value` は信用しない（fail-closed）。"""

    value: object = None
    error: str | None = None

    @property
    def ok(self) -> bool:
        return self.error is None


@dataclasses.dataclass(frozen=True)
class RawInputs:
    """純関数層へ渡す生入力一式（GitHub / git から取得したまま）。"""

    head_sha: str | None
    base_ref: str | None
    pull: Fetched = Fetched()
    check_runs: Fetched = Fetched()
    reviews: Fetched = Fetched()
    required_checks: Fetched = Fetched()
    changed_files: Fetched = Fetched()
    ancestry: Fetched = Fetched()


# ---------------------------------------------------------------------------
# I/O 層（`gh_exec` を呼ぶ唯一の場所）
# ---------------------------------------------------------------------------

def _reason(text, limit: int = 120) -> str:
    """理由コードの詳細部を 1 行に畳む（flags は文字列のリストであるため）。"""
    if not isinstance(text, str):
        text = str(text)
    folded = " ".join(text.split())
    return folded[:limit] if folded else "unknown"


def _run_gh_text(gh, args, *, repo, cwd, attempts=FETCH_ATTEMPTS):
    """`gh` を実行して stdout を返す。失敗は `(None, reason)`。"""
    last = "unknown"
    for _ in range(max(1, attempts)):
        try:
            proc = gh.run_gh(list(args), repo=repo, cwd=cwd)
        except gh_exec.Denied as exc:
            return None, f"denied:{exc.reason}"
        except Exception as exc:  # timeout / 実行不能 = transient 扱いで retry
            last = f"exec_error:{type(exc).__name__}"
            continue
        if proc.returncode != 0:
            return None, f"rc={proc.returncode}:{_reason(proc.stderr)}"
        return proc.stdout, None
    return None, last


def _run_git_text(gh, args, *, cwd, attempts=FETCH_ATTEMPTS):
    """読み取り系 `git` を実行して `(stdout, returncode, reason)` を返す。"""
    last = "unknown"
    for _ in range(max(1, attempts)):
        try:
            proc = gh.run_git(list(args), cwd=cwd)
        except gh_exec.Denied as exc:
            return None, None, f"denied:{exc.reason}"
        except Exception as exc:
            last = f"exec_error:{type(exc).__name__}"
            continue
        return proc.stdout, proc.returncode, None
    return None, None, last


def _parse_json_stream(text):
    """`--paginate` が連結出力する複数 JSON 値を順に取り出す。"""
    decoder = json.JSONDecoder()
    values = []
    index, total = 0, len(text or "")
    while index < total:
        while index < total and text[index].isspace():
            index += 1
        if index >= total:
            break
        value, index = decoder.raw_decode(text, index)
        values.append(value)
    if not values:
        raise ValueError("空レスポンス")
    return values


def _api_get(gh, endpoint, *, repo, cwd, paginate=True):
    """`gh api <endpoint>` の GET を実行し、JSON 値のリストを返す。"""
    args = ["api", endpoint]
    if paginate:
        args.append("--paginate")
    stdout, error = _run_gh_text(gh, args, repo=repo, cwd=cwd)
    if error is not None:
        return None, error
    try:
        return _parse_json_stream(stdout), None
    except ValueError as exc:
        return None, f"unparsable_json:{_reason(exc)}"


def fetch_pull(gh, *, repo, pr_number, cwd=None) -> Fetched:
    """`repos/{o}/{r}/pulls/{n}` → `mergeable` / `head.sha` / `base.ref`。"""
    values, error = _api_get(gh, f"repos/{repo}/pulls/{int(pr_number)}",
                             repo=repo, cwd=cwd, paginate=False)
    if error is not None:
        return Fetched(None, error)
    pull = values[0]
    if not isinstance(pull, dict):
        return Fetched(None, "unexpected_shape:pull")
    return Fetched(pull)


def fetch_check_runs(gh, *, repo, head_sha, cwd=None) -> Fetched:
    """`repos/{o}/{r}/commits/{head_sha}/check-runs` → check-run の生配列。"""
    endpoint = (f"repos/{repo}/commits/{head_sha}/check-runs"
                f"?per_page={PER_PAGE}")
    values, error = _api_get(gh, endpoint, repo=repo, cwd=cwd)
    if error is not None:
        return Fetched(None, error)
    runs = []
    for page in values:
        if not isinstance(page, dict) or not isinstance(page.get("check_runs"), list):
            return Fetched(None, "unexpected_shape:check_runs")
        runs.extend(page["check_runs"])
    return Fetched(runs)


def fetch_reviews(gh, *, repo, pr_number, cwd=None) -> Fetched:
    """`repos/{o}/{r}/pulls/{n}/reviews` → review の生配列（全件）。"""
    endpoint = (f"repos/{repo}/pulls/{int(pr_number)}/reviews"
                f"?per_page={PER_PAGE}")
    values, error = _api_get(gh, endpoint, repo=repo, cwd=cwd)
    if error is not None:
        return Fetched(None, error)
    reviews = []
    for page in values:
        if not isinstance(page, list):
            return Fetched(None, "unexpected_shape:reviews")
        reviews.extend(page)
    return Fetched(reviews)


def _required_from_rules(values) -> list:
    """`rules/branches/{ref}` の応答から required check context の **union** を取る。"""
    names = set()
    for page in values:
        if not isinstance(page, list):
            raise ValueError("rules 応答が配列でない")
        for rule in page:
            if not isinstance(rule, dict):
                raise ValueError("rule が object でない")
            if rule.get("type") != "required_status_checks":
                continue
            params = rule.get("parameters")
            if not isinstance(params, dict):
                raise ValueError("parameters が object でない")
            items = params.get("required_status_checks")
            if not isinstance(items, list):
                raise ValueError("required_status_checks が配列でない")
            for item in items:
                context = item.get("context") if isinstance(item, dict) else None
                if not isinstance(context, str):
                    raise ValueError("context が文字列でない")
                names.add(context)
    return sorted(names)


def fetch_required_checks(gh, *, repo, base_ref, cwd=None) -> Fetched:
    """`repos/{o}/{r}/rules/branches/{base_ref}` → required check 名の union。

    取得失敗（403 / rate limit / 想定外形式）は **config fallback を入れず**
    fail-closed（D1-A）。古い集合を正と誤認する逆リスクを避ける。
    """
    if not base_ref:
        return Fetched(None, "base_ref_unknown")
    values, error = _api_get(gh, f"repos/{repo}/rules/branches/{base_ref}",
                             repo=repo, cwd=cwd, paginate=False)
    if error is not None:
        return Fetched(None, error)
    try:
        return Fetched(_required_from_rules(values))
    except ValueError as exc:
        return Fetched(None, f"unexpected_shape:{_reason(exc)}")


def fetch_changed_files(gh, *, base_rev, head_sha, cwd=None) -> Fetched:
    """`git diff --name-only <base>...<head>` で変更パスを実測する（R-017）。

    **空リストで埋めない**。取得失敗は `Fetched(None, reason)` を返し、
    呼び出し側が `changed_files_unavailable:<reason>` を積む（fail-open 封じ）。
    """
    if not base_rev:
        return Fetched(None, "base_ref_unknown")
    stdout, rc, error = _run_git_text(
        gh, ["diff", "--name-only", f"{base_rev}...{head_sha}"], cwd=cwd)
    if error is not None:
        return Fetched(None, error)
    if rc != 0:
        return Fetched(None, f"rc={rc}")
    return Fetched([line for line in (stdout or "").splitlines() if line.strip()])


def fetch_ancestry(gh, *, source_sha, head_sha, cwd=None) -> Fetched:
    """`git merge-base --is-ancestor <source_sha> <head_sha>` の 3 値判定。

    exit 0 → `True` / exit 1 → `False` / それ以外（shallow clone 等）→ `None`。
    `None` は `delivery.py` の `is not True` で `HUMAN_ESCALATED` に倒れる。
    """
    if not source_sha:
        return Fetched(None, "source_sha_unknown")
    _stdout, rc, error = _run_git_text(
        gh, ["merge-base", "--is-ancestor", source_sha, head_sha], cwd=cwd)
    if error is not None:
        return Fetched(None, error)
    if rc == 0:
        return Fetched(True)
    if rc == 1:
        return Fetched(False)
    return Fetched(None, f"rc={rc}")


def fetch_raw_inputs(gh, *, repo, pr_number, source_sha, cwd=None,
                     expected_head_sha=None, base_ref=None,
                     base_rev=None) -> RawInputs:
    """REST GET 4 本 + 読み取り系 git 2 本をまとめて実行する（I/O 層の入口）。

    head SHA は `pulls/{n}` から解決する。解決できず `expected_head_sha` も
    無い場合のみ `CollectorError`（AC-1 の束縛対象を欠くため snapshot を
    構成できない）。
    """
    pull = fetch_pull(gh, repo=repo, pr_number=pr_number, cwd=cwd)
    head = None
    if pull.ok and isinstance(pull.value.get("head"), dict):
        candidate = pull.value["head"].get("sha")
        if isinstance(candidate, str) and candidate:
            head = candidate
    if pull.ok and isinstance(pull.value.get("base"), dict):
        candidate = pull.value["base"].get("ref")
        if isinstance(candidate, str) and candidate:
            base_ref = candidate
    if head is None:
        head = expected_head_sha
    if not head:
        raise CollectorError(
            "head SHA を解決できない（pulls/{n} 取得失敗かつ expected_head_sha 未指定）: "
            f"{pull.error}")

    return RawInputs(
        head_sha=head,
        base_ref=base_ref,
        pull=pull,
        check_runs=fetch_check_runs(gh, repo=repo, head_sha=head, cwd=cwd),
        reviews=fetch_reviews(gh, repo=repo, pr_number=pr_number, cwd=cwd),
        required_checks=fetch_required_checks(gh, repo=repo, base_ref=base_ref,
                                              cwd=cwd),
        changed_files=fetch_changed_files(
            gh, base_rev=base_rev or (f"origin/{base_ref}" if base_ref else None),
            head_sha=head, cwd=cwd),
        ancestry=fetch_ancestry(gh, source_sha=source_sha, head_sha=head, cwd=cwd),
    )


# ---------------------------------------------------------------------------
# 純関数層（raw JSON dict → snapshot）
# ---------------------------------------------------------------------------

def conclusion_for(entry):
    """check-run の `conclusion` を決める（R-019 の写像・必須）。

    `status != "completed"` のとき生の `conclusion` は **null** であり、
    `validate_snapshot()` は `str` を要求するため `invalid_snapshot` に落ちる。
    未完了は `conclusion = status`（`queued` / `in_progress`）へ写像し、
    `delivery.CHECK_PENDING` に一致させて `WAITING_FOR_CHECKS` へ倒す。
    """
    if not isinstance(entry, dict):
        return None
    status = entry.get("status")
    if isinstance(status, str) and status != "completed":
        return status
    conclusion = entry.get("conclusion")
    return conclusion if isinstance(conclusion, str) else None


def normalize_raw_check_run(entry) -> dict:
    """AC-9 で同梱する生レスポンスの正規化サブセット（決定論）。"""
    return {
        "id": entry.get("id"),
        "name": entry.get("name"),
        "head_sha": entry.get("head_sha"),
        "status": entry.get("status"),
        "conclusion": entry.get("conclusion"),
        "completed_at": entry.get("completed_at"),
    }


def checks_from_raw(raw_entries, head_sha):
    """生 check-run から `checks[]` を導出する（AC-1: head SHA 束縛）。

    - `head_sha` に一致しない check-run は**採用しない**（旧 head の green を
      拾わない）。除外は正常系であり flag を立てない（`delivery.py` 側の
      stale 規定 = `WAITING_FOR_CHECKS` に委ねる）
    - `conclusion` を導出できない要素は落として理由コードを積む（fail-closed）
    """
    checks, flags = [], []
    for entry in raw_entries or ():
        if not isinstance(entry, dict):
            flags.append(f"{FLAG_CHECK_RUN_UNPARSABLE}:non_object")
            continue
        if entry.get("head_sha") != head_sha:
            continue
        name = entry.get("name")
        conclusion = conclusion_for(entry)
        if not isinstance(name, str) or not isinstance(conclusion, str):
            label = name if isinstance(name, str) else "unnamed"
            flags.append(f"{FLAG_CHECK_RUN_UNPARSABLE}:{label}")
            continue
        checks.append({"name": name, "sha": head_sha, "conclusion": conclusion,
                       "check_run_id": entry.get("id")})
    return checks, flags


def _reviewer_key(review, index):
    """レビュアの同一性キー。`user.login` が読めない場合は index で分離する。

    分離するのは fail-closed のため（login 不明の review を他レビュアの
    「最新」で上書きさせない）。
    """
    user = review.get("user")
    login = user.get("login") if isinstance(user, dict) else None
    if isinstance(login, str) and login.strip():
        return ("login", login.strip())
    return ("anonymous", index)


def _latest_per_reviewer(candidates) -> list:
    """レビュアごとの**最新 1 件**を選ぶ（同値時は安全側 = CHANGES_REQUESTED）。

    `submitted_at` 欠落時に配列順（ページ順）で結果が反転すると `approved` にも
    `changes_requested` にもなりうる（R1 B-11）。同値のときは
    `CHANGES_REQUESTED` を優先し、それも同値なら配列順で後勝ちにする
    （決定論・安全側固定）。
    """
    grouped: dict = {}
    for item in candidates:
        grouped.setdefault(item["reviewer"], []).append(item)
    latest = []
    for reviewer in sorted(grouped, key=lambda k: (k[0], str(k[1]))):
        items = grouped[reviewer]
        newest = max(item["submitted_at"] for item in items)
        tied = [item for item in items if item["submitted_at"] == newest]
        blocking = [item for item in tied if item["state"] == REVIEW_STATE_BLOCKING]
        latest.append((blocking or tied)[-1])
    return latest


def reduce_review(raw_reviews, head_sha) -> dict:
    """review 配列 → 単一 dict へ縮約する（R-018 の 6 点規則 + R1 B-7 是正）。

    ①`commit_id == head_sha` のみ対象 ③`DISMISSED` は除外
    ④`state.lower()` へ正規化（`delivery.py:290` は小文字比較）
    ⑤該当ゼロは `{"state": "none", "sha": head_sha}`
    ⑥全件取得は I/O 層（`per_page` 明示 + `--paginate`）が担う。

    ②（採用規則）は **「最新 1 件が勝つ」から以下へ変更**した（R1 B-7）:

      1. `APPROVED` は投稿者権限が `REVIEW_ELIGIBLE_ASSOCIATIONS` の場合のみ
         候補に残す（外部者 / bot の approve で承認を成立させない。
         `author_association` 欠落は fail-closed で除外）
      2. **レビュアごとの最新**を取る（同値時は安全側 = 変更要求）
      3. その中に未解消の `CHANGES_REQUESTED` が **1 件でもあれば
         `changes_requested`**（後続の別レビュアの approve で上書きしない）
      4. それ以外で `APPROVED` があれば `approved`
      5. どちらでもなければ最新候補の state をそのまま返す

    「未解消」の判定は `DISMISSED` 除外（③）と「レビュアごとの最新」の合成で
    行う。GitHub は同一レビュアが再 approve すると前の変更要求を解消するため、
    レビュアごとの最新が `CHANGES_REQUESTED` であることが未解消と等価である。
    """
    candidates = []
    for index, review in enumerate(raw_reviews or ()):
        if not isinstance(review, dict):
            continue
        if review.get("commit_id") != head_sha:
            continue
        state = review.get("state")
        if not isinstance(state, str):
            continue
        normalized = state.upper()
        if normalized == REVIEW_STATE_DISMISSED:
            continue
        if normalized == REVIEW_STATE_APPROVED and \
                review.get("author_association") not in REVIEW_ELIGIBLE_ASSOCIATIONS:
            # 権限不明 / 外部者の approve は候補にしない（fail-closed）
            continue
        submitted = review.get("submitted_at")
        candidates.append({
            "reviewer": _reviewer_key(review, index),
            "submitted_at": submitted if isinstance(submitted, str) else "",
            "state": normalized,
            "index": index,
        })
    if not candidates:
        return {"state": REVIEW_STATE_NONE, "sha": head_sha}

    latest = _latest_per_reviewer(candidates)
    if any(item["state"] == REVIEW_STATE_BLOCKING for item in latest):
        return {"state": REVIEW_STATE_BLOCKING.lower(), "sha": head_sha}
    if any(item["state"] == REVIEW_STATE_APPROVED for item in latest):
        return {"state": REVIEW_STATE_APPROVED.lower(), "sha": head_sha}
    fallback = max(latest, key=lambda item: (item["submitted_at"], item["index"]))
    return {"state": fallback["state"].lower(), "sha": head_sha}


def _raw_is_parsable(entry) -> bool:
    """raw check-run が `checks[]` へ導出可能か（`checks_from_raw()` と同じ規則）。"""
    if not isinstance(entry, dict):
        return False
    return isinstance(entry.get("name"), str) and \
        isinstance(conclusion_for(entry), str)


def verify_raw_evidence(checks, raw_entries, head_sha) -> list:
    """AC-9: `checks[]` と raw check-run を **双方向**に照合する。

    - **順方向**（`checks[]` → raw）: 各 check が raw の対応要素から導出された
      ことを確認する。raw が無いことを「照合 OK」と扱わない（fail-closed）。
      改竄・捏造は `raw_evidence_mismatch:<name>` / `raw_evidence_missing:<name>`。
    - **逆方向**（raw → `checks[]`）: raw にある **head 一致かつ導出可能**な
      check-run が `checks[]` に**すべて現れる**ことを要求する。片方向だけだと
      「raw にある failure な check-run を `checks[]` から削除する」fail-open
      方向の改竄を検出できない（R1 B-8）。欠落は `raw_evidence_omitted:<name>`。
      raw に `id` が無い要素は突合できないため同じく omitted に倒す。

    `head_sha` は逆方向の対象を絞るために必須（旧 head の check-run が
    `checks[]` に無いのは正常であり flag しない）。

    **限界**: 手作り snapshot を `delivery.py` へ直接投入する経路は塞がない
    （module docstring の scope 明示を参照）。
    """
    by_id = {}
    for entry in raw_entries or ():
        if isinstance(entry, dict) and entry.get("id") is not None:
            by_id[entry["id"]] = entry
    flags = []
    seen_ids = set()
    for check in checks or ():
        name = check.get("name") if isinstance(check, dict) else None
        raw = by_id.get(check.get("check_run_id")) if isinstance(check, dict) else None
        if raw is None:
            flags.append(f"{FLAG_RAW_EVIDENCE_MISSING}:{name}")
            continue
        seen_ids.add(check.get("check_run_id"))
        derived = (raw.get("name"), raw.get("head_sha"), conclusion_for(raw))
        actual = (name, check.get("sha"), check.get("conclusion"))
        if derived != actual:
            flags.append(f"{FLAG_RAW_EVIDENCE_MISMATCH}:{name}")

    for entry in raw_entries or ():
        if not _raw_is_parsable(entry) or entry.get("head_sha") != head_sha:
            continue
        if entry.get("id") is None or entry["id"] not in seen_ids:
            flags.append(f"{FLAG_RAW_EVIDENCE_OMITTED}:{entry.get('name')}")
    return flags


def verify_snapshot_evidence(snapshot) -> list:
    """snapshot 単体に対して AC-9 の導出照合を行う（監査・再検証用）。

    `collect()` が build 後の最終 snapshot に対して**必ず**呼ぶ（`build_snapshot()`
    内の照合は同一 raw から両者を作った直後で構造的に恒真になりうるため、
    最終形に対する独立再検証を経路として持たせる / R1 B-8）。
    """
    return verify_raw_evidence(snapshot.get("checks") or [],
                               snapshot.get(RAW_CHECK_RUNS_KEY) or [],
                               snapshot.get("head_sha"))


def missing_required_checks(required, checks) -> list:
    """required 集合 ⊆ `checks[]` の名前集合 を検査し、不足名を返す（AC-2）。"""
    present = {c.get("name") for c in checks or () if isinstance(c, dict)}
    return sorted(name for name in required or () if name not in present)


def normalize_mergeable(value) -> str:
    """REST の `mergeable`（true / false / null）を `delivery` の enum へ写像する。

    未知値は `UNKNOWN` に倒す（`delivery.py` は `MERGEABLE` 以外を conflict 側に
    倒すため安全側）。
    """
    if value is True:
        return "MERGEABLE"
    if value is False:
        return "CONFLICTING"
    if isinstance(value, str) and value in delivery.MERGEABLE_VALID:
        return value
    return "UNKNOWN"


def parse_result_ref_parts(ref) -> dict:
    """`result_ref`（`k:v|k:v`）を辞書へ戻す **最小パーサ**（キー絞り込みなし）。

    `executor.parse_result_ref()` と同じ規約だが、`collector` は `executor` を
    import できない（`executor → collector` の import があり循環する）ため
    ここに最小実装を置く。値に `:` を含む URL を壊さないよう **最初の 1 個**
    のみで分割する（executor と同一規則）。両者の一致は test が機械照合する。
    """
    if not isinstance(ref, str) or not ref:
        return {}
    parsed = {}
    for chunk in ref.split(RESULT_REF_SEP):
        key, sep, value = chunk.partition(RESULT_REF_KV)
        if sep:
            parsed[key] = value
    return parsed


def receipt_evidence_ref(result_ref):
    """receipt の `result_ref` に載った実測根拠（`evidence:<ref>`）を返す。"""
    value = parse_result_ref_parts(result_ref).get(PART_EVIDENCE)
    return value if isinstance(value, str) and value.strip() else None


def derive_dod_evaluated(entries, pr_number, head_sha) -> bool:
    """`record.jsonl` から `dod_evaluated` を導出する（D3 (b) / R1 B-1・B-2 是正）。

    受理条件（**すべて**満たす直近の `dod_reevaluate` receipt が存在するとき
    のみ `True`）:

      1. `kind == "receipt"` / `action_kind == "dod_reevaluate"` /
         `pr_number` 一致 / `head_sha` が現在の head と一致
      2. **同一 `action_id` の `kind=="intent"` entry が存在する**
         （`delivery.py receipt` CLI は intent 先行を必須にするが、読み手側が
         intent を見ないと `record.jsonl` に receipt 行を 1 行足すだけで
         `dod_evaluated=True` → `MERGE_READY` を通せる / R1 B-2）
      3. `result_ref` に **`evidence:<ref>` が載っている**
         （外部作用ゼロの rubber stamp を DoD ゲートの根拠にしない / R1 B-1。
         Executor 側は `evidence_ref` を必須入力にして対称にしている）

    不一致・未存在・破損は `False`（`delivery.py` は False を
    `MERGE_READY_CANDIDATE` 止まりとして扱うため既に fail-closed）。
    """
    intent_ids = {entry.get("action_id") for entry in entries or ()
                  if isinstance(entry, dict) and entry.get("kind") == "intent"
                  and entry.get("action_kind") == "dod_reevaluate"
                  and entry.get("action_id")}
    latest = None
    for entry in entries or ():
        if not isinstance(entry, dict):
            continue
        if entry.get("kind") != "receipt":
            continue
        if entry.get("action_kind") != "dod_reevaluate":
            continue
        if entry.get("pr_number") != pr_number:
            continue
        latest = entry
    if latest is None or latest.get("head_sha") != head_sha:
        return False
    if latest.get("action_id") not in intent_ids:
        return False
    return receipt_evidence_ref(latest.get("result_ref")) is not None


def extract_allowed_paths(plan_text) -> list:
    """`plan.md` の `## Files / Components to Touch` からパスを抽出する（D3 (b)）。

    実装は `plan_package.extract_allowed_paths()` の**再利用**（再実装しない）。
    0 件は例外ではなく空リストで、呼び出し側が `escalation_flags` へ倒す。
    """
    return plan_package.extract_allowed_paths(plan_text or "")


def normalize_finding_type(value) -> str:
    """任意の入力語彙を **正規 `finding_type`** へ写像する（T-51 / R-034）。

    Collector の変換アダプタと Executor の `repair_review` receipt が
    **本関数のみ**を通ることで、`_past_repair_finding_types()` との集合積が
    成立する（語彙不一致 = `same_type_recurrence` の恒久 fail-open を封じる）。
    未知値は例外にせず `other` へ倒す（両側が同じ値へ落ちるため積は成立する）。
    """
    if not isinstance(value, str):
        return FINDING_TYPE_OTHER
    key = value.strip().lower()
    if not key:
        return FINDING_TYPE_OTHER
    if key in FINDING_TYPE_VOCABULARY:
        return key
    return FINDING_TYPE_ALIASES.get(key, FINDING_TYPE_OTHER)


#: 入力 finding のうち `finding_type` の供給元として読むキー（先頭優先）。
#: `docs/ai/external-reviewer-interface.md` §3.1 の Finding には型欄が無く、
#: 実装ごとに `category` / `type` を使うため複数を受ける（正規化は 1 箇所）。
FINDING_TYPE_SOURCE_KEYS = ("finding_type", "category", "type", "lane")


def _raw_finding_type(source) -> object:
    for key in FINDING_TYPE_SOURCE_KEYS:
        value = source.get(key)
        if isinstance(value, str) and value.strip():
            return value
    return None


def normalize_severity(value) -> str:
    """severity を `delivery.SEVERITY_VALID` へ写像する（未知値は安全側 `major`）。"""
    if isinstance(value, str) and value.strip().lower() in delivery.SEVERITY_VALID:
        return value.strip().lower()
    return SEVERITY_FALLBACK


def _first_text(source, keys) -> str:
    """`keys` の先頭優先で最初の非空文字列を返す（無ければ空文字）。"""
    for key in keys:
        value = source.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ""


def finding_id(raw) -> str:
    """入力 finding に対して**決定論的**な `id` を導出する（T-51 / R-034 / B-6）。

    入力が既に `id`（例: `review-external.md` の `R-NNN`）を持つ場合はそれを
    尊重する（run 間で最も安定する識別子であるため）。持たない場合は
    本文（`FINDING_ID_BODY_KEYS`）/ 位置（`FINDING_ID_LOCATION_KEYS`）/
    正規化 `finding_type`（severity / disposition は**含まない**）から
    `c3_contract.canonical_hash()` で導出する。**再実装しない**。

    本文・位置が**両方とも空**のときは `finding_type` しか材料が残らず、
    別々の指摘が同一 id へ潰れる（`_resolved()` は id 突合であるため 1 件
    直すと N 件消える / R1 B-6）。この場合は id を**導出せず**
    `FINDING_ID_UNDERIVABLE` を返し、`build_snapshot()` が
    `finding_id_underivable` を積んで fail-closed に倒す。
    """
    if isinstance(raw, dict):
        given = raw.get("id")
        if isinstance(given, str) and given.strip():
            return given.strip()
    source = raw if isinstance(raw, dict) else {}
    body = _first_text(source, FINDING_ID_BODY_KEYS)
    location = _first_text(source, FINDING_ID_LOCATION_KEYS)
    if not body and not location:
        return FINDING_ID_UNDERIVABLE
    core = {
        "finding": body,
        "location": location,
        "finding_type": normalize_finding_type(_raw_finding_type(source)),
    }
    digest = c3_contract.canonical_hash(core).split(":")[-1]
    return f"{FINDING_ID_PREFIX}{digest[:FINDING_ID_DIGEST_LEN]}"


def finding_id_flags(findings) -> list:
    """`findings[]` の id 健全性を検査する（producer を問わない構造検査 / B-6）。

    - 導出できなかった id（`FINDING_ID_UNDERIVABLE`）→ `finding_id_underivable`
    - 複数 finding が**同一 id** に潰れている → `finding_id_collision:<id>`

    後者は「1 件直すと N 件消える」を構造的に禁止する（アダプタを経由せず
    外部から `findings[]` を渡された場合にも効く）。
    """
    flags, seen, reported = [], set(), set()
    for finding in findings or ():
        if not isinstance(finding, dict):
            continue
        fid = finding.get("id")
        if fid == FINDING_ID_UNDERIVABLE and FLAG_FINDING_ID_UNDERIVABLE not in flags:
            flags.append(FLAG_FINDING_ID_UNDERIVABLE)
        if not isinstance(fid, str):
            continue
        if fid in seen and fid not in reported:
            flags.append(f"{FLAG_FINDING_ID_COLLISION}:{fid}")
            reported.add(fid)
        seen.add(fid)
    return flags


def adapt_finding(raw) -> dict:
    """外部レビューア形式（`{finding, severity, evidence, location}`）→ snapshot の
    `findings[]` 要素（`{id, finding_type, severity, disposition?}`）へ変換する。

    薄い変換アダプタ（plan 論点 D3 `findings[]` 行の案 (b) ①）。producer は repo 内に
    存在しないため本関数が唯一の供給経路になる。**外部作用ゼロ・決定論**。
    """
    source = raw if isinstance(raw, dict) else {}
    adapted = {
        "id": finding_id(source),
        "finding_type": normalize_finding_type(_raw_finding_type(source)),
        "severity": normalize_severity(source.get("severity")),
    }
    disposition = source.get("disposition")
    if isinstance(disposition, dict) and disposition.get("kind") in \
            delivery.DISPOSITION_KINDS:
        adapted["disposition"] = dict(disposition)
    return adapted


def adapt_findings(raw_findings) -> list:
    """`adapt_finding()` を配列に適用する（順序保存・決定論）。"""
    return [adapt_finding(f) for f in raw_findings or ()]


def _conflict_resolution_complete(cr) -> bool:
    """三点（`base_sha` / `head_sha` / `result_sha`）が揃っているか（R-026）。"""
    return isinstance(cr, dict) and all(
        cr.get(key) for key in ("base_sha", "head_sha", "result_sha"))


def _checks_are_settled(checks) -> bool:
    """head の check 集合が「出揃った」と言えるか。

    ⊇ 照合（AC-2）は **settled のときだけ**発火させる。理由: repair push 直後や
    CI 起動前は required check がまだ 1 件も登録されておらず、常時発火させると
    `WAITING_FOR_CHECKS`（TC-02 / TC-39）へ倒れるべき局面まで
    `HUMAN_ESCALATED` に倒れ、AC-4 の「repair → 最新 head 再評価」の 1 周が
    回らなくなる。settled でない間は `MERGE_READY` に到達しない
    （`waiting_checks` が先に立つ）ため、merge 側に対して fail-open にならない。
    """
    if not checks:
        return False
    return not any(c.get("conclusion") in delivery.CHECK_PENDING for c in checks)


def build_snapshot(*, task_id, pr_number, head_sha, raw, plan_text,
                   record_entries=(), record_error=None,
                   findings=FINDINGS_UNSUPPLIED, findings_supplied=None,
                   checks=None, conflict_resolution=None, ci_log_text="") -> dict:
    """raw 入力から snapshot を組み立てる **純関数**（I/O なし・決定論）。

    必須 12 キーを必ず埋め、`conflict_resolution` は三点が揃うときのみ出力する。
    pre-check の失敗はすべて `escalation_flags` へ積み、snapshot は破棄しない。

    `checks` を渡すと raw から導出せず**与えられた `checks[]` と raw を突合**
    する（AC-9 の照合が同一 raw から作った直後の恒真検査にならないようにする
    ための経路 / R1 B-8）。`findings` は**未供給**（既定）と**空リストの明示
    供給**を区別し、未供給は `findings_unavailable` に倒す（R1 B-4）。
    """
    flags: list = []

    if not raw.pull.ok:
        flags.append(f"{FLAG_PULL_FETCH_FAILED}:{raw.pull.error}")
    mergeable = normalize_mergeable(
        raw.pull.value.get("mergeable") if raw.pull.ok else None)

    raw_runs = raw.check_runs.value if raw.check_runs.ok else []
    if not raw.check_runs.ok:
        flags.append(f"{FLAG_CHECK_RUNS_FETCH_FAILED}:{raw.check_runs.error}")
    embedded = [normalize_raw_check_run(e) for e in raw_runs or ()
                if isinstance(e, dict)]
    if checks is None:
        checks, check_flags = checks_from_raw(raw_runs, head_sha)
        flags.extend(check_flags)
    else:
        checks = [dict(c) for c in checks if isinstance(c, dict)]
    # AC-9: 導出照合を Collector 内で**必ず**行う（呼び忘れを設計で許さない）。
    flags.extend(verify_raw_evidence(checks, embedded, head_sha))

    if not raw.reviews.ok:
        flags.append(f"{FLAG_REVIEWS_FETCH_FAILED}:{raw.reviews.error}")
    review = reduce_review(raw.reviews.value if raw.reviews.ok else [], head_sha)

    required = raw.required_checks.value if raw.required_checks.ok else []
    if not raw.required_checks.ok:
        flags.append(
            f"{FLAG_REQUIRED_CHECKS_FETCH_FAILED}:{raw.required_checks.error}")
    elif not required:
        # 空集合に対する ⊇ 照合は自明に成立し、照合が**無音で消える**（R1 B-3）。
        # 時間で解消しない構成側の事実であるため settled ゲートを掛けない。
        flags.append(FLAG_REQUIRED_CHECKS_EMPTY)
    else:
        missing = missing_required_checks(required, checks)
        if missing and _checks_are_settled(checks):
            flags.append(f"{FLAG_REQUIRED_CHECKS_MISSING}:{','.join(missing)}")

    if raw.changed_files.ok:
        changed_files = list(raw.changed_files.value)
        if not changed_files:
            # 取得成功かつ 0 件。PR に差分が無いのは正常状態ではなく、
            # 通すと `plan_deviation` が恒久的に不発になる（R1 B-9）。
            flags.append(FLAG_CHANGED_FILES_EMPTY)
    else:
        # 空リストで通すと `plan_deviation` が恒久的に不発（fail-open）になる。
        changed_files = []
        flags.append(
            f"{FLAG_CHANGED_FILES_UNAVAILABLE}:{raw.changed_files.error}")

    supplied = findings_supplied if isinstance(findings_supplied, bool) else \
        (findings is not FINDINGS_UNSUPPLIED and findings is not None)
    if findings is FINDINGS_UNSUPPLIED or findings is None:
        findings = ()
    findings_out = [dict(f) for f in findings if isinstance(f, dict)] \
        if supplied else []
    if not supplied:
        # producer 未接続のまま呼ばれると `REVIEW_REPAIR` が恒久不発になる。
        # 空リストの明示供給（= 指摘ゼロ）とは区別する（R1 B-4）。
        flags.append(FLAG_FINDINGS_UNAVAILABLE)
    flags.extend(finding_id_flags(findings_out))

    allowed_paths = extract_allowed_paths(plan_text)
    if not allowed_paths:
        flags.append(FLAG_ALLOWED_PATHS_EMPTY)

    if record_error:
        flags.append(f"{FLAG_RECORD_UNREADABLE}:{_reason(record_error)}")

    snapshot = {
        "task_id": task_id,
        "pr_number": int(pr_number),
        "head_sha": head_sha,
        "source_sha_ancestry": raw.ancestry.value if raw.ancestry.ok else None,
        "mergeable": mergeable,
        "checks": checks,
        "review": review,
        "findings": findings_out,
        "changed_files": changed_files,
        "allowed_paths": allowed_paths,
        "escalation_flags": flags,
        "dod_evaluated": derive_dod_evaluated(record_entries, int(pr_number),
                                              head_sha),
        RAW_CHECK_RUNS_KEY: embedded,
        REQUIRED_CHECKS_KEY: list(required),
    }
    if _conflict_resolution_complete(conflict_resolution):
        snapshot["conflict_resolution"] = dict(conflict_resolution)

    taxonomy = ci_taxonomy.resolve_taxonomy(
        pr_number=int(pr_number), head_sha=head_sha,
        entries=record_entries or (), log_text=ci_log_text or "")
    return ci_taxonomy.apply_to_snapshot(snapshot, taxonomy)


# ---------------------------------------------------------------------------
# 入口（I/O 層 → 純関数層）
# ---------------------------------------------------------------------------

def collect(*, task_id, repo, pr_number, source_sha, plan_text,
            record_path=None, record_entries=None, ci_log_text="",
            findings=FINDINGS_UNSUPPLIED, findings_supplied=None, checks=None,
            conflict_resolution=None, base_ref=None, base_rev=None,
            expected_head_sha=None, gh=gh_exec, cwd=None) -> dict:
    """snapshot を 1 つ生成する（`gh` は差し替え可能 = テストは実 API に出ない）。

    `findings` を渡さない呼び出しは **producer 未接続**として
    `findings_unavailable` を積む（R1 B-4）。指摘ゼロを表明する場合は
    `findings=[]` を**明示的に**渡すこと。
    """
    record_error = None
    if record_entries is None:
        record_entries = []
        if record_path is not None:
            try:
                record_entries = ci_taxonomy.load_record_entries(record_path)
            except delivery.RecordError as exc:
                record_error = str(exc)

    raw = fetch_raw_inputs(gh, repo=repo, pr_number=pr_number,
                           source_sha=source_sha, cwd=cwd,
                           expected_head_sha=expected_head_sha,
                           base_ref=base_ref, base_rev=base_rev)
    snapshot = build_snapshot(
        task_id=task_id, pr_number=pr_number, head_sha=raw.head_sha, raw=raw,
        plan_text=plan_text, record_entries=record_entries,
        record_error=record_error, findings=findings,
        findings_supplied=findings_supplied, checks=checks,
        conflict_resolution=conflict_resolution, ci_log_text=ci_log_text)
    # AC-9: 組み上がった**最終 snapshot** に対して独立に再照合する（B-8）。
    # `build_snapshot()` 内の照合だけだと「同一 raw から両者を作った直後」で
    # 構造的に恒真になりうるため、後段の合成（taxonomy 付与等）まで含んだ
    # 最終形を検査する経路を必ず 1 本通す（`verify_snapshot_evidence()` の
    # 非テスト呼び出し元をゼロにしない）。
    existing = list(snapshot.get("escalation_flags") or ())
    for flag in verify_snapshot_evidence(snapshot):
        if flag not in existing:
            existing.append(flag)
    snapshot["escalation_flags"] = existing
    return snapshot
