# C-1 セルフレビュー（第 2 回 / v3・v4 に対する差分検証）— TASK-1101

> **本ファイルは [`review-self.md`](./review-self.md)（v1 に対する第 1 回・`verdict: FAIL`）の後続**。
> `working-context.md` の C-3 ゲートは「review-self.md（C-1）と review-external.md（C-2）を人間が確認」と定めるため、
> **人間が最初に開く C-1 文書が FAIL・v1 内容のままでは承認判断の入力が壊れる**（RiverReview M-9）。
> 第 1 回は**履歴として保持**し、解消状況は本ファイルを正とする。
>
> 実施: 2026-08-15 / `origin/main` = `dfaeebb` / 対象: **plan v4**

## 総合判定

| 回 | 対象 | verdict |
|---|---|---|
| 第 1 回（[review-self.md](./review-self.md)） | plan **v1** | **FAIL**（11 FAIL / 3 WARN / 3 PASS） |
| 簡易 C-1（差分検証） | plan **v2** | **WARN**（未解消 3 / 新規 4） |
| **本ファイル（第 2 回）** | plan **v4** | **PASS（条件付き）** |

**条件**: C-3 で **Mode override の承認**を得ること（下記 §未解決事項）。

## 第 1 回 FAIL 11 件 / WARN 3 件の最終状態

| 項目ID | 第 1 回 | 最終 | 反映先 |
|---|---|---|---|
| C1-PLAN-03（`_norm_target` の共有） | FAIL | **解消** | plan §中核の設計判断（`_ho_key`）/ **AC-2** / TC-02・03・04 / **TC-08 第 8 変異**（M-4 で検出力を担保） |
| C1-PLAN-06（依存の逆行） | FAIL | **解消** | plan Step 2 前倒し / Step 3 sandbox / todo T-07 |
| C1-PLAN-07（AC-4 が false green） | FAIL | **解消** | **AC-4**「`ta-65` 経由での確認は不可」/ plan Step 6 / TC-07（**M-7 で大文字入力も追加**） |
| C1-TODO-08（粒度） | FAIL | **解消** | todo T-01〜T-19 + H-01〜H-03 |
| C1-TODO-09（depends_on） | FAIL | **解消** | 全 22 タスク。**N-3 で依存グラフに H-01 を前段として描画** |
| C1-TODO-10（チェックポイント） | FAIL | **解消** | 全タスクに🚩（T-11/12/13/18/19 を追加） |
| C1-TODO-11（Iron Law） | FAIL | **解消** | T-05🚩「AI は `--dry-run` のみ」/ H-02 を Human タスクへ分離 |
| C1-TODO-12（完了条件） | FAIL | **解消** | 各タスクに要件記述。AC-6 は T-01 + T-17 |
| C1-TEST-13（AC→TC 網羅） | FAIL | **解消** | AC-1〜AC-11 の 11 件すべてに TC 割当（機械確認済み） |
| C1-TEST-14（具体性） | FAIL | **解消** | 入力値・期待 rc・期待文字列を値で記述。**m-6 で TC-11b の省略記法も是正** |
| C1-TEST-15（エッジケース） | FAIL | **解消** | 9 件。**N-1 で `/CLAUDE.md` の期待値を統一** |
| C1-PLAN-01（AC-6 の Step 欠落）WARN | WARN | **解消** | plan Step 8 / todo T-01 / **Step ↔ ToDo 対応表** |
| C1-PLAN-04（seam / AC-3 の測定力）WARN | WARN | **解消** | plan Step 1「単体ファイルとして実装」/ AC-3 拡充 / TC-06 |
| C1-B1B2-16（B-1 記録なし）WARN | WARN | **受容** | 未決論点（repo root 跨ぎ `..`）は **AC-8 で block に確定済み**のため実害なし。§未解決事項に記載 |

**第 1 回の 14 件: 解消 13 / 受容 1。**

## 簡易 C-1（v2 に対する差分検証）で検出した新規指摘

| N-n | severity | 最終 | 反映先 |
|---|---|---|---|
| N-1（`/CLAUDE.md` の期待値が 3 箇所で矛盾） | major | **解消** | plan Non-goals / **AC-8 を 2 条件へ** / エッジケース表 / **TC-11b 新設** |
| N-2（AC-8 の「絶対パス残り」は到達不能・空振り fixture） | major | **解消** | **AC-8 から削除** / TC-11 に具体値 5 件 |
| N-3（依存グラフに H-01 が無い） | minor | **解消** | todo §依存関係 |
| N-4（T-01 / T-02 に対応する Step が無い） | minor | **解消** | **plan v4 で Step 0 を追加** + Step ↔ ToDo 対応表 |

## RiverReview（第 3 の外部レビュー）で検出した指摘

> **critical 1 件は、第 1 回 C-1・C-2 3 レーン・簡易 C-1 の 4 回すべてが見逃していた。**

| ID | severity | 最終 | 反映先 |
|---|---|---|---|
| **C-1（順序 (2)→(3) で `.//CLAUDE.md` が skip される）** | **critical** | **解消** | **plan v4 で畳み込みを最初に置く** / pbi-input §正規化の適用順序 / TC-01🚩 / TC-07 / TC-08🚩 |
| M-1（AC-9 / TC-12 が PASS 不能） | major | **解消** | **AC-9 の対象を `hook-events.log` に限定** / TC-12 |
| M-2（plan に「fail-closed 3 件」が残存） | major | **解消** | plan v4 Step 4 |
| M-3（Mode が正本の定量表と不整合） | major | **解消（override / 要 C-3 承認）** | pbi-input §Mode / plan §Mode 判定 / todo H-01🚩 |
| M-4（AC-2 の検出力が無担保） | major | **解消** | **TC-08 に第 8 変異**（v1 設計を注入）/ AC-5 |
| M-5（In scope が 3 クラスのまま） | major | **解消** | pbi-input In scope を **7 クラス**へ |
| M-6（行番号アンカーの多用） | major | **解消** | plan の消費点表を**記号アンカー**へ（行番号は「参考」と明示） |
| M-7（TC-07 が 3 クラスしか測らない） | major | **解消** | TC-07 に**大文字入力 3 件**を追加 |
| M-8（#1104 の書き分け要求に拘束力が無い） | major | **解消** | **AC-7 に (a)(b) を条件追加** / TC-10 を grep 5 項目へ |
| M-9（C-1 の verdict が FAIL のまま） | major | **解消** | **本ファイル**（review-self-2.md）を発行 |
| M-10（監査表の REFLECTED が虚偽） | major | **解消** | **plan v4 で Step 0 を実際に追加** / todo に経緯を明記 |
| m-1〜m-4（版ずれ） | minor | **解消** | status / current-state / todo / test-cases / INDEX |
| m-5（小文字化の実装が未定義） | minor | **解消** | plan §実装方式に **1 文字ずつの `case` ループ**を明記 |
| m-6（TC-11b の省略記法） | minor | **解消** | 具体値 + 自己完結の作成/削除手順へ |
| m-7（AC-7 の前提が事実より強い） | minor | **解消** | 訂正対象を「総数」→「**列挙した変換クラスの不足**」へ |
| m-8（C-2 を「3 レーン」と表記） | minor | **解消** | review-external.md の体制表記 |
| i-1（`evidence/c1-review/` が無い） | info | **解消** | 本ファイル発行時に整備 |

## 未解決事項（C-3 で判断を要する）

| # | 内容 | 状態 |
|---|---|---|
| **U-1** | **Mode override**: 定量では `critical` 帯（受入基準 11+）だが `high-risk` を維持する（2026-08-15 ユーザー選択 **B**）。**C-3 でこの判断ごと承認を得る** | **要承認** |
| U-2 | B-1 確認質問の記録が package 内に無い（C1-B1B2-16）。実体だった未決論点は AC-8 で確定済み | 受容 |
| U-3 | マルチバイト環境（`ja_JP.UTF-8`）での小文字化の挙動が未実測。**Step 6 の 4 シェル評価で確認**し、問題があれば `case` 側で吸収（**方式分岐にはならない**） | exec 中に解消 |

## 検証した事実（一次ソース）

| 主張 | 実測 |
|---|---|
| `.//CLAUDE.md` は実ファイルに到達する | `ls -la .//CLAUDE.md` → 6,572 bytes |
| v3 の順序で `.//CLAUDE.md` が `/CLAUDE.md` になる | `sh -c 'case "$v" in ./*) v="${v#./}";; esac'` → `/CLAUDE.md` |
| v4 の順序で `.//CLAUDE.md` が `CLAUDE.md` になる | 畳み込み関数を直接評価 → `CLAUDE.md` |
| v4 の順序で絶対パスが不変（skip 側） | `/private/tmp/x/note.md` → 変化なし |
| HO block は `skip-decision-log.jsonl` に書かない | `grep -n 'skip-decision-log'` → SKIP 3 経路のみ。HO block は `log_event` のみ |
| 受入基準 11 件は正本の定量表で `critical` 帯 | `mode-classification.md` の定量表 → `11+` = 超高 |
| plan v3 に Step 0 は存在しなかった | `grep -n '^### Step' plan.md` → Step 1〜9 のみ |
| `hook-enforcement.md` は迂回総数を 4 件と主張していない | 該当箇所 → 「ta-65 TC-07 が 4 ケースを KNOWN-GAP として固定」＝ TC の内容 |
