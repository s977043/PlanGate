# TASK-0031 EXECUTION PLAN

## Goal

TASK-0029/0030 で構築したスキル基盤（Intent Classifier, Skill Policy Router, Evidence Ledger）を
ユーザーが直接呼び出せる軽量コマンド UX として実装する。
`/pg-think`, `/pg-hunt`, `/pg-check`, `/pg-verify` の 4 コマンドを提供し、
plugin.json を v0.3.0 に更新する。

## Constraints / Non-goals

- コマンドファイルには TASK 番号を含めない（Rule 2 準拠）
- Markdownlint に通る Markdown
- subagent 自動実行・PR 自動作成・GitHub Actions 連携は対象外
- `main` への直接コミット禁止

## Approach Overview

1. 既存 `ai-dev-workflow.md` の形式を踏襲したコマンドファイルを 4 件作成
2. 各コマンドに Iron Law・出力フォーマット・GatePolicy 連携を明記
3. plugin.json を 0.2.0 → 0.3.0 に更新
4. working context ファイル群を整備

## Work Breakdown

| Step | Output | Owner | Risk | Checkpoint |
|------|--------|-------|------|-----------|
| 1. pg-think.md 作成 | `plugin/plangate/commands/pg-think.md` | agent | 低 | ファイル存在確認 |
| 2. pg-hunt.md 作成 | `plugin/plangate/commands/pg-hunt.md` | agent | 低 | Iron Law 明記確認 |
| 3. pg-check.md 作成 | `plugin/plangate/commands/pg-check.md` | agent | 低 | Severity 定義確認 |
| 4. pg-verify.md 作成 | `plugin/plangate/commands/pg-verify.md` | agent | 低 | EvidenceLedger JSON 確認 |
| 5. plugin.json 更新 | `plugin/plangate/.claude-plugin/plugin.json` | agent | 低 | version=0.3.0 確認 |
| 6. working context 整備 | `docs/working/TASK-0031/` 各ファイル | agent | 低 | 全ファイル存在確認 |
| 7. 受入基準 5 件自己突合 | — | agent | 低 | 全 PASS 確認 |
| 8. git commit | feature/task-0031-pg-commands | agent | 低 | コミット SHA 確認 |

## Files / Components to Touch

- `plugin/plangate/commands/pg-think.md` （新規）
- `plugin/plangate/commands/pg-hunt.md` （新規）
- `plugin/plangate/commands/pg-check.md` （新規）
- `plugin/plangate/commands/pg-verify.md` （新規）
- `plugin/plangate/.claude-plugin/plugin.json` （更新）
- `docs/working/TASK-0031/pbi-input.md` （新規）
- `docs/working/TASK-0031/plan.md` （新規）
- `docs/working/TASK-0031/todo.md` （新規）
- `docs/working/TASK-0031/test-cases.md` （新規）
- `docs/working/TASK-0031/INDEX.md` （新規）
- `docs/working/TASK-0031/current-state.md` （新規）
- `docs/working/TASK-0031/handoff.md` （新規）

## Testing Strategy

- Unit: なし（コマンドファイルはドキュメント）
- Integration: なし
- E2E: なし
- Verification: 受入基準 5 件の自己突合（ファイル存在・内容確認）

## Risks & Mitigations

| リスク | 対策 |
|-------|------|
| Markdown lint 違反 | コードブロック・見出しレベル・空行を既存ファイルに合わせる |
| plugin.json 破損 | 既存内容を Read してから Edit する |

## Questions / Unknowns

なし

## Mode 判定

**モード**: `light`

**判定根拠**:

- 変更ファイル数: 12 → standard（ただし全てドキュメント・設定ファイル）
- 受入基準数: 5 → standard
- 変更種別: ドキュメント追加 + 設定更新 → light 相当
- リスク: 低（ロジックコードなし）
- **最終判定**: `light`（ドキュメント追加のみのため、定性基準を優先）
