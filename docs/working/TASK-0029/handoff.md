# Handoff Package: TASK-0029

```yaml
task: TASK-0029
related_issue: https://github.com/s977043/plangate/issues/54
author: implementation-agent
issued_at: 2026-04-26
v1_release: feature/task-0029-intent-classifier
```

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| AC-1: Intent を 7 分類できる（structured output） | PASS | intent-classifier/SKILL.md に feature/bug/refactor/research/review/docs/ops の 7 分類定義と JSON 出力フォーマットが存在する |
| AC-2: Mode を判定できる（定量・定性基準） | PASS | mode-classification.md の判定基準（定量・定性・判定ロジック）が存在し、`high-risk` ラベルで 5 段階が定義されている |
| AC-3: Intent + Mode から GatePolicy を返せる | PASS | skill-policy-router/SKILL.md に Mode 別ポリシー表と GatePolicy JSON 出力フォーマットが存在する |
| AC-4: high-risk 以上で approval/worktree/TDD/review/verify が必須 | PASS | skill-policy-router の Mode 別ポリシー表で high-risk / critical の requiredSkills に approval, worktree, tdd, review, verify が全て含まれている |
| AC-5: ultra-light/light では重いゲートを要求しない | PASS | ultra-light: requiresUserApproval=false, requiresWorktree=false, requiresFailingTestFirst=false。light: 同様 |
| AC-6: docs/working/TASK-0029/test-cases.md にテストケースが記述されている | PASS | TC-01〜TC-11 の 11 テストケースが 7 受入基準に対応して記述されている |
| AC-7: README または docs に mode 分類基準が記載されている | PASS | plugin/plangate/rules/mode-classification.md に 5 段階モード定義・GatePolicy 定義セクションが記載されている |

**総合**: `7/7 基準 PASS`

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| mode-classification.md の `full` 旧ラベルが他ドキュメントに残存する可能性（CLAUDE.md 等） | minor | accepted | No |
| GatePolicy の `standard` における `requiresUserApproval=recommended` は boolean でなく三値（Issue #54 仕様では boolean） | minor | accepted | Yes |

**Critical 課題の対応**: なし（Critical 課題は存在しない）

## 3. V2 候補

| V2 候補 | 理由 | 推定優先度 | 関連 Issue |
|--------|------|----------|-----------|
| `requiresUserApproval` の三値化（true/false/recommended） | `standard` モードで「推奨」という中間状態があるが、boolean で表現できない | Medium | — |
| 既存 docs/working/ および CLAUDE.md の `full` → `high-risk` 置換 | 旧ラベルの残存を機械的に解消する | Low | — |
| CI の markdownlint 対象に plugin/plangate/ を追加 | 現状 CI 対象外のため Skill ファイルの品質保証ができない | Low | — |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| `standard` の `requiresUserApproval=recommended` を notes 文字列で表現 | boolean を true に昇格 | Issue #54 仕様では `standard` での approval は「推奨」であり、true にすると仕様逸脱 |
| GatePolicy を Markdown テーブルで定義 | JSON Schema / TypeScript 型定義 | リポジトリに TypeScript 基盤がないため |
| `full` 旧ラベルの置換は plugin/plangate/rules/mode-classification.md のみ | 全ドキュメント横断置換 | CLAUDE.md 等はプロジェクト外・システムプロンプト文脈であり、本 PR の scope 外とした |

## 5. 引き継ぎ文書

### 概要

Issue #54「Intent / Mode Classifier と Skill Policy Router を実装する」の実装。
`intent-classifier` と `skill-policy-router` の 2 つの SKILL.md を新規作成し、
`mode-classification.md` の `full` → `high-risk` リネームと GatePolicy 定義セクションの追加を行った。
全 7 件の受入基準は PASS。

### 触れないでほしいファイル

- `plugin/plangate/rules/mode-classification.md` の GatePolicy 定義セクション: `skill-policy-router/SKILL.md` の Mode 別ポリシー表と整合している。どちらかを変更する場合は両方を同期する必要がある。

### 次に手を入れるなら

- `requiresUserApproval` の boolean → 三値化（V2 候補参照）
- `intent-classifier` と `skill-policy-router` を呼び出すオーケストレーター Skill の追加
- CLAUDE.md 等での `full` → `high-risk` 置換（low priority）

### 参照リンク

- 親 PBI: https://github.com/s977043/plangate/issues/54
- plan.md: `docs/working/TASK-0029/plan.md`
- status.md: 未作成（standard モードのため current-state.md で代替）
- Intent Classifier: `plugin/plangate/skills/intent-classifier/SKILL.md`
- Skill Policy Router: `plugin/plangate/skills/skill-policy-router/SKILL.md`
- Mode 分類基準: `plugin/plangate/rules/mode-classification.md`

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| ドキュメント仕様突合 | 11 | 11 | 0 | — |
| Unit | 0 | 0 | 0 | — |
| Integration | 0 | 0 | 0 | — |
| E2E | 0 | 0 | 0 | — |

**FAIL / SKIP の詳細**: なし

**補足**: 本実装は Markdown/Skill ベース（TypeScript 基盤なし）のため、テストは test-cases.md の仕様突合で代替した。
