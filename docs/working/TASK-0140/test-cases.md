---
task_id: TASK-0140
artifact_type: test-cases
schema_version: 1
---

# TEST CASES — TASK-0140

## 受入基準マッピング

| AC | テストケース |
|----|------------|
| AC-1 (init) | TC-01 正常系, TC-02 異常系 |
| AC-2 (status) | TC-03 正常系, TC-04 異常系 |
| AC-3 (handoff) | TC-05 正常系, TC-06 異常系 |
| AC-4 (verify/eval smoke) | TC-07, TC-08 |
| AC-5 (sandbox 非汚染) | TC-09 |
| AC-6 (ta-42 認識) | TC-10 |

## テストケース一覧

### TC-01: init 正常系（新規作成）
- **前提**: TASK-XXXX ディレクトリが存在しない
- **入力**: `bin/plangate init TASK-XXXX`（mktemp ベース）
- **期待**: exit 0、docs/working/TASK-XXXX/{pbi-input.md, INDEX.md, approvals/, evidence/} 作成
- **種別**: 正常系

### TC-02: init 異常系（既存 TASK）
- **前提**: TASK-XXXX ディレクトリが既に存在
- **入力**: `bin/plangate init TASK-XXXX`（同じパス）
- **期待**: exit 0（冪等）、"already exists" メッセージ
- **種別**: 異常系（冪等性）

### TC-03: status 正常系
- **前提**: TASK-XXXX ディレクトリと INDEX.md が存在
- **入力**: `bin/plangate status TASK-XXXX`
- **期待**: exit 0、"Task:" 行を含む出力
- **種別**: 正常系

### TC-04: status 異常系（TASK なし）
- **前提**: TASK-XXXX ディレクトリが存在しない
- **入力**: `bin/plangate status TASK-NONEXISTENT`
- **期待**: exit 1、エラーメッセージ
- **種別**: 異常系

### TC-05: handoff 正常系
- **前提**: TASK-XXXX ディレクトリが存在
- **入力**: `bin/plangate handoff TASK-XXXX`
- **期待**: exit 0、handoff.md が作成される
- **種別**: 正常系

### TC-06: handoff 異常系（TASK なし）
- **前提**: TASK-XXXX ディレクトリが存在しない
- **入力**: `bin/plangate handoff TASK-NONEXISTENT`
- **期待**: exit 1、エラーメッセージ
- **種別**: 異常系

### TC-07: verify smoke（TASK 存在）
- **前提**: TASK-XXXX ディレクトリが存在（pbi-input.md のみ）
- **入力**: `bin/plangate verify TASK-XXXX`
- **期待**: exit 0 or 1（クラッシュしない）、出力に "Validating" を含む
- **種別**: smoke

### TC-08: eval smoke（TASK 存在）
- **前提**: TASK-XXXX ディレクトリが存在（handoff.md なし）
- **入力**: `bin/plangate eval TASK-XXXX`
- **期待**: exit 1、"handoff.md not found" エラーメッセージ
- **種別**: smoke（異常系）

### TC-09: sandbox 非汚染確認
- **前提**: テスト用 mktemp ディレクトリを使用
- **検証**: テスト終了後に docs/working/ 内に TASK-XXXX ディレクトリが存在しない
- **期待**: PASS（汚染なし）
- **種別**: 整合性

### TC-10: ta-42 認識（自己証明）
- **前提**: tests/run-tests.sh に ta-42 のエントリが存在
- **検証**: このテストが実行されていること
- **期待**: PASS（自己証明）
- **種別**: 整合性

## エッジケース

- init で作成したサンドボックス TASK が実際の docs/working/ に書き込まれないこと
- verify/eval が PLANGATE_ROOT 環境変数を使用している場合のパス解決
