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
  9. **添字式（`ast.Subscript`）も束縛解決の対象にする**（R3-1）。
     属性アクセス（`ast.Attribute`）だけを解決対象にすると、意味が同じでも
     AST の形が違うだけで検査の視野外になる:
       - `vars(os)["system"]` は `os.system` と同一（`__dict__` 経路と等価）
       - `sys.modules["subprocess"]` は `subprocess` モジュールそのもの
       - `globals()["subprocess"]` はモジュール内束縛名の参照
     これらを `resolve()` で dotted path に畳み込み、加えて
     **基底が静的に解決できない添字式の呼び出し**（`x[k](...)`）と
     **「解決可能な名前空間 + 文字列リテラル添字」の形になっていない
     `vars` / `globals` / `locals` / `dir`**・`sys.modules` 参照を
     fail-closed で violation にする（不変条件 8 と同じ原則の添字版）。
 10. **実行時に評価されないコードは検査対象外**（R3-3 / 偽陽性の除去）。
       - `if TYPE_CHECKING:` ブロックは実行時に必ず False であり dead code
         （`TYPE_CHECKING` / `typing.TYPE_CHECKING` の両表記に対応）
       - `from __future__ import annotations` があるモジュールの注釈式は
         PEP 563 により文字列化され評価されない
     どちらも「実行能力を持たないことが構文上証明できる」範囲に限る
     （`else` 節や future import の無いモジュールの注釈は対象外にしない）。

**substring 走査は使わない**: `discovery.py` の docstring には「subprocess での
gh 呼び出し禁止」という宣言文が実在し、grep 方式では偽陽性になる。

--------------------------------------------------------------------------
残存脅威モデル（この検査器が守るもの / 守らないもの）
--------------------------------------------------------------------------

**完全性は主張しない。** 本 PBI では敵対レビューを 3 ラウンド回し、**毎回
1 つ深い回避クラスが新たに見つかった**（R1: 直接記述・`getattr` / R2:
ローカル別名の代入 1 行 / R3: `ast.Subscript` 経路）。この事実自体が
「AST 静的検査で任意の回避を塞ぎ切れる」という主張が成り立たないことの
証拠であり、次に触る人が「もう完全に塞がっている」と誤読しないために
以下を明記する。

守るもの（this checker DOES stop）:
  - **偶発的な迂回**。将来の実装者が無自覚に `subprocess` / `os.system` /
    `pty` / `ctypes` / `asyncio.create_subprocess_*` 等を書くこと
  - **列挙された回避クラス**（3 ラウンドの敵対レビューで実測 → 是正）:
      R1 直接記述（`subprocess` / `os.system` / `pty` / `ctypes` /
                   `multiprocessing` / `asyncio` / `eval`・`exec`・`compile`）
      R1 `getattr(os, "system")` とその非リテラル形
      R1 `gh_exec.py` 内部の `shell=True` / `_spawn()` 外の呼び出しサイト
      R2 import 別名・ローカル代入・タプル代入・多重代入・デフォルト引数
         （`mod = os` の 1 行で R1 の是正が全部無効化されていた）
      R2 イントロスペクション属性（`os.__dict__["system"]` 等）
      R3 添字式（`vars(os)["system"]` / `sys.modules["subprocess"].run` /
         `globals()["subprocess"]`）
  - **fail-closed の既定**。静的に解決できない間接参照は「トークンでない」
    ではなく violation として扱う（不変条件 4 / 8 / 9）

守らないもの（this checker does NOT stop）:
  - **コミット権限を持つ実装者が意図的に回避しようとする場合**。AST 静的
    検査は sandbox ではなく、新しい回避クラスは原理的に無限に存在しうる
    （3 ラウンドで 3 クラス出た経験則がそれを示している）
  - **この Python プロセスの外**の作用。同一セッションの Bash・別プロセス・
    CI ジョブからの `gh pr merge`（plan「⚠️ 回避不能なギャップ（AC-5 の
    scope 明示）」と同じ限界）
  - `scripts/ai-loop/*.py` **以外**のファイル。検査対象ディレクトリ外から
    実行能力を渡す経路は本検査器の視野外
  - 基底が**モジュール外から渡される**一般名の呼び出し（`def f(m): m.run(x)`）。
    偽陽性を避けるため `run` / `call` は間接実行名に載せていない
    （モジュール内での取得経路は不変条件 7〜9 で塞いである）

したがって **本検査器は「多層防御の 1 層」**であり、単独で
「NO MERGE BY AI」を保証するものではない。保証の主体は
  (1) runtime の `gh_exec` allowlist（`authorize_gh()` の deny 既定）
  (2) C-4 Human レビュー
  (3) repo 側の branch protection / required review
であり、本検査器はそれらが**気付かないうちに掘り崩されていない**ことを
CI で機械的に確かめる補助線に過ぎない。

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

#: 動的属性アクセスの**ファミリー**（R3-1）。`getattr` と同じく「名前空間から
#: 名前で実行能力を取り出す」builtin であり、`vars(os)["system"]` は
#: `os.__dict__["system"]` とも `getattr(os, "system")` とも意味が同じ。
#: `dir` は callable を返さないが同族の内省 API なので同じ規律下に置く。
#: 「解決可能な名前空間 + 文字列リテラル添字」の形以外は fail-closed。
DYNAMIC_ATTR_FAMILY = frozenset({"vars", "globals", "locals", "dir"})

#: 名前空間そのものを返す（＝引数が名前空間になる）ファミリー。`vars(os)` は
#: `os` の名前空間なので、`vars(os)["system"]` を `os.system` へ畳み込める。
NAMESPACE_OF_ARG_BUILTINS = frozenset({"vars"})

#: 引数なしでモジュール / ローカルの名前空間を返すファミリー。
#: `globals()["subprocess"]` はモジュール内の束縛名 `subprocess` の参照。
NAMESPACE_OF_SCOPE_BUILTINS = frozenset({"globals", "locals"})

#: 動的なモジュール表。`sys.modules["subprocess"]` は `subprocess` そのもの
#: （`import subprocess` と同じ実行能力を与える / R3-1）。
MODULE_TABLE_PATH = "sys.modules"

#: 型検査専用ブロックの判定に使う名前（`TYPE_CHECKING` / `typing.TYPE_CHECKING`）。
TYPE_CHECKING_NAME = "TYPE_CHECKING"

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
#:
#: **検出力に関する正確な主張**（R3-2 で書き直し。旧版は「別名経由の
#: `subprocess.run` は束縛伝播が解決するので検出力は落ちない」と**無条件に**
#: 書いていたが、`sys.modules["subprocess"].run(a)` が実測ですり抜けており
#: 誤りだった。添字経路は束縛伝播（不変条件 7）の視野外だったため）:
#:
#:   - **モジュール内で `subprocess` を取得する経路**は塞いである。
#:     `import` / `from import`（別名含む）・代入伝播（不変条件 7）・
#:     `getattr`・`__dict__` 添字・`vars()` 添字・`sys.modules[...]`・
#:     `globals()[...]`（不変条件 9）はいずれも dotted path へ解決されるので、
#:     `_run = subprocess.run` / `_sp = sys.modules["subprocess"]` のような
#:     別名付けは `run` を本集合に載せなくても検出できる。
#:   - **塞げていない残余**: 基底が**モジュール外から渡ってくる**場合
#:     （`def f(m, a): m.run(a)` で `m` が引数）。偽陽性回避のため `run` を
#:     本集合に載せない以上、この形は原理的に捕捉できない。ただし呼び出し側で
#:     `subprocess` を取得する行は上記のいずれかで検出されるため、
#:     `scripts/ai-loop/` 内で閉じた回避には使えない（検査対象ディレクトリ外
#:     からの受け渡しは module docstring「残存脅威モデル」の scope 外）。
INDIRECT_EXEC_ATTRS = frozenset(
    OS_EXEC_ATTRS + ASYNCIO_EXEC_ATTRS + OS_EXEC_FAMILY
    + ("Popen", "check_output", "check_call", "getoutput", "getstatusoutput",
       "CDLL", "LoadLibrary", "import_module", "__import__"))

#: `gh_exec.py` で bare name 呼び出しの静的解決を免除する (関数名, 呼び出し名)。
#: **この 1 件から増やさない**（`GRANDFATHER_ARGV_EXCEPTIONS` と同じ凍結方式）。
#: `authorize_gh()` は rule table の condition 関数列（`GH_RULES` に載る
#: module-local な `_c_*`）を反復適用するため、呼び出し先がループ変数になる。
#: 解消には `gh_exec.py` 側の構造変更が要るため、本 PBI では**凍結**して扱う。
#:
#: **凍結の前提条件（R3-4 / 呼び出し元の規律に依存する黙示の前提を明文化）**:
#: この例外は「`condition` に束縛されるのは `GH_RULES` に載る module-local な
#: `_c_*` 関数だけ」という前提の上でのみ安全である。`gh_exec.py` の
#: `authorize_gh(args, *, repo, rules=GH_RULES)` / `run_gh(..., rules=GH_RULES)`
#: は `rules` をキーワードで差し替えられるため、外部から任意の callable を
#: 載せた rule table を渡されると本例外が**任意の関数呼び出しを素通しする穴**
#: に変わる。したがって:
#:
#:   **`rules=` を外部から差し替えないこと。** 本番の呼び出し元は既定値
#:   （`GH_RULES`）のみを使う。差し替えが必要になった時点でこの凍結例外は
#:   前提を失うので、例外の削除（`gh_exec.py` 側の構造変更）を先に行うこと。
#:
#: 現状の呼び出し元 2 箇所（`collector.py` / `executor.py`）はいずれも既定値
#: のみを使用しており未到達。`test_gh_exec.py` は変異注入で `rules=` を渡すが、
#: `GH_RULES` の条件を**落とすだけ**で `condition` に載るのは同じ `_c_*` に
#: 留まるため前提は保たれる。`gh_exec.py` のシグネチャは本 PBI では変更しない。
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
        """`Name` / `Attribute` / `Subscript` / 名前空間 builtin を dotted path へ解決する。

        解決できないときは None。添字式（`Subscript`）と名前空間 builtin
        （`vars` / `globals` / `locals`）の解決は不変条件 9（R3-1）。
        モジュール属性としてトップレベル関数に切り出してあるのは、変異注入で
        「添字解決を外すと R3 の 3 形が復活する」ことを実証できるようにするため。
        """
        if isinstance(node, ast.Name):
            return self.modules.get(node.id) or self.functions.get(node.id)
        if isinstance(node, ast.Attribute):
            base = self.resolve(node.value)
            return f"{base}.{node.attr}" if base else None
        if isinstance(node, ast.Subscript):
            return _resolve_subscript(self, node)
        if isinstance(node, ast.Call):
            return _resolve_namespace_call(self, node)
        return None


def _resolve_subscript(binds: _Bindings, node):
    """添字式を dotted path へ畳み込む（不変条件 9 / R3-1）。

    キーが**文字列リテラル**でない添字は解決しない（fail-closed 層が受け持つ）。

    対応する形:
      - `sys.modules["subprocess"]`            → `subprocess`（モジュールそのもの）
      - `os.__dict__["system"]`                → `os.system`（`__dict__` 経路）
      - `vars(os)["system"]`                   → `os.system`（`vars` は名前空間）
      - `globals()["subprocess"]`              → モジュール内束縛名の解決
      - それ以外（`os.environ["HOME"]` 等）    → `os.environ.HOME`（属性と同型）
    """
    key = node.slice
    if not (isinstance(key, ast.Constant) and isinstance(key.value, str)):
        return None
    base_node = node.value
    if (isinstance(base_node, ast.Call) and isinstance(base_node.func, ast.Name)
            and base_node.func.id in NAMESPACE_OF_SCOPE_BUILTINS
            and not base_node.args and not base_node.keywords):
        # `globals()["subprocess"]` はモジュール内の束縛名そのものを指す。
        return binds.modules.get(key.value) or binds.functions.get(key.value)
    base = binds.resolve(base_node)
    if base is None:
        return None
    if base == MODULE_TABLE_PATH:
        return key.value
    if isinstance(base_node, ast.Attribute) and base_node.attr in INTROSPECTION_ATTRS:
        # `os.__dict__["system"]` の基底は `os` なので `__dict__` を畳んで落とす。
        return f"{base.rsplit('.', 1)[0]}.{key.value}"
    return f"{base}.{key.value}"


def _resolve_namespace_call(binds: _Bindings, node):
    """`vars(mod)` を「`mod` の名前空間」として解決する（不変条件 9 / R3-1）。

    `globals()` / `locals()` は引数から名前空間を特定できないため、
    `_resolve_subscript` 側で添字と組で扱う（ここでは None を返す）。
    """
    if not (isinstance(node.func, ast.Name) and node.func.id in DYNAMIC_ATTR_FAMILY):
        return None
    if (node.func.id in NAMESPACE_OF_ARG_BUILTINS
            and len(node.args) == 1 and not node.keywords):
        return binds.resolve(node.args[0])
    return None


def _is_type_checking_test(node) -> bool:
    """`if TYPE_CHECKING:` / `if typing.TYPE_CHECKING:` を判定する（不変条件 10）。"""
    test = node.test
    if isinstance(test, ast.Name):
        return test.id == TYPE_CHECKING_NAME
    if isinstance(test, ast.Attribute):
        return test.attr == TYPE_CHECKING_NAME
    return False


def _has_future_annotations(tree) -> bool:
    """`from __future__ import annotations`（PEP 563）が宣言されているか。"""
    for node in tree.body:
        if isinstance(node, ast.ImportFrom) and node.module == "__future__":
            if any(alias.name == "annotations" for alias in node.names):
                return True
    return False


def _excluded_nodes(tree) -> set:
    """**実行時に評価されない**ノードの id 集合を返す（不変条件 10 / R3-3）。

    「検査を緩める」のではなく「実行能力を持たないことが構文上証明できる範囲を
    対象外にする」ための集合。ここに入れてよいのは以下だけ:

      - `if TYPE_CHECKING:` の **body**（実行時は常に False = dead code）。
        `else` 節は実行されるので対象にしない。
      - `from __future__ import annotations` があるモジュールの**注釈式**
        （PEP 563 で文字列化され評価されない）。future import が無い
        モジュールの注釈は実際に評価されるので対象にしない。
    """
    excluded: set = set()

    def mark(node) -> None:
        for sub in ast.walk(node):
            excluded.add(id(sub))

    for node in ast.walk(tree):
        if isinstance(node, ast.If) and _is_type_checking_test(node):
            for stmt in node.body:
                mark(stmt)

    if _has_future_annotations(tree):
        for node in ast.walk(tree):
            if isinstance(node, ast.arg):
                if node.annotation is not None:
                    mark(node.annotation)
            elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                if node.returns is not None:
                    mark(node.returns)
            elif isinstance(node, ast.AnnAssign):
                mark(node.annotation)
    return excluded


def _walk(tree, excluded=None):
    """`ast.walk` から検査対象外ノード（不変条件 10）を除いて列挙する。"""
    if excluded is None:
        excluded = _excluded_nodes(tree)
    for node in ast.walk(tree):
        if id(node) not in excluded:
            yield node


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


def _propagate_bindings(tree, binds: _Bindings, excluded=None) -> bool:
    """代入 / デフォルト引数を 1 巡だけ伝播する。変化があれば True。

    `excluded` は `_excluded_nodes()` の結果（不変条件 10）。`check_source` が
    1 度だけ計算して各層へ配る（省略時は都度計算する = 単体利用向け）。
    """
    changed = False
    for node in _walk(tree, excluded):
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


def _collect_bindings(tree, violations, name, excluded=None):
    """import + 代入伝播で束縛表を作り、解決不能な形（star import）を fail-closed で記録。"""
    binds = _Bindings()
    for node in _walk(tree, excluded):
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
        if not _propagate_bindings(tree, binds, excluded):
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
    """`node` が `module` 配下へ解決されるか。

    `ast.Name` だけでなく `_Bindings.resolve` の解決全体（属性チェーン /
    添字式 / 名前空間 builtin）を使う。これにより
    `sys.modules["subprocess"].run(...)` も subprocess 呼び出しサイトとして
    列挙できる（R3-1。以前は `Name` 限定だったため添字経路が視野外だった）。
    """
    dotted = binds.resolve(node)
    return bool(dotted) and dotted.split(".")[0] == module


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


def _introspection_subscripts(tree, excluded=None):
    """`X.__dict__["literal"]` の形を (Attribute ノード id → キー文字列) で返す。

    この形**だけ**が静的に解決可能なイントロスペクションであり、それ以外
    （キーが非リテラル / 添字を伴わない参照）は fail-closed で violation にする。
    """
    resolved: dict[int, str] = {}
    for node in _walk(tree, excluded):
        if not isinstance(node, ast.Subscript):
            continue
        base = node.value
        if not (isinstance(base, ast.Attribute) and base.attr in INTROSPECTION_ATTRS):
            continue
        key = node.slice
        if isinstance(key, ast.Constant) and isinstance(key.value, str):
            resolved[id(base)] = key.value
    return resolved


def _subscript_label(node, binds: _Bindings) -> str:
    """添字式の経路名（違反メッセージ用）。どの回避クラスかを読み手に示す。"""
    base = node.value
    if isinstance(base, ast.Call) and isinstance(base.func, ast.Name):
        return f"{base.func.id}() 経由"
    if isinstance(base, ast.Attribute):
        return f"{binds.resolve(base) or base.attr} 経由"
    return "添字経由"


def _collect_exec_tokens(tree, binds: _Bindings, excluded=None):
    """(lineno, token, route) のリストを返す。import 形と属性呼び出し形の両方を拾う。

    `token` は**正規化された実行系トークン**（`gh_exec.py` の許否判定はこれで
    行う）、`route` はそれをどの経路で取得したかの表示用ラベル
    （`__dict__ 経由` / `vars() 経由` / `sys.modules 経由` 等、無ければ空文字）。
    両者を分けるのは、`gh_exec.py` で `sys.modules["subprocess"]` を
    「許可されるのは subprocess のみ: sys.modules 経由: subprocess」という
    自己矛盾したメッセージで倒さないため（許否は token、説明は route）。

    `getattr` による動的属性アクセスと `eval` / `exec` / `compile` による動的
    コード生成も対象（R1-A-1 / A-2）。前者はリテラル解決できなければ
    fail-closed、後者は無条件に violation とする。

    さらに**添字式**（`vars(os)["system"]` / `sys.modules["subprocess"]` /
    `globals()["subprocess"]`）も `_Bindings.resolve` で畳み込んで判定する
    （不変条件 9 / R3-1。`ast.Attribute` だけを見ていた頃は同じ意味でも
    AST の形が違うだけですり抜けていた）。
    """
    found = []
    introspection = _introspection_subscripts(tree, excluded)
    for node in _walk(tree, excluded):
        if isinstance(node, ast.Import):
            for alias in node.names:
                token = _module_token(alias.name)
                if token:
                    found.append((node.lineno, token, ""))
        elif isinstance(node, ast.ImportFrom):
            module = node.module or ""
            for alias in node.names:
                if alias.name == "*":
                    continue
                dotted = f"{module}.{alias.name}" if module else alias.name
                token = _module_token(dotted)
                if token:
                    found.append((node.lineno, token, ""))
        elif isinstance(node, ast.Attribute):
            if node.attr in INTROSPECTION_ATTRS:
                # `os.__dict__["system"]` を `os.system` として解決する
                # （解決できない形は `_collect_dynamic_unresolved` が fail-closed）。
                key = introspection.get(id(node))
                target = binds.resolve(node.value)
                if key is not None and target is not None:
                    token = _module_token(f"{target}.{key}")
                    if token:
                        found.append((node.lineno, token, f"{node.attr} 経由"))
                continue
            token = _attribute_token(node, binds)
            if token:
                found.append((node.lineno, token, ""))
            elif (binds.resolve(node.value) is None
                  and node.attr in INDIRECT_EXEC_ATTRS):
                # 基底が解決できない属性参照。既定を fail-closed へ反転する
                # （R2-a-2 / 不変条件 8(b)）。属性名が実行能力そのものの名前の
                # ときだけ倒すことで `proc.returncode` 等の偽陽性を出さない。
                found.append((node.lineno,
                              f"?.{node.attr}（基底が静的に解決できない）", ""))
        elif isinstance(node, ast.Subscript):
            # `__dict__["system"]` は上の Attribute 分岐が既に扱っているので
            # 二重計上しない。ここは `vars()` / `sys.modules` / `globals()` /
            # その他の添字経路を受け持つ（不変条件 9 / R3-1）。
            base = node.value
            if isinstance(base, ast.Attribute) and base.attr in INTROSPECTION_ATTRS:
                continue
            dotted = binds.resolve(node)
            token = _module_token(dotted) if dotted else None
            if token:
                found.append((node.lineno, token, _subscript_label(node, binds)))
        elif isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
            if node.func.id == "__import__":
                found.append((node.lineno, "__import__", ""))
            elif node.func.id in DYNAMIC_CODE_BUILTINS:
                found.append((node.lineno, f"{node.func.id}()", ""))
            elif node.func.id == DYNAMIC_ATTR_BUILTIN:
                token, _resolvable = _getattr_token(node, binds)
                if token:
                    found.append((node.lineno, token,
                                  f"{DYNAMIC_ATTR_BUILTIN} 経由"))
    return found


def _collect_dynamic_unresolved(tree, binds: _Bindings, name: str, excluded=None):
    """静的に解決できない動的参照を fail-closed の Violation として返す。

    - `getattr` の属性名が文字列リテラルでない（R1-A-1）
    - イントロスペクション属性（`__dict__` 等）が「解決可能な基底 + 文字列
      リテラル添字」以外の形で現れる（R2-a-2 / 不変条件 8(a)）
    """
    violations = []
    introspection = _introspection_subscripts(tree, excluded)
    for node in _walk(tree, excluded):
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


def _collect_subscript_unresolved(tree, binds: _Bindings, name: str, excluded=None):
    """添字経路の fail-closed 層（不変条件 9 / R3-1）。

    `_collect_exec_tokens` の添字解決が**効かなかった**形を violation にする。
    属性名ベースの反転（不変条件 8(b)）と同型で、「静的に解決できない間接
    参照は通さない」を添字にも適用する。対象は 3 つ:

      (a) **添字式そのものを呼び出している**のに基底が解決できない
          （`x[k](...)` / `handlers["run"](...)`）。実行能力を名前で引いて
          即座に呼ぶ形であり、正当な用途は本ディレクトリに存在しない
          （実測 0 件）。将来ディスパッチテーブルが必要になった場合は
          **凍結例外を増やさず**、モジュール内定義の関数へ分岐する構造で解く。
      (b) `vars` / `globals` / `locals` / `dir` が「解決可能な名前空間 +
          文字列リテラル添字」の形になっていない（`vars(m)[k]` / 裸の
          `globals()`）。`getattr` の非リテラル形と同じ扱い。
      (c) `sys.modules` が文字列リテラル添字を伴わない
          （`sys.modules[name]` / 裸の `sys.modules`）。`__dict__` と同型。

    偽陽性ガード: **通常の添字アクセス**（`d["key"]` / `lst[0]` /
    `os.environ["HOME"]` / `argv[1:]`）は「呼び出していない」ので (a) に
    掛からず、(b)(c) の対象名でもないため 1 件も出ない。
    """
    violations = []
    resolved_bases = set()
    if excluded is None:
        excluded = _excluded_nodes(tree)
    for node in _walk(tree, excluded):
        if isinstance(node, ast.Subscript) and binds.resolve(node) is not None:
            resolved_bases.add(id(node.value))

    for node in _walk(tree, excluded):
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Subscript):
            if binds.resolve(node.func) is None:
                violations.append(Violation(
                    name, node.lineno, CODE_INDIRECT_EXEC,
                    "添字式による呼び出しの基底が静的に解決できない"
                    "（fail-closed）"))
        if (isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
                and node.func.id in DYNAMIC_ATTR_FAMILY
                and id(node) not in resolved_bases):
            violations.append(Violation(
                name, node.lineno, CODE_DYNAMIC_UNRESOLVED,
                f"動的属性アクセス {node.func.id}() が「解決可能な名前空間 + "
                "文字列リテラル添字」の形でない（静的追跡不能 / fail-closed）"))
        if (isinstance(node, ast.Attribute)
                and binds.resolve(node) == MODULE_TABLE_PATH
                and id(node) not in resolved_bases):
            violations.append(Violation(
                name, node.lineno, CODE_INDIRECT_EXEC,
                f"{MODULE_TABLE_PATH} による間接参照"
                "（文字列リテラル添字 以外は fail-closed）"))
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


def _gh_exec_indirect_calls(tree, binds: _Bindings, name: str, exceptions=None,
                            excluded=None):
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
    for node in _walk(tree, excluded):
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


def _gh_exec_discipline(tree, binds: _Bindings, name: str, excluded=None):
    """`gh_exec.py` 内部の subprocess 呼び出しサイトを AST で列挙して検査する。

    語（`subprocess` の有無）だけを見る逆向きホワイトリストでは、唯一の境界の
    **内部**に `subprocess.run(cmd, shell=True)` のような無検査の抜け道が残る。
    """
    violations = []
    scopes = _enclosing_functions(tree)
    for call in _subprocess_call_sites(tree, binds, excluded):
        detail = _shell_kwarg_verdict(call)
        if detail is not None:
            violations.append(Violation(name, call.lineno, CODE_GH_EXEC_SHELL, detail))
        enclosing = scopes.get(id(call))
        if enclosing != GH_EXEC_SPAWN_FUNC:
            violations.append(Violation(
                name, call.lineno, CODE_GH_EXEC_SPAWN_SITE,
                f"subprocess の呼び出しは {GH_EXEC_SPAWN_FUNC}() に限る"
                f"（実際の関数: {enclosing!r}）"))
    for node in _walk(tree, excluded):
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

def _subprocess_call_sites(tree, binds: _Bindings, excluded=None):
    """subprocess のエントリポイント呼び出しノードを列挙する。

    **呼び出し先の形で分岐せず** `_Bindings.resolve()` の結果 1 本で判定する
    （R3-1）。これにより属性形（`subprocess.run` / `sp.run`）・bare name 形
    （`from subprocess import run`）に加えて**添字形**
    （`sys.modules["subprocess"].run` / `vars(subprocess)["run"]`）も同じ
    経路で列挙され、`test_*.py` の argv 不変条件と `gh_exec.py` の構造規律の
    両方が添字経路に効くようになる。
    """
    sites = []
    for node in _walk(tree, excluded):
        if not isinstance(node, ast.Call):
            continue
        dotted = binds.resolve(node.func)
        if not dotted:
            continue
        parts = dotted.split(".")
        if parts[0] == "subprocess" and parts[-1] in SUBPROCESS_ENTRY_POINTS:
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

    excluded = _excluded_nodes(tree)
    binds = _collect_bindings(tree, violations, name, excluded)
    is_gh_exec = name == GH_EXEC_MODULE
    is_test = name.startswith("test_")

    for lineno, token, route in _collect_exec_tokens(tree, binds, excluded):
        shown = f"{route}: {token}" if route else token
        if token == "subprocess":
            if is_gh_exec or is_test:
                continue
            violations.append(Violation(
                name, lineno, CODE_EXEC_TOKEN,
                f"{GH_EXEC_MODULE} 以外での実行系トークン: {shown}"))
        elif is_gh_exec:
            violations.append(Violation(
                name, lineno, CODE_GH_EXEC_EXTRA_TOKEN,
                f"{GH_EXEC_MODULE} で許可されるのは subprocess のみ: {shown}"))
        else:
            violations.append(Violation(
                name, lineno, CODE_EXEC_TOKEN,
                f"{GH_EXEC_MODULE} 以外での実行系トークン: {shown}"))

    violations.extend(_collect_dynamic_unresolved(tree, binds, name, excluded))
    violations.extend(_collect_subscript_unresolved(tree, binds, name, excluded))

    if is_gh_exec:
        violations.extend(_gh_exec_discipline(tree, binds, name, excluded))
        violations.extend(_gh_exec_indirect_calls(tree, binds, name,
                                                  excluded=excluded))

    if is_test:
        scopes = _enclosing_functions(tree)
        exempt = {(pathlib.PurePath(f).name, fn) for f, fn in grandfather}
        for call in _subprocess_call_sites(tree, binds, excluded):
            verdict = _argv_verdict(call, binds)
            if verdict is None:
                continue
            if (name, scopes.get(id(call))) in exempt:
                continue
            code, detail = verdict
            violations.append(Violation(name, call.lineno, code, detail))

    violations.sort(key=lambda v: (v.line, v.code, v.detail))
    return _dedup(violations)


def _dedup(violations: list) -> list:
    """完全に同一の Violation を 1 件に畳む（層が重なる形の重複出力を防ぐ）。

    複数の層（トークン検出 / fail-closed / 構造規律）が同じ 1 行を別経路で
    捕まえることがあり、その場合に同一メッセージが並ぶのを避ける。
    **異なる detail は畳まない**（どの層が何を捕まえたかは残す）。
    """
    seen = set()
    unique = []
    for v in violations:
        key = (v.path, v.line, v.code, v.detail)
        if key in seen:
            continue
        seen.add(key)
        unique.append(v)
    return unique


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
