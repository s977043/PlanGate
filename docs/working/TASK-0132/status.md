# STATUS — TASK-0132 (#566)

## C-3 Gate: APPROVED
- c3.json: APPROVED（plan_hash sha256:fb36788…）/ presence gate 通過 / critical

## exec 進捗
- [x] T1 plugin 2スキル / mode-classification / docs/workflows 精読
- [x] T2 .claude/skills/intent-classifier/SKILL.md 正本新設（plugin 移植）
- [x] T3 .claude/skills/skill-policy-router/SKILL.md 正本新設 + Mode 正本参照注記
- [x] T6 lite_eligible 責務分界を両スキルに明記
- [x] T4 plugin 2スキルを mirror 同期（本体↔mirror diff 一致）
- [x] T5 WF-00 advisory（docs/workflows/00_intent_intake.md）新設 + README 目次追記
- [x] T7 検証（正本/mirror 一致・Mode 正本参照・lite_eligible・WF-00 advisory・HO 未編集）
- [ ] T8 handoff

## 設計判断（plan S2 の解釈）
mode-classification.md に GatePolicy(requiredSkills) 表が無いため、router の Mode 別ポリシー表は**重複ではなく GatePolicy 写像**。完全削除は機能喪失となるため、表は写像として残し「Mode 判定基準・lite_eligible は mode-classification 単一正本・router は判定せず写像のみ」を明記して重複を解消（plan の重複解消意図を満たす）。
