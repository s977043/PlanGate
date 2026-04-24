# PlanGate

PlanGate は、AI コーディングエージェントをプロダクション開発で扱うためのゲート型ワークフローです。

「計画を承認しないと AI は 1 行もコードを書けない」という関所モデルを中核に、PBI から計画、承認、実装、検証、handoff までを構造化します。

![Harness Engineering と PlanGate の関係](docs/assets/harness-plangate-readme-dark-v2.png)

## 何を目指すか

PlanGate は、AI エージェントを単体の便利な実装者としてではなく、承認境界・成果物・検証手順を持つ開発ハーネスの中で動かすことを目指します。

一般的なハーネスエンジニアリングが「AI を安全に動かす外枠」を整えるものだとすれば、PlanGate はその外枠の中で次を具体化します。

- 計画が承認されるまで実装を始めない
- 承認・差し戻し・再実行の境界を明確にする
- 実装前に計画、タスク、テスト観点を成果物として残す
- 実装後に受け入れ検査、レビュー、handoff を残す
- 判断基準とコンテキストを個人の記憶ではなくファイルに固定する

## 向き合う課題

AI コーディングは速い一方で、運用の外枠が弱いと次の問題が起きやすくなります。

- AI 実装が計画より先行しやすい
- 承認や責任境界が曖昧になりやすい
- 検証が後付けになり、品質保証が不安定になりやすい
- コンテキストや評価基準がセッションや個人に依存しやすい
- 完了判断の根拠が PR や会話ログに散らばりやすい

PlanGate はこれらを注意力ではなく、ワークフロー、ゲート、成果物、再利用可能な Skill / Agent の分離によって抑えます。

詳細な思想と問題設定は [docs/philosophy.md](docs/philosophy.md) を参照してください。

## 中核アイデア

| アイデア | 内容 |
| --- | --- |
| 計画先行 | PBI から plan / todo / test-cases を作り、承認前の実装を禁止する |
| ゲート制御 | C-3（計画承認）と C-4（PR レビュー）で人間の判断点を固定する |
| 検証内蔵 | L-0 / V-1〜V-4 により、実装後の検証をワークフローに組み込む |
| 状態の永続化 | `docs/working/TASK-XXXX/` に計画、レビュー、検証、handoff を残す |
| 実行層の分離 | v7 では Workflow / Skill / Agent を分け、再利用性と拡張性を高める |

## クイックスタート

詳細: [docs/plangate.md](docs/plangate.md)

```bash
# 1. 作業コンテキスト作成
/working-context TASK-XXXX

# 2. Plan + ToDo + Test Cases 生成、セルフレビュー、外部 AI レビュー
/ai-dev-workflow TASK-XXXX plan

# 3. 人間レビュー（PlanGate ゲート）後、Agent 実行
/ai-dev-workflow TASK-XXXX exec
```

## リポジトリ構成

```text
/docs                    - ナレッジ・ガイドドキュメント
  /ai                    - 共通ルール・役割分担
  /workflows             - v7 Workflow 定義
  /working               - チケット単位の作業コンテキスト
/.claude                 - Claude Code 固有の設定
/.codex                  - Codex CLI 固有の設定
/plugin/plangate         - Claude Code plugin 配布パッケージ
/scripts                 - 起動スクリプト
```

## Claude Code + Codex CLI

PlanGate は Claude Code と Codex CLI の併用を前提にしています。共通ルールは [docs/ai/project-rules.md](docs/ai/project-rules.md) に一元化し、ツール固有の入口ファイルは薄く保ちます。

| ツール | 入口ファイル | 固有設定 |
| --- | --- | --- |
| Claude Code | [CLAUDE.md](CLAUDE.md) | `.claude/` |
| Codex CLI | [AGENTS.md](AGENTS.md) | `.codex/` |
| 共通 | [docs/ai/project-rules.md](docs/ai/project-rules.md) | `docs/`, `scripts/` |

役割分担の詳細: [docs/ai/tool-roles.md](docs/ai/tool-roles.md)

## Read Next

| ドキュメント | 内容 |
| --- | --- |
| [docs/philosophy.md](docs/philosophy.md) | 思想、問題設定、ハーネスエンジニアリング上の位置づけ |
| [docs/index.md](docs/index.md) | GitHub Pages 用の公開ドキュメント入口 |
| [docs/plangate.md](docs/plangate.md) | PlanGate ガイド、運用手順、フェーズ説明 |
| [docs/plangate-v7-hybrid.md](docs/plangate-v7-hybrid.md) | v7 ハイブリッドアーキテクチャ |
| [docs/workflows/README.md](docs/workflows/README.md) | WF-01〜WF-05 の Workflow 定義 |
| [docs/plangate-plugin-migration.md](docs/plangate-plugin-migration.md) | Claude Code plugin としての利用・移行 |
| [docs/oss-governance.md](docs/oss-governance.md) | OSS 公開設定・運用判断 |
| [CHANGELOG.md](CHANGELOG.md) | 主要リリース履歴 |

## 解説記事

- [AIコーディングの暴走を「仕組み」で止める — PlanGateという開発フロー](https://note.com/mine_unilabo/n/n3aae6b5467b9)（note）

## ライセンス

[MIT](LICENSE)
