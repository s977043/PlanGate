# TASK-0031 TEST CASES

## 受入基準 → テストケースマッピング

| 受入基準 | テストケース |
|---------|------------|
| AC-1 | TC-01 |
| AC-2 | TC-02 |
| AC-3 | TC-03 |
| AC-4 | TC-04 |
| AC-5 | TC-05 |

## テストケース一覧

### TC-01: コマンドファイルの存在確認

**前提条件**: feature/task-0031-pg-commands ブランチで実装完了後

**入力**: `ls plugin/plangate/commands/`

**期待出力**:

```text
ai-dev-workflow.md
pg-check.md
pg-hunt.md
pg-think.md
pg-verify.md
working-context.md
```

**種別**: Verification（ファイル存在確認）

**判定**: `pg-think.md`, `pg-hunt.md`, `pg-check.md`, `pg-verify.md` の 4 件が存在すれば PASS

---

### TC-02: skill-policy-router との連携記述確認

**前提条件**: pg-think.md および pg-verify.md が存在する

**入力**: `grep -l "skill-policy-router" plugin/plangate/commands/pg-*.md`

**期待出力**: `pg-think.md` と `pg-verify.md` が含まれる

**種別**: Verification（内容確認）

**判定**: 両ファイルに `skill-policy-router` への言及があれば PASS

---

### TC-03: EvidenceLedger JSON フォーマット定義確認

**前提条件**: pg-verify.md が存在する

**入力**: pg-verify.md の内容を確認

**期待出力**: 以下を含む

- `"claim"` フィールド
- `"status"` フィールド（`"passed | failed | unknown"`）
- `"evidence"` 配列
- `"exitCode"` フィールド
- `"outputExcerpt"` フィールド

**種別**: Verification（内容確認）

**判定**: 上記 5 要素が JSON ブロック内に定義されていれば PASS

---

### TC-04: /pg-hunt の Iron Law 明記確認

**前提条件**: pg-hunt.md が存在する

**入力**: `grep "NO FIXES WITHOUT ROOT CAUSE" plugin/plangate/commands/pg-hunt.md`

**期待出力**: 1 行以上マッチ

**種別**: Verification（内容確認）

**判定**: Iron Law `NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST` が明記されていれば PASS

---

### TC-05: /pg-check の Severity 定義と出力フォーマット確認

**前提条件**: pg-check.md が存在する

**入力**: pg-check.md の内容を確認

**期待出力**: 以下を含む

- `critical` の Severity 定義
- `major` の Severity 定義
- `minor` の Severity 定義
- `info` の Severity 定義
- Findings テーブル（Severity 列付き）

**種別**: Verification（内容確認）

**判定**: 4 種の Severity 定義と Findings 出力フォーマットが存在すれば PASS

---

## エッジケース

| エッジケース | 対処 |
|------------|------|
| コマンドファイルが空の場合 | Write ツールで作成するため発生しない |
| plugin.json の構文エラー | Read してから Edit するため発生しない |
| Markdown lint 違反 | コードブロックのバッククォート三重使用時に注意 |
