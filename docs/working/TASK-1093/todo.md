# EXECUTION TODO — TASK-1093 (#1093)

> mode=**critical**（v2 で high-risk から引き上げ）。L-0 / V-1〜V-4 / PR 作成は
> workflow-conductor が制御するため本表に含めない。
> **AI は apply script の `--apply` を実行しない**（sandbox 内でも / 全タスク共通の Iron Law）。
>
> **v2（C-2 REJECT 反映 / `Refs: R-001 R-002 R-003 R-004 R-005 R-006 R-007 R-008 R-009 R-010 R-011 R-012`）**

## 🤖 Agent タスク

### 準備

| ID | タスク | Owner | depends_on | rollback | 🚩 |
|----|-------|-------|-----------|----------|----|
| T-01 | 34 本全数の `--dry-run` 実測（**完了済**: `evidence/apply-dryrun-matrix.txt`） | agent | — | 不要（読取のみ） | `ls scripts/apply-*.sh` の集合と matrix の集合が `comm -3` で空（**件数で照合しない** / R-012） |
| T-02 | 各 script の**冪等判定の所在**を実測して記録（**書き写さない**。どこに何行目相当の判定があるかではなく「判定を持つ / 持たない」を記録） | agent | T-01 | 不要（読取のみ） | 判定を持たない script を名指しで列挙（例: `apply-task-0134-progress.sh` は引数解析すら無い） |
| T-03 | 各 script の**書き込み対象パス**（`targets`）と tracked/untracked を実測 | agent | T-01 | 不要（読取のみ） | untracked のみを対象とする script が `scope=local` 候補（現時点 3 本想定） |

### 実装

| ID | タスク | Owner | depends_on | rollback | 🚩 |
|----|-------|-------|-----------|----------|----|
| T-04 | `scripts/apply-registry.tsv` 作成（列 = `script` / `scope` / `targets` / `defer`） | agent | T-03 | `git rm scripts/apply-registry.tsv` | **`probe_expr` 相当の列が存在しない**こと（v1 方式への逆戻り検出）。`scope=local` の `targets` に tracked が 1 つも無いこと |
| T-05 | `docs/ai/ho-change-workflow.md` に rc 契約（0=applied / 10=pending / その他=undecidable）を正本化し、**既存の「標準フロー」2 の契約記述を同時に整理** | agent | — | `git checkout origin/main -- docs/ai/ho-change-workflow.md` | 「アンカー不在→exit 1」等の既存記述と**矛盾が残っていない**（**R-009**） |
| T-06 | `scope=release` の apply script を rc 契約に適合させる（**実質ロジックは変えない**） | agent | T-04, T-05 | `git checkout origin/main -- scripts/apply-<name>.sh` | **1 本ずつ** `git diff` を確認し、`--apply` 経路の挙動が変わっていないこと（変わったら **SC-5 で即停止**） |
| T-07 | `check_pending_applies()` を rc ベース + 実行ガード（timeout / rc 捕捉 / `scope=local` は実行しない）へ差し替え | agent | T-06 | `git checkout origin/main -- scripts/release-prep.sh` | 旧実装の `[dry-run]` 文字列一致が grep で **0 件**。stdout を判定に使っていないこと |
| T-08 | 台帳カバレッジ照合を判定側に組込（`comm -3` の集合同値） | agent | T-07 | 同上 | 台帳に無い script を 1 本足すと `undecidable`→NOT READY |
| T-09 | `defer` の 4 層防御を実装（Human 発行のみ / `decision-log.jsonl` 1:1 / 参照 issue が **OPEN** / `git diff` 1 行可視） | agent | T-07 | 同上 | **`undecidable` に `defer` が効かない**こと（判定不能を defer で消させない / **R-001**） |
| T-10 | `n/a (local)` 行に `bin/plangate doctor --check-settings` への導線を表示 | agent | T-07 | 同上 | 通常 checkout で settings 配線シグナルが**完全には消えない**（**R-008**） |
| T-11 | `check_plugin_cache_sync()` を `run_checks()` から除去 | agent | T-07 | 同上 | `--check` 出力に「plugin キャッシュ」行が 0 件 |
| T-12 | **`run_checks \|\| true`（`vX.Y.Z` 経路）の rc 握り潰しを解消** | agent | T-11 | 同上 | `sh scripts/release-prep.sh vX.Y.Z` が NOT READY 時に **rc≠0**（**R-006**） |
| T-13 | `docs/release-process.md` にリリース**後**手順として `sync-plugin-installed.sh` を記載 | agent | T-11 | `git checkout origin/main -- docs/release-process.md` | 移設先から到達でき、`run_checks()` 側の参照が 0 件（**R-007**） |

### 検証

| ID | タスク | Owner | depends_on | rollback | 🚩 |
|----|-------|-------|-----------|----------|----|
| T-14 | `tests/extras/ta-67-release-prep-pending.sh` 作成（**`ta-65` に触れない**） | agent | T-08, T-09 | `git rm tests/extras/ta-67-release-prep-pending.sh` | **ta-61 契約 full 準拠**: 先頭 20 行に `# PG_EXTRA_CAPABILITY:` **ちょうど 1 個** / `pg_extra_contract_init ta-67-release-prep-pending <capability>`（basename 一致・marker 一致）/ 末尾 `pg_extra_contract_finalize` / rc 層 0/1/2/3 / standalone・harness 両対応 / 7 env unset / `register_cleanup` 使用（**R-005**） |
| T-15 | sandbox ヘルパを**最小サブツリー**（`scripts/` + `tests/` + `bin/` + `.claude/`。`docs/` 除外）で実装し 1 回複製を使い回す | agent | T-14 | 不要（sandbox 内） | 複製サイズを実測して記録。`timeout-minutes: 10` に収まること（**R-010**） |
| T-16 | **MUT-6（判定品質の kill）**: `targets` の実装本体を壊し marker/コメントは残す変異で、当該 script の `--dry-run` が **rc=10 に反転**することを要求 | agent | T-14 | 不要（sandbox 内） | 対象は **`scope=release` かつ `targets` が単一 tracked ファイルの全行**（集合で定義・件数を契約にしない）。**反転しない script は緑にせず名指し報告**（**SC-6 / R-002**） |
| T-17 | MUT-1〜5（検出器側の call site を壊す変異）で kill を実証 | agent | T-14 | 不要（sandbox 内） | 空振り fixture でないこと |
| T-18 | AC-5 環境同値: `.claude/settings.json` 有 / 無 の 2 sandbox で判定出力を `diff` して同一 | agent | T-14 | 不要（sandbox 内） | worktree 実機 + 通常 checkout 実機でも各 1 回実走して証跡化 |
| T-19 | `sh tests/run-tests.sh` rc=0（AC-7）。件数は**記録のみ** | agent | T-14 | 不要（読取のみ） | rc を verbatim で証跡に残す（**base 実測 = 本ブランチ head で rc=0**） |
| T-20 | `git diff --stat` で **HO パス 0 件 / `ta-65-*` 0 件** を確認（SC-3） | agent | T-19 | 不要 | 1 件でもあれば**即停止** |

### 完了

| ID | タスク | Owner | depends_on | rollback | 🚩 |
|----|-------|-------|-----------|----------|----|
| T-21 | follow-up issue 起票: (i) `defer` の hook 層保護（HO 変更が必要・**本 PBI では塞げない**）/ (ii) MUT-6 で顕在化した判定が弱い script / (iii) Out of scope の実質ロジック是正（逆方向差分・引数解析欠落）/ (iv) `--check` の CI 配線（HO・Human） | agent | T-20 | issue close | **塞げないことを黙らない**（**R-004 / R-005 / U-5**） |
| T-22 | `handoff.md` 発行（必須 6 要素） | agent | T-21 | — | 既知課題に「判定が弱い script」「`defer` の hook 未保護」「`--check` CI 未配線」を列挙 |

## 👤 Human タスク

| ID | タスク | Owner | タイミング | 依存 |
|----|-------|-------|-----------|------|
| **H-1** | **C-3 ゲート（人間必須 / mode=critical）**: **U-1**（初期 `defer`。**`apply-ai-loop-workflow-command.sh` を名指しで**）/ **U-4**（スコープ分割 A or B）/ **U-5**（CI 配線）を判断 | human | exec 前 | C-1（`review-self-2.md`）+ C-2（`review-external.md`）を読んで判断 |
| **H-2** | `defer` の**発行**（AI は行わない）。`decision-log.jsonl` への記録を伴う | human | H-1 の判断に従い | H-1 |
| **H-3** | **C-4 ゲート**: PR レビュー・**merge**（AI は行わない） | human | PR 作成後 | T-22 |
| **H-4** | 新判定で `pending` と出た apply script の **`--apply` 実行**（必要な場合） | human | 任意（本 PBI の完了条件ではない） | — |
| **H-5** | `--check` の CI 配線（`.github/workflows/*` = **HO**。AI は不可） | human | 任意（U-5 の判断次第） | H-1 |

## ⚠️ 依存関係

- **H-1（C-3）→ T-04 以降**: `defer` 初期値とスコープ分割の判断が実装方針を決める。承認前に進まない
- **T-02/T-03 → T-04**: 台帳は実測のみで書く（推測禁止）
- **T-05 → T-06**: 契約を正本化してから script を適合させる（順序を逆にすると contract drift）
- **T-06 → T-07**: script が契約適合してから検出器を rc ベースにする（逆だと全件 `undecidable`）
- **T-14 → T-16/T-17**: テストを書いた直後に変異注入。書きっぱなしにしない
- **T-20 → T-21**: スコープ逸脱ゼロを確認してから起票

## Iron Law（本 PBI での適用）

- **NO MERGE BY AI** — merge は H-3（Human-owned）
- **apply script の `--apply` を AI が実行しない** — **sandbox 内であっても実行しない**
- **HO パスを AI が編集しない** — `bin/plangate` / `scripts/hooks/*.sh` / `.claude/**` / `.github/workflows/*`
  （**`--check` の CI 配線が AI にできない**のはこの帰結。U-5 / H-5）
- **`defer` を AI 判断で増やさない** — SC-2
- **判定が弱い script を緑にしない** — SC-6
