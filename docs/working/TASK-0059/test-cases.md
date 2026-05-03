# TEST CASES: TASK-0059 (PBI-HI-007)

| ID | AC | 検証方法 | 期待結果 |
|----|-----|---------|---------|
| TC-01 | governance ドキュメント存在 | `ls docs/ai/issue-governance.md` または `pages/guides/governance/documentation-management.md` | 1 件以上存在 |
| TC-02 | Issue 必須セクション定義 | `grep "Why\|What\|Acceptance Criteria\|Non-goals" docs/ai/issue-governance.md` | 4 セクション言及 |
| TC-03 | label taxonomy 定義 | issue-governance.md に label セクションあり | PASS |
| TC-04 | milestone mapping 正本 | issue-governance.md に milestone policy あり | PASS |
| TC-05 | roadmap issue 作成 checklist | issue-governance.md に checklist あり | PASS |
| TC-06 | pages/docs 責務分離 | documentation-management.md 第2章に既存 | PASS（既存）|
| TC-07 | 公開説明は pages/ | documentation-management.md 第3章 | PASS（既存）|
| TC-08 | sidebars.js 管理方針 | documentation-management.md 第6章 | PASS（既存）|
| TC-09 | user-facing 変更時 doc update | documentation-management.md 第4章 | PASS（既存）|
| TC-10 | PR checklist | documentation-management.md 4.3 節 | PASS（既存）|
| TC-11 | status / cadence / owner policy | documentation-management.md 4.5-4.7 節 | PASS（既存）|
| TC-12 | source of truth rules | documentation-management.md 第5章 | PASS（既存）|
| TC-13 | deprecated / removal rules | documentation-management.md 第9章 | PASS（既存）|
| TC-14 | EPIC #193 child policy と矛盾していない | issue-governance.md で #193 を引用 | PASS |
| TC-15 | Issue テンプレート方針 | `.github/ISSUE_TEMPLATE/plangate-roadmap-task.yml` 存在 + governance doc で言及 | PASS |
