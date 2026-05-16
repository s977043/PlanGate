---
task_id: TASK-0073
artifact_type: test-cases
schema_version: 1
status: draft
---

# テストケース定義 — TASK-0073

| AC | TC |
|----|----|
| AC-1 | TC-1 |
| AC-2 | TC-2, TC-3 |
| AC-3 | TC-4 |
| AC-4 | TC-5, TC-6 |
| AC-5 | TC-7 |
| AC-6 | TC-8 |
| AC-7 | TC-9 |

## テストケース
- **TC-1**: 委譲タスクに commit/push 境界宣言の構造化フィールドが定義（仕様/テンプレ検証）
- **TC-2**: 委譲境界=「commit禁止」宣言下で commit 発生 → 機械検出が非0/違反記録
- **TC-3**: 境界宣言なし → 従来動作（検出は発火しない・誤検出なし）
- **TC-4**: exec 前プリフライトで git 操作主体未定義 → 停止 or 明示降格
- **TC-5**: 認証三点（gh auth / git config user / remote）整合 → プリフライト PASS
- **TC-6**: 認証不整合（例: gh active ≠ 期待）→ exec 前に検出・停止
- **TC-7**: core-contract/execute.md にプリフライト不変条件が存在し §5-bis と整合
- **TC-8**: 違反/不整合時の出力が決定論的（理由文字列つき・自然言語依存でない）
- **TC-9**: 既存 hook テスト全 green + doc 整合性回帰なし

## エッジケース
- E1: 境界宣言ありだが commit が「親フェーズの正規 commit」→ 検出対象外（主体で判別）
- E2: PLANGATE_BYPASS_HOOK との優先順（既存 hook 慣行に従う）
- E3: 認証プリフライトは F1 capability preflight と同一ゲートで順序定義（重複排除）
- E4: settings wiring 必要時は Claude 適用不可 → 手動手順を handoff（TASK-0070 教訓）
