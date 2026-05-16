# Phase Contract: execute

> [`prompt-assembly.md`](../prompt-assembly.md) の phase_contract / 7 phase の 1 つ

## Goal

承認済 plan / todo / test-cases に従って実装する。todo の各タスクを 2-5 分粒度で順次実行。

### 実行者の決定（exec 前プリフライト）

exec 開始時の実行者決定・委譲 commit 境界・認証整合の検証は
[`core-contract.md` §5-bis-1（exec 前プリフライト 単一正本）](../core-contract.md)（§5-bis 実行環境不変条件 → §5-bis-1 exec 前プリフライト）
に従う（capability 判定 → conductor 委譲 or direct-implementer-mode /
委譲 commit 境界 EH-9 / 認証三点プリフライト / exec 後検証 / 2 段委譲を
ハード前提にしない不変条件）。本契約は exec phase での適用点のみを示す。

## Success criteria

- todo の全 🤖 Agent タスクが完了
- 各タスクで test 実行（TDD: RED → GREEN → REFACTOR）
- scope 外ファイルへの編集ゼロ（[`tool-policy.md`](../tool-policy.md) allowed_files 準拠）
- Iron Law: `NO SCOPE CHANGE WITHOUT USER APPROVAL`
- exec 前プリフライト（§5-bis-1）を通過している

## Stop rules

- scope 外作業が必要と判明 → 即停止、ユーザー確認
- test FAIL の root cause が不明 → 停止（Iron Law #6: NO FIXES WITHOUT ROOT CAUSE INVESTIGATION）
- plan_hash 改竄検知 → block（[`hook-enforcement.md`](../hook-enforcement.md) EH-3）
- 承認なし production code 編集要求 → block（EH-1）
- 委譲境界 `no-commit` 違反 / 認証三点不整合 / 委譲不可 → §5-bis-1 に従い停止 or direct-implementer-mode 降格

## Output discipline

- 実装コード（`allowed_files` glob 内のみ）
- コミット履歴（チェックポイント単位）
- status.md にリアルタイム進捗

## 関連

- [`core-contract.md` §5-bis / §5-bis-1](../core-contract.md) — 実行環境不変条件 / exec 前プリフライト単一正本（capability / 委譲 commit 境界 / 認証三点 / direct-implementer-mode / Error taxonomy）
- [`tool-policy.md`](../tool-policy.md) — exec phase の allowed tools
- [`hook-enforcement.md`](../hook-enforcement.md) EH-1 / EH-3 / EH-6 / EH-9（委譲 commit 境界）
