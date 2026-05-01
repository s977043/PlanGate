# PBI INPUT PACKAGE: TASK-0056 / Issue #169 セッション A

> Source: [#169 残 Hook 実装（EH-1 / EH-3〜EH-7 / EHS-1）](https://github.com/s977043/plangate/issues/169)
> Mode: **critical**（実行 block を伴うが既存 EH-2 パターン踏襲で慎重実装）

## Context / Why

#157 で EH-2 / EHS-2 / EHS-3 を実装後、残 7 hook（EH-1 / EH-3〜EH-7 / EHS-1）は未対応。本 PBI（セッション A）で **EH-1 + EH-3** の 2 件を実装。`check-c3-approval.sh` の 3 mode 設計（default warning / strict block / bypass escape）+ 監査ログを踏襲することでパターン一貫性を保ち、誤検出時の作業妨害を最小化する。

## What

### In scope
- `scripts/hooks/check-plan-exists.sh`（EH-1）: `docs/working/$TASK/plan.md` 不在を warn / block
- `scripts/hooks/check-plan-hash.sh`（EH-3）: `approvals/c3.json` の `plan_hash` と現 `plan.md` の sha256 を突合
- 各 hook で 3 mode（default / strict / bypass）+ 監査ログ
- `tests/hooks/run-tests.sh` に EH-1 + EH-3 テスト 9 件追加（既存 12 → 21 件 PASS）
- `tests/fixtures/hooks/{plan-exists,plan-tampered,plan-clean}/` 等 fixture
- `.claude/settings.example.json` に EH-1 / EH-3 PreToolUse 登録例
- `docs/ai/hook-enforcement.md` Status v2 → v3、§ 4 表に 2 hook 追加

### Out of scope（次セッション B/C）
- EH-4 / EH-5 / EH-6 / EH-7 / EHS-1（残 5 hook）
- 実 `.claude/settings.json` への登録（手動 opt-in、本 PR は example のみ）

## Acceptance Criteria

- AC-1: `check-plan-exists.sh` は plan.md 不在で warn（default）/ block（strict）/ allow（bypass）
- AC-2: `check-plan-hash.sh` は plan_hash 不一致で warn（default）/ exit 1（strict）/ exit 0（bypass）
- AC-3: hook 単体テストが **21 件 PASS**（既存 12 + EH-1 5 件 + EH-3 4 件）
- AC-4: `tests/run-tests.sh` 全体で 24 件 PASS 維持（hook 子テストの内部数値が変動するのみ）
- AC-5: `.claude/settings.example.json` に EH-1 + EH-2 + EH-3 が並ぶ
- AC-6: `hook-enforcement.md` Status v3、5/10 hook 実装済を明記
- AC-7: 既存 EH-2 / EHS-2 / EHS-3 の挙動が無変更（後方互換）
