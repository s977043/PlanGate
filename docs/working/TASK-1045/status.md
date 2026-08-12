# STATUS — TASK-1045

> 計画: [`plan.md`](./plan.md) / ToDo: [`todo.md`](./todo.md) / TC: [`test-cases.md`](./test-cases.md)
> Mode: **`critical`** / `lite_eligible=false`

## モード判定結果

`critical`（plan §Mode 判定。C-3 裁定 Q-1 で維持確定）

## 全体構成

| PR / ブランチ | 状態 |
|---|---|
| `feat/1045-exec` | exec 完了・push 済み（**PR は未作成 = 指示による**） |

base: `origin/main` = `e9d384b77616314995c32d42a7f3d59f2dea32f6`

## フェーズ履歴

| 日時 | フェーズ | 内容 |
|---|---|---|
| 2026-08-12 | C-3 Gate | **APPROVED**（`plan_hash = sha256:30261b118da7761f7a78d9090c4fcda9f1d1dbd07af27cbff58ddd436029e681`）。`bin/plangate validate TASK-1045` = PASS |
| 2026-08-13 03:05 | exec 開始 | `feat/1045-exec` を `origin/main` から作成。`git diff origin/main --stat` = 0 件を確認 |
| 2026-08-13 03:06 | A-1 完了 | baseline **47 passed / 0 failed**。誤検知 11 形を本 PBI 内で再現。U-6 / U-3 / RT-2 / i-1 / R-008 を実測 |
| 2026-08-13 03:09 | A-1b 完了 | BSD `sed` と GNU `sed` 4.10 で **29/29 分類一致・出力 byte identical**。`RT-1` 不発火 |
| 2026-08-13 03:11 | A-2/A-3/A-4 完了 | RED 成立。FAIL 集合 = **GC-4-C の 6 件と完全一致**。focused 子で 7 ラベル全出現（UV-3 解消） |
| 2026-08-13 03:14 | A-5a 完了 | fd 複製/クローズ除去 + **GC-8 (i)(ii)(iii)** 実装。`T1045-TC-22` / `TC-22b` 追加・両 PASS |
| 2026-08-13 03:15 | A-5b/A-6a/A-6b 完了 | `/dev/null` 破棄除去を追加。**GREEN 成立**（56 passed / 0 failed）。アンカー 2 種とも `grep -c` == 1 |
| 2026-08-13 03:17 | A-7 完了 | 境界 TC + 併記回避 + 監査 + 既存突合 + syntax を通常群へ追加（66 passed / 0 failed） |
| 2026-08-13 03:18 | A-8/A-8b 完了 | `rule=<id>` 6 種を付与 + `T1045-TC-08`。`_t25_mutate` に label prefix 引数（既存 7 呼び出しは無変更） |
| 2026-08-13 03:19 | A-9/A-10 完了 | 変異 2 方向がともに **実 TC の `[FAIL]` + 子 rc 非 0** で kill。出力ラベル `T1045-TC-09` / `T1045-TC-10` |
| 2026-08-13 03:2x | A-11/A-12/A-13 完了 | evidence 採取・`sh -n` PASS・standalone **70 passed / 0 failed**・`tests/run-tests.sh` 実行 |

## C-3 Gate: APPROVED

`docs/working/TASK-1045/approvals/c3.json`（**Human-owned**。AI は作成・編集していない）
`plan.md` は C-3 承認後 **1 行も編集していない**（`plan_hash` 維持）。

## Stop Condition / Replan Trigger の処理状況

| ID | 結果 |
|---|---|
| SC-1 | **不発火**。(a) baseline 0 failed / (b) RED の FAIL 集合が GC-4-C の 6 件と完全一致 |
| SC-2 | **不発火**。`t1045-redirect-normalize` = 1 / `t1045-file-redirect` = 1 |
| SC-3 | **不発火**。変異 (a)(b) とも kill（実出力を evidence に保存） |
| SC-4 | **不発火**。既存 mutation 7 種（`TC-15`/`16`/`17`/`17b`/`17c`/`17d`/`17e`）すべて kill 継続 |
| SC-5 | **不発火**。`T1023-TC-09` PASS 維持 |
| SC-6 | **不発火**。`T1045-TC-07 (1)` / `TC-11`〜`15` / `TC-19` すべて rc=2 |
| SC-7 | **不発火**（下記「計画からの変更点」の注記あり） |
| SC-8 | **不発火**。`PLANGATE_SKIP_TOKEN_GUARD` は一度も使用していない |
| SC-9 | **不発火**。`T1045-TC-22` / `TC-22b` 両 PASS + (i) 欠落 build での FAIL-OPEN を実測して検出力を実証 |
| RT-1〜RT-5 | **すべて不発火**（RT-1 は 29/29 一致 / RT-2 は複製・invoke なし / RT-3 は `tests/` ヒット 0 / RT-4 は既存 7 呼び出し無変更で全 PASS / RT-5 は列挙的 allowlist のまま AC-01〜03 充足） |

## 計画からの変更点

1. **A-1b のケース数**: plan は 26 ケースを想定。実行は **29 ケース**（plan の集合を包含する上位集合）。
   分類は BSD / GNU で完全一致。
2. **A-1b の GNU `sed` 取得手段**: docker daemon 停止のためコンテナを使わず、
   **ローカルへ GNU sed 4.10 を導入**して実行（リポジトリ変更なし）。
   CI（Linux / GNU `grep` / dash）の実行結果は PR 作成後にしか得られないため未取得。
3. **`T1045-TC-16` の実装形**: 「スイート自身を suite 内で再実行する」は無限再帰になるため、
   既存の `PG_T25_NO_RECURSE=1` 機構を用いた **子プロセスでの通常群フル実行**（0 failed）
   + 既存 TC ラベルの静的存在確認 の 2 段で実装した。
   `sh tests/run-tests.sh` 経路は A-13 で外側から実行し evidence に残す。
4. **`FP-E`（`->` を含む文字列リテラル）は解消しない**。plan **GC-2** が
   「文字列リテラル中の `>` は block 維持＝誤検知として扱わない」と宣言済みで、
   固定 TC は `T1045-TC-19`。handoff の既知課題へ記載。

## 残タスク

- [ ] **C-4（PR レビュー）**: PR は本 exec では作成しない（派遣指示）。人間が PR を起票する
- [ ] CI（ubuntu / GNU）での `ta-25` 実行結果取得（UV-1 の最終クローズ）
- [ ] follow-up issue 起票: `apply-task-0123-patches.sh` の複製導線（R-008 / R-14）
- [ ] follow-up issue 起票: `tests/run-tests.sh` が実リポジトリ直下へテスト用 TASK ディレクトリを残す件（下記 P1）

## 既知の副作用（本 PBI の変更由来ではない）

`sh tests/run-tests.sh` は **実行中**、リポジトリ作業ツリーに以下の untracked ディレクトリを一時生成する:
`docs/working/TASK-APPROVE-HARDEN-TEST/` / `TASK-FORCE-OVERWRITE-TEST/` / `TASK-T420/` / `TASK-T999/`。
**実行完了時に runner が cleanup し、実測で 4 件とも消滅**（残留なし）。恒久的な汚染ではない。
**本 PBI の変更とは無関係**であり commit もしていない。中断時に残りうる点のみ留意。
