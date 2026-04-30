# TEST CASES: TASK-0045 / Issue #159

## 受入基準 → テストケースマッピング

| AC | TC | 種別 |
|----|----|----|
| AC-1 | TC-1 | CI manifest review |
| AC-2 | TC-2 | fixture: warn |
| AC-3 | TC-3 | fixture: pass with YAML related_issue |
| AC-4 | TC-4 | fixture: skip-label |
| AC-5 | TC-5 | manual: PR template review |
| AC-6 | TC-6 | fixtures count |

## テストケース

### TC-1: workflow trigger（manual review）

- **前提**: `.github/workflows/check-pr-issue-link.yml` が存在
- **検証**: `on: pull_request` トリガが [opened, edited, synchronize, labeled] を含む
- **期待**: 含まれる

### TC-2: closing keyword 欠落 → WARN

- **入力**:
  - `pr-body.txt`: closing keyword を含まない（"## Summary\n... fix something"）
  - `labels.txt`: 空 / `enhancement` のみ
  - `changed-files.txt`: 任意
- **期待 stdout**: `WARN: no closing keyword found`
- **exit code**: 0

### TC-3: closing keyword あり → PASS

- **入力**:
  - `pr-body.txt`: `closes #159` を含む
  - `labels.txt`: `enhancement`
  - `changed-files.txt`: 任意
- **期待 stdout**: `PASS: closing keyword(s) #159 found`
- **exit code**: 0

### TC-4: documentation label → SKIP

- **入力**:
  - `pr-body.txt`: 任意（closing keyword 不要）
  - `labels.txt`: `documentation`
  - `changed-files.txt`: 任意
- **期待 stdout**: `SKIP: label "documentation" matched skip rule`
- **exit code**: 0

### TC-5: skip marker → SKIP

- **入力**:
  - `pr-body.txt`: `<!-- skip-issue-link-check -->` を含む
  - `labels.txt`: 空
- **期待 stdout**: `SKIP: marker found`
- **exit code**: 0

### TC-6: fixtures count

- `tests/fixtures/check-pr-issue-link/` 配下に **pass / warn / skip-label / skip-marker** の 4 ディレクトリが存在
