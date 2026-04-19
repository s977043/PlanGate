# TASK-0024 EXECUTION TODO

> 生成日: 2026-04-20

## 🤖 Agentタスク

### 準備フェーズ

- [ ] 🚩 T-1: Scope/受入基準を再掲 [Owner: agent]
  - files: [docs/working/TASK-0024/pbi-input.md]
  - depends_on: []
- [ ] 🚩 T-2: 既存 `.claude/skills/` 9 件（README 除く） の SKILL.md を読み、共通テンプレートを策定 [Owner: agent]
  - files: [docs/working/TASK-0024/evidence/skill-template.md]
  - depends_on: [T-1]
- [ ] 🚩 T-2a: 10 新規 × 既存 9 件の比較表（新規/統合/共存）を作成 [Owner: agent]
  - files: [docs/working/TASK-0024/evidence/skill-comparison.md]
  - depends_on: [T-2]
- [ ] 🚩 T-3: 名前衝突確認 + 入出力フォーマット方針確定（PBI Unknown 処理） [Owner: agent]
  - files: []
  - depends_on: [T-2a]

### 実装フェーズ（C-3 Gate APPROVE 後のみ開始）

> ⚠️ T-4 は C-3 承認必須。

- [ ] 🚩 T-4: `context-load` Skill 作成（Scan/WF-01） [Owner: agent]
  - files: [.claude/skills/context-load/SKILL.md]
  - depends_on: [T-3, C-3]
  - prerequisite: **C-3 Gate APPROVE**
- [ ] 🚩 T-5: `requirement-gap-scan` Skill 作成（Scan/WF-02） [Owner: agent]
  - files: [.claude/skills/requirement-gap-scan/SKILL.md]
  - depends_on: [T-4]
- [ ] 🚩 T-6: `nonfunctional-check` Skill 作成（Check/WF-02） [Owner: agent]
  - files: [.claude/skills/nonfunctional-check/SKILL.md]
  - depends_on: [T-4]
- [ ] 🚩 T-7: `edgecase-enumeration` Skill 作成（Check/WF-02） [Owner: agent]
  - files: [.claude/skills/edgecase-enumeration/SKILL.md]
  - depends_on: [T-4]
- [ ] 🚩 T-8: `risk-assessment` Skill 作成（Check/WF-02） [Owner: agent]
  - files: [.claude/skills/risk-assessment/SKILL.md]
  - depends_on: [T-4]
- [ ] 🚩 T-9: `acceptance-criteria-build` Skill 作成（Design/WF-02） [Owner: agent]
  - files: [.claude/skills/acceptance-criteria-build/SKILL.md]
  - depends_on: [T-4]
- [ ] 🚩 T-10: `architecture-sketch` Skill 作成（Design/WF-03） [Owner: agent]
  - files: [.claude/skills/architecture-sketch/SKILL.md]
  - depends_on: [T-4]
- [ ] 🚩 T-11: `feature-implement` Skill 作成（Build/WF-04） [Owner: agent]
  - files: [.claude/skills/feature-implement/SKILL.md]
  - depends_on: [T-4]
- [ ] 🚩 T-12: `acceptance-review` Skill 作成（Review/WF-05） [Owner: agent]
  - files: [.claude/skills/acceptance-review/SKILL.md]
  - depends_on: [T-4]
- [ ] 🚩 T-13: `known-issues-log` Skill 作成（Review/WF-05） [Owner: agent]
  - files: [.claude/skills/known-issues-log/SKILL.md]
  - depends_on: [T-4]
- [ ] 🚩 T-14: `docs/workflows/skill-mapping.md`（10 Skill × 5 phase マッピング表）作成 [Owner: agent]
  - files: [docs/workflows/skill-mapping.md]
  - depends_on: [T-5, T-6, T-7, T-8, T-9, T-10, T-11, T-12, T-13]

### セルフレビュー①

- [ ] 🚩 T-15: `/self-review` 実行、Rule 2 遵守・構造一貫性を確認 [Owner: agent]
  - files: []
  - depends_on: [T-14]

### 検証フェーズ

- [ ] 🚩 T-16: 10 新規 Skill 名でのディレクトリ存在確認（名前ベース / README 非依存） [Owner: agent]
  - files: []
  - depends_on: [T-15]
  - 検証: `for s in context-load requirement-gap-scan ...; do test -d ".claude/skills/$s"; done`
- [ ] 🚩 T-17: Rule 2 遵守チェック（案件固有情報混入なし）、`evidence/rule2-check.md` に記録 [Owner: agent]
  - files: [docs/working/TASK-0024/evidence/rule2-check.md]
  - depends_on: [T-16]
- [ ] 🚩 T-18: phase マッピングが 5 phase 全てをカバーしていることを確認 [Owner: agent]
  - files: []
  - depends_on: [T-17]
- [ ] 🚩 T-19: 受入基準 6 項目の全確認 [Owner: agent]
  - files: []
  - depends_on: [T-18]

### セルフレビュー②

- [ ] 🚩 T-20: `/self-review` 再実行 [Owner: agent]
  - depends_on: [T-19]

### 完了フェーズ

- [ ] 🚩 T-21: コミット作成、status.md 更新 [Owner: agent]
  - files: [docs/working/TASK-0024/status.md]
  - depends_on: [T-20]

## 👤 Humanタスク

- [ ] C-3: Plan/ToDo/Test Cases 人間レビュー
- [ ] C-4: PR レビュー・承認

## ⚠️ 依存関係

- **前提 TASK**: #23 完了
- T-1 → T-2 → T-3（準備）
- T-4（1 件目）→ T-5〜T-13 並列可能
- T-14（mapping）は T-5〜T-13 完成後
