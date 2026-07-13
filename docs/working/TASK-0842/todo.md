---
task_id: TASK-0842
artifact_type: todo
schema_version: 1
status: draft
created_by: orchestrator
---

# EXECUTION TODO — TASK-0842

> L-0〜V-4・PR 作成は workflow-conductor が自動制御するため含めない。
> Mode = high-risk → 実装タスクは rollback 必須。

## 🤖 Agent タスク

### 準備

- [ ] T-1: `grep -rn "plugin" docs/ai/ai-loop/` を実行しログを `evidence/verification/grep-plugin-ai-loop.log` に保存（AC-2）
  - Owner: agent / depends_on: なし / files: `docs/working/TASK-0842/evidence/verification/grep-plugin-ai-loop.log`
  - rollback: 不要（読取・ログ保存のみ）
- [ ] T-2: EH-3 無変更確認（R-003 対応・2 段）— ①`git diff --stat origin/main...HEAD -- .claude/rules/mode-classification.md scripts/hooks/check-plan-hash.sh` が空（ブランチ全差分）②`git diff --stat -- <同パス>` が空（未コミット差分）の両方をログ保存（AC-3）
  - Owner: agent / depends_on: なし / files: `docs/working/TASK-0842/evidence/verification/eh3-no-change.log`
  - rollback: 不要（読取のみ）

### 実装

- [ ] T-3: `docs/ai/ai-loop/asset-inventory.md` に「`plugin/plangate/**` の整合担保は CI-owned（sync-plugin-plangate.yml drift 検出 → 同期 PR → Human C-4 merge）に一本化（#842 B案）」の 1 行を追記（AC-4）
  - Owner: agent / depends_on: H-2（ho-paths.md 適用後）/ files: `docs/ai/ai-loop/asset-inventory.md`
  - rollback: `git checkout -- docs/ai/ai-loop/asset-inventory.md`（追記 1 行の revert）
- [ ] T-4: H-2 適用後の検証 — `grep -c "HO-plugin" docs/ai/ai-loop/ho-paths.md` = 0 かつ `sync-plugin-plangate.yml` の `on.push.paths` に `docs/ai/ai-loop/**` / `scripts/ai-loop/**` が追加されていることを確認しログ保存
  - Owner: agent / depends_on: H-2 / files: `docs/working/TASK-0842/evidence/verification/ho-plugin-removed.log`
  - rollback: 不要（検証のみ）

### #843 同期（後段）

- [ ] T-5: `sh scripts/sync-plugin-plangate.sh --dry-run` を実行し対象差分を確認・ログ保存（AC-5 前段。#840 由来か否かの出自を区別して記録）
  - Owner: agent / depends_on: H-2 / files: `docs/working/TASK-0842/evidence/verification/sync-dry-run.log`
  - rollback: 不要（dry-run のみ）
- [ ] T-6: `sh scripts/sync-plugin-plangate.sh`（本番）を実行し、同期ブランチで **PR-2** 作成（本文に差分の出自内訳を明記。merge は Human C-4）（AC-5）
  - Owner: agent / depends_on: T-5, PR-1 merge / files: `plugin/plangate/**`（sync スクリプト経由のみ）
  - rollback: 同期ブランチ削除 + PR close（`git push origin --delete <sync-branch>` / `gh pr close <n>`）。main には未マージのため影響なし
- [ ] T-6b: **PR-1 作成** — 本タスクブランチ（plan 成果物 + asset-inventory 追記 + H-2 の Human commit 2 件）で PR 作成（R-002 対応。merge は Human C-4）
  - Owner: agent / depends_on: T-3, T-4 / files: なし（PR 操作のみ）
  - rollback: PR close（ブランチは保持）

### 完了

- [ ] T-7: handoff.md 発行（提案差分・evidence・#843 PR 状態・V2 候補 = C案を集約）
  - Owner: agent / depends_on: T-4, T-6 / files: `docs/working/TASK-0842/handoff.md`
  - rollback: 不要（成果物発行）

## 👤 Human タスク

- [ ] H-1: **C-3 同期承認** — plan.md（B案採用・提案差分・S4 先行順序）を確認し `approvals/c3.json` を APPROVED で発行（high-risk・autonomous APPROVE 対象外 / AC-6）
- [ ] H-2: **本タスクブランチ（PR-1）上で提案差分 1・2 を commit**（R-002/R-004 対応）— ①ho-paths.md: HO-plugin 3 箇所削除 + 関連ドキュメント節への注記追加（plan.md「提案差分 1」の変更指示・行番号付き）②sync-plugin-plangate.yml: trigger paths に `docs/ai/ai-loop/**` / `scripts/ai-loop/**` を追加（「提案差分 2」）。main へ直接 commit しない
- [ ] H-3: **PR-1 の C-4 レビュー・merge**（HO 変更 2 件を含むため差分を直接確認）
- [ ] H-4: **PR-2（#843 同期 PR）の C-4 レビュー・merge**

## ⚠️ 依存関係

```
T-1, T-2（並列可）→ C-1 → C-2 反映 → H-1（C-3 🚩）→ H-2（PR-1 ブランチ上 🚩）→ T-3, T-4 → T-6b（PR-1）→ H-3（C-4 🚩）→ T-5 → T-6（PR-2）→ H-4（C-4 🚩）→ T-7
```
