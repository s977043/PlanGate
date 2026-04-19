# 10 新規 Skill × 既存 Skill 比較表

> 実施日: 2026-04-20
> 対象: 新規 10 個 × 既存 8 個（README.md 除く）= 80 通りの判定
> 判定種別: **新規** / 統合 / 共存

## 既存 Skill 一覧（8 個）

1. `brainstorming` - アイデアや要件を対話的に設計書へ昇華
2. `codex-multi-agent` - マルチエージェントでタスク分解・委譲・並列実行
3. `self-review` - 変更内容の詳細なセルフレビュー
4. `skill-creator` - 新規 Skill の対話的設計
5. `skill-ops-planner` - Skill 運用計画
6. `skill-optimizer` - 既存 Skill の最適化
7. `subagent-driven-development` - 実装計画タスクをサブエージェントに委譲
8. `systematic-debugging` - バグや障害の体系的調査

## 新規 10 Skill との比較判定

### Scan カテゴリ

| 新規 Skill | vs brainstorming | vs codex-multi-agent | vs self-review | vs skill-creator | vs skill-ops-planner | vs skill-optimizer | vs subagent-driven-development | vs systematic-debugging | 総合判定 |
|---|---|---|---|---|---|---|---|---|---|
| `context-load` | 類似なし（要件抽出ではなく前提抽出） | 無関係 | 無関係 | 無関係 | 無関係 | 無関係 | 無関係 | 無関係 | **新規** |
| `requirement-gap-scan` | brainstorming は対話で生成、本 Skill は抜け漏れ検出（目的差分あり / 共存） | 無関係 | 無関係 | 無関係 | 無関係 | 無関係 | 無関係 | 無関係 | **共存**（brainstorming と目的が異なる） |

### Check カテゴリ

| 新規 Skill | 比較結果 | 総合判定 |
|---|---|---|
| `nonfunctional-check` | 既存に類似なし（性能・保守性・安全性の体系チェック） | **新規** |
| `edgecase-enumeration` | 既存に類似なし（境界条件の列挙に特化） | **新規** |
| `risk-assessment` | 既存に類似なし（severity 付きリスク一覧） | **新規** |

### Design カテゴリ

| 新規 Skill | 比較結果 | 総合判定 |
|---|---|---|
| `acceptance-criteria-build` | 既存 `brainstorming` は AC を生成する側面があるが、こちらは AC を**明文化・構造化**する専用 Skill。目的差分あり | **共存** |
| `architecture-sketch` | 既存に類似なし（モジュール構成 / データフロー / 状態管理の設計スケッチ） | **新規** |

### Build カテゴリ

| 新規 Skill | 比較結果 | 総合判定 |
|---|---|---|
| `feature-implement` | 既存 `subagent-driven-development` は実装を**サブエージェントに委譲**する workflow。本 Skill は **個別の実装作業**を扱う。目的レベルが異なる | **共存** |

### Review カテゴリ

| 新規 Skill | 比較結果 | 総合判定 |
|---|---|---|
| `acceptance-review` | 既存 `self-review` は**全般的なセルフレビュー**。本 Skill は **AC 照合に特化**。使用場面が異なる | **共存** |
| `known-issues-log` | 既存に類似なし（妥協点・V2 候補を handoff に集約） | **新規** |

## 総合判定サマリ

| 判定 | 件数 | Skill |
|---|---|---|
| **新規** | 6 | `context-load`, `nonfunctional-check`, `edgecase-enumeration`, `risk-assessment`, `architecture-sketch`, `known-issues-log` |
| **共存** | 4 | `requirement-gap-scan`, `acceptance-criteria-build`, `feature-implement`, `acceptance-review` |
| 統合 | 0 | - |

## 共存理由の詳細

### `requirement-gap-scan` vs `brainstorming`

- `brainstorming`: 対話的ドリルダウンで PBI INPUT PACKAGE を**生成**する
- `requirement-gap-scan`: 既存要件から**抜け漏れを検出**して追加候補を列挙する
- 呼び出されるタイミング / 目的が異なる。brainstorming 後の後工程として本 Skill が使われる

### `acceptance-criteria-build` vs `brainstorming`

- `brainstorming`: 要件の骨子を対話で作る（AC は副次的）
- `acceptance-criteria-build`: 確定した要件から **AC を構造化して明文化**する（機械検証可能な形に整理）
- Work の粒度と出力の形が異なる

### `feature-implement` vs `subagent-driven-development`

- `subagent-driven-development`: 計画を複数のサブエージェントに**委譲してオーケストレーション**する
- `feature-implement`: 1 つの実装タスクを **TDD で回す**
- 粒度が異なり、subagent-driven-development から feature-implement を呼び出す関係

### `acceptance-review` vs `self-review`

- `self-review`: 変更内容全般のセルフレビュー（コード品質 / 構造 / 一貫性）
- `acceptance-review`: **AC 照合に特化**（適合 / 不足 / 保留の判定）
- 同じ PR で両方が使われることも想定（補完関係）

## 結論

- **統合すべき Skill は 0 件**（既存と目的が完全に重なる Skill はない）
- **新規 6 件 + 共存 4 件 = 10 件**が妥当
- 共存 Skill は呼び出し文脈が明確に分離されており、README などで棲み分けを説明すれば運用上の混乱は発生しない
