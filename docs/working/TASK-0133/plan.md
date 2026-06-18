# EXECUTION PLAN — TASK-0133 (#567)

## Goal
brainstorm の不採用案理由を decision-log に構造化記録できるよう、`alternatives_rejected` を additive 追加し、記録規約を brainstorming skill に定める。後方互換を維持。

## Constraints / Non-goals
- additive のみ（alternatives string[] は不変）。
- schemas/ に JSON 実体を作らない（markdown 正本維持）。
- 全 mode 必須化しない。
- #565 / #566 と独立。

## Approach Overview（Codex 設計相談）
1. `decision-log-schema.md` に `alternatives_rejected:[{option,rationale}]`（任意）を追加 + サンプル + type 整理。
2. brainstorming skill（**正本 `.agents/skills/`** + 3 ミラー同期）に「採用案決定時、不採用案を alternatives_rejected で記録。必須は high-risk/critical/human decision」を追記。
3. pbi-input Notes は decision-log への参照・要約に縮退する旨を規約化（正本=decision-log）。

## Work Breakdown
- **S1** decision-log-schema.md に alternatives_rejected を additive 追加（フィールド表 + サンプル + 後方互換注記）/ Owner: agent / Risk: 既存サンプルとの整合
- **S2** brainstorming skill（正本 `.agents/skills/` → `.claude/` `.codex/` `plugin/plangate/` 同期）に記録規約追記 / Owner: agent / Risk: 既存手順との重複・ミラー drift
- **S3** pbi-input テンプレ/規約に Notes 縮退（正本=decision-log）を明記 / Owner: agent / Risk: 既存運用との齟齬

## Files / Components to Touch
- `docs/working/templates/decision-log-schema.md`（AI 可・HO 外）
- `.agents/skills/brainstorming/SKILL.md`（**正本**・AGENTS.md 準拠）+ ミラー `.claude/` `.codex/` `plugin/plangate/`（AI 可・skills は override 外）
- `docs/working/templates/pbi-input.md`（**存在を T1 で確認**。無ければ `.claude/rules/working-context.md`（**正本**・実在。ミラー `plugin/plangate/rules/working-context.md` も同内容で実在）の pbi-input 記述箇所へ fallback。fallback 先は T4 で確定 / AI 可）

## Testing Strategy
- 機械: schema に `alternatives_rejected` の grep、既存フィールド名が全て残ることの grep、サンプル JSON が jq でパース可能
- レビュー: 後方互換（旧エントリが valid）、必須条件が mode-classification と矛盾しない
- markdownlint

## Risks & Mitigations（内容 / 検証手段 / Fallback）
- R1 既存 decision-log 資産が無効化 / 任意フィールド + jq parse 検証 / 破壊が出たら additive に戻す
- R2 記録規約が儀式化 / 必須を high-risk/critical/human のみに限定 / 過負荷なら任意へ緩和
- R3 Notes と decision-log の二重管理 / 正本=decision-log を明記し Notes は参照化 / 齟齬時は decision-log 優先

## Metrics Evidence
- 対象「変更ファイル」: 実数 2-3（schema + brainstorming skill + pbi-input 規約）/ 見積もり 3 / ratio 1.0 → 採用。

## Questions / Unknowns
- rationale の粒度 → 初回は自由文 string。構造化は将来。

## Mode判定

**モード**: standard

**判定根拠**:
- 変更ファイル数: 2-3 → standard
- 受入基準数: 4 → standard
- 変更種別: スキーマ additive 変更（内部・非破壊）→ standard
- 影響範囲: decision-log 記録 + brainstorm 運用 → 限定的
- **最終判定**: standard。ただし「スキーマ変更」に該当するため working-context autonomous APPROVE マトリクスにより **autonomous APPROVE 不可・人間 C-3 同期**（安全側）。HO 対象外（templates/ + .claude/skills/）のため exec は AI 可。
