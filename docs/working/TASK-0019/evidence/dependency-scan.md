# TASK-0019 Rules/Scripts 依存スキャン結果

> 調査日: 2026-04-19

## Rules 参照

`.claude/rules/` 配下のファイルへの参照を 6 agents でスキャン:

```bash
grep -n "\.claude/rules/" <6 agent files>
```

### 検出結果（1 件）

| Agent | Line | 参照 |
|-------|------|------|
| workflow-conductor.md | 216 | `.claude/rules/mode-classification.md` |

その他 5 agents からは rules への直接参照なし。

## Scripts 依存

`.claude/agents/` 内で `scripts/` への言及をスキャン:

```bash
grep -n "scripts/" <6 agent files>
```

### 検出結果

現時点で検出なし。各 agent は scripts への直接依存を持たない。

## 既存 scripts/ ディレクトリの内容（参考）

```
scripts/
├── ai-dev-common.sh
├── ai-dev-plan.sh
├── ai-dev-prepare-cloud.sh
├── ai-dev-sync-cloud.sh
├── ai-dev-workflow
├── codex-claude-review.sh
└── codex-local.sh
```

これらは PlanGate のローカル CI/ワークフロー補助スクリプト群。plugin 同梱の要否は次の基準で判断:

| スクリプト | 同梱要否 | 理由 |
|----------|---------|------|
| `ai-dev-workflow` | **同梱**候補 | PlanGate の導線コマンドと整合 |
| `ai-dev-common.sh` | **同梱**候補 | 他の ai-dev-*.sh の共通ライブラリ |
| `ai-dev-plan.sh` | 保留 | plan 生成支援だが、agents から呼ばれない |
| `ai-dev-prepare-cloud.sh` / `ai-dev-sync-cloud.sh` | 除外 | Cloud 環境固有 |
| `codex-claude-review.sh` / `codex-local.sh` | 除外 | Codex CLI 連携、別 plugin の責務 |

→ TASK-0019 では agents が直接依存しないため、**scripts の plugin 同梱は保留**し、TASK-0020（README 整備）で plugin 利用者が既存 scripts/ をどう扱うかを明記する方針。

## 結論

- Rules: 1 件の参照を `plugin/plangate/rules/mode-classification.md` 相対参照に変更
- Scripts: 本 TASK では同梱しない（agents が依存しないため）
- agent-to-agent: 参照なし（workflow-conductor は文脈記述のみで subagent_type 呼び出しなし）
