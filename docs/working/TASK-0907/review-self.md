# C-1 セルフレビュー — TASK-0907

> Mode=critical → 17 項目フル。判定: PASS / WARN / FAIL。

## Plan チェック（7 項目）

| # | 項目 | 判定 | 根拠 |
|---|------|------|------|
| C1-PLAN-01 | 受入基準網羅性 | PASS | AC-1〜5 が Work Breakdown S1〜S6 / test-cases TC-1〜5 に全対応 |
| C1-PLAN-02 | Unknowns 処理 | PASS | Questions/Unknowns に C-3 論点 5 件を先出し。仮説（HO 適用前の中間状態）と確定事項（HO 判定・sync 経路）を分離 |
| C1-PLAN-03 | スコープ制御 | PASS | 00_concept を Out of scope 明示（B-1 Q2）。§5 変更・#780 本体・§3 変更を Non-goal 明記 |
| C1-PLAN-04 | テスト戦略 | PASS | doc V-1 / sync drift cmp / §5 diff ゼロ / doctor 回帰。論理コード変更ゼロを反映 |
| C1-PLAN-05 | Work Breakdown Output | PASS | 各 S に Output/Owner/Risk/🚩/rollback。速く学べる順（sync 検証をクリティカルパス末尾） |
| C1-PLAN-06 | 依存関係 | PASS | T2→T3/T4→T5→T6、C-1/C-2→H1→H2→PR→H3 を todo ⚠️ に明記 |
| C1-PLAN-07 | 動作検証自動化 | PASS | sync-plugin-plangate.sh + cmp（機械照合）/ git diff §5 範囲 / doctor |

## ToDo チェック（5 項目）

| # | 項目 | 判定 | 根拠 |
|---|------|------|------|
| C1-TODO-01 | タスク粒度 | PASS | T1〜T8 各 2〜5 分相当（doc 編集単位） |
| C1-TODO-02 | depends_on 設定 | PASS | 全タスクに depends_on 明記 |
| C1-TODO-03 | チェックポイント設定 | PASS | 🚩 を §5 不変・HO 適用ゲート・drift 再検証に配置 |
| C1-TODO-04 | Iron Law 遵守 | PASS | HO patch は生成のみ・適用 Human（責務4分類）。NO MERGE BY AI |
| C1-TODO-05 | 完了条件 | PASS | 各タスクの Output が完了条件。rollback を critical 実装タスク（T2〜T5）に必須記載 |

## TestCases チェック（3 項目）

| # | 項目 | 判定 | 根拠 |
|---|------|------|------|
| C1-TC-01 | 受入基準との紐付き | PASS | TC-1〜5 が AC-1〜5 に 1:1 |
| C1-TC-02 | Edge case 網羅 | PASS | EC-1（HO 未適用中間状態）/ EC-2（§4 再定義禁止）/ EC-3（リンク切れ） |
| C1-TC-03 | 自動化可否 | PASS | 全 TC が grep/diff/cmp で機械判定可 |

## Mode / lite_eligible チェック

| 項目 | 判定 | 根拠 |
|------|------|------|
| Mode 判定妥当性 | PASS | critical（承認境界＋ワークフロー定義 HO）。mode-classification 例外ルール一致 |
| lite_eligible | PASS | false（AC-10 Hardening Override 優先）。C-3 同期固定 |

## 総合判定

**PASS**（17/17）。WARN/FAIL なし。

注記: 本 plan は承認境界（rollout eligibility policy）を触るため、C-1 PASS でも **C-2 は 2 レーン + 敵対的観点必須**（承認境界の受理側は 1 ラウンドでは表層のみ）。特に「§2 拡張が §5 不変を実質緩和していないか」「注記節が §4 を再定義せず参照に留まるか」を C-2 で一次ソース照合する。
