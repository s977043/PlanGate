#!/usr/bin/env python3
"""gh_exec.py — gh / git を実行する **唯一の境界**（TASK-0917 / #917 / AC-5）。

契約正本: docs/working/TASK-0917/plan.md「論点 D2 / D2-A の設計詳細（実装契約）」。
境界そのものは `check_exec_boundary.py` が AST で機械強制する
（本モジュールは「除外」ではなく **逆向きホワイトリスト検査**の対象＝
`subprocess` **のみ**許可され、`os.system` / `urllib` / `socket` 等は 0 件）。

設計:
  - **リポジトリ内で唯一 `subprocess` を import してよいモジュール**。gh と git を
    同一モジュールに置き、allowlist テーブルは 2 つ（`GH_RULES` / `GIT_READ_RULES`）。
  - `shell=False` 固定・argv はリスト・`argv[0]` は wrapper が固定する
    （caller から受け取らない）。
  - **allowlist は argv トークン列の構造照合**:
      1. `argv[0]` は wrapper が固定
      2. `--k=v` は `--k` + `v` に分解して正規化する
      3. **短縮形は long 化せず即 deny**（`-X` / `-f` / `-F` / `-q` / `-b` / `-w` /
         `-e` 等）。理由 = 短縮形の意味は**サブコマンド依存**であり
         （`-F` は `gh api` では `--field`、`gh pr comment` では `--body-file`）、
         単一のグローバル正規化表が成立しない。`-XPOST` の結合形は
         **分解したうえで** deny する。wrapper 自身は常に long 形で組み立てる
      4. **未知フラグは即 deny**
      5. 位置引数列を rule の `verbs` と**完全一致**照合（prefix / 部分一致は使わない）
      6. rule 固有 constraint（名前付き条件の合成）を適用
      7. **関数末尾は無条件 `raise Denied`**（fallthrough allow を作らない）
  - **禁止は allowlist の補集合として自動成立**する。`gh pr merge` /
    `gh pr review --approve` / `gh pr close` 等を個別に列挙して塞ぐ設計ではない。
  - **`graphql` は allowlist に載せない**（常に POST で `mergePullRequest` /
    `addPullRequestReview` の直接経路になる）。**`--cache` も除外**（stale が
    AC-1 の head SHA 束縛と衝突する）。
  - **git push は allowlist ではなく構造化 API**（`push_pr_head()`）。
    `+`（force 相当）/ 空 src `:branch`（削除）/ `--force*` / `--delete` /
    `--mirror` / `--prune` / `--receive-pack` は「**組み立てない**」ことで
    原理的に発生させない。読み取り系 git のみ argv 検査型 allowlist。

⚠️ **回避不能なギャップ（AC-5 の scope 明示）**: in-process allowlist は
**この Python プロセス経由の作用しか守らない**。同一セッションの Bash や別
プロセスからの `gh pr merge` は塞がらず、トークン権限でも分離できない
（merge も comment も同じ `pull_requests:write` スコープ）。したがって
**AC-5 の scope は「Executor 経路のみを守る」**。プロセス外は既存の規範層
（`.claude/rules/`）+ C-4 Human レビューに残る。

NO MERGE BY AI: merge は Human-owned であり、本モジュールは merge 経路を
一切組み立てない（`.claude/rules/responsibility-classes.md`）。
"""

from __future__ import annotations

import dataclasses
import json
import pathlib
import re
import subprocess
import tempfile

# ---------------------------------------------------------------------------
# 例外 / 理由コード
# ---------------------------------------------------------------------------

REASON_EMPTY_ARGV = "EMPTY_ARGV"
REASON_SHORT_FLAG = "SHORT_FLAG"
REASON_UNKNOWN_FLAG = "UNKNOWN_FLAG"
REASON_UNKNOWN_SUBCOMMAND = "UNKNOWN_SUBCOMMAND"
REASON_ARITY = "ARITY"
REASON_POSITIONAL = "POSITIONAL_MISMATCH"
REASON_SLOT = "SLOT_MISMATCH"
REASON_CONSTRAINT = "CONSTRAINT"
REASON_PRECHECK = "PRECHECK"


class Denied(Exception):
    """allowlist に載っていない（= 実行してはならない）argv。

    `reason` は機械判定用の理由コード、`message` は人間可読な詳細。
    """

    def __init__(self, reason: str, message: str) -> None:
        super().__init__(f"[{reason}] {message}")
        self.reason = reason
        self.message = message


# ---------------------------------------------------------------------------
# rule table のデータ構造
# ---------------------------------------------------------------------------

ARITY_NONE = "none"
ARITY_VALUE = "value"


@dataclasses.dataclass(frozen=True)
class Slot:
    """位置引数のうち可変部分。`pattern` は fullmatch で照合する。"""

    name: str
    pattern: str


@dataclasses.dataclass(frozen=True)
class GhRule:
    """`gh` の 1 サブコマンドに対する allowlist エントリ。

    `verbs` は位置引数列（`str` = リテラル / `Slot` = 可変部）。
    `flags` は `((flag, arity), ...)` で **long 形のみ**。
    `conditions` は `((name, fn), ...)`。名前付きにすることで、テストが
    `dataclasses.replace` で 1 条件だけ落とした変異体を作れる（検出力の実証）。
    """

    name: str
    verbs: tuple
    flags: tuple
    conditions: tuple

    @property
    def literal_prefix(self) -> tuple:
        prefix = []
        for verb in self.verbs:
            if not isinstance(verb, str):
                break
            prefix.append(verb)
        return tuple(prefix)

    @property
    def flag_map(self) -> dict:
        return dict(self.flags)


@dataclasses.dataclass(frozen=True)
class GitRule:
    """読み取り専用 git サブコマンドの allowlist エントリ。"""

    sub: str
    flags: tuple
    max_operands: int

    @property
    def flag_map(self) -> dict:
        return dict(self.flags)


@dataclasses.dataclass(frozen=True)
class Ctx:
    """rule 固有 constraint に渡す照合コンテキスト。"""

    repo: str
    rule: GhRule
    tokens: tuple
    positionals: tuple
    flags: tuple
    slots: dict


# ---------------------------------------------------------------------------
# 正規化（短縮形の一律 deny / `--k=v` の分解）
# ---------------------------------------------------------------------------

def _split_short(token: str) -> tuple:
    """`-XPOST` を `('-X', 'POST')` に分解する（deny 理由の可読化のため）。"""
    return (token[:2], token[2:])


def _reject_short_forms(tokens) -> None:
    """短縮形（`-x` / `-xVALUE` / 単独 `-`）を一律 deny する。

    long 化しない理由: 短縮形の意味はサブコマンド依存で単一のグローバル
    正規化表が成立しないため（`-F` は `gh api` では `--field`、
    `gh pr comment` では `--body-file`）。wrapper は常に long 形で組み立てる。
    """
    for token in tokens:
        if not token.startswith("-") or token.startswith("--"):
            continue
        if token == "-":
            raise Denied(REASON_SHORT_FLAG, "単独の '-'（stdin）は使用禁止")
        head, rest = _split_short(token)
        detail = f"分解: {head!r} + {rest!r}" if rest else f"分解: {head!r}"
        raise Denied(REASON_SHORT_FLAG,
                     f"短縮形は long 化せず一律 deny（{detail}）: {token}")


def _leading_positionals(tokens) -> list:
    lead = []
    for token in tokens:
        if token.startswith("-"):
            break
        lead.append(token)
    return lead


def _parse_flags_and_positionals(tokens, flag_map):
    """`--k=v` を分解しつつ、未知フラグ / arity 違反を即 deny する。"""
    positionals: list = []
    flags: list = []
    index = 0
    total = len(tokens)
    while index < total:
        token = tokens[index]
        if not token.startswith("-"):
            positionals.append(token)
            index += 1
            continue
        if "=" in token:
            name, _, inline = token.partition("=")
            has_inline = True
        else:
            name, inline, has_inline = token, None, False
        if name == "--":
            raise Denied(REASON_UNKNOWN_FLAG,
                         "'--' 以降の passthrough は許可されない")
        arity = flag_map.get(name)
        if arity is None:
            raise Denied(REASON_UNKNOWN_FLAG, f"未知フラグ: {name}")
        if arity == ARITY_NONE:
            if has_inline:
                raise Denied(REASON_ARITY, f"値を取らないフラグに値が付与された: {token}")
            flags.append((name, None))
            index += 1
            continue
        if has_inline:
            flags.append((name, inline))
            index += 1
            continue
        if index + 1 >= total:
            raise Denied(REASON_ARITY, f"値が必要なフラグに値が無い: {name}")
        flags.append((name, tokens[index + 1]))
        index += 2
    return positionals, flags


def _match_verbs(rule: GhRule, positionals):
    """位置引数列を `verbs` と完全一致照合する（prefix / 部分一致は使わない）。"""
    if len(positionals) != len(rule.verbs):
        raise Denied(REASON_POSITIONAL,
                     f"{rule.name}: 位置引数の個数が一致しない "
                     f"（期待 {len(rule.verbs)} / 実際 {len(positionals)}）")
    slots: dict = {}
    for expected, actual in zip(rule.verbs, positionals):
        if isinstance(expected, str):
            if expected != actual:
                raise Denied(REASON_POSITIONAL,
                             f"{rule.name}: リテラル不一致（期待 {expected!r} / "
                             f"実際 {actual!r}）")
            continue
        if re.fullmatch(expected.pattern, actual) is None:
            raise Denied(REASON_SLOT,
                         f"{rule.name}: slot {expected.name} が不正: {actual!r}")
        slots[expected.name] = actual
    return slots


# ---------------------------------------------------------------------------
# 条件（constraint）— 名前付きにして変異注入で検出力を実証できるようにする
# ---------------------------------------------------------------------------

def _values(ctx: Ctx, flag: str) -> list:
    return [value for name, value in ctx.flags if name == flag]


#: `--json` に指定してよいフィールド名（読み取り専用の範囲に限定）。
JSON_FIELDS = frozenset({
    "headRefName", "baseRefName", "headRefOid", "baseRefOid", "number", "state",
    "mergeable", "mergeStateStatus", "url", "title", "isDraft", "reviewDecision",
    "latestReviews", "statusCheckRollup", "commits", "files", "author", "createdAt",
    "updatedAt", "name", "bucket", "link", "workflow", "event", "startedAt",
    "completedAt", "description",
})

#: `gh api` において「1 つでもあれば POST へ自動昇格する」body パラメータ。
API_BODY_PARAM_FLAGS = ("--field", "--raw-field", "--input")


def _c_repo_bound(ctx: Ctx) -> None:
    for value in _values(ctx, "--repo"):
        if value != ctx.repo:
            raise Denied(REASON_CONSTRAINT,
                         f"--repo は呼び出し時の repo に束縛される "
                         f"（期待 {ctx.repo!r} / 実際 {value!r}）")


def _c_json_fields(ctx: Ctx) -> None:
    for value in _values(ctx, "--json"):
        for field in value.split(","):
            if field not in JSON_FIELDS:
                raise Denied(REASON_CONSTRAINT, f"--json の未許可フィールド: {field!r}")


def _c_body_file_once(ctx: Ctx) -> None:
    values = _values(ctx, "--body-file")
    if len(values) != 1:
        raise Denied(REASON_CONSTRAINT,
                     f"--body-file はちょうど 1 回必要（実際 {len(values)} 回）。"
                     "本文の inline 指定・エディタ起動は許可しない")


def _c_body_file_wrapper_temp(ctx: Ctx) -> None:
    for value in _values(ctx, "--body-file"):
        resolved = str(pathlib.Path(value).resolve())
        if resolved not in _WRAPPER_BODY_FILES:
            raise Denied(REASON_CONSTRAINT,
                         "--body-file は wrapper が生成した temp path のみ許可: "
                         f"{value!r}")


def _c_api_method_get(ctx: Ctx) -> None:
    methods = _values(ctx, "--method")
    if len(methods) > 1:
        raise Denied(REASON_CONSTRAINT,
                     f"--method の複数指定は許可しない: {methods}")
    if methods and methods[0] != "GET":
        raise Denied(REASON_CONSTRAINT,
                     f"--method は 'GET' に完全一致すること: {methods[0]!r}")


def _c_api_no_body_params(ctx: Ctx) -> None:
    for flag in API_BODY_PARAM_FLAGS:
        if _values(ctx, flag):
            raise Denied(REASON_CONSTRAINT,
                         f"{flag} はリクエストを POST へ自動昇格させるため deny")


def _c_api_endpoint_bound(ctx: Ctx) -> None:
    endpoint = ctx.slots.get("endpoint", "")
    if ".." in endpoint:
        raise Denied(REASON_CONSTRAINT, f"endpoint に '..' を含む: {endpoint!r}")
    for pattern in api_endpoint_patterns(ctx.repo):
        if pattern.fullmatch(endpoint):
            return
    raise Denied(REASON_CONSTRAINT,
                 f"allowlist 外の endpoint（owner/repo は実値束縛）: {endpoint!r}")


#: `gh api` の GET 強制は **3 条件 AND**。1 つでも欠けると POST 経路が開く。
API_GET_CONDITIONS = (
    ("method_is_get", _c_api_method_get),
    ("no_body_params", _c_api_no_body_params),
    ("endpoint_bound", _c_api_endpoint_bound),
)
API_GET_CONDITION_NAMES = tuple(name for name, _ in API_GET_CONDITIONS)


def api_endpoint_patterns(repo: str) -> tuple:
    """4 本の endpoint 正規表現を **呼び出し時の repo 実値で束縛**して返す。

    `{owner}` プレースホルダや自由変数は使わない（配布先で壊れる repo 固有 id を
    埋め込まないため、ruleset 一覧 / `rulesets/{id}` も載せない）。
    """
    owner, _, name = repo.partition("/")
    o = re.escape(owner)
    r = re.escape(name)
    query = r"(?:\?per_page=[0-9]{1,3})?"
    ref = r"[A-Za-z0-9][A-Za-z0-9._/-]*"
    return (
        re.compile(rf"repos/{o}/{r}/commits/[0-9a-f]{{7,40}}/check-runs{query}"),
        re.compile(rf"repos/{o}/{r}/pulls/[0-9]+{query}"),
        re.compile(rf"repos/{o}/{r}/pulls/[0-9]+/reviews{query}"),
        re.compile(rf"repos/{o}/{r}/rules/branches/{ref}"),
    )


# ---------------------------------------------------------------------------
# rule table（gh）
# ---------------------------------------------------------------------------

_PR_SELECTOR = Slot("pr", r"(?:[0-9]+|[A-Za-z0-9][A-Za-z0-9._/-]*)")
_PR_NUMBER = Slot("pr", r"[0-9]+")
_ENDPOINT = Slot("endpoint", r"[^\s]+")

GH_RULES = (
    GhRule(
        name="pr view",
        verbs=("pr", "view", _PR_SELECTOR),
        flags=(("--json", ARITY_VALUE), ("--jq", ARITY_VALUE),
               ("--repo", ARITY_VALUE)),
        conditions=(("repo_bound", _c_repo_bound), ("json_fields", _c_json_fields)),
    ),
    GhRule(
        name="pr diff",
        verbs=("pr", "diff", _PR_NUMBER),
        flags=(("--name-only", ARITY_NONE), ("--repo", ARITY_VALUE)),
        conditions=(("repo_bound", _c_repo_bound),),
    ),
    GhRule(
        name="pr checks",
        verbs=("pr", "checks", _PR_NUMBER),
        flags=(("--json", ARITY_VALUE), ("--jq", ARITY_VALUE),
               ("--repo", ARITY_VALUE)),
        conditions=(("repo_bound", _c_repo_bound), ("json_fields", _c_json_fields)),
    ),
    GhRule(
        # `--delete-last` / `--edit-last` / `--yes` / `--create-if-none` / `--editor`
        # / `--web` / `--body` は **flags に載せない**ことで deny する
        # （サブコマンド名だけの allow は「PR の履歴を変える操作」を通してしまう）。
        name="pr comment",
        verbs=("pr", "comment", _PR_NUMBER),
        flags=(("--body-file", ARITY_VALUE), ("--repo", ARITY_VALUE)),
        conditions=(("repo_bound", _c_repo_bound),
                    ("body_file_once", _c_body_file_once),
                    ("body_file_wrapper_temp", _c_body_file_wrapper_temp)),
    ),
    GhRule(
        # body パラメータ 3 種は **flags に載せたうえで条件で deny** する。
        # 載せずに「未知フラグ」で落とすと、GET 強制 3 条件 AND の 2 番目が
        # 実効を持つかどうかをテストで検証できなくなるため。
        name="api",
        verbs=("api", _ENDPOINT),
        flags=(("--method", ARITY_VALUE), ("--jq", ARITY_VALUE),
               ("--paginate", ARITY_NONE),
               ("--field", ARITY_VALUE), ("--raw-field", ARITY_VALUE),
               ("--input", ARITY_VALUE)),
        conditions=API_GET_CONDITIONS,
    ),
)


# ---------------------------------------------------------------------------
# rule table（読み取り系 git）
# ---------------------------------------------------------------------------

#: git operand（rev-ish / パス）として許可する形。`+` / `:` / 先頭 `-` は許可しない。
_GIT_OPERAND_RE = re.compile(
    r"[A-Za-z0-9_][A-Za-z0-9._/-]*(?:\.{2,3}[A-Za-z0-9_][A-Za-z0-9._/-]*)?")

GIT_READ_RULES = (
    GitRule("rev-parse",
            (("--abbrev-ref", ARITY_NONE), ("--verify", ARITY_NONE),
             ("--short", ARITY_NONE), ("--is-inside-work-tree", ARITY_NONE)), 2),
    GitRule("merge-base", (("--is-ancestor", ARITY_NONE),), 3),
    GitRule("log",
            (("--max-count", ARITY_VALUE), ("--format", ARITY_VALUE),
             ("--oneline", ARITY_NONE), ("--no-color", ARITY_NONE)), 3),
    GitRule("status", (("--porcelain", ARITY_NONE), ("--branch", ARITY_NONE)), 1),
    GitRule("diff",
            (("--name-only", ARITY_NONE), ("--stat", ARITY_NONE),
             ("--no-color", ARITY_NONE)), 3),
    GitRule("ls-remote",
            (("--get-url", ARITY_NONE), ("--heads", ARITY_NONE),
             ("--exit-code", ARITY_NONE)), 3),
    GitRule("show",
            (("--no-patch", ARITY_NONE), ("--format", ARITY_VALUE),
             ("--name-only", ARITY_NONE)), 2),
)


# ---------------------------------------------------------------------------
# 認可（allowlist 照合）
# ---------------------------------------------------------------------------

def rule_literal_prefixes(rules=GH_RULES) -> set:
    """rule table の literal prefix 集合（補集合テストの自動追随に使う）。"""
    return {rule.literal_prefix for rule in rules}


def rule_by_name(name: str, rules=GH_RULES) -> GhRule:
    for rule in rules:
        if rule.name == name:
            return rule
    raise KeyError(name)


def authorize_gh(args, *, repo: str, rules=GH_RULES) -> list:
    """`gh` の argv を allowlist 照合し、通れば **wrapper が組み立てた argv** を返す。

    `args` は `gh` を **含まない** トークン列（`argv[0]` は caller から受け取らない）。
    末尾は無条件 `raise Denied`（fallthrough allow を作らない）。
    """
    tokens = [str(token) for token in args]
    if not tokens:
        raise Denied(REASON_EMPTY_ARGV, "argv が空")
    _reject_short_forms(tokens)
    lead = _leading_positionals(tokens)
    for rule in rules:
        prefix = rule.literal_prefix
        if not prefix or tuple(lead[:len(prefix)]) != prefix:
            continue
        positionals, flags = _parse_flags_and_positionals(tokens, rule.flag_map)
        slots = _match_verbs(rule, positionals)
        ctx = Ctx(repo=repo, rule=rule, tokens=tuple(tokens),
                  positionals=tuple(positionals), flags=tuple(flags), slots=slots)
        for _name, condition in rule.conditions:
            condition(ctx)
        return ["gh", *tokens]
    raise Denied(REASON_UNKNOWN_SUBCOMMAND,
                 f"allowlist に該当 rule が無い: {tokens}")


def authorize_git(args, *, rules=GIT_READ_RULES) -> list:
    """**読み取り系** git の argv を allowlist 照合する。

    `push` / `commit` / `branch` 等の書き込み系は rule table に存在しないため
    補集合として自動的に deny される。末尾は無条件 `raise Denied`。
    """
    tokens = [str(token) for token in args]
    if not tokens:
        raise Denied(REASON_EMPTY_ARGV, "argv が空")
    _reject_short_forms(tokens)
    for rule in rules:
        if tokens[0] != rule.sub:
            continue
        operands, _flags = _parse_flags_and_positionals(tokens[1:], rule.flag_map)
        if len(operands) > rule.max_operands:
            raise Denied(REASON_POSITIONAL,
                         f"{rule.sub}: operand が多すぎる（上限 {rule.max_operands}）")
        for operand in operands:
            if _GIT_OPERAND_RE.fullmatch(operand) is None:
                raise Denied(REASON_SLOT,
                             f"{rule.sub}: 許可されない operand: {operand!r}")
        return ["git", *tokens]
    raise Denied(REASON_UNKNOWN_SUBCOMMAND,
                 f"読み取り系 git allowlist に無いサブコマンド: {tokens[0]!r}")


# ---------------------------------------------------------------------------
# 実行（唯一の subprocess 呼び出し地点）
# ---------------------------------------------------------------------------

def _spawn(argv, *, cwd=None, timeout=120):
    """`shell=False` 固定でプロセスを起動する（既存 `scripts/doctor_check.py` 慣習）。

    モジュール属性 `subprocess` をテストが spy へ差し替えられるよう、
    グローバル参照のまま呼ぶ（実ネットワークに出ないための唯一の口）。
    """
    return subprocess.run(argv, capture_output=True, text=True, check=False,
                          cwd=cwd, timeout=timeout)


def run_gh(args, *, repo: str, cwd=None, rules=GH_RULES):
    """allowlist を通過した `gh` コマンドのみ実行する。"""
    return _spawn(authorize_gh(args, repo=repo, rules=rules), cwd=cwd)


def run_git(args, *, cwd=None, rules=GIT_READ_RULES):
    """allowlist を通過した **読み取り系** git コマンドのみ実行する。"""
    return _spawn(authorize_git(args, rules=rules), cwd=cwd)


# ---------------------------------------------------------------------------
# コメント本文の temp file（`--body-file` は wrapper 生成 path のみ許可）
# ---------------------------------------------------------------------------

#: wrapper が生成した body file の resolve 済み path。allowlist の照合キー。
_WRAPPER_BODY_FILES: set = set()


def make_comment_body_file(body: str) -> pathlib.Path:
    """決定論生成したコメント本文を temp file へ書き、その path を登録して返す。

    `pr comment` rule の `body_file_wrapper_temp` 条件は本関数が登録した path
    のみを許可する（任意ファイルの投稿を構造的に塞ぐ）。
    """
    handle = tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", suffix=".md",
        prefix="plangate-gh-exec-", delete=False)
    with handle:
        handle.write(body)
    path = pathlib.Path(handle.name).resolve()
    _WRAPPER_BODY_FILES.add(str(path))
    return path


def comment_pr(*, repo: str, pr_number, body: str, cwd=None):
    """PR へコメントする（本文は wrapper が生成した temp file 経由に限定）。"""
    path = make_comment_body_file(body)
    return run_gh(["pr", "comment", str(int(pr_number)),
                   "--body-file", str(path), "--repo", repo],
                  repo=repo, cwd=cwd)


# ---------------------------------------------------------------------------
# git push（allowlist ではなく構造化 API）
# ---------------------------------------------------------------------------

_BRANCH_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._/-]*")
_SHA_RE = re.compile(r"[0-9a-f]{7,40}")


@dataclasses.dataclass(frozen=True)
class PushResult:
    """`push_pr_head()` の結果。`argv` は実際に組み立てた argv。"""

    pushed: bool
    argv: tuple
    result: object


def _require_branch(branch: str) -> str:
    if not isinstance(branch, str) or _BRANCH_RE.fullmatch(branch) is None:
        raise Denied(REASON_PRECHECK, f"branch 名が許可形式でない: {branch!r}")
    if ".." in branch:
        raise Denied(REASON_PRECHECK, f"branch 名に '..' を含む: {branch!r}")
    return branch


def _require_sha(sha: str) -> str:
    if not isinstance(sha, str) or _SHA_RE.fullmatch(sha) is None:
        raise Denied(REASON_PRECHECK, f"SHA が許可形式でない: {sha!r}")
    return sha


def build_push_argv(*, branch: str) -> list:
    """push の argv を **wrapper が自ら組み立てる**（危険形を生成しない）。

    `+`（force 相当）/ 空 src `:branch`（削除）/ `--force*` / `--delete` /
    `--mirror` / `--prune` / `--receive-pack` は組み立てないことで
    原理的に発生させない。src は常に `HEAD`、dst は常に `refs/heads/<branch>`。
    """
    _require_branch(branch)
    return ["git", "push", "origin", f"HEAD:refs/heads/{branch}"]


def _origin_matches(url: str, repo: str) -> bool:
    normalized = url.strip()
    if normalized.endswith(".git"):
        normalized = normalized[:-4]
    normalized = normalized.rstrip("/")
    return normalized.endswith("/" + repo) or normalized.endswith(":" + repo)


def push_pr_head(*, repo: str, branch: str, expected_parent_sha: str, cwd=None):
    """PR の head branch へ fast-forward push する（事前検査 4 点）。

    1. `branch` が `gh pr view --json headRefName` の実測値と一致すること
    2. `baseRefName` と**不一致**であること（default branch への push を明示 deny）
    3. `git ls-remote --get-url origin` が `repo` と一致すること
    4. `expected_parent_sha` が `HEAD` の祖先である（fast-forward である）こと

    いずれか 1 つでも不成立なら push に到達せず `Denied` を送出する。
    """
    _require_sha(expected_parent_sha)
    argv = build_push_argv(branch=branch)

    view = run_gh(["pr", "view", branch, "--json", "headRefName,baseRefName",
                   "--repo", repo], repo=repo, cwd=cwd)
    if view.returncode != 0:
        raise Denied(REASON_PRECHECK,
                     f"gh pr view に失敗（rc={view.returncode}）: {view.stderr!r}")
    try:
        meta = json.loads(view.stdout)
    except (ValueError, TypeError) as exc:
        raise Denied(REASON_PRECHECK, f"gh pr view の出力を解釈できない: {exc}") from exc
    if meta.get("headRefName") != branch:
        raise Denied(REASON_PRECHECK,
                     f"branch が PR の headRefName と一致しない "
                     f"（期待 {branch!r} / 実際 {meta.get('headRefName')!r}）")
    if meta.get("baseRefName") == branch:
        raise Denied(REASON_PRECHECK,
                     f"baseRefName と一致する branch へは push しない: {branch!r}")

    origin = run_git(["ls-remote", "--get-url", "origin"], cwd=cwd)
    if origin.returncode != 0 or not _origin_matches(origin.stdout, repo):
        raise Denied(REASON_PRECHECK,
                     f"origin URL が repo と一致しない（repo={repo!r} / "
                     f"url={origin.stdout.strip()!r}）")

    ancestry = run_git(["merge-base", "--is-ancestor", expected_parent_sha, "HEAD"],
                       cwd=cwd)
    if ancestry.returncode != 0:
        raise Denied(REASON_PRECHECK,
                     f"fast-forward でない（expected_parent_sha={expected_parent_sha!r} "
                     f"は HEAD の祖先でない / rc={ancestry.returncode}）")

    result = _spawn(argv, cwd=cwd)
    return PushResult(pushed=True, argv=tuple(argv), result=result)
