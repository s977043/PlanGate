# Contributing

Thanks for helping improve PlanGate.

## Workflow

1. Open an issue for non-trivial changes so the intent is visible.
2. Create a branch from `main`.
3. Keep pull requests small and focused.
4. Fill in the pull request template and list the checks you ran.
5. Wait for CI and review before merging.

## Quality Bar

- Prefer clear, maintainable changes over cleverness.
- Update documentation when behavior or usage changes.
- Avoid committing secrets, local credentials, or generated build artifacts.
- Call out security or compatibility tradeoffs in the pull request.

---

## 日本語による貢献ガイド

PlanGate は日本語での貢献を歓迎しています。

### PlanGate の貢献フロー

PlanGate 自身のワークフローに従って貢献を進めてください。

```text
1. Issue を開く（意図を共有する）
2. pbi-input.md を作成する（What / Why / 受入基準を記述）
3. /ai-dev-workflow plan で plan / todo / test-cases を生成する
4. C-3 ゲート: plan.md を人間がレビューし APPROVE / CONDITIONAL / REJECT を判断する
5. /ai-dev-workflow exec で実装・テスト・PR 作成まで自動実行する
6. C-4 ゲート: GitHub PR を人間がレビューしてマージする
```

`good first issue` ラベルがついた Issue は、初めて貢献する方に適した範囲・難易度のタスクです。まずはそこから始めることを推奨します。

### 開発環境のセットアップ

PlanGate は Claude Code と Codex CLI を前提にしています。

#### Option A — Plugin として利用する（推奨）

```bash
git clone https://github.com/s977043/plangate.git
# Claude Code 公式のプラグイン登録手順に従う
# 参照: plugin/plangate/README.md
```

#### Option B — `.claude/` を直接配置する

```bash
git clone https://github.com/s977043/plangate.git
cp -r plangate/.claude/ your-project/.claude/
```

どちらか一方を選択してください。両方を適用すると競合が発生します。

### コミットメッセージ規約

Conventional Commits に従います。

| プレフィックス | 用途 |
| --- | --- |
| `feat:` | 新機能追加 |
| `fix:` | バグ修正 |
| `docs:` | ドキュメントのみの変更 |
| `chore:` | ビルド・設定・依存関係の変更 |
| `refactor:` | リファクタリング（機能変更なし） |
| `test:` | テスト追加・修正 |

例: `feat: add gate enforcement spec (c3.json + plan_hash)`

### Adding a New Provider

PlanGate separates workflow governance from AI tool implementation.
To add support for a new provider (e.g. a new CLI tool):

1. Open an issue referencing [Issue #82](https://github.com/s977043/plangate/issues/82) to discuss the provider's capabilities.
2. Create a RFC document at `docs/rfc/provider-<name>.md` using an existing RFC as a template.
3. Identify which role(s) the provider fills (planner / implementer / reviewer / external-reviewer).
4. Update `workflows/*.yaml` to reference the new provider type.
5. Submit a PR with the RFC and any required harness changes.

Do not implement provider support without an approved RFC — governance compatibility
must be verified before merging.

### CI について

PR には `Markdown lint` の必須チェックがあります。ローカルで確認するには:

```bash
npx markdownlint-cli2 "**/*.md" --ignore node_modules
```
