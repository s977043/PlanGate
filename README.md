# PlanGate

> 「承認なし、コードなし」― AI コーディングエージェントのためのゲート型ワークフロー  
> English: A lightweight governance harness for safe AI coding agents.

[![GitHub release](https://img.shields.io/github/v/release/s977043/plangate)](https://github.com/s977043/plangate/releases)
[![CI](https://github.com/s977043/plangate/actions/workflows/ci.yml/badge.svg)](https://github.com/s977043/plangate/actions/workflows/ci.yml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/s977043/plangate/badge)](https://securityscorecards.dev/viewer/?uri=github.com/s977043/plangate)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![English](https://img.shields.io/badge/lang-English-blue)](README_en.md)

PlanGate は、AI コーディングエージェントのためのガバナンス優先ワークフローハーネスです。
人間が承認した計画・タスク・受入テストが揃うまで、AI にプロダクションコードを書かせません。

一般的なエージェントフレームワークが「自律性」を重視するのに対し、PlanGate は **承認境界・監査可能性・スクラム親和性** を重視します。

![PlanGate overview](docs/assets/harness-plangate-readme-dark-v2.png)

## 最新状態

PlanGate は v8.5.0 で、ワークフロー文書セットではなく、CLI / Hook / Schema / Eval / CI を持つ実行可能なガバナンスハーネスへ進化しています。

| 項目 | 状態 |
| --- | --- |
| 最新リリース | **v8.5.0** — Hook enforcement 完成 |
| Hook enforcement | **10/10 hooks 実装済み** |
| CLI テスト | `sh tests/run-tests.sh` — **24 PASS** |
| Hook テスト | `sh tests/hooks/run-tests.sh` — **42 PASS** |
| Eval | `bin/plangate eval` による 8 観点評価と release blocker 検知 |
| Schema | `validate-schemas` + CI による JSON artifact 検証 |

v8.5.0 では、以下のような不変条件を hook / CLI で検査できます。

- `plan.md` なしの production code 編集を検知する
- C-3 承認なしの実装をブロックする
- 承認後の `plan.md` 改変を `plan_hash` で検知する
- `test-cases.md` なしの V-1 実行を検知する
- 検証 evidence なしの PR 作成を検知する
- `forbidden_files` による scope 外編集を検知する
- C-3 / C-4 承認なしのマージを検知する
- standard / high-risk / critical で V-3 外部レビューを必須化する

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

> [!NOTE]
> **新規利用者は Option A または B のどちらか一方を推奨します。**
> 既存利用者や段階的移行を行う場合、plugin と `.claude/` のデュアル運用は技術的に可能ですが、同名 Skill / コマンドの解決順に注意してください。
> plugin 側を明示的に呼び出す場合は `plangate:<skill-or-agent>` prefix を使用します。詳細は [plugin 移行ガイド](docs/plangate-plugin-migration.md) を参照してください。

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
| Hook 強制 | v8.5 では plan / approval / evidence / scope / review の不変条件を hook と CLI で検査する |
| 検証内蔵 | L-0 / V-1〜V-4 により、実装後の検証をワークフローに組み込む |
| 状態の永続化 | `docs/working/TASK-XXXX/` に計画、レビュー、検証、handoff を残す |
| 実行層の分離 | v7 では Workflow / Skill / Agent を分け、再利用性と拡張性を高める |
| Control OS | v7.2 以降は Intent / Mode / GatePolicy / Evidence Ledger / Completion Gate を持つ |

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
| **競合リスク** | 名前空間化により低い。ただし同名 command / skill の解決順に注意 | なし |

新規導入ではどちらか一方を選びます。既存利用者の段階移行や高度なカスタマイズでは、Plugin をベースレイヤー、プロジェクトの `.claude/` を override として併用できます。
登録手順は [plugin/plangate/README.md](plugin/plangate/README.md) を参照してください。

## リポジトリ構成

```text
/bin                     — plangate CLI（init / doctor / status / validate / validate-schemas / review / exec / eval / abort / timeline / resume）
/docs                    — ナレッジ・ワークフロードキュメント
  /ai                    — 共通ルール・役割分担・実行契約・Model Profile・Prompt Assembly・Eval framework（v8.3+）
    /contracts           — phase 別 contract × 7（plan / classify / approve-wait / execute / review / verify / handoff）
    /adapters            — profile 別 adapter × 4（outcome_first / outcome_first_strict / explicit_short / legacy_or_unknown）
    /eval-cases          — model migration eval 観点 × 8（v8.3+）
  /workflows             — v7 Workflow 定義（WF-01〜WF-05 + Orchestrator）
  /working               — チケット単位の作業コンテキスト（TASK-XXXX/, PBI-XXX/）
/schemas                 — JSON Schema（plan / handoff / status / approval / model-profile / Structured Outputs / eval-result 等）
/workflows               — v8 Workflow DSL（5 mode YAML: ultra-light / light / standard / high-risk / critical）
/.claude                 — Claude Code 設定
/.codex                  — Codex CLI 設定
/plugin/plangate         — Claude Code plugin パッケージ
/scripts                 — ヘルパースクリプト、hook、parser、CI 補助
/examples                — PlanGate 成果物の完成例
/tests                   — CLI / hook テストスイート（fixtures + hooks + extras + run-tests.sh）
```

## Claude Code + Codex CLI

PlanGate は Claude Code と Codex CLI の併用を前提にしています。共通ルールは [docs/ai/project-rules.md](docs/ai/project-rules.md) に一元化し、ツール固有の入口ファイルは薄く保ちます。

| ツール | 入口ファイル | 固有設定 |
| --- | --- | --- |
| Claude Code | [CLAUDE.md](CLAUDE.md) | `.claude/` |
| Codex CLI | [AGENTS.md](AGENTS.md) | `.codex/` |
| 共通 | [docs/ai/project-rules.md](docs/ai/project-rules.md) | `docs/`、`scripts/` |

役割分担の詳細: [docs/ai/tool-roles.md](docs/ai/tool-roles.md)

## CLI

`bin/plangate` はローカルの作業コンテキストを検証・実行補助する POSIX sh ベースの CLI です。

```bash
bin/plangate init TASK-XXXX
bin/plangate status TASK-XXXX
bin/plangate validate TASK-XXXX --mode high-risk
bin/plangate validate-schemas TASK-XXXX
bin/plangate eval TASK-XXXX --no-write
PLANGATE_EXTERNAL_REVIEWER=gemini bin/plangate review TASK-XXXX --phase c2
PLANGATE_IMPL_AGENT=opencode bin/plangate exec TASK-XXXX --mode standard
```

- `validate --mode <mode>` は `workflows/<mode>.yaml` の `gate_enforcement.c3.required_artifacts` を読み込みます。
- `validate-schemas` は task artifact の JSON Schema 準拠を検証します。
- `eval` は 8 観点の評価結果を `eval-result.{md,json}` として生成し、release blocker を検知します。
- `review` は外部 reviewer provider を呼び出し、`review-external.md` を生成します。
- `exec` は C-3 gate が `APPROVED` でない場合に実行をブロックします。

## テスト

CLI / hook テストスイートをローカルで実行:

```bash
sh tests/run-tests.sh
sh tests/hooks/run-tests.sh
```

v8.5.0 時点のテスト状況:

| スイート | 件数 | 主な検証対象 |
| --- | ---: | --- |
| `tests/run-tests.sh` | **24 PASS** | CLI、Workflow DSL、schema validate、eval、provider dispatch、fixture 検証 |
| `tests/hooks/run-tests.sh` | **42 PASS** | EH-1〜EH-7 / EHS-1〜EHS-3、default / strict / bypass の 3 mode 挙動 |

主な検証対象:

- `plangate validate --dir` — complete-task / missing-approval / stale-plan-hash / broken-pbi の fixture
- `plangate validate --mode <mode>` — Workflow DSL に基づく artifact 動的決定
- `plangate validate-schemas` — task artifact の JSON Schema 準拠
- `plangate eval` — 8 観点評価、baseline 比較、release blocker 検知
- `plangate review` — 外部 reviewer provider dispatch
- `plangate exec` — C-3 gate 未通過時の実行ブロック
- hook enforcement — plan / approval / hash / test-cases / evidence / forbidden_files / merge approvals / V-3 review の検査

CI は同じ CLI / hook スイートを全 PR で `.github/workflows/test.yml` を通じて実行します。

## Provider サポート

PlanGate のガバナンスワークフローはプロバイダに依存しない設計です。
ゲート機構・Artifact スキーマ・`run.ndjson` ログ形式は、利用する AI ツールに関わらず動作します。

| Provider | 役割 | 状態 |
| --- | --- | --- |
| Claude Code | 計画生成、exec オーケストレーション | 完全対応 |
| Codex CLI | 外部レビュー（C-2 / V-3）、並列実行 | 完全対応 |
| Gemini CLI | 外部レビュー | 対応済み — `PLANGATE_EXTERNAL_REVIEWER=gemini plangate review` |
| OpenCode | 実装エージェント | 対応済み — `PLANGATE_IMPL_AGENT=opencode plangate exec` |
| Cursor | 実装エージェント | 計画中 |

新しい Provider のサポート追加は [CONTRIBUTING.md](CONTRIBUTING.md#adding-a-new-provider) を参照してください。

## Read Next

| ドキュメント | 内容 |
| --- | --- |
| [docs/philosophy.md](docs/philosophy.md) | 思想、問題設定、ハーネスエンジニアリング上の位置づけ |
| [docs/index.md](docs/index.md) | GitHub Pages 用の公開ドキュメント入口 |
| [docs/plangate.md](docs/plangate.md) | PlanGate ガイド、運用手順、フェーズ説明 |
| [docs/plangate-v7-hybrid.md](docs/plangate-v7-hybrid.md) | v7 ハイブリッドアーキテクチャ |
| [docs/orchestrator-mode.md](docs/orchestrator-mode.md) | Parent-Child PBI Orchestrator Mode 仕様 |
| [docs/workflows/README.md](docs/workflows/README.md) | WF-01〜WF-05 の Workflow 定義 |
| [docs/ai/core-contract.md](docs/ai/core-contract.md) | 実行契約の正本（Iron Law / Stop rules / Output discipline） |
| [docs/ai/model-profiles.yaml](docs/ai/model-profiles.yaml) | 実行モデル別 4 profile 設定（v8.3） |
| [docs/ai/prompt-assembly.md](docs/ai/prompt-assembly.md) | プロンプト 4 層組み立て（v8.3） |
| [docs/ai/structured-outputs.md](docs/ai/structured-outputs.md) | Structured Outputs / JSON Schema 適用方針（v8.3+） |
| [docs/ai/eval-plan.md](docs/ai/eval-plan.md) | model migration eval framework（8 観点） |
| [docs/ai/eval-runner.md](docs/ai/eval-runner.md) | `bin/plangate eval` による機械評価 CLI 仕様 |
| [docs/ai/responsibility-boundary.md](docs/ai/responsibility-boundary.md) | CLAUDE.md / Skill / Hook の責務境界 |
| [docs/ai/tool-policy.md](docs/ai/tool-policy.md) | phase 別 allowed_tools 定義 |
| [docs/ai/hook-enforcement.md](docs/ai/hook-enforcement.md) | v8.5 の Hook enforcement 10/10 実装状態 |
| [docs/plangate-plugin-migration.md](docs/plangate-plugin-migration.md) | Claude Code plugin としての利用・移行 |
| [docs/oss-governance.md](docs/oss-governance.md) | OSS 公開設定・運用判断 |
| [CHANGELOG.md](CHANGELOG.md) | 主要リリース履歴 |

## ライセンス

MIT — [LICENSE](LICENSE) を参照
