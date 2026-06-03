---
name: plan-quality-reviewer
description: "C-2 外部レビューの設計妥当性レーン担当。plan.md / todo.md / test-cases.md を読み、R-NNN 形式の構造化 Finding を出力する。実装コードは原則読まない。Use when: C-2 外部レビューで plan の論理・受入基準網羅・スコープ整合をチェックしたい時。"
---

# Plan Quality Reviewer

> **本 Skill と `plan-quality-check` の違い**:
> `plan-quality-check` は実装前の内部セルフチェック（スコア返却）。
> 本 Skill は C-2 外部レビューの **設計妥当性レーン** として R-NNN 構造化 Finding を出力する。

## カテゴリ

Review / External

## 想定 Phase

C-2（plan ゲート外部レビュー）

## 役割・責務

[`review-principles.md §7-bis`](../../../.claude/rules/review-principles.md) の
「設計妥当性レーン」担当として以下を担う:

| 読む | 読まない（原則） |
|------|----------------|
| plan.md | 実装コード |
| todo.md | テスト結果ログ |
| test-cases.md | |
| pbi-input.md | |

**捕捉する観点**:
- plan の論理整合（Goal → Approach → Work Breakdown のつながり）
- 受入基準（AC）の網羅性・テスト可能性
- スコープ欠落（Out of scope が明示されているか）
- 既存コード構造に起因する不足は「追加 AC 候補」として返す（コードベース整合レーンへの返し）

## 入力

```yaml
plan: <plan.md の内容>
todo: <todo.md の内容>
test_cases: <test-cases.md の内容>
pbi_input: <pbi-input.md の内容（任意）>
```

## 出力フォーマット

`review-external.md` 追記と互換の Finding 配列:

```markdown
## Plan Quality Review — R-NNN〜R-MMM

| ID | Lane | Severity | Status | 内容 |
|----|------|---------|--------|------|
| R-001 | design-validity | major | open | AC-02 の検証コマンドが未定義 |
| R-002 | design-validity | minor | open | Risks セクションにロールバック手順が欠落 |
```

各 Finding の必須フィールド:

| フィールド | 値の例 |
|----------|--------|
| `id` | `R-NNN`（review-external.md 採番ルールに従う） |
| `lane` | `design-validity` |
| `severity` | `critical` / `major` / `minor` / `info` |
| `status` | `open` |
| `body` | 具体的な指摘内容（plan.md の該当箇所を引用） |

## 判定基準

[`review-principles.md §3-4`](../../../.claude/rules/review-principles.md) に従う:

| 判定 | 条件 |
|------|------|
| Auto-approve 相当 | critical=0, major=0 |
| Human review 推奨 | major ≥ 1 |
| Human review 必須 | critical ≥ 1 |

指摘ゼロの場合も「指摘なし（監査連続性のため）」を明示記録すること。

## 使い方（呼び出し例）

```bash
# C-2 フェーズで呼び出す場合
bin/plangate review TASK-XXXX --phase c2 --reviewer plan-quality-reviewer
```

または SKILL を直接 invoke:

```
/plan-quality-reviewer
入力: docs/working/TASK-XXXX/plan.md, todo.md, test-cases.md
```

## 関連

- [`review-principles.md §7-bis`](../../../.claude/rules/review-principles.md) — 2 レーン責務契約
- [`external-reviewer-interface.md`](../../../docs/ai/external-reviewer-interface.md) — 接続 IF 正本
- [`plan-quality-check`](../plan-quality-check/SKILL.md) — 内部セルフチェック（別 Skill）
- `review-external.schema.json` — Finding スキーマ
