---
name: skill-policy-router
description: "Intent と Mode を受け取り、必要な Skill・ゲート要件（GatePolicy）を返す。Use when: 依頼の Intent と Mode が確定した後、どの Skill とゲートが必要かを決定したい時。「どのスキルが必要か教えて」「ゲートポリシーを決めて」「Mode に応じた手順を教えて」。"
---

# Skill Policy Router

Intent と Mode を入力として受け取り、必要な Skill とゲート要件（GatePolicy）を structured JSON で返す。

## Iron Law

`GATE POLICY IS DETERMINED BY MODE, NOT BY INTENT`

GatePolicy の必須 / 任意判定は Mode によって決まる。
Intent はスキルの優先度や追加推奨にのみ影響する。

## Common Rationalizations

| こう思ったら | 現実 |
|---|---|
| 「小さな feature だから approval 不要」 | Mode が high-risk ならば Intent に関わらず approval は必須 |
| 「docs なら worktree は不要では？」 | Mode が high-risk なら docs でも worktree が必要 |
| 「ultra-light なら全部スキップでいい」 | verify は ultra-light でも必須 |

## GatePolicy 型定義

```json
{
  "requiredSkills": ["<skill-name>", "..."],
  "optionalSkills": ["<skill-name>", "..."],
  "requiresUserApproval": "<boolean>",
  "requiresEvidence": "<boolean>",
  "requiresFailingTestFirst": "<boolean>",
  "requiresWorktree": "<boolean>"
}
```

**Skill 識別子**:

| 識別子 | 対応 Skill / 行動 |
|--------|----------------|
| `think` | 設計・計画の立案（plan.md 生成） |
| `hunt` | コードベース調査（Grep / Glob 探索） |
| `check` | セルフレビュー（self-review Skill） |
| `tdd` | テスト駆動開発（failing test first） |
| `verify` | 受け入れ検査（test-cases.md 突合） |
| `worktree` | 独立ブランチでの作業（worktree 分離） |
| `review` | 外部レビュー（human / external AI） |
| `approval` | 人間の明示的承認取得 |

## Mode 別ポリシー表

| フィールド | ultra-light | light | standard | high-risk | critical |
|-----------|------------|-------|----------|-----------|---------|
| requiredSkills | verify | check, verify | think, check, verify | think, approval, worktree, tdd, check, review, verify | think, approval, worktree, tdd, review, verify |
| optionalSkills | check | think, hunt | hunt, tdd | — | — |
| requiresUserApproval | false | false | recommended | true | true |
| requiresEvidence | false | false | true | true | true |
| requiresFailingTestFirst | false | false | conditional | true | true |
| requiresWorktree | false | false | false | true | true |

**`standard` の補足**:

- `requiresUserApproval=recommended`: 人間確認を強く推奨するが必須ではない
- `requiresFailingTestFirst=conditional`: TDD が optional として推奨される

**`critical` の追加要件**:

- ロールバック計画の策定が必要
- セキュリティレビューを含む多角的レビューを推奨
- 段階的デプロイ計画の策定を推奨

## 手順

### Step 1: 入力検証

以下のフォーマットで入力を受け取る:

```json
{
  "intent": "<feature|bug|refactor|research|review|docs|ops>",
  "mode": "<ultra-light|light|standard|high-risk|critical>"
}
```

`mode` が不明な場合は `standard` をデフォルトとして使用する。
`intent` が不明な場合は `feature` をデフォルトとして使用する（Intent は GatePolicy に影響しない）。

### Step 2: Mode によるベースポリシー決定

「Mode 別ポリシー表」から対応する行を読み取り、ベース GatePolicy を構築する。

### Step 3: Intent による調整（任意）

Intent に応じて optionalSkills を追加・調整する:

| Intent | 推奨 optionalSkills 追加 |
|--------|------------------------|
| `feature` | think（未追加の場合） |
| `bug` | hunt（原因調査のため） |
| `refactor` | check（品質確認のため） |
| `research` | — |
| `review` | check |
| `docs` | — |
| `ops` | verify（デプロイ検証のため、未追加の場合） |

ただし、requiredSkills に既に含まれている Skill は optionalSkills に重複追加しない。

### Step 4: GatePolicy 出力

構築した GatePolicy を structured JSON で出力する。

## 出力フォーマット

```json
{
  "input": {
    "intent": "<intent>",
    "mode": "<mode>"
  },
  "policy": {
    "requiredSkills": ["<skill-name>"],
    "optionalSkills": ["<skill-name>"],
    "requiresUserApproval": true,
    "requiresEvidence": true,
    "requiresFailingTestFirst": true,
    "requiresWorktree": true
  },
  "notes": "<特記事項（critical の追加要件等）>"
}
```

## 使用例

**入力**: `{ "intent": "docs", "mode": "ultra-light" }`

**出力**:

```json
{
  "input": {
    "intent": "docs",
    "mode": "ultra-light"
  },
  "policy": {
    "requiredSkills": ["verify"],
    "optionalSkills": ["check"],
    "requiresUserApproval": false,
    "requiresEvidence": false,
    "requiresFailingTestFirst": false,
    "requiresWorktree": false
  },
  "notes": ""
}
```

**入力**: `{ "intent": "feature", "mode": "high-risk" }`

**出力**:

```json
{
  "input": {
    "intent": "feature",
    "mode": "high-risk"
  },
  "policy": {
    "requiredSkills": ["think", "approval", "worktree", "tdd", "check", "review", "verify"],
    "optionalSkills": [],
    "requiresUserApproval": true,
    "requiresEvidence": true,
    "requiresFailingTestFirst": true,
    "requiresWorktree": true
  },
  "notes": ""
}
```

## 関連 Skill

- **intent-classifier**: ユーザー依頼文から Intent を判定する。このスキルの前段として使用
