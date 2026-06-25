---
task_id: TASK-0143
artifact_type: test-cases
schema_version: 1
status: draft
---

# TEST CASES — TASK-0143

## 受入基準 → テストケース マッピング

| AC | テストケース |
|----|------------|
| AC-01 | TC-01, TC-02 |
| AC-02 | TC-03 |
| AC-03 | TC-04 |
| AC-04 | TC-05 |
| AC-05 | TC-06 |
| AC-06 | TC-07 |
| AC-07 | TC-08 |
| AC-08 | TC-09 |
| AC-09 | TC-10 |

## テストケース一覧

### TC-01: EH-4 — test-cases.md なし → verify が exit 1 でブロック（apply 後）
| 項目 | 内容 |
|------|------|
| AC | AC-01 |
| 前提条件 | apply-script 適用済み、TASK-T4401 が test-cases.md のないダミーディレクトリ |
| 入力 | `PLANGATE_HOOK_STRICT=1 sh scripts/hooks/check-test-cases.sh TASK-T4401` |
| 期待出力 | exit 1、`[Hook EH-4 BLOCK]` メッセージ |
| 種別 | Unit（スクリプト直接呼び出し） |

### TC-02: EH-4 — test-cases.md あり → PASS
| 項目 | 内容 |
|------|------|
| AC | AC-01 |
| 前提条件 | TASK-T4402 に test-cases.md あり |
| 入力 | `sh scripts/hooks/check-test-cases.sh TASK-T4402` |
| 期待出力 | exit 0、`[Hook EH-4 PASS]` メッセージ |
| 種別 | Unit |

### TC-03: EH-5 — evidence なし → warn（exit 0）
| 項目 | 内容 |
|------|------|
| AC | AC-02 |
| 前提条件 | TASK-T4403 に evidence/ ディレクトリなし |
| 入力 | `sh scripts/hooks/check-verification-evidence.sh TASK-T4403` |
| 期待出力 | exit 0（warning mode）、`[Hook EH-5 WARNING]` メッセージ |
| 種別 | Unit |

### TC-04: EH-7 — C-3/C-4 ともに APPROVED → PASS
| 項目 | 内容 |
|------|------|
| AC | AC-03 |
| 前提条件 | TASK-T4404 に c3.json (APPROVED) + c4-approval.json (APPROVED) あり |
| 入力 | `sh scripts/hooks/check-merge-approvals.sh TASK-T4404` |
| 期待出力 | exit 0、`[Hook EH-7 PASS]` メッセージ |
| 種別 | Unit |

### TC-05: ta-44 テストスイート — apply 前 SKIP / apply 後 PASS
| 項目 | 内容 |
|------|------|
| AC | AC-04 |
| 前提条件 | apply-script 未適用の clean state |
| 入力 | `sh tests/run-tests.sh` |
| 期待出力 | ta-44 は SKIP（適用前）、既存 332 tests は 0 FAIL |
| 種別 | Integration |

### TC-06: settings-wiring-contract.md に CLI 配線セクション存在確認
| 項目 | 内容 |
|------|------|
| AC | AC-05 |
| 前提条件 | T-06 実施後 |
| 入力 | `grep -c "CLI 配線" docs/ai/settings-wiring-contract.md` |
| 期待出力 | 1 以上 |
| 種別 | Integration |

### TC-07: EHS-1〜3 設計セクション — hook-enforcement.md 存在確認
| 項目 | 内容 |
|------|------|
| AC | AC-06 |
| 前提条件 | T-07 実施後 |
| 入力 | `grep -c "EHS-1\|EHS-2\|EHS-3" docs/ai/hook-enforcement.md` |
| 期待出力 | 3 以上 |
| 種別 | Integration |

### TC-08: doctor が CLI Hook Wiring セクションを出力（apply 後）
| 項目 | 内容 |
|------|------|
| AC | AC-07 |
| 前提条件 | apply-script 適用済み |
| 入力 | `bin/plangate doctor 2>&1` |
| 期待出力 | `=== CLI Hook Wiring` または `CLI Hook Wiring` を含む行 |
| 種別 | Integration（apply 後） |

### TC-09: metrics collect / report が動作する（#529 dogfooding）
| 項目 | 内容 |
|------|------|
| AC | AC-08 |
| 前提条件 | TASK-0143 working directory 存在 |
| 入力 | `bin/plangate metrics TASK-0143 --collect && bin/plangate metrics TASK-0143 --report` |
| 期待出力 | exit 0、events.ndjson に 1 件以上のエントリ |
| 種別 | Integration |

### TC-10: improvement-seeds.md に TASK-0143 エントリ確認（#529 dogfooding）
| 項目 | 内容 |
|------|------|
| AC | AC-09 |
| 前提条件 | WF-06 retro opt-in 完了後 |
| 入力 | `grep -c "TASK-0143" docs/working/improvement-seeds.md` |
| 期待出力 | 1 以上 |
| 種別 | Integration |

## エッジケース

| # | エッジケース | 対処 |
|---|------------|------|
| E-01 | apply-script を複数回 --apply した場合 | idempotent: 2 回目は "already applied" を検出して SKIP |
| E-02 | test-cases.md が空ファイルの場合 | EH-4 は existence のみチェック → PASS（空でも PASS） |
| E-03 | evidence/ ディレクトリが空の場合 | EH-5 は VIOLATION（空ディレクトリは evidence なし扱い） |
| E-04 | bin/plangate が未インストールの場合 | TC-08/09 は前提確認で SKIP |
