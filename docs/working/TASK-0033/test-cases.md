# テストケース定義 — TASK-0033

## 受入基準 → テストケースマッピング

| AC | 内容 | 対応 TC |
|----|------|--------|
| AC-1 | タスクごとに Allowed Context を生成できる | TC-01 |
| AC-2 | high-risk/critical で worktree requirement を表現できる | TC-02 |
| AC-3 | subagent ごとに渡す文脈を制限できる | TC-03 |
| AC-4 | review 結果を severity 付きで統合できる | TC-04 |
| AC-5 | Evidence Ledger + Review Gate + GateStatus から PR 判断を出せる | TC-05 |

## テストケース一覧

### TC-01（AC-1 対応）

| 項目 | 内容 |
|------|------|
| TC-ID | TC-01 |
| 対応 AC | AC-1 |
| 前提条件 | タスクあり（任意のタスク文脈） |
| 操作 | `plugin/plangate/skills/context-packager/SKILL.md` を確認する |
| 期待結果 | Allowed Context の 6 要素（対象ファイル / 仕様 / 既存テスト / 変更制約 / 実行コマンド / 禁止スコープ）が定義されている |
| 種別 | 文書確認 |
| 担当 Agent | Agent D |

### TC-02（AC-2 対応）

| 項目 | 内容 |
|------|------|
| TC-ID | TC-02 |
| 対応 AC | AC-2 |
| 前提条件 | Mode が high-risk または critical |
| 操作 | `plugin/plangate/rules/worktree-policy.md` を確認する |
| 期待結果 | (1) high-risk: 必須（推奨）、critical: 必須（強制）が明記されている。(2) `requiresWorktree` フラグとの接続（`skill-policy-router` への参照）が記述されている |
| 種別 | 文書確認 |
| 担当 Agent | Agent E（本タスク） |

### TC-03（AC-3 対応）

| 項目 | 内容 |
|------|------|
| TC-ID | TC-03 |
| 対応 AC | AC-3 |
| 前提条件 | マルチエージェント実行（複数サブエージェントが並列動作） |
| 操作 | `plugin/plangate/skills/subagent-dispatch/SKILL.md` を確認する |
| 期待結果 | (1) Allowed Context を各エージェントに渡す仕組みが記述されている。(2) 禁止スコープによるコンテキスト制限が記述されている |
| 種別 | 文書確認 |
| 担当 Agent | Agent D |

### TC-04（AC-4 対応）

| 項目 | 内容 |
|------|------|
| TC-ID | TC-04 |
| 対応 AC | AC-4 |
| 前提条件 | レビュー結果あり（finding 一覧）|
| 操作 | `plugin/plangate/rules/subagent-roles.md` の reviewer ロール定義を確認する |
| 期待結果 | reviewer / security-reviewer / test-reviewer が severity 付き finding（critical / major / minor / info）を出力することが定義されている |
| 種別 | 文書確認 |
| 担当 Agent | Agent D |

### TC-05（AC-5 対応）

| 項目 | 内容 |
|------|------|
| TC-ID | TC-05 |
| 対応 AC | AC-5 |
| 前提条件 | Evidence Ledger + Review Gate + GateStatus（Completion Gate）の 3 入力が揃っている |
| 操作 | `plugin/plangate/skills/pr-decision/SKILL.md` を確認する |
| 期待結果 | (1) 3 つの入力から PR APPROVE / BLOCK / CONDITIONAL を判定できる仕組みが記述されている。(2) 各判定の条件が明示されている。(3) 出力が structured output（判定レポート）として定義されている |
| 種別 | 文書確認 |
| 担当 Agent | Agent E（本タスク） |

## エッジケース

| ケース | 期待動作 |
|--------|---------|
| TC-02: Mode が standard の場合 | worktree-policy.md に「推奨だが必須ではない」と記述されている |
| TC-05: Completion Gate が BLOCKED かつ critical finding = 0 の場合 | 判定は BLOCK（Gate 通過失敗が優先） |
| TC-05: Rollback Plan が存在しない場合（standard モード） | CONDITIONAL ではなく APPROVE（standard では Rollback Plan は任意） |
| TC-05: Evidence Ledger の status が "skipped" の場合 | 判定は CONDITIONAL（failed ではないが確証がない） |

## 検証方法

全テストケースは文書確認（acceptance-tester による目視確認）で実施する。

コード実行は不要（Markdown ドキュメントの内容確認のため）。
