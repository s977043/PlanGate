---
task_id: TASK-0078
artifact_type: plan
schema_version: 1
status: draft
---

# EXECUTION PLAN — TASK-0078 F2 §5-bis 統合

## Goal

execute.md の F2 暫定プリフライト節を core-contract §5-bis 単一正本へ移設
統合し、二重定義を排除する。挙動・スクリプトは不変（参照集約のみ）。

## Constraints / Non-goals

- スクリプト/Hook 挙動変更しない（EH-9/auth-preflight/commit-boundary 不変）
- 情報無損失（execute.md F2 本文の内容は §5-bis へ完全移動・要約しない）
- core-contract の他 Iron Law/節は触らない
- #203/#251/TASK-0071 は Non-goal

## Approach Overview

1. core-contract §5-bis を「実行環境不変条件 + exec 前プリフライト正本」に
   拡張（capability 既存 + F2 の認証三点/commit境界/EH-9/配線契約/exec後検証/
   delegation_unavailable taxonomy を統合配置）
2. execute.md の §9/§28/Error taxonomy 重複本文を削除、§5-bis 参照に置換
3. execute.md 暫定統合ノート（57-59）削除、Stop rules は exec 文脈で簡潔保持
4. F2(TASK-0073) handoff 既知課題を「統合完了」に更新
5. 回帰確認（hook 78/0 不変・doc 整合・スクリプト diff ゼロ）

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 |
|------|------|--------|-------|------|----|
| S1 | §5-bis と execute.md の重複箇所マッピング（情報無損失確認） | 対応表 | agent | low | - |
| S2 | core-contract §5-bis 拡張（F2 内容を統合配置） | core-contract 差分 | agent | high | 🚩AC-1 |
| S3 | execute.md 重複削除→§5-bis 参照化（§9/§28/taxonomy/ノート） | execute.md 差分 | agent | high | 🚩AC-2,3,5 |
| S4 | F2 handoff 既知課題更新 | handoff 差分 | agent | low | 🚩AC-7 |
| S5 | 回帰: hook 78/0・スクリプト diff ゼロ・doc 整合・参照切れなし | テスト結果 | agent | med | 🚩AC-4,6 |
| V | V-1 / V-3（standard: Codex+Gemini） | レビュー | agent | med | - |

## Files / Components to Touch

- `docs/ai/core-contract.md`（§5-bis 拡張）
- `docs/ai/contracts/execute.md`（重複削除・参照化）
- `docs/working/TASK-0073/handoff.md`（既知課題→解消更新）
- 変更しない（確認のみ）: scripts/hooks/check-{auth-preflight,delegation-commit-boundary,plan-hash}.sh

## Testing Strategy

- 情報無損失: S1 対応表で execute.md F2 全項目が §5-bis に存在することを突合
- 参照整合: execute.md → §5-bis リンク・§5-bis 内リンクが切れていない（grep）
- スクリプト不変: `git diff main -- scripts/hooks/` が空
- 回帰: hook テスト 78 passed/0 failed（挙動不変）
- doc lint: 変更ファイルが CI lint スコープなら 0 error

## Risks & Mitigations

- R1: 情報欠落 → S1 対応表で 1:1 移設を機械突合、欠落ゼロを AC-1 検証
- R2: 参照切れ → §5-bis アンカー名固定、execute.md からの相対リンク検証
- R3: core-contract 正本破壊 → §5-bis 節内のみ編集、他節 diff ゼロを確認

## Questions / Unknowns

- なし（F2 handoff で統合方針確定済。S1 で対応表作成のみ）

## Mode判定

**モード**: standard

**判定根拠**:
- 変更ファイル数: 3（core-contract/execute.md/handoff） → 中
- 受入基準数: 7 → 高だがコード変更なし・情報移設主体
- 変更種別: governance 正本のドキュメント refactor（挙動不変） → 中
- リスク: 中（core-contract 触るが §5-bis 節内・スクリプト不変）
- 例外: 強制力ドキュメント正本 → 最低中
- **最終判定**: standard（V-3 実施・V-2/V-4 スキップ）
