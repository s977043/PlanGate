# EXECUTION TODO — TASK-1093 (#1093)

> mode=**high-risk**。L-0 / V-1〜V-3 / PR 作成は workflow-conductor が制御するため本表に含めない。
> **AI は apply script の `--apply` を実行しない**（全タスク共通の Iron Law）。

## 🤖 Agent タスク

### 準備

| ID | タスク | Owner | depends_on | rollback | 🚩 |
|----|-------|-------|-----------|----------|----|
| T-01 | 34 本全数の `--dry-run` 実測を固定（**完了済**: `evidence/apply-dryrun-matrix.txt`） | agent | — | 不要（読取のみ） | `ls scripts/apply-*.sh \| wc -l` と行数の**同値照合** |
| T-02 | 現行 `check_pending_applies()` の verdict を matrix から機械導出し `evidence/current-verdict.txt` に固定 | agent | T-01 | 不要（読取のみ） | 誤検出 2 本・検出漏れ 2 本以上が**名指しで**入っていること |
| T-03 | 各 script の「適用済み判定 probe」候補を実測（対象ファイル + 一意な marker） | agent | T-01 | 不要（読取のみ） | **書けない script は SC-1 で報告**。曖昧なまま埋めない |

### 実装

| ID | タスク | Owner | depends_on | rollback | 🚩 |
|----|-------|-------|-----------|----------|----|
| T-04 | `scripts/apply-registry.tsv` を新規作成（34 行 + ヘッダ。列 = script / scope / probe_target / probe_expr / ack） | agent | T-03 | `git rm scripts/apply-registry.tsv` | `scope=local` 行の probe_target が **untracked パスのみ**であること |
| T-05 | `check_pending_applies()` を台帳ベース 4 値判定へ差し替え（`2>/dev/null \|\| true` 撤廃） | agent | T-04 | `git checkout origin/main -- scripts/release-prep.sh` | 旧実装の `[dry-run]` 文字列一致が**残っていない**ことを grep で 0 件確認 |
| T-06 | 台帳カバレッジ照合を判定側に組込（`ls scripts/apply-*.sh` と台帳の**集合同値**。件数の絶対値は使わない） | agent | T-05 | 同上 | 台帳に無い script を 1 本足すと `unknown`→NOT READY になること |
| T-07 | 契約適合 script の `PLANGATE-APPLY-STATUS` と probe の cross-check（不一致→`unknown`） | agent | T-05 | 同上 | 現状 0 本適合＝経路が**死んでいない**ことをテストで担保 |
| T-08 | `check_plugin_cache_sync()` を `run_checks()` から除去 | agent | T-05 | 同上 | `--check` 出力に「plugin キャッシュ」行が出ないこと |
| T-09 | `docs/release-process.md` にリリース**後**手順として `sync-plugin-installed.sh` を記載 | agent | T-08 | `git checkout origin/main -- docs/release-process.md` | 移設先から到達でき、リリース**前**節に残存していないこと |
| T-10 | `docs/ai/ho-change-workflow.md` に `--dry-run` 出力契約を正本化（**既存 34 本へ遡及しない**と明記） | agent | T-05 | `git checkout origin/main -- docs/ai/ho-change-workflow.md` | 「新規 script のみ強制」が読み取れること |

### 検証

| ID | タスク | Owner | depends_on | rollback | 🚩 |
|----|-------|-------|-----------|----------|----|
| T-11 | `tests/extras/ta-67-release-prep-pending.sh` を新規作成（TC-01〜TC-12。**`ta-65` に触れない**） | agent | T-06, T-07 | `git rm tests/extras/ta-67-release-prep-pending.sh` | AC-1〜AC-6 と TC が **1:1** で対応していること |
| T-12 | **変異注入**で検出力を実証（旧実装 / `unknown`→OK 退行 / カバレッジ照合除去 / `n/a` 無条件付与 の 4 変異が **kill** されること） | agent | T-11 | 不要（sandbox 内） | 変異は **call site を壊す**。空振り fixture でないことを確認 |
| T-13 | AC-5 環境同値: `.claude/settings.json` 有 / 無 の 2 sandbox で判定出力を **diff して同一**を確認 | agent | T-11 | 不要（sandbox 内） | worktree 実機でも 1 回実走して証跡化 |
| T-14 | `sh tests/run-tests.sh` を実行し rc=0（AC-7）。件数は**記録のみ**で契約値にしない | agent | T-11 | 不要（読取のみ） | rc を verbatim で証跡に残す |
| T-15 | `git diff --stat` で **HO パス 0 件 / `ta-65-*` 0 件 / `scripts/apply-*.sh` 0 件** を確認（SC-3） | agent | T-14 | 不要 | 1 件でもあれば**即停止** |

### 完了

| ID | タスク | Owner | depends_on | rollback | 🚩 |
|----|-------|-------|-----------|----------|----|
| T-16 | Out of scope 分の別 issue 起票（逆方向差分 / 無条件ヘッダ / 引数解析欠落） | agent | T-15 | issue close | **中身は直さない**。起票のみ |
| T-17 | `handoff.md` 発行（必須 6 要素） | agent | T-16 | — | 既知課題に「新規可視化された pending」を列挙 |

## 👤 Human タスク

| ID | タスク | Owner | タイミング | 依存 |
|----|-------|-------|-----------|------|
| **H-1** | **C-3 ゲート（人間必須）**: mode=high-risk のため autonomous APPROVE 不可。とくに **U-1（初期 ack の是非）/ U-2（契約の遡及可否）** を判断 | human | exec 前 | T-01〜T-03 完了後、C-1 / C-2 を読んで判断 |
| **H-2** | **C-4 ゲート**: PR レビュー・**merge**（AI は行わない） | human | PR 作成後 | T-17 |
| **H-3** | 新判定で `pending` と出た apply script の **`--apply` 実行**（必要な場合） | human | 任意（本 PBI の完了条件ではない） | — |

## ⚠️ 依存関係

- **H-1（C-3）→ T-04 以降**: 台帳の `ack` 初期値は **H-1 の判断結果**を書く。承認前に実装へ進まない
- **T-03 → T-04**: probe を実測せずに台帳を書かない（推測禁止）
- **T-11 → T-12**: テストを書いた直後に変異注入。書きっぱなしにしない
- **T-15 → T-16**: スコープ逸脱ゼロを確認してから起票

## Iron Law（本 PBI での適用）

- **NO MERGE BY AI** — merge は H-2（Human-owned）
- **apply script の `--apply` を AI が実行しない** — sandbox 内であっても実行しない
- **HO パスを AI が編集しない** — `bin/plangate` / `scripts/hooks/*.sh` / `.claude/**` / `.github/workflows/*`
- **`ack` を AI 判断で増やさない** — SC-2
