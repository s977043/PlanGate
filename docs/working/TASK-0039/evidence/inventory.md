# Inventory — TASK-0039 Step 1 棚卸し結果

> 実施: 2026-04-30 / hard-mandate キーワード `必ず|絶対|ALWAYS|NEVER` の grep 結果集計

## 全 64 ファイル grep 結果

### 入口 (3 ファイル)

| ファイル | hit | 一次評価 |
|---------|-----|---------|
| `CLAUDE.md` | 2 件 | 全て AI 運用 4 原則（第 1 / 第 4）→ **保持** |
| `AGENTS.md` | 0 件 | 該当なし |
| `docs/ai/project-rules.md` | 3 件 | 4 原則 (2) + ブランチ規則 (1)、ブランチ規則は「禁止」表現に置換可 |

### 共通 (1 ファイル)

| ファイル | hit | 一次評価 |
|---------|-----|---------|
| `docs/ai-driven-development.md` | 3 件 | 全て手順指定（「必ず含めること」「必ず明記」「絶対ルール」）→ **削減候補** |

### .claude/rules (5 ファイル)

| ファイル | hit | 一次評価 |
|---------|-----|---------|
| `working-context.md` | 2 件 | L0 読み込み手順 + プロンプト記載手順 → **削減候補**（手順は別箇所に） |
| `hybrid-architecture.md` | 1 件 | 「絶対に通さない」 = Hook 説明 → **保持**（不変制約の概念説明） |
| `mode-classification.md` | 0 件 | — |
| `review-principles.md` | 0 件 | — |
| `orchestrator-mode.md` | 0 件 | — |

### .claude/commands (3 ファイル)

| ファイル | hit | 一次評価 |
|---------|-----|---------|
| `ai-dev-workflow.md` | 3 件 | 「絶対ルール」（Iron Law）+ 「変更理由は必ずコードベース由来」→ **保持**（Iron Law 関連） |
| `working-context.md` | 0 件 | — |
| `README.md` | 0 件 | — |

### .claude/agents (23 ファイル, hit 4 件)

| ファイル | 一次評価 |
|---------|---------|
| `prompt-engineer.md` | 要個別レビュー |
| `linter-fixer.md` | 要個別レビュー |
| `workflow-conductor.md` | 要個別レビュー |
| `code-optimizer.md` | 要個別レビュー |
| その他 19 ファイル | hit 0 件 |

### plugin/plangate/rules (9 ファイル, hit 2 件)

| ファイル | hit | 一次評価 |
|---------|-----|---------|
| `working-context.md` | 2 件 | `.claude/rules/` と同内容、同期削減候補 |
| その他 8 ファイル | 0 件 | — |

### plugin/plangate/commands (7 ファイル, hit 3 件)

| ファイル | hit | 一次評価 |
|---------|-----|---------|
| `ai-dev-workflow.md` | 3 件 | `.claude/commands/` と同内容、Iron Law 関連 → **保持** |
| その他 6 ファイル | 0 件 | — |

### plugin/plangate/skills (14 ファイル, hit 2 件)

| ファイル | hit | 一次評価 |
|---------|-----|---------|
| `intent-classifier/SKILL.md` | 1 件 | confidence 指示 → **保持**（仕様明確化） |
| `self-review/SKILL.md` | 1 件 | 「必ず修正すべき」→ 「修正必須」へ言い換え可 |
| その他 12 ファイル | 0 件 | — |

## 削減候補 3 段階分類

### 必須削減（手順指定の冗長表現）

| ファイル | 内容 | 対応 |
|---------|------|------|
| `docs/ai-driven-development.md:318` | 「必ず含めること」（plan の Step 形式説明） | 「以下を含める」に修正 |
| `docs/ai-driven-development.md:346` | 「必ず明記すること」（todo の Owner 説明） | 「明記する」に修正 |
| `docs/ai-driven-development.md:479` | 「絶対ルール」（Iron Law 説明） | 「Iron Law（不可侵ルール）」に統一 |
| `.claude/rules/working-context.md:89` | 「必ず最初に読む」 | 「最初に読む」に修正 |
| `.claude/rules/working-context.md:244` | 「必ず含める」 | 「含める」に修正 |
| `plugin/plangate/rules/working-context.md:62` | 同上 | 同上 |
| `plugin/plangate/rules/working-context.md:197` | 同上 | 同上 |

### 推奨削減（言い換えで slimming 可能）

| ファイル | 内容 | 対応 |
|---------|------|------|
| `plugin/plangate/skills/self-review/SKILL.md:195` | 「必ず修正すべき」 | 「修正必須」へ |

### 保持（Iron Law / AI 運用 4 原則に該当）

| ファイル | 内容 | 理由 |
|---------|------|------|
| `CLAUDE.md:36` | 「必ず...y/n 確認」（第 1 原則） | AI 運用 4 原則 |
| `CLAUDE.md:42` | 「絶対的に遵守する」（第 4 原則） | AI 運用 4 原則 |
| `docs/ai/project-rules.md:64` | 第 1 原則 | 同上（Core Contract に統合検討） |
| `docs/ai/project-rules.md:70` | 第 4 原則 | 同上 |
| `.claude/rules/hybrid-architecture.md:68` | 「絶対に通さない」（Hook 説明） | 不変制約の概念説明として必要 |
| `.claude/commands/ai-dev-workflow.md` (3 件) | Iron Law 説明 | Iron Law 7 項目関連 |
| `plugin/plangate/commands/ai-dev-workflow.md` (3 件) | 同上 | 同上 |
| `plugin/plangate/skills/intent-classifier/SKILL.md:21` | 「必ず confidence に反映」 | 仕様明確化 |

### 個別レビュー要（agents 4 件）

| ファイル | 次ステップ |
|---------|----------|
| `.claude/agents/prompt-engineer.md` | 個別 grep + 文脈確認 |
| `.claude/agents/linter-fixer.md` | 同上 |
| `.claude/agents/workflow-conductor.md` | 同上 |
| `.claude/agents/code-optimizer.md` | 同上 |

→ Step 6 (本 PBI スコープ内) で対応。本 inventory ではヒット件数の認識のみ。

## Step 1 完了条件

- [x] **全 64 ファイル grep 完了** （本ファイルに記録）
- [x] **削減候補 3 段階分類** （必須 7 件、推奨 1 件、保持 14 件、個別 4 件）
- [x] **編集対象優先層の特定** （入口 + 共通 + ローカル/Plugin 重複領域）

## 編集範囲（plan.md L2 mitigation 準拠）

本 PBI で編集する優先層:

1. `CLAUDE.md` (薄型化)
2. `AGENTS.md` (薄型化)
3. `docs/ai/project-rules.md` (Core Contract 参照追加)
4. `docs/ai-driven-development.md` (手順指定の冗長表現削除)
5. `docs/ai/core-contract.md` (新規作成、Iron Law 正本)
6. `.claude/rules/working-context.md` + `plugin/plangate/rules/working-context.md` (同期)
7. `.claude/commands/ai-dev-workflow.md` + `plugin/plangate/commands/ai-dev-workflow.md` (Iron Law 表現を Core Contract 参照に)
8. `.claude/agents/{prompt-engineer,linter-fixer,workflow-conductor,code-optimizer}.md` (個別レビュー)
9. `plugin/plangate/skills/self-review/SKILL.md` (推奨削減 1 件)

V2 候補（本 PBI スコープ外）:
- hard-mandate ヒットなしの agents (19 件)
- hard-mandate ヒットなしの skills (12 件)
- `.claude/rules/{mode-classification,review-principles,orchestrator-mode}.md`
