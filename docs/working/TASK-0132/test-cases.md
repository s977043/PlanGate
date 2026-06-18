# TEST CASES — TASK-0132 (#566)

## AC → TC
### AC-01: 正本が .claude/skills に存在・plugin は mirror 一致
- TC-01: `.claude/skills/intent-classifier/SKILL.md` と `.claude/skills/skill-policy-router/SKILL.md` が存在。種別: 機械
- TC-02: plugin 側と本体正本の本文が一致（export 注記行を除き diff なし）。種別: 機械
### AC-02: router の Mode別表削除 + 参照化
- TC-03: `grep -i "Mode別ポリシー表\|ultra-light.*light.*standard" .claude/skills/skill-policy-router/SKILL.md` がマトリクス本体をヒットしない。種別: 機械
- TC-04: router が `mode-classification.md` を明示参照している。種別: 機械
### AC-03: WF-00 advisory 配線
- TC-05: WF-00 に「intent→mode→router→GatePolicy→plan」advisory フロー記述がある。種別: レビュー+機械(grep)
### AC-04: hybrid 正本/export 方向整合
- TC-06: hybrid-architecture の「.claude 正本・plugin export」に反しない（本体正本が存在し plugin が mirror）。種別: レビュー
### AC-05: lite_eligible 責務明記
- TC-07: classifier/mode判定/router の lite_eligible 責務分界が記述されている。種別: レビュー

### AC-06: critical プロセス制約の維持（Refs: R-002）
- TC-08: plan.md / todo.md に「Mode=critical・人間 C-3 必須・autonomous APPROVE 不可」が明記され、planning 段階で緩和されていない。種別: レビュー

## Edge cases
- EC-01: 既存 plugin 利用者が壊れない（plugin に SKILL は残る）
- EC-02: advisory は強制でない（既存 phase の必須性を変えない）
- EC-03: mode-classification.md は編集せず参照のみ（単一正本維持）
