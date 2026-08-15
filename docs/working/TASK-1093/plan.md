# EXECUTION PLAN — TASK-1093 (#1093)

> `scripts/release-prep.sh` の `check_pending_applies()` を **stdout 文字列一致から
> 実態ベース判定へ差し替え**、`sync-plugin-installed.sh` を READY 条件から外し、
> `--dry-run` の出力契約を正本化する。**apply script の `--apply` は AI が実行しない**。

## Goal

**リリース readiness 検査の「適用待ち apply」判定が、
`--dry-run` の stdout に何を印字するかに依存せず、
(a) fail-open せず / (b) 誤検出せず / (c) 実行環境に依存せず / (d) 検出漏れしない**
状態にする。緑が出たときに「本当に適用待ちが無い」と言える構造にする。

## Constraints / Non-goals

### Constraints

- **`bin/plangate` / `.github/workflows/*` / `scripts/hooks/*.sh` は HO パス — AI は編集しない**
- **apply script の `--apply` は AI が実行しない**（Human-owned / `feedback_ho_apply_script_no_ai_exec`）。
  検証は **リポジトリの複製 sandbox 上でも `--apply` を使わず**、
  「未適用状態を持つ入力」に対する**判定関数の出力**で行う
- **他セッション占有域に触れない**: `tests/extras/ta-65-*` / `scripts/hooks/check-plan-hash.sh`（#1101）
- **`check_pending_applies()` は関数名で参照する**（行番号アンカー禁止 / #1089 教訓）
- **`tests/run-tests.sh` の baseline 件数を契約値にしない**（`feedback_no_absolute_counts_on_growing_dirs`）

### Non-goals

- 個々の apply script の**中身の是正**（逆方向差分 / 無条件ヘッダ / 引数解析欠落 → 別 issue 起票のみ）
- HO 9 カテゴリの内容変更
- 承認境界の緩和 / C-3・C-4 の変更
- `sync-plugin-installed.sh` 自体の実装変更（**呼び出し位置のみ**移す）

## Approach Overview

現行の `check_pending_applies()` は **script の stdout（表現）**を測っている。
これを **2 層**に置き換える:

1. **台帳（レジストリ）による実態判定 — 一次判定**
   `scripts/apply-registry.tsv`（新規・非 HO）に **`scripts/apply-*.sh` 1 本につき 1 行**、
   「適用済みかを判定する probe」と「スコープ区分」を持たせる。
   検出器は **script を実行せず**、probe を対象ファイルへ評価して
   `applied` / `pending` / `n/a` / `unknown` の 4 値を出す。

   | 値 | 意味 | READY への影響 |
   |----|------|--------------|
   | `applied` | 適用済み（probe 成立） | OK |
   | `pending` | 未適用（probe 不成立・対象ファイルは存在） | **NG** |
   | `n/a` | **repo 外 / untracked のローカル設定**が対象（`.claude/settings*.json` 等）＝リリース readiness の対象外 | OK（理由を明示表示） |
   | `unknown` | probe 対象が無い / probe 評価不能 / **台帳に行が無い** | **NG（判定不能）** |

   - **(a) fail-open 解消**: `2>/dev/null \|\| true` を撤廃。判定不能は `unknown`→NG（fail-closed）
   - **(b) 誤検出解消**: 「無条件ヘッダを印字するか」ではなく **対象ファイルに実装が入っているか**を見る
   - **(c) 環境依存解消**: probe 対象を **git tracked ファイルに限定**。
     untracked なローカル設定を対象とする script は `scope=local` → `n/a` で**両環境同値**
   - **(d) 検出漏れ解消**: `[dry-run]` を印字しない script も台帳行を持つため必ず判定される

2. **台帳カバレッジの機械強制 — 抜けを構造的に不可能にする**
   `ls scripts/apply-*.sh` の集合と台帳の script 集合が **完全一致**することを
   検出器とテストの両方で検査（**集合の同値照合。件数の絶対値は使わない**）。
   新規 apply script を台帳登録なしで追加すると `unknown`→NOT READY。

3. **`--dry-run` 出力契約の正本化 — 将来の橋渡し**
   `docs/ai/ho-change-workflow.md`（非 HO）に契約を追記:
   - `--dry-run`（および引数なし）は**非破壊**・`rc=0`
   - **`PLANGATE-APPLY-STATUS: applied|pending` を 1 行だけ stdout に出力**
   - 未知引数は `rc=1`
   契約に適合する script は**台帳 probe と突き合わせて cross-check** し、
   **不一致は `unknown` 扱い（fail-closed）**とする（R-2 drift 対策）。
   既存 34 本への後付けは **Out of scope**（台帳が橋渡しする）。

4. **`check_plugin_cache_sync()` を `run_checks()` から外す**
   関数は残さず削除し、`docs/release-process.md` の
   「リリース後の workflow run 結果確認」節の近傍に**リリース後手順**として記載。

### 既存 pending の扱い（R-1 / U-1）

新判定で **未適用が新規に可視化される**（`rnnn-c4-extension` / `task-0130-working-context` 等）。
リリースを恒久ブロックしないため、台帳に **`ack` 列**（`ack=<issue番号>` or 空）を設ける:

- `pending` かつ `ack` 空 → **NG（READY を阻む）**
- `pending` かつ `ack=#NNNN` → **WARN 表示・READY は阻まない**（未適用であることは毎回表示）

**`ack` の付与は Human 判断**（C-3 で承認された初期値のみを exec で書く）。
AI が黙って ack を増やすことは禁止（本 plan の停止条件 SC-2）。

## Work Breakdown

| # | Step | Output | Owner | Risk | 🚩 チェックポイント |
|---|------|--------|-------|------|------------------|
| 1 | 現行判定の再現と全数実測の固定 | `evidence/apply-dryrun-matrix.txt`（34/34・**取得済**）+ `evidence/current-verdict.txt` | AI | low | 34 本全数であることを `ls \| wc -l` と同値照合 |
| 2 | 台帳スキーマ確定 + 34 行の probe 記述 | `scripts/apply-registry.tsv` | AI | **high** | 各 probe が「適用済み」を**実測で**言えること。曖昧な 1 本でもあれば `unknown` に倒す |
| 3 | `check_pending_applies()` の実装差し替え | `scripts/release-prep.sh` | AI | **high** | 旧実装の `[dry-run]` 文字列一致が **残っていない**ことを grep で確認 |
| 4 | `check_plugin_cache_sync()` を `run_checks()` から除去 | `scripts/release-prep.sh` | AI | medium | `--check` 出力に「plugin キャッシュ」行が出ないこと |
| 5 | リリース後手順への移設 | `docs/release-process.md` | AI | low | 移設先から `sync-plugin-installed.sh` へ到達できること |
| 6 | `--dry-run` 出力契約の正本化 | `docs/ai/ho-change-workflow.md` | AI | medium | 既存 34 本を**遡って強制しない**と明記 |
| 7 | 回帰テスト（(a)(b)(c)(d) 1:1 + カバレッジ + 環境同値） | `tests/extras/ta-67-release-prep-pending.sh` | AI | **high** | **変異注入**で各 TC が旧実装/退行実装を kill することを実証 |
| 8 | AC-1/AC-2 の正負両方向 fixture | `tests/fixtures/`（sandbox 合成） | AI | **high** | `--apply` を**一切実行しない**こと（Constraint） |
| 9 | 別 issue 起票（Out of scope 分） | issue 3 本 | AI | low | 起票のみ。本 PBI では中身を直さない |
| 10 | 証跡の再現可能化 | `evidence/*`（すべて `<repo_root>` 引数で再実行可能） | AI | low | 別ディレクトリから実行して同一結果 |

## Files / Components to Touch

| ファイル | 区分 | 変更 |
|---------|------|------|
| `scripts/release-prep.sh` | **非 HO** | `check_pending_applies()` 差し替え / `check_plugin_cache_sync()` を `run_checks()` から除去 |
| `scripts/apply-registry.tsv` | **非 HO・新規** | apply script 台帳（script / scope / probe_target / probe_expr / ack） |
| `tests/extras/ta-67-release-prep-pending.sh` | **非 HO・新規** | 回帰テスト（`ta-65` は #1101 占有・不可侵） |
| `docs/ai/ho-change-workflow.md` | **非 HO** | `--dry-run` 出力契約の正本化 |
| `docs/release-process.md` | **非 HO** | plugin キャッシュ同期をリリース後手順へ |
| `docs/working/TASK-1093/**` | **非 HO** | plan / evidence |
| `scripts/apply-*.sh` | **非 HO** | **変更しない**（Out of scope。契約は新規 script から） |
| `bin/plangate` / `.github/workflows/*` / `scripts/hooks/*.sh` | **HO** | **触らない** |
| `tests/extras/ta-65-*` / `scripts/hooks/check-plan-hash.sh` | 他セッション占有 | **触らない** |

## Testing Strategy

| 層 | 内容 |
|----|------|
| **Unit** | 判定関数を 4 値（`applied`/`pending`/`n/a`/`unknown`）で単体評価。probe 評価・台帳パースの境界（空行 / コメント行 / タブ欠落 / 重複行） |
| **Integration** | sandbox に repo を複製し、**未適用状態を合成**（probe が不成立になる最小改変）→ `pending` 検出（AC-1）。**適用済み状態**（HEAD そのまま）→ 非検出（AC-2, AC-3）。probe 対象を故意に壊す → `unknown`→NG（AC-4） |
| **環境同値（AC-5）** | 同一入力に対し、`.claude/settings.json` **有り / 無し**の 2 sandbox で判定を実行し **出力を diff** して同一を確認（worktree 実機と通常 checkout 実機でも 1 回ずつ実走して証跡化） |
| **Mutation（検出力の実証）** | 各 TC を **旧実装（`[dry-run]` 文字列一致 + `2>/dev/null \|\| true`）** に対して走らせ **FAIL する**ことを確認。さらに新実装の call site を壊す変異（`unknown`→OK に倒す / 台帳カバレッジ照合を外す / `n/a` を無条件付与）で **kill を実証**（`feedback_mutation_testing_for_new_tests`） |
| **Verification Automation** | `evidence/*.sh` はすべて `<repo_root>` を引数に取り、任意ディレクトリから再実行可能 |
| **回帰 baseline（AC-7）** | `sh tests/run-tests.sh` **rc=0**。件数は**着手時に再測定して記録するのみ**（契約値にしない） |

## Risks & Mitigations

| ID | リスク | 緩和 |
|----|-------|------|
| R-1 | 一斉 NG 化でリリースが止まる | 台帳 `ack` 列（Human が C-3 で承認した初期値のみ）。ack 済みも毎回 WARN 表示して不可視化しない |
| R-2 | 台帳と script 実態が silent drift | (i) 契約適合 script は status 行と probe を **cross-check し不一致は `unknown`**、(ii) カバレッジ集合の同値照合、(iii) probe 対象ファイル不在は `unknown` |
| R-3 | 34 本への契約後付けが Out of scope に踏み込む | 契約は **新規 script のみ強制**。既存は台帳で橋渡しすると正本に明記 |
| R-4 | `apply-eh3-ho-always.sh` は HEAD で**既適用**のため AC-1 の未適用 fixture が無い | sandbox で probe 不成立状態を合成（`--apply` は使わない）。**AC-1 は「未適用の全 script」で実証**するため、HEAD で真に未適用の `rnnn-c4-extension` / `task-0130-working-context` も同時に対象化 |
| R-5 | AC-5 が解けない | 判定スコープを **git tracked ファイル**に限定し、untracked ローカル設定対象は `scope=local`→`n/a`。両環境で同一出力になることを diff で実証 |
| R-6 | `n/a` が「見なかったことにする」抜け道になる | `n/a` は **untracked/local を対象とする script に限る**。台帳の `scope` 値と probe_target のパスが整合しない行はテストで FAIL |
| R-7 | 本 PBI が承認境界そのものを緩めていないか | release-prep は **NG を増やす方向**の変更のみ。C-3/C-4/EH-3 に触れないことを差分で確認（停止条件 SC-3） |

## 停止条件 / Stop Conditions

| ID | 条件 | 行動 |
|----|------|------|
| **SC-1** | 34 本のうち **probe を実測で書けない script** が出た | その行は `unknown` に倒し、**握りつぶさず** plan の Unknowns に上げて報告 |
| **SC-2** | `ack` を新規に付けたくなった（AI 判断で NG を消したくなった） | **即停止・Human 判断を仰ぐ**。AI は ack を増やさない |
| **SC-3** | 差分が HO パス / `tests/extras/ta-65-*` / 承認境界に及んだ | **即停止**。`git diff --stat` で 0 件を毎回確認 |
| **SC-4** | AC-5 が「両環境同一」にならない | 設計（scope 定義）に戻る。テストを緩めて通さない |

## Questions / Unknowns

| ID | 内容 | 要判断者 |
|----|------|---------|
| **U-1** | 新規可視化される pending を **初期 ack するか / リリースブロッカーとするか** | **Human（C-3）** |
| **U-2** | 出力契約を既存 34 本へ後付けするか（本 plan は「しない」を提案） | **Human（C-3）** |
| **U-3** | `ack` を台帳に置くか別ファイル（監査ログ）に置くか | AI 提案 = 台帳同居 + 変更が diff に必ず出る形 |

## Mode 判定

**モード**: **high-risk**

**判定根拠**:

- 変更ファイル数: 6（`release-prep.sh` / `apply-registry.tsv` / `ta-67` / `ho-change-workflow.md` / `release-process.md` / working context）→ **high**（6-15）
- 受入基準数: 7（AC-1〜AC-7）→ **high**（6-10）
- タスク数（見込み）: 12-14 → **high**（11-20）
- 変更種別: リリース readiness ゲートのロジック差し替え + 新規台帳の導入 → **high**
- リスク: 誤ると **「リリースして良い」の判定が誤る**（false green の再生産） → **high**
- 影響範囲: release-prep の判定 → リリース可否判断。複数レイヤー（script / 台帳 / doc / test）→ **high**
- ロールバック: 計画的に必要（`release-prep.sh` の関数単位 revert + 台帳削除）→ **high**

**Hardening Override 判定**: `scripts/release-prep.sh` / `scripts/apply-registry.tsv` /
`tests/extras/*` / `docs/**` は **HO 9 カテゴリのいずれにも該当しない**
（HO は `.claude/rules/*.md` / `.claude/settings*.json` / `.claude/commands/*.md` /
`.claude/agents/*.md` / `scripts/hooks/*.sh` / `bin/plangate` / `schemas/*.schema.json` /
`.github/workflows/*` / `AGENTS.md`・`CLAUDE.md`。正本 = `scripts/hooks/check-plan-hash.sh`
の `_override=0` 直後の `case` ブロック）。
→ **HO 対象外**。ただし**リリースプロセス保護に直結**するため、
`mode-classification.md`「自動推定の安全側」に従い **high-risk へ引き上げ**る。

**最終判定**: **high-risk**
→ `lite_eligible=false` / **C-2 必須** / **C-3 は人間必須（autonomous APPROVE 不可）** /
V-2・V-3 実行。
