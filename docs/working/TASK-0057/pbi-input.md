# PBI INPUT PACKAGE: TASK-0057 / Issue #169 セッション B

> Source: [#169 残 Hook 実装](https://github.com/s977043/plangate/issues/169)
> Mode: **critical**（実行 block を伴うが既存 8 hook の 3 mode 設計を踏襲）

## Context / Why

#169 EPIC のセッション B として **EH-4 + EH-5 + EH-6** の 3 hook を実装。セッション A（EH-1 + EH-3）と同じ 3 mode 設計（default warning / strict block / bypass escape）+ 監査ログを踏襲し、5/10 → 8/10 hooks に到達。残 EH-7 + EHS-1 はセッション C へ。

## What

### In scope
- `scripts/hooks/check-test-cases.sh`（EH-4、CLI）: V-1 前に test-cases.md 不在を warn / block
- `scripts/hooks/check-verification-evidence.sh`（EH-5、CLI）: PR 作成前に evidence/ 配下の verification 系ファイル不在を warn / block
- `scripts/hooks/check-forbidden-files.sh`（EH-6、PreToolUse + CLI）: 子 PBI YAML の forbidden_files glob と編集対象 path を突合
- `tests/hooks/run-tests.sh` に EH-4 + EH-5 + EH-6 ケース 12 件追加（21 → 33 件 PASS）
- `tests/fixtures/hooks/{test-cases-exists,evidence-ok,forbidden-parent}/` 等
- `.claude/settings.example.json` に EH-6 PreToolUse 登録例（EH-4 / EH-5 は CLI のため hook 登録不要）
- `docs/ai/hook-enforcement.md` Status v3 → v4、§ 4 表に 3 hook 追加

### Out of scope（次セッション C）
- EH-7（branch protection 連携、外部 GitHub API 操作）
- EHS-1（V-3 外部レビュー必須化）

## Acceptance Criteria

- AC-1: EH-4 が test-cases.md 不在で warn（default）/ exit 1（strict）/ exit 0（bypass）
- AC-2: EH-5 が evidence verification 不在で warn / exit 1 / exit 0
- AC-3: EH-6 が forbidden_files マッチで continue:false（strict）/ continue:true + WARNING（default）/ continue:true（bypass）
- AC-4: hook 単体テストが **33 件 PASS**（21 → 33）
- AC-5: tests/run-tests.sh が **24 件 PASS** 維持
- AC-6: `.claude/settings.example.json` に EH-6 が並ぶ
- AC-7: hook-enforcement.md Status v4 / 8/10 hooks Done
- AC-8: 既存 5 hook（EH-1 / EH-2 / EH-3 / EHS-2 / EHS-3）の挙動無変更
