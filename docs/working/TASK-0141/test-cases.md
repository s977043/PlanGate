# TEST CASES — TASK-0141

## 受入基準 → テストケースマッピング

| AC | テストケース |
|----|------------|
| AC-1 (EH-2 strict JSON) | TC-01〜TC-04（ta-43）|
| AC-2 (stdin fallback) | TC-05〜TC-06（ta-43）|
| AC-3 (ta-06 unsilence) | TC-07（run-tests.sh で PASS/FAIL 確認）|
| AC-4 (ta-43 自動テスト) | ta-43 の自己証明（TC-08）|
| AC-5 (全テスト PASS) | run-tests.sh FAIL=0 |

## テストケース一覧（ta-43）

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| TC-01 | 正常 c3.json (c3_status: APPROVED) | env TASK | continue:true（PASS/allow）| 正常系 |
| TC-02 | 壊れた JSON (not valid JSON) | env TASK | continue:true（warn + allow）| 異常系 |
| TC-03 | c3.json にコメント行あり + c3_status 埋め込み | env TASK | continue:true（warn, non-APPROVED）| 異常系 |
| TC-04 | c3.json に c3_status フィールドなし | env TASK | continue:true（warn）| 異常系 |
| TC-05 | stdin file_path に TASK-XXXX パス | stdin のみ | continue:true（APPROVED）| 正常系 |
| TC-06 | stdin なし + env なし | なし | continue:true（SKIP）| 正常系 |

## エッジケース

- c3.json が空ファイル → python3 は ValueError → 空文字 → 非 APPROVED（WARN）
- c3_status が APPROVED 以外（CONDITIONAL など）→ ブロック/warn
- stdin JSON 解析失敗 → task_id 空文字 → SKIP（false-positive 防止）
- file_path に TASK-XXXX が複数含まれる → 最初のマッチを使用
