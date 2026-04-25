# PlanGate Claude Code Plugin 移行ガイド

> 最終更新: 2026-04-20
> 対象バージョン: plugin 0.1.0

## 背景・目的

PlanGate は当初、`.claude/` ディレクトリを含むリポジトリ配布前提の構成でした。この構成は単一リポジトリ内では十分機能しますが、他プロジェクトへの横展開に課題があります:

- 複数リポジトリに `.claude/` 設定を個別配布する手間
- アップデート時の整合性確保
- PlanGate 本体のカスタマイズと利用先プロジェクトの設定の混在

これらを解決するため、PlanGate の Claude Code 側機能を **plugin 形式**で配布可能にしました（`plugin/plangate/`）。本ドキュメントは、既存利用者と新規利用者双方に向けた移行・導入ガイドです。

## デュアル運用の前提

本 plugin は、既存の `.claude/` 構成と **併存可能**に設計されています:

- `.claude/` 側は削除せず温存
- plugin 側を追加導入することで、両方を並列利用可能
- 呼び出し時の優先順位は Claude Code の内部仕様に従う
- 明示的に plugin 側を呼ぶ場合: `plangate:<skill/agent>` prefix を使用

このため、**既存利用者は急いで移行する必要はありません**。plugin の安定性を確認してから段階的に移行できます。

## 同梱範囲（plugin 0.1.0）

### Skills (5)

| Skill | 役割 |
|-------|------|
| `brainstorming` | アイデア → 設計書（PBI INPUT PACKAGE）への昇華 |
| `self-review` | 変更内容の17項目体系的セルフレビュー |
| `subagent-driven-development` | サブエージェント駆動の2段階レビュー開発 |
| `systematic-debugging` | エビデンスベースの体系的デバッグ |
| `codex-multi-agent` | Codex マルチエージェント連携 |

### Commands (2)

| Command | 役割 |
|---------|------|
| `/working-context` | チケット単位の作業コンテキスト管理 |
| `/ai-dev-workflow` | PlanGate ワークフロー起動（plan → exec 等） |

### Agents (6)

| Agent | 役割 |
|-------|------|
| `workflow-conductor` | PlanGate 全フェーズの制御 |
| `spec-writer` | PBI → plan/todo/test-cases 生成 |
| `implementer` | TDD 実装 |
| `linter-fixer` | L-0 リンター自動修正 |
| `acceptance-tester` | V-1 受入検査 |
| `code-optimizer` | V-2 コード最適化 |

### Rules (3)

| Rule | 内容 |
|------|------|
| `working-context.md` | `docs/working/` 配下の作業コンテキスト管理ルール |
| `review-principles.md` | CI/ローカル共通のレビュー判定フレーム |
| `mode-classification.md` | 5 段階モード分類基準（ultra-light/light/standard/high-risk/critical） |

## 対象外の理由

### プロジェクト固有 agents (plugin 未同梱)

以下は特定プロジェクトのインフラ/フレームワーク前提を持つため、汎用配布には不適合です:

| Agent | 固有前提 |
|-------|---------|
| `backend-specialist` | Laravel 11、クリーンアーキテクチャ |
| `frontend-specialist` | TypeScript、特定フレームワーク |
| `database-architect` | PostgreSQL 16、Eloquent ORM |
| `devops-engineer` | AWS ECS + CodeBuild + CodeDeploy + Terraform |

**入手方法**: 必要に応じ、plangate リポジトリから個別にコピー:

```bash
git clone https://github.com/s977043/plangate.git
cp plangate/.claude/agents/backend-specialist.md your-project/.claude/agents/
```

### 専門用途 agents (plugin 未同梱)

以下は opt-in 想定のため、本 plugin には含めません。必要時に手動追加、または将来的に別 plugin として提供予定:

- `security-auditor`, `penetration-tester`, `performance-optimizer`

### 補助 agents (plugin 未同梱)

運用熟成後に追加検討:

- `migration-agent`, `research-analyst`, `explorer-agent`, `project-planner`, `retrospective-analyst`, `scrum-master`, `agile-coach`, `documentation-writer`, `debugger`, `prompt-engineer`, `orchestrator`, `claude-code-reviewer`, `skill-designer`, `test-engineer`, `release-manager`

※ `test-engineer` と `release-manager` は現時点で `.claude/agents/` に存在しません（implementer が兼務、release-manager は critical モード時のみ必要）。

### Codex CLI は対象外

本 plugin は **Claude Code 専用**です。Codex CLI 向け設定（`.codex/`）は別 plugin（例: `openai-codex/codex`）として扱ってください。将来的に統合を検討する可能性はありますが、現時点では対象外です。

## Plugin 内 Rules 参照規則

plugin 内 agents から rules を参照する場合、plugin ルート相対パスを使用:

```markdown
> 判定基準の正本: `plugin/plangate/rules/mode-classification.md`
```

従来の `.claude/rules/` 参照は legacy 側で有効、plugin 側では書き換え済み。

## Plugin 内 Agent/Skill 呼び出し規則

### Skills

```
plangate:brainstorming
plangate:self-review
plangate:subagent-driven-development
plangate:systematic-debugging
plangate:codex-multi-agent
```

### Agents

```python
Task(subagent_type="plangate:workflow-conductor", ...)
Task(subagent_type="plangate:spec-writer", ...)
# ...他も同様
```

### Commands

Commands は `/command-name` 形式でそのまま呼び出し可能。解決順（plugin vs legacy）は Claude Code 内部仕様に従う。

## 既存利用者向け段階的移行手順

### Phase 1: 評価（推奨: 1 週間程度）

```bash
# 1. plugin/plangate/ の存在を確認
ls plugin/plangate/

# 2. 既存の .claude/ と並行稼働させ、違和感なく使えるかテスト
# plugin 経由と legacy 経由の両方を使ってみる
```

### Phase 2: 部分移行

特定プロジェクトで plugin 側に切り替えたい場合、Claude Code の plugin 有効化設定を変更:

- 対象プロジェクトの `.claude/settings.json` で plugin を有効化
- プロジェクト固有の拡張（backend-specialist 等）は `.claude/agents/` に残す

### Phase 3: 完全移行（将来、オプション）

plugin の安定性を十分確認後、以下を段階的に実施:

- プロジェクトローカルの `.claude/{skills,commands,agents,rules}/` のうち、plugin で代替可能なものを削除
- プロジェクト固有のカスタマイズは `.claude/` に残す
- plugin は読み取り専用の base layer、`.claude/` は project-specific override として使い分け

**注意**: 完全移行は必須ではありません。デュアル運用のままでも問題ありません。

## 将来計画

### 短期（〜3 ヶ月）

- [ ] Plugin の runtime 検証（統合）完了
- [ ] Plugin バージョン 0.2.0（フィードバック反映）
- [ ] plugin 利用例の collection を収集

### 中期（3〜6 ヶ月）

- [ ] Hooks の実装本体（deterministic hooks: lint 自動実行、C-1 トリガー等）
- [ ] Test-engineer / release-manager agent の新規作成（必要性が確認されれば）
- [ ] Critical モード向け agents の拡充

### 長期（6 ヶ月〜）

- [ ] Marketplace 公開の検討（Claude Code 公式 marketplace）
- [ ] Codex CLI との統合 plugin（別 package として）
- [ ] 多言語化（英語 README、国際化対応）

※ 上記は現時点の構想であり、確約ではありません。

## FAQ

### Q. plugin を入れると既存の `.claude/` は動かなくなりますか？

**A.** いいえ。デュアル運用により、既存の `.claude/` はそのまま動作します。

### Q. plugin 版と `.claude/` 版で挙動に違いはありますか？

**A.** 同梱されている skills / commands / agents / rules の **内容は原本と完全一致**（rules 参照パスのみ plugin 内パスに書き換え）です。挙動の差はありません。

### Q. 自分のプロジェクト固有 agents を plugin に追加したい

**A.** 本 plugin 自体の改変は推奨しません。代わりに、利用先プロジェクトの `.claude/agents/` に配置してください。Claude Code は plugin 側と project 側を統合して認識します。

### Q. Codex CLI 側も plugin 化する予定は？

**A.** 現時点で計画なし。Codex CLI のエコシステムは別途（`openai-codex/codex` plugin 等）で整備されているため、本 plugin との統合は慎重に検討します。

### Q. 既存の `ai-dev-workflow` command がどう動くか分からない

**A.** plugin 導入前: `.claude/commands/ai-dev-workflow.md` が呼ばれる。plugin 導入後: Claude Code の解決順に依存（plugin 優先 or 同名の後勝ち）。明示的に plugin 側を呼ぶ場合は `plangate:ai-dev-workflow` 形式を試してください（runtime 検証推奨）。

## 参考リンク

- 親 Issue: [#16](https://github.com/s977043/plangate/issues/16)
- 子 Issues:
  - [#17 skeleton](https://github.com/s977043/plangate/issues/17)
  - [#18 skills + commands](https://github.com/s977043/plangate/issues/18)
  - [#19 agents + rules](https://github.com/s977043/plangate/issues/19)
  - [#20 README + migration note (this doc)](https://github.com/s977043/plangate/issues/20)
- Plugin manifest: [plugin/plangate/.claude-plugin/plugin.json](../plugin/plangate/.claude-plugin/plugin.json)
- Plugin README: [plugin/plangate/README.md](../plugin/plangate/README.md)
