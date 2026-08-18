# C-1 セルフレビュー — TASK-1115 (#1115)

対象: `plan.md` / `todo.md` / `test-cases.md`（`high-risk` = 17 項目フル）

## Plan チェック（7 項目）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| C1-PLAN-01 | 受入基準の網羅性 | **PASS** | AC-1〜6 が Work Breakdown S-2〜S-5 と test-cases のマッピング表で 1:1 対応。AC-4（#1110 回帰）・AC-5（誤検出）を負側 AC として独立に立てた |
| C1-PLAN-02 | Unknowns の処理 | **PASS** | 混在引用（`"c3.jso"*`）を Unknowns に挙げ、引用除去版でも照合する設計で解消。未解消の残存クラスは plan §残存クラスに 4 件明示 |
| C1-PLAN-03 | スコープ制御 | **PASS** | #1101（HO 側）/ `&>`（#1110 据置）/ `rm` 系書き込み意図拡張を Out of scope に明記。触るファイルは HO 外 2 本 + Plan Package のみ |
| C1-PLAN-04 | テスト戦略 | **PASS** | 本番経路（stdin PreToolUse payload）に統一。変異はレーン全体 1 + レーン内部 4（うち 1 は誤検出方向） |
| C1-PLAN-05 | Work Breakdown の Output | **PASS** | S-1〜S-5 すべてに Output と rollback を記載 |
| C1-PLAN-06 | 依存関係 | **PASS** | todo に T-01→…→T-07 の順序と H-01/H-02 の Human 依存を明示 |
| C1-PLAN-07 | 動作検証の自動化 | **PASS** | `ta-25` 単体実行で全 AC を機械判定。手動確認に依存する AC なし |

## ToDo チェック（5 項目）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| C1-TODO-01 | タスク粒度 | **PASS** | 9 タスク。実装/テスト/検証が分離 |
| C1-TODO-02 | depends_on 設定 | **PASS** | ⚠️ 依存関係セクションに記載 |
| C1-TODO-03 | チェックポイント | **PASS** | T-02 / T-04 / T-05 / T-07 に 🚩 |
| C1-TODO-04 | Iron Law 遵守 | **PASS** | `c3.json` を発行しない・merge は Human-owned を todo と plan の双方に明記 |
| C1-TODO-05 | 完了条件 | **PASS** | `ta-25` rc=0 + before/after 実測表 + 変異 kill |

## TestCases チェック（3 項目）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| C1-TC-01 | 受入基準との紐付き | **PASS** | AC→TC マッピング表あり。AC-3 は既存 TC 全件 + TC-05 に紐付け |
| C1-TC-02 | Edge case 網羅 | **PASS** | エッジケース 4 件（basename に glob 無し / `approvals-notes` / 先頭 glob / 変数代入語）。うち 2 件は**閉じない**ことを期待値として固定 |
| C1-TC-03 | 自動化可否 | **PASS** | 全 TC が `ta-25` で自動実行可能 |

## 追加観点（本 PBI 固有 / diff-audit Phase 6）

| 観点 | 判定 | 根拠 |
|------|------|------|
| 変異は **call site** を壊すか | **PASS** | M-7〜M-11 はすべてアンカーコメント付き call site 行を書き換える（関数定義の削除ではない） |
| **レーン内部の分類**を誤らせる変異があるか | **PASS** | M-8（ルール A のみ）/ M-9（ルール B のみ）/ M-10（誤検出方向）/ M-11（basename 抽出）。M-7 だけに依存していない |
| 負側 TC が**本番経路**を通るか | **PASS** | 全 TC が `t25_guard`（stdin に PreToolUse JSON を供給）経由。明示引数 / テスト専用 env に偏っていない |
| 成長する対象に**絶対件数**を assert していないか | **PASS** | 新規 TC / 変異のいずれも件数を等値比較しない（既存 `T1045-TC-21` の `=7` は本 PBI で触らない既存契約） |
| fail-closed を緩めていないか | **PASS** | 既存の判定不能 → block 経路は無改変。追加はゲートを**広げる**方向のみ |
| 真の陽性を落としていないか | **PASS** | 既存 `ta-25` 86 件が実装後も全 PASS（実測）。before/after 実測で `2 → 0` の遷移は 0 件 |

## 判定

**PASS**（FAIL 0 / WARN 0）

### 指摘事項（minor / plan に反映済み）

- **R-101 (minor)**: 先頭 glob（`*.json`）を照合対象から外すため、approvals 外の
  `cp x foo/*3.json` 型は残存する。誤検出抑制とのトレードオフとして plan
  §残存クラスに明記済み。承認境界を「広げない」方向の残存であり、
  #1115 の報告クラス（ファイル名リテラルの崩し）は閉じている。
- **R-102 (minor)**: `rm` は `_has_write_intent` に含まれないため
  `rm <approvals>/*.json` は依然 rc=0。**既存ギャップ**であり本 PBI で
  新たに生じたものではない。Out of scope に明記、follow-up 候補。

## C-3 について

Mode = `high-risk`（承認境界のガード本体・block を広げる変更）のため
`lite_eligible=false`、**autonomous APPROVE 不可**。
本ワーカーは `docs/working/TASK-1115/approvals/c3.json` を**発行しない**。
