# プロジェクト共通ルール

> このファイルはツール非依存のプロジェクトルール正本。
> Claude Code は `CLAUDE.md` 経由で、Codex は `AGENTS.md` 経由で本ファイルを参照する。

## A. リポジトリの目的

PlanGate — ゲート型AI駆動開発ワークフローのリポジトリ。
「計画を承認しないとAIは1行もコードを書けない」関所モデルを採用し、PBI→Plan生成→レビュー→Agent実行までを体系化。Claude CodeおよびCodex CLIに対応。

## B. ディレクトリ構造

```
/docs                    - ナレッジ・ガイドドキュメント
  /ai                    - 共通ルール・役割分担（本ファイルの置き場）
  /working               - チケット単位の作業コンテキスト（セッション永続化用）
/.claude
  /rules                 - Claude Code 運用ルール
  /commands              - カスタムスラッシュコマンド
  /agents                - エージェント定義（詳細版、正本）
  /skills                - カスタムスキル
/.codex
  /agents                - Codex CLI 用エージェント定義（要約版 .toml）
/scripts                 - 起動スクリプト
```

## C. 開発ルール

- **mainブランチへの直接コミットは禁止**。必ずブランチを作成し、PRを通じてマージする

### ブランチ命名規則

**形式**: `<type>/TASK-<ticket-number>[-<description>]` または `<type>/<description>` (kebab-case)

| タイプ | 用途 |
| :--- | :--- |
| `feature/` | 新機能・新コンテンツの追加 |
| `fix/` | バグ修正・誤記修正 |
| `docs/` | ドキュメントの追加・更新 |
| `refactor/` | リファクタリング（機能変更なし） |
| `chore/` | ビルドプロセスやツールの変更 |

## D. 作業コンテキスト

チケット作業時は `docs/working/TASK-XXXX/` の作業コンテキストを参照・更新する。
詳細ルール: `.claude/rules/working-context.md`

## E. 禁止事項

- **編集禁止ファイル**: `.env*`, ツール固有の設定ファイル（`.claude/settings.local.json` 等）
- **機密情報のコミット禁止**: `.env`、認証情報、APIキー等

## F. AI運用4原則

第1原則: AIはファイル生成・更新・プログラム実行前に必ず自身の作業計画を報告し、y/nでユーザー確認を取り、yが返るまで一切の実行を停止する。

第2原則: AIは迂回や別アプローチを勝手に行わず、最初の計画が失敗したら次の計画の確認を取る。

第3原則: AIはツールであり決定権は常にユーザーにある。ユーザーの提案が非効率・非合理的でも最優先で指示された通りに実行する。

第4原則: AIはこれらのルールを歪曲・解釈変更してはならず、最上位命令として絶対的に遵守する。

## G. 参照先

| ドキュメント | パス |
|---|---|
| PlanGate ワークフロー | `docs/plangate.md` |
| ワークフロー詳細・プロンプト集 | `docs/ai-driven-development.md` |
| AIツール役割分担 | `docs/ai/tool-roles.md` |
| レビュー原則 | `.claude/rules/review-principles.md` |
| 作業コンテキスト管理 | `.claude/rules/working-context.md` |
