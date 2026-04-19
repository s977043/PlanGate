# TASK-0025 テストケース定義

> 生成日: 2026-04-20

## 受入基準 → TC マッピング

| 受入基準 | TC | 種別 |
|---------|-----|------|
| 5 Agent 新規配置 | TC-1 | Unit |
| 責務/委譲/allowed-tools/呼び出しSkill 定義 | TC-2 | Unit |
| Rule 3 遵守 | TC-3 | Integration |
| 既存 18 agents とのマッピング表 | TC-4 | Integration |
| 実行シーケンス動作可能形で文書化 | TC-5 | Integration |

## テストケース一覧

### TC-1: 5 Agent ファイル存在

- **入力**:
  ```bash
  for a in orchestrator requirements-analyst solution-architect implementation-agent qa-reviewer; do
    test -f ".claude/agents/$a.md" || echo "missing: $a"
  done
  ```
- **期待出力**: 出力なし（全 5 件存在）
- **種別**: Unit

### TC-2: 各 Agent の必須フィールド（既存定義パターン準拠）

- **入力**: 各 `.claude/agents/<agent>.md` の frontmatter と本文確認
- **期待出力**: 各ファイルに以下
  - frontmatter: `name`, `description`, `tools`（既存 agents と同形式）
  - 本文: 「責務」「委譲関係」「呼び出し Skill」「ツール使用方針」セクション（`skills` は frontmatter 拡張ではなく本文）
- **種別**: Unit

### TC-3: Rule 3 遵守

- **入力**:
  ```bash
  grep -l "Laravel\|PostgreSQL\|TASK-\|このプロジェクト\|Cloudflare" .claude/agents/orchestrator.md .claude/agents/requirements-analyst.md .claude/agents/solution-architect.md .claude/agents/implementation-agent.md .claude/agents/qa-reviewer.md
  ```
- **期待出力**: 出力なし
- **種別**: Integration

### TC-4: 既存 agents マッピング表

- **入力**: `docs/working/TASK-0025/evidence/existing-agents-inventory.md` を確認
- **期待出力**: 既存 18 agents それぞれに対し、5 新規 agent との関係（対応/重複/新規）が記載
- **種別**: Integration

### TC-5: 実行シーケンス文書化

- **入力**: `docs/workflows/execution-sequence.md` を確認
- **期待出力**:
  - 5 agent 全てが登場
  - orchestrator 起点、handoff 終点
  - 順序: orchestrator → requirements-analyst → qa-reviewer → solution-architect → implementation-agent → qa-reviewer → orchestrator
- **種別**: Integration

## エッジケース

### TC-E1: 既存 agent との名前衝突

- 新規 5 名（orchestrator, requirements-analyst, solution-architect, implementation-agent, qa-reviewer）が既存 18 agents と重複しないことを確認

### TC-E2: 本文「呼び出し Skill」セクションの妥当性

- 各 agent の本文「呼び出し Skill」セクションに列挙された名前が、#24 で確定した 10 Skill 名と完全一致
- 前提: #24 は完了済（本 TASK の前提 TASK）
