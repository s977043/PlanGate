# PBI INPUT PACKAGE: TASK-0030

## Context / Why

AIエージェントが証拠なしに「完了した」「修正した」「テストが通るはず」と主張することを防ぐため、
実行コマンド・終了コード・出力抜粋を記録する Evidence Ledger v1 を実装する。

Epic #53（PlanGateをAIコーディングの開発統制OSへ拡張する）Phase 1の一部。

## What（Scope）

### In scope

- EvidenceItem / EvidenceLedger のスキーマ定義（SKILL.md）
- status 計算ルール（failed/unknown/passed の判定）
- missingEvidence → Completion Gate ブロックルール
- `/pg verify` の出力形式として使える仕様
- docs/working/TASK-XXXX/evidence/ との統合方針

### Out of scope

- GitHub Checks 連携
- PR コメント自動投稿
- CI ログ全量保存
- 外部 DB 永続化
- TypeScript コード実装

## 受入基準

1. command + exitCode + outputExcerpt を記録できる（スキーマが定義されている）
2. exitCode != 0 の証拠がある場合、status が failed になる（ルールが明記されている）
3. 必須証拠がない場合、Completion Gate がブロックされる（ルールが明記されている）
4. /pg verify 相当の出力形式として使える（SKILL.md に出力形式が定義されている）
5. docs に Evidence Ledger の例がある

## Notes from Refinement

- Markdown/Skill ベース実装（TypeScript 不要）
- 既存の evidence/ ディレクトリ構造（working-context.md）と整合する
- Iron Law: `NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE`

## Estimation Evidence

- Risks: 既存 evidence/ 概念との命名衝突
- Assumptions: Skill は再利用可能な汎用形式で書く（Rule 2 遵守）
