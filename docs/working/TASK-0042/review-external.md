# C-2 外部AIレビュー結果 — TASK-0042 (PBI-116-04 / Issue #120) + Phase 2 統合

> 実施: 2026-04-30 / Codex CLI / `codex exec` 経由
> 入力: [`docs/working/PBI-116/_codex-c2-phase2.txt`](../PBI-116/_codex-c2-phase2.txt)
> 対象: 3 子 PBI（PBI-116-02 / 04 / 06）一括レビュー、本ファイルが統合判定の主体

## サマリ（全 3 PBI 統合）

| 区分 | 件数 |
|------|------|
| critical | 0 |
| major | **1** |
| minor | 2 |
| info | 1 |

**総合判定: WARN / Child C-3 推奨: CONDITIONAL（同 PR で全件対応済）**

## TASK-0042 (PBI-116-04 Structured Outputs) 観点別判定

| 観点 | 判定 | コメント |
|------|------|---------|
| 1. 要件適合性 | PASS | AC-1〜AC-6 は plan / TC で網羅 |
| 2. スコープ境界 | WARN | 既存 schema 互換性の対象が実リポジトリより狭い（5 件 → 12 件に拡張要） |
| 3. interface-preflight 準拠 | PASS | 02/06 の値域に依存しない設計 |
| 4. Phase 2 並行性 | PASS | 02/06 とファイル・schema namespace の直接競合なし |
| 5. テスト戦略 | WARN | 既存 review-* schema との重複確認が不足 |
| 6. リスク評価 | WARN | L1 mitigation が「既存 5 schema」前提で、実際の `schemas/` 全体をカバーしない |

## 指摘事項（major、本 PBI で最重要）

### EX-04-01 [major] 既存 review-self / review-external schema との互換性確認が計画に不足

- **該当**: `docs/working/TASK-0042/plan.md:13`, `:107`, `pbi-input.md:57`
- **内容**: 実リポジトリには `schemas/review-self.schema.json` / `schemas/review-external.schema.json` / `test-cases.schema.json` / `todo.schema.json` 等が既に存在する（合計 12 件 + README）。新規 `review-result.schema.json` は既存 review schema と責務重複し得るが、plan の既存保持対象は 5 件に限定されていた。
- **推奨**: AC-5 / TC-6 / forbidden 確認を「既存 `schemas/*.schema.json` 全件」に広げ、特に `review-self` / `review-external` との関係を `structured-outputs.md` に明記する。

## クロス PBI 観点

- **02 ↔ 06 接続**: 整合。共有値域 `narrow / allowed_tools_by_phase / expanded` と `lenient / normal / strict` は一致
- **04 独立性**: 確認。02/06 の tool_policy / validation_bias には依存しない
- **既存 schemas/ 互換性**: 改善要 → 同 PR で対応
- **Phase 3 前提機能**: 機能する（02 model profile / 06 tool policy boundary / 04 schema 方針が PBI-116-03 の入力として利用可能）

## Child C-3 推奨

3 PBI 一括は **CONDITIONAL** → 同 PR で EX-04-01 対応 → **APPROVE 候補**

## 同 PR での CONDITIONAL 対応

| ID | 対応 |
|----|------|
| EX-02-01（02）| ✅ TASK-0040 plan.md Q2 を構造化案 (`recommended_effort` + `allowed_efforts[]`) に修正 |
| EX-04-01（04, major）| ✅ TASK-0042 plan / pbi-input / test-cases で「既存 5 schema」→「全 12 schema」に拡張、`review-self` / `review-external` との責務境界を明記 |
| EX-06-01（06）| ✅ TASK-0041 plan Risk L1 mitigation を「02 完了前提」→「interface-preflight 値域を正、02 成果物があれば照合」に修正 |
| EX-06-02（06）| ✅ TASK-0041 plan の `clip relation` typo を `cross relation` に修正 |

→ 全 4 件対応済。3 PBI とも **Child C-3 APPROVE 候補**。

## 総合 Child C-3 推奨

3 PBI を一括 **APPROVE** 候補として提案。02 / 06 / 04 すべて exec フェーズへ進める準備完了。Phase 2 並行起動可能。
