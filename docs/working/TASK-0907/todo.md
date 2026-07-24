# EXECUTION TODO — TASK-0907

> L-0〜V-4・PR 作成は workflow-conductor が自動制御するため含めない。
> Mode=critical → 実装タスクに `rollback:` 必須。C-2 確定反映済み（`Refs: R-NNN`）。

## 🤖 Agent タスク

### 準備
- [ ] T1 pbi-input / plan / rollout-policy §2〜§6 / command 実行前チェック3 を再読し touch 差分を確定
  - Owner: agent / depends_on: なし / files: docs/working/TASK-0907/plan.md
  - 🚩 §5/§4/§6 の escalate 条件の現行文言を控える（additive-only 照合の基準）
  - rollback: 不要（読取）

### 実装
- [ ] T2 `rollout-policy.md`（正本・非HO）§2 表行を案 C で拡張 + 直下注記節
  - 注記に: **carve-out `scripts/ai-loop/**`**（R-001）/ #780 ハード順序制約継承（R-003）/ §5/§4/§6 不変明示（R-002）/ Human verbatim
  - Owner: agent / depends_on: T1 / files: docs/workflows/ai-loop/rollout-policy.md
  - 🚩 §5/§4/§6 は escalate 条件を一字も削除・緩和しない（additive のみ）
  - rollback: `git checkout -- docs/workflows/ai-loop/rollout-policy.md`
- [ ] T3 plugin 派生 rollout-policy を sync 再生成（`Refs: R-101`）
  - `sh scripts/sync-plugin-plangate.sh` → `sync --dry-run` が no change を確認（**手同期禁止**・cmp byte 一致を期待しない）
  - Owner: agent / depends_on: T2 / files: plugin/plangate/skills/ai-loop-cycle/references/rollout-policy.md
  - rollback: `git checkout -- plugin/plangate/skills/ai-loop-cycle/references/rollout-policy.md`
- [ ] T4 HO command patch 生成（`.claude/commands/ai-loop-workflow.md`）+ `ho-apply-approval.md`（`Refs: R-103/R-004`）
  - 実行前チェック3 を §2 拡張と整合。**ガード非後退**（HO 接触無条件 escalate / NO MERGE BY AI / touches-HO 停止規則）を保持
  - Owner: agent 生成 / **Human 適用** / depends_on: T2 / files: docs/working/TASK-0907/patches/
  - 🚩 AI は patch 生成のみ。**plugin command 版は AI 編集しない**（sync で revert されるため）
  - rollback: 未適用 no-op / 適用済みは reverse patch 同梱
- [ ] T5 plugin command の sync 再生成（**H2 適用後**）
  - `sh scripts/sync-plugin-plangate.sh` → `cmp .claude/commands/ai-loop-workflow.md plugin/plangate/commands/ai-loop-workflow.md` = exit 0
  - Owner: agent / depends_on: **H2** / files: plugin/plangate/commands/ai-loop-workflow.md
  - 🚩 H2 の後（Human patch 適用前に sync すると plugin が旧内容で上書き）
  - rollback: sync 再実行で復元

### 検証
- [ ] T6 承認境界 非後退・drift 検証（AC-2/5/6/7）
  - rollout-policy: `sync --dry-run` 冪等 / §5/§4/§6 escalate 条件 diff = additive-only / carve-out grep 存在 / clean 判定集合点検
  - command: cmp exit 0（H2 後）
  - Owner: agent / depends_on: T3,T5 / files: docs/working/TASK-0907/evidence/
  - rollback: 不要（検証）
- [ ] T7 doc V-1: リンク健全性 + 実行例到達性 + AC-1/AC-3/AC-8 grep 突合
  - Owner: agent / depends_on: T2 / files: docs/working/TASK-0907/evidence/
  - rollback: 不要（検証）
- [ ] T8 `bin/plangate doctor` 回帰なし確認
  - Owner: agent / depends_on: T2〜T4 / files: -
  - rollback: 不要（検証）

## 👤 Human タスク
- [ ] H1 C-3 人間レビュー（Mode=critical・同期固定）→ `bin/plangate approve TASK-0907`
  - Owner: human / depends_on: C-1,C-2 完了。**C-3 論点 6 件**（特に R-001 carve-out 方式）
- [ ] H2 HO command patch 適用（`.claude/commands/ai-loop-workflow.md`）
  - Owner: human / depends_on: T4, H1
- [ ] H3 C-4 PR レビュー → merge
  - Owner: human / depends_on: PR 作成

## ⚠️ 依存関係（順序ロック）
- T2 → T3（sync 再生成）/ T2 → T4（patch 生成）
- **T4 → H1（C-3）→ H2（HO 適用）→ T5（plugin command sync）→ T6 command 部**（順序ロック・R-103）
- C-1,C-2 → H1 → H2 → PR → H3
