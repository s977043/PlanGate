# EXECUTION TODO: TASK-0129

> 承認境界の中核。exec は**人間 C-3 承認後**。HO 適用は人間。

## 🤖 Agent（C-3 承認後に exec）
- [ ] T01 Decision→c3_status mapping 確定（doc） — depends_on: H01 / files: docs/
- [ ] T02 c3-approval.schema additive 拡張の apply-script（後方互換） — depends_on: T01 / files: scripts/apply-task-0129-schema.sh 🚩
- [ ] T03 C-1 充足チェック（Stop/Replan Triggers 記入検出）追加 — depends_on: T01 / files: .claude/skills/plan-quality-check, docs
- [ ] T04 Stop-Work↔機械トリガー対応表 apply-script（working-context HO） — depends_on: T01 / files: scripts/apply-task-0129-wc.sh 🚩
- [ ] T05 後方互換テスト（既存 c3.json valid）+ mapping 単体 — depends_on: T02 / files: evidence/
- [ ] T06 status/handoff — depends_on: T05

## 👤 Human
- [ ] H01 **C-3 承認**（承認境界・Standard 同期・autonomous 不可） — depends_on: C-1/C-2
- [ ] H02 apply-script 適用（schema/working-context HO） — depends_on: T02,T04 ⚠️ AI 不可
- [ ] H03 C-4 レビュー — depends_on: PR

## ⚠️ 依存
- 全 exec タスクは H01（人間 C-3）後。HO 適用（H02）は人間専任。
