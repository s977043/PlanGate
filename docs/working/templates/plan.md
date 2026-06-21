---
task_id: TASK-XXXX
artifact_type: plan
schema_version: 1
status: draft
mode: standard
related_issue: <issue URL>
created_by: orchestrator
---

# TASK-XXXX Implementation Plan

> このテンプレートは、AI実装者が安全に実行できる **実行可能な作業指示書** として `plan.md` を書くためのもの。
> Superpowers の `writing-plans` から、PlanGateに合う要素だけを翻訳している。

## Goal

{このPBIで何を達成するかを1文で書く}

## Context

- 背景: {なぜ必要か}
- 関連Issue: {URL}
- 関連artifact:
  - `pbi-input.md`
  - `design.md`
  - `test-cases.md`

## Scope

### In Scope

- {今回やること}

### Out of Scope

- {今回やらないこと}

> 実装中に**スコープ外の改善・不具合を発見**した場合は、その場で直さず**別 Issue / メモ（handoff の V2 候補・既知課題）へ分離**する（依頼外変更・便乗リファクタの混入防止 / #578）。

## Global Constraints

- {既存設計・命名規則・依存追加・セキュリティ・後方互換性などの制約}
- `TBD` / `TODO` / `必要に応じて` / `適切に` のような曖昧な未決事項を残さない
- 変更対象外ファイルを触る場合は、理由を明記する
- 重要な設計判断は同タスクの `decision-log.jsonl`（正本・各 TASK ディレクトリ直下）に記録する。学び/再発防止は [`AGENT_LEARNINGS.md`](../../../AGENT_LEARNINGS.md)、監査ログは [`_audit/`](../_audit/)、docs 配置規約は [`documentation-management.md`](../../pages/guides/governance/documentation-management.md) に従う（保存先を分離し AGENTS.md に恒常ルール以外を足さない / #578）

## Approach Comparison

| 案 | 内容 | メリット | デメリット | 判定 |
|---|---|---|---|---|
| A | {案A} | {メリット} | {デメリット} | 採用 / 不採用 |
| B | {案B} | {メリット} | {デメリット} | 採用 / 不採用 |

### Recommended Approach

{採用案と理由。既存設計との整合性、実装コスト、保守性、テスト容易性を含める}

## Files / Interfaces

| ファイル | 操作 | 目的 | 公開インターフェース / 依存 |
|---|---|---|---|
| `path/to/file.ts` | create / modify | {目的} | `{functionName(args): ReturnType}` |
| `path/to/test.ts` | create / modify | {テスト目的} | — |

## Work Breakdown

> 各Taskは、独立して検証可能で、reviewerがTask単位で approve / reject できる粒度にする。
> setup / config / docs は、それを必要とする成果物のTaskに含める。

### Task 1: {タスク名}

**Purpose**: {このTaskで達成すること}

**Files**:

- Create: `path/to/new-file.ts`
- Modify: `path/to/existing-file.ts`
- Test: `path/to/test-file.test.ts`

**Interfaces**:

- Consumes: `{前Taskや既存コードから使う関数・型}`
- Produces: `{後続Taskが使う関数・型・ファイル}`

**Steps**:

- [ ] Step 1: failing test を追加する
  - 変更: `path/to/test-file.test.ts`
  - 期待: 対象機能が未実装のため失敗する
- [ ] Step 2: REDを確認する
  - command: `pnpm test path/to/test-file.test.ts`
  - expected: `FAIL` with `{期待する失敗理由}`
- [ ] Step 3: 最小実装を追加する
  - 変更: `path/to/new-file.ts`
  - 方針: テストを通すために必要な最小実装に留める
- [ ] Step 4: GREENを確認する
  - command: `pnpm test path/to/test-file.test.ts`
  - expected: `PASS`
- [ ] Step 5: 関連検証を実行する
  - command: `pnpm typecheck`
  - expected: `PASS`

**Completion Criteria**:

- [ ] 対象テストが成功している
- [ ] 変更ファイルがScope内に収まっている
- [ ] Evidence Ledgerに検証結果を記録している

**Rollback**:

- {戻す場合の手順。high-risk / criticalでは必須}

### Task 2: {タスク名}

**Purpose**: {このTaskで達成すること}

**Files**:

- Create: `path/to/file`
- Modify: `path/to/file`
- Test: `path/to/test`

**Interfaces**:

- Consumes: `{Task 1で作ったもの}`
- Produces: `{後続Taskが使うもの}`

**Steps**:

- [ ] Step 1: {具体的な作業}
  - command: `{必要ならコマンド}`
  - expected: `{期待結果}`

**Completion Criteria**:

- [ ] {完了条件}

**Rollback**:

- {戻す場合の手順}

## Verification Plan

| 種別 | コマンド / 確認方法 | 期待結果 | Evidence保存先 |
|---|---|---|---|
| Unit | `pnpm test path/to/test.ts` | 0 failed | `evidence/tdd/` or `evidence/verification/` |
| Typecheck | `pnpm typecheck` | exitCode=0 | `evidence/verification/` |
| Lint | `pnpm lint` | exitCode=0 | `evidence/verification/` |
| Manual | {必要なら手動確認} | {期待結果} | `evidence/manual/` |

> **検証が実行不能な場合**（環境制約・依存未整備等）は、その**理由**と**代替確認方法**を明記する（「Done = 検証完了」を満たせない検証を黙って省略しない / #578）。

## Replan Triggers

以下に該当した場合はexecを止め、planを更新してC-1を再実行する。

- 想定外の変更対象ファイルが必要になった
- 既存テストがbaselineで失敗している
- 受入基準と実装方針に矛盾が見つかった
- Task間のインターフェースが成立しない
- セキュリティ・データ損失・後方互換性リスクが見つかった

## Stop Condition

以下に該当した場合は人間判断まで停止する。

- C-3承認前にexecが必要になった
- rollback不能な変更が必要になった
- 外部API / 認証情報 / 本番データに触る必要が出た
- high-risk / criticalでTDD証跡を残せない

## C-1 Self Review Checklist

- [ ] 受入基準がWork Breakdownにマッピングされている
- [ ] TaskごとのFiles / Interfaces / Steps / Completion Criteriaが具体的
- [ ] `TBD` / `TODO` / `後で実装` / `必要に応じて` / `適切に` / `いい感じに` が残っていない
- [ ] 未定義の関数名・型名・ファイルパス・コマンドを参照していない
- [ ] テストの入力・期待値・検証コマンドが具体的
- [ ] Out of Scopeに触れていない
- [ ] Replan Triggers / Stop Condition が書かれている
- [ ] high-risk / critical の場合、Rollbackが具体的
