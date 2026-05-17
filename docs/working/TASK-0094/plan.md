# EXECUTION PLAN — TASK-0094 / #204 PBI-HI-011

## Goal
ハーネス変更の regression detection 用に代表 fixture suite を固定し、
#196 eval comparison の比較対象を安定化する。

## Constraints / Non-goals
- 完全自動実行エンジン / 全 provider 網羅 / 外部 benchmark 互換 /
  LLM judge 採点 / performance benchmark は実装しない。
- #196 の eval-comparison.schema.json を変更しない（補完のみ）。

## Approach Overview
examples/eval-fixtures/ に 8 fixture（各 fixture.md 固定フォーマット）→
plangatebench.md 正本（一覧/接続/整合/追加ルール/Non-goal）→ eval-runner.md
に PlanGateBench 連携注記。

## Work Breakdown
| Step | Output | Owner | Risk | 🚩 |
|------|--------|-------|------|----|
| S1 | examples/eval-fixtures/** 8 fixture | agent | 低 | 🚩 AC1-4 |
| S2 | docs/ai/plangatebench.md 正本 | agent | 中 | 🚩 AC5-7 |
| S3 | eval-runner.md 接続注記 | agent | 低 | 🚩 AC5 |

## Files / Components to Touch
- examples/eval-fixtures/**（新規 8 dir）
- docs/ai/plangatebench.md（新規・正本）
- docs/ai/eval-runner.md（注記追記）

## Testing Strategy
- Verification: AC1-7 を grep 構造突合（fixture 数 / 各 fixture の必須
  セクション / scope・approval・verification 含有 / plangatebench 追加ルール
  / #196 schema 非変更確認）。
- Unit/E2E: 該当なし（fixture 定義 + docs、実行系なし）。

## Risks & Mitigations
- #196 矛盾 → schema 非変更・補完位置付けを plangatebench §5 に明記
- Non-goal 侵食 → 各 fixture.md に「非実行・記述固定」注記
- fixture 重複 → 追加ルール §6 で eval focus 非重複を必須化

## Questions / Unknowns
なし

## Mode判定
**モード**: standard
**判定根拠**:
- 変更ファイル数: 10（8 fixture + 2 docs）→ 高寄りだが定型・低リスク
- 受入基準数: 7 → 中
- 変更種別: feat（fixture suite + 正本 docs）→ 中
- リスク: 中（#196 整合・Non-goal 境界）
- **最終判定**: standard（V-3 外部レビュー実施）
