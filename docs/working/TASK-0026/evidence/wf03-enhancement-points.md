# TASK-0026 WF-03 深化ポイント

> 作成日: 2026-04-20

## #23 で作成された WF-03 基盤（深化前）

`docs/workflows/03_solution_design.md` には以下がある:
- 目的
- 入力
- 完了条件（6 項目）
- 呼び出す Skill（architecture-sketch, risk-assessment）
- 主担当 Agent（solution-architect, orchestrator）
- 次 phase への引き継ぎ（基本情報のみ）

## TASK-0026 での深化内容

### 1. 次 phase への引き継ぎ詳細化

**深化前**:
- artifact クラス: design
- 受け取り先: WF-04

**深化後**:
- 配置先明示: `docs/working/TASK-XXXX/design.md`
- テンプレート参照: `docs/working/templates/design.md`
- 含まれる 7 要素を明示

### 2. plan.md との役割分担追記

PlanGate 既存の `plan.md` と新設の `design.md` の役割分担表を追加:
- 主目的
- 出力者
- 変化頻度
- 対象読者

### 3. 挿入位置図への導線

`docs/workflows/plangate-insertion-map.md` への参照を追加。

## 新規成果物

- `docs/working/templates/design.md` — 7 要素テンプレート
- `docs/workflows/plangate-insertion-map.md` — A→B→WF-03→C-1〜D の挿入位置
- `docs/working/TASK-0026/evidence/sample-design.md` — TASK-0023 を題材としたサンプル

## Rule 1 遵守確認

`03_solution_design.md` の深化は以下を守る:
- 実装ノウハウ非混入（具体コード例なし）
- phase 5 要素（目的/入力/完了条件/呼び出し Skill/主担当 Agent）を維持
- 追加は「次 phase への引き継ぎ詳細化」「plan.md との役割分担」のみで、5 要素に影響しない

✅ Rule 1 遵守
