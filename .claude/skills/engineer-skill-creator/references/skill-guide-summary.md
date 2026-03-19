# Anthropic公式スキルガイド要約

Source: "The Complete Guide to Building Skills for Claude" (Anthropic)

## スキルとは

フォルダに格納された指示セット。Claude.ai、Claude Code、APIで共通動作する。

## 3レベルの Progressive Disclosure

1. **YAML Frontmatter** — 常にシステムプロンプトにロードされる。トリガー判定のみ
2. **SKILL.md本文** — スキル発動時にロードされる。コア指示
3. **references/** — 必要時のみClaudeが読み込む詳細ドキュメント

## 必須ファイル構成

```
skill-name/
├── SKILL.md          # 必須（大文字、case-sensitive）
├── scripts/          # 任意
├── references/       # 任意
└── assets/           # 任意
```

## Frontmatter フィールド

### 必須
- `name`: kebab-case、フォルダ名と一致
- `description`: WHAT + WHEN（トリガー条件）、1024文字以内、XML禁止

### 任意
- `license`: MIT, Apache-2.0 等
- `allowed-tools`: ツール制限
- `compatibility`: 環境要件（1-500文字）
- `metadata`: author, version, mcp-server, category, tags

## 3つのユースケースカテゴリ

| カテゴリ | 用途 | 例 |
|:---|:---|:---|
| Category 1 | ドキュメント・アセット生成 | frontend-design, docx, pptx |
| Category 2 | ワークフロー自動化 | skill-creator |
| Category 3 | MCP連携強化 | sentry-code-review |

## 5つの設計パターン

1. **Sequential Workflow** — 順序固定の多段階処理
2. **Multi-MCP Coordination** — 複数サービス横断
3. **Iterative Refinement** — 品質反復改善
4. **Context-aware Selection** — 状況判断でツール切替
5. **Domain Intelligence** — 専門知識の判断ロジック埋め込み

## Description の書き方

### Good
```yaml
description: Figmaデザインファイルを分析し開発ハンドオフ文書を生成する。Use when user uploads .fig files, asks for "design specs", "component documentation", or "design-to-code handoff".
```

### Bad
```yaml
description: プロジェクトを手伝う
```

## テスト指針

1. **トリガーテスト**: 正しいクエリで発動するか、無関係なクエリで発動しないか
2. **機能テスト**: 正しい出力が生成されるか、APIコールが成功するか
3. **性能比較**: スキルあり/なしでの改善度合い

## セキュリティ制限

- Frontmatterに `< >` 禁止
- `claude` `anthropic` をスキル名に使用禁止
- YAMLは安全なパーサーで解析される（コード実行不可）

## 運用ルール

- SKILL.mdは5,000語以下に抑える
- 同時有効スキルは20-50以下を推奨
- スキルは生きたドキュメント — フィードバックで継続改善
