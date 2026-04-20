# TASK-0028 EXECUTION TODO

> 生成日: 2026-04-20

## 🤖 Agentタスク

### 準備フェーズ

- [ ] 🚩 T-1: Scope/受入基準再掲 [Owner: agent]
  - files: [docs/working/TASK-0028/pbi-input.md]
  - depends_on: []
- [ ] 🚩 T-2: 既存 v5/v6 ドキュメント調査、v7 との差分整理 [Owner: agent]
  - files: [docs/working/TASK-0028/evidence/v5-v6-v7-diff.md]
  - depends_on: [T-1]

### 実装フェーズ（C-3 APPROVE 後）

- [ ] 🚩 T-3: `docs/plangate-v7-hybrid.md` 作成 [Owner: agent]
  - files: [docs/plangate-v7-hybrid.md]
  - depends_on: [T-2, C-3]
  - prerequisite: **C-3 Gate APPROVE**
- [ ] 🚩 T-4: `.claude/rules/hybrid-architecture.md` 作成 [Owner: agent]
  - files: [.claude/rules/hybrid-architecture.md]
  - depends_on: [T-3]
- [ ] 🚩 T-5: `docs/plangate.md` に v7 導線 note 追加 [Owner: agent]
  - files: [docs/plangate.md]
  - depends_on: [T-4]
- [ ] 🚩 T-6: `docs/plangate-v6-roadmap.md` に v7 導線 note 追加 [Owner: agent]
  - files: [docs/plangate-v6-roadmap.md]
  - depends_on: [T-5]

### 検証

> 注: C-1 セルフレビュー / C-2 外部レビューは exec 前ゲートとして `review-self.md` / `review-external.md` 側で完了している前提。exec 中の TODO には含めない。

- [ ] 🚩 T-8: v7 ドキュメントに Rule 1〜5 全て記載（`grep -c "Rule [1-5]"` 検証） [Owner: agent]
  - depends_on: [T-6]
- [ ] 🚩 T-9: 境界ルール・接続表記載（`grep -E "GATE\|STATUS\|APPROVAL\|ARTIFACT\|Workflow\|Skill\|Agent"` で機械検証） [Owner: agent]
  - depends_on: [T-8]
- [ ] 🚩 T-10: v5/v6 から v7 への導線記載 [Owner: agent]
  - depends_on: [T-9]
- [ ] 🚩 T-10a: v5/v6 との差分・位置付け節が v7 ドキュメント内に存在することを確認 [Owner: agent]
  - depends_on: [T-10]
- [ ] 🚩 T-11: 受入基準 6 項目確認 [Owner: agent]
  - depends_on: [T-10a]

### 完了

- [ ] 🚩 T-12: コミット、status.md 更新 [Owner: agent]
  - files: [docs/working/TASK-0028/status.md]
  - depends_on: [T-11]
- [ ] 🚩 T-13: 親 #22 Close 可否を判断（#23-#27 も完了していれば Close） [Owner: agent/human]
  - depends_on: [T-12]

## 👤 Humanタスク

- [ ] C-3 / C-4
- [ ] 親 #22 Close 判断

## ⚠️ 依存関係

- **前提**: #23-#27 と並行可能
- 完了後: #22 Close 可能（#23-#27 も完了している必要あり）
