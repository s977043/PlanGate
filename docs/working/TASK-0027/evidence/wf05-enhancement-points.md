# TASK-0027 WF-05 深化ポイント

> 作成日: 2026-04-20

## #23 で作成された WF-05 基盤（深化前）

`docs/workflows/05_verify_and_handoff.md` には以下がある:
- 目的
- 入力
- 完了条件（5 項目）
- 呼び出す Skill（acceptance-review, known-issues-log）
- 主担当 Agent（qa-reviewer, orchestrator）
- 次 phase への引き継ぎ

## TASK-0027 での深化内容

### 1. 次 phase への引き継ぎ詳細化

**深化前**:
- artifact クラス: handoff

**深化後**:
- 配置先明示: `docs/working/TASK-XXXX/handoff.md` 固定
- テンプレート参照: `docs/working/templates/handoff.md`
- 6 要素を明示

### 2. 役割分担追記（status / current-state / handoff）

3 ファイルの役割分担表を追加。

### 3. V-1 との関係明示

PlanGate V-1 受け入れ検査と WF-05 handoff の関係を表で明示:
- V-1 = 実装ゲート（PASS/FAIL 判定）
- WF-05 = 完了後の資産化（handoff package）
- 両者は並立（役割が異なる）

### 4. Skill 連携詳細

`acceptance-review` / `known-issues-log` の出力が handoff のどの章に反映されるかを明示。

## 新規成果物

- `docs/working/templates/handoff.md` — 6 要素テンプレート（命名規約明記）
- `docs/working/TASK-0027/evidence/sample-handoff.md` — TASK-0017 題材のサンプル
- `.claude/rules/working-context.md` に handoff 節追加（全 PBI 必須のルール化）

## Rule 1 遵守確認

`05_verify_and_handoff.md` の深化は以下を守る:
- 実装ノウハウ非混入
- phase 5 要素（目的/入力/完了条件/呼び出し Skill/主担当 Agent）を維持
- 追加は「引き継ぎ詳細化」「役割分担」「V-1 関係」「Skill 連携」のみで、5 要素に影響しない

✅ Rule 1 遵守

## Rule 5 との関連

Rule 5: 最終成果物は毎回 handoff に集約する。仕様 / 既知課題 / V2 候補 / 確認結果を残す。

本 TASK で以下を達成:
- handoff.md テンプレに 6 要素を明文化（仕様 / 既知課題 / V2 候補 / 確認結果 + 妥協点 + テスト結果）
- `.claude/rules/working-context.md` で「全 PBI 必須」ルール化
- 既存 status.md / current-state.md との役割分担を明示

TASK-0028 で Rule 5 の統合ルールとして v7 ドキュメントに記載予定。
