# TASK-1608 C-1 セルフレビュー

> 対象: plan.md / todo.md / test-cases.md（初版、2026-10-24）。実施者は plan 作成者本人（独立レビューではない）。

## 判定: WARN

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
