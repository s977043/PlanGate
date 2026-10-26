# TASK-1608 EXECUTION TODO

> Mode: high-risk。実装タスクは `rollback:` 必須。

## 👤 Human

- [ ] H-1 C-3: plan / todo / test-cases の承認判断（Q-1〜Q-4 は 2026-10-24 に決定済み）。`approvals/c3.json` は Human が発行 — owner: human
- [ ] H-2 C-4: PR レビュー・merge — owner: human / depends_on: T-12

## 🤖 Agent

### 準備

- [ ] T-1 現行 seeds / digest の不可視文字・HTML コメント・setext・blockquote の有無を実測し `evidence/` に記録 — depends_on: H-1 / rollback: 不要（読取のみ）
- [ ] T-2 回帰ケース（TC-R4-02 / TC-R4-03 / TC-HTML-* / TC-BLK-* / TC-INV-* / TC-NEG-*）を追加し、RED / GREEN の内訳を記録 🚩 — depends_on: T-1 / rollback: テスト追加コミットを revert

### 実装

- [ ] T-3 入力正規化（utf-8-sig・CRLF→LF）とブロック状態機械（fenced / html / indented / atx / paragraph・list）を実装 — depends_on: T-2 / rollback: commit revert
- [ ] T-4 seed 意味解析を状態機械の出力へ載せ替え（見出しの正規形判定・守備範囲外の日付見出しの拒否）🚩 既存 22 件 PASS — depends_on: T-3 / rollback: commit revert
- [ ] T-5 digest 意味解析（`## 対象エントリ` 節の唯一性・索引行）を載せ替え — depends_on: T-3 / rollback: commit revert
- [ ] T-6 不可視文字の拒否（D-2）と否定値判定の字句境界（D-3）🚩 TC-INV / TC-NEG PASS — depends_on: T-4, T-5 / rollback: commit revert
- [ ] T-7 旧正規表現・`mask_code_blocks` の撤去、docstring 残存脅威モデル更新（PG-SH-GUARD 領域は不変）🚩 TC-STRUCT-01/02 — depends_on: T-6 / rollback: commit revert

### 検証

- [ ] T-8 unit / ta-116 / ta-70 / 現行データ（TC-INT-01〜03）をログ保存 🚩 7 / 5 不変 — depends_on: T-7 / rollback: 不要
- [ ] T-9 変異注入（状態遷移ごと）で検出力を実証 — depends_on: T-8 / rollback: 変異は commit しない
- [ ] T-10 敵対レビュー R1（新構造への回避）→ `review-external.md` 台帳 — depends_on: T-9 / rollback: 不要
- [ ] T-11 敵対レビュー R2（是正の有効性・新しい穴・正常系の破壊）→ 収束判定。同層新クラスが 2 連続なら停止して Q-1 再提示 🚩 — depends_on: T-10 / rollback: 不要

### 改訂（2026-10-24、Human 裁定 (c) / plan D-1b）

- [ ] H-3 改訂 plan の C-3 再承認（新しい plan_hash で `approvals/c3.json` を Human が再発行）— owner: human
- [ ] T-13 TC-CB-01〜07 / N1〜N3 を追加し、現実装で RED になる内訳を記録 🚩 — depends_on: H-3 / rollback: テスト追加コミットを revert
- [ ] T-14 コンテナ境界の拒否（D-1b）を実装 🚩 TC-CB PASS・既存 55 件 PASS・現行データ 7 / 5 不変 — depends_on: T-13 / rollback: commit revert
- [ ] T-15 変異注入（境界判定の各条件）で検出力を実証 — depends_on: T-14 / rollback: 変異は commit しない
- [ ] T-16 敵対レビュー R5 / R6 → 収束判定。コンテナ軸で新クラスが 2 ラウンド続いたら再停止 🚩 — depends_on: T-15 / rollback: 不要

### 改訂 2（2026-10-25、Human 裁定「入れ子をすべて拒否」/ plan D-1c）

- [ ] H-4 改訂 2 の plan の C-3 再承認（新しい plan_hash で `approvals/c3.json` を Human が再発行）— owner: human
- [ ] T-17 TC-NEST-A / B / 03〜07 / N1〜N3 を追加し、現実装で RED の内訳を記録 🚩 — depends_on: H-4 / rollback: テスト追加コミットを revert
- [ ] T-18 入れ子拒否（D-1c）を container 更新の前に実装 🚩 TC-NEST PASS・既存 60 件（`1c26e9de` の実測 `Ran 60 tests`）PASS・現行データ 7 / 5 不変 — depends_on: T-17 / rollback: commit revert
- [ ] T-19 R6 m-1（リスト項目の内容オフセットを 2 に固定）の是正: 内容オフセットが 2 でないリスト（インデント付きマーカー ` - a`・番号付き `1. a`・マーカー後の空白 2 個以上）を拒否する（fail-closed。現行データ 0 行を実測済み）。拒否側 TC を追加 — depends_on: T-18 / rollback: commit revert
- [ ] T-20 R6 m-2（TC 件数の記録ずれ）の是正: handoff / status / current-state の単体テスト件数を、`python3 scripts/test_improvement_seed_delta.py` の `Ran N tests` の実測値で書き直す（R6 時点の実測は 60 件、記録は 61 件）。以後は件数をログの実測から転記する — depends_on: T-19 / rollback: 不要
- [ ] T-21 変異注入（入れ子判定・オフセット判定の各条件）で検出力を実証 — depends_on: T-20 / rollback: 変異は commit しない
- [ ] T-22 敵対レビュー R7 / R8 → 収束判定（オーガナイザー側）。コンテナ軸で新クラスが 2 ラウンド続いたら再停止 🚩 — depends_on: T-21 / rollback: 不要

### 改訂 3（2026-10-26、Human 決定「検証設計を変える」+ HD-1 / HD-2 / plan D-1d・検証モデル）

- [ ] H-5 改訂 3 の plan の C-3 再承認（新しい plan_hash で `approvals/c3.json` を Human が再発行）— owner: human
- [ ] H-6 HO patch（`docs/working/TASK-1608/ho/test-yml.patch`、hashFiles ガード付き）を、Human が origin/main から切った feature ブランチで `apply-test-yml.sh` により適用 → commit → PR → merge（#1611 より先。#1611 には依存しない。D-017）— owner: human / depends_on: T-26
- [ ] T-23 参照パーサー依存のハッシュ固定 requirements と、`reference_view` / `out_of_scope` + 射影規則の単体テスト（impl 非 import の検査つき）— depends_on: H-5 / rollback: commit revert
- [ ] T-24 4 値判定の差分ハーネス・件数 / 版 / ハッシュの assert・陽性対照 fixture（`ca9a8b33` / `1c26e9de`）🚩 陽性対照で検出 ≥ 1、参照パーサー不在で FAIL — depends_on: T-23 / rollback: commit revert
- [ ] T-25 V-B 生成器（不可視文字の独立軸・受理されるべき入れ子でない構造を含む）と V-C コーパス fixture（8 本、blob SHA 記録）。TC-NEST-C4〜C7 / N4〜N6 を追加し RED を記録 — depends_on: T-24 / rollback: テスト追加コミットを revert
- [ ] T-26 D-1d（列の上限なしの入れ子拒否）を実装 🚩 E-1〜E-4 をローカルで成立・現行データ 7 / 5 不変。差分テストのローカル実行時間（`SEED_DELTA_MINIMIZE=0`）と既存 `run-tests.sh` の時間を実測して status に記録し、E-1 の時間上限と patch の step `timeout-minutes` を確定（超える場合は patch を改訂）。HO patch の dry-run 結果を記録 — depends_on: T-25 / rollback: commit revert
- [ ] T-27 変異注入（impl の状態遷移・常に拒否・常に空・射影規則・`out_of_scope` の常に True / 列 2 以上で True）で E-5 を実証 — depends_on: T-26 / rollback: 変異は commit しない
- [ ] T-28 H-6 の merge 後に #1611 を main へ追従し、CI で差分テスト step が skip されず実行されたジョブログを確認して E-1 の証跡（URL・seed 範囲・版・spec 版・実行時間）を記録 🚩 — depends_on: H-6, T-27 / rollback: 不要
- [ ] T-29 敵対レビュー R8（検証モデルの穴）→ 停止条件で判定（オーガナイザー側）— depends_on: T-28 / rollback: 不要

> 改訂 4 の依存順序（D-017 / R-013）: H-5 → T-23 → T-24 → T-25 → T-26 → {T-27, H-6} → T-28 → T-29 → T-12 → H-2。
> H-6 は #1611 の merge に依存せず（hashFiles ガード）、T-23 の requirements が main に無くても適用・merge できるため循環しない。

### 完了

- [ ] T-12 handoff.md（残存脅威モデルを含む）・status / INDEX 更新、PR を ready for review — depends_on: T-29 / rollback: 不要
