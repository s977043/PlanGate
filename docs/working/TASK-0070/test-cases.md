---
task_id: TASK-0070
artifact_type: test-cases
schema_version: 1
status: draft
---

# テストケース定義 — TASK-0070

## 受入基準 → テストケース マッピング

| AC | テストケース |
|----|------------|
| AC-1 | TC-1 |
| AC-2 | TC-2 |
| AC-3 | TC-3 |
| AC-4 | TC-4, TC-5 |
| AC-5 | TC-6 |
| AC-6 | TC-7 |
| AC-7 | TC-8 |

## テストケース一覧

### TC-1: TASK文脈なし + plan.md対象 → BLOCK
- 前提: PLANGATE_HOOK_TASK 未設定, 引数なし
- 入力: PLANGATE_HOOK_FILE=docs/working/TASK-0070/plan.md
- 期待: exit 2、監査ログに VIOLATION + 対象パス、stderr に BLOCK メッセージ
- 種別: behavior

### TC-2: TASK文脈なし + 非plan対象 → SKIP
- 前提: PLANGATE_HOOK_TASK 未設定
- 入力: PLANGATE_HOOK_FILE=src/foo.ts
- 期待: exit 0、監査ログに SKIP 理由 + 対象パス
- 種別: behavior

### TC-3: STRICT=1 + TASK文脈なし → BLOCK（対象不問）
- 前提: PLANGATE_HOOK_STRICT=1, PLANGATE_HOOK_TASK 未設定
- 入力: PLANGATE_HOOK_FILE=src/foo.ts
- 期待: exit 2
- 種別: behavior

### TC-4: TASK文脈あり + ハッシュ一致 → PASS（不変）
- 前提: 有効 TASK + plan.md + c3.json の plan_hash 一致
- 期待: exit 0、PASS ログ
- 種別: regression

### TC-5: TASK文脈あり + ハッシュ不一致 → 従来挙動（不変）
- 前提: 有効 TASK + plan.md 改変、STRICT=1
- 期待: exit 2（VIOLATION）。STRICT 未設定なら従来 warn 挙動
- 種別: regression

### TC-6: 対象パス解決の優先順
- 入力: PLANGATE_HOOK_FILE と $2 と stdin JSON を各々与える
- 期待: PLANGATE_HOOK_FILE > $2 > stdin JSON の順で採用
- 種別: behavior

### TC-7: PLANGATE_BYPASS_HOOK=1 → BYPASS（不変）
- 前提: PLANGATE_BYPASS_HOOK=1
- 期待: exit 0、BYPASS ログ（TASK/対象不問）
- 種別: regression

### TC-8: POSIX sh 構文
- 入力: dash -n scripts/hooks/check-plan-hash.sh
- 期待: 構文エラーなし（exit 0）
- 種別: static

## エッジケース

- E1: target_file が `plan.md`（パス無し相対）→ BLOCK 対象
- E2: target_file が `docs/working/TASK-X/plan.md.bak` → 非plan扱い（SKIP）
- E3: stdin が空 / 非JSON → target_file 空のまま、plan.md でなければ SKIP
- E4: target_file 空 + TASK文脈なし + 非STRICT → SKIP（plan.md と判定できない＝安全側は SKIP だが、TASK文脈なしの plan.md 編集は通常 PLANGATE_HOOK_FILE が来る前提。E4 は監査ログで追跡）
