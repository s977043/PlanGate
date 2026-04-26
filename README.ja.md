# PlanGate

> 「承認なし、コードなし」― AI コーディングエージェントのためのゲート型ワークフロー

[![GitHub release](https://img.shields.io/github/v/release/s977043/plangate)](https://github.com/s977043/plangate/releases)
[![CI](https://github.com/s977043/plangate/actions/workflows/ci.yml/badge.svg)](https://github.com/s977043/plangate/actions/workflows/ci.yml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/s977043/plangate/badge)](https://securityscorecards.dev/viewer/?uri=github.com/s977043/plangate)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![English](https://img.shields.io/badge/lang-English-blue)](README.md)

PlanGate は、AI コーディングエージェントのためのガバナンス優先ワークフローハーネスです。
人間が承認した計画・タスク・受入テストが揃うまで、AI にプロダクションコードを書かせません。

一般的なエージェントフレームワークが「自律性」を重視するのに対し、PlanGate は **承認境界・監査可能性・スクラム親和性** を重視します。

![PlanGate overview](docs/assets/harness-plangate-readme-dark-v2.png)

## インストール

### Option A: clone + plugin 登録（推奨）

```bash
git clone https://github.com/s977043/plangate.git
cd plangate
```

その後、[Claude Code plugin 登録手順](plugin/plangate/README.md) に従うか、`.claude/` をプロジェクトにコピーしてください。

### Option B: `.claude/` を直接コピー

```bash
git clone https://github.com/s977043/plangate.git
cp -r plangate/.claude/ your-project/.claude/
```

> [!WARNING]
> **同じプロジェクトで両方の方法を使わないでください。**
> plugin のインストールと `.claude/` のコピーを併用すると、Skill・コマンドの重複解決が起きます。
> どちらか一方を選択してください。詳細は [plugin 移行ガイド](docs/plangate-plugin-migration.md) を参照してください。

## 仕組み

PlanGate は AI 実装の前後に 2 つの人間承認ゲートを設けます。

| ゲート | タイミング | 判断 |
| --- | --- | --- |
| **C-3** | 計画レビュー後、実装前 | APPROVE / CONDITIONAL / REJECT |
| **C-4** | AI 実装後、GitHub PR 上 | APPROVE / REQUEST CHANGES |

```text
人間が PBI を書く → AI が計画を生成 → [C-3: 人間が承認]
→ AI が実装（TDD）→ 自動検証（L-0, V-1…V-4）
→ PR 作成 → [C-4: 人間が GitHub でレビュー] → マージ
```

| 中核アイデア | 内容 |
| --- | --- |
| 計画先行 | PBI から plan / todo / test-cases を作り、承認前の実装を禁止する |
| ゲート制御 | C-3（計画承認）と C-4（PR レビュー）で人間の判断点を固定する |
| 検証内蔵 | L-0 / V-1〜V-4 により、実装後の検証をワークフローに組み込む |
| 状態の永続化 | `docs/working/TASK-XXXX/` に計画、レビュー、検証、handoff を残す |
| 実行層の分離 | v7 では Workflow / Skill / Agent を分け、再利用性と拡張性を高める |

## クイックスタート

```bash
# 1. 作業コンテキスト作成
/working-context TASK-XXXX

# 2. Plan + ToDo + Test Cases 生成、セルフレビュー
/ai-dev-workflow TASK-XXXX plan

# 3. [C-3 ゲート] 人間がレビュー後、実行
/ai-dev-workflow TASK-XXXX exec
```

詳細: [docs/plangate.md](docs/plangate.md)

## 10 分チュートリアル

### ステップ 1: 作業コンテキストを作成する

```bash
/working-context TASK-0001
```

`docs/working/TASK-0001/pbi-input.md` と関連する成果物ファイルが作成されます。

### ステップ 2: PBI INPUT PACKAGE を記入する（人間作業）

`docs/working/TASK-0001/pbi-input.md` を編集します。

- **Why** — ビジネスコンテキスト、解決する問題
- **What** — スコープの内外
- **受入基準** — 検証可能・テスト可能な条件

### ステップ 3: 計画を生成する

```bash
/ai-dev-workflow TASK-0001 plan
```

AI が `plan.md`、`todo.md`、`test-cases.md`、`review-self.md` を生成します。

### ステップ 4: C-3 ゲート — 人間がレビューして承認する（人間作業）

`docs/working/TASK-0001/plan.md` を読み、判断します。

- **APPROVE** → exec に進む
- **CONDITIONAL** → 必要な修正を記録して進む
- **REJECT** → PBI を修正して計画を再生成する

### ステップ 5: 実行する

```bash
/ai-dev-workflow TASK-0001 exec
```

AI が TDD で実装し、lint 修正（L-0）、受け入れ検査（V-1）、外部レビュー（V-3）を実行して PR を作成します。

### ステップ 6: C-4 ゲート — GitHub で PR レビューする（人間作業）

GitHub 上で PR をレビューし、準備ができたらマージします。完了です。

全成果物ファイルの完成例は `examples/sample-task/` を参照してください。

## Plugin vs `.claude/` の違い

| | Plugin（plugin 登録経由） | `.claude/` コピー |
| --- | --- | --- |
| **用途** | 複数プロジェクトのベースレイヤー | 単一プロジェクトまたは完全カスタマイズ |
| **更新** | 再 clone と再登録 | 手動 `git pull` |
| **カスタマイズ** | プロジェクトの `.claude/` が plugin を上書き | 直接編集 |
| **競合リスク** | 低い（スキル・コマンドが名前空間で管理） | なし |

技術的には両方の共存も可能です。Plugin がベースを提供し、プロジェクトの `.claude/` が上書きします。
登録手順は [plugin/plangate/README.md](plugin/plangate/README.md) を参照してください。

## リポジトリ構成

```text
/docs                    — ナレッジ・ワークフロードキュメント
  /ai                    — 共通ルール・役割分担
  /workflows             — v7 Workflow 定義（WF-01〜WF-05）
  /working               — チケット単位の作業コンテキスト（TASK-XXXX/）
/.claude                 — Claude Code 設定
/.codex                  — Codex CLI 設定
/plugin/plangate         — Claude Code plugin パッケージ
/scripts                 — ヘルパースクリプト
/examples                — PlanGate 成果物の完成例
```

## Claude Code + Codex CLI

PlanGate は Claude Code と Codex CLI の併用を前提にしています。共通ルールは [docs/ai/project-rules.md](docs/ai/project-rules.md) に一元化し、ツール固有の入口ファイルは薄く保ちます。

| ツール | 入口ファイル | 固有設定 |
| --- | --- | --- |
| Claude Code | [CLAUDE.md](CLAUDE.md) | `.claude/` |
| Codex CLI | [AGENTS.md](AGENTS.md) | `.codex/` |
| 共通 | [docs/ai/project-rules.md](docs/ai/project-rules.md) | `docs/`、`scripts/` |

役割分担の詳細: [docs/ai/tool-roles.md](docs/ai/tool-roles.md)

## テスト

CLI テストスイートをローカルで実行:

```bash
sh tests/run-tests.sh
```

テストは `plangate validate --dir` を 4 種類のフィクスチャシナリオ（complete-task / missing-approval / stale-plan-hash / broken-pbi）に対して検証します。
CI は同じスイートを全 PR で `.github/workflows/test.yml` を通じて実行します。

## Provider サポート

PlanGate のガバナンスワークフローはプロバイダに依存しない設計です。
ゲート機構・Artifact スキーマ・`run.ndjson` ログ形式は、利用する AI ツールに関わらず動作します。

| Provider | 役割 | 状態 |
| --- | --- | --- |
| Claude Code | 計画生成、exec オーケストレーション | 完全対応 |
| Codex CLI | 外部レビュー（C-2 / V-3）、並列実行 | 完全対応 |
| Gemini CLI | 外部レビュー | RFC — [docs/rfc/provider-gemini-cli.md](docs/rfc/provider-gemini-cli.md) 参照 |
| OpenCode | 実装エージェント | RFC — [docs/rfc/provider-opencode.md](docs/rfc/provider-opencode.md) 参照 |
| Cursor | 実装エージェント | 計画中 |

新しい Provider のサポート追加は [CONTRIBUTING.md](CONTRIBUTING.md#adding-a-new-provider) を参照してください。

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

## ライセンス

MIT — [LICENSE](LICENSE) を参照
