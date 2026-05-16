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

## exec 前プリフライト（F2 / TASK-0073）

exec 開始前に以下を決定論的に検証する（自然言語依存にしない）。
不整合は exec 前に停止 or 明示降格する:

1. **git 操作主体**: 委譲タスクは todo.md のメタフィールド
   `delegation_commit_boundary: no-commit` で commit/push 境界を宣言できる。
   宣言時、委譲先サブエージェントは commit/push しない（完了フェーズは親が実施）。
2. **認証整合（三点）**: `gh auth`（active account）/ `git config user` /
   `git remote`（push 先）が期待と一致するか。不一致は exec 前に検出。
3. **委譲 commit 境界の機械検出**: 上記宣言下の git commit/push 相当
   （`git -c`/`-C`/env 前置/`command git`/`gh pr merge`/`sh -c` 等を含む）は
   **EH-9**（[`hook-enforcement.md`](../hook-enforcement.md)）が PreToolUse で
   決定論検出し **default=block**（bypass・未宣言のみ従来動作。warn は廃止＝
   high-risk 恒久対処）。信頼境界は stdin JSON tool_input.command を正本とし
   env は CLI テスト専用。
   **配線契約（MJ-1）**: 委譲元 orchestrator は todo.md メタ
   `delegation_commit_boundary: no-commit` を読み、委譲時に
   `PLANGATE_DELEGATION_NOCOMMIT=1` を注入する責務を負う。注入漏れに備え
   exec 後検証（4）は env ではなく **todo.md メタを直接読む fail-closed
   バックストップ**とする。
4. **exec 後検証（二段の保険・fail-closed）**: exec 完了時、todo.md メタの
   委譲境界宣言を直接読み、宣言タスクで予期しない commit が無いことを
   検証する（env 注入漏れでも機能する最終防線。ユーザー定義 git alias 等
   EH-9 が解決不能なケースのバックストップ）。
5. **認証三点プリフライト**: `check-auth-preflight.sh`（gh active /
   git config user.email / origin。`PLANGATE_EXPECTED_GH_ACCOUNT` 指定時は
   厳格一致）が exec 前に決定論検証し、不整合は exit!=0 で停止。

> F1（TASK-0072 / PR #245）の capability preflight（`Agent`/`Task` 可否）と
> 同一プリフライト層に属する。#245 マージ後、core-contract §5-bis 配下の
> 単一プリフライト・ゲートへ統合する（重複定義を排除。handoff 参照）。

## Stop rules

- scope 外作業が必要と判明 → 即停止、ユーザー確認
- test FAIL の root cause が不明 → 停止（Iron Law #6: NO FIXES WITHOUT ROOT CAUSE INVESTIGATION）
- plan_hash 改竄検知 → block（[`hook-enforcement.md`](../hook-enforcement.md) EH-3）
- 承認なし production code 編集要求 → block（EH-1）
- 委譲境界 `no-commit` 宣言下で commit/push 試行 → block（EH-9, strict 時）
- 認証三点（gh auth / git config / remote）不整合 → exec 前停止

## Output discipline

- 実装コード（`allowed_files` glob 内のみ）
- コミット履歴（チェックポイント単位）
- status.md にリアルタイム進捗

## 関連

- [`tool-policy.md`](../tool-policy.md) — exec phase の allowed tools
- [`hook-enforcement.md`](../hook-enforcement.md) EH-1 / EH-3 / EH-6 / **EH-9**（委譲 commit 境界）


## Error taxonomy（最小定義 / TASK-0072、将来 #203 統合）

| category | 定義 | recovery policy |
|----------|------|-----------------|
| `delegation_unavailable` | サブエージェント起動（`Agent`/`Task`）が利用不可、**または判定不能**（両者を同一扱い＝安全側に倒すため。判定不能で委譲を試みると再びデッドロックし得る） | exec router が **direct-implementer-mode** へ自動移行（人間介入不要・正規フロー）。conductor は委譲可能時のみ起動されるため Iron Law と衝突しない |

> 正本 taxonomy は #203（Tool Error Taxonomy and Recovery Policy）で一元化予定。
> 本節は field の恒常 bug（#237/#238/#239）を待たせないための最小定義。
