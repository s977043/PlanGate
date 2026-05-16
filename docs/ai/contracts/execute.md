# Phase Contract: execute

> [`prompt-assembly.md`](../prompt-assembly.md) の phase_contract / 7 phase の 1 つ

## Goal

承認済 plan / todo / test-cases に従って実装する。todo の各タスクを 2-5 分粒度で順次実行。

### 実行者の決定（capability preflight / TASK-0072）

exec 開始時に **委譲ケイパビリティ（`Task` 利用可否）をツール存在検査で判定**する:

- 委譲可能 → `workflow-conductor` 委譲（並列性・責務分離の最適化経路）
- 委譲不可 → **exec router が direct-implementer-mode に入る（既定の正規フロー）**。
  router 自身がタスク分割・依存順序・status/todo 更新・L-0〜V-4・PR を担う
  （実行者は router、責務は conductor 委譲時と同等。Codex V-3 MJ-1）
- 判定不能 → 安全側＝direct-implementer-mode

2 段委譲はハード前提にしない（[`core-contract.md`](../core-contract.md) §5-bis 不変条件）。

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


## Error taxonomy（最小定義 / TASK-0072、将来 #203 統合）

| category | 定義 | recovery policy |
|----------|------|-----------------|
| `delegation_unavailable` | サブエージェント起動（`Agent`/`Task`）が利用不可、**または判定不能**（両者を同一扱い＝安全側に倒すため。判定不能で委譲を試みると再びデッドロックし得る） | exec router が **direct-implementer-mode** へ自動移行（人間介入不要・正規フロー）。conductor は委譲可能時のみ起動されるため Iron Law と衝突しない |

> 正本 taxonomy は #203（Tool Error Taxonomy and Recovery Policy）で一元化予定。
> 本節は field の恒常 bug（#237/#238/#239）を待たせないための最小定義。

