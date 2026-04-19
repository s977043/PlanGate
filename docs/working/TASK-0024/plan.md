# TASK-0024 EXECUTION PLAN

> 生成日: 2026-04-20
> PBI: [TASK-0021-B] 再利用可能な Skill 10 個を整備する
> チケットURL: https://github.com/s977043/plangate/issues/24

## Goal

`.claude/skills/` に 10 個の Skill を新規配置し、各 Skill の入力 / 出力 / 想定利用 phase / カテゴリを定義する。

## Constraints / Non-goals

- Rule 2 遵守（Skill は再利用単位限定、案件固有情報なし）
- 既存 Skill（8 件）と共存、重複は作らない
- `.claude/skills/` に統一配置
- **Non-goals**: Skill 実行エンジン、既存 Skill のリファクタ、plugin 同梱（将来別タスク）

## Approach Overview

1. SKILL.md 共通テンプレート策定
2. 10 Skill を順次作成（カテゴリ順: Scan 2 → Check 3 → Design 2 → Build 1 → Review 2）
3. phase マッピング表（`docs/workflows/skill-mapping.md`）作成
4. Rule 2 遵守チェック

## Work Breakdown

### Step 1: 既存 SKILL.md 調査と共通テンプレート策定

- **Output**:
  - `docs/working/TASK-0024/evidence/skill-template.md`
  - `docs/working/TASK-0024/evidence/skill-comparison.md`（10 新規 × 既存 9 件の「新規/統合/共存」比較表）
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**:
  - frontmatter（name, description, user-invocable）+ 本文構造（入力/出力/想定phase/カテゴリ/役割）が確定
  - 既存 9 件と 10 新規の対応関係が評価されている
  - SKILL.md 入出力フォーマット方針（Markdown ベースか）が明記、PBI Unknowns を閉じる
  - `user-invocable` は別 decision item として個別に設定

### Step 2-3: Scan カテゴリ 2 Skill 作成

- **Output**: `.claude/skills/context-load/SKILL.md`, `.claude/skills/requirement-gap-scan/SKILL.md`
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: 2 ファイル存在、テンプレ準拠

### Step 4-6: Check カテゴリ 3 Skill 作成

- **Output**: `nonfunctional-check`, `edgecase-enumeration`, `risk-assessment`
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: 3 ファイル存在

### Step 7-8: Design カテゴリ 2 Skill 作成

- **Output**: `acceptance-criteria-build`, `architecture-sketch`
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: 2 ファイル存在

### Step 9: Build カテゴリ 1 Skill 作成

- **Output**: `feature-implement`
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: 1 ファイル存在

### Step 10-11: Review カテゴリ 2 Skill 作成

- **Output**: `acceptance-review`, `known-issues-log`
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: 2 ファイル存在

### Step 12: phase マッピング表作成

- **Output**: `docs/workflows/skill-mapping.md`
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: 10 Skill × 5 phase のマッピングが明示

### Step 13: Rule 2 遵守チェック

- **Output**: `docs/working/TASK-0024/evidence/rule2-check.md`
- **Owner**: agent
- **Risk**: 中
- **🚩 チェックポイント**: 各 Skill に案件固有情報（プロジェクト名・技術スタック・具体仕様）が含まれていないことを確認

## Files / Components to Touch

| 種別 | ファイルパス | 変更内容 |
| --- | --- | --- |
| 新規 | .claude/skills/context-load/SKILL.md | Skill 定義 |
| 新規 | .claude/skills/requirement-gap-scan/SKILL.md | Skill 定義 |
| 新規 | .claude/skills/nonfunctional-check/SKILL.md | Skill 定義 |
| 新規 | .claude/skills/edgecase-enumeration/SKILL.md | Skill 定義 |
| 新規 | .claude/skills/risk-assessment/SKILL.md | Skill 定義 |
| 新規 | .claude/skills/acceptance-criteria-build/SKILL.md | Skill 定義 |
| 新規 | .claude/skills/architecture-sketch/SKILL.md | Skill 定義 |
| 新規 | .claude/skills/feature-implement/SKILL.md | Skill 定義 |
| 新規 | .claude/skills/acceptance-review/SKILL.md | Skill 定義 |
| 新規 | .claude/skills/known-issues-log/SKILL.md | Skill 定義 |
| 新規 | docs/workflows/skill-mapping.md | phase マッピング表 |
| 新規 | docs/working/TASK-0024/evidence/skill-template.md | 共通テンプレ |
| 新規 | docs/working/TASK-0024/evidence/rule2-check.md | Rule 2 遵守チェック |

## Testing Strategy

- **Unit**: 10 Skill ファイル存在、frontmatter valid
- **Integration**: phase マッピングが 5 phase 全てをカバー、既存 Skill との名前衝突なし
- **E2E**: 対象外（Skill は定義のみ、実行は runtime で）
- **Verification Automation**:
  - 10 新規 Skill 名の存在確認: `for s in context-load requirement-gap-scan ...; do test -d ".claude/skills/$s" || echo missing; done` → 出力なし
  - `grep -l "プロジェクト固有\|このプロジェクト\|TASK-" .claude/skills/context-load/SKILL.md ...` → 0 件
  - `evidence/skill-comparison.md` で 10 件全てに「新規/統合/共存」判定記載
  - （注: `ls .claude/skills/` は README.md 含むため件数ベースは避け、名前存在確認を採用）

## Risks & Mitigations

| リスク | 対策 |
| --- | --- |
| Rule 2 違反（案件固有情報混入） | Step 13 で機械チェック、違反は修正 |
| 既存 Skill と名前衝突 | Step 1 で既存リスト確認、10 Skill 全て新規名 |
| Skill 粒度のばらつき | Step 1 の共通テンプレ準拠で揃える |

## Questions / Unknowns

- SKILL.md の frontmatter に `user-invocable` を全 Skill で true にするか false にするか
  - 採用方針: Scan/Check/Design/Review は false（agent 内部呼び出し）、Build の `feature-implement` も false。ただし手動でも呼べるよう true で統一することを検討

## Mode判定

**モード**: `full`（TASK-0022 同様の基準整合）

**判定根拠**:
- 変更ファイル数: 13（10 Skill + skill-mapping + evidence 2 + status） → **full**（6-15 帯）
- タスク数: 21 → **critical 帯だがサブタスク粒度のため full にダウングレード**
- 受入基準数: 6 → full（6-10 帯）
- 変更種別: 再利用資産の新規整備 → standard
- リスク: 中（Rule 2 遵守が重要） → standard
- 影響範囲: 複数レイヤー相当（#25〜#28 が参照） → **full**
- **最終判定**: `full`（定量基準の最大値 + TASK-0022 の先例に合わせる）

## 依存

- **前提**: #23（Workflow 定義）完了
- **後続**: #25 / #26 / #27 から参照される
