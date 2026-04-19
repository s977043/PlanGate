# TASK-0019 Agents 固有前提スキャン結果

> 調査日: 2026-04-19
> 対象: `.claude/agents/` の 6 agents

## スキャン方法

```bash
grep -l "Laravel\|PostgreSQL\|Eloquent\|ECS\|CodeBuild\|CodeDeploy\|Cloudflare\|Vitest\|PHPUnit\|Terraform" \
  .claude/agents/workflow-conductor.md \
  .claude/agents/spec-writer.md \
  .claude/agents/implementer.md \
  .claude/agents/linter-fixer.md \
  .claude/agents/acceptance-tester.md \
  .claude/agents/code-optimizer.md
```

## 結果

**出力**: 空（**プロジェクト固有前提の記述なし**）

## 判定

6 agents は既に汎用表現で記述されており、**プロジェクト固有前提の除去作業は不要**。

PlanGate の 18 agents 体制のうち、プロジェクト固有の agents（`backend-specialist`, `frontend-specialist`, `database-architect`, `devops-engineer` 等）は別ファイルとして管理されており、plugin 同梱対象の 6 agents はワークフロー中核として汎用設計されていた。

## 処理方針

- agents 6 件: **原本をそのままコピー**（汎用化修正は不要）
- 唯一の repo パス参照（workflow-conductor.md:216 `/.claude/rules/mode-classification.md`）は、TASK-0019 Step 4（rules 配置 + 参照修正）で `plugin/plangate/rules/` 参照に変更する

## リスク

- 当初計画で想定していた「固有前提除去」という工数は不要
- ただし、agents 定義内に今後プロジェクト固有記述が混入しないよう、README 等で汎用化ガイドラインを明記する必要あり（TASK-0020 で対応）
