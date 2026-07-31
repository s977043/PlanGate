#!/usr/bin/env python3
"""check_exec_boundary.py — ai-loop の実行系境界を AST で機械強制する検査器（TASK-0917 / #917）。

契約正本: docs/working/TASK-0917/plan.md「D2-A の設計詳細（実装契約）」および
「`test_*.py` の argv 先頭要素 不変条件（精緻化 / C-1 F-1 の裁定）」。

不変条件:
  1. `gh_exec.py` **以外**のモジュールは実行系トークンを持たない
     （`subprocess` / `os.system` / `os.popen` / `os.exec*` / `os.spawn*` /
     `os.posix_spawn*` / `os.forkpty` / `pty` / `ctypes` / `multiprocessing` /
     `asyncio.create_subprocess_*` / `urllib` / `socket` / `http.client` /
     `requests` / `importlib.import_module` による動的 import）。
  2. `gh_exec.py` は「除外」ではなく **逆向きホワイトリスト検査**にかける。
     `subprocess` **のみ**許可し、その他の実行系トークンは 0 件であること
     （除外にすると唯一の実行境界そのものが無検査になり、`gh_exec.py` 内の
     `os.system("gh pr merge 1")` を止めるものが存在しなくなる）。
     さらに `gh_exec.py` **内部の** `subprocess` 呼び出しサイトには
     **構造規律**を課す（R1-A-4。語の有無だけでは唯一の境界の内部に無検査の
     抜け道が残るため）:
       (a) `shell=True` を渡さない（非リテラル / `**kwargs` 展開も fail-closed）
       (b) `subprocess` 呼び出しは単一のプライベート実行関数（`_spawn()`）に限る
       (c) `_spawn()` の呼び出し元は監査済みの入口関数集合
           （`GH_EXEC_SPAWN_CALLERS`）に限る
  3. `test_*.py` は `subprocess` を使ってよいが、`run` / `check_output` /
     `Popen` / `call` / `check_call` 等の **argv 先頭要素**は
     `sys.executable` **または**読み取り専用 git サブコマンド allowlist
     （status / rev-parse / diff / log / merge-base / ls-remote / show）に限る。
     テストを単純除外すると迂回路になるため、除外ではなく追加不変条件を課す。
  4. argv が静的に追跡できない場合（変数経由・keyword のみ 等）は
     **例外リストに載っていない限り violation**（fail-closed）。
  5. import 形は AST で解決してから照合する（`import subprocess as sp` /
     `from subprocess import run` / `from subprocess import check_output as co`
     も同一扱い）。解決できない import 形（star import 等）は fail-closed。
  6. **動的属性アクセス / 動的コード生成は全モジュールで禁止**（R1-A-1 / A-2）。
     `getattr(os, "system")` は属性トークンとして解決して判定し、
     `getattr(os, "sys" + "tem")` のように**第 2 引数がリテラルでない**場合は
     解決不能として fail-closed で violation にする（不変条件 4 と同じ原則を
     実行系トークン検出全体へ一貫適用する）。`eval` / `exec` / `compile` は
     AST 静的検査と原理的に相容れないため **`gh_exec.py` を含む全モジュールで**
     一律 deny。
  7. **束縛は代入を伝播する**（R2-a-1 / 根本是正）。トークン判定の基底を
     `import` 文だけから作ると `_run = subprocess.run` / `_os = os` の
     **1 行の代入**で 1〜3・6 の全検査が迂回できる。`Assign` / `AnnAssign` /
     `AugAssign` の右辺、タプル代入・多重代入、および**関数のデフォルト引数**
     （`def f(runner=subprocess.run)`）を不動点まで伝播させ、別名を元の
     dotted path と同一視する。
  8. **既定は fail-closed**（R2-a-2 / 根本是正）。「静的に解決できない＝
     トークンでない」ではなく「静的に解決できない＝violation」を既定にする。
     ただし通常の `self.foo()` / ローカルオブジェクトのメソッド呼び出しまで
     violation にすると偽陽性で開発が止まるため、**間接的に実行能力を取得
     しうる形**へ適用範囲を限定する:
       (a) `__dict__` / `__globals__` 等の**イントロスペクション属性**は
           「解決可能なモジュール + 文字列リテラル添字」以外すべて violation
           （`os.__dict__["system"]` は `os.system` として解決する）
       (b) 基底が解決できない属性参照のうち、属性名が**実行系の名前**
           （`system` / `popen` / `run` / `Popen` / `exec*` / `spawn*` 等）に
           一致するもの
       (c) 基底が解決できない `getattr(x, "<実行系の名前>")`
       (d) `gh_exec.py` **のみ**さらに厳格に、**呼び出し先が静的に解決できない
           bare name 呼び出し**を violation にする（唯一の外部作用境界であり、
           小さく統制されているため成立する）。例外は
           `GH_EXEC_INDIRECT_CALL_EXCEPTIONS` に**凍結**して列挙する

**substring 走査は使わない**: `discovery.py` の docstring には「subprocess での
gh 呼び出し禁止」という宣言文が実在し、grep 方式では偽陽性になる。

限界（scope の明示）: 本検査器は **この Python プロセス経由の作用**の構造しか
守らない。同一セッションの Bash や別プロセスからの `gh pr merge` は塞がらない
（plan「⚠️ 回避不能なギャップ（AC-5 の scope 明示）」と同じ限界）。

CLI:
    python3 scripts/ai-loop/check_exec_boundary.py [--dir <path>]

exit code:
    0 = 違反なし / 1 = 違反あり（違反箇所を stdout に出力）
"""

from __future__ import annotations

import argparse
import ast
import pathlib
import sys

# ---------------------------------------------------------------------------
# 契約定数
# ---------------------------------------------------------------------------

#: 唯一 `subprocess` を持ってよいモジュール（逆向きホワイトリスト検査の対象）。
GH_EXEC_MODULE = "gh_exec.py"

#: argv 先頭が "git" のとき、続くサブコマンドとして恒久的に許容する読み取り専用集合。
GIT_READONLY_SUBCOMMANDS = frozenset({
    "status", "rev-parse", "diff", "log", "merge-base", "ls-remote", "show",
})

#: argv 検査の対象となる subprocess のエントリポイント。
SUBPROCESS_ENTRY_POINTS = frozenset({
    "run", "check_output", "Popen", "call", "check_call",
    "getoutput", "getstatusoutput",
})

#: grandfather 例外（**1 件から増やさない**）。(ファイル名, 関数名) で特定する。
#: `test_c3prime_verify.py` の `_run()` が組み立てる `args = ["python3", ...]` は
#: PATH 依存で実行中インタプリタと一致しない潜在不具合であり、正当化ではなく
#: **凍結**として扱う（`sys.executable` 化は V2 候補）。
GRANDFATHER_ARGV_EXCEPTIONS = (
    ("test_c3prime_verify.py", "_run"),
)

#: import しただけで違反となるモジュール root（実行系 / ネットワーク）。
#: `pty` / `ctypes` / `multiprocessing` は難読化なしの直書きで
#: `pty.spawn(["gh","pr","merge","1"])` / `ctypes.CDLL("libc").system(...)` /
#: `multiprocessing` 経由の子プロセス起動を作れるため root ごと deny する（R1-A-3）。
FORBIDDEN_MODULE_ROOTS = ("urllib", "socket", "http", "requests",
                          "pty", "ctypes", "multiprocessing")

#: `os` の実行系属性（完全一致 / prefix）。
#: `posix_spawn` / `posix_spawnp` / `forkpty` は prefix ("exec"/"spawn") に
#: 当たらないため**完全一致側**に載せる（R1-A-3）。
OS_EXEC_ATTRS = ("system", "popen", "posix_spawn", "posix_spawnp", "forkpty")
OS_EXEC_PREFIXES = ("exec", "spawn")

#: `asyncio` 経由の子プロセス起動（R1-A-3）。
ASYNCIO_EXEC_ATTRS = ("create_subprocess_exec", "create_subprocess_shell")

#: 動的コード生成の builtin。**`gh_exec.py` を含む全モジュールで** deny する
#: （AST 静的検査と原理的に相容れないため / R1-A-2）。
DYNAMIC_CODE_BUILTINS = ("eval", "exec", "compile")

#: 動的属性アクセスの builtin（第 2 引数が文字列リテラルなら属性トークンとして
#: 解決し、リテラルでなければ fail-closed で violation にする / R1-A-1）。
DYNAMIC_ATTR_BUILTIN = "getattr"

#: `gh_exec.py` 内で `subprocess` を呼んでよい唯一のプライベート実行関数。
GH_EXEC_SPAWN_FUNC = "_spawn"

#: `GH_EXEC_SPAWN_FUNC` を呼んでよい入口関数（**この 3 件から増やさない**）。
#: `push_pr_head` は allowlist ではなく構造化 API（`build_push_argv()` が argv を
#: 自ら組み立てる）経路であり、`run_gh` / `run_git` と同格の監査済み入口である。
GH_EXEC_SPAWN_CALLERS = ("run_gh", "run_git", "push_pr_head")

#: イントロスペクション属性。**解決可能なモジュール + 文字列リテラル添字**
#: （`os.__dict__["system"]`）以外は一律 fail-closed（不変条件 8(a) / R2-a-2）。
#: `__slots__` / `__repr__` / `__name__` 等の宣言・メタ情報系は含めない。
INTROSPECTION_ATTRS = frozenset({
    "__dict__", "__globals__", "__builtins__", "__subclasses__",
    "__getattribute__", "__code__", "__bases__", "__mro__", "__loader__",
    "__closure__", "__func__", "__self__", "__wrapped__",
})

#: `os` の exec / spawn ファミリ（**完全一致**）。基底が解決できない属性参照に
#: 使う。prefix 一致（`OS_EXEC_PREFIXES`）をそのまま使うと `cursor.execute()` の
#: ような無害な呼び出しを誤検出するため、族を明示列挙する。
OS_EXEC_FAMILY = (
    "execl", "execle", "execlp", "execlpe",
    "execv", "execve", "execvp", "execvpe",
    "spawnl", "spawnle", "spawnlp", "spawnlpe",
    "spawnv", "spawnve", "spawnvp", "spawnvpe",
    "forkpty", "posix_spawn", "posix_spawnp",
)

#: 基底が静的に解決できないときに fail-closed とする属性名（不変条件 8(b)/(c)）。
#: **「その名前自体が実行能力を指す」ものだけ**を載せる。
#: `run` / `call` / `fork` を**載せない**のは、`R(1).run()`（ローカル dataclass の
#: メソッド）や `repo.fork()` のような正当な呼び出しと区別できず偽陽性になるため。
#: 別名経由の `subprocess.run`（`_run = subprocess.run`）は本層ではなく
#: **束縛伝播（不変条件 7）が解決して**捕捉するので、検出力は落ちない。
INDIRECT_EXEC_ATTRS = frozenset(
    OS_EXEC_ATTRS + ASYNCIO_EXEC_ATTRS + OS_EXEC_FAMILY
    + ("Popen", "check_output", "check_call", "getoutput", "getstatusoutput",
       "CDLL", "LoadLibrary", "import_module", "__import__"))

#: `gh_exec.py` で bare name 呼び出しの静的解決を免除する (関数名, 呼び出し名)。
#: **この 1 件から増やさない**（`GRANDFATHER_ARGV_EXCEPTIONS` と同じ凍結方式）。
#: `authorize_gh()` は rule table の condition 関数列（`GH_RULES` に載る
#: module-local な `_c_*`）を反復適用するため、呼び出し先がループ変数になる。
#: 解消には `gh_exec.py` 側の構造変更が要るため、本 PBI では**凍結**して扱う。
GH_EXEC_INDIRECT_CALL_EXCEPTIONS = (
    ("authorize_gh", "condition"),
)

#: `gh_exec.py` の bare name 呼び出しで静的解決済みとみなす builtin。
#: `dir(builtins)` を使わない（`eval` / `getattr` / `__import__` を巻き込むため）。
SAFE_BUILTIN_CALLS = frozenset({
    "bool", "bytes", "dict", "enumerate", "float", "format", "frozenset", "int",
    "isinstance", "issubclass", "iter", "len", "list", "max", "min", "next",
    "range", "repr", "reversed", "set", "sorted", "str", "sum", "tuple", "zip",
    "all", "any", "abs", "print", "super", "ValueError", "TypeError",
    "KeyError", "IndexError", "RuntimeError", "NotImplementedError",
    "AssertionError", "OSError", "Exception",
})

#: 代入伝播の不動点反復の上限（`a = b`, `b = c` の連鎖長の安全側上限）。
MAX_PROPAGATION_ROUNDS = 8

# 違反コード
CODE_EXEC_TOKEN = "EXEC_TOKEN"
CODE_GH_EXEC_EXTRA_TOKEN = "GH_EXEC_EXTRA_TOKEN"
CODE_GH_EXEC_SHELL = "GH_EXEC_SHELL"
CODE_GH_EXEC_SPAWN_SITE = "GH_EXEC_SPAWN_SITE"
CODE_GH_EXEC_SPAWN_CALLER = "GH_EXEC_SPAWN_CALLER"
CODE_GH_EXEC_INDIRECT_CALL = "GH_EXEC_INDIRECT_CALL"
CODE_ARGV_HEAD = "ARGV_HEAD"
CODE_ARGV_UNRESOLVED = "ARGV_UNRESOLVED"
CODE_DYNAMIC_UNRESOLVED = "DYNAMIC_UNRESOLVED"
CODE_INDIRECT_EXEC = "INDIRECT_EXEC"
CODE_IMPORT_UNRESOLVED = "IMPORT_UNRESOLVED"
CODE_SYNTAX = "SYNTAX"


class Violation:
    """1 件の違反。`path`（表示名）/ `line` / `code` / `detail`。"""

    __slots__ = ("path", "line", "code", "detail")

    def __init__(self, path: str, line: int, code: str, detail: str) -> None:
        self.path = path
        self.line = line
        self.code = code
        self.detail = detail

    def __repr__(self) -> str:  # テスト失敗時の可読性のため
        return f"{self.path}:{self.line}: [{self.code}] {self.detail}"

    def __eq__(self, other) -> bool:
        if not isinstance(other, Violation):
            return NotImplemented
        return (self.path, self.line, self.code, self.detail) == (
            other.path, other.line, other.code, other.detail)


# ---------------------------------------------------------------------------
# import 解決（AC: 別名 / 直接 import も同一扱い）
# ---------------------------------------------------------------------------

class _Bindings:
    """モジュール内のローカル名 → 正規 import パスの束縛表。

    import だけでなく**代入の右辺も伝播**する（不変条件 7 / R2-a-1）。
    `_run = subprocess.run` のような 1 行の別名付けで検査が迂回されるのを防ぐ。
    """

    def __init__(self) -> None:
        self.modules: dict[str, str] = {}      # 名前 → モジュール dotted path
        self.functions: dict[str, str] = {}    # 名前 → "module.attr" dotted path

    def bind(self, local: str, dotted: str) -> bool:
        """`local` を `dotted` の別名として登録する。変化があれば True。"""
        changed = False
        if self.modules.get(local) != dotted:
            self.modules[local] = dotted
            changed = True
        if self.functions.get(local) != dotted:
            self.functions[local] = dotted
            changed = True
        return changed

    def resolve(self, node):
        """`Name` / `Attribute` チェーンを dotted path へ解決する（不能なら None）。"""
        if isinstance(node, ast.Name):
            return self.modules.get(node.id) or self.functions.get(node.id)
        if isinstance(node, ast.Attribute):
            base = self.resolve(node.value)
            return f"{base}.{node.attr}" if base else None
        return None


def _unpack_targets(target, value):
    """(target, value) を分解する。タプル / リストの要素数一致時のみ対応付ける。"""
    if isinstance(target, (ast.Tuple, ast.List)):
        if isinstance(value, (ast.Tuple, ast.List)) and len(target.elts) == len(value.elts):
            for sub_target, sub_value in zip(target.elts, value.elts):
                yield from _unpack_targets(sub_target, sub_value)
        return
    yield (target, value)


def _assignment_pairs(node):
    """`Assign` / `AnnAssign` / `AugAssign` から (target, value) を列挙する。

    多重代入（`a = b = os`）は `node.targets` の各要素へ、タプル代入
    （`a, b = os, sys`）は要素数一致時に要素ごとへ展開する。
    """
    if isinstance(node, ast.Assign):
        for target in node.targets:
            yield from _unpack_targets(target, node.value)
    elif isinstance(node, ast.AnnAssign) and node.value is not None:
        yield from _unpack_targets(node.target, node.value)
    elif isinstance(node, ast.AugAssign):
        yield from _unpack_targets(node.target, node.value)


def _default_pairs(func):
    """関数のデフォルト引数から (引数名, デフォルト式) を列挙する。

    `def f(runner=subprocess.run)` を代入と同等に扱う（不変条件 7）。
    """
    args = func.args
    positional = list(getattr(args, "posonlyargs", [])) + list(args.args)
    if args.defaults:
        for arg, default in zip(positional[len(positional) - len(args.defaults):],
                                args.defaults):
            yield (arg.arg, default)
    for arg, default in zip(args.kwonlyargs, args.kw_defaults):
        if default is not None:
            yield (arg.arg, default)


def _propagate_bindings(tree, binds: _Bindings) -> bool:
    """代入 / デフォルト引数を 1 巡だけ伝播する。変化があれば True。"""
    changed = False
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            for local, default in _default_pairs(node):
                dotted = binds.resolve(default)
                if dotted and binds.bind(local, dotted):
                    changed = True
            continue
        for target, value in _assignment_pairs(node):
            if not isinstance(target, ast.Name):
                continue
            dotted = binds.resolve(value)
            if dotted and binds.bind(target.id, dotted):
                changed = True
    return changed


def _collect_bindings(tree, violations, name):
    """import + 代入伝播で束縛表を作り、解決不能な形（star import）を fail-closed で記録。"""
    binds = _Bindings()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                local = alias.asname or alias.name.split(".")[0]
                target = alias.name if alias.asname else alias.name.split(".")[0]
                binds.modules[local] = target
        elif isinstance(node, ast.ImportFrom):
            module = node.module or ""
            for alias in node.names:
                if alias.name == "*":
                    if module.split(".")[0] in (
                            "subprocess", "os", "importlib") + FORBIDDEN_MODULE_ROOTS:
                        violations.append(Violation(
                            name, node.lineno, CODE_IMPORT_UNRESOLVED,
                            f"解決できない import 形（fail-closed）: from {module} import *"))
                    continue
                local = alias.asname or alias.name
                dotted = f"{module}.{alias.name}" if module else alias.name
                binds.functions[local] = dotted
                # `from urllib import request` のようにモジュールを直接束縛する形も拾う
                binds.modules.setdefault(local, dotted)
    # 代入の連鎖（`a = os` → `b = a`）を不動点まで伝播する。
    for _round in range(MAX_PROPAGATION_ROUNDS):
        if not _propagate_bindings(tree, binds):
            break
    return binds


def _enclosing_functions(tree):
    """各ノード → 最も内側の関数名（無ければ None）の対応表を作る。"""
    mapping: dict[int, str | None] = {}

    def visit(node, fname):
        for child in ast.iter_child_nodes(node):
            if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef)):
                mapping[id(child)] = fname
                visit(child, child.name)
            else:
                mapping[id(child)] = fname
                visit(child, fname)

    visit(tree, None)
    return mapping


# ---------------------------------------------------------------------------
# トークン判定
# ---------------------------------------------------------------------------

def _module_token(dotted: str):
    """dotted path が実行系トークンなら正規化名を返す（該当なしは None）。"""
    root = dotted.split(".")[0]
    if root == "subprocess":
        return "subprocess"
    if root == "http":
        return "http.client"
    if root in FORBIDDEN_MODULE_ROOTS:
        return root
    if dotted == "importlib.import_module":
        return "importlib.import_module"
    if root == "os":
        rest = dotted.split(".")[1:]
        if rest:
            attr = rest[0]
            if attr in OS_EXEC_ATTRS or any(attr.startswith(p) for p in OS_EXEC_PREFIXES):
                return f"os.{attr}"
    if root == "asyncio":
        rest = dotted.split(".")[1:]
        if rest and rest[0] in ASYNCIO_EXEC_ATTRS:
            return f"asyncio.{rest[0]}"
    return None


def _attribute_token(node, binds: _Bindings):
    """`X.attr` 形の実行系トークンを解決する（X は束縛名 / 属性チェーン）。

    `_Bindings.resolve` を使うため、`import` 由来の名前だけでなく**代入で
    伝播した別名**（`_os = os` の `_os.system`）も解決できる（R2-a-1）。
    """
    target = binds.resolve(node.value)
    if target is None:
        return None
    return _module_token(f"{target}.{node.attr}")


def _resolves_to_module(node, binds: _Bindings, module: str) -> bool:
    return (isinstance(node, ast.Name)
            and binds.modules.get(node.id, "").split(".")[0] == module)


def _is_sys_executable(node, binds: _Bindings) -> bool:
    return (isinstance(node, ast.Attribute) and node.attr == "executable"
            and _resolves_to_module(node.value, binds, "sys"))


def _getattr_token(node, binds: _Bindings):
    """`getattr(mod, "attr")` を属性トークンとして解決する（R1-A-1）。

    戻り値は `(token, resolvable)`:
      - 第 2 引数が**文字列リテラル**なら静的に解決し `(token or None, True)`
      - リテラルでない（変数 / 文字列連結 / f-string 等）なら `(None, False)`
        ＝ **fail-closed で violation** にする（不変条件 4 と同じ原則）
    """
    if len(node.args) < 2:
        return (None, False)
    attr_node = node.args[1]
    if not (isinstance(attr_node, ast.Constant) and isinstance(attr_node.value, str)):
        return (None, False)
    target = binds.resolve(node.args[0])
    if target is None:
        # 基底が解決できない。既定を fail-closed へ反転する（R2-a-2 / 不変条件 8(c)）:
        # 属性名が実行能力そのものの名前なら violation、無害な名前
        # （`getattr(proc, "returncode", 1)` 等）は従来どおり通す。
        if attr_node.value in INDIRECT_EXEC_ATTRS:
            return (f"?.{attr_node.value}（基底が静的に解決できない）", True)
        return (None, True)
    return (_module_token(f"{target}.{attr_node.value}"), True)


def _introspection_subscripts(tree):
    """`X.__dict__["literal"]` の形を (Attribute ノード id → キー文字列) で返す。

    この形**だけ**が静的に解決可能なイントロスペクションであり、それ以外
    （キーが非リテラル / 添字を伴わない参照）は fail-closed で violation にする。
    """
    resolved: dict[int, str] = {}
    for node in ast.walk(tree):
        if not isinstance(node, ast.Subscript):
            continue
        base = node.value
        if not (isinstance(base, ast.Attribute) and base.attr in INTROSPECTION_ATTRS):
            continue
        key = node.slice
        if isinstance(key, ast.Constant) and isinstance(key.value, str):
            resolved[id(base)] = key.value
    return resolved


def _collect_exec_tokens(tree, binds: _Bindings):
    """(lineno, token) のリストを返す。import 形と属性呼び出し形の両方を拾う。

    `getattr` による動的属性アクセスと `eval` / `exec` / `compile` による動的
    コード生成も対象（R1-A-1 / A-2）。前者はリテラル解決できなければ
    fail-closed、後者は無条件に violation とする。
    """
    found = []
    introspection = _introspection_subscripts(tree)
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                token = _module_token(alias.name)
                if token:
                    found.append((node.lineno, token))
        elif isinstance(node, ast.ImportFrom):
            module = node.module or ""
            for alias in node.names:
                if alias.name == "*":
                    continue
                dotted = f"{module}.{alias.name}" if module else alias.name
                token = _module_token(dotted)
                if token:
                    found.append((node.lineno, token))
        elif isinstance(node, ast.Attribute):
            if node.attr in INTROSPECTION_ATTRS:
                # `os.__dict__["system"]` を `os.system` として解決する
                # （解決できない形は `_collect_dynamic_unresolved` が fail-closed）。
                key = introspection.get(id(node))
                target = binds.resolve(node.value)
                if key is not None and target is not None:
                    token = _module_token(f"{target}.{key}")
                    if token:
                        found.append((node.lineno, f"{node.attr} 経由: {token}"))
                continue
            token = _attribute_token(node, binds)
            if token:
                found.append((node.lineno, token))
            elif (binds.resolve(node.value) is None
                  and node.attr in INDIRECT_EXEC_ATTRS):
                # 基底が解決できない属性参照。既定を fail-closed へ反転する
                # （R2-a-2 / 不変条件 8(b)）。属性名が実行能力そのものの名前の
                # ときだけ倒すことで `proc.returncode` 等の偽陽性を出さない。
                found.append((node.lineno,
                              f"?.{node.attr}（基底が静的に解決できない）"))
        elif isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
            if node.func.id == "__import__":
                found.append((node.lineno, "__import__"))
            elif node.func.id in DYNAMIC_CODE_BUILTINS:
                found.append((node.lineno, f"{node.func.id}()"))
            elif node.func.id == DYNAMIC_ATTR_BUILTIN:
                token, _resolvable = _getattr_token(node, binds)
                if token:
                    found.append((node.lineno, f"{DYNAMIC_ATTR_BUILTIN} 経由: {token}"))
    return found


def _collect_dynamic_unresolved(tree, binds: _Bindings, name: str):
    """静的に解決できない動的参照を fail-closed の Violation として返す。

    - `getattr` の属性名が文字列リテラルでない（R1-A-1）
    - イントロスペクション属性（`__dict__` 等）が「解決可能な基底 + 文字列
      リテラル添字」以外の形で現れる（R2-a-2 / 不変条件 8(a)）
    """
    violations = []
    introspection = _introspection_subscripts(tree)
    for node in ast.walk(tree):
        if isinstance(node, ast.Attribute) and node.attr in INTROSPECTION_ATTRS:
            if introspection.get(id(node)) is None or binds.resolve(node.value) is None:
                violations.append(Violation(
                    name, node.lineno, CODE_INDIRECT_EXEC,
                    f"イントロスペクション属性 {node.attr} による間接参照"
                    "（解決可能なモジュール + 文字列リテラル添字 以外は fail-closed）"))
            continue
        if not (isinstance(node, ast.Call) and isinstance(node.func, ast.Name)):
            continue
        if node.func.id != DYNAMIC_ATTR_BUILTIN:
            continue
        _token, resolvable = _getattr_token(node, binds)
        if not resolvable:
            violations.append(Violation(
                name, node.lineno, CODE_DYNAMIC_UNRESOLVED,
                "getattr の属性名が文字列リテラルでない（静的追跡不能 / fail-closed）"))
    return violations


# ---------------------------------------------------------------------------
# gh_exec.py 内部の構造規律（R1-A-4 / 逆向きホワイトリストの深化）
# ---------------------------------------------------------------------------

def _shell_kwarg_verdict(call):
    """`shell=` キーワードを検査する。OK なら None、違反なら detail 文字列。"""
    for keyword in call.keywords:
        if keyword.arg is None:
            return ("subprocess 呼び出しに **kwargs 展開があり shell=True を"
                    "静的に否定できない（fail-closed）")
        if keyword.arg != "shell":
            continue
        value = keyword.value
        if isinstance(value, ast.Constant) and value.value is False:
            continue
        if isinstance(value, ast.Constant):
            return f"subprocess 呼び出しに shell={value.value!r} が渡されている"
        return "shell= の値がリテラルでない（静的追跡不能 / fail-closed）"
    return None


def _local_definitions(tree) -> set:
    """モジュール内で定義される関数 / クラス名（ネストを含む）を返す。"""
    return {node.name for node in ast.walk(tree)
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef))}


def _gh_exec_indirect_calls(tree, binds: _Bindings, name: str, exceptions=None):
    """`gh_exec.py` の **呼び出し先が静的に解決できない** bare name 呼び出しを検出する。

    唯一の外部作用境界に対して**既定を fail-closed へ反転**する
    （R2-a-2 / 不変条件 8(d)）。`gh_exec.py` は小さく統制されているため
    「呼び出し先はモジュール内定義 / import 由来 / 安全 builtin のいずれか」を
    要求できる。属性呼び出し（`path.unlink()` 等）は対象外にして偽陽性を防ぎ、
    そちらは `INDIRECT_EXEC_ATTRS` による fail-closed が受け持つ。
    """
    # 既定値は**呼び出し時**に解決する（`def` 時に束縛すると、凍結リストを
    # 差し替える変異注入テストが素通りして検出力を実証できなくなる）。
    if exceptions is None:
        exceptions = GH_EXEC_INDIRECT_CALL_EXCEPTIONS
    violations = []
    known = _local_definitions(tree) | set(binds.modules) | set(binds.functions)
    scopes = _enclosing_functions(tree)
    exempt = set(exceptions)
    for node in ast.walk(tree):
        if not (isinstance(node, ast.Call) and isinstance(node.func, ast.Name)):
            continue
        callee = node.func.id
        if callee in known or callee in SAFE_BUILTIN_CALLS:
            continue
        if callee in DYNAMIC_CODE_BUILTINS or callee == DYNAMIC_ATTR_BUILTIN:
            continue  # 専用の deny 経路（`_collect_exec_tokens`）が既に扱う
        if (scopes.get(id(node)), callee) in exempt:
            continue
        violations.append(Violation(
            name, node.lineno, CODE_GH_EXEC_INDIRECT_CALL,
            f"呼び出し先が静的に解決できない（fail-closed）: {callee}()"))
    return violations


def _gh_exec_discipline(tree, binds: _Bindings, name: str):
    """`gh_exec.py` 内部の subprocess 呼び出しサイトを AST で列挙して検査する。

    語（`subprocess` の有無）だけを見る逆向きホワイトリストでは、唯一の境界の
    **内部**に `subprocess.run(cmd, shell=True)` のような無検査の抜け道が残る。
    """
    violations = []
    scopes = _enclosing_functions(tree)
    for call in _subprocess_call_sites(tree, binds):
        detail = _shell_kwarg_verdict(call)
        if detail is not None:
            violations.append(Violation(name, call.lineno, CODE_GH_EXEC_SHELL, detail))
        enclosing = scopes.get(id(call))
        if enclosing != GH_EXEC_SPAWN_FUNC:
            violations.append(Violation(
                name, call.lineno, CODE_GH_EXEC_SPAWN_SITE,
                f"subprocess の呼び出しは {GH_EXEC_SPAWN_FUNC}() に限る"
                f"（実際の関数: {enclosing!r}）"))
    for node in ast.walk(tree):
        if not (isinstance(node, ast.Call) and isinstance(node.func, ast.Name)):
            continue
        if node.func.id != GH_EXEC_SPAWN_FUNC:
            continue
        enclosing = scopes.get(id(node))
        if enclosing not in GH_EXEC_SPAWN_CALLERS:
            violations.append(Violation(
                name, node.lineno, CODE_GH_EXEC_SPAWN_CALLER,
                f"{GH_EXEC_SPAWN_FUNC}() の呼び出し元は "
                f"{list(GH_EXEC_SPAWN_CALLERS)} に限る（実際の関数: {enclosing!r}）"))
    return violations


# ---------------------------------------------------------------------------
# argv 先頭要素 不変条件
# ---------------------------------------------------------------------------

def _subprocess_call_sites(tree, binds: _Bindings):
    """subprocess のエントリポイント呼び出しノードを列挙する（別名 / 直接 import 解決済）。"""
    sites = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        func = node.func
        if isinstance(func, ast.Attribute):
            if (_resolves_to_module(func.value, binds, "subprocess")
                    and func.attr in SUBPROCESS_ENTRY_POINTS):
                sites.append(node)
        elif isinstance(func, ast.Name):
            dotted = binds.functions.get(func.id)
            if dotted and dotted.split(".")[0] == "subprocess":
                if dotted.split(".")[-1] in SUBPROCESS_ENTRY_POINTS:
                    sites.append(node)
    return sites


def _argv_verdict(call, binds: _Bindings):
    """argv 先頭要素を評価する。OK なら None、違反なら (code, detail)。"""
    if not call.args:
        return (CODE_ARGV_UNRESOLVED,
                "argv が位置引数で渡されていない（静的追跡不能 / fail-closed）")
    first = call.args[0]
    if not isinstance(first, (ast.List, ast.Tuple)):
        return (CODE_ARGV_UNRESOLVED,
                "argv がリテラルの list/tuple でない（静的追跡不能 / fail-closed）")
    if not first.elts:
        return (CODE_ARGV_HEAD, "argv が空")
    head = first.elts[0]
    if isinstance(head, ast.Starred):
        return (CODE_ARGV_UNRESOLVED, "argv 先頭が unpack（静的追跡不能 / fail-closed）")
    if _is_sys_executable(head, binds):
        return None
    if isinstance(head, ast.Constant) and isinstance(head.value, str):
        if head.value != "git":
            return (CODE_ARGV_HEAD,
                    f"argv 先頭要素が sys.executable でも git でもない: {head.value!r}")
        if len(first.elts) < 2:
            return (CODE_ARGV_HEAD, "git のサブコマンドが無い")
        sub = first.elts[1]
        if not (isinstance(sub, ast.Constant) and isinstance(sub.value, str)):
            return (CODE_ARGV_UNRESOLVED,
                    "git サブコマンドがリテラルでない（静的追跡不能 / fail-closed）")
        if sub.value not in GIT_READONLY_SUBCOMMANDS:
            return (CODE_ARGV_HEAD,
                    f"読み取り専用 git allowlist 外のサブコマンド: {sub.value!r}")
        return None
    return (CODE_ARGV_UNRESOLVED,
            "argv 先頭要素が静的に解決できない（fail-closed）")


# ---------------------------------------------------------------------------
# 検査本体
# ---------------------------------------------------------------------------

def check_source(name: str, source: str,
                 grandfather=GRANDFATHER_ARGV_EXCEPTIONS) -> list:
    """1 ファイル分のソースを検査し Violation のリストを返す（純関数）。

    `name` は表示名かつ判定キー（`gh_exec.py` / `test_*.py` の分岐と
    grandfather 例外の照合に使う）。ファイル I/O は行わない。
    """
    name = pathlib.PurePath(name).name
    violations: list = []
    try:
        tree = ast.parse(source)
    except SyntaxError as exc:
        return [Violation(name, exc.lineno or 0, CODE_SYNTAX,
                          f"parse できない（fail-closed）: {exc.msg}")]

    binds = _collect_bindings(tree, violations, name)
    is_gh_exec = name == GH_EXEC_MODULE
    is_test = name.startswith("test_")

    for lineno, token in _collect_exec_tokens(tree, binds):
        if token == "subprocess":
            if is_gh_exec or is_test:
                continue
            violations.append(Violation(
                name, lineno, CODE_EXEC_TOKEN,
                f"{GH_EXEC_MODULE} 以外での実行系トークン: {token}"))
        elif is_gh_exec:
            violations.append(Violation(
                name, lineno, CODE_GH_EXEC_EXTRA_TOKEN,
                f"{GH_EXEC_MODULE} で許可されるのは subprocess のみ: {token}"))
        else:
            violations.append(Violation(
                name, lineno, CODE_EXEC_TOKEN,
                f"{GH_EXEC_MODULE} 以外での実行系トークン: {token}"))

    violations.extend(_collect_dynamic_unresolved(tree, binds, name))

    if is_gh_exec:
        violations.extend(_gh_exec_discipline(tree, binds, name))
        violations.extend(_gh_exec_indirect_calls(tree, binds, name))

    if is_test:
        scopes = _enclosing_functions(tree)
        exempt = {(pathlib.PurePath(f).name, fn) for f, fn in grandfather}
        for call in _subprocess_call_sites(tree, binds):
            verdict = _argv_verdict(call, binds)
            if verdict is None:
                continue
            if (name, scopes.get(id(call))) in exempt:
                continue
            code, detail = verdict
            violations.append(Violation(name, call.lineno, code, detail))

    violations.sort(key=lambda v: (v.line, v.code, v.detail))
    return violations


def check_paths(paths, grandfather=GRANDFATHER_ARGV_EXCEPTIONS) -> list:
    """複数ファイルを検査して Violation のリストを返す。"""
    violations: list = []
    for path in paths:
        p = pathlib.Path(path)
        violations.extend(
            check_source(p.name, p.read_text(encoding="utf-8"), grandfather))
    return violations


def default_targets(root=None) -> list:
    """既定の検査対象（`scripts/ai-loop/*.py`）を返す。"""
    base = pathlib.Path(root) if root else pathlib.Path(__file__).resolve().parent
    return sorted(base.glob("*.py"))


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="ai-loop の実行系境界を AST で検査する（substring 走査は使わない）")
    parser.add_argument("--dir", default=None,
                        help="検査対象ディレクトリ（既定: 本スクリプトのディレクトリ）")
    opts = parser.parse_args(argv)

    targets = default_targets(opts.dir)
    violations = check_paths(targets)
    if violations:
        print(f"check_exec_boundary: {len(violations)} 件の違反", file=sys.stdout)
        for v in violations:
            print(f"  {v}", file=sys.stdout)
        return 1
    print(f"check_exec_boundary: clean（{len(targets)} ファイル / 違反 0）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
