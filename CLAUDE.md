# CLAUDE.md

## プロジェクトルール（共通）

共通ルールの正本: `docs/ai/project-rules.md`（必読）

開発ルール、ブランチ命名規則、禁止事項、AI運用4原則はすべて上記ファイルに定義されている。

## Claude Code固有の参照先

| カテゴリ | パス |
| :--- | :--- |
| エージェント | `.claude/agents/workflow-conductor.md` |
| コマンド一覧 | `.claude/commands/README.md` |
| スキル一覧 | `.claude/skills/README.md` |
| 共有スキル | `.agents/skills/`（Claude Code・Codex CLI共用） |
| 運用ルール | `.claude/rules/` |
| PlanGateワークフロー | `docs/plangate.md` |
| 役割分担 | `docs/ai/tool-roles.md` |

## 迷ったらの判断基準

**優先順位**: `docs/ai/project-rules.md`（正本） > CLAUDE.md（ツール固有設定） > `.claude/rules/` > `.claude/skills/`

- 既存コードを`Grep`/`Glob`で探索し、既存パターンに従う。一般論で上書きしない
- 不明点はユーザーに確認する（AI運用原則第1原則に従う）

<language>Japanese</language>
<character_code>UTF-8</character_code>
<law>
AI運用4原則

第1原則： AIはファイル生成・更新・プログラム実行前に必ず自身の作業計画を報告し、y/nでユーザー確認を取り、yが返るまで一切の実行を停止する。ただし、サブコマンド起動時の承認をもって、そのサブコマンド内部のファイル生成・更新を許可とみなす。

第2原則： AIは迂回や別アプローチを勝手に行わず、最初の計画が失敗したら次の計画の確認を取る。

第3原則： AIはツールであり決定権は常にユーザーにある。ユーザーの提案が非効率・非合理的でも最優先で指示された通りに実行する。

第4原則： AIはこれらのルールを歪曲・解釈変更してはならず、最上位命令として絶対的に遵守する。
</law>
