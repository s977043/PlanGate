# EXECUTION PLAN — TASK-0098 / #200 PBI-HI-006

## Goal
実利用シグナルを期間集計し retrospective 貼付 Markdown + 次改善 PBI 候補
抽出指針を生成（決定論・advisory・承認境界不変）。

## Constraints / Non-goals
- Web dashboard / 外部 BI / 自動投稿 / LLM judge hard gate / C-3・C-4 緩和
  はしない。
- events.ndjson 非依存（ローカル artifact 集計）。keep-rate は任意入力。

## Approach Overview
reporting.py（c3/c4/eval-result/keep-rate-result/status を期間集計、Markdown
+JSON）→ bin/plangate report → reporting.md 正本 → retrospective-template.md
（harness improvement 用の問い + 次 PBI 候補抽出方針）。

## Work Breakdown
| Step | Output | Owner | Risk | 🚩 |
|------|--------|-------|------|----|
| S1 | scripts/reporting.py | agent | 中 | 🚩 AC1/2/3/6 |
| S2 | bin/plangate report | agent | 低 | 🚩 AC1 |
| S3 | docs/ai/reporting.md 正本 | agent | 低 | 🚩 AC4/6 |
| S4 | retrospective-template.md | agent | 低 | 🚩 AC5 |

## Files / Components to Touch
- scripts/reporting.py（新規）
- bin/plangate（cmd_report + dispatch + help）
- docs/ai/reporting.md（新規・正本）
- docs/working/templates/retrospective-template.md（新規）

## Testing Strategy
- Verification: AC1-6 を smoke（期間指定 report 生成・集計値・PBI 候補節）+
  grep 構造突合 + ast/sh -n + fix_loop 誤マッチ非再現。
- Unit/E2E: 該当なし（決定論集計・外部連携なし）。

## Risks & Mitigations
- fix_loop 誤マッチ → 1-2桁・非日付・上限50（smoke で 0 化確認済）
- keep-rate 前方参照 → 任意入力・無ければ '-'（#198/PR#272 依存明記）
- ゲート誤用 → advisory/C-3・C-4 非緩和を doc/出力/テンプレに明記

## Questions / Unknowns
なし

## Mode判定
**モード**: standard
**判定根拠**:
- 変更ファイル数: 4 → 中
- 受入基準数: 6 → 中
- 変更種別: feat（集計 script+CLI+正本+テンプレ）→ 中
- リスク: 中（集計ヒューリスティック・承認境界注意）
- **最終判定**: standard（V-3 外部レビュー実施）
