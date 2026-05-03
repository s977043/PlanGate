# PBI INPUT PACKAGE: TASK-0059 (PBI-HI-007 / Issue #201)

## Context / Why

Harness Improvement Roadmap (EPIC #193) の Issue 群を継続的に運用するため、Issue / Label / Milestone 運用を標準化する。今回の milestone 整列対応 (v8.6.0/v8.7.0/v8.8.0/v8.9.0 一括訂正) で、運用ルールが暗黙のままだと再発することが判明した。

## What

### In scope
- Issue 必須セクション (Why / What / AC / Non-goals) を正本化
- Label taxonomy（kind / area / priority / status）を定義
- Milestone mapping policy を定義（推測禁止、EPIC で固定）
- Roadmap issue 作成チェックリストを提供
- GitHub Issue テンプレートを追加（PlanGate Roadmap Task 用）
- 既存 `pages/guides/governance/documentation-management.md` に Issue governance への参照を追加

### Out of scope
- すべての既存 Issue の即時修正
- 自動ラベリング bot
- GitHub Projects 導入
- release automation

## Acceptance Criteria（Issue #201 から転記）

15 項目。issue-governance.md と既存 documentation-management.md の組合せで充足する。

## Mode 判定

**light** — documentation 系 PBI（変更ファイル 3-4 件、既存テンプレ拡張中心、リスク低）。

## Plan/Test cases

簡易版で進める（light モード）。
