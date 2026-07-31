#!/usr/bin/env python3
"""check_exec_boundary.py — ai-loop の実行系境界を AST で機械強制する検査器（TASK-0917 / #917）。

契約正本: docs/working/TASK-0917/plan.md「D2-A の設計詳細（実装契約）」および
「`test_*.py` の argv 先頭要素 不変条件（精緻化 / C-1 F-1 の裁定）」。

不変条件:
  1. `gh_exec.py` **以外**のモジュールは実行系トークンを持たない
     （`subprocess` / `os.system` / `os.popen` / `os.exec*` / `os.spawn*` /
     `urllib` / `socket` / `http.client` / `requests` /
     `importlib.import_module` による動的 import）。
  2. `gh_exec.py` は「除外」ではなく **逆向きホワイトリスト検査**にかける。
     `subprocess` **のみ**許可し、その他の実行系トークンは 0 件であること
     （除外にすると唯一の実行境界そのものが無検査になり、`gh_exec.py` 内の
     `os.system("gh pr merge 1")` を止めるものが存在しなくなる）。
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
FORBIDDEN_MODULE_ROOTS = ("urllib", "socket", "http", "requests")

#: `os` の実行系属性（完全一致 / prefix）。
OS_EXEC_ATTRS = ("system", "popen")
OS_EXEC_PREFIXES = ("exec", "spawn")

# 違反コード
CODE_EXEC_TOKEN = "EXEC_TOKEN"
CODE_GH_EXEC_EXTRA_TOKEN = "GH_EXEC_EXTRA_TOKEN"
CODE_ARGV_HEAD = "ARGV_HEAD"
CODE_ARGV_UNRESOLVED = "ARGV_UNRESOLVED"
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


def _collect_exec_tokens(tree, binds: _Bindings):
    """(lineno, token) のリストを返す。import 形と属性呼び出し形の両方を拾う。"""
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
    return found


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
