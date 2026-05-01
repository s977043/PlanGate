---
task_id: TASK-0056
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-05-01
author: qa-reviewer
v1_release: ""
related_issue: 169
---

# Handoff: TASK-0056 / Issue #169 セッション A — EH-1 + EH-3 実装

## 1. 要件適合確認結果

| AC | 判定 | 根拠 |
|----|------|------|
| AC-1: EH-1 3 mode | PASS | `tests/hooks/run-tests.sh` で plan exists / no plan default / strict + no plan / bypass の 5 件 PASS（うち 1 件は plan exists、bypass の優先確認）|
| AC-2: EH-3 3 mode | PASS | matching / mismatch default / mismatch strict / bypass の 4 件 PASS |
| AC-3: hook 単体 21 PASS | PASS | `Results: 21 passed, 0 failed`（既存 12 + EH-1 5 + EH-3 4） |
| AC-4: run-tests.sh 24 PASS | PASS | `Results: 24 passed, 0 failed`（loader 経由 hook tests を内部 21 PASS で動作）|
| AC-5: settings.example に 3 hook | PASS | PreToolUse に check-plan-exists / check-c3-approval / check-plan-hash 並ぶ |
| AC-6: hook-enforcement v3 | PASS | `Status: v3 (Implementation: 5/10 hooks Done)`、§ 4 表に EH-1 + EH-3 追加 |
| AC-7: 既存 EH-2 無変更 | PASS | check-c3-approval.sh は無編集、tests/hooks の既存ケース 12 件 PASS 維持 |

**総合**: **7 / 7 PASS**

## 2. 既知課題一覧

| 課題 | Severity | 状態 |
|------|---------|------|
| EH-1 が `PLANGATE_HOOK_TASK` 未設定時 SKIP（false-positive guard）| info | accepted（既存 EH-2 と同パターン）|
| EH-3 が plan_hash の `sha256:` prefix 必須 | info | accepted（c3-approval.schema.json で pattern 検証済）|
| 共通ヘルパ（emit_judgment / log_event）は各 hook に個別定義 | info | accepted（共通化は v2 候補、過剰抽象化を避ける）|
| 残 5 hook（EH-4 / EH-5 / EH-6 / EH-7 / EHS-1）は **未実装** | minor | open（#169 セッション B/C で対応）|

## 3. V2 候補

| V2 候補 | 理由 | 優先度 |
|--------|------|--------|
| 共通ヘルパ `scripts/hooks/_lib.sh` を作って emit_judgment / log_event を共通化 | DRY | Low |
| EH-1 で編集対象 path から自動で TASK 推定 | UX | Low（false-positive リスクで現状の env 渡しが安全）|
| 残 5 hook（#169 セッション B/C）| 本 PBI の続き | High |

## 4. 妥協点

| 選択 | 諦めた代替 | 理由 |
|------|-----------|------|
| 1 PBI で EH-1 + EH-3 一括 | 2 PBI に分離 | 同じ「plan / plan_hash 系」グループ、test fixture も共有 |
| ヘルパ関数の共通化なし | scripts/hooks/_lib.sh で集約 | scripts/hooks/* は今 5 ファイル、過剰抽象化を避ける |
| EH-3 を CLI + PreToolUse 兼用 | PreToolUse 専用 | sha256 突合は CLI でも有用（plan-hash debug 等） |
| `.claude/settings.example.json` の opt-in | 実 settings.json に直接登録 | 既存方針踏襲、本セッションの作業妨害ゼロ |

## 5. 引き継ぎ文書

### 概要

#169（残 Hook EPIC）のセッション A として **EH-1 + EH-3** を実装。`check-c3-approval.sh` の 3 mode 設計を踏襲、tests/hooks/run-tests.sh で 12 → 21 件 PASS（+9）。`.claude/settings.example.json` に PreToolUse 3 hook（EH-1 / EH-2 / EH-3）が並んだ状態に。docs/ai/hook-enforcement.md は Status v2 → v3、5/10 hooks Done を明示。

主要成果:
- `scripts/hooks/check-plan-exists.sh`（EH-1、PreToolUse hook）
- `scripts/hooks/check-plan-hash.sh`（EH-3、PreToolUse hook + CLI 兼用）
- `tests/hooks/run-tests.sh` fixture 4 種追加（plan-exists / no-plan / hash-ok / hash-tampered）
- `.claude/settings.example.json` 更新
- `docs/ai/hook-enforcement.md` v2 → v3

### 触れないでほしいファイル

- `scripts/hooks/check-c3-approval.sh`: 既存 hook の structure を踏襲する基準パターン、変更すると EH-1 / EH-3 と整合崩壊
- `tests/hooks/run-tests.sh` の fixture sha256 計算部分: shasum / sha256sum の OS 差吸収、勝手な書き換え注意

### 次に手を入れるなら

- **#169 セッション B**: EH-4（test-cases なし V-1 block）+ EH-5（検証ログなし PR block）+ EH-6（forbidden_files 違反）
- **#169 セッション C**: EH-7（branch protection 連携）+ EHS-1（V-3 必須化）
- アンチパターン: 共通ヘルパを `_lib.sh` に切り出して各 hook を sourceする — 過剰抽象化、現状 5 ファイル × 各 50 行で十分単純

### 参照リンク

- Issue: <https://github.com/s977043/plangate/issues/169>
- 親パターン: `scripts/hooks/check-c3-approval.sh`（#157 / TASK-0048）
- retrospective T-1: `docs/working/retrospective-2026-05-01-s3.md` § Try T-1（残 Hook 実装の段階分割）

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP |
|---------|------|------|-----------|
| Hook 単体（tests/hooks/run-tests.sh）| **21** | **21** | 0 / 0 |
| Integration（tests/run-tests.sh）| 24 | 24 | 0 / 0 |

検証コマンド:
```sh
sh tests/hooks/run-tests.sh    # 21 PASS（うち EH-1 5 件 + EH-3 4 件 = 9 件追加）
sh tests/run-tests.sh          # 24 PASS（loader 経由）
```
