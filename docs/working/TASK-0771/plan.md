# EXECUTION PLAN — TASK-0771: ai-loop を plangate プラグインに同梱配布（issue #771）

## Goal

他プロジェクトで ai-loop-workflow を検証できるよう、既存 plangate プラグインに
ai-loop の正本 docs・裁定エンジン・skill を同梱する（Human 設計決定: 同梱 / scaffold なし）。

## Constraints / Non-goals

- 正本は現行位置（docs/workflows/ai-loop 等）のまま。plugin は sync による配布コピー
  （一方向性の維持 — #737/#758 と同じ構造）
- run 記録・摩擦台帳は配布しない。バージョン bump / リリースは別途（次回リリース同梱）
- PlanGate 本番ゲートとの統合変更なし

## Work Breakdown

| # | Step | Output | Risk |
|---|------|--------|------|
| 1 | 配布版 skill 正本の新設 | `.agents/skills/ai-loop-cycle/SKILL.md`（固有パス抽象化・台帳/run 記録は導入先定義と明記） | Rule 2 違反残り → AC-3 で機械検出 |
| 2 | sync スクリプト拡張 | `scripts/sync-plugin-plangate.sh` に ai-loop docs（workflows 10 本 + ai/ai-loop 思想層）→ `plugin/plangate/docs/ai-loop/`、`scripts/ai-loop/{arbiter,test_arbiter}.py` → `plugin/plangate/scripts/ai-loop/` の同期を追加。ho-paths.md はコピー時に雛形注記ヘッダを前置 | 既存 sync 対象への回帰 → dry-run 差分で検証 |
| 3 | plugin README へ ai-loop 節 | 導入手順・適用境界（低リスク帯限定・HITL/HOTL 前提・PlanGate 本番非適用） | — |
| 4 | sync 実行（plugin 生成） | plugin/plangate/{docs,scripts,skills} の生成コピー | 🚩 実 sync は C-3 承認範囲に含めて実行 |
| 5 | 検証 | plugin 配下で `python3 plugin/plangate/scripts/ai-loop/test_arbiter.py` 全 PASS / Rule 2 grep / CI sync 品質ガード | — |

## Files to Touch

手書き 3（.agents skill 新設 / sync スクリプト / plugin README）+ sync 生成コピー（docs ~14 + scripts 2 + skill 1）

## Testing Strategy

- AC-1: `sh scripts/sync-plugin-plangate.sh --dry-run` が ai-loop 対象を WOULD COPY 表示
- AC-2: `python3 plugin/plangate/scripts/ai-loop/test_arbiter.py` 全 PASS（自立実行）
- AC-3: `grep -RlE 'docs/working/|run-001-frictions' plugin/plangate/skills/ai-loop-cycle/` → 0 件（Rule 2）
- AC-4: plugin 版 ho-paths 相当の冒頭に雛形注記（固定句「導入先で確定」）
- AC-5: CI（plugin sync 品質ガード含む）全 green

## Mode 判定

**high-risk**（手書き 3 + 生成 ~17 ファイル・新配布面）→ **人間 C-3 必須**（autonomous APPROVE 対象外）

## Risks & Mitigations

- 配布版 skill の抽象化漏れ → AC-3 機械検出 + レビュー
- sync 拡張の既存対象への回帰 → dry-run 差分の全件目視 + CI ガード
- plugin 利用側での HO 未定義 → ho-paths 雛形注記（未確定なら arbiter は安全側 escalate、の原則を注記に明記）
