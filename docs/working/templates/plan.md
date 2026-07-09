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

## 前提の実測検証（#786）

> 計画が依拠する前提は、検証コマンドと実測結果で裏取りする。検証不能な前提は Questions / Unknowns に降格する。

| 前提 | 検証コマンド | 実測結果 | 判定 |
|---|---|---|---|
| {計画が依拠する前提} | `{検証コマンド}` | {実測結果} | ✅ / ❌ / N/A |

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

### レビューレーン計画（#786）

| 成果物 | レーン（観点/独立性） | unavailable 時の代替 |
|---|---|---|
| {対象成果物} | {レーン1: 観点・独立性} / {レーン2: 観点・独立性} | {レーン不能時に切り替える代替レーン} |

> 独立レーンが同一指摘に収斂 → 採用。単一レーンの推測指摘 → 実測で裏取り後に判定する。

## Plan Review Readiness

> C-1 self-review の前に [`docs/ai/plan-review-readiness-gate.md`](../../ai/plan-review-readiness-gate.md) で確認する。各項目は `pass / needs_revision / blocked` 判定に使われるため、`TBD` / `TODO` / `必要に応じて` / `適切に` のまま残さない。

### Success Criteria

- AC: {受入基準と対応する `test-cases.md` のケースID}
- Completion boundary: {どこまで終わればDoneか、どこから先は別PBIか}

### Review Criteria

- Design alignment: {既存設計・ADR・UI/UX・workflowとの整合観点}
- Test expectations: {C-1/C-2/C-3で確認すべきテスト期待値}
- Security: {セキュリティ観点。N/Aの場合は理由}
- Maintainability: {保守性・命名・責務境界の観点}
- Backward compatibility: {後方互換性。N/Aの場合は理由}
- Operational risk: {運用リスク。N/Aの場合は理由}

### Required Context

- Referenced issues: {Issue URL / 番号}
- ADR / docs: {参照したADR・設計doc・運用doc}
- Existing implementation: {既存実装・関連ファイル}
- Related tests: {関連テスト・fixture}
- Constraints: {HO paths / forbidden files / 環境制約 / 権限制約}

### Non-goals and Scope Boundary

- Out of scope: {今回やらないこと}
- Change-prohibited zones: {触らないファイル・ディレクトリ・設定}
- Forbidden new dependencies: {追加禁止の依存。許可する場合は承認条件}

## Replan Triggers

> plan-quality-check skill の C1-LOOP-02（Replan Triggers と機械値/閾値の記入）に対応する（#786）。

以下に該当した場合はexecを止め、planを更新してC-1を再実行する。

- 想定外の変更対象ファイルが必要になった
- 既存テストがbaselineで失敗している
- 受入基準と実装方針に矛盾が見つかった
- Task間のインターフェースが成立しない
- セキュリティ・データ損失・後方互換性リスクが見つかった
- hidden dependency が見つかり、Work Breakdown または Files / Interfaces が変わる
- public API / schema / hook / workflow 契約の変更が必要になった
- `test-cases.md` と実装可能なテスト契約が一致しない
- scope bloat（計画外ファイルが大幅に増える、または目的外改善が混入する）が発生した
- security impact が新たに見つかった

## Stop Condition

> plan-quality-check skill の C1-LOOP-01（Stop Condition の記入）に対応する（#786）。

以下に該当した場合は人間判断まで停止する。

- C-3承認前にexecが必要になった
- 要件間の矛盾、または AC と実装方針の矛盾が見つかった
- rollback不能な変更が必要になった
- 外部API / 認証情報 / 課金 / 権限 / 本番データに触る必要が出た
- 破壊的操作、データ削除、migration、不可逆変更が必要になった
- 新規依存追加、または大規模な想定外変更が必要になった
- high-risk / criticalでTDD証跡を残せない

## Human Approval Boundary

以下は AI が自己判断で実行せず、人間承認または別PBI化まで停止する。

- Security-sensitive changes: {暗号化・認証・認可・秘密情報・監査ログなど}
- Auth / billing / permissions: {認証、課金、権限、アカウント操作}
- Production operations: {本番操作、デプロイ、外部公開、運用設定}
- Data deletion / migration: {削除、移行、不可逆なデータ変換}
- Irreversible changes: {戻せない変更、公開 API 契約変更、広範な互換性破壊}

## C-1 Self Review Checklist

- [ ] Plan Review Readiness Gate が `pass` 相当（7 項目がすべて具体化済み）
- [ ] 受入基準がWork Breakdownにマッピングされている
- [ ] TaskごとのFiles / Interfaces / Steps / Completion Criteriaが具体的
- [ ] `TBD` / `TODO` / `後で実装` / `必要に応じて` / `適切に` / `いい感じに` が残っていない
- [ ] 未定義の関数名・型名・ファイルパス・コマンドを参照していない
- [ ] テストの入力・期待値・検証コマンドが具体的
- [ ] Out of Scopeに触れていない
- [ ] Replan Triggers / Stop Condition が書かれている
- [ ] high-risk / critical の場合、Rollbackが具体的
- [ ] （is_ui_task の場合）states / design token / component 再利用+variant / a11y を design.md 視覚設計に明示し、未定義デザイン値は発明せず提案扱い（#579・non-UI は N/A）
