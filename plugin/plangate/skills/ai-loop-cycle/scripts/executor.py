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

__doc__ = """executor.py — `delivery.py` の intent を実行する **唯一の外部書き込み層**
（TASK-0917 / #917 / AC-3・AC-5・R-005・R-021）。

契約正本: docs/working/TASK-0917/plan.md
  「R-005（repair push が C-4 承認を stale にする）への対処」/
  「外部作用の実行順序と二重作用の封じ込め（R-021 反映 / C-3 論点）」/
  Work Breakdown Step 6。

## 責務

`delivery.py assess()` が返す **6 種の `action_kind`**（`repair_ci` /
`resolve_conflict` / `repair_review` / `record_disposition` /
`feedback_loop_referral` / `dod_reevaluate`）を実行する。**新しい
`action_kind` を作らない**（新設は `delivery.py` の変更＝ Out of scope に
触れるため。R-005 案②の通知コメントは `repair_ci` / `repair_review` の実行に
**内包**する）。

## 外部作用の実行順序（R-021・C-3 裁定済み）

    ① 通知コメント → ② pre-check（実行済みなら skip）→ ③ repair push → ④ receipt

`delivery.py` は `actions = [a for a in actions if a["action_id"] not in
receipts]` により **receipt の無い intent を次 run で再要求**する。したがって
「外部作用**後** / receipt **前**」に中断すると同じ push が再実行されうる。
上記順序ならば中断時の残骸は **可逆な「余分なコメント 1 件」**に限定され、
不可逆な push は pre-check（②）が二重実行を封じる。**コメントに失敗したら
push しない**（TC-E6）。

### ② pre-check の判定（実装上の精密化）

plan の文言は「`expected_parent_sha` が既に PR head の祖先なら実行済み」だが、
`git merge-base --is-ancestor X X` は **exit 0**（commit は自分自身の祖先）で
あるため、文字どおり実装すると **未 push の局面でも常に skip** し repair が
永久に反映されない。したがって「PR head が `expected_parent_sha` と一致しない
**かつ** `expected_parent_sha` が PR head の祖先」= **真の祖先**で判定する
（plan の意図「resume 時に二重 push しない」をそのまま満たし、かつ初回 push を
潰さない）。

### ③ コメントの再投稿抑止

R-021 ③「同一 `action_id` 由来のコメントが既にあるなら再投稿しない」は、
`record.jsonl` の **`kind="notice"` entry**（append-only・`delivery.py` の
`assess()` からは不可視）で追跡する。抑止キーは **`(pr_number, head_sha,
repair_commit_sha)`**（R1 B-13）: `action_id` は finding ごとに異なるため、
それを鍵にすると同一 run の `repair_review` N 件が**同じ push を告げる同内容
コメントを N 件**投稿してしまう。PR 側のコメント一覧を読む経路は
`gh_exec` の allowlist に **存在しない**（`gh api .../issues/{n}/comments` は
endpoint allowlist 外・`gh pr view --json comments` は `JSON_FIELDS` 外）ため、
唯一の決定論的な追跡手段が append-only record である。

## finding_type 語彙（T-51 / R-034）

`repair_review` の receipt に載る `finding_type` は **`collector.py` の単一
定数表**（`FINDING_TYPE_VOCABULARY`）から供給する。語彙が Collector の変換
アダプタとズレると `delivery.py` の `_past_repair_finding_types()` との集合積が
常に空になり `same_type_recurrence` が恒久 fail-open になるため、語彙外の値を
持つ intent は **外部作用ゼロで拒否**する。

NO MERGE BY AI: 本モジュールは merge / approve / close を一切組み立てない。
外部作用は `gh_exec.comment_pr()` と `gh_exec.push_pr_head()` の 2 経路のみ。
"""

import dataclasses
import io
import json
import pathlib
import sys
from contextlib import redirect_stdout

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import c3_contract  # noqa: E402  action_id の単一定義（canonical_hash を再実装しない）
import collector  # noqa: E402  finding_type 定数表の単一の置き場（T-51）
import delivery  # noqa: E402  action / record 契約の実物（AC-7: 変更しない）
import gh_exec  # noqa: E402  唯一の外部作用境界（allowlist）

# ---------------------------------------------------------------------------
# 契約定数
# ---------------------------------------------------------------------------

#: `delivery.py assess()` が発行しうる 6 種。**この tuple を増やさない**。
ACTION_KINDS = (
    "repair_ci", "repair_review", "resolve_conflict",
    "record_disposition", "feedback_loop_referral", "dod_reevaluate",
)

#: R-005 案②の通知コメントを**内包**する action_kind（新設ゼロ）。
NOTIFY_KINDS = ("repair_ci", "repair_review")

#: repair push を伴う action_kind（`delivery.REPAIR_KINDS` を単一ソースに再利用）。
PUSH_KINDS = delivery.REPAIR_KINDS

#: `finding_type` 語彙の単一定数表（`collector.py` から import。再定義しない）。
FINDING_TYPE_VOCABULARY = collector.FINDING_TYPE_VOCABULARY

# --- result_ref convention（D3: `delivery.py receipt --result-ref` の汎用文字列）
#: 区切りと `evidence` キーは `collector.py` を**単一ソース**として参照する
#: （collector は executor を import できない = 循環するため、共有部の置き場を
#: collector に固定する。同じ理由で `FINDING_TYPE_VOCABULARY` も collector 側）。
RESULT_REF_SEP = collector.RESULT_REF_SEP
RESULT_REF_KV = collector.RESULT_REF_KV
PART_ADOPTED = "adopted"
PART_REJECTED = "rejected"
PART_COMMENT = "comment"
PART_BASE = "base"
PART_HEAD = "head"
PART_REFERRAL = "referral"
PART_DOD = "dod"
PART_SKIPPED = "skipped"
#: 実測根拠（`dod_reevaluate` / `record_disposition` の必須入力）。
PART_EVIDENCE = collector.PART_EVIDENCE
#: `repair_review` の `adopted` が「どの finding に対する commit か」を残すキー
#: （単一 `repair_commit_sha` を finding ごとの検証なしに貼ると、critical を
#: 含む全 finding が一括で `adopted` 化する / R1 B-5）。
PART_FINDING = "finding"
#: `parse_result_ref()` が認識する部分キー（未知キーは無視する = 前方互換）。
RESULT_REF_PARTS = (PART_ADOPTED, PART_REJECTED, PART_COMMENT, PART_BASE,
                    PART_HEAD, PART_REFERRAL, PART_DOD, PART_SKIPPED,
                    PART_EVIDENCE, PART_FINDING)

# --- record.jsonl の補助 entry（`assess()` からは不可視 / append-only）
NOTICE_KIND = "notice"

# --- 実行結果ステータス
STATUS_EXECUTED = "executed"
STATUS_SKIPPED = "skipped"                    # pre-check で「実行済み」と判定
STATUS_ALREADY_RECEIPTED = "already_receipted"  # receipt 済み = 外部作用ゼロ
STATUS_FAILED = "failed"

# --- escalation_flags の理由コード（opaque・#894 が語彙を決める / AC-6 接続点）
FLAG_COMMENT_FAILED = "executor_comment_failed"
FLAG_PUSH_FAILED = "executor_push_failed"
FLAG_RECEIPT_FAILED = "executor_receipt_failed"
FLAG_UNKNOWN_ACTION_KIND = "executor_unknown_action_kind"
FLAG_ACTION_ID_MISMATCH = "executor_action_id_mismatch"
FLAG_FINDING_TYPE_VOCABULARY = "executor_finding_type_out_of_vocabulary"
FLAG_MISSING_INPUT = "executor_missing_input"
FLAG_PR_HEAD_UNRESOLVED = "executor_pr_head_unresolved"
FLAG_ANCESTRY_UNKNOWN = "executor_precheck_ancestry_unknown"

#: 通知コメントの本文テンプレート（**決定論生成**。時刻・乱数を含めない）。
NOTIFY_TEMPLATE = """## ai-loop: repair push 通知（TASK-0917 / #917 / R-005）

- `action_kind`: `{action_kind}`
- `action_id`: `{action_id}`
- 承認時の head（old）: `{old_sha}`
- repair 後の head（new）: `{new_sha}`

この push により **既存の C-4 承認は最新 head を指していません**
（`dismiss_stale_reviews_on_push: false` の実測に基づく明示通知）。
再レビューとマージは Human-owned です（NO MERGE BY AI）。
"""


class ExecutorError(RuntimeError):
    """Executor が構成できない状態（呼び出し側の契約違反）。"""


# ---------------------------------------------------------------------------
# データ構造
# ---------------------------------------------------------------------------

@dataclasses.dataclass(frozen=True)
class ExecContext:
    """1 run 分の実行コンテキスト（外部から与えられる事実のみ）。

    `gh` を差し替えられることが唯一の I/O 注入点（テストは実ネットワークに
    出ない）。`repair_commit_sha` / `base_sha` / `evidence_ref` は Executor が
    生成せず**呼び出し側（exec レーン）が実測して渡す**（Executor は publish
    のみを責務とする）。
    """

    repo: str
    branch: str
    task_dir: object
    now: str
    gh: object = gh_exec
    cwd: object = None
    repair_commit_sha: object = None
    base_sha: object = None
    evidence_ref: object = None

    @property
    def record_path(self):
        return delivery.record_path(self.task_dir)


@dataclasses.dataclass(frozen=True)
class CommentResult:
    ok: bool
    url: object = None
    reason: object = None


@dataclasses.dataclass(frozen=True)
class PushOutcome:
    pushed: bool
    reason: object = None


@dataclasses.dataclass(frozen=True)
class ActionOutcome:
    """1 action の実行結果（監査可能・決定論）。"""

    action_id: str
    action_kind: str
    status: str
    result_ref: object = None
    comment_url: object = None
    pushed: bool = False
    escalation_flags: tuple = ()
    reason: object = None


@dataclasses.dataclass(frozen=True)
class ExecutionReport:
    outcomes: tuple
    escalation_flags: tuple

    @property
    def executed(self) -> tuple:
        return tuple(o for o in self.outcomes if o.status == STATUS_EXECUTED)

    @property
    def failed(self) -> tuple:
        return tuple(o for o in self.outcomes if o.status == STATUS_FAILED)


# ---------------------------------------------------------------------------
# result_ref convention（Reconciler が disposition を再構成する唯一の規約）
# ---------------------------------------------------------------------------

def build_result_ref(parts) -> str:
    """`(key, value)` の列を `k:v|k:v` 形式へ組み立てる（決定論・順序保存）。"""
    chunks = []
    for key, value in parts:
        if value in (None, ""):
            continue
        text = str(value).replace(RESULT_REF_SEP, "/")
        chunks.append(f"{key}{RESULT_REF_KV}{text}")
    return RESULT_REF_SEP.join(chunks)


def parse_result_ref(ref) -> dict:
    """`result_ref` を辞書へ戻す（未知キー / 自由文字列は黙って捨てる）。

    分割は `collector.parse_result_ref_parts()` に委譲する（同じ規約を 2 箇所で
    実装すると drift するため。値に `:` を含む URL を壊さないよう区切りは
    **最初の 1 個**のみ = collector 側の実装が担保する）。
    """
    return {k: v for k, v in collector.parse_result_ref_parts(ref).items()
            if k in RESULT_REF_PARTS}


# ---------------------------------------------------------------------------
# record.jsonl の読み書き（append-only・`delivery.py` の実物を使う）
# ---------------------------------------------------------------------------

def receipt_ids(entries) -> set:
    """receipt 済み `action_id` の集合（`delivery.py` と同じ規則）。"""
    return {e.get("action_id") for e in entries or ()
            if isinstance(e, dict) and e.get("kind") == "receipt"}


def is_receipted(action, receipts) -> bool:
    """当該 action が receipt 済みかの **唯一の判定**（Executor / Reconciler 共用）。

    `reconciler.filter_unexecuted()` と `execute_action()` が同じ判定を別々に
    書くと（`a.get("action_id") not in receipts` と
    `action["action_id"] in receipt_ids(entries)`）、片方だけ規則が変わったときに
    「Reconciler は落としたのに Executor は実行する」/ その逆の drift が起きる。
    集合の生成（`receipt_ids()`）と 1 件の判定（本関数）を分けているのは、
    N action × M entry の再走査を避けつつ規則を 1 箇所に保つため。

    `receipts` は `receipt_ids()` の返り値（集合）。
    """
    return isinstance(action, dict) and action.get("action_id") in receipts


def notice_key(action, repair_commit_sha):
    """通知コメントの**再投稿抑止キー**（R-021 ③ / R1 B-13 で拡幅）。

    抑止キーを `action_id` にすると、同一 run の `repair_review` が finding 数
    だけ発行された場合に **同じ push を告げる同内容コメントが N 件**並ぶ
    （`action_id` は finding ごとに異なるため）。通知が伝える事実は
    「PR `pr_number` の head `head_sha` が `repair_commit_sha` へ進む」であり、
    この 3 点が一致する通知は run 内で 1 件に集約してよい。
    """
    return (action.get("pr_number"), action.get("head_sha"), repair_commit_sha)


def notice_index(entries) -> dict:
    """抑止キー → 既投稿コメント URL（`comment_url` は None もありうる）。"""
    index = {}
    for entry in entries or ():
        if not isinstance(entry, dict) or entry.get("kind") != NOTICE_KIND:
            continue
        index[(entry.get("pr_number"), entry.get("head_sha"),
               entry.get("repair_commit_sha"))] = entry.get("comment_url")
    return index


def notice_urls(entries) -> dict:
    """`action_id` → 既投稿コメント URL（監査・後方互換の索引）。"""
    urls = {}
    for entry in entries or ():
        if not isinstance(entry, dict) or entry.get("kind") != NOTICE_KIND:
            continue
        if entry.get("action_id"):
            urls[entry["action_id"]] = entry.get("comment_url")
    return urls


def notice_entry(action, comment_url, repair_commit_sha=None) -> dict:
    """コメント投稿の事実を append-only に残す entry（`assess()` からは不可視）。"""
    return {"kind": NOTICE_KIND, "action_id": action["action_id"],
            "action_kind": action["action_kind"],
            "pr_number": action.get("pr_number"),
            "head_sha": action.get("head_sha"),
            "repair_commit_sha": repair_commit_sha,
            "comment_url": comment_url}


def load_entries(ctx: ExecContext) -> list:
    """`record.jsonl` を読む（破損は `delivery.RecordError` を握り潰さず送出）。"""
    return delivery.load_entries(ctx.record_path)


def append(ctx: ExecContext, entries) -> int:
    return delivery.append_entries(ctx.record_path, entries, ctx.now)


def record_receipt(ctx: ExecContext, action_id: str, result_ref: str) -> int:
    """receipt は `delivery.py` の `receipt` サブコマンドを **実物のまま**呼ぶ。

    in-process 呼び出し（`subprocess` を使わない = 実行系境界を広げない）。
    intent 先行必須 / `pr_number` / `head_sha` / `finding_type` の束縛は
    `delivery.py` 側の実装がそのまま効く（再実装しない）。
    """
    buf = io.StringIO()
    with redirect_stdout(buf):
        rc = delivery.main(["delivery.py", "receipt",
                            "--task-dir", str(ctx.task_dir),
                            "--action-id", action_id,
                            "--result-ref", result_ref,
                            "--now", ctx.now])
    return rc


# ---------------------------------------------------------------------------
# 検証（外部作用の**前**に全部済ませる）
# ---------------------------------------------------------------------------

def verify_action_id(action) -> bool:
    """`action_id` が `delivery.py` と同じ規則で導出されているかを再計算照合する。

    `c3_contract.canonical_hash()` を **import 再利用**する（TC-08）。捏造された
    intent をそのまま実行しないための最小の完全性検査。
    """
    if not isinstance(action, dict) or not action.get("action_id"):
        return False
    body = {k: v for k, v in action.items() if k != "action_id"}
    return action["action_id"] == c3_contract.canonical_hash(body)


def _required_inputs(action, ctx: ExecContext):
    """action_kind ごとの必須入力を検査し、不足なら理由文字列を返す。

    `dod_reevaluate` / `record_disposition` は **`evidence_ref` を必須**にする:

    - `dod_reevaluate`（R1 B-1）: 必須入力ゼロだと Executor は外部作用ゼロで
      receipt を書き、Collector の `derive_dod_evaluated()` がそれを見て
      `True` にする＝ **DoD ゲートを AI ループが自分で押せる** rubber stamp に
      なる。実測根拠の参照を必須にして「判定した事実」を receipt へ束縛する。
    - `record_disposition`（R1 B-5）: これは minor/info の「**記録**」であって
      「修正」ではない。`repair_commit_sha` の fallback を残すと run 全体で 1 個
      の SHA が finding ごとの対応検証なしに全件へ貼られ、記録要求まで
      `adopted` 化する。不採用根拠（`evidence_ref`）のみを受理する。
    """
    kind = action["action_kind"]
    if kind in PUSH_KINDS and not ctx.repair_commit_sha:
        return "repair_commit_sha"
    if kind == "resolve_conflict" and not ctx.base_sha:
        return "base_sha"
    if kind == "record_disposition" and not ctx.evidence_ref:
        return "evidence_ref"
    if kind == "dod_reevaluate" and not ctx.evidence_ref:
        return "evidence_ref"
    return None


def _finding_type_violation(action):
    """`repair_review` の `finding_type` が単一定数表の語彙内かを検査する（T-51）。"""
    if action["action_kind"] != "repair_review":
        return None
    value = action.get("finding_type")
    if value in FINDING_TYPE_VOCABULARY:
        return None
    return f"{value!r}"


# ---------------------------------------------------------------------------
# ① 通知コメント
# ---------------------------------------------------------------------------

def notification_body(*, action, old_sha, new_sha) -> str:
    """通知コメント本文を**決定論生成**する（テンプレ + old_sha / new_sha）。"""
    return NOTIFY_TEMPLATE.format(action_kind=action["action_kind"],
                                  action_id=action["action_id"],
                                  old_sha=old_sha, new_sha=new_sha)


def perform_comment(action, ctx: ExecContext) -> CommentResult:
    """通知コメントを投稿する（`gh_exec.comment_pr()` = wrapper 生成 temp file 経由）。"""
    body = notification_body(action=action, old_sha=action.get("head_sha"),
                             new_sha=ctx.repair_commit_sha)
    try:
        proc = ctx.gh.comment_pr(repo=ctx.repo, pr_number=action["pr_number"],
                                 body=body, cwd=ctx.cwd)
    except gh_exec.Denied as exc:
        return CommentResult(False, reason=f"denied:{exc.reason}")
    except Exception as exc:  # noqa: BLE001  握り潰さず理由コードへ落とす
        return CommentResult(False, reason=f"exec_error:{type(exc).__name__}")
    if getattr(proc, "returncode", 1) != 0:
        return CommentResult(False, reason=f"rc={proc.returncode}")
    url = (getattr(proc, "stdout", "") or "").strip().splitlines()
    return CommentResult(True, url=url[-1] if url else None)


# ---------------------------------------------------------------------------
# ② pre-check（実行済み判定）
# ---------------------------------------------------------------------------

def fetch_pr_head_sha(ctx: ExecContext):
    """PR の現在の head SHA を読む（読み取り系 allowlist の `gh pr view`）。"""
    try:
        proc = ctx.gh.run_gh(["pr", "view", ctx.branch, "--json", "headRefOid",
                              "--repo", ctx.repo], repo=ctx.repo, cwd=ctx.cwd)
    except gh_exec.Denied as exc:
        return None, f"denied:{exc.reason}"
    except Exception as exc:  # noqa: BLE001
        return None, f"exec_error:{type(exc).__name__}"
    if proc.returncode != 0:
        return None, f"rc={proc.returncode}"
    try:
        meta = json.loads(proc.stdout)
    except (ValueError, TypeError) as exc:
        return None, f"unparsable_json:{type(exc).__name__}"
    sha = meta.get("headRefOid") if isinstance(meta, dict) else None
    if not isinstance(sha, str) or not sha:
        return None, "missing_headRefOid"
    return sha, None


def is_ancestor(ctx: ExecContext, ancestor, descendant):
    """`git merge-base --is-ancestor` の 3 値判定（True / False / None=不明）。"""
    try:
        proc = ctx.gh.run_git(["merge-base", "--is-ancestor", ancestor, descendant],
                              cwd=ctx.cwd)
    except gh_exec.Denied:
        return None
    except Exception:  # noqa: BLE001
        return None
    if proc.returncode == 0:
        return True
    if proc.returncode == 1:
        return False
    return None


def push_already_applied(action, ctx: ExecContext):
    """当該 repair push が **既に PR へ反映済み**かを判定する（R-021 ②）。

    返り値: `True`（実行済み → skip）/ `False`（未実行）/ `None`（判定不能）。

    判定は 3 点の AND:

    1. PR head が `expected_parent_sha` と**一致しない**。
       `merge-base --is-ancestor X X` は exit 0 のため、等値ガードを外すと
       初回 push まで skip されて repair が永久に反映されない
       （module docstring の精密化を参照）。
    2. `expected_parent_sha` が PR head の祖先である（fast-forward の関係）。
    3. **`ctx.repair_commit_sha` が PR head から到達可能である**（R2 B2-4）。
       1+2 だけだと「snapshot 採取後に**無関係な commit** が head に載った」
       ケースを「repair 済み」と誤判定する。誤判定すると `STATUS_SKIPPED` +
       receipt が記録され、`delivery.py` は receipt 済み intent を再要求
       しないため **当該 repair は永久に push されない**。押すべき commit
       そのものの到達可能性を見るのが唯一の正しい「実行済み」判定である。
    """
    expected_parent_sha = action.get("head_sha")
    head, reason = fetch_pr_head_sha(ctx)
    if head is None:
        return None, reason
    if head == expected_parent_sha:
        return False, None
    verdict = is_ancestor(ctx, expected_parent_sha, head)
    if verdict is None:
        return None, "ancestry_unresolved"
    if not verdict:
        return False, None
    repair = ctx.repair_commit_sha
    if not repair:
        # 押すべき commit が不明なら「実行済み」と断定しない（安全側 = 再 push を
        # 試み、最終防衛は `gh_exec.push_pr_head()` の事前検査 4 点に委ねる）。
        return False, None
    reached = is_ancestor(ctx, repair, head)
    if reached is None:
        return None, "repair_commit_ancestry_unresolved"
    return bool(reached), None


# ---------------------------------------------------------------------------
# ③ repair push
# ---------------------------------------------------------------------------

def perform_push(action, ctx: ExecContext) -> PushOutcome:
    """`gh_exec.push_pr_head()` 経由で PR head branch へ fast-forward push する。

    **`perform_comment()` と同じ形で終了コードを検査する**（R2 B2-1）。可逆な
    コメントだけ検査し不可逆な push を無検査にすると、push 失敗が
    `STATUS_EXECUTED` + receipt になり `delivery.py` が当該 intent を二度と
    再要求しない（修正が反映されないまま「repair 済み」として loop が進む）。
    `gh_exec.push_pr_head()` は非 0 終了時に `PushResult(pushed=False, ...)` を
    返すため、ここでは `pushed` を **必ず** 見る（未知の返り値型も失敗扱い）。
    """
    try:
        result = ctx.gh.push_pr_head(repo=ctx.repo, branch=ctx.branch,
                                     expected_parent_sha=action["head_sha"],
                                     cwd=ctx.cwd)
    except gh_exec.Denied as exc:
        return PushOutcome(False, reason=f"denied:{exc.reason}")
    except Exception as exc:  # noqa: BLE001
        return PushOutcome(False, reason=f"exec_error:{type(exc).__name__}")
    if not getattr(result, "pushed", False):
        rc = getattr(getattr(result, "result", None), "returncode", None)
        return PushOutcome(False, reason=f"rc={rc}")
    return PushOutcome(True)


# ---------------------------------------------------------------------------
# ④ result_ref の組み立て（action_kind ごと）
# ---------------------------------------------------------------------------

def build_action_result_ref(action, ctx: ExecContext, *, comment_url=None,
                            skipped=False) -> str:
    """`result_ref` を組み立てる（Reconciler が disposition を再構成する唯一の規約）。

    `repair_review` の `adopted` には **finding_id を併記**する（どの finding に
    対する commit かを receipt に残さないと、単一 `repair_commit_sha` が
    critical を含む全 finding へ無検証で貼られたことを後から区別できない /
    R1 B-5）。`record_disposition` は `rejected:<evidence_ref>` のみ。
    """
    kind = action["action_kind"]
    parts = []
    if kind == "resolve_conflict":
        parts.append((PART_ADOPTED, ctx.repair_commit_sha))
        parts.append((PART_BASE, ctx.base_sha))
        parts.append((PART_HEAD, action.get("head_sha")))
    elif kind in PUSH_KINDS:
        parts.append((PART_ADOPTED, ctx.repair_commit_sha))
        parts.append((PART_FINDING, action.get("finding_id")))
    elif kind == "record_disposition":
        parts.append((PART_REJECTED, ctx.evidence_ref))
        parts.append((PART_FINDING, action.get("finding_id")))
    elif kind == "feedback_loop_referral":
        parts.append((PART_REFERRAL, action.get("finding_type")))
    elif kind == "dod_reevaluate":
        parts.append((PART_DOD, action.get("head_sha")))
        parts.append((PART_EVIDENCE, ctx.evidence_ref))
    if comment_url:
        parts.append((PART_COMMENT, comment_url))
    if skipped:
        parts.append((PART_SKIPPED, "already_applied"))
    return build_result_ref(parts)


# ---------------------------------------------------------------------------
# 実行本体
# ---------------------------------------------------------------------------

def _fail(action, flag, detail, flags_out):
    """失敗 outcome を作る。**先行 flag を落とさない**（R1 B-12）。

    `escalation_flags=(code,)` にすると、直前に積んだ
    `executor_precheck_ancestry_unknown` 等が次 run の snapshot へ伝播せず
    `flags_out` が dead write になる（`execute_actions()` は outcome の
    `escalation_flags` を集約するため）。`code` は直上で append 済みなので
    `tuple(flags_out)` がその run の全理由コードになる。
    """
    code = f"{flag}:{detail}" if detail else flag
    flags_out.append(code)
    return ActionOutcome(action_id=action.get("action_id") or "",
                         action_kind=action.get("action_kind") or "",
                         status=STATUS_FAILED,
                         escalation_flags=tuple(flags_out), reason=code)


def execute_action(action, ctx: ExecContext, *, entries) -> ActionOutcome:
    """1 action を **① comment → ② pre-check → ③ push → ④ receipt** の順で実行する。

    外部作用に到達する前にすべての検証を終える（余分なコメントすら残さない）。
    """
    flags: list = []
    kind = action.get("action_kind")

    if kind not in ACTION_KINDS:
        return _fail(action, FLAG_UNKNOWN_ACTION_KIND, str(kind), flags)
    if not verify_action_id(action):
        return _fail(action, FLAG_ACTION_ID_MISMATCH, str(action.get("action_id")),
                     flags)
    if is_receipted(action, receipt_ids(entries)):
        # AC-3 / TC-07: receipt 済み = 外部作用ゼロで即返す（gh を一度も呼ばない）
        return ActionOutcome(action_id=action["action_id"], action_kind=kind,
                             status=STATUS_ALREADY_RECEIPTED)
    violation = _finding_type_violation(action)
    if violation is not None:
        return _fail(action, FLAG_FINDING_TYPE_VOCABULARY, violation, flags)
    missing = _required_inputs(action, ctx)
    if missing is not None:
        return _fail(action, FLAG_MISSING_INPUT, f"{kind}:{missing}", flags)

    # --- ① 通知コメント（R-021 ①: push より先。失敗したら push しない） ---
    # 抑止キーは (pr_number, head_sha, repair_commit_sha)。同一 push を告げる
    # 通知は finding 数だけ重ねない（R1 B-13）。通知を出さない action_kind に
    # 他 action のコメント URL を貼らないため、参照も NOTIFY_KINDS に限る。
    comment_url = None
    if kind in NOTIFY_KINDS:
        key = notice_key(action, ctx.repair_commit_sha)
        index = notice_index(entries)
        comment_url = index.get(key)
        if key not in index:
            result = perform_comment(action, ctx)
            if not result.ok:
                return _fail(action, FLAG_COMMENT_FAILED,
                             f"{kind}:{result.reason}", flags)
            comment_url = result.url
            # コメントは不可逆でないが、**再投稿抑止のため必ず記録**する（R-021 ③）
            append(ctx, [notice_entry(action, comment_url,
                                      ctx.repair_commit_sha)])

    # --- ② pre-check（実行済みなら push を skip） ---
    pushed = False
    skipped = False
    if kind in PUSH_KINDS:
        applied, reason = push_already_applied(action, ctx)
        if applied is None:
            # 判定不能は握り潰さず記録したうえで push を試みる（push しない選択は
            # 恒久 livelock になる。最終防衛は `gh_exec.push_pr_head()` の 4 点検査）
            flags.append(f"{FLAG_ANCESTRY_UNKNOWN}:{reason}")
            applied = False
        if applied:
            skipped = True
        else:
            # --- ③ repair push ---
            outcome = perform_push(action, ctx)
            if not outcome.pushed:
                return _fail(action, FLAG_PUSH_FAILED, f"{kind}:{outcome.reason}",
                             flags)
            pushed = True

    # --- ④ receipt ---
    result_ref = build_action_result_ref(action, ctx, comment_url=comment_url,
                                         skipped=skipped)
    rc = record_receipt(ctx, action["action_id"], result_ref)
    if rc != 0:
        return _fail(action, FLAG_RECEIPT_FAILED, f"{kind}:rc={rc}", flags)

    return ActionOutcome(action_id=action["action_id"], action_kind=kind,
                         status=STATUS_SKIPPED if skipped else STATUS_EXECUTED,
                         result_ref=result_ref, comment_url=comment_url,
                         pushed=pushed, escalation_flags=tuple(flags))


def execute_actions(actions, ctx: ExecContext, *, entries=None) -> ExecutionReport:
    """action 列を順に実行する（1 件の失敗で後続を止めない・全件の理由を集約）。

    `entries` 未指定なら `record.jsonl` を読む。破損時は `delivery.RecordError` を
    **握り潰さず**送出する（fail-closed）。
    """
    if entries is None:
        entries = load_entries(ctx)
    outcomes = []
    flags: list = []
    for action in actions or ():
        outcome = execute_action(action, ctx, entries=entries)
        outcomes.append(outcome)
        flags.extend(outcome.escalation_flags)
        if outcome.status in (STATUS_EXECUTED, STATUS_SKIPPED):
            entries = load_entries(ctx)  # receipt / notice を次の action へ反映
    return ExecutionReport(tuple(outcomes), tuple(flags))


def apply_escalation_flags(snapshot, flags) -> dict:
    """Executor が積んだ理由コードを **次 run の snapshot** へ引き渡す（AC-6 接続点）。

    `collector.build_snapshot()` を変えずに合流させるための薄い合成関数。
    元の snapshot は破壊しない（順序保存・重複排除）。

    ⚠️ **本関数の非テスト呼び出し元をゼロにしない**（`collector.py` の
    `verify_snapshot_evidence()` と同じ規律 / R2 B2-3）。呼び出し元が
    テストだけになると「Executor が積んだ理由コードが次 run へ到達する」
    ことが一度も実証されず、AC-6 で機械固定されているのが Collector 側の
    素通しだけになる。`tests/extras/ta-57-pr-convergence.sh` の E2E が
    「Executor の flag → 次 run snapshot → `HUMAN_ESCALATED`」を 1 本通す。
    """
    merged = dict(snapshot or {})
    existing = list(merged.get("escalation_flags") or ())
    for flag in flags or ():
        if flag not in existing:
            existing.append(flag)
    merged["escalation_flags"] = existing
    return merged
