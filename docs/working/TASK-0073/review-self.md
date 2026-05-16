---
task_id: TASK-0073
artifact_type: review-self
schema_version: 1
status: draft
---

# C-1 セルフレビュー — TASK-0073

## Plan チェック（7項目）
| ID | 判定 | 備考 |
|----|------|------|
| C1-PLAN-01 受入基準網羅 | PASS | AC-1〜7 が S1〜S7/V に対応 |
| C1-PLAN-02 Unknowns | PASS | 境界表現/検出主体/settings要否を S2・C-3 に明示分離 |
| C1-PLAN-03 スコープ制御 | PASS | F1/sockpuppet/F5 を Out。未宣言は従来動作 |
| C1-PLAN-04 テスト戦略 | PASS | 決定論マトリクス + 回帰 + F1整合 |
| C1-PLAN-05 WB Output | PASS | 各 Step Output |
| C1-PLAN-06 依存関係 | PASS | F1/#245 整合、S2→S4、認証メモリ参照 |
| C1-PLAN-07 動作検証自動化 | WARN | プリフライト/認証は環境依存。Hook+文書トレースで担保（D-3） |

## ToDo（5項目）: 粒度/depends_on/CP/IronLaw/完了条件 すべて PASS

## TestCases（3項目）: 紐付き PASS / Edge(E1〜E4) PASS / 自動化 WARN（TC-4/6 認証は半自動）

## 総合判定: CONDITIONAL（C-3 意思決定要）

### D-1（C-3 必須・major）: 委譲 commit 境界の構造化表現 + 検出主体
候補表現: (i) todo.md の委譲タスクにメタフィールド (ii) 委譲プロンプト規約
(iii) 専用 delegation-contract ファイル。検出主体: (a) PreToolUse Hook on
git（決定論・100%強制・PlanGate 思想合致だが settings wiring 要→TASK-0070
教訓で Claude 適用不可リスク） (b) exec 後検証ステップ（wiring 不要だが
事後）。**推奨: 表現=(i) todo.md メタ、検出=(a) Hook + (b) 事後検証の二段**。
C-3 で確定。

### D-2（C-3 必須・major）: mode 確定（high-risk か critical か）
S6 が core-contract の実質的不変条件追加に及ぶか次第。**§5-bis 参照型の
最小追記なら high-risk、独立不変条件新設なら critical**。C-3 で確定し
V-4 要否を決定。

### D-3（info）: F1 との統合
#239 問題3 プリフライトは F1 capability preflight と同一ゲート。S1 で F1
記述を確認し**統合（重複定義禁止）**。plan に明記済み。

### 推奨
D-1（境界表現+検出主体）と D-2（mode）を C-3 意思決定に。F1 整合は S1 で吸収。
