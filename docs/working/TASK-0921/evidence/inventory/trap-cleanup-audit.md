# TASK-0921 Phase 2 — Trap / Cleanup Conflict Audit

> **目的**: Issue #921 Plan Package の **案 C（standalone 時のみ signal 0 trap を張る共通 helper）** が
> 採用可能かを、C-1 レビュー指摘 C1-M1（未検証 load-bearing assumption）に対して **実測で決着させる**。
> **本監査は読み取り専用**。`tests/` `scripts/` `bin/` `.github/` は 1 行も変更していない。

| 項目 | 値 |
|------|-----|
| 監査日 | 2026-08-05 |
| 監査ブランチ / HEAD | `main` / `12424208b347ae8e48dd6ac99cc7c883f91751ff` |
| 備考 | 依頼時に提示された `4448420`（PR #1008 merge）は HEAD の 2 世代前。以降 `dfeeed3`→`4448420`→`ded2b4c`→`12424208` と main が進行。**本監査対象ファイル（tests/ 配下）に差分なし**（`git log --oneline` 上、後続 2 commit は `docs/working` のみ） |
| 監査対象 | `tests/extras/ta-*.sh` **57 件**（実測、`find tests/extras -maxdepth 1 -type f -name 'ta-*.sh' \| wc -l`）+ `tests/run-tests.sh` **1 件** = **計 58 件** |
| 結論 | **案 D へ Replan 推奨**（§6 参照） |

---

## 0. 実行したコマンドと exit code

すべて読み取り専用（`find` / `grep` / `sed` / `git log` / `git rev-parse`）。
実測用の trap セマンティクス実験のみ scratchpad 内の合成スクリプトに対して実行した（repo 非接触）。

| # | コマンド（要旨） | exit code |
|---|---|---|
| 1 | `find tests/extras -maxdepth 1 -type f -name 'ta-*.sh' \| wc -l` → `57` | 0 |
| 2 | `git rev-parse HEAD` / `git branch --show-current` / `git log --oneline -3` | 0 |
| 3 | `grep -n "trap" tests/extras/ta-*.sh tests/run-tests.sh` | 0 |
| 4 | `grep -n "rm -rf\|rm -f\|register_cleanup\|cleanup()\|_cleanup" tests/extras/ta-*.sh tests/run-tests.sh` | 0 |
| 5 | `grep -n "^trap " …`（top-level 判別）/ `grep -n "^[[:space:]]\+trap " …`（インデント） | 0 |
| 6 | `sed -n` による ta-07 / ta-09 / ta-24 / ta-28 / ta-45 / ta-54 / run-tests.sh の該当箇所精読 | 0 |
| 7 | `grep -c "^[[:space:]]*trap[[:space:]]" tests/run-tests.sh` → **`0`** | 1（該当なし） |
| 8 | early exit 経路列挙（`grep -nE 'return 0 2>/dev/null\|(\|\|\|;)[[:space:]]*exit[[:space:]]+[0-9]'`） | 0 |
| 9 | per-file インベントリ生成（`sh -c 'for f in …; do … done'`、zsh 単語分割回避のため `sh -c` 経由） | 0 |
| 10 | trap セマンティクス実験 exp1〜exp7（scratchpad 内合成スクリプト） | 0 |

**注**: extras の standalone 実走（`sh "$f" </dev/null`）は **実行していない**。
理由: (a) 別セッションが同一 checkout で並行作業中、(b) ta-07 / ta-09 / ta-34 / ta-37 / ta-42 / ta-44 / ta-45 /
ta-54 は **実 repository の tracked path を書き換え・削除する**（§3）ため、並行作業中の実行は
INC 級の汚染リスクがある。trap セマンティクスの決着に必要な事実は §2 の合成実験で完全に代替できた。

---

## 1. trap 保有ファイル一覧（実測）

`trap` を含む実行文を持つのは **5 ファイルのみ**（残り 52 extras + run-tests.sh は trap を一切張らない）。

| ファイル | 行 | trap 文 | スコープ | 判定 |
|---|---|---|---|---|
| `ta-07-eval-runner.sh` | 13 | `trap cleanup_eval EXIT INT TERM` | `if` ブロック内（**= top-level shell**） | **top-level exit trap** |
| `ta-07-eval-runner.sh` | 49 | `trap - EXIT INT TERM` | 同上 | **trap 解除（harness trap も道連れ）** |
| `ta-09-metrics.sh` | 23 | `trap cleanup_metrics EXIT INT TERM` | col-0 | **top-level exit trap** |
| `ta-24-parallel-review.sh` | 252 | `trap 'rm -rf "$t24_tmpdir4"' EXIT INT TERM` | `if` ブロック内（**= top-level shell**） | **top-level exit trap** |
| `ta-24-parallel-review.sh` | 280 | `trap - EXIT INT TERM` | 同上 | **trap 解除** |
| `ta-28-plugin-version.sh` | 87 | `trap 'cp "$_bak" "$_t28_mp" …; rm -f "$_bak"' EXIT INT TERM` | **`$( … )` コマンド置換サブシェル内** | subprocess-only（親を汚染しない） |
| `ta-28-plugin-version.sh` | 114 | `trap 'rm -rf "$_sh"' EXIT INT TERM` | **`$( … )` コマンド置換サブシェル内** | subprocess-only（親を汚染しない） |
| `ta-45-c3-mode-config.sh` | 76 | `trap cleanup_t45 EXIT` | col-0 | **top-level exit trap** |
| `ta-45-c3-mode-config.sh` | 224 | `trap - EXIT` | col-0 | **trap 解除** |

### 集計

| 分類 | 件数 | ファイル |
|---|---|---|
| **top-level exit trap を張るファイル** | **4** | `ta-07`, `ta-09`, `ta-24`, `ta-45` |
| うち `trap - EXIT` で解除するファイル | **3** | `ta-07`, `ta-24`, `ta-45` |
| subprocess-only trap のみのファイル | 1 | `ta-28`（2 箇所とも `$( )` 内） |
| trap を一切持たないファイル | **53** | 残り 52 extras + `tests/run-tests.sh` |
| **`tests/run-tests.sh` の trap 数** | **0**（実測 `grep -c` = 0） | — |

> **インデント ≠ サブシェル**: ta-07 / ta-24 の trap は 2 スペースインデントだが、
> 囲みは `if … then … fi` であり **同一シェルプロセス**。実測（§2 exp2）で
> top-level 登録されることを確認済み。C-1 が「未検証」とした最大の論点はここ。

### trap 上書き（同一実行内での多重登録）

`run-tests.sh` は 57 extras を `. "$extra"` で **同一シェルに順次 source** する（`tests/run-tests.sh` L167-174）。
そのため source 順（辞書順）で **ta-07 → ta-09 → ta-24 → ta-45** の 4 つの top-level EXIT trap が
**互いに上書き**し、さらに ta-45 L224 の `trap - EXIT` が **最終的に全部を消す**。
これは `tests/extras/README.md` L81-83「**trap は使わない**」および L127-146（#530-3 規約）が
すでに明文化している既知の破綻であり、本監査で実測により再確認した。

---

## 2. trap セマンティクスの実測（合成実験 / repo 非接触）

scratchpad 内に harness 相当と extras 相当の合成スクリプトを作り、`sh` で実行した。

| 実験 | 内容 | 実測結果 | 案 C への含意 |
|---|---|---|---|
| **exp1** | harness が自前 EXIT trap を持ち、a.sh（if 内 trap）→ b.sh（trap）→ c.sh（`trap - EXIT`）を source | **`cleanup_a` / `cleanup_b` / `HARNESS FINALIZER` の 3 つとも 1 つも発火しない** | **決定的**。source 連鎖で後段の `trap - EXIT` が harness finalizer まで消す |
| **exp2** | `if true; then trap … EXIT; fi` を source | `cleanup_a ran` が親シェル終了時に発火 | **インデントは subshell を意味しない**。ta-07 / ta-24 は top-level trap で確定 |
| **exp3** | `v=$(trap "echo SUBTRAP" EXIT; echo x)` | `SUBTRAP` はサブシェル終了時のみ。親は無傷 | ta-28 方式（サブシェル閉じ込め）は安全 |
| **exp4** | `trap A EXIT; trap B EXIT` | **`B` のみ発火（`A` は消滅）** | POSIX trap に**合成機能は無い**。後勝ちの完全上書き |
| **exp5b** | `trap -p EXIT` で既存 trap を取り出して合成 | `FIRST` → `SECOND` の順に両方発火（合成は**技術的には可能**） | 合成には `trap -p` が必須 |
| **exp5c** | `trap -p` の可搬性 | `sh`: OK / `bash`: OK / **`dash`: `trap: Illegal option -p`** / **`zsh`: `command not found: -p`** | **`trap -p` は POSIX 非準拠**。`#!/bin/sh` 前提の本 suite で合成方式は採れない |
| **exp6** | standalone（harness trap 無し）で `trap f EXIT; exit 3` | `fin` 発火、rc=3 保持 | standalone 単体では trap は正しく動く |
| **exp7** | `trap A EXIT; trap B EXIT; trap - EXIT` | **何も発火しない** | 1 箇所の `trap -` が全チェーンを破壊 |

---

## 3. 最重要: repository 内パスを cleanup 対象にする処理

**「repo 内パスを削除しうる処理」は存在する。以下が全件（実測）。**

### 3-A. 実 tracked ディレクトリを削除する（最高リスク）

| ファイル:行 | 削除対象 | 実体 | 保護機構 | リスク |
|---|---|---|---|---|
| **`ta-54-ai-loop-link-selfcontained.sh:129`** | `$PG_T54_PLUGIN` = **`$REPO_ROOT/plugin/plangate`** | **git tracked のプロダクト成果物ディレクトリ全体** | backup 存在＋非空チェック（L127）のみ。**trap 無し** | `rm -rf` 直後〜`cp -r` 復元完了（L130）の間に SIGINT / SIGTERM / 異常終了が入ると **`plugin/plangate` が working tree から消えたまま残る**。コード内コメント自身が「ツリー汚染の可能性・要手動復旧」と認めている |

> **これは案 C / 案 D いずれとも独立に存在する既存リスク**であり、TASK-0921 の scope 外だが
> **本監査の最優先報告事項**として記録する。`ta-54` は `register_cleanup` を standalone fallback 無しで
> 無条件呼び出し（L39）し、`FIXTURES_DIR` にも無条件依存（L11）するため **harness-only** と判定できる。

### 3-B. 実 `docs/working/` 配下の fixture TASK を削除する（中リスク）

いずれも `TASK-9990` / `TASK-9991` / `TASK-T45` 等の**テスト専用 TASK 名**に限定されており、
`docs/working` 自体や実 TASK を消す経路は見つからなかった。

| ファイル:行 | 削除対象（展開後） | trap 経由か |
|---|---|---|
| `ta-07-eval-runner.sh:12` | `$REPO_ROOT/docs/working/TASK-9990` | **Yes**（L13 top-level trap の本体） |
| `ta-08-codex-log-parser.sh:38,52` | `$REPO_ROOT/docs/working/TASK-<log fixture>` | No（明示実行） |
| `ta-09-metrics.sh:17,18` | `$REPO_ROOT/docs/working/TASK-9991` / `$REPO_ROOT/.tmp-metrics-events.ndjson` | **Yes**（L23 top-level trap の本体） |
| `ta-34-cli-min-coverage.sh:11,64` | `$REPO_ROOT/docs/working/<t34 task>` | No |
| `ta-37-cli-coverage-batch2.sh:11,76` | `$REPO_ROOT/docs/working/<t37 task>` | No |
| `ta-42-cli-subcommands.sh:27,92` | `$REPO_ROOT/docs/working/<t42 task>` / `.../TASK-T999` | No（`register_cleanup` 併用） |
| `ta-44-eh457-cli-wiring.sh:105` | `$REPO_ROOT/docs/working/TASK-T4400-ta44-tmp`, `TASK-T4401-ta44-tmp` | No（`register_cleanup` 併用） |
| **`ta-45-c3-mode-config.sh:74`** | `$_T45_WD/$_T45_TASK` = `$REPO_ROOT/docs/working/TASK-T45` | **Yes**（L76 top-level trap の本体） |
| `tests/run-tests.sh:151` | `$REPO_ROOT/docs/working/TASK-GATETEST`（`created_gate_test=1` 時のみ） | No |

### 3-C. 実 tracked ファイルを一時改変・復元する

| ファイル:行 | 対象 | 保護機構 |
|---|---|---|
| `ta-09-metrics.sh:19-21` | `$REPO_ROOT/docs/working/_audit/hook-events.log`（backup から `mv` 復元） | top-level trap（L23）+ `METRICS_CLEANUP_DONE` ガード |
| `ta-09-metrics.sh:424-455` | `$REPO_ROOT/docs/working/TASK-0059/eval-result.{json,md}` | mktemp backup + 明示復元（trap 非依存） |
| `ta-28-plugin-version.sh:80-98` | `$REPO_ROOT/.claude-plugin/marketplace.json` | **サブシェル内 EXIT trap**（L87）— 安全側の正しい例 |
| `ta-54:45` | `sh "$PG_T54_SCRIPT"` が実 `plugin/plangate` へ書き込み | mktemp backup（L41-42）+ L127-136 の復元 |

### 3-D. 変数未設定時の暴発余地

`ta-45:74` の `rm -rf "$_T45_WD/$_T45_TASK"` は両変数が空だと `rm -rf "/"` に相当する形になる。
harness 経由では `run-tests.sh` L11 の `set -eu` が守るが、**extras 自身は 1 件も `set -eu` を宣言していない**
（実測: top-level `set -eu` は 0 件。`ta-18` のみサブシェル内で `set -eu`）。
standalone 実行では `-u` の保護が無い。現状は同ファイル内で L57-58 に literal 代入があるため実害は無いが、
**案 C / 案 D いずれでも helper がこの前提に依存してはならない**。

---

## 4. 全 58 ファイル cleanup インベントリ（機械生成）

凡例: `trap` = trap 文の有無（行番号） / `cleanup fn` = cleanup 関数定義 / `reg` = `register_cleanup` 出現数 /
`rm` = `rm -rf`/`rm -f` 出現数 / `repo path rm` = repo 内パスを消す `rm` の有無 / `EE` = early exit 経路数（§5 定義）

| ファイル | trap | cleanup fn | reg | rm | repo path rm | EE |
|---|---|---|---|---|---|---|
| ta-04-check-pr-issue-link.sh | - | - | 0 | 0 | - | 0 |
| ta-05-validate-schemas.sh | - | - | 0 | 1 | - | 0 |
| ta-06-hooks.sh | - | - | 0 | 0 | - | 0 |
| **ta-07-eval-runner.sh** | **13 (top), 49 (`trap -`)** | `cleanup_eval` L12 | 0 | 1 | **Yes** (L12) | 0 |
| ta-08-codex-log-parser.sh | - | - | 0 | 2 | **Yes** (L38,52) | 0 |
| **ta-09-metrics.sh** | **23 (top)** | `cleanup_metrics` L14 | 0 | 5 | **Yes** (L17,18) | 0 |
| ta-10-doctor-fix.sh | - | - | 0 | 12 | - | 0 |
| ta-11-plan-hash-contract.sh | - | - | 0 | 0 | - | 0 |
| ta-12-maintenance.sh | - | - | 0 | 4 | - | 0 |
| ta-13-plangate-setup.sh | - | - | 0 | 0 | - | 0 |
| ta-14-codex-guarded.sh | - | - | 0 | 0 | - | 0 |
| ta-14-skip-acknowledge.sh | - | - | 0 | 1 | - | 0 |
| ta-15-codex-hook-bridge.sh | - | - | 0 | 0 | - | 0 |
| ta-16-pollution-guard.sh | - | - | 0 | 0 | - | 0 |
| ta-17-pre-push-guard.sh | - | - | 0 | 1 | - | 0 |
| ta-18-tag-main-parity.sh | - | - | 0 | 2 | - (mktemp) | 0 |
| ta-19-plan-metrics-verification.sh | - | - | 0 | 0 | - | 0 |
| ta-20-codex-review.sh | - | - | 0 | 0 | - | 0 |
| ta-21-codex-mvp-split.sh | - | - | 0 | 0 | - | 0 |
| ta-22-git-add-scope.sh | - | - | 3 | 0 | - | 0 |
| ta-23-gh-account-pin.sh | - | - | 0 | 0 | - | 0 |
| **ta-24-parallel-review.sh** | **252 (top), 280 (`trap -`)** | - (inline) | 0 | 5 | - (mktemp) | 0 |
| ta-25-approval-token-guard.sh | - | - | 0 | 0 | - | 0 |
| ta-26-plugin-sync.sh | - | `register_cleanup` fallback L28 | 27 | 22 | - (mktemp sandbox) | 1 |
| ta-27-codex-commands.sh | - | - | 0 | 1 | - | 1 |
| **ta-28-plugin-version.sh** | **87, 114（両方 `$( )` 内 = subprocess-only）** | - (inline) | 0 | 2 | tracked file 一時改変（trap で復元） | 1 |
| ta-29-committed-pollution.sh | - | - | 0 | 2 | - | 0 |
| ta-30-install-skills.sh | - | - | 0 | 1 | - | 0 |
| ta-31-codex-plugin-status.sh | - | - | 0 | 4 | - | 4 |
| ta-32-real-ssot-pollution.sh | - | - | 0 | 1 | - | 0 |
| ta-33-agent-model-tier.sh | - | - | 0 | 0 | - | 0 |
| ta-34-cli-min-coverage.sh | - | - | 0 | 2 | **Yes** (L11,64) | 0 |
| ta-35-yaml-schema.sh | - | - | 0 | 1 | - | 0 |
| ta-36-fixloop-event.sh | - | - | 0 | 0 | - | 0 |
| ta-37-cli-coverage-batch2.sh | - | - | 0 | 2 | **Yes** (L11,76) | 0 |
| ta-38-agent-tools.sh | - | - | 0 | 0 | - | 0 |
| ta-39-eh3-doc-light.sh | - | - | 2 | 2 | - | 1 |
| ta-40-task-0129-review-gate.sh | - | - | 0 | 0 | - | 0 |
| ta-41-approve-hardening.sh | - | - | 4 | 0 | (docs/working 配下を reg 登録) | 0 |
| ta-42-cli-subcommands.sh | - | - | 3 | 2 | **Yes** (L27,92) | 0 |
| ta-43-eh2-strict-json.sh | - | - | 2 | 2 | - | 1 |
| ta-44-eh457-cli-wiring.sh | - | - | 6 | 1 | **Yes** (L105) | 1 |
| **ta-45-c3-mode-config.sh** | **76 (top), 224 (`trap -`)** | `cleanup_t45` L72 | 0 | 2 | **Yes** (L74) | 1 |
| ta-46-ehs-wiring.sh | - | - | 0 | 0 | - | 1 |
| ta-47-ehs23-wiring.sh | - | - | 0 | 0 | - | 1 |
| ta-49-bias-export.sh | - | - | 0 | 1 | - | 1 |
| ta-50-precompact-guard.sh | - | - | 2 | 2 | - | 0 |
| ta-51-doctor-w6.sh | - | - | 2 | 4 | - (tmp 内 docs/working) | 0 |
| ta-52-doctor-skill-collision.sh | - | - | 2 | 2 | - | 0 |
| ta-53-doctor-prepush.sh | - | - | 2 | 3 | - | 0 |
| **ta-54-ai-loop-link-selfcontained.sh** | - | - | 1 | 2 | **Yes / 最高リスク** (L129 = `plugin/plangate`) | 0 |
| ta-55-c3prime-accept.sh | - | - | 1 | 0 | - | 0 |
| ta-56-delivery.sh | - | - | 1 | 0 | - | 0 |
| ta-57-pr-convergence.sh | - | - | 3 | 2 | - | 0 |
| ta-58-git-destructive-guard.sh | - | `register_cleanup` fallback L53 | 7 | 3 | - | 1 |
| ta-59-apply-settings-merge.sh | - | `register_cleanup` fallback L31 | 3 | 4 | - | 1 |
| ta-60-run-evidence.sh | - | `register_cleanup` fallback L33 | 4 | 2 | - | 1 |
| **tests/run-tests.sh** | **0（trap 一切なし・実測）** | `register_cleanup` L35 / `_pg_drain_cleanup` L42 | 4 | 3 | **Yes** (L151 `TASK-GATETEST`) | 0 |

> ※ `ta-48` は欠番。`ta-14` は `-codex-guarded` と `-skip-acknowledge` の 2 ファイルが同番号で存在。
> 57 件という総数は実測値であり、両者を別ファイルとして数えている。

---

## 5. early exit 経路の総数（案 D コスト見積もり用）

**定義**: シェルとして実際に制御を抜ける文（コメント・`printf` 文字列・python heredoc 内の `return` は除外）。

### 5-A. standalone-safe early-exit イディオム `return 0 2>/dev/null || …` — **11 箇所 / 8 ファイル**

| ファイル | 行 |
|---|---|
| ta-31-codex-plugin-status.sh | 43, 56, 72, 73（**4 箇所**） |
| ta-39-eh3-doc-light.sh | 59（`|| exit 0`）、61（`exit 0`） |
| ta-43-eh2-strict-json.sh | 56 |
| ta-44-eh457-cli-wiring.sh | 49 |
| ta-45-c3-mode-config.sh | 52 |
| ta-46-ehs-wiring.sh | 23 |
| ta-47-ehs23-wiring.sh | 23 |
| ta-49-bias-export.sh | 72 |

### 5-B. `|| exit N` / 終端 `exit N` — **9 箇所**

| ファイル:行 | 文 | 位置 |
|---|---|---|
| ta-26-plugin-sync.sh:744 | `exit 1` | standalone サマリ末尾 |
| ta-27-codex-commands.sh:37 | `cd "$_t27_tmp" \|\| exit 1` | 本文中（**cleanup 未実行のまま脱出**） |
| ta-28-plugin-version.sh:113 | `_sh=$(mktemp -d) \|\| exit 9` | `$( )` サブシェル内 |
| ta-39-eh3-doc-light.sh:59,61 | `exit 0` | 5-A と重複計上 |
| ta-43-eh2-strict-json.sh:56 / ta-44:49 | `\|\| exit 0` | 5-A と重複計上 |
| ta-58-git-destructive-guard.sh:382 | `[ "$fail" -eq 0 ] \|\| exit 1` | standalone サマリ末尾 |
| ta-59-apply-settings-merge.sh:507 | 同上 | standalone サマリ末尾 |
| ta-60-run-evidence.sh:184 | `[ "$fail" = "0" ] \|\| exit 1` | standalone サマリ末尾 |
| tests/run-tests.sh:180 | `exit 1` | harness 末尾 |

### 5-C. その他 top-level `return`

| ファイル:行 | 文 |
|---|---|
| ta-04-check-pr-issue-link.sh:20 | `return`（`if` 内 early return） |
| ta-57-pr-convergence.sh:54 | `return 0`（関数内） |
| ta-58-git-destructive-guard.sh:132 | `return 0`（関数内） |
| ta-09-metrics.sh:16 | `return 0`（`cleanup_metrics` 内の冪等ガード） |
| tests/run-tests.sh:43 | `return 0`（`_pg_drain_cleanup` 内ガード） |

### 5-D. 合計（案 D の証明対象）

| 分類 | 件数 |
|---|---|
| **finalizer 到達性の証明が必要な top-level early exit（5-A + 5-B のうち関数外・サブシェル外）** | **17** |
| うち standalone-safe イディオム（`return 0 2>/dev/null`） | 11 |
| うち `exit N`（standalone サマリ末尾 4 + `run-tests.sh` 末尾 1 + 本文中 1 = 6、`$( )` 内 1 を除外） | 6 |
| 参考: 関数内 `return` / サブシェル内 `exit`（finalizer 到達性の対象外） | 6 |
| **early exit 経路 総数（5-A ∪ 5-B ∪ 5-C の実文、重複排除）** | **23** |

**案 D コスト示唆**: 静的検査で守るべき top-level 経路は **17**。うち **11** は既に統一イディオム
（`return 0 2>/dev/null || …`）に収束しており、正規表現 1 本で機械検出可能。
`ta-27:37` の `cd … || exit 1` だけが finalizer を持たない裸の脱出であり、mutation test の
kill 対象として最も価値が高い。実装コストは「全 57 ファイルに finalizer 呼び出しを配線」ではなく
「**17 経路に対する静的検査 + 8 ファイルの標準イディオム化**」で足りる。

---

## 6. 案 C 採用可否判定（実測ベース）

> **前提の切り分け**（Phase 1 の capability 分類を待たずに述べる）
> - **最悪ケース**: 全 57 件が standalone-capable と分類された場合
> - **現実ケース**: 明らかに harness-only と読めるものを除いた場合。`FIXTURES_DIR` に無条件依存
>   または `register_cleanup` を standalone fallback 無しで呼ぶファイル（例: `ta-07`, `ta-09`,
>   `ta-24`, `ta-54`, `ta-22`, `ta-41`, `ta-42`）は harness-only 相当

| # | 条件 | 最悪ケース | 現実ケース | 根拠 |
|---|---|---|---|---|
| 1 | standalone-capable 対象に競合する top-level exit trap が無い | **❌** | **⚠️ 条件付き ❌** | 最悪: `ta-07` / `ta-09` / `ta-24` / `ta-45` の **4 件が top-level EXIT trap を保持**、うち 3 件が `trap - EXIT` で解除。現実: `ta-07`/`ta-09`/`ta-24` を harness-only に落としても **`ta-45` が残る**。`ta-45` は L14-22 に standalone 分岐（`PG_HARNESS_SOURCED` 判定 + 自前 unset + 自前 `_T45_ROOT` 解決）を持ち、**明白に standalone-capable として設計されている**にもかかわらず L76 で top-level `trap cleanup_t45 EXIT`、L224 で `trap - EXIT` を実行する。**競合は 1 件でも残れば案 C の前提は崩れる** |
| 2 | （競合がある場合）既存 trap との安全な合成方法を証明できる | **❌** | **❌** | exp4: POSIX `trap` に合成機能は無い（後勝ちの完全上書き）。exp5b: `trap -p` を使えば合成できるが、exp5c で **`dash` は `trap: Illegal option -p` で失敗、`zsh` は `command not found: -p`**。本 suite は `#!/bin/sh`（`tests/run-tests.sh` L1）かつ CI は `run: sh tests/run-tests.sh`（`.github/workflows/test.yml:28`）で shell 実体を固定していない。**POSIX sh 上で安全な合成は証明不能**。さらに exp7 のとおり **他ファイルの `trap - EXIT` 1 行で合成チェーン全体が破壊される**ため、合成が成功しても保持が保証されない |
| 3 | harness source 時には trap を設定しない設計が可能 | **✅** | **✅** | `PG_HARNESS_SOURCED` + `FIXTURES_DIR` の AND 判定が既に規約化されている（`tests/extras/README.md` 規約 8）。`run-tests.sh` L20 で外部漏れを unset、L166 で `export` せず設定するため判定は健全。この条件**だけ**は満たせる |
| 4 | helper が既存 runner の trap や cleanup を変更しない | **✅（trap）/ ⚠️（cleanup）** | 同左 | `tests/run-tests.sh` の trap 数は **実測 0**。よって「runner の trap を壊す」ことは構造上起こらない。ただし runner の cleanup は `register_cleanup` + `_pg_drain_cleanup`（L35-49, L174）という **trap 非依存の drain 方式**であり、helper が signal 0 trap を導入すると **cleanup 機構が 2 系統に分裂**する。さらに `ta-45` の `trap - EXIT`（L224）は helper が張った trap も消すため、**helper 自身が既存ファイルの trap 解除の被害者になる**（exp1 で実証） |
| 5 | repository 内の未検証 path を削除しない | **❌** | **❌** | §3 のとおり **repo 内パス削除は実在する**。特に `ta-54:129` は `$REPO_ROOT/plugin/plangate`（tracked ディレクトリ全体）を `rm -rf` する。加えて trap 本体そのものが repo path を消す例が **3 件**: `ta-07:12`（`docs/working/TASK-9990`）、`ta-09:17-18`（`docs/working/TASK-9991` + `.tmp-metrics-events.ndjson`）、`ta-45:74`（`docs/working/TASK-T45`）。案 C が「standalone 時に trap を張って cleanup を走らせる」設計である以上、**signal 経由で repo 内パス削除が発火する経路を新設することになる**。`ta-45:74` は `set -u` 非適用の standalone で両変数が空なら `rm -rf "/"` 形になる構造も残る |

### 判定サマリ

| 条件 | 最悪ケース | 現実ケース |
|---|---|---|
| 1 競合 trap 不在 | ❌ | ❌ |
| 2 安全な合成の証明 | ❌ | ❌ |
| 3 harness 時 trap 非設定 | ✅ | ✅ |
| 4 既存 runner 非変更 | ✅ / ⚠️ | ✅ / ⚠️ |
| 5 repo 内 path 非削除 | ❌ | ❌ |

**5 条件中 3 条件が ❌**。しかも ❌ の 3 つはいずれも **最悪ケースと現実ケースの両方で ❌**（分類結果に依存しない）。

---

## 7. 結論

# **案 D へ Replan 推奨**

### 満たせない条件と理由

| 条件 | なぜ満たせないか |
|---|---|
| **条件 1（競合 trap 不在）** | `ta-45` が standalone-capable として明示設計されているのに top-level `trap … EXIT` と `trap - EXIT` を持つ。分類をどう寄せてもこの 1 件は残る。`ta-07` / `ta-09` / `ta-24` を harness-only に倒す判断も、trap を持つという理由で分類を決めるのは**循環論法**であり Phase 1 の分類根拠にできない |
| **条件 2（安全な合成）** | POSIX `trap` に合成機能が無く（exp4）、合成に必須の `trap -p` が `dash` / `zsh` で使えない（exp5c）。`#!/bin/sh` + CI の `sh` 実体非固定という本 suite の前提下では **合成の安全性を証明できない**。加えて他ファイルの `trap - EXIT` 1 行で合成チェーンが消える（exp1 / exp7）ため、仮に合成できても**保持が保証されない** |
| **条件 5（repo 内 path 非削除）** | trap 本体が repo 内パスを消す既存実装が 3 件（`ta-07` / `ta-09` / `ta-45`）。案 C は signal 経路からこれらを発火させる設計になり、**リポジトリ破壊の新経路を追加**する。`ta-54:129` の `plugin/plangate` 削除は trap 非経由だが、案 C の思想（trap で安全網を張る）を適用すると同じ問題圏に入る |

### さらに決定的な構造的理由

**案 C は本リポジトリの既存規約と正面から矛盾する。**
`tests/extras/README.md` L81-83 は「**trap は使わない**」を明文規約として掲げ、
L127-146（#530-3）は「source 型の構造上 trap EXIT は後続 extras に上書きされ、発火が保証されない」
「親シェルの trap を `trap - EXIT` で消さない」と、案 C が依存しようとしている前提の否定を
**すでに実害経験（s3 retrospective）に基づいて記録している**。
`tests/run-tests.sh` L30-49 の `register_cleanup` / `_pg_drain_cleanup` は、まさに
**trap 非依存**の代替として導入された機構であり、現在 **21 ファイルが採用**している。
案 C は「捨てた設計に戻る」提案であり、C-1 が `NEEDS_REVISION_BEFORE_C3` としたのは妥当。

### 案 D の実装コスト（実測ベースの見積もり）

| 項目 | 実測値 |
|---|---|
| finalizer 到達性の証明が必要な top-level early exit 経路 | **17** |
| うち既に統一イディオム化済み（正規表現 1 本で静的検査可能） | **11 / 17** |
| 追加の標準イディオム化が必要なファイル | **1**（`ta-27:37` の `cd … \|\| exit 1`） |
| standalone サマリ末尾の `exit N`（finalizer を末尾に置けば自然に到達） | **5** |
| mutation test の kill 対象として最も価値が高い変異点 | `ta-27:37`（finalizer を持たない裸の脱出）、および各 standalone サマリ直前への finalizer 挿入漏れ |
| early exit 経路 総数（参考・関数内 return 等を含む） | **23** |

案 D は「全 57 ファイルへの配線」ではなく「**17 経路の静的検査 + 既存 `register_cleanup` 機構への接続**」で成立する。
既存の `register_cleanup` / `_pg_drain_cleanup`（`tests/run-tests.sh` L35-49）と
standalone fallback パターン（`ta-58` L53 / `ta-59` L31 / `ta-60` L33 に既存実装あり）を
**共通 helper として抽出するだけ**で、trap を 1 つも新設せずに案 C の目的を達成できる。

---

## 8. TASK-0921 scope 外だが要起票（最優先報告）

| ID | 内容 | 重大度 |
|---|---|---|
| **X-1** | `tests/extras/ta-54-ai-loop-link-selfcontained.sh:129` が `$REPO_ROOT/plugin/plangate`（git tracked ディレクトリ全体）を `rm -rf` し、trap 無しで `cp -r` 復元する。`rm` と `cp` の間で中断すると working tree から `plugin/plangate` が消えたまま残る。コード内コメント自身が「ツリー汚染の可能性・要手動復旧」と認めている | **critical** |
| X-2 | `tests/extras/ta-45-c3-mode-config.sh:74` の `rm -rf "$_T45_WD/$_T45_TASK"` は `set -u` 非適用の standalone 実行で変数が空なら `rm -rf "/"` 形になる。extras は top-level `set -eu` を 1 件も宣言していない（実測） | major |
| X-3 | `tests/extras/README.md` L81「trap は使わない」規約に対し、`ta-07` / `ta-09` / `ta-24` / `ta-45` の 4 ファイルが未追従。CI に規約違反検出（`grep -nE "^[[:space:]]*trap[[:space:]]"` が subshell 外で 0 件）が無い | major |
