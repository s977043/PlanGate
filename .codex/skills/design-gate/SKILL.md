---
name: design-gate
description: "Design Gate を実施し、設計書（Design Artifact）を生成・評価する。Use when: high-risk 以上のタスクで実装前に設計を整理したい時。「設計書を作りたい」「Design Gate を通したい」「実装前に設計レビューをしたい」。"
---

# Design Gate

high-risk 以上のタスクで実装前に設計書（Design Artifact）を生成・評価する。

## Iron Law

`NO CODE WITHOUT APPROVED DESIGN FIRST`

high-risk 以上のモードでは、Design Artifact の 8 項目が揃い承認されるまで実装を開始しない。

## Common Rationalizations

| こう思ったら | 現実 |
|---|---|
| 「シンプルだから設計不要」 | シンプルなほど設計は速い。10 分の設計が数時間の手戻りを防ぐ |
| 「急いでいるから省略」 | 設計なしの実装は後で手戻りになる。急ぐほど設計が必要 |
| 「前に似たことをやった」 | コードベースは変化する。前回の前提が今回も成立するとは限らない |
| 「PoC だから後で直す」 | PoC は往々にして本番コードになる。設計の借金は複利で増える |

## Design Artifact 8 項目の入力フォーム

以下の質問にすべて答えることで Design Artifact が完成する。

### 1. 問題定義

**質問**: 何が問題か？

- 現状はどうなっているか
- どのような課題・不便が発生しているか
- なぜ今対応が必要か（背景・トリガー）

### 2. 目的

**質問**: なぜ解決するか？

- このタスクで達成したいゴールは何か
- 解決後にどのような状態になっていてほしいか（期待効果）

### 3. 非目的

**質問**: 今回対応しないことは？

- スコープ外として明示的に除外するもの
- 「やらない」と決めた理由

### 4. 仕様

**質問**: 何を作るか？（具体的な機能要件）

- 実装する機能・コンポーネントを列挙する
- 入力・処理・出力を明示する
- 受入基準（Acceptance Criteria）を記述する

### 5. 代替案

**質問**: 他に検討したアプローチは？（最低 2 案）

| 案 | 概要 | メリット | デメリット |
|---|------|--------|---------|
| 案 1 | ... | ... | ... |
| 案 2 | ... | ... | ... |

### 6. 採用案

**質問**: 選んだアプローチと選択理由は？

- 採用するアプローチを明示する
- 代替案と比較した場合の優位点を述べる
- トレードオフを認識した上で選択した旨を記述する

### 7. リスク

**質問**: 実装・運用上のリスクは？（影響度・対策付き）

| リスク | 影響度 | 発生確率 | 対策 |
|-------|-------|---------|------|
| リスク 1 | High / Medium / Low | High / Medium / Low | ... |
| リスク 2 | ... | ... | ... |

### 8. テスト方針

**質問**: どう検証するか？

| レイヤー | テスト種別 | カバー範囲 |
|---------|----------|----------|
| Unit | Unit | ... |
| Integration | Integration | ... |
| E2E | E2E | ... |

## 手順

1. `/pg-think` を実行して論点整理を行う（Problem Restatement / Assumptions / Options / Recommended Approach / Risks）
2. `/pg-think` の出力を元に 8 項目を補完する
   - Problem Restatement → 問題定義・目的
   - Assumptions → 非目的（スコープ外の前提）
   - Options → 代替案
   - Recommended Approach → 採用案
   - Risks → リスク
3. 設計書を `docs/working/TASK-XXXX/design.md` に保存する（`docs/working/templates/design.md` を参照）
4. **high-risk の場合**: チームへレビュー依頼（推奨）
5. **critical の場合**: 人間の明示的承認を待つ（必須）。承認前に実装を開始しない

## Mode 別の扱い

| Mode | Design Gate | 承認要件 |
|------|------------|---------|
| `ultra-light` | スキップ可 | 不要 |
| `light` | スキップ可 | 不要 |
| `standard` | スキップ可 | 不要 |
| `high-risk` | **必須** | 推奨（承認記録を design.md に残す） |
| `critical` | **必須** | **必須**（承認なしに実装開始不可） |

## 出力フォーマット

設計書は `docs/working/TASK-XXXX/design.md` に保存する。
テンプレート `docs/working/templates/design.md` の形式に従い、8 項目を Markdown で記述する。

```markdown
## メタ情報

task: TASK-XXXX
related_issue: <issue URL>
author: <担当者>
updated: YYYY-MM-DD
approved_by: <承認者>（high-risk 以上で記入）
approved_at: YYYY-MM-DD（high-risk 以上で記入）

## 1. 問題定義
<記述>

## 2. 目的
<記述>

## 3. 非目的
<記述>

## 4. 仕様
<記述>

## 5. 代替案
<代替案テーブル>

## 6. 採用案
<記述>

## 7. リスク
<リスクテーブル>

## 8. テスト方針
<テストテーブル>
```

## 関連

- Rule: `plugin/plangate/rules/design-gate.md`（適用条件・ブロック条件の正本）
- Command: `plugin/plangate/commands/pg-think.md`（論点整理の初段）
- Template: `docs/working/templates/design.md`（design.md の保存形式）
- Skill: `plugin/plangate/skills/skill-policy-router/SKILL.md`（GatePolicy との連携）
