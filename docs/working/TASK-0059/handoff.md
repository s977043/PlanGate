# Handoff: TASK-0059 (PBI-HI-007 / Issue #201)

## 1. 要件適合確認結果

| AC | 検証 | 判定 |
|----|------|------|
| AC-01 governance ドキュメント存在 | docs/ai/issue-governance.md + pages/guides/governance/documentation-management.md | ✅ PASS |
| AC-02 Why/What/AC/Non-goals 定義 | issue-governance.md §2 (4セクション) | ✅ PASS |
| AC-03 label taxonomy | issue-governance.md §3 (kind/area/priority/status) | ✅ PASS |
| AC-04 milestone mapping 正本 | issue-governance.md §4 (推測禁止条項含む) | ✅ PASS |
| AC-05 roadmap checklist | issue-governance.md §5 (10 項目チェック) | ✅ PASS |
| AC-06 pages/docs 責務分離 | documentation-management.md §2 | ✅ PASS（既存）|
| AC-07 公開説明は pages/ | documentation-management.md §3 | ✅ PASS（既存）|
| AC-08 sidebars.js 管理方針 | documentation-management.md §6 | ✅ PASS（既存）|
| AC-09 user-facing 変更時 doc update | documentation-management.md §4 | ✅ PASS（既存）|
| AC-10 PR checklist | documentation-management.md §4.3 | ✅ PASS（既存）|
| AC-11 status/cadence/owner policy | documentation-management.md §4.5-4.7 | ✅ PASS（既存）|
| AC-12 source of truth rules | documentation-management.md §5 | ✅ PASS（既存）|
| AC-13 deprecated/removal rules | documentation-management.md §9 | ✅ PASS（既存）|
| AC-14 EPIC #193 child policy 整合 | issue-governance.md §4.2 で #193 引用、矛盾なし | ✅ PASS |
| AC-15 Issue テンプレート方針 | .github/ISSUE_TEMPLATE/plangate-roadmap-task.yml + governance §6 言及 | ✅ PASS |

**全 15/15 PASS**

## 2. 既知課題

なし。

## 3. V2 候補

- 既存 Issue への label backfill（一括対応）
- `priority:` ラベルが GitHub 上に未作成 → 必要時に作成（自動作成は scope 外）
- GitHub Projects 連携による進捗可視化
- 自動ラベリング bot

## 4. 妥協点

- Issue テンプレートは `.yml` 1 件のみ（複雑な validation は GitHub Issue Forms の制約上限定的）
- 既存 Issue (EPIC #193 配下 11 件) の本文書式の遡及修正はしない（運用負荷回避）

## 5. 引き継ぎ文書

新規ファイル 2 件 + 既存 1 件への参照追記。

- 新規: `docs/ai/issue-governance.md`（Issue / Label / Milestone 運用の正本）
- 新規: `.github/ISSUE_TEMPLATE/plangate-roadmap-task.yml`（roadmap PBI 用 GitHub Issue Form）
- 追記: `pages/guides/governance/documentation-management.md` 冒頭に Related 欄追加（doc / issue 正本の役割分離を明記）

documentation-management.md（PR #205 でマージ済み）が doc 配置・更新ルール側を、issue-governance.md が issue 運用側を担う 2 ファイル体制となる。

## 6. テスト結果サマリ

- L-0 markdown lint: CI で確認予定
- V-1 受入基準照合: 全 15 AC PASS（自己検証）
- 影響範囲: docs only、runtime 変更なし
