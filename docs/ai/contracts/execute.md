# Phase Contract: execute

> [`prompt-assembly.md`](../prompt-assembly.md) の phase_contract / 7 phase の 1 つ

## Goal

承認済 plan / todo / test-cases に従って実装する。todo の各タスクを 2-5 分粒度で順次実行。

## Success criteria

- todo の全 🤖 Agent タスクが完了
- 各タスクで test 実行（TDD: RED → GREEN → REFACTOR）
- scope 外ファイルへの編集ゼロ（[`tool-policy.md`](../tool-policy.md) allowed_files 準拠）
- Iron Law: `NO SCOPE CHANGE WITHOUT USER APPROVAL`

## Stop rules

- scope 外作業が必要と判明 → 即停止、ユーザー確認
- test FAIL の root cause が不明 → 停止（Iron Law #6: NO FIXES WITHOUT ROOT CAUSE INVESTIGATION）
- plan_hash 改竄検知 → block（[`hook-enforcement.md`](../hook-enforcement.md) EH-3）
- 承認なし production code 編集要求 → block（EH-1）

## Output discipline

- 実装コード（`allowed_files` glob 内のみ）
- コミット履歴（チェックポイント単位）
- status.md にリアルタイム進捗

## 関連

- [`tool-policy.md`](../tool-policy.md) — exec phase の allowed tools
- [`hook-enforcement.md`](../hook-enforcement.md) EH-1 / EH-3 / EH-6
