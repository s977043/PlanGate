---
task_id: TASK-0078
artifact_type: review-self
schema_version: 1
status: draft
---

# C-1 セルフレビュー — TASK-0078

## Plan（7項目）
| ID | 判定 | 備考 |
|----|------|------|
| 受入基準網羅 | PASS | AC-1〜7 が S1〜S5/V 対応 |
| Unknowns | PASS | F2 handoff で統合方針確定済・S1 対応表のみ |
| スコープ制御 | PASS | スクリプト挙動/#203/#251/TASK-0071 を Out。情報無損失厳守 |
| テスト戦略 | PASS | 情報無損失突合 + スクリプト diff ゼロ + hook 78/0 回帰 |
| WB Output | PASS | 各 Step Output |
| 依存関係 | PASS | #245/#246 マージ済（前提充足）・独立 |
| 動作検証自動化 | PASS | grep 突合 + git diff + hook テストで機械化 |

## ToDo（5項目）: 全 PASS
## TestCases（3項目）: 紐付き PASS / Edge E1〜E3 PASS / 自動化 PASS

## 総合判定: PASS（C-3 は差分確認主体）

統合方針は F2（TASK-0073）handoff で確定済・挙動変更ゼロのドキュメント
refactor のため、C-1 は重大論点なし。C-3 は「§5-bis への移設が情報無損失か」
の差分確認が主眼（意思決定事項なし）。standard のため V-3 実施。

### 留意（info）
- core-contract は governance 正本。§5-bis 節内のみ編集し他節 diff ゼロを
  S5 で機械確認（review-principles の §2〜4 不変と同型の不変ガード）。
