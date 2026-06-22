# TEST CASES — TASK-0138 (#528)

## 受入基準 → テストケースマッピング

| AC | TC |
|----|-----|
| AC-01: 非 HO .md → DOC_LIGHT_SKIP | TC-01, TC-02 |
| AC-02: HO パス → BLOCK | TC-03 |
| AC-03: plan.md → BLOCK | TC-04（既存 ta-14 カバー） |
| AC-04: skip-decision-log に EH-3_DOC_LIGHT_SKIP 記録 | TC-01（副次確認） |
| AC-05: ta-39 全 PASS + run-tests 認識 | TC-05 |
| AC-06: ta-14 回帰 PASS | TC-06 |

## テストケース一覧

### TC-01: docs 配下 .md → DOC_LIGHT_SKIP

- 前提: TASK 文脈なし（PLANGATE_HOOK_TASK 未設定）
- 入力: target_file = `docs/working/TASK-XXXX/status.md`
- 期待: exit 0 + stdout に `DOC_LIGHT_SKIP` 含む
- 副次: skip-decision-log.jsonl に `EH-3_DOC_LIGHT_SKIP` エントリ追記
- 種別: unit

### TC-02: .claude/skills 配下 .md → DOC_LIGHT_SKIP（非 HO パス）

- 前提: TASK 文脈なし
- 入力: target_file = `.claude/skills/some-skill/SKILL.md`
- 期待: exit 0 + stdout に `DOC_LIGHT_SKIP` 含む
- 種別: unit

### TC-03: HO パス .md → BLOCK

- 前提: TASK 文脈なし
- 入力: target_file = `.claude/rules/working-context.md`
- 期待: exit 2（HARDENING_OVERRIDE）
- 種別: unit（HO 境界の回帰）

### TC-04: plan.md → BLOCK（既存動作回帰）

- 前提: TASK 文脈なし
- 入力: target_file = `docs/working/TASK-XXXX/plan.md`
- 期待: exit 2（plan.md without TASK context）
- 種別: unit（ta-14 重複だが明示確認）

### TC-05: ta-39 が run-tests.sh で認識される

- 前提: `sh tests/run-tests.sh` 実行
- 入力: -
- 期待: ta-39 の TC が出力に含まれる
- 種別: integration

### TC-06: ta-14 全 TC 回帰 PASS

- 前提: apply 後の check-plan-hash.sh
- 入力: `sh tests/extras/ta-14-hook-eh3.sh`
- 期待: 全 TC PASS / FAIL ゼロ
- 種別: regression

## エッジケース

- `.MD`（大文字拡張子）→ doc-light 対象（ケース非感応）
- CLAUDE.md → HO BLOCK（ファイル名判定で上流 case 文が捕捉）
- AGENTS.md → HO BLOCK（同上）
