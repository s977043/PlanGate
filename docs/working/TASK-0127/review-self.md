# C-1 セルフレビュー: TASK-0127

Mode: high-risk → フル C-1（Plan 7 / ToDo 5 / TestCases 3）

## Plan チェック（7項目）

| # | 項目 | 判定 | コメント |
|---|------|------|---------|
| P1 | 受入基準網羅性 | PASS | AC-01〜08 が plan の In scope / Work Breakdown / Testing に対応 |
| P2 | Unknowns 処理 | PASS | 簡易パーサ品質・HO 適用フローを Risks に明記し緩和策あり |
| P3 | スコープ制御 | PASS | In/Out（V2: serve/PDF/mermaid/外部MDライブラリ）明確 |
| P4 | テスト戦略 | PASS | Unit/Integration/Verification/エラー系を定義 |
| P5 | Work Breakdown Output | PASS | 各 Step に Output / Owner / Risk / 🚩 を付与 |
| P6 | 依存関係 | PASS | todo に depends_on、H02(HO適用)の AI 不可を明示 |
| P7 | 動作検証自動化 | WARN(minor) | 外部参照ゼロ(TC-08)・目次アンカー(TC-04)は grep ベースで自動化可能だが、ブラウザ目視確認の比重が残る |

## ToDo チェック（5項目）

| # | 項目 | 判定 | コメント |
|---|------|------|---------|
| T1 | タスク粒度 | PASS | T01〜T15 が 2〜5 分相当に分解 |
| T2 | depends_on 設定 | PASS | 全タスクに depends_on / files |
| T3 | チェックポイント設定 | PASS | T03/T05/T06/T10/T14 に 🚩 |
| T4 | Iron Law 遵守 | PASS | bin/plangate 直接編集なし→apply-script 経由・人間適用(H02) |
| T5 | 完了条件 | PASS | T15 で status/handoff 更新・evidence 保存 |

## TestCases チェック（3項目）

| # | 項目 | 判定 | コメント |
|---|------|------|---------|
| C1 | 受入基準との紐付き | PASS | AC→TC マッピング表あり（AC-01〜08 全カバー） |
| C2 | Edge case 網羅 | PASS | 空ファイル/巨大表/XSS エスケープを明記 |
| C3 | 自動化可否 | WARN(minor) | TC-04/TC-08 は grep で自動化可だが一部目視寄り |

## 総合判定

**PASS**（WARN minor 2 件: P7 / C3 — いずれもブラウザ目視の比重。grep ベース自動検証で代替可能なため exec をブロックしない）

FAIL なし → C-2 / C-3 へ進行可能。
