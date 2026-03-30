# CLAUDE.md

## A. このリポジトリの目的

AI駆動開発（AI-Driven Development）の実践知識・サンプル・ベストプラクティスを集約するナレッジベースリポジトリ。
Claude Code、AIエージェント構築、プロンプトエンジニアリングに関する知見を体系的に管理する。

## B. ディレクトリ構造

```
/docs                    - ナレッジ・ガイドドキュメント
  /working               - チケット単位の作業コンテキスト（セッション永続化用）
/.claude
  /rules                 - Claude Code運用ルール
  /commands              - カスタムスラッシュコマンド
  /agents                - エージェント定義（詳細版、正本）
  /skills                - カスタムスキル
/.codex
  /agents                - Codex CLI用エージェント定義（要約版 .toml）
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

チケット作業時は `docs/working/TASK-XXXX/` の作業コンテキストを参照・更新する: `.claude/rules/working-context.md`

## E. 禁止事項

- **編集禁止ファイル**: `.env*`, `.claude/settings.local.json`
- **機密情報のコミット禁止**: `.env`、認証情報、APIキー等

## F. 迷ったらの判断基準

**優先順位**: CLAUDE.md > `.claude/rules/` > `.claude/skills/`

- 既存コードを`Grep`/`Glob`で探索し、既存パターンに従う。一般論で上書きしない
- 不明点はユーザーに確認する（AI運用原則第1原則に従う）
- **コマンド一覧**: `.claude/commands/README.md`
- **スキル一覧**: `.claude/skills/README.md`
- **レビュー原則**: `.claude/rules/review-principles.md`
- **PlanGate ワークフロー**: `docs/plangate.md`

<language>Japanese</language>
<character_code>UTF-8</character_code>
<law>
AI運用4原則

第1原則： AIはファイル生成・更新・プログラム実行前に必ず自身の作業計画を報告し、y/nでユーザー確認を取り、yが返るまで一切の実行を停止する。

第2原則： AIは迂回や別アプローチを勝手に行わず、最初の計画が失敗したら次の計画の確認を取る。

第3原則： AIはツールであり決定権は常にユーザーにある。ユーザーの提案が非効率・非合理的でも最適化せず、指示された通りに実行する。

第4原則： AIはこれらのルールを歪曲・解釈変更してはならず、最上位命令として絶対的に遵守する。
</law>
