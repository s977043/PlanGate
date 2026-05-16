---
task_id: TASK-0075
artifact_type: plan
schema_version: 1
status: draft
---

# EXECUTION PLAN — TASK-0075 opt-in 終端 Retro フェーズ（F4）

## Goal

run 完了時に振り返りドラフトを自動生成し改善ネタを append-only 蓄積する
opt-in 終端フェーズ R を定義する。承認境界（人間 confirm/skip）は維持。

## Constraints / Non-goals

- 既定 OFF / opt-in 限定（強制発火・既定 ON は禁止＝#228 設計と衝突回避）
- 自動はドラフトのみ・確定は人間（承認境界撤廃しない）
- スコアリング禁止（#231 judge と責務非重複）
- #228 テンプレ再定義しない（参照のみ）。#200 本体実装は Non-goal
- 強制 Hook は追加しない（opt-in フェーズ定義のソフト導入）

## Approach Overview

1. 終端フェーズ R の workflow 定義（新 doc）+ execution-sequence/README 反映
2. opt-in 起動正本（明示フラグ・既定 OFF・発火条件）定義
3. improvement-seeds.md 配置・append-only スキーマ定義
4. #228（5項目テンプレ参照）/ #200（集計入力接続点）への参照定義
5. 既定 OFF で既存 run 挙動不変を回帰確認

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 |
|------|------|--------|-------|------|----|
| S1 | 現状調査: workflow 定義群 / execution-sequence / #228 #200 参照点 | 調査メモ | agent | low | - |
| S2 | opt-in フラグ形 + seeds スキーマ粒度の意思決定 → C-3 | design note | agent | med | 🚩C-3判断 |
| S3 | 終端フェーズ R workflow 定義新設（目的/入力/完了条件/呼ぶSkill/主担当）| 06_retro.md | agent | high | 🚩AC-1,5 |
| S4 | opt-in 起動正本 + 既定OFF を定義（フェーズ定義 + 接続箇所） | 定義差分 | agent | high | 🚩AC-2 |
| S5 | improvement-seeds.md 配置/append-only スキーマ定義 | schema/spec | agent | med | 🚩AC-4 |
| S6 | #228 参照（5項目・スコアリングなし）/ #200 接続点定義 | 参照差分 | agent | low | 🚩AC-3,6,7 |
| S7 | execution-sequence/README 反映 + 既定OFF 回帰 | doc 差分 | agent | med | 🚩AC-8 |
| V | V-1 / V-3（high-risk: Codex+Gemini） | レビュー | agent | high | - |

## Files / Components to Touch（S1 確定）

- `docs/workflows/06_retro.md`（新設・終端フェーズ R 定義）
- `docs/workflows/execution-sequence.md` / `docs/workflows/README.md`（反映）
- `docs/ai/retro-phase.md` or 既存 ai doc（opt-in 正本 + seeds スキーマ、S1 確定）
- `.claude/rules/working-context.md`（improvement-seeds.md の役割追記）
- 既存 #228/#200 参照ドキュメント（接続点）

## Testing Strategy

- 構造検証: フェーズ R 定義に必須セクション（目的/入力/完了条件/Skill/主担当）が grep で存在
- opt-in: 既定（フラグ無し）で R が発火しない記述・既存 run 挙動不変を文書トレース
- スキーマ: improvement-seeds.md が append-only・run またぎ累積で定義
- 責務非重複: スコアリングしない（#231）・#228 再定義しない が明記
- 回帰: 既存 workflow 定義 / doc 整合性、hook テスト不変

## Risks & Mitigations

- R1: 既定 ON 化の誤解 → 「既定 OFF・opt-in 限定」を不変条件として明記
- R2: #228/#231/#200 と責務重複 → 各 Out of scope と参照関係を明記
- R3: workflow 終端変更が既存フロー破壊 → R は handoff 後の純追加・既定 OFF
- R4: opt-in フラグ未定義 Level 依存 → 本 PBI で opt-in フラグ正本化（Level 非依存）

## Questions / Unknowns

- ~~opt-inフラグ形~~ → **C-3確定: 明示コマンド `/ai-dev-workflow TASK-X retro` + pbi-input メタ `retro_enabled: true` の併用（env 不使用・既定OFF）**
- ~~seedsスキーマ粒度~~ → **C-3確定: 最小 `{date, task_id, items{5項目}, confirmed_by}` append-only**

## Mode判定

**モード**: high-risk

**判定根拠**:
- 変更ファイル数: 5-6 → 高
- 受入基準数: 8 → 高
- 変更種別: ワークフロー終端フェーズ追加（定義変更） → 高〜超高
- リスク: 高（フロー定義だが opt-in・既定OFF・純追加で影響限定）
- 例外: ワークフロー定義変更 → critical 相当だが opt-in/既定OFF/純追加で
  影響を限定でき high-risk に留める（C-3 で最終確定）
- **最終判定（C-3確定）**: **high-risk**（opt-in/既定OFF/純追加で影響限定）。V-3 必須・V-4 スキップ
