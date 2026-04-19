# TASK-0024 テストケース定義

> 生成日: 2026-04-20

## 受入基準 → テストケース マッピング

| 受入基準 | TC | 種別 |
|---------|-----|------|
| 10 Skill が `.claude/skills/` に配置 | TC-1 | Unit |
| 各 Skill に 入力/出力/phase/カテゴリ 定義 | TC-2 | Unit |
| Rule 2 遵守 | TC-3 | Integration |
| 4 カテゴリへの分類明示 | TC-4 | Unit |
| 既存 Skill との重複解消 | TC-5 | Integration |
| WF-01〜WF-05 マッピング作成 | TC-6 | Integration |

## テストケース一覧

### TC-1: 10 Skill ファイル存在

- **前提条件**: `.claude/skills/` 存在
- **入力**:
  ```bash
  for s in context-load requirement-gap-scan nonfunctional-check edgecase-enumeration risk-assessment acceptance-criteria-build architecture-sketch feature-implement acceptance-review known-issues-log; do
    test -f ".claude/skills/$s/SKILL.md" || echo "missing: $s"
  done
  ```
- **期待出力**: 出力なし（全 10 件存在）
- **種別**: Unit

### TC-2: 各 Skill の必須フィールド

- **前提条件**: TC-1 パス
- **入力**: 各 SKILL.md の frontmatter と本文を確認
- **期待出力**: 各ファイルに以下が含まれる
  - frontmatter: `name`, `description`
  - 本文: 「入力」「出力」「想定 phase」「カテゴリ」セクション
- **種別**: Unit

### TC-3: Rule 2 遵守チェック

- **前提条件**: TC-1 パス
- **入力**:
  ```bash
  grep -l "TASK-\|PostgreSQL\|Laravel\|このプロジェクト" .claude/skills/context-load/SKILL.md .claude/skills/requirement-gap-scan/SKILL.md .claude/skills/nonfunctional-check/SKILL.md .claude/skills/edgecase-enumeration/SKILL.md .claude/skills/risk-assessment/SKILL.md .claude/skills/acceptance-criteria-build/SKILL.md .claude/skills/architecture-sketch/SKILL.md .claude/skills/feature-implement/SKILL.md .claude/skills/acceptance-review/SKILL.md .claude/skills/known-issues-log/SKILL.md
  ```
- **期待出力**: 出力なし（案件固有情報なし）
- **種別**: Integration

### TC-4: 4 カテゴリ分類明示

- **前提条件**: TC-1 パス
- **入力**: 各 SKILL.md の「カテゴリ」セクション
- **期待出力**:
  - Scan: context-load, requirement-gap-scan（2 件）
  - Check: nonfunctional-check, edgecase-enumeration, risk-assessment（3 件）
  - Design: acceptance-criteria-build, architecture-sketch（2 件）
  - Build: feature-implement（1 件）
  - Review: acceptance-review, known-issues-log（2 件）
- **種別**: Unit

### TC-5: 既存 Skill との重複解消 / 共存理由明記

- **前提条件**: TC-1 パス、T-2a で `evidence/skill-comparison.md` に 10 新規 × 既存 9 件の比較表が作成済
- **入力**: `evidence/skill-comparison.md` の内容確認
- **期待出力**: 各新規 Skill について次のいずれかが明記
  - 「新規」：既存に該当なし
  - 「統合」：既存 Skill を置換 or 取り込み（対象名記載）
  - 「共存」：既存と機能差分があり並列運用、差分記載
- **種別**: Integration

### TC-6: phase マッピング表存在

- **前提条件**: `docs/workflows/skill-mapping.md` 存在
- **入力**: ファイル内容確認
- **期待出力**: 10 Skill × 5 phase のマッピング表、WF-01〜WF-05 全カバー
- **種別**: Integration

## エッジケース

### TC-E1: frontmatter valid

- 各 SKILL.md の先頭が `---`、`name:` / `description:` 存在

### TC-E2: Skill 名ベース存在確認（件数ではなく名前）

- **前提**: TC-1 パス
- **入力**: 10 新規 Skill 名のディレクトリが全て `.claude/skills/` 配下に存在
- **期待**: 全 10 件のディレクトリが存在、README.md の有無は検証対象外
- **種別**: Unit
