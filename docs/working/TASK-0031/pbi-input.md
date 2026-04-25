# TASK-0031 PBI INPUT PACKAGE

## Context / Why

TASK-0029（Intent/Mode Classifier + Skill Policy Router）と TASK-0030（Evidence Ledger v1）が完了し、
ユーザーが日常的に使える軽量コマンド UX が不足している状態。
Waza 風の `/pg-*` コマンドを提供することで、ユーザーが直感的にワークフローの各フェーズを呼び出せるようにする。
Epic #53 Phase 1 の最後のピース。

関連 Issue: https://github.com/s977043/plangate/issues/56

## What（Scope）

### In scope

- `/pg-think`: 実装前の論点整理・設計整理コマンド
- `/pg-hunt`: バグ修正前の根本原因調査コマンド
- `/pg-check`: 差分レビュー・安全確認コマンド
- `/pg-verify`: 完了宣言前の証拠確認コマンド（Evidence Ledger 出力）
- `plugin/plangate/.claude-plugin/plugin.json` の version を 0.3.0 に更新

### Out of scope

- Superpowers 相当の full workflow 強制
- subagent 自動実行
- PR 自動作成
- GitHub Actions 連携
- コマンド間の自動連携フロー

## 受入基準

| ID | 基準 |
|----|------|
| AC-1 | ユーザーが `/pg-think`, `/pg-hunt`, `/pg-check`, `/pg-verify` を明示的に起動できる（コマンドファイルが存在する） |
| AC-2 | GatePolicy により必要スキルとして自動要求できる（`skill-policy-router` との連携が記述されている） |
| AC-3 | `/pg-verify` が Evidence Ledger 形式を返せる（出力フォーマットに EvidenceLedger JSON が定義されている） |
| AC-4 | `/pg-hunt` は root cause なしに fix へ進めない（Iron Law が明記されている） |
| AC-5 | `/pg-check` は severity 付き finding を返せる（Severity 定義と出力フォーマットが定義されている） |

## Notes from Refinement

- コマンドファイルには TASK 番号を含めない（Rule 2: Skill は再利用単位に限定）
- Markdownlint に通る Markdown を書く
- `main` ブランチへの直接コミット禁止。`feature/task-0031-pg-commands` で作業

## Estimation Evidence

### Risks

- コマンドファイルの形式が既存の `ai-dev-workflow.md` と乖離するリスク → 事前に既存ファイルを読んで合わせる

### Unknowns

- なし（依存 Skill が TASK-0029/0030 で確定済み）

### Assumptions

- `plugin/plangate/commands/` ディレクトリが存在する
- `evidence-ledger` Skill の JSON スキーマは TASK-0030 の SKILL.md に準拠する
