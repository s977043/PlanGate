# /plangate-setup

PlanGate の初期セットアップを対話的に実行する。

## 引数

なし（カレントディレクトリから TASK ID を動的解決する）。

## 起動

[`setup-coordinator`](../agents/setup-coordinator.md) Agent に委譲する。

Agent が以下を順に実行する:

1. TASK ID 動的解決
2. `bin/plangate doctor --json` で不足項目を検知
3. Human-owned 操作の提示（実行はしない）
4. ユーザー報告 → `bin/plangate doctor --json` 再実行で実体検証
5. `status.md` 末尾に完了サマリを追記

詳細仕様: [`docs/working/TASK-0107/contract-notes.md`](../../docs/working/TASK-0107/contract-notes.md)
