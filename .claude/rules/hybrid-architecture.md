# ハイブリッドアーキテクチャ Rule（正本）

> PlanGate v7 ハイブリッドアーキテクチャの **設計原則と境界ルール**。
> 親 PBI: [#22](https://github.com/s977043/plangate/issues/22)
> 詳細解説: [docs/plangate-v7-hybrid.md](../../docs/plangate-v7-hybrid.md)

## Rule 1〜5（再構築ルール）

| Rule | 内容 |
|------|------|
| **Rule 1** | **Workflow は順序と完了条件だけを持つ**。実装ノウハウは書かない |
| **Rule 2** | **Skill は再利用単位に限定する**。案件固有の話を入れない |
| **Rule 3** | **Agent は責務だけを持つ**。ツール固有手順や案件固有仕様は持たせない |
| **Rule 4** | **案件固有情報は CLAUDE.md に寄せる**。Agent や Skill に埋め込まない |
| **Rule 5** | **最終成果物は毎回 handoff に集約する**。仕様 / 既知課題 / V2 候補 / 確認結果を残す |

## Rule 別の適用先

### Rule 1: Workflow（順序と完了条件のみ）

- 配置: `docs/workflows/0N_*.md`
- 必須セクション: 目的 / 入力 / 完了条件 / 呼び出す Skill / 主担当 Agent
- **書いてはいけないこと**: 実装コード、具体的な手順、ツールの細かい操作
- **書くべきこと**: 「何が終わっていれば次 phase に進めるか」

### Rule 2: Skill（再利用単位、案件固有なし）

- 配置: `.claude/skills/<skill-name>/SKILL.md`
- 必須: frontmatter（name, description）+ 本文構造（入力 / 出力 / 想定 phase / カテゴリ / 役割）
- **書いてはいけないこと**: プロジェクト名、特定フレームワーク前提、特定リポジトリの具体仕様
- **書くべきこと**: どのプロジェクトでも再利用できる観点・手順

### Rule 3: Agent（責務のみ、ツール固有なし）

- 配置: `.claude/agents/<agent-name>.md`
- 必須: frontmatter（name, description, tools, model）+ 本文（責務 / 委譲関係 / 呼び出し Skill / ツール使用方針）
- **書いてはいけないこと**: 特定ツールの細かい使い方、案件固有仕様
- **書くべきこと**: 単一責務、他 Agent への委譲ルール

### Rule 4: 案件固有情報 は CLAUDE.md

- 配置: プロジェクトルート `CLAUDE.md`（+ 必要に応じて `.claude/rules/`, `AGENTS.md`）
- 例: プロジェクトルール、技術スタック、禁止事項、ドメイン用語

### Rule 5: 最終成果物は handoff に集約

- 配置: `docs/working/TASK-XXXX/handoff.md`（全 PBI で必須）
- 必須 6 要素: 要件適合確認 / 既知課題 / V2 候補 / 妥協点 / 引き継ぎ文書 / テスト結果
- テンプレート: [`docs/working/templates/handoff.md`](../../docs/working/templates/handoff.md)
- 例外: critical インシデント対応等、緊急度が極めて高い場合は事後追補で可

## CLAUDE.md / Skill / Hook の境界ルール

Rule 4 を補完する **強制力の軸** での境界:

| 対象 | 役割 | 置き場所 | 強制力 |
|------|------|---------|-------|
| **CLAUDE.md** | 案件固有情報、常時必要な文脈 | プロジェクトルート | ソフト（LLM が参照） |
| **Skill** | 再利用可能な手順・観点（必要時だけ読み込む） | `.claude/skills/` or `.claude/commands/` | ソフト（LLM が呼び出し） |
| **Hook** | 強制力が必要な決定論的制御（100% 強制） | `.claude/settings.json` の hooks | **ハード**（harness が実行） |

### 使い分けの判断基準

| 用途 | 推奨配置 |
|------|---------|
| プロジェクトのルール・制約 | CLAUDE.md |
| 再利用可能な観点・チェックリスト | Skill |
| 「絶対に通さない」制御（例: plan 未作成なら block） | Hook |

## ガバナンス層 × 実行層 接続

| 統制層（PlanGate） | 実行層（Workflow / Skill / Agent） |
|-------------------|--------------------------------|
| GATE（計画を止める） | Workflow phase 完了条件で制御 |
| STATUS（状態を保存） | status.md + current-state.md + handoff.md |
| APPROVAL（承認管理） | C-3 ゲート / C-4 ゲート |
| ARTIFACT（成果物正本化） | plan.md / design.md / handoff.md |

## 既存ルール との関係

| 既存ルール | 本ルールとの関係 |
|----------|---------------|
| [`working-context.md`](./working-context.md) | v5/v6 ワークフローと handoff 必須化を規定。本ルールはそれを補完 |
| [`review-principles.md`](./review-principles.md) | レビュー原則（CI / ローカル共通）。本ルールと並立 |
| [`mode-classification.md`](./mode-classification.md) | 5 段階モード分類。本ルールと並立 |

## 違反時の検出

| Rule | 機械検出方法 |
|------|------------|
| Rule 1 | `grep -l "実装方法\|コード例\|\\\`\\\`\\\`typescript\|\\\`\\\`\\\`python" docs/workflows/0*.md` → 0 件 |
| Rule 2 | `grep -l "プロジェクト固有\|このプロジェクト\|TASK-" .claude/skills/<new>/SKILL.md` → 0 件 |
| Rule 3 | `grep -l "Laravel\|PostgreSQL\|ECS\|Cloudflare" .claude/agents/<new>.md` → 0 件 |
| Rule 4 | Agent / Skill 内に特定プロジェクト名が無いことを確認 |
| Rule 5 | 全 PBI で `docs/working/TASK-XXXX/handoff.md` 存在確認 |

手動レビューと組み合わせて運用する。

## 参照

- 親 PBI: [#22 TASK-0021](https://github.com/s977043/plangate/issues/22)
- 詳細ドキュメント: [docs/plangate-v7-hybrid.md](../../docs/plangate-v7-hybrid.md)
- Workflow 定義: [docs/workflows/README.md](../../docs/workflows/README.md)
- Skill マッピング: [docs/workflows/skill-mapping.md](../../docs/workflows/skill-mapping.md)
- 実行シーケンス: [docs/workflows/execution-sequence.md](../../docs/workflows/execution-sequence.md)
- handoff テンプレート: [docs/working/templates/handoff.md](../../docs/working/templates/handoff.md)
