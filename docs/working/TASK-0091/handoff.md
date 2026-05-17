# Handoff — TASK-0091 / #213 PBI-PQ-001 Lightweight Plan Quality Checks
## 1. 要件適合確認
| AC | 判定 |
|----|------|
| AC1 Plan/Risk/Done Check 責務文書化 | PASS (T1) |
| AC2 出力構造定義（missing/risks/assumptions/done/next）| PASS (T2) |
| AC3 Plan Health Score 最小内訳 | PASS (T3, V-3 mn-2 で required 化) |
| AC4 AI 出力が JSON として扱える | PASS (T4) |
| AC5 軽量 Check 手動実行 | PASS (T5, CLI --init/--validate) |
| AC6 Plan 状態として保存方針 | PASS (T6) |
| AC7 heavy Gate/PR review/browser QA 非依存 | PASS (T7) |
| AC8 gstack 参考思想留め・直接移植しない | PASS (T8) |
V-1 全 PASS。V-3（Codex）critical 0 / major 3 / minor 2 → 全反映・回帰 PASS。
## 2. 既知課題
- CLI は scaffold(--init)/validate(--validate) のみ。AI による自動 Check 生成は
  skill 経由の手動運用（heavy 化回避のため意図的）。
## 3. V2 候補
- `plan-check` の AI 自動生成モード（skill 連携・opt-in、heavy 化に注意）。
- status.md/current-state.md からの plan-quality-check.json 自動参照表示。
- Gate/Review/QA/Release 判定への拡張（本 PBI は土台のみ・Non-goal）。
## 4. 妥協点
- CLI に AI 実行を内蔵しない（軽量・heavy Gate 非依存の AC 優先）。判定は助言で
  人間承認の代替にしない（承認境界不変）。
## 5. 引き継ぎ
#213 を standard で実装。schema + skill(Rule2準拠) + 正本 doc + 軽量 CLI
(plan-check --init/--validate) + schema_mapping 登録。V-3 で enum 統一/雛形
decision 整合/CI schema 健全性検証ステップ/Rule2 gate名除去/score_breakdown
required を修正。次は #196 Harness Eval expansion。
## 6. テスト結果
V-1: T1-T8 + E1/E2 全 PASS。V-3 反映後回帰全 PASS。CLI --validate PASS・
workflow step 実機シミュレーション成功。
