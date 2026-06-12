# C-1 セルフレビュー: TASK-0128

Mode: high-risk → フル C-1（Plan 7 / ToDo 5 / TestCases 3）

## Plan チェック（7項目）

| # | 項目 | 判定 | コメント |
|---|------|------|---------|
| P1 | 受入基準網羅性 | PASS | AC-01〜09 が Approach / Work Breakdown / Testing に対応 |
| P2 | Unknowns 処理 | PASS | TTY 取得可否・settings drift・bootstrap を Risks に明記し緩和策あり |
| P3 | スコープ制御 | PASS | In/Out（V2: GitHub案B / #420フル / C-4 / 親PBI）明確 |
| P4 | テスト戦略 | PASS | Unit/Integration/Security負例/回帰/settings を定義。非対話拒否を中核に据える |
| P5 | Work Breakdown Output | PASS | 各 Step に Output/Owner/Risk/🚩 |
| P6 | 依存関係 | PASS | todo depends_on、H02 の人間専任・bootstrap 依存を明示 |
| P7 | 動作検証自動化 | WARN(minor) | 対話 TTY シミュレーション（script コマンド等）は環境依存。非対話拒否側は自動化容易 |

## ToDo チェック（5項目）

| # | 項目 | 判定 | コメント |
|---|------|------|---------|
| T1 | タスク粒度 | PASS | T01〜T16 が適切に分解 |
| T2 | depends_on 設定 | PASS | 全タスクに depends_on/files |
| T3 | チェックポイント設定 | PASS | T03/T05/T09/T10/T13/T14/T15 に 🚩（防御・回帰の要所） |
| T4 | Iron Law 遵守 | PASS | bin/plangate + settings は apply-script 経由・人間適用（H02） |
| T5 | 完了条件 | PASS | T16 で status/handoff/evidence |

## TestCases チェック（3項目）

| # | 項目 | 判定 | コメント |
|---|------|------|---------|
| C1 | 受入基準との紐付き | PASS | AC→TC 全カバー（AC-01〜09） |
| C2 | Edge case 網羅 | PASS | plan不在/git config未設定/mkdir + 回帰TC-R1 |
| C3 | 自動化可否 | PASS | 非対話拒否・三値・hash は自動化可。TTY正常系は script で擬似化 |

## リスク特記（high-risk として）

- **回帰リスク**: maintenance の L1-L4 共通化は既存の承認境界防御に触れる。TC-R1（回帰）を必須ゲートとし、共通化は関数抽出に限定（挙動不変）。
- **bootstrap**: 本 PBI の C-3 を機構で自己承認できない循環は plan/todo で interim→完成後正規化として解消設計済み。

## 総合判定

**PASS**（WARN minor 1 件: P7 — TTY 正常系の自動化が環境依存。負例側の自動化で承認境界の安全性は担保）

FAIL なし → C-2 / C-3 へ進行可能。なお high-risk かつ承認境界中核のため、本 PBI は C-2 外部レビュー推奨度が高い。
