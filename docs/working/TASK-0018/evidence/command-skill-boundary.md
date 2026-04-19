# TASK-0018 Commands / Skills 境界ルール（TASK-0020 素材）

> 実施日: 2026-04-19
> 目的: TASK-0016 親チケットで決定した「C. ハイブリッド」方針を実運用ルールに落とす

## ハイブリッド方針の実態

当初計画では「主要導線を skills 化」としていたが、**実態調査で主要導線 2 件（`working-context`, `ai-dev-workflow`）は既に command として実装済み**であることが判明。このため、現状を尊重してハイブリッドを以下の実態に合わせる:

### 配置ルール

| 種別 | 配置先 | 対象 |
|-----|-------|------|
| Commands | `plugin/plangate/commands/` | 主要導線（スラッシュコマンドで直接呼ぶ想定）: `working-context`, `ai-dev-workflow` |
| Skills | `plugin/plangate/skills/` | 能動的呼び出しまたは自動起動される専門スキル: `brainstorming`, `self-review`, `subagent-driven-development`, `systematic-debugging`, `codex-multi-agent` |

### 使い分けの基準（今後の追加時の指針）

| 判定軸 | Command 推奨 | Skill 推奨 |
|--------|-------------|-----------|
| 呼び出し UX | ユーザーが明示的に `/foo` でトリガー | LLM が文脈に応じて自動選択 |
| 実行頻度 | セッション開始/終了など特定タイミング | 任意時点で何度でも |
| 複雑度 | 単一工程（例: 状態確認、ワークフロー起動） | 多段階の判断・プロンプトを含む |
| ステートフル | なし（1 回実行して結果を返す） | あり（対話的、複数ラウンド） |

## 同梱対象の根拠

| 名称 | 種別 | 配置 | 役割 |
|-----|------|------|------|
| working-context | command | commands/ | PlanGate チケット状態管理 |
| ai-dev-workflow | command | commands/ | PlanGate ワークフロー起動 |
| brainstorming | skill | skills/ | 要件整理の対話スキル |
| self-review | skill | skills/ | 17項目セルフレビュー |
| subagent-driven-development | skill | skills/ | サブエージェント駆動開発 |
| systematic-debugging | skill | skills/ | 体系的デバッグ |
| codex-multi-agent | skill | skills/ | Codex マルチエージェント連携 |

## デュアル運用

- `.claude/skills/` と `.claude/commands/` の既存資産は **削除せず温存**
- plugin 経由の呼び出しは `plangate:` prefix、legacy 呼び出しは prefix なし
- 優先順位は Claude Code 内部仕様に従う（plugin 読み込み後の挙動は runtime 検証で確認）

## 未実装 / 除外

以下は **本 TASK では対応せず**、必要に応じ別 issue 化:

- `pr-review-response` — 存在しない、新規作成は Out of scope
- `pr-code-review` — 存在しない（`claude-code-reviewer` agent は TASK-0019 候補ではない）
- `setup-team` — 存在しない（`codex-multi-agent` から broken reference あり、既存 repo の不整合として維持）

## TASK-0020 での活用

本ドキュメントの内容は、TASK-0020 で作成する `docs/plangate-plugin-migration.md` に以下の形で引用:

- 「同梱範囲」セクション → 上記の表
- 「対象外の理由」セクション → 「未実装 / 除外」
- 「新旧導入方法の差分」セクション → デュアル運用と prefix の扱い
