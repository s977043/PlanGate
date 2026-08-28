---
name: subagent-team-design
description: "PlanGate のエージェント群（orchestrator / workflow-conductor / implementer 等）を前提としたチーム設計。タスクに応じたマルチエージェントチームを設計・構成する（旧 setup-team（plangate 版）の後継）。Use when: 「エージェントチームを組んで」「複数エージェントで実行したい」「並列実行チームを設計して」「どのエージェントを使うか決めて」「チームでこのタスクを進めて」。1エージェントで完結する小タスクには不要。"
---

# Subagent Team Design

タスクの規模・モードに応じて最適なマルチエージェントチームを設計し、各メンバーへの委譲準備を行うスキル。

## Common Rationalizations

| こう思ったら | 現実 |
|---|---|
| 「全部 implementer に任せれば速い」 | ロール分離がない実行は品質保証がない。チーム設計が速度を生む |
| 「チーム設計は時間がかかる」 | 役割が明確なほど各エージェントの出力品質が上がり、手戻りが減る |
| 「standard 以下でもチームを組む」 | ultra-light/light は 1 エージェントで完結。チーム設計はオーバーキル |

---

## ステップ 1: チームが必要か判定する

| モード | チーム設計 |
|--------|-----------|
| ultra-light / light | 不要。単一エージェントで完結 |
| standard | 実装 + レビューの 2 体が基本 |
| high-risk | 実装 + レビュー + テスト確認の 3 体以上 |
| critical | 全ロール（planner / implementer / reviewer / security-reviewer / test-reviewer）を配置 |

## ステップ 2: ロール定義を確認する

以下の 6 ロールを使用する。**本節が 6 ロール定義の正本**である。

> 旧正本 `plugin/plangate/rules/subagent-roles.md` は**削除済み**（TASK-0124 /
> `2645848`, 2026-06-02 の plugin 初回同期適用）。ロール定義は本節が引き継いだ。
> 派遣プロンプトの契約（必須 8 要素 / OUTCOME 契約 / 行動規範）は
> `docs/ai/subagent-delegation/README.md` を参照（ロール定義は含まない）。

**参照解決順（導入先で必ずこの順に探す）**: 本 Skill が参照する `docs/**` は上流リポジトリ基準の相対パスであり、`install.sh --claude` / plugin（Claude marketplace）/ Codex の **3 経路とも配布対象外**（解決不可）。(1) 導入先リポジトリの同名パスを探す → (2) 見つからなければ **「正本 `<path>` を参照できなかった」と明示**し、本 Skill 内の記述を代替正本として扱い、推測で内容を補わない。**plugin root 配下の探索は `docs/**` には適用しない**: plugin が配布するのは `agents` / `commands` / `skills` / `rules` 等の定義ディレクトリのみで `docs/` を配布対象として認識せず、plugin root 配下に相当する配布物が存在しないため、plugin root 段を置いても必ず空振りする（クラス A の rules 参照が plugin root 配下で解決できるのは `rules/` が実際に配布されるからであり、この非対称を `docs/**` に持ち込まない）。

| ロール | 責務 | 対応 subagent_type |
|--------|------|-------------------|
| planner | 要件分析・実行計画策定 | `Plan` または `plangate:spec-writer` |
| implementer | コード実装 | `plangate:implementer` または `implementation-agent` |
| reviewer | 設計・コード品質レビュー | `plangate:acceptance-tester` または `qa-reviewer` |
| security-reviewer | セキュリティ観点レビュー | `security-auditor` |
| test-reviewer | テスト品質・カバレッジ確認 | `test-engineer` |
| documentation-reviewer | ドキュメント整合性確認 | `documentation-writer` |

## ステップ 3: チーム構成を決定する

タスクの Work Breakdown（`plan.md`）を元にチームを設計する。

### 出力フォーマット

```yaml
team:
  - role: planner
    agent: plangate:spec-writer
    tasks: [TA-01]
    run_in_background: false

  - role: implementer
    agent: plangate:implementer
    tasks: [TA-02, TA-03]
    depends_on: [planner]
    run_in_background: true

  - role: reviewer
    agent: plangate:acceptance-tester
    tasks: [TA-04]
    depends_on: [implementer]
    run_in_background: false
```

## ステップ 4: 並列実行グループを特定する

`subagent-dispatch` スキルと連携して、依存関係グラフを生成する。

```
Phase A（並列可）: 依存関係のないタスク群 → run_in_background: true
Phase B（逐次）:  Phase A 完了後に実行するタスク群
```

## ステップ 5: 各エージェントへの委譲プロンプトを生成する

各エージェントへ渡すプロンプトに以下を含める。

```markdown
## 目的
{このエージェントが達成すべきゴール}

## 担当タスク
{Work Breakdown から割り当てられたタスク番号と内容}

## Allowed Context
{context-packager が生成した 6 要素: 対象ファイル / 仕様 / 既存テスト / 変更制約 / 実行コマンド / 禁止スコープ}

## 完了条件
{このエージェントの DONE 基準}

## 制約
- Allowed Context 外のファイルを変更しない
- 完了後に結果サマリを返す
```

## ステップ 6: キックオフする

並列実行可能なエージェントを同一メッセージで起動する。

```python
# Phase A: 並列起動（依存なし）
Agent(subagent_type="plangate:implementer", run_in_background=True, prompt="...")
Agent(subagent_type="plangate:implementer", run_in_background=True, prompt="...")

# Phase B: Phase A 完了後に逐次起動
Agent(subagent_type="plangate:acceptance-tester", run_in_background=False, prompt="...")
```

## 関連スキル

- `subagent-dispatch`: 依存関係グラフ生成と Allowed Context 付き dispatch
- `context-packager`: 各エージェントへ渡す Allowed Context を生成
- `codex-multi-agent`: Codex CLI を使う場合の並列エージェント実行
