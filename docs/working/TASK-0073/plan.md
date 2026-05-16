---
task_id: TASK-0073
artifact_type: plan
schema_version: 1
status: draft
---

# EXECUTION PLAN — TASK-0073 exec 強制力ギャップ（F2）

## Goal

委譲先の commit/push 境界をツール/検出レベルで強制し、exec 前に git 操作主体・
認証整合をプリフライト検証する。自然言語依存の禁止指示を決定論的ガードへ。

## Constraints / Non-goals

- F1（TASK-0072 委譲ケイパビリティ）と整合（同一プリフライト層に統合）
- 未宣言の委譲は従来動作（誤検出で正常 commit を阻害しない）
- sockpuppet 検出の新規実装はしない（既存運用ルール踏襲）
- core-contract の Iron Law は弱めない（追加強制のみ）

## Approach Overview

1. 委譲 commit 境界の構造化宣言仕様を定義（todo.md / 委譲規約のどこに置くか）
2. 違反検出を決定論化（PreToolUse Hook on git or exec 後検証）
3. exec 前プリフライト・ゲートに git 主体 + 認証三点検査を追加（F1 と統合）
4. core-contract / execute.md にプリフライト不変条件を追記（§5-bis 整合）

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 |
|------|------|--------|-------|------|----|
| S1 | 現状調査: 委譲規約所在 / 既存 git hook / 認証三点の既存記述 / F1 プリフライト記述 | 調査メモ | agent | low | - |
| S2 | 委譲 commit 境界の構造化表現 + 検出主体の意思決定 → C-3 上申 | design note | agent | high | 🚩C-3判断 |
| S3 | 委譲境界宣言仕様を定義（規約 + テンプレ） | 仕様差分 | agent | med | 🚩AC-1 |
| S4 | 違反検出の実装（Hook or 検証ステップ・S2 決定に従う） | 検出機構 | agent | high | 🚩AC-2 |
| S5 | exec 前プリフライトに git 主体 + 認証三点を追加（F1 と統合） | router/contract 差分 | agent | high | 🚩AC-3/AC-4 |
| S6 | core-contract / execute.md プリフライト不変条件追記 | contract 差分 | agent | crit | 🚩AC-5 |
| S7 | 回帰（hook テスト / doc 整合）+ 決定論性確認 | テスト結果 | agent | med | 🚩AC-7 |
| V | V-1 / V-3(Codex+Gemini) / V-4(critical時) | レビュー | agent | high | - |

## Files / Components to Touch（S1 で確定）

- `docs/ai/core-contract.md`（プリフライト不変条件・§5-bis 隣接）
- `docs/ai/contracts/execute.md`（プリフライト・ゲート拡張）
- `.claude/commands/ai-dev-workflow.md`（exec router プリフライト統合）
- `scripts/hooks/`（git commit 境界検出 Hook、S2 で要否確定）
- `.claude/settings*.json`（Hook wiring → ユーザー手動の可能性: TASK-0070 教訓）
- `tests/hooks/run-tests.sh`（検出 Hook の回帰）

## Testing Strategy

- 決定論性: 同一入力で同一判定（委譲境界宣言あり/なし × commit 有無のマトリクス）
- Hook: 予期しない commit を検出し非0、宣言なしは従来動作
- プリフライト: 認証不整合シナリオで exec 前停止を文書/テストでトレース
- 回帰: 既存 hook テスト全 green、doc 整合性
- F1 整合: §5-bis と矛盾しないことを grep + レビュー

## Risks & Mitigations

- R1: commit 検出の誤検出 → 委譲境界は明示宣言必須、未宣言は従来動作
- R2: settings wiring が必要なら Claude 適用不可（TASK-0070 教訓）→ AC を
  「仕様 + ユーザー手動適用手順」に分解、handoff に明記
- R3: F1 と二重定義 → S1 で F1 プリフライト記述を確認し統合（重複排除）
- R4: critical 化（core-contract 連続変更）→ S6 を最小・§5-bis 参照型に

## Questions / Unknowns

- ~~委譲境界の構造化表現と検出主体~~ → **C-3確定: 表現=todo.md 委譲タスクのメタフィールド / 検出=PreToolUse Hook on git（決定論100%強制）+ exec後検証ステップ の二段**
- ~~settings wiring 要否~~ → **C-3確定: Hook 採用のため wiring 必要。Claude 適用不可（TASK-0070 教訓）→ AC を「Hook script(Claude) + wiring 手順(ユーザー手動)」に分解、handoff 明記**

## Mode判定

**モード**: high-risk（条件付き critical）

**判定根拠**:
- 変更ファイル数: 5-6 → 高
- 受入基準数: 7 → 高
- 変更種別: 強制力レイヤ追加 + core-contract 追記 → 高〜超高
- リスク: 高（誤検出が正常作業阻害。F1 整合必須）
- 例外: セキュリティ/強制力関連 → 最低中、core-contract 追記含むため
- **最終判定（C-3確定）**: **high-risk**（core-contract は §5-bis 参照型の最小追記に留める）。V-3 必須・V-4 スキップ
