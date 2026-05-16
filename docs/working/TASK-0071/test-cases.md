---
task_id: TASK-0071
artifact_type: test-cases
schema_version: 1
status: draft
---

# テストケース定義 — TASK-0071

## 受入基準 → テストケース

| AC | TC |
|----|----|
| AC-1 | TC-1 |
| AC-2 | TC-2, TC-3 |
| AC-3 | TC-4, TC-5 |
| AC-4 | TC-6, TC-7 |
| AC-5 | TC-8, TC-9 |
| AC-6 | TC-10, TC-11 |
| AC-7 | TC-12 |
| AC-8 | TC-13 |

## テストケース

- **TC-1**: settings 変更要 TASK で AI 出力に「パッチ + 検証テスト」が揃う（成果物検査）
- **TC-2**: wiring 適用済み環境で `doctor --check-settings` → exit 0 / PASS
- **TC-3**: wiring 未適用環境で `doctor --check-settings` → 非0 / FAIL + 対象明示
- **TC-4**: settings 未適用のまま handoff 完了試行 → ブロック（タスクロック作動）
- **TC-5**: settings 適用後は handoff 完了可（ロック解除）
- **TC-6**: CI drift check — wiring 未適用 PR → required check failure
- **TC-7**: CI drift check — model-profile.schema 不整合 → failure
- **TC-8**: EH-3 メンテモード有効時、heredoc なしで通常 Edit が継続可
- **TC-9**: メンテモード有効期限切れ → 自動的に通常強制へ復帰
- **TC-10**: SKIP 発生時 SKIP_REASON が機械可読で監査ログ/todo に残る
- **TC-11**: SKIP_REASON 未記述で SKIP しようとすると要記述で停止
- **TC-12**: 責務 4 分類が rules 正本に存在し機械検出可能（grep）
- **TC-13**: 既存 hook テスト 60 件 + 新規が全 green（回帰なし）

## エッジケース

- E1: メンテモード中でも plan.md は依然 BLOCK（C-3 ハッシュ強制は不変）
- E2: PLANGATE_BYPASS_HOOK との優先順位（bypass > メンテモード > 通常）
- E3: doctor --check-settings は settings 不在/壊れ JSON で安全側 FAIL
- E4: タスクロックは critical インシデント時の事後追補例外と整合
