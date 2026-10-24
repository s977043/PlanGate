# TASK-1608 C-1 セルフレビュー

> 対象: plan.md / todo.md / test-cases.md（初版、2026-10-24）。実施者は plan 作成者本人（独立レビューではない）。

## 簡易 C-1 再判定（2026-10-24、Human 裁定 (c) による plan 改訂後）: PASS

- C1-PLAN-01 / C1-TEST-13: AC-11 を追加し、TC-CB-01〜07（拒否側。TC-CB-01 は R4 の再現）/ TC-CB-N1〜N3（正常系）/ TC-INT-03 に対応づけた → PASS
- C1-PLAN-02 Unknowns: 「コンテナ境界をどう解釈するか」は解釈しない（拒否）と決定済み（D-011）→ PASS
- C1-PLAN-03 スコープ: 変更は同じ 2 ファイル。HO パスなし。規則の適用範囲は「空行なしのコンテナ切り替え」に一般化して定義し、例は種別として列挙 → PASS
- C1-PLAN-04 テスト戦略: 現行データでの誤拒否ゼロを受入条件にし、事前実測（境界は blockquote 継続のみ）を記載 → PASS
- C1-PLAN-08/09 Stop / Replan: 改訂後の敵対レビューは R5 から下限 2、コンテナ軸で新クラスが 2 連続なら再停止 → PASS
- C1-TODO: H-3（再承認）→ T-13（RED 記録）→ T-14 → T-15 → T-16 の順、rollback 記載 → PASS
- 注記: 既存の `approvals/c3.json` は初版の plan_hash であり本改訂とは一致しない（編集・削除していない）。exec 再開には Human の再承認が要る

## 簡易 C-1 再判定（2026-10-24、Q-1〜Q-4 確定反映後）: PASS

- C1-PLAN-02 Unknowns 処理: WARN → **PASS**（Q-1〜Q-4 を Human 回答で決定済み。decision-log D-004〜D-007）
- C1-PLAN-01 / C1-TEST-13: AC-10（Q-3 の読み替え）を追加し、test-cases の TC-BLK-01〜05 / TC-HTML-01〜04 に対応づけた → PASS
- C1-PLAN-03 スコープ: 依存追加をしないことが確定し、変更範囲は 2 ファイルのまま → PASS
- 他項目は plan の内容に変更がないため初回判定のまま

## 初回判定（2026-10-24）: WARN

FAIL 項目なし。Human 判断が必要な Unknowns（Q-1〜Q-4）が残るため WARN。

| ID | 観点 | 判定 | 所見 |
|----|------|------|------|
| C1-PLAN-01 | 受入基準網羅性 | PASS | AC-1〜9 すべてに test-cases の対応あり |
| C1-PLAN-02 | Unknowns 処理 | WARN | Q-1〜Q-4 を推奨案つきで Human へ。Q-1 で代替案が選ばれたら plan 再生成 |
| C1-PLAN-03 | スコープ制御 | PASS | 変更は 2 ファイル。HO パス・出力スキーマ・依存追加は Out of scope と明記 |
| C1-PLAN-04 | テスト戦略 | PASS | unit / ta-116 / ta-70 / 現行データ / 変異注入 |
| C1-PLAN-05 | Work Breakdown Output | PASS | S1〜S6 に Output と 🚩 |
| C1-PLAN-06 | 依存関係 | PASS | todo の depends_on で直列化 |
| C1-PLAN-07 | 動作検証自動化 | PASS | 3 コマンドのログを evidence に保存 |
| C1-PLAN-08-AEE | Stop Condition | PASS | 3 条件を明記 |
| C1-PLAN-09-AEE | Replan Triggers | PASS | 現行データ 7 / 5 の変化、同層新クラス 2 連続 |
| C1-SUP-PLAN-01 | No Placeholders | PASS | |
| C1-SUP-PLAN-02 | Task Sizing | PASS | 12 タスク |
| C1-TODO-08〜12 | 粒度・depends_on・🚩・Iron Law・完了条件 | PASS | テスト先行（T-2）を実装より前に置く |
| C1-TODO-RB | rollback | PASS | 実装タスク全件に記載 |
| C1-TEST-13 | AC→TC 網羅 | PASS | |
| C1-TEST-14 | 具体性 | PASS | 最小再現の入力を記載 |
| C1-TEST-15 | エッジケース | PASS | 入れ子・CRLF・4 空白 fence |
| C1-SEC-01 | セキュリティ | PASS | 確認マーカー受理判定は安全側（誤拒否を許容し誤受理を避ける）。`authority` 不変 |
| C1-SCOPE-DISC-01 | スコープ規律 | PASS | |

## 自己指摘（反映済み）

- 初稿の D-3 は「先頭トークン判定をやめ値全体で判定」としていたが、`no, later` が受理される fail-open を生むため、
  現行の先頭トークン判定を維持する案へ改め、AC-6 と Q-4 を追加した
