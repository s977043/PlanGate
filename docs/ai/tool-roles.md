# AIツール役割分担ガイド

> Claude Code と Codex CLI の併用時の役割分担・運用パターンを定義する。

## ツール特性の比較

| 特性 | Claude Code | Codex CLI |
|------|------------|-----------|
| 対話性 | 高い（チャット型） | 低い（バッチ型） |
| コンテキスト | 大（1Mトークン） | 制限あり |
| ファイル操作 | Read/Write/Edit 全般 | サンドボックス内操作 |
| 探索 | Grep/Glob で高速 | コマンドベース |
| マルチエージェント | Agent tool で委譲 | config.toml で定義 |
| MCP | hooks + MCP サーバー連携 | config.toml で MCP 定義 |
| セッション | 対話的、自動メモリ | バッチ実行、セッションログ |
| 適性 | 対話的思考、探索、レビュー | バッチ実行、差分生成、反復修正 |

## 役割分担（基本方針）

### Claude Code の担当領域

- **探索・分析**: コードベース調査、影響範囲特定、Gap検出
- **対話的設計**: brainstormingスキルによるPBI INPUT PACKAGE生成
- **レビュー**: self-reviewスキル、review-principles適用
- **PlanGate planフェーズ**: B（計画生成）、C-1（セルフレビュー）、C-2（外部レビュー）
- **ワークフロー制御**: `/ai-dev-workflow`、`/working-context` コマンド
- **デバッグ**: systematic-debuggingスキル
- **横断リファクタ**: 大コンテキストを活かした広範囲の変更分析

### Codex CLI の担当領域

- **バッチ実装**: 計画に基づく並列タスク実行
- **差分生成**: 明確なタスク仕様に基づく機械的なファイル変更
- **ドキュメント生成**: documentation_writerエージェントによる定型ドキュメント
- **PlanGate execフェーズ**: D（Agent実行）以降の機械的実行
- **反復的な修正**: 設定変更、テンプレート適用、パターンの横展開

## 併用フローパターン

### パターン1: 標準PlanGateフロー（推奨）

```
1. Claude Code: /working-context TASK-XXXX（コンテキスト準備）
2. Claude Code: /ai-dev-workflow TASK-XXXX brainstorm（要件整理）
3. Claude Code: /ai-dev-workflow TASK-XXXX plan（計画生成+レビュー）
4. 人間: C-3ゲート承認
5. Codex CLI: plan.md + todo.md に基づくバッチ実装
6. Claude Code: 実装結果のレビュー + PR作成
```

Claude Code の対話的探索・計画能力と、Codex の安定したバッチ実行を組み合わせる最も堅い構成。

### パターン2: 探索 → 実装

```
1. Claude Code: コードベース探索・影響範囲分析
2. Claude Code: 変更方針のドラフト作成
3. Codex CLI: ドラフトに基づく機械的変更の実行
4. Claude Code: 変更結果のレビュー
```

PlanGateの正式フローを経ない小規模な変更に適用。

### パターン3: Codex 単独（小規模変更）

```
1. Codex CLI: 明確なタスクの単独実行
```

typo修正、テンプレートファイル生成、設定値変更など、探索やレビューが不要な定型作業。

## やらないこと

- **MCP を両方に無差別公開しない**: 外部取得系・書き込み系は権限境界を切る
- **コマンド体系を分裂させない**: 共通のスクリプトを `scripts/` に寄せる
- **CLAUDE.md と AGENTS.md に同じ長文を二重管理しない**: 共通ルールは `docs/ai/project-rules.md` に一元化

## ツール固有の設定ファイル

| ツール | 設定の所在 |
|--------|-----------|
| Claude Code | `CLAUDE.md`（入口）→ `.claude/agents/`, `.claude/commands/`, `.claude/skills/`, `.claude/rules/` |
| Codex CLI | `AGENTS.md`（入口）→ `.codex/config.toml`, `.codex/instructions.md`, `.codex/agents/*.toml` |
| 共通 | `docs/ai/project-rules.md`（正本）、`docs/plangate.md`（ワークフロー） |
