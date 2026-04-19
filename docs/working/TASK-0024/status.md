# TASK-0024 作業ステータス

> 最終更新: 2026-04-20

## 全体構成

- **親 Issue**: #22
- **対象 Issue**: #24（[TASK-0021-B] 再利用可能な Skill 10 個を整備する）
- **ブランチ**: `docs/TASK-0024-skill-definitions`
- **モード**: full
- **状態**: exec 完了、PR 作成準備中

## C-3 Gate: APPROVED (CONDITIONAL → APPROVE)

- 判定: CONDITIONAL APPROVE（2026-04-20）
- 根拠: C-1 PASS、Codex C-2（スコア 78/100、major 2 / minor 2）全対応済み

## 現在のフェーズ

exec 完了 → PR 作成 → V-1 / V-2 / V-3 → C-4 待ち

## 完了タスク

### Phase 1: 準備

- [x] T-1: Scope / 受入基準の再掲
- [x] T-2: 既存 `.claude/skills/` 8 件の調査、共通テンプレート策定 → `evidence/skill-template.md`
- [x] T-2a: 10 新規 × 既存 8 件の比較表作成 → `evidence/skill-comparison.md`
- [x] T-3: 名前衝突確認（全 10 件が新規名）

### Phase 2: 実装（10 Skill 作成）

- [x] T-4: `context-load` Skill 作成（Scan / WF-01）
- [x] T-5: `requirement-gap-scan` Skill 作成（Scan / WF-02）
- [x] T-6: `nonfunctional-check` Skill 作成（Check / WF-02）
- [x] T-7: `edgecase-enumeration` Skill 作成（Check / WF-02）
- [x] T-8: `risk-assessment` Skill 作成（Check / WF-02 + WF-03）
- [x] T-9: `acceptance-criteria-build` Skill 作成（Design / WF-02）
- [x] T-10: `architecture-sketch` Skill 作成（Design / WF-03）
- [x] T-11: `feature-implement` Skill 作成（Build / WF-04）
- [x] T-12: `acceptance-review` Skill 作成（Review / WF-05）
- [x] T-13: `known-issues-log` Skill 作成（Review / WF-05）
- [x] T-14: `docs/workflows/skill-mapping.md`（phase マッピング表）作成

### Phase 3: 検証

- [x] T-17: Rule 2 遵守チェック → `evidence/rule2-check.md`（Layer 1 CLEAN / Layer 2 全 10 件再利用可能）

### Phase 4: 完了

- [ ] T-21: コミット + push + PR 作成

## 成果物サマリ

### 新規作成（10 Skill + マッピング表）

- `.claude/skills/context-load/SKILL.md`
- `.claude/skills/requirement-gap-scan/SKILL.md`
- `.claude/skills/nonfunctional-check/SKILL.md`
- `.claude/skills/edgecase-enumeration/SKILL.md`
- `.claude/skills/risk-assessment/SKILL.md`
- `.claude/skills/acceptance-criteria-build/SKILL.md`
- `.claude/skills/architecture-sketch/SKILL.md`
- `.claude/skills/feature-implement/SKILL.md`
- `.claude/skills/acceptance-review/SKILL.md`
- `.claude/skills/known-issues-log/SKILL.md`
- `docs/workflows/skill-mapping.md`

### Evidence

- `docs/working/TASK-0024/evidence/skill-template.md`
- `docs/working/TASK-0024/evidence/skill-comparison.md`
- `docs/working/TASK-0024/evidence/rule2-check.md`

## モード `full` 追加ゲート（C-4 前）

- [x] C-2 外部AIレビュー（Codex / スコア 78/100 → 全対応 APPROVE 相当）
- [ ] L-0 リンター自動修正
- [ ] V-1 受け入れ検査
- [ ] V-2 コード最適化
- [ ] V-3 外部モデルレビュー
- V-4 リリース前チェック: スキップ（critical のみ）
