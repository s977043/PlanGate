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

# 違反コード
CODE_EXEC_TOKEN = "EXEC_TOKEN"
CODE_GH_EXEC_EXTRA_TOKEN = "GH_EXEC_EXTRA_TOKEN"
CODE_GH_EXEC_SHELL = "GH_EXEC_SHELL"
CODE_GH_EXEC_SPAWN_SITE = "GH_EXEC_SPAWN_SITE"
CODE_GH_EXEC_SPAWN_CALLER = "GH_EXEC_SPAWN_CALLER"
CODE_ARGV_HEAD = "ARGV_HEAD"
CODE_ARGV_UNRESOLVED = "ARGV_UNRESOLVED"
CODE_DYNAMIC_UNRESOLVED = "DYNAMIC_UNRESOLVED"
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
    """モジュール内のローカル名 → 正規 import パスの束縛表。"""

    def __init__(self) -> None:
        self.modules: dict[str, str] = {}      # 名前 → モジュール dotted path
        self.functions: dict[str, str] = {}    # 名前 → "module.attr" dotted path


def _collect_bindings(tree, violations, name):
    """import 文を走査して束縛表を作り、解決不能な形（star import）を fail-closed で記録。"""
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
    """`X.attr` 形の実行系トークンを解決する（X はローカル束縛名）。"""
    if not isinstance(node.value, ast.Name):
        return None
    target = binds.modules.get(node.value.id)
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
    base = node.args[0]
    if not isinstance(base, ast.Name):
        return (None, True)
    target = binds.modules.get(base.id)
    if target is None:
        return (None, True)
    return (_module_token(f"{target}.{attr_node.value}"), True)


def _collect_exec_tokens(tree, binds: _Bindings):
    """(lineno, token) のリストを返す。import 形と属性呼び出し形の両方を拾う。

    `getattr` による動的属性アクセスと `eval` / `exec` / `compile` による動的
    コード生成も対象（R1-A-1 / A-2）。前者はリテラル解決できなければ
    fail-closed、後者は無条件に violation とする。
    """
    found = []
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
            token = _attribute_token(node, binds)
            if token:
                found.append((node.lineno, token))
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
    """静的に解決できない `getattr` を fail-closed の Violation として返す（R1-A-1）。"""
    violations = []
    for node in ast.walk(tree):
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
