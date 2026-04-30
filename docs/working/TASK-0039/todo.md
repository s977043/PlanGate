# EXECUTION TODO — TASK-0039 (PBI-116-01 / Issue #117)

> [`plan.md`](./plan.md) の Work Breakdown を 2-5 分粒度のタスクに分解。
> Iron Law: `NO SCOPE CHANGE WITHOUT USER APPROVAL`

## 🤖 Agentタスク

### 準備フェーズ

- [ ] 🚩 T-1: Scope/受入基準を再掲し、作業範囲を固定する（pbi-input.md / plan.md 再読込） [Owner: agent] [depends_on: -] [files: -]
- [ ] 🚩 T-2: 既存 ai-driven-development.md の Iron Law 6 項目を確認し、新定義の 7 項目（root cause / two-stage review 含む）との差分を特定 [Owner: agent] [depends_on: T-1] [files: docs/ai-driven-development.md]

### 実装フェーズ（TDD: doc-review として、検証 → 実装 → 検証）

#### Step 1: 棚卸し
- [ ] 🚩 T-3: hard-mandate キーワード grep を 64 ファイル全体で実行し evidence/inventory.md に記録 [Owner: agent] [depends_on: T-2] [files: docs/working/TASK-0039/evidence/inventory.md]
- [ ] 🚩 T-4: 棚卸し結果を 3 段階（必須削減 / 推奨削減 / 保留）に分類 [Owner: agent] [depends_on: T-3] [files: docs/working/TASK-0039/evidence/inventory.md]

#### Step 2: Core Contract 定義
- [ ] 🚩 T-5: docs/ai/core-contract.md の skeleton 作成（8 セクション） [Owner: agent] [depends_on: T-4] [files: docs/ai/core-contract.md]
- [ ] 🚩 T-6: Hard constraints セクションに Iron Law 7 項目を明示転記 [Owner: agent] [depends_on: T-5] [files: docs/ai/core-contract.md]
- [ ] 🚩 T-7: Role / Goal / Success criteria / Decision rules / Available evidence / Stop rules / Output discipline の各セクションを記述 [Owner: agent] [depends_on: T-6] [files: docs/ai/core-contract.md]
- [ ] 🚩 T-8: Core Contract のセルフ検証（8 セクション完備、Iron Law 7 項目漏れなし） [Owner: agent] [depends_on: T-7] [files: docs/ai/core-contract.md]

#### Step 3: CLAUDE.md 薄型化
- [ ] 🚩 T-9: 現状 CLAUDE.md の行数記録（baseline） [Owner: agent] [depends_on: T-8] [files: -]
- [ ] 🚩 T-10: CLAUDE.md を Core Contract への導線中心に書き換え（`<law>` セクション維持、Claude Code 固有参照先テーブル維持） [Owner: agent] [depends_on: T-9] [files: CLAUDE.md]
- [ ] 🚩 T-11: 行数 50% 以下確認、削減後の lint 通過確認 [Owner: agent] [depends_on: T-10] [files: -]

#### Step 4: AGENTS.md 薄型化
- [ ] 🚩 T-12: 現状 AGENTS.md の行数記録（baseline） [Owner: agent] [depends_on: T-11] [files: -]
- [ ] 🚩 T-13: AGENTS.md を Core Contract への導線中心に書き換え [Owner: agent] [depends_on: T-12] [files: AGENTS.md]
- [ ] 🚩 T-14: 行数 50% 以下確認、削減後の lint 通過確認 [Owner: agent] [depends_on: T-13] [files: -]

#### Step 5: project-rules.md 整合
- [ ] 🚩 T-15: docs/ai/project-rules.md の G. 参照先に core-contract.md を追加、ディレクトリ構造に追記 [Owner: agent] [depends_on: T-14] [files: docs/ai/project-rules.md]

#### Step 6: hard-mandate 削減
- [ ] 🚩 T-16: .claude/rules/working-context.md の hard-mandate 整理（Iron Law 該当のみ保持） [Owner: agent] [depends_on: T-15] [files: .claude/rules/working-context.md]
- [ ] 🚩 T-17: .claude/commands/ai-dev-workflow.md の hard-mandate 整理（最大ファイル、353 行） [Owner: agent] [depends_on: T-16] [files: .claude/commands/ai-dev-workflow.md]
- [ ] 🚩 T-18: plugin/plangate/rules/working-context.md と plugin/plangate/commands/ai-dev-workflow.md を同期 [Owner: agent] [depends_on: T-17] [files: plugin/plangate/rules/working-context.md plugin/plangate/commands/ai-dev-workflow.md]
- [ ] 🚩 T-19: .claude/agents/*.md（hard-mandate ヒット 4 ファイル）を個別整理 [Owner: agent] [depends_on: T-18] [files: .claude/agents/]
- [ ] 🚩 T-20: plugin/plangate/skills/*/SKILL.md（hard-mandate ヒット 2 ファイル）を個別整理 [Owner: agent] [depends_on: T-19] [files: plugin/plangate/skills/]

### 検証フェーズ

- [ ] 🚩 T-21: 全変更ファイルで markdown lint 実行、0 error 確認 [Owner: agent] [depends_on: T-20] [files: -]
- [ ] 🚩 T-22: hard-mandate 残存スキャン（Iron Law 7 項目以外がゼロ） [Owner: agent] [depends_on: T-21] [files: -]
- [ ] 🚩 T-23: token 削減率測定 → evidence/verification.md に記録（CLAUDE.md / AGENTS.md / 主要ファイル） [Owner: agent] [depends_on: T-22] [files: docs/working/TASK-0039/evidence/verification.md]
- [ ] 🚩 T-24: 受入基準 6 項目の全確認（pbi-input.md と突合） [Owner: agent] [depends_on: T-23] [files: -]

### 完了フェーズ

- [ ] 🚩 T-25: handoff.md 作成（必須 6 要素） [Owner: agent] [depends_on: T-24] [files: docs/working/TASK-0039/handoff.md]
- [ ] 🚩 T-26: status.md 作成・最終更新 [Owner: agent] [depends_on: T-25] [files: docs/working/TASK-0039/status.md]
- [ ] 🚩 T-27: コミット作成 [Owner: agent] [depends_on: T-26] [files: -]
- [ ] 🚩 T-28: push + PR 作成 [Owner: agent] [depends_on: T-27] [files: -]

> 注: L-0 / V-1 / V-2 / V-3 はワークフロー側で自動制御（high-risk のため V-2 / V-3 必須）。

## 👤 Humanタスク

- [ ] **C-3**: plan/todo/test-cases の人間レビュー（exec 前ゲート） [Owner: human]
- [ ] **C-4**: PR レビュー・承認（GitHub 上） [Owner: human]

## ⚠️ 依存関係

- 親 PBI Parent C-3 ✅ APPROVED 済（2026-04-30）
- Agent 実装 → Human Child C-3 レビュー承認後に exec 開始
- exec 完了 → L-0 → V-1 → V-2 → V-3 → PR 作成 → Human Child C-4 レビュー承認後にマージ

## タスク粒度ルール

- 各タスクは 2-5 分で完了する 1 アクションに分解
- 🚩 マークでチェックポイントを明示（todo.md / current-state.md 更新タイミング）
- 各タスクに Owner / depends_on / files を必ず明記
- スコープ外作業は禁止（Iron Law: `NO SCOPE CHANGE WITHOUT USER APPROVAL`）
