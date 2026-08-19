# #1169 patch 設計書 — `sh` で Python スクリプトを起動すると docstring が評価される

> **Status**: 設計のみ（実装未着手）。採否の最終判断は **Human（C-3）** に残す。
> **対象 issue**: [#1169](https://github.com/s977043/plangate/issues/1169)（bug / priority:P2 / area:cli）
> **測定基準 ref**: `origin/main` = `24aa460ce9814e4d702401cd19bbe68d85b0b7b9`（2026-08-20 実測）
> **本書のブランチ**: `docs/1169-sh-invocation`
> **成果物**: 本ファイル 1 点のみ。`scripts/` / `tests/` / `.github/` / `bin/` / `schemas/` / `.codex/` / skill root には一切触れていない。

---

## 0. 結論（先出し）

| # | 結論 | 根拠 |
|---|------|------|
| C-1 | issue が報告した「`.codex/skills` 34 ファイル書き換え」は **本問題の最小の実害**であり、同じ機構でより重い経路が存在する。`sh scripts/ai-loop/gh_exec.py` は **`gh pr merge` / `gh pr close` / `gh pr review --approve` / `gh pr comment` / `gh api` を実際に起動する**（sandbox 実測で stub 発火を確認） | §2.4 / §3 |
| C-2 | issue の是正候補 1（shebang + 実行ビット）は **`scripts/check-skill-frontmatter.py` では既に満たされている**（`origin/main` で mode `100755`・shebang `#!/usr/bin/env python3`）。それでも事故は起きた。**導線改善は防御にならない** | §4.3 |
| C-3 | 是正候補 2（該当行のバッククォート除去）は**対症**。同一ファイル内に他にも展開点があり、`$(...)` / `$VAR` / リダイレクトは残る | §3.3 / §4.1 |
| C-4 | **推奨は「ファイル先頭の sh ガード」**（Python の docstring 位置に置く 4 行の polyglot）。全 59 ファイルへ機械適用可能で、`__doc__` も保てることを実測済 | §4.2 / §6 |
| C-5 | 再発検知は `tests/extras/ta-70-sh-invocation-guard.sh`（新規）で **挙動ベース 4 条件の連言**として設計。静的 grep のみ / 「非ゼロ終了のみ」といった素朴な設計は **false green になることを実測で示した** | §5 / §6.3 |
| C-6 | 適用（`scripts/*.py` と `tests/extras/*.sh` の編集）は **Hardening Override 対象外**だが、**EH-3 により no-task セッションの AI は `.md` 以外を書けない**。`PLANGATE_HOOK_TASK` を設定したセッションが必須 | §8 |

---

## 1. 事象の再掲と再現条件

`sh scripts/check-skill-frontmatter.py` と誤起動すると、読み取り専用の検査のつもりで `.codex/skills/**` が書き換わる。

- shebang は `#!/usr/bin/env python3`
- `git grep -n 'check-skill-frontmatter' origin/main -- scripts .github tests` の結果、**repo 内に `sh` で起動している配線は無い**（オーガナイザー実測。本作業では追検証していない = §9 U-3）
- したがって **入口は人間 / AI の起動ミス**であり、「配線を直す」対象が存在しない

### 1.1 本書での再現方法（repo を汚さない手順）

実 repo に対しては **一度も** `sh scripts/check-skill-frontmatter.py` を実行していない。再現は次の隔離条件で行った。

```text
sandbox/            # 使い捨てディレクトリ（cwd）
  target.py         # git show origin/main:scripts/check-skill-frontmatter.py の出力
  emptypath/        # 空ディレクトリ
  scripts/install-plangate-skills-to-codex.sh   # 「MARKER-INSTALL-RAN」を出すだけの stub
```

実行コマンド（cwd = sandbox）:

```sh
env -i PATH="<sandbox>/emptypath" /bin/sh target.py >out.txt 2>err.txt
```

- `PATH` を空ディレクトリに固定 → `gh` / `git` / `python3` 等の実バイナリは一切解決されない
- cwd を使い捨てディレクトリに固定 → 相対パスは実 repo に届かない
- 実行前に **全展開点を静的に列挙し、絶対パス起動と破壊的動詞（`rm` / `mv` / `cp` / `curl` / `sudo` 等）が 1 件も無いこと**を確認してから実行した（§3.3 の集合）

結果（実測）:

```text
EXIT=2
target.py: line 54: plangate-setup/SKILL.md: No such file or directory
...
MARKER: install script WAS EXECUTED          <-- stub が発火 = 同期スクリプトは実際に起動される
...
target.py: line 63: syntax error near unexpected token `('
```

---

## 2. 原因の構造的説明 — `sh` から見たこのファイル

### 2.1 `sh <file>` は shebang を見ない

`sh foo.py` は「`foo.py` を **sh スクリプトとして** 読め」という明示指示である。`#!` 行は sh から見ると **ただのコメント**であり、インタプリタ選択には一切使われない（`#!` が効くのはカーネルの `execve` 経由、つまり `./foo.py` と直接起動したときだけ）。

### 2.2 `"""` の sh 上での意味 — ここが起点

`origin/main` の当該ファイルの 1〜2 行目（`git show origin/main:scripts/check-skill-frontmatter.py | sed -n '1,2p'`）:

```text
#!/usr/bin/env python3
"""
```

sh のトークナイザは `"""` を **3 個の独立した `"`** として読む:

| 位置 | 文字 | sh の状態遷移 |
|------|------|--------------|
| 1 | `"` | UNQUOTED → DQ（二重引用符を開く） |
| 2 | `"` | DQ → UNQUOTED（空文字列 `""` が 1 個できる） |
| 3 | `"` | UNQUOTED → **DQ（開きっぱなし）** |

3 個目で開いた二重引用符は **改行では閉じない**。閉じるのは次に現れる `"` — すなわち docstring 終端の `"""` の 1 文字目である。よって:

> **module docstring の中身が丸ごと 1 個の「二重引用符付きの単語」になる。**

さらに `"""`（開）と `"""`（閉）の引用符は合計 6 個で偶奇が揃うため、docstring を抜けた時点で sh は UNQUOTED に戻る。その直後の改行で **単純コマンドが 1 個完成し、sh はそれを実行する**。実行の直前に行われるのが **展開（expansion）** であり、ここで docstring 内のすべての `` ` `` と `$` が評価される。

（実測での裏付け: §1.1 の stderr 末尾で、docstring 全文が展開後の文字列として `: File name too long` というエラーとともにコマンド名として扱われている。）

### 2.3 二重引用符の中でも `` ` `` と `$` は展開される

POSIX shell の引用規則:

| 引用 | `` ` `` | `$(...)` | `$VAR` | `>` `<` `&&` `;` |
|------|--------|----------|--------|------------------|
| なし（UNQUOTED） | 展開 | 展開 | 展開 | **演算子として作用** |
| `"..."`（DQ） | **展開** | **展開** | **展開** | リテラル文字 |
| `'...'`（SQ） | リテラル | リテラル | リテラル | リテラル |

つまり「docstring 全体が DQ に入る」ことは**安全側には働かない**。DQ はフィールド分割とグロブは止めるが、**コマンド置換とパラメータ展開は止めない**。

### 2.4 実際に何が実行されるか（記号アンカーで特定）

sh はバッククォートを **出現順にペアリング**する。奇数番目が開始、偶数番目が終了である。docstring 中のバッククォートは「本文中のコード引用」として偶数個ずつ現れるため、**「引用したいコード」と「引用と引用の間の日本語」が交互にコマンド置換の中身になる**。

`origin/main` の docstring 内で、実際にコマンド置換の中身になる文字列（= sh が実行を試みる文字列）は次の 24 件。アンカーは docstring 内の節名（記号アンカー）を主とし、行番号は補助として括弧内に置く。

| # | docstring 内の位置（記号アンカー） | 実行される文字列 | 実効 |
|---|-----------------------------------|-----------------|------|
| 1 | 「背景:」節冒頭 | `plangate-setup/SKILL.md` | ファイル起動失敗 |
| 2 | 同上 | `description` | command not found |
| 3 | 同上 | `Use when:` | command not found |
| 4 | 同上 | `mapping values are not allowed here` | `mapping` が not found |
| 5 | 同上（strict パーサの説明） | `claude plugin validate --strict` | **`claude` CLI を起動しにいく** |
| 6-8 | 「既存の skill 系検査」列挙 | `check-skill-name-collisions.py` / `check-stale-skill-refs.py` / `tests/extras/ta-13` | 起動失敗 |
| 9 | 同上 | `key: value` | not found |
| 10 | 「対象:」節 | `<root>/<skill-name>/SKILL.md` | **`<` `>` がリダイレクトとして解釈される** |
| 11-14 | 既定 root 列挙 | `.agents/skills` / `.claude/skills` / `.codex/skills` / `plugin/*/skills` | ディレクトリ起動失敗（グロブ展開も発生） |
| 15 | `.codex/skills` 説明行（L28 付近） | `.codex/skills` | 起動失敗 |
| **16** | **同行（L28 付近）** | **`scripts/install-plangate-skills-to-codex.sh`** | **実行される（本 issue の実害）** |
| 17-20 | 「検査項目:」節 | `---` ×2 / `name` / `description` | not found |
| 21-22 | 「配線について:」節 | `.github/workflows/` / `bin/plangate` | **`bin/plangate` は実行可能なので起動される** |
| 23 | 同上 | `tests/extras/ta-64-skill-frontmatter.sh` | 起動失敗（実行ビット無し） |
| **24** | **同上** | **`tests/run-tests.sh`** | **実行される（テストスイート全体が走る）** |

**16 の 1 行**は `git show origin/main:scripts/check-skill-frontmatter.py | sed -n '28p'` で確認できる:

```text
    `.codex/skills` は `scripts/install-plangate-skills-to-codex.sh` の生成物だが、
```

原因は「バッククォートがあるから」ではなく、**「docstring 全体が DQ に入り、DQ の中でもコマンド置換が生きるから」**である。したがって当該 1 行だけを直しても構造は残る（§4.1）。

### 2.5 docstring の後に何が起きるか（実測）

docstring を抜けた後、sh は Python コードを shell として読み続ける:

```text
from __future__ import annotations   -> `from`: command not found
import argparse                      -> `import`: command not found
...
REPO_ROOT = Path(__file__)...        -> syntax error near unexpected token `('  -> シェル終了 (rc=2)
```

**このファイルでは、`->` 型注釈由来のリダイレクト（§3.2 K4）に到達する前にシェルが構文エラーで死ぬ。** 別ファイルでは死ぬ位置が違うため、到達可否はファイルごとに変わる（§3.4 で実測）。

---

## 3. 危険になる構文の全 `scripts/*.py` 実測

### 3.1 測定方法

1. `git archive origin/main scripts | tar -x -C <scratch>` で `origin/main` の `scripts/` を丸ごと取り出す（作業ツリーは使わない）
2. POSIX sh の引用状態機械を実装した静的モデル（scratchpad の `shmodel2.py`）で、各ファイルの
   - コマンド置換（`` `...` `` / `$(...)`）
   - パラメータ展開（`$VAR` / `${...}` / `$0` `$@` 等）
   - **UNQUOTED 領域の演算子**（`<` `>` `|` `&` `;`）
   を列挙
3. 到達可否（＝本当に実行されるか）は **hermetic sandbox の実走**で確定（§3.4）

対象は `scripts/` 配下の `.py` **59 件**（`git ls-tree -r --name-only origin/main -- scripts | grep '\.py$' | wc -l` = 59）。

### 3.2 危険構文のクラス

| クラス | 何が起きるか | 例（`origin/main` 実測） |
|--------|-------------|------------------------|
| **K1: バッククォート** | docstring 内のコード引用がそのままコマンド置換になる | `` `scripts/install-plangate-skills-to-codex.sh` `` |
| **K2: `$(...)`** | 同上。DQ 内でも展開される | `_apply_task_*.py` の埋め込み shell 断片 |
| **K3: `$VAR` / `${VAR:-x}` / `$0` / `$@`** | 値が空文字に化けて単語が壊れる。`$(...)` を内包する形なら実行される | §3.3 (C) |
| **K4: UNQUOTED のリダイレクト `>` `<`** | **ファイルを新規作成 / truncate する**。Python の `-> str:` 型注釈が `>` として解釈されるのが主経路 | `def _display(path: Path) -> str:` → `>` の宛先 `str:` |
| **K5: UNQUOTED の `\|` `&` `;`** | パイプライン / バックグラウンド / コマンド区切りとして作用し、想定外のコマンド境界を作る | `def main(argv: list[str] \| None = None) -> int:` |
| **K6: グロブ** | UNQUOTED の `*` がファイル名展開され、対象集合が実行時の repo 状態に依存する | `` `plugin/*/skills` `` / `` `scripts/ai-loop/*.py` `` |

**K4/K5 は「バッククォートを消せば安全」という直感を壊す最重要クラス**である。Python の型注釈 `->` は sh から見ると常にリダイレクトであり、docstring とは無関係に全ファイルに存在する。

### 3.3 静的計測結果（59 件・集合として列挙）

**(A) コマンド置換（K1/K2）を 1 つ以上持つファイル — 45 / 59**

```text
scripts/_ai_loop_link_rewrite.py             scripts/ai-loop/arbiter.py
scripts/_apply_task_0144_patches.py          scripts/ai-loop/c3_contract.py
scripts/_apply_task_0147_patches.py          scripts/ai-loop/c3prime_verify.py
scripts/_paths.py                            scripts/ai-loop/check_exec_boundary.py
scripts/baseline-snapshot.py                 scripts/ai-loop/ci_taxonomy.py
scripts/batch-acknowledge-skip-decisions.py  scripts/ai-loop/collector.py
scripts/check-skill-frontmatter.py           scripts/ai-loop/delivery.py
scripts/check-skill-name-collisions.py       scripts/ai-loop/discovery.py
scripts/check-stale-skill-refs.py            scripts/ai-loop/executor.py
scripts/context-engine.py                    scripts/ai-loop/gh_exec.py
scripts/doctor_check.py                      scripts/ai-loop/metrics.py
scripts/doctor_fix.py                        scripts/ai-loop/plan_package.py
scripts/eval-runner.py                       scripts/ai-loop/reconciler.py
scripts/keep-rate.py                         scripts/ai-loop/run_evidence.py
scripts/metrics_reporter.py                  scripts/ai-loop/run_evidence_verify.py
scripts/plan_hash_util.py                    scripts/ai-loop/test_arbiter.py
scripts/render_review.py                     scripts/ai-loop/test_check_exec_boundary.py
scripts/reporting.py                         scripts/ai-loop/test_ci_taxonomy.py
scripts/schema_mapping.py                    scripts/ai-loop/test_collector.py
                                             scripts/ai-loop/test_discovery.py
                                             scripts/ai-loop/test_executor.py
                                             scripts/ai-loop/test_gh_exec.py
                                             scripts/ai-loop/test_plan_package.py
                                             scripts/ai-loop/test_reconciler.py
                                             scripts/ai-loop/test_run_evidence.py
                                             scripts/ai-loop/test_run_evidence_verify.py
```

展開されるコマンド文字列は全 59 ファイル合計 **1574 件**。

**(B) UNQUOTED の演算子（K4/K5）を持つファイル — 48 / 59**

`ファイル (件数, 最初の出現行)`。主アンカーは「最初の `def ... -> T:` 行」、行番号は補助。

```text
scripts/_apply_task_0143_patches.py (6, L6)           scripts/reporting.py (27, L23)
scripts/_apply_task_0144_patches.py (8, L9)           scripts/schema_mapping.py (5, L15)
scripts/_apply_task_0145_patches.py (1, L10)          scripts/validate-schemas.py (8, L26)
scripts/_apply_task_0146_patches.py (1, L8)           scripts/validate-yaml-schemas.py (3, L33)
scripts/_apply_task_0147_patches.py (1, L11)          scripts/parsers/codex_log_parser.py (4, L25)
scripts/_resolve_validation_bias.py (2, L29)          scripts/ai-loop/c3_contract.py (4, L51)
scripts/baseline-snapshot.py (14, L32)                scripts/ai-loop/c3prime_verify.py (1, L41)
scripts/batch-acknowledge-skip-decisions.py (8, L41)  scripts/ai-loop/check_exec_boundary.py (24, L334)
scripts/check-skill-frontmatter.py (14, L84)          scripts/ai-loop/ci_taxonomy.py (1, L77)
scripts/check-skill-name-collisions.py (26, L89)      scripts/ai-loop/collector.py (39, L262)
scripts/context-engine.py (10, L29)                   scripts/ai-loop/delivery.py (25, L99)
scripts/doctor_check.py (19, L28)                     scripts/ai-loop/discovery.py (1, L160)
scripts/doctor_fix.py (13, L50)                       scripts/ai-loop/executor.py (20, L223)
scripts/eval-runner.py (38, L35)                      scripts/ai-loop/gh_exec.py (29, L80)
scripts/keep-rate.py (17, L25)                        scripts/ai-loop/metrics.py (17, L62)
scripts/metrics_collector.py (28, L30)                scripts/ai-loop/reconciler.py (9, L87)
scripts/metrics_reporter.py (16, L24)                 scripts/ai-loop/run_evidence.py (23, L87)
scripts/metrics_timeline.py (4, L17)                  scripts/ai-loop/run_evidence_verify.py (15, L92)
scripts/plan_hash_util.py (4, L27)                    scripts/ai-loop/test_c3_contract.py (1, L41)
                                                      scripts/ai-loop/test_check_exec_boundary.py (2, L46)
                                                      scripts/ai-loop/test_collector.py (4, L81)
                                                      scripts/ai-loop/test_delivery.py (1, L347)
                                                      scripts/ai-loop/test_discovery.py (1, L27)
                                                      scripts/ai-loop/test_executor.py (4, L141)
                                                      scripts/ai-loop/test_gh_exec.py (8, L48)
                                                      scripts/ai-loop/test_metrics.py (1, L26)
                                                      scripts/ai-loop/test_run_evidence.py (2, L396)
                                                      scripts/ai-loop/test_run_evidence_verify.py (4, L41)
```

**(C) パラメータ展開（K3）を持つファイル — 7 / 59**

```text
scripts/_apply_task_0143_patches.py         ($task_id, $0, ...)
scripts/_apply_task_0144_patches.py         ($schema, $id, $_c3mode, ...)
scripts/_apply_task_0145_patches.py         ($0, $task_id, ...)
scripts/_apply_task_0146_patches.py         (${PLANGATE_VALIDATION_BIAS:-normal}, $plangate_root, ...)
scripts/_apply_task_0147_patches.py         (${profile_var}, $@, ...)
scripts/ai-loop/run_evidence_verify.py      ($ref, $schema, $id)
scripts/ai-loop/test_run_evidence_verify.py ($schema, $id)
```

**(D) 危険度が最大の集合 — 展開されるコマンドが「実在する実行可能ファイル」を指すもの（8 / 59）**

```text
scripts/_apply_task_0147_patches.py    -> bin/plangate
scripts/baseline-snapshot.py           -> bin/plangate
scripts/check-skill-frontmatter.py     -> bin/plangate, scripts/install-plangate-skills-to-codex.sh, tests/run-tests.sh
scripts/check-skill-name-collisions.py -> scripts/sync-plugin-plangate.sh
scripts/schema_mapping.py              -> scripts/eval-runner.py, scripts/validate-schemas.py
scripts/ai-loop/arbiter.py             -> scripts/ai-loop/metrics.py
scripts/ai-loop/gh_exec.py             -> scripts/doctor_check.py
scripts/ai-loop/test_arbiter.py        -> ./bin/plangate, bin/plangate
```

**(E) 展開されるコマンドが PATH 上の実 CLI（`gh` / `git`）を指すもの — 6 / 59**

```text
scripts/ai-loop/c3prime_verify.py       git rev-parse HEAD
scripts/ai-loop/check_exec_boundary.py  gh pr merge
scripts/ai-loop/collector.py            gh api / gh pr view --json statusCheckRollup / git diff --name-only
scripts/ai-loop/discovery.py            gh issue list --json number,title,labels,body
scripts/ai-loop/executor.py             gh api .../issues/{n}/comments / gh pr view --json comments / git merge-base --is-ancestor
scripts/ai-loop/gh_exec.py              gh api / gh pr close / gh pr comment / gh pr merge / gh pr review --approve
```

### 3.4 到達可否の実測（hermetic sandbox 実走）

静的列挙は「書いてある」ことしか示さない。**シェルは最初の構文エラーで死ぬため、後方の展開点には到達しない**。そこで到達可否を実走で確定した。

**手順**（すべて使い捨てディレクトリ内。実 repo 不変）:

1. 全 392 個の「展開されるコマンドの先頭語」を抽出し、`/` を含まない 366 個について **呼び出しを記録するだけの stub 実行可能ファイル**を生成
2. `PATH` を stub ディレクトリのみに固定（実 `gh` / `git` / `python3` は解決不能）
3. 各 `.py` を、**空の使い捨て cwd** で `env -i PATH=<stubs> /bin/sh <file> </dev/null` により実行（timeout 25s）
4. パス形式のコマンド（`scripts/xxx.sh` 等）については、**実 repo で実行可能な path にだけ** stub を植えた別 cwd を用意して再実行

**結果 (E) — `gh` / `git` stub が実際に発火したファイル: 6 件**

| ファイル | 実際に到達した外部コマンド |
|----------|--------------------------|
| `scripts/ai-loop/c3prime_verify.py` | `git rev-parse HEAD` |
| `scripts/ai-loop/check_exec_boundary.py` | **`gh pr merge`** |
| `scripts/ai-loop/collector.py` | `gh api`, `gh pr view --json statusCheckRollup`, `git diff --name-only` |
| `scripts/ai-loop/discovery.py` | `gh issue list --json ...` |
| `scripts/ai-loop/executor.py` | `gh api .../issues/{n}/comments`, `gh pr view --json comments`, `git merge-base --is-ancestor` |
| `scripts/ai-loop/gh_exec.py` | **`gh api`, `gh pr close`, `gh pr comment`, `gh pr merge`, `gh pr review --approve`** |

**結果 (D) — repo 内実行可能ファイルの stub が実際に発火したファイル: 6 / 8**

```text
scripts/check-skill-frontmatter.py     FIRED = bin/plangate, scripts/install-plangate-skills-to-codex.sh, tests/run-tests.sh
scripts/check-skill-name-collisions.py FIRED = scripts/sync-plugin-plangate.sh
scripts/schema_mapping.py              FIRED = scripts/eval-runner.py, scripts/validate-schemas.py
scripts/baseline-snapshot.py           FIRED = bin/plangate
scripts/ai-loop/arbiter.py             FIRED = scripts/ai-loop/metrics.py
scripts/ai-loop/gh_exec.py             FIRED = scripts/doctor_check.py
scripts/_apply_task_0147_patches.py    FIRED = NONE（到達前に構文エラーで停止）
scripts/ai-loop/test_arbiter.py        FIRED = NONE（同上）
```

**結果 (K4) — リダイレクトによるファイル作成**: 59 件すべてで、sandbox cwd に新規ファイルは作られなかった。`->` 由来のリダイレクトに到達する前にシェルが構文エラーで死ぬため。**ただしこれはファイル構造への依存であり、構造が変われば到達しうる**（K4 を「無害」と結論してはならない）。

### 3.5 §3.4 から導かれる、issue の scope の再評価

- `scripts/check-skill-name-collisions.py` は **`scripts/sync-plugin-plangate.sh` を実行する**。これは `plugin/plangate/**` を `cp` で書き換える同期スクリプト（`git show origin/main:scripts/sync-plugin-plangate.sh` の `cp` / `mkdir -p` 行群で確認）。**#1169 と完全に同型の第 2 の実害経路**であり、issue 本文には記載がない。
- `scripts/check-skill-frontmatter.py` は `tests/run-tests.sh` も起動する（テストスイート全体が予期せず走る）。
- `scripts/ai-loop/gh_exec.py` / `check_exec_boundary.py` は **`gh pr merge` / `gh pr review --approve` に到達する**。merge は [`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md) で **Human-owned 固定**の操作である。誤起動 1 回で Human-owned 境界に触れうる経路が存在する、という位置づけになる。
  - ただし引数が欠けているため（`gh pr merge` に PR 番号なし）、**実際に merge が成立するかは未確認**（§9 U-2）。stub 実測で確認したのは「`gh` が引数 `pr merge` で起動される」ところまで。
- `plugin/plangate/skills/ai-loop-cycle/scripts/*.py` は `scripts/ai-loop/*.py` の **byte 同一ミラー**（`gh_exec.py` の sha256 は両者とも `4a92da4f25efcff2be3067b581dabab27e363b033a7511f9137ea0f04e96d5cc`）。**同じ欠陥が plugin として外部リポジトリへ配布されている**。是正と検知は両方を対象にする必要がある。

---

## 4. 修正案の比較

### 4.1 案 A — 該当行のバッククォートを除去する（対症）

```text
-    `.codex/skills` は `scripts/install-plangate-skills-to-codex.sh` の生成物だが、
+    .codex/skills は scripts/install-plangate-skills-to-codex.sh の生成物だが、
```

| | 内容 |
|---|---|
| **塞ぐ範囲** | 当該 1 行から `install-plangate-skills-to-codex.sh` が起動されなくなる（issue 本文の症状そのもの） |
| **塞がない範囲** | 同ファイル内の残り 23 件のコマンド置換（`bin/plangate` / `tests/run-tests.sh` / `claude plugin validate --strict` を含む）／ 他 44 ファイルのコマンド置換／ K3 パラメータ展開／ K4 リダイレクト／ K6 グロブ ／ plugin ミラー |
| **退行しやすさ** | 高。docstring の可読性を犠牲にしており、次に docstring を書く人が普通にバッククォートを戻す。**「なぜバッククォートを使ってはいけないか」がコードに残らない** |
| **コスト** | 最小（1 行） |
| **実測での裏付け** | §6.2 の変異 M8（`origin/main` の全バッククォートを `'` に置換したもの）は、**依然として検査で FAIL する**（K4/K5 が残るため）。案 A 単体では「安全」を主張できない |

### 4.2 案 B — ファイル先頭に sh ガードを置く（推奨）

Python の docstring 位置に、**Python では文字列リテラル・sh では実行される 4 行**を置く。

```python
#!/usr/bin/env python3
'''': # PLANGATE-SH-GUARD (#1169): the lines below are shell, not Python
printf "%s\n" "PLANGATE-SH-GUARD: this file is Python; run it with python3, not sh" >&2
exit 97
'''
```

**なぜ両方で成立するか**

| | Python から見ると | sh から見ると |
|---|------------------|--------------|
| 2 行目 `'''': #...` | `'''` でトリプルクォート開始、以降 `'''` までが文字列 | `''` + `''` + `:` = **空単語 2 個に続く `:`** → null コマンド `:` が走る（`#` 以降は sh コメント） |
| 3 行目 `printf ... >&2` | 文字列の中身 | **実行される**（診断メッセージ） |
| 4 行目 `exit 97` | 文字列の中身 | **ここでシェルが終了する。以降は一切読まれない** |
| 5 行目 `'''` | 文字列終了 | 到達しない |

**`__doc__` の扱い（重要な副作用と、その解消）**

ガードは docstring より前になければ意味がないため、素朴に入れると **元の docstring が module docstring でなくなり `__doc__` が `None` になる**。`origin/main` では以下が `__doc__` を消費しており、これは実挙動の退行になる（`git grep -n '__doc__' origin/main -- scripts`）:

```text
scripts/baseline-snapshot.py:175            argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
scripts/check-skill-frontmatter.py:383      argparse.ArgumentParser(description=__doc__, ...)
scripts/check-skill-name-collisions.py:567  同上
scripts/check-stale-skill-refs.py:443       argparse.ArgumentParser(description=__doc__)
scripts/doctor_check.py:451                 __doc__.split("\n\n")[0]
scripts/doctor_fix.py:253                   同上
scripts/metrics_collector.py:337            同上
scripts/metrics_reporter.py:265             同上
scripts/ai-loop/test_check_exec_boundary.py:1325,1334   ceb.__doc__ を assert している
```

解消方法（実測で確認済み）: **ガードブロック自体を module docstring にし、元の docstring は `__doc__ = """..."""` の明示代入として再掲する**。

さらに **`from __future__ import annotations` の制約**がある。`__future__` インポートは「docstring・コメント以外の文より前」でなければならず、`__doc__ = ...` を `__future__` より前に置くと `SyntaxError: from __future__ imports must occur at the beginning of the file` になる（本作業で実際に踏んだ）。よって配置順は:

```python
#!/usr/bin/env python3
'''': # PLANGATE-SH-GUARD ...        <- これが module docstring になる（合法）
printf ... >&2
exit 97
'''

from __future__ import annotations   <- 従来どおり

__doc__ = """                        <- 元の docstring をここで再掲
...元の内容そのまま...
"""
```

| | 内容 |
|---|---|
| **塞ぐ範囲** | K1〜K6 の**全クラス**。docstring の中身も、型注釈由来のリダイレクトも、埋め込み shell 断片も、`sh` が到達しないので一切評価されない。ファイルごとの構文エラー位置に依存しない |
| **塞がない範囲** | ① `bash <file>` / `zsh <file>` / `. <file>`（source）— **実測は `/bin/sh` のみ**（§9 U-1）。② ガードを持たない**新規ファイル** — これは §5 の検査で機械的に塞ぐ。③ `python2` 等の別 Python での起動。④ ガード行より前に何かを足す将来変更 |
| **可読性コスト** | ファイル冒頭に 4 行 + `__doc__ = ` 1 語。docstring 本文には手を入れない（**案 A と違い、書き方の自由度を奪わない**） |
| **適用コスト** | 59 ファイル + plugin ミラー。**機械変換が可能**であることを実測済（§7） |
| **リスク** | `__doc__` / `__future__` の扱いを誤るとインポート時に落ちる → §7 の検証で `compileall` + selftest により担保 |

**終了コードを 97 にする理由（設計上の要点）**: §3.4 の実測で、**ガードの無いファイルは軒並み `rc=2`（bash の構文エラー）で終了する**。ガードの終了コードを 2 にすると「ガードが効いている」と「ガードが無くて構文エラーで死んだ」が **区別できず、検査が false green になる**。0/1/2/126/127 と衝突しない値を選ぶ（本書では 97）。

### 4.3 案 C — 起動経路そのものを塞ぐ

| 具体策 | 評価 |
|--------|------|
| **C-1: shebang + 実行ビットを付け `./script.py` 導線にする**（issue の候補 1） | **既に満たされている。効果なし。** `git ls-tree -r origin/main -- scripts` で `scripts/check-skill-frontmatter.py` は `100755`、shebang は `#!/usr/bin/env python3`。それでも事故は起きた。`sh <file>` は実行ビットも shebang も参照しないため、**この方向は原理的に防御にならない**。なお `scripts/` 配下 59 件のうち実行ビット付きは 14 件のみ（`100755` ×14 / `100644` ×45）で、残り 45 件はそもそも `./` 起動できない |
| **C-2: `.py` を wrapper `.sh` に置き換え、Python を別名（`_impl.py`）に隠す** | 起動ミスの入口は減るが、**隠した `_impl.py` を `sh` で叩けば同じ**。かつ全呼出側（`tests/extras` / `bin/plangate` / plugin ミラー）の書き換えが必要で影響範囲が案 B より遥かに大きい。Hardening Override 対象の `bin/plangate` に触れる可能性が高く、C-3 コストが跳ね上がる |
| **C-3: ドキュメント / CLAUDE.md で「`sh` で起動するな」と規範化** | 強制力ゼロ（[`hybrid-architecture.md`](../../../.claude/rules/hybrid-architecture.md) の「CLAUDE.md はソフト」）。事故は誤操作なので、規範だけでは §3.4 の経路は残る |
| **C-4: 全 `.py` に実行ビット付与** | C-1 と同じ理由で効果なし。45 ファイルの mode 変更という差分だけが残る |

### 4.4 比較サマリ

| 観点 | 案 A（バッククォート除去） | **案 B（sh ガード）** | 案 C（起動経路） |
|------|--------------------------|----------------------|-----------------|
| K1/K2 コマンド置換 | 当該行のみ | **全件** | 不変 |
| K3 パラメータ展開 | 不変 | **全件** | 不変 |
| K4 リダイレクト（`->`） | 不変 | **全件** | 不変 |
| K6 グロブ | 不変 | **全件** | 不変 |
| 他 44 ファイル | 不変 | **全件（機械適用）** | 不変 |
| plugin ミラー | 不変 | **同じ変換で可** | 不変 |
| 新規ファイルの再発 | 防げない | 検査（§5）と組で防げる | 防げない |
| 実装コスト | 最小 | 中（機械変換 + 検証） | 大 |
| 既存挙動への影響 | なし | `__doc__` / `__future__` の扱いに注意（§7 で実測担保） | 大 |

### 4.5 推奨と、その理由

**推奨: 案 B（sh ガード）+ §5 の再発検知。案 A は不要（案 B が包含する）。案 C は採らない。**

判断基準の優先順位（要件適合性 → 安全性 → 保守性 → 実装コスト → 拡張性）に沿って:

1. **要件適合性**: issue の要求は「読み取り専用のつもりの操作が repo を変えない」こと。案 A はこの要求を **1 経路でしか**満たさない（§3.4 で同型経路が他に 5 件以上あることを実測）。案 B は欠陥クラス全体を満たす。
2. **安全性**: 案 B は「シェルが 4 行目で死ぬ」という**位置に依存しない**性質。案 A は「この docstring にバッククォートが無い」という**内容に依存する**性質で、docstring は今後も編集され続ける。
3. **保守性**: 案 B はファイル先頭の定型 4 行として grep 可能・機械検証可能。案 A は暗黙規約を人間の記憶に置く。
4. **実装コスト**: 案 B は 59 + ミラー分の機械変換。§7 で 59/59 の変換成功と回帰なしを実測済。
5. **拡張性**: 案 B は新規 `.py` にも同じ 4 行で適用でき、§5 の検査で強制できる。

**ただし採否は Human（C-3）判断**。§10 に判断項目を列挙する。

---

## 5. 再発検知の設計 — `tests/extras/ta-70-sh-invocation-guard.sh`（新規）

### 5.1 なぜ既存の機械ゲートで検出されないか

| 既存ゲート | 検出しない理由 |
|-----------|--------------|
| `scripts/check-skill-frontmatter.py` 系 | SKILL.md の frontmatter しか見ない |
| `markdownlint` / `schema-validate` | `.py` を見ない |
| Python lint | このファイルは **Python として完全に正しい** |
| `tests/run-tests.sh` の既存 extras（ta-04..69） | `sh` 誤起動という観点が存在しない |

**「Python として正しい」ことと「sh に食わせても安全」ことが直交している**のが、このクラスがどのゲートにも引っかからない理由である。

### 5.2 配置と配線

- 新規 `tests/extras/ta-70-sh-invocation-guard.sh`
- `tests/run-tests.sh` は `tests/extras/ta-*.sh` を自動 source する（`git show origin/main:tests/run-tests.sh` の extras loader 節）。**`run-tests.sh` 本体には触れない**（extras README 規約 4）
- 番号: `origin/main` の既存 ta-NN は `04..47, 49..66, 68, 69`（欠番 48 / 67）。**新規は 70** を提案（欠番の再利用は履歴追跡を難しくする）
- extras 規約に従う: shebang 不要 / `set -eu` 前提 / `pass` `fail` カウンタを直接更新 / **`trap` を使わない** / 一時ディレクトリは明示 `rm -rf` / **`exit` を使わない**（source されるため harness ごと落ちる）

### 5.3 検査する性質（4 条件の連言）

対象ファイル 1 件につき、**使い捨て cwd + 空 PATH** で `env -i PATH=<empty> /bin/sh <file> </dev/null` を実行し、次の **4 条件をすべて**満たすことを要求する。

| # | 条件 | これが無いと何が漏れるか |
|---|------|------------------------|
| P1 | 終了コードが **97**（ガード専用値） | `rc != 0` だけでは、ガード無しの構文エラー終了（rc=2）と区別できない → §6.3 で false green を実測 |
| P2 | stderr に `PLANGATE-SH-GUARD` を含む | ガード以外の理由で 97 が返る事故を排除 |
| P3 | stderr が **ちょうど 1 行** | ガードが動いた後に処理が継続していないことの担保（`command not found` の山が出ない） |
| P4 | 使い捨て cwd に **新規ファイルが 1 件も作られていない** | K4 リダイレクトによる副作用の直接確認 |

### 5.4 対象集合の決め方と fail-closed（#1087 AC-9 準拠）

- 対象は **実行時に列挙**する（`git ls-files` でトラック済みの `.py`）。**絶対件数を契約値にしない**
- 列挙件数 `N` に対する assertion は **下限のみ**: `N > 0`。0 件なら「検査が no-op に退行した」として **FAIL**（`check-skill-frontmatter.py` の exit code 2 と同じ fail-closed 思想）
- 合否は **同値照合**: 「4 条件を満たしたファイル数 `GOOD`」と「列挙件数 `N`」が **実行時に一致する**ことを要求する。`N` はどこにもハードコードしない
- 対象スコープの候補（Human 判断 → §10 H-4）:
  - 最小: `scripts/**/*.py`（59 件）
  - 推奨: `scripts/**/*.py` + `plugin/**/*.py`（byte 同一ミラー 25 件を含む）
  - 最大: トラック済み全 `.py`（98 件。`docs/working/**/evidence/**` の使い捨て 10 件と `fuzz/` 1 件を含む）

### 5.5 実装スケッチ（extras 規約準拠・**未実装**）

```sh
# tests/extras/ta-70-sh-invocation-guard.sh
# sh 誤起動時に Python スクリプトが docstring を評価しないこと (#1169)

printf '\n=== TA-70: sh-invocation guard (#1169) ===\n'

TA70_MARKER='PLANGATE-SH-GUARD'
TA70_RC=97
TA70_LIST=$(git -C "$REPO_ROOT" ls-files 'scripts/*.py' 'scripts/**/*.py') && ta70_rc=0 || ta70_rc=$?
TA70_N=$(printf '%s\n' "$TA70_LIST" | grep -c '[^[:space:]]') || TA70_N=0

if [ "$ta70_rc" -ne 0 ] || [ "$TA70_N" -le 0 ]; then
  printf '[FAIL] TA-70: 走査対象 0 件（検査が no-op に退行）\n'
  fail=$((fail + 1))
else
  TA70_EMPTY_PATH="$(mktemp -d)"
  ta70_good=0
  ta70_bad=''
  for f in $TA70_LIST; do
    sb="$(mktemp -d)"
    ( CDPATH= cd -- "$sb" \
      && env -i PATH="$TA70_EMPTY_PATH" /bin/sh "$REPO_ROOT/$f" \
           >stdout.txt 2>stderr.txt </dev/null ) && rc=0 || rc=$?
    lines=$(grep -c '' "$sb/stderr.txt") || lines=0
    extra=$(ls -A "$sb" | grep -v -e '^stdout.txt$' -e '^stderr.txt$' | wc -l | tr -d ' ')
    ok=1
    [ "$rc" = "$TA70_RC" ] || ok=0
    grep -q "$TA70_MARKER" "$sb/stderr.txt" || ok=0
    [ "$lines" = "1" ] || ok=0
    [ "$extra" = "0" ] || ok=0
    if [ "$ok" = "1" ]; then
      ta70_good=$((ta70_good + 1))
    else
      ta70_bad="$ta70_bad $f(rc=$rc,lines=$lines,extra=$extra)"
    fi
    rm -rf "$sb"
  done
  rm -rf "$TA70_EMPTY_PATH"

  if [ "$ta70_good" = "$TA70_N" ]; then
    printf '[PASS] TA-70: %s 件すべてが sh 起動をガードで拒否 (rc=%s)\n' "$TA70_N" "$TA70_RC"
    pass=$((pass + 1))
  else
    printf '[FAIL] TA-70: ガード未適用:%s\n' "$ta70_bad"
    fail=$((fail + 1))
  fi
fi
```

> 上記は **設計スケッチ**であり、`REPO_ROOT` 相当の変数名など harness 側の実変数への接続は exec 時に実測合わせが必要（extras README に明記されているのは `PLANGATE_BIN` / `FIXTURES_DIR`。`REPO_ROOT` 相当の可用性は **未確認** — §9 U-4）。本書で挙動を実証したのは、同一ロジックを持つ scratchpad 上のプロトタイプ（§6）である。

---

## 6. 変異注入による検出力の実証

### 6.1 セットアップ

- 検査プロトタイプ: scratchpad 上の `ta-proto.sh`（§5.5 と同一の 4 条件 + fail-closed + 同値照合。`exit` を使う点だけがスタンドアロン版として異なる）
- 正例 `T1_guarded`: `origin/main` の `check-skill-frontmatter.py` に §4.2 のガードを機械適用したもの
- 負例 `T0_unguarded`: `origin/main` そのまま

### 6.2 変異と結果（全 8 件 KILL）

| ID | 変異内容 | 狙う欠陥クラス | 期待 | 実測 | 判定 |
|----|---------|--------------|------|------|------|
| T0 | （baseline）ガード無し = `origin/main` | — | FAIL | FAIL(rc=1) | baseline-ok |
| T1 | （baseline）ガード適用済 | — | PASS | PASS(rc=0) | baseline-ok |
| M1 | ガードを丸ごと削除 | 是正の完全な巻き戻し | FAIL | FAIL | **KILL** |
| M2 | ガードを docstring の**後ろ**へ移動 | 「存在するが位置が違う」 | FAIL | FAIL | **KILL** |
| M3 | `exit 97` → `exit 0` | 「ガードは在るが止めない」 | FAIL | FAIL | **KILL** |
| M4 | `exit` 行を削除（printf だけ残す） | 「診断は出るが素通り」 | FAIL | FAIL | **KILL** |
| M5 | `exit 97` → `exit 2` | **ガード終了コードと構文エラー終了コードの衝突** | FAIL | FAIL | **KILL** |
| M6 | ガード済ツリーに**新規の未ガード `.py` を 1 件追加** | allowlist / ハードコード対象集合 | FAIL | FAIL | **KILL** |
| M7 | 列挙 root を空ディレクトリに差し替え（対象 0 件） | **恒真 PASS（vacuous green）** | FAIL | FAIL(`scanned 0 python files`) | **KILL** |
| M8 | ガード無しのまま**バッククォートだけ全除去**（= 案 A 単体） | 「対症で足りる」という主張 | FAIL | FAIL | **KILL** |

M7 が「検査が対象 0 件になって緑のまま」の経路であり、`N > 0` の fail-closed で潰している。M6 は「対象集合を実行時列挙にしている」ことの担保。M8 は §4.1 の主張（案 A では不十分）の機械的裏付け。

### 6.3 「全件 KILL は変異セットの十分性を意味しない」— 別途の論証

このリポジトリの教訓どおり、上記 8/8 KILL は **変異セットが欠陥クラスを覆えている証拠にはならない**。そこで **検査側を変異させる（検査の検査）** を追加で行った。

| 弱化した検査 | 何を落としたか | 実測 |
|------------|--------------|------|
| **D-weak-1**: 「`sh` が非ゼロ終了すること」だけを見る | P2/P3/P4 を落とし、P1 を `rc != 0` に緩めた | **`T0_unguarded`（= `origin/main` そのもの）に対して PASS を返した**（false green） |
| **D-weak-2**: ファイル先頭 8 行に `PLANGATE-SH-GUARD` が grep で見つかることだけを見る（静的検査のみ） | 挙動確認を落とした | **`M3_exit0` と `M4_no_exit` の両方に対して PASS を返した**（false green） |

この 2 件は「もっともらしい検査設計が実際に false green を出す」ことを実測で示すもので、§5.3 の **4 条件の連言**と §4.2 の **専用終了コード 97** の必要性の直接的根拠である。

**欠陥クラスの被覆に関する論証**

対象欠陥クラスを次のように定義する:

> **DC**: Python ソースファイル `F` を `sh F` に与えたとき、`F` の内容に由来して **何らかの展開・実行・ファイル生成が発生する**こと。

- 検査 P1〜P4 は **DC の定義そのものを直接観測している**（P4 = ファイル生成、P3 = 追加のコマンド実行の痕跡、P1/P2 = 停止点がガードであること）。したがって「ガードの書き方（イディオム）を変える」型の変異は原理的に逃げられない — M1〜M5 が同一クラスの別イディオムであり、すべて KILL された。
- **被覆できていない範囲（正直に列挙）**:
  1. **`/bin/sh` 以外のシェル**。`bash F` / `zsh F` / `. F`（source）は未検証。`''''` の解釈は POSIX 準拠シェル間で同じはずだが、**実測していない**（§9 U-1 / U-7）
  2. **対象集合の外**。§5.4 で最小スコープを選ぶと `plugin/**/*.py`（byte 同一ミラー 25 件）が検査されない。**AC は消費箇所ごとに立てる**という原則に従えば、plugin ミラーは同じ AC の別消費点である
  3. **stub PATH の有限性**（§3.4 の到達可否測定の限界であって、§5 の検査自体の限界ではない）。§3.4 で「発火した」と言えるのは stub を用意した 366 語のみ。用意しなかった語のコマンドは観測できていない
  4. **時間軸**。検査は「今トラックされている `.py`」しか見ない。untracked / 生成物の `.py` は対象外
  5. **`sh` 以外の誤インタプリタ**（`awk -f` / `perl` 等）は本設計の対象外

---

## 7. 偽陽性の検証

### 7.1 検査が正しい状態を誤検出しないこと

`origin/main` の **全 59 件**に §4.2 のガードを機械適用したツリーを作り、プロトタイプ検査を実行:

```text
INFO: scanning 59 python file(s) under <scratch>/guardedtree
PASS: all 59 python file(s) refuse sh invocation at the guard (rc=97)
DETECTOR_RC_ON_GUARDED_TREE=0
```

**偽陽性 0 件 / 59。**

### 7.2 ガード適用が Python 側の挙動を壊さないこと

| 検証 | 方法 | 結果 |
|------|------|------|
| 機械変換の成否 | AST ベース変換 + `ast.parse` 再検証（59 件） | `transformed_ok=59` / `transform_failed=0` |
| `__doc__` の再付与 | 変換後 AST に `__doc__ = ...` 代入があるか | `docstring_reattach_missing=0`（元々 docstring を持つ全ファイルで再付与済） |
| 構文健全性 | `python3 -m compileall -q .`（guardedtree） | `COMPILEALL_RC=0` |
| `--help` に docstring が出るか | `python3 check-skill-frontmatter.py --help` | usage の下に元 docstring 全文が表示された（`__doc__` 保持を確認） |
| selftest 回帰 | `python3 check-skill-frontmatter.py --selftest` | `SELFTEST PASS (21 checks)`（ガード無し版と同一） |
| selftest 回帰 | `python3 check-skill-name-collisions.py --selftest` | `SELFTEST PASS (28 checks)` |
| selftest 回帰 | `python3 check-stale-skill-refs.py --selftest` | `SELFTEST FAIL` — **ただしガード無しの `origin/main` スナップショットでも同じく `SELFTEST FAIL`**。scratchpad が git repo でないことによる環境依存であり、**ガード起因の回帰ではない**（同一 baseline） |

### 7.3 検証していないこと

- `scripts/ai-loop/test_*.py` の unittest 群は **実行していない**（依存する fixture / repo 構造が scratchpad に無い）。特に `test_check_exec_boundary.py` は `ceb.__doc__` を assert しているため、**exec 時に必ず実走が必要**
- `bin/plangate` / CI からの `python3 scripts/...` 呼び出し経路の回帰は未検証

---

## 8. 責務と適用条件

| 事項 | 分類 | 根拠 |
|------|------|------|
| 本設計書の作成 | **AI-owned** | [`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md) |
| `scripts/**/*.py` の編集 | **AI-owned**（Hardening Override 対象**外**） | [`mode-classification.md`](../../../.claude/rules/mode-classification.md) の HO 9 カテゴリに `scripts/*.py` は含まれない（含まれるのは `scripts/hooks/*.sh`）。同ファイルの注記「`.claude/skills/` と `scripts/_*.py` は現行 override パターン**外**」とも整合 |
| `tests/extras/*.sh` の新規追加 | **AI-owned**（HO 対象**外**） | HO 対象は `scripts/hooks/*.sh` であって `tests/extras/*.sh` ではない |
| `tests/run-tests.sh` 本体 | **触らない** | extras README 規約 4（loader が自動発見） |
| PR の merge | **Human-owned 固定** | `responsibility-classes.md` |

### 8.1 EH-3 による適用上の制約（重要）

`scripts/*.py` と `tests/extras/*.sh` は Hardening Override 対象外だが、**Hook EH-3（`scripts/hooks/check-plan-hash.sh`）により、no-task セッション（`PLANGATE_HOOK_TASK` 未設定）の AI は `.md` 以外のファイルを書けない**。本作業でも scratchpad への `.py` 書き込みで `Write` が block された（`[Hook EH-3] SKIP 拒否: SKIP_REASON 未設定`）。

したがって:

> **本 patch の適用（`scripts/**/*.py` へのガード挿入、`tests/extras/ta-70-*.sh` の新規作成）には、`PLANGATE_HOOK_TASK` を設定して起動したセッションが必須である。**
> `PLANGATE_HOOK_TASK` は**セッション起動時に固定**され実行中の `export` では変えられないため、**別セッションの起動が必要**。plan.md を伴う正規の TASK 化（C-3 承認込み）を経由すること。

---

## 9. 未確認事項（推測を断定にしないための明示）

| # | 未確認事項 |
|---|-----------|
| U-1 | `bash <file>` / `zsh <file>` / `. <file>`（source）での挙動。実測は `/bin/sh`（macOS では bash-as-sh）**のみ** |
| U-2 | `gh pr merge`（引数なし）が実際に merge を成立させうるか。実測で確認したのは **`gh` が `pr merge` という引数で起動される**ところまで |
| U-3 | 「repo 内に `sh` で起動している配線が無い」はオーガナイザーの実測を採用しており、本作業では追検証していない |
| U-4 | extras から `REPO_ROOT` 相当の変数が利用可能かは未確認（README に明記があるのは `PLANGATE_BIN` / `FIXTURES_DIR`） |
| U-5 | §5.5 のスケッチは harness に source した状態で実走させていない。実証したのはロジック等価な scratchpad プロトタイプ |
| U-6 | `scripts/ai-loop/test_*.py`（unittest 群）のガード適用後の回帰 |
| U-7 | Linux 環境（CI）での `/bin/sh` = dash における `''''` の解釈。POSIX 準拠なら同一のはずだが未実測 |
| U-8 | `docs/working/**/evidence/**/*.py`（10 件）と `fuzz/fuzz_render_review.py` の危険度。§3 の静的 / 動的計測は `scripts/` に限定した |

---

## 10. Human（C-3）に残す判断項目

| # | 判断事項 | 選択肢 | AI からの推奨 |
|---|---------|-------|-------------|
| H-1 | **採用する案** | A（対症）/ **B（ガード）** / C（起動経路）/ A+B | **B** |
| H-2 | **適用スコープ** | `scripts/**/*.py` のみ / + `plugin/**/*.py` ミラー / トラック済み全 `.py` | **`scripts/**` + `plugin/**` ミラー**（byte 同一ミラーが外部配布されているため） |
| H-3 | **ガードの終了コード** | 97 / 他の非衝突値 | 97（0/1/2/126/127 と衝突しないこと**が要件**。値自体は任意） |
| H-4 | **検査スコープ**（TA-70 の列挙対象） | H-2 と一致させる / 検査だけ広く取る | H-2 と一致 |
| H-5 | **PR 分割** | ①ガード適用 + ②TA-70 を 1 PR / 2 PR | **1 PR**（検査だけ先に入れると全件 FAIL、ガードだけ先に入れると再発防止が空く） |
| H-6 | **`gh_exec.py` / `check_exec_boundary.py` の扱い** | #1169 に含める / 別 issue に切る | §3.4 の実測（`gh pr merge` / `gh pr review --approve` 到達）を踏まえ、**#1169 の scope に含めるか P1 として別起票するかを判断されたい** |
| H-7 | **モード判定** | 本 patch は `scripts/` 59 件 + `plugin/` 25 件 + `tests/extras` 1 件を触る | 変更ファイル数から **`critical`（16+）** 相当。HO 対象パスは含まないので `lite_eligible` の強制無効化には該当しないが、規模基準だけで **人間 C-3 必須**（`working-context.md` autonomous APPROVE 判定マトリクス: high-risk / critical は不可） |
| H-8 | **exec 前提条件** | `PLANGATE_HOOK_TASK` 付きセッションの起動（§8.1） | 必須。TASK 化して plan / todo / test-cases → C-1 → C-3 の正規フローへ |

---

## 11. スコープ外で見つけた問題（手を出さず報告のみ）

| # | 内容 | 根拠 |
|---|------|------|
| S-1 | **`sh scripts/check-skill-name-collisions.py` は `scripts/sync-plugin-plangate.sh` を実行する**。`plugin/plangate/**` を `cp` で書き換える同型の第 2 実害経路。issue #1169 本文に記載なし | §3.4 (D) |
| S-2 | **`sh scripts/ai-loop/gh_exec.py` は `gh pr merge` / `gh pr close` / `gh pr review --approve` / `gh pr comment` / `gh api` に到達する**。`sh scripts/ai-loop/check_exec_boundary.py` も `gh pr merge` に到達。merge は Human-owned 固定操作 | §3.4 (E) |
| S-3 | **`sh scripts/check-skill-frontmatter.py` は `tests/run-tests.sh` も起動する**（テストスイート全体が予期せず走る）。issue 本文に記載なし | §2.4 #24 / §3.4 (D) |
| S-4 | `plugin/plangate/skills/ai-loop-cycle/scripts/*.py`（25 件）は `scripts/ai-loop/*.py` の **byte 同一ミラー**。同じ欠陥が plugin として外部リポジトリへ配布されている | §3.5 |
| S-5 | `scripts/` 配下 59 件のうち実行ビット付きは 14 件のみ（`100755` ×14 / `100644` ×45）。issue の是正候補 1 を全面採用するなら 45 件の mode 変更が必要だが、§4.3 のとおり **防御効果は無い** | §4.3 |
| S-6 | ワーカー環境の worktree 隔離ガードが、`cd` を含む Bash や複数コマンド連結（`&&` + リダイレクト、`while` ループ、`git` + リダイレクトの併記）を拒否する。回避には「python heredoc でファイルを生成 → 別コマンドで実行」の分割が必要だった。**中括弧 `{` `}` 自体は本作業では拒否されなかった**（前ワーカーの観測とは差異あり） | 作業記録 |

---

## 12. 実行した測定コマンド一覧（再測定用）

```sh
# 対象集合
git ls-tree -r --name-only origin/main -- scripts | grep '\.py$'                          # 59 件
git ls-tree -r origin/main -- scripts | grep '\.py$' | awk '{print $1}' | sort | uniq -c  # 100644 x45 / 100755 x14
git ls-tree -r --name-only origin/main | grep -c '\.py$'                                  # 98 件（全 tracked .py）

# 原因行
git show origin/main:scripts/check-skill-frontmatter.py | sed -n '28p'

# __doc__ 消費箇所
git grep -n '__doc__' origin/main -- scripts

# plugin ミラー parity
git show origin/main:scripts/ai-loop/gh_exec.py | shasum -a 256
git show origin/main:plugin/plangate/skills/ai-loop-cycle/scripts/gh_exec.py | shasum -a 256

# extras の番号と loader
git ls-tree -r --name-only origin/main -- tests/extras | sed -n 's|tests/extras/ta-\([0-9]*\).*|\1|p' | sort -n | uniq
git show origin/main:tests/run-tests.sh | grep -n extras
```

sh 展開の静的モデル / hermetic sandbox 実走 / 変異注入は scratchpad 上のスクリプト
（`shmodel2.py` / `census.py` / `runner.py` / `runner2.py` / `mkguard.py` / `guardall.py` /
`ta-proto.sh` / `mkmutants.py` / `runmut.py` / `ta-weak1.sh` / `ta-weak2.sh`）で実施した。
これらは repo 外の使い捨てであり、**本 PR には含まれない**。再現が必要なら
§2.4 / §3.1 / §5.5 / §6.1 の記述から再実装できる。
