# EXECUTION TODO — TASK-1093 (#1093)

> mode=**high-risk**（**v3 で critical から戻した** / C-3 2026-08-18 の案 B）。
> L-0 / V-1〜V-3 / PR 作成は workflow-conductor が制御するため本表に含めない。
> **AI は apply script の `--apply` を実行しない**（sandbox 内でも / 全タスク共通の Iron Law）。
> **AI は `scripts/apply-*.sh` を編集しない**（契約適合の移行は **#1114**）。
>
> **v2（C-2 REJECT 反映 / `Refs: R-001 R-002 R-003 R-004 R-005 R-006 R-007 R-008 R-009 R-010 R-011 R-012`）**
>
> **v3（C-3 裁定 2026-08-18 反映 / 案 B: 2 分割）** — **旧 T-06（apply script の契約適合）を
> [#1114](https://github.com/s977043/PlanGate/issues/1114) へ移設**し、以降を再採番。
> 旧 T-16（実 script に対する MUT-6）も **#1114 へ移設**し、本 PBI は **fixture に対する MUT-6'** を持つ。

## 🤖 Agent タスク

### 準備

| ID | タスク | Owner | depends_on | rollback | 🚩 |
|----|-------|-------|-----------|----------|----|
| T-01 | apply script 全数の `--dry-run` 実測（**完了済**: `evidence/apply-dryrun-matrix.txt`） | agent | — | 不要（読取のみ） | `ls scripts/apply-*.sh` の集合と matrix の集合が `comm -3` で空（**件数で照合しない** / R-012） |
| T-02 | 各 script の**冪等判定の所在**を実測して記録（**書き写さない**。「判定を持つ / 持たない」を記録）。**是正はしない（#1114）** | agent | T-01 | 不要（読取のみ） | 判定を持たない script を名指しで列挙（例: `apply-task-0134-progress.sh` は引数解析すら無い）。**`contract` 列の初期値の根拠になる** |
| T-03 | 各 script の**書き込み対象パス**（`targets`）と tracked/untracked を実測 | agent | T-01 | 不要（読取のみ） | untracked のみを対象とする script が `scope=local` 候補（**集合で列挙。件数を契約にしない**） |

### 実装

| ID | タスク | Owner | depends_on | rollback | 🚩 |
|----|-------|-------|-----------|----------|----|
| T-04 | `scripts/apply-registry.tsv` 作成（列 = `script` / `scope` / `targets` / **`contract`** / `defer`） | agent | T-03 | `git rm scripts/apply-registry.tsv` | **`probe_expr` 相当の列が存在しない**こと（v1 方式への逆戻り検出）。`scope=local` の `targets` に tracked が 1 つも無いこと。**`defer` 列は空で作る**（AI は defer を発行しない / SC-2） |
| T-05 | `docs/ai/ho-change-workflow.md` に rc 契約（0=applied / 10=pending / その他=undecidable）を正本化し、**既存の「標準フロー」2 の契約記述を同時に整理** | agent | — | `git checkout origin/main -- docs/ai/ho-change-workflow.md` | 「アンカー不在→exit 1」等の既存記述と**矛盾が残っていない**（**R-009**）。**#1114 が「移行先の契約」として参照できる**こと |
| T-06 | `check_pending_applies()` を rc ベース + 実行ガード（timeout / rc 捕捉 / `scope=local` は実行しない）へ差し替え | agent | T-04, T-05 | `git checkout origin/main -- scripts/release-prep.sh` | 旧実装の `[dry-run]` 文字列一致が grep で **0 件**。stdout を判定に使っていないこと |
| T-07 | 台帳カバレッジ照合を判定側に組込（`comm -3` の集合同値） | agent | T-06 | 同上 | 台帳に無い script を 1 本足すと `undecidable`→NOT READY |
| T-08 | **`contract=legacy`→`unmigrated(#1114)` WARN の実装**（**U-6 採用時のみ**）: 凍結集合 / 一方向 / #1114 OPEN 検査 | agent | T-06 | 同上 | **凍結集合外の `legacy`** と **`adopted→legacy` 差し戻し**が FAIL。**#1114 が CLOSED なら `undecidable`→NG**（**SC-7**） |
| T-09 | `defer` の 4 層防御を実装（Human 発行のみ / `decision-log.jsonl` 1:1 / 参照 issue が **OPEN** / `git diff` 1 行可視） | agent | T-06 | 同上 | **`undecidable` に `defer` が効かない**こと（判定不能を defer で消させない / **R-001 / TC-21**） |
| T-10 | `n/a (local)` 行に `bin/plangate doctor --check-settings` への導線を表示 | agent | T-06 | 同上 | 通常 checkout で settings 配線シグナルが**完全には消えない**（**R-008**） |
| T-11 | `check_plugin_cache_sync()` を `run_checks()` から除去 | agent | T-06 | 同上 | `--check` 出力に「plugin キャッシュ」行が 0 件 |
| T-12 | **`run_checks \|\| true`（`vX.Y.Z` 経路）の rc 握り潰しを解消** | agent | T-11 | 同上 | `sh scripts/release-prep.sh vX.Y.Z` が NOT READY 時に **rc≠0**（**R-006**） |
| T-13 | `docs/release-process.md` にリリース**後**手順として `sync-plugin-installed.sh` を記載 | agent | T-11 | `git checkout origin/main -- docs/release-process.md` | 移設先から到達でき、`run_checks()` 側の参照が 0 件（**R-007**） |

### 検証

| ID | タスク | Owner | depends_on | rollback | 🚩 |
|----|-------|-------|-----------|----------|----|
| T-14 | `tests/extras/ta-67-release-prep-pending.sh` 作成（**`ta-65` に触れない**） | agent | T-08, T-09 | `git rm tests/extras/ta-67-release-prep-pending.sh` | **ta-61 契約 full 準拠**: 先頭 20 行に `# PG_EXTRA_CAPABILITY:` **ちょうど 1 個** / `pg_extra_contract_init ta-67-release-prep-pending <capability>`（basename 一致・marker 一致）/ 末尾 `pg_extra_contract_finalize` / rc 層 0/1/2/3 / standalone・harness 両対応 / 7 env unset / `register_cleanup` 使用（**R-005**） |
| T-15 | sandbox ヘルパを**最小サブツリー**（`scripts/` + `tests/` + `bin/` + `.claude/`。`docs/` 除外）で実装し 1 回複製を使い回す | agent | T-14 | 不要（sandbox 内） | 複製サイズを実測して記録。`timeout-minutes: 10` に収まること（**R-010**） |
| T-16 | **MUT-6'（判定品質の kill / fixture 版）**: sandbox の**契約準拠 fixture apply script** の実装本体を壊し marker/コメントは残す変異で、`--dry-run` が **rc=10 に反転**し検出器が `pending` を出すことを要求 | agent | T-14 | 不要（sandbox 内） | kill されなければ**緑にしない**（**SC-6**）。**実 script 全数に対する MUT-6 は #1114**（`adopted` になって初めて実行可能） |
| T-17 | MUT-1〜5（検出器側の call site を壊す変異）で kill を実証 | agent | T-14 | 不要（sandbox 内） | 空振り fixture でないこと |
| T-18 | AC-5 環境同値: `.claude/settings.json` 有 / 無 の 2 sandbox で判定出力を `diff` して同一 | agent | T-14 | 不要（sandbox 内） | worktree 実機 + 通常 checkout 実機でも各 1 回実走して証跡化 |
| T-19 | `sh tests/run-tests.sh` rc=0（AC-7）。件数は**記録のみ** | agent | T-14 | 不要（読取のみ） | rc を verbatim で証跡に残す（**base 実測 = 本ブランチ head で rc=0**） |
| T-20 | `git diff --stat` で **HO パス 0 件 / `ta-65-*` 0 件 / `scripts/apply-*.sh` 0 件** を確認（SC-3 / **SC-5**） | agent | T-19 | 不要 | 1 件でもあれば**即停止**。`scripts/apply-registry.tsv` は対象外（新規・本 PBI の成果物） |

### 完了

| ID | タスク | Owner | depends_on | rollback | 🚩 |
|----|-------|-------|-----------|----------|----|
| T-21 | follow-up issue 起票: (i) **`ack` / `defer` の hook 層保護**（HO 定義本体の変更が必要・**C-3 で「本 PBI では塞げない」と確定**）/ (ii) `--check` の CI 配線（HO・Human・**U-5 持ち越し**）。**(iii) 実質ロジック是正と契約適合移行は #1114 に集約済＝新規起票しない** | agent | T-20 | issue close | **塞げないことを黙らない**（**R-004 / U-5**）。#1114 と相互リンク |
| T-22 | `handoff.md` 発行（必須 6 要素） | agent | T-21 | — | 既知課題に「`defer` の hook 未保護（follow-up）」「`--check` CI 未配線（U-5）」「**契約非適合 script が `unmigrated` として残る（#1114）**」を列挙 |

## 👤 Human タスク

| ID | タスク | Owner | タイミング | 依存 |
|----|-------|-------|-----------|------|
| **H-1** | **C-3 ゲート（人間必須 / mode=high-risk）**: 残る判断は **U-6**（`contract=legacy`→WARN を採用するか / 不採用なら #1114 完了まで NOT READY を受け入れる）。**U-1 / U-4 は 2026-08-18 に裁定済・U-5 は持ち越し確定** | human | exec 前 | C-1（`review-self-3.md`）+ C-2（`review-external.md`）+ [C-3 裁定](https://github.com/s977043/PlanGate/issues/1093#issuecomment-5320820417) |
| **H-1b** | **`c3.json` の発行**（v3 で **`plan_hash` が変わった**ため、**本更新の後**に発行する） | human | H-1 の後 | H-1 |
| **H-2** | `defer` の**発行**（AI は行わない / SC-2）。`decision-log.jsonl` への記録を伴う。名指し対象 = `apply-ai-loop-workflow-command.sh` | human | **#1114 で当該 script が `adopted` になった後** | #1114 |
| **H-3** | **C-4 ゲート**: PR レビュー・**merge**（AI は行わない） | human | PR 作成後 | T-22 |
| **H-4** | 新判定で `pending` と出た apply script の **`--apply` 実行**（必要な場合） | human | 任意（本 PBI の完了条件ではない） | — |
| **H-5** | `--check` の CI 配線（`.github/workflows/*` = **HO**。AI は不可 / **U-5 持ち越し**） | human | 任意 | — |

## ⚠️ 依存関係

- **H-1/H-1b → T-04 以降**: **U-6 の判断が T-08 の要否を決める**。`c3.json` 発行前に進まない
- **T-02/T-03 → T-04**: 台帳は実測のみで書く（推測禁止）。`contract` 列の初期値も実測由来
- **T-05 → T-06**: 契約を正本化してから検出器を書く（順序を逆にすると contract drift）
- **本 PBI → #1114**: 契約（T-05）と台帳（T-04）が無いと移行先が無い。**#1114 は本 PBI の exec 完了が前提**
- **T-14 → T-16/T-17**: テストを書いた直後に変異注入。書きっぱなしにしない
- **T-20 → T-21**: スコープ逸脱ゼロ（**`scripts/apply-*.sh` 0 件を含む**）を確認してから起票

## Iron Law（本 PBI での適用）

- **NO MERGE BY AI** — merge は H-3（Human-owned）
- **apply script の `--apply` を AI が実行しない** — **sandbox 内であっても実行しない**
- **`scripts/apply-*.sh` を本 PBI で編集しない** — 契約適合の移行は **#1114**（SC-5）
- **HO パスを AI が編集しない** — `bin/plangate` / `scripts/hooks/*.sh` / `.claude/**` / `.github/workflows/*`
  （**`--check` の CI 配線が AI にできない**のはこの帰結。U-5 / H-5。
  **`ack` / `defer` の hook 層保護が本 PBI で塞げない**のも同じ帰結。R-004 / T-21）
- **`defer` を AI 判断で増やさない** — SC-2（C-3 2026-08-18 で維持を確認）
- **`undecidable` に `defer` を効かせない** — TC-21（C-3 2026-08-18 で維持を確認）
- **`legacy` を凍結集合の外へ広げない** — SC-7
- **判定品質の変異が kill されないまま緑にしない** — SC-6
