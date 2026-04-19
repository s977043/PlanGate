# TASK-0025 EXECUTION PLAN

> 生成日: 2026-04-20
> PBI: [TASK-0021-C] 責務ベース Agent 5 体を整備する
> チケットURL: https://github.com/s977043/plangate/issues/25

## Goal

`.claude/agents/` に 5 体の責務ベース Agent を新規配置し、既存 18 agents との責務マッピングを作成する。実行シーケンスを文書化する。

## Constraints / Non-goals

- Rule 3 遵守（責務のみ、ツール固有/案件固有なし）
- 既存 Agent は削除せず共存、`orchestrator.md` は **新規作成**（既存に同名なし確認済）
- `呼び出す Skill` は frontmatter 拡張ではなく **本文セクション**で表現（既存 agents の定義パターンとの整合性）
- **Non-goals**: 既存 Agent の改変、Agent 実行エンジン、plugin 同梱、`.claude/agents/README.md` の仕様更新

## Approach Overview

1. 既存 Agent 18 体の責務を調査、マッピング表作成
2. 5 新規 Agent 定義（責務・委譲・allowed-tools・呼び出し Skill）
3. 実行シーケンス図（Mermaid or 箇条書き）
4. Rule 3 遵守チェック

## Work Breakdown

### Step 1: 既存 Agent 調査とマッピング表作成

- **Output**: `docs/working/TASK-0025/evidence/existing-agents-inventory.md`
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: 18 agents の名前と責務要約、5 新規との対応表

### Step 2: Agent 共通テンプレート策定（既存定義パターン準拠）

- **Output**: `docs/working/TASK-0025/evidence/agent-template.md`
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: frontmatter（既存準拠: name, description, tools）+ 本文構造（責務 / 委譲 / 呼び出し Skill / ツール使用方針）
- **注**: `skills` は frontmatter 拡張ではなく**本文セクション**として記載、既存 agents 定義と整合

### Step 3-7: 5 Agent 作成

- **Output**: `.claude/agents/{orchestrator, requirements-analyst, solution-architect, implementation-agent, qa-reviewer}.md`
- **Owner**: agent
- **Risk**: 中
- **🚩 チェックポイント**: 5 ファイル存在、各に責務・委譲・allowed-tools・呼び出し Skill 明記

### Step 8: 実行シーケンス図作成

- **Output**: `docs/workflows/execution-sequence.md`
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: orchestrator → 各 agent → handoff のフロー図（Mermaid 推奨）

### Step 9: Rule 3 遵守チェック

- **Output**: `docs/working/TASK-0025/evidence/rule3-check.md`
- **Owner**: agent
- **Risk**: 中
- **🚩 チェックポイント**: 各 agent 定義にツール固有手順・案件固有仕様が含まれないことを確認

## Files / Components to Touch

| 種別 | ファイルパス | 変更内容 |
| --- | --- | --- |
| 新規 | .claude/agents/orchestrator.md | Agent 定義 |
| 新規 | .claude/agents/requirements-analyst.md | Agent 定義 |
| 新規 | .claude/agents/solution-architect.md | Agent 定義 |
| 新規 | .claude/agents/implementation-agent.md | Agent 定義 |
| 新規 | .claude/agents/qa-reviewer.md | Agent 定義 |
| 新規 | docs/workflows/execution-sequence.md | 実行シーケンス |
| 新規 | docs/working/TASK-0025/evidence/existing-agents-inventory.md | 既存マッピング |
| 新規 | docs/working/TASK-0025/evidence/agent-template.md | テンプレ |
| 新規 | docs/working/TASK-0025/evidence/rule3-check.md | Rule 3 チェック |

## Testing Strategy

- **Unit**: 5 Agent ファイル存在、frontmatter valid
- **Integration**: 実行シーケンス図が全 5 agent をカバー、呼び出し Skill が #24 で予定されているものと一致
- **Verification Automation**:
  - `ls .claude/agents/*.md | wc -l` → 新規 5 含む件数
  - Rule 3 違反検索（プロジェクト固有前提）

## Risks & Mitigations

| リスク | 対策 |
| --- | --- |
| Rule 3 違反（固有情報混入） | Step 9 機械チェック |
| 既存 Agent と責務衝突 | Step 1 マッピング表で明示、orchestrator は workflow-conductor と共存方針記載 |
| 委譲関係のループ | Step 8 シーケンス図で検証、orchestrator 起点に統一 |

## Questions / Unknowns

- 各 agent の allowed-tools は Step 3-7 で確定（implementation-agent は Edit/Write/Bash/Read、qa-reviewer は Read/Grep/Bash/Glob 等）
- `skills` frontmatter に #24 の Skill 名を列挙（実体は #24 完了後に解決）

## Mode判定

**モード**: `standard`

**判定根拠**:
- 変更ファイル数: 9 → standard
- 受入基準数: 5 → standard
- 変更種別: Agent 新規整備 → standard
- リスク: 中 → standard
- **最終判定**: standard

## 依存

- **前提**: #23 完了、**#24 完了**（Skill 名凍結のため）
- **後続**: #26 / #27 で参照される
