# PBI INPUT PACKAGE — TASK-0131 (#565)

## Context / Why

外部提案（agent-skills → PlanGate 取り込み検討）のギャップ調査で、提案6要素中5要素は既存充足を確認した。唯一の実質ギャップが「**タスク粒度のロールバック手順の明示**」。現状、戻し手順は `plan.md` の Risks & Mitigations / Approach に散在し、`todo.md` の各タスク（owner / depends_on / files / 🚩）には Rollback 欄がない。

high-risk / critical mode では「各タスクが失敗したらどう戻すか」を task 単位で持つ価値が高い（mode-classification.md 定性基準に「ロールバック: 計画的に必要 / 段階的ロールバック必須」が既にある）。

## 重要な前提（調査で判明）

- `docs/working/templates/` に **todo.md の独立テンプレ正本は存在しない**。
- todo.md の構造定義は次に分散:
  - `.claude/rules/working-context.md`（todo.md の役割・記載内容の正本）
  - `.agents/skills/ai-dev-plan/SKILL.md` の「todo.md 規約」（`.codex/` `plugin/plangate/` `.claude/worktrees/` にミラー）
- したがって「Rollback フィールドをどこに追加するか」は**設計判断**（Codex 相談対象）。

## What (Scope)

### In scope
- todo.md 各タスクに Rollback 手順を表現する規約の追加（追加先は設計で確定）
- mode 別の必須/任意ルール（high-risk / critical で必須、それ以下は任意・「不要」明記可）
- 記入サンプル（既存 TASK の todo.md いずれか、またはテンプレ例）

### Out of scope
- `plan.md` の Risks 構造の改変（責務分界＝plan は全体リスク / todo はタスク戻し手順、に留める）
- #566（Skill Router 統合）・#567（不採用理由の構造化）

## 受入基準
- AC-01: todo.md の各タスクに Rollback 手順を記す規約が、正本（working-context.md または ai-dev-plan skill）に明文化されている
- AC-02: mode 別の必須/任意ルールが mode-classification.md / working-context.md と矛盾なく記載されている
- AC-03: 記入サンプルが 1 件存在する
- AC-04: ai-dev-plan skill の正本＋ミラー間で記述が整合している（drift を作らない）
- AC-05: C-1（plan-quality-check / review-self）が high-risk/critical の rollback 欠落を FAIL 検出する（Refs: R-001）

## Notes from Refinement
- 「テンプレ」という提案語に引きずられず、実態（規約分散）に合わせた追加先を選ぶ。
- 二重管理（plan.md Risks と todo.md Rollback）を避ける責務分界を明記する。

## Estimation Evidence
- Risks: 追加先が HO 対象（working-context.md = `.claude/rules/*.md`）の場合、AI 編集不可 → apply-script + 人間適用が必須。ai-dev-plan skill 正本（`.agents/skills/`）は override パターン外だが、ミラー同期の整合が必要。
- Unknowns: 追加先（working-context.md / skill / 新規テンプレ）の最適解 → Codex 相談で決定。
- Assumptions: mode-classification.md の既存ロールバック定性基準は変更しない（参照のみ）。
- Mode 見込み: **high-risk**（承認境界周辺の `.claude/rules/*.md` に触れる可能性 → 最低 high-risk・人間 C-3 同期固定 / autonomous APPROVE 不可）。
