---
task_id: TASK-0081
artifact_type: review-external
schema_version: 1
status: done
phase: V-3
---

# V-3 外部レビュー — TASK-0081（責務4分類 S4）

standard。Codex 実行（Gemini ランタイムクラッシュ→Codex 主体・前例運用）。

## 判定: Codex=critical0/major1/minor2 → fix-loop

| # | Sev | 指摘 | 対応 |
|---|-----|------|------|
| MJ-1 | major | orchestrator-mode AS-1〜5 を一括 Human-owned としたが AS-3/ParentDone は `HumanOrPolicyFinalApprovalPassed`（人間 or policy）→ 既存正本と矛盾 | AS-1/2/4/5（Human-owned）/ AS-3（Human-owned or 事前定義 policy）に分割。境界原則に「個別正本が policy 許容を定める箇所は委譲＝矛盾でなく階層」例外を明記 |
| mn-1 | minor | Human-owned「self-mod 対象適用」が広い | `.claude/settings*.json` 等 self-mod guard 対象に限定 |
| mn-2 | minor | additive 確認 | 問題なし（hybrid 参照追記のみ・本文不変）|

Codex 整合確認: merge=Human / settings適用=Human / CI=reference / doctor=実体 /
Workflow=タスクロック は settings-wiring-contract / TASK-0077 AC-4 / TASK-0071 と整合。

## 確認
- 再 V-1: AC-1〜6 + MJ-1/minor 全 PASS、hook 78/0、hybrid 削除行0（additive）

## 出典
- Codex: /tmp/t0081-codex-v3.md（critical0/major1/minor2）
- Gemini: /tmp/t0081-gemini-v3.md（ランタイムクラッシュ）
