# TASK-0019 Plugin 同梱スクリプト一覧

> 調査日: 2026-04-19

## 決定

**本 TASK では `plugin/plangate/scripts/` にスクリプトを同梱しない**。

## 根拠

- TASK-0019 の target 6 agents（workflow-conductor, spec-writer, implementer, linter-fixer, acceptance-tester, code-optimizer）はいずれも `scripts/` 配下のシェルスクリプトに直接依存していない（`dependency-scan.md` 参照）
- 既存 `scripts/` には PlanGate のローカル CI/ワークフロー補助スクリプトがあるが、これらは repo 側の開発者向けユーティリティであり、plugin 同梱には適さない
- 無理に同梱すると「plugin 標準機能 vs プロジェクト固有ツール」の境界が曖昧になる

## 配置する具体スクリプト一覧

**なし**（0 件）

`plugin/plangate/scripts/` は空ディレクトリ（`.gitkeep` で保持）のまま、将来の拡張に備える。

## 将来の追加候補

以下は検討対象として TASK-0020 の migration note に記載:

| スクリプト | 追加タイミング | 理由 |
|----------|-------------|------|
| `ai-dev-workflow` | 将来の PlanGate runtime 実装時 | 導線コマンドと整合する汎用 shim |
| `ai-dev-common.sh` | 上記依存として同梱 | 共通ライブラリ |

他のスクリプト（cloud 系、codex 系）は別 plugin または repo 側に残す方針。

## Plugin 利用者向け案内

TASK-0020 の README に以下を記載予定:
- 「plugin には scripts を含まない」
- 「既存 plangate リポジトリの scripts/ を必要に応じて参照してください」
