# EXECUTION TODO — TASK-0033

## 凡例

- `[x]` = 完了
- `[ ]` = 未完了
- Owner: `agent` / `human`
- 🚩 = チェックポイント（必須確認ポイント）

---

## Agent D 担当タスク（ブランチ: `feature/task-0033-agent-control-context-dispatch`）

### 準備

- [x] 既存 Rule / Skill の参照確認（completion-gate / evidence-ledger / review-gate / mode-classification / skill-policy-router） — Owner: agent
- [x] worktree 作成（`feature/task-0033-agent-control-context-dispatch`） — Owner: agent

🚩 **CP-D1**: 参照ファイルを全て読み込み、整合性を確認した

### 実装

- [x] `plugin/plangate/skills/context-packager/SKILL.md` 作成 — Owner: agent
  - 対応 AC: AC-1（Allowed Context 6 要素の定義）
- [x] `plugin/plangate/rules/subagent-roles.md` 作成 — Owner: agent
  - 対応 AC: AC-4（reviewer ロールの severity 付き finding 定義）
- [x] `plugin/plangate/skills/subagent-dispatch/SKILL.md` 作成 — Owner: agent
  - 対応 AC: AC-3（Allowed Context の渡し方・禁止スコープの制限）

🚩 **CP-D2**: 各ファイルが Rule 2 チェック（プロジェクト固有情報なし）を通過した

---

## Agent E 担当タスク（ブランチ: `feature/task-0033-agent-control-worktree-pr`）

### 準備

- [x] 既存 Rule / Skill の参照確認（completion-gate / evidence-ledger / review-gate / mode-classification / skill-policy-router） — Owner: agent
- [x] worktree 作成（`feature/task-0033-agent-control-worktree-pr`） — Owner: agent
- [x] ディレクトリ作成（`plugin/plangate/skills/pr-decision/`, `docs/working/TASK-0033/`） — Owner: agent

🚩 **CP-E1**: 参照ファイルを全て読み込み、整合性を確認した

### 実装

- [x] `plugin/plangate/rules/worktree-policy.md` 作成 — Owner: agent
  - 対応 AC: AC-2（high-risk/critical の worktree requirement と `requiresWorktree` フラグ接続）
- [x] `plugin/plangate/skills/pr-decision/SKILL.md` 作成 — Owner: agent
  - 対応 AC: AC-5（Evidence Ledger + Review Gate + GateStatus から PR 判断）
- [x] `docs/working/TASK-0033/pbi-input.md` 作成 — Owner: agent
- [x] `docs/working/TASK-0033/plan.md` 作成 — Owner: agent
- [x] `docs/working/TASK-0033/todo.md` 作成 — Owner: agent
- [x] `docs/working/TASK-0033/test-cases.md` 作成 — Owner: agent
- [x] `docs/working/TASK-0033/INDEX.md` 作成 — Owner: agent
- [x] `docs/working/TASK-0033/current-state.md` 作成 — Owner: agent
- [x] `docs/working/TASK-0033/handoff.md` 作成 — Owner: agent

🚩 **CP-E2**: 各ファイルが Rule 2 チェック（プロジェクト固有情報なし）を通過した

### 検証

- [ ] Rule 2 チェック（grep による固有情報不在確認） — Owner: agent
- [ ] 必須セクション・frontmatter の存在確認 — Owner: agent

🚩 **CP-E3**: worktree-policy.md と pr-decision/SKILL.md の内容が AC-2 / AC-5 を満たしていることを確認

---

## Human タスク

### C-3 ゲート（計画承認）

- [ ] plan.md・todo.md・test-cases.md をレビューする — Owner: human
- [ ] APPROVE / CONDITIONAL / REJECT を判定する — Owner: human

⚠️ **依存関係**: C-3 APPROVE 後に Agent E の実装を開始する（本タスクでは事前承認済みのため省略）

### C-4 ゲート（PR レビュー）

- [ ] GitHub 上で Agent E ブランチの PR をレビューする — Owner: human
- [ ] APPROVE / REQUEST CHANGES / REJECT を判定する — Owner: human

---

## 依存関係サマリ

```text
Agent D (CP-D1 → CP-D2) ─── 並列 ───> Agent E (CP-E1 → CP-E2 → CP-E3)
                                         ↓
                                    統合 PR 作成
                                         ↓
                                    acceptance-tester による 5 AC 突合
                                         ↓
                                    C-4 ゲート（human）
```
