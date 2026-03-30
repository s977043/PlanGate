# カスタムスラッシュコマンド一覧

## コマンド

| コマンド | 説明 | 引数 |
|---------|------|------|
| `/working-context` | チケット作業コンテキストの管理（作成・読込・保存） | `TASK-XXXX` / `save` / なし |
| `/ai-dev-workflow` | PlanGate ワークフロー v5 の各フェーズ実行 | `TASK-XXXX {brainstorm\|plan\|exec\|status}` |

## 使い方

```bash
# 作業コンテキストの新規作成・読み込み
/working-context TASK-1234

# 作業コンテキストの保存（セッション終了時）
/working-context save

# Plan生成 → セルフレビュー（15項目）→ 外部AIレビュー（一括自動実行）
/ai-dev-workflow TASK-1234 plan

# Agent実行（C-3承認後。多層防御検証 → PR作成まで自動）
/ai-dev-workflow TASK-1234 exec
```

## 関連ドキュメント

- PlanGateガイド: `docs/plangate.md`
- ワークフロー詳細・プロンプト集: `docs/ai-driven-development.md`
- 作業コンテキストルール: `.claude/rules/working-context.md`
