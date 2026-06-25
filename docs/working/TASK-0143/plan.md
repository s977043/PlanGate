---
task_id: TASK-0143
artifact_type: plan
schema_version: 1
status: draft
---

# EXECUTION PLAN — TASK-0143

## Goal

EH-4 / EH-5 を `bin/plangate verify` に CLI 配線し、EH-7 は `doctor` 経由で
可視化する。settings-wiring-contract.md に CLI 配線セクションを追加、
EHS-1〜3 の設計をドキュメント化し、ta-44 テストで配線確認を自動化する。
#529 dogfooding として metrics opt-in + WF-06 retro を初回実施。

## Constraints / Non-goals

- `bin/plangate` は HO パス → **AI は直接編集不可**。apply-script を作成し Human が適用する
- EHS-1〜3 の実装は本 PBI 外（設計・ドキュメント化のみ）
- `pr` / `merge` サブコマンドの新規実装は本 PBI 外
- EH-4/5/7 の PreToolUse hook 化は本 PBI 外

## Approach Overview

1. `cmd_verify` に EH-4（strict）+ EH-5（warn）を追加する apply-script を作成
2. `cmd_doctor` に `=== CLI Hook Wiring (EH-4/5/7) ===` セクションを追加（apply-script 経由）
3. `docs/ai/settings-wiring-contract.md` に CLI 配線セクションを追記（AI 直接編集可）
4. `docs/ai/hook-enforcement.md` 配線状態表を更新、EHS-1〜3 設計を追記
5. `tests/extras/ta-44-eh457-cli-wiring.sh` を新規作成し `tests/run-tests.sh` に追加

## Work Breakdown

### Step 1: 調査（AI / 既完了）
- **Output**: EH-4/5/7 スクリプト仕様確認、cmd_verify の現状把握、ta-43 テスト構造把握
- **Owner**: agent
- **Risk**: 低（read-only）
- **rollback**: 不要

### Step 2: apply-script 作成（AI）
- `scripts/apply-task-0143-eh457-wiring.sh` を新規作成
- **変更内容（bin/plangate への patch）**:
  - `cmd_verify` 先頭に EH-4 呼び出し追加（strict=1 → test-cases.md なしは block）
  - `cmd_verify` の validate PASS 後に EH-5 呼び出し追加（warning mode = exit 0）
  - `cmd_doctor` に `=== CLI Hook Wiring (EH-4/5/7) ===` セクション追加
- **dry-run / --apply 両対応**（ta-43 パターンに準拠）
- **Output**: `scripts/apply-task-0143-eh457-wiring.sh`
- **Owner**: agent
- **Risk**: 中（apply 待ち状態では機能未配線のまま）
- **rollback**: apply 前なら不要; apply 後は `git checkout bin/plangate`

### Step 3: docs/ai/ ドキュメント更新（AI）
- `docs/ai/settings-wiring-contract.md` に「CLI 配線（EH-4/5/7）」節を追加
- `docs/ai/hook-enforcement.md` 配線状態表を更新（EH-4/5 → ✅ CLI 配線、EH-7 doctor 可視化 → ⏳、EHS-1〜3 設計追加）
- **Output**: 2 ファイル更新
- **Owner**: agent
- **Risk**: 低（docs のみ）
- **rollback**: `git checkout docs/ai/settings-wiring-contract.md docs/ai/hook-enforcement.md`

### Step 4: ta-44 テスト作成（AI）
- `tests/extras/ta-44-eh457-cli-wiring.sh` を新規作成
- `tests/run-tests.sh` に source 追加
- **テスト内容**:
  - TC-01: apply-script 未適用時 → SKIP（bin/plangate grep で判定）
  - TC-02（apply 後）: `plangate verify` 実行時に EH-4 が audit log に VIOLATION を記録すること（test-cases.md なし → exit 1）
  - TC-03（apply 後）: doctor 出力に `CLI Hook Wiring` セクションが含まれること
  - TC-04（apply 後）: doctor が EH-4/5/7 スクリプトの存在を PASS/WARN で報告すること
- **Owner**: agent
- **Risk**: 低
- **rollback**: `git checkout tests/extras/ta-44-eh457-cli-wiring.sh tests/run-tests.sh`

### Step 5: Human apply + 検証（Human）
- 🚩 **Human Gate**: `sh scripts/apply-task-0143-eh457-wiring.sh --apply` 実行
- `sh tests/run-tests.sh` で 0 FAIL 確認
- **Owner**: human
- **Risk**: 高（bin/plangate 変更）
- **rollback**: `git checkout bin/plangate`

### Step 6: #529 dogfooding（AI）
- 各フェーズで `bin/plangate metrics TASK-0143 --collect` 実行
- 完了後に `docs/working/improvement-seeds.md` にエントリ追記
- **Owner**: agent
- **Risk**: 低
- **rollback**: 不要（append のみ）

## Files / Components to Touch

| ファイル | 変更種別 | HO | Owner |
|---------|---------|-----|-------|
| `bin/plangate` | Edit（apply-script 経由） | ✅ | Human (apply-script) |
| `scripts/apply-task-0143-eh457-wiring.sh` | 新規作成 | — | AI |
| `docs/ai/settings-wiring-contract.md` | Edit（CLI 配線節追加） | — | AI |
| `docs/ai/hook-enforcement.md` | Edit（配線表更新、EHS 設計追加） | — | AI |
| `tests/extras/ta-44-eh457-cli-wiring.sh` | 新規作成 | — | AI |
| `tests/run-tests.sh` | Edit（ta-44 source 追加） | — | AI |

## Testing Strategy

- **Unit**: ta-44 が apply 前に SKIP、apply 後に TC-02/03/04 PASS
- **Integration**: `sh tests/run-tests.sh` 0 FAIL（既存 332 tests + ta-44）
- **Verification**: `plangate verify TASK-0143` が EH-4 を呼び audit log に記録される
- **Manual**: apply-script dry-run で期待差分を確認してから --apply

## Risks & Mitigations

| リスク | 緩和策 |
|-------|-------|
| EH-5 が verify 後に呼ばれても evidence がない（常時 WARN） | warning mode のみ（exit 0）、FAIL ではなく WARN |
| apply-script の patch が bin/plangate の行番号変化で失敗 | grep/sed パターンベースの patch（行番号非依存） |
| EH-7 の verify 時呼び出しは C-4 未承認で常に WARN | EH-7 は verify に含めず doctor のみに限定 |
| ta-44 が apply 未適用環境で FAIL | apply 判定 → SKIP パターン（ta-43 踏襲） |

## Questions / Unknowns（解消済み）

- bin/plangate に pr/merge サブコマンド: **存在しない** → doctor 経由で EH-5/7 を案内
- cmd_validate が test-cases.md をチェック: **validate は artifact check（ファイル存在）のみ、audit log なし** → EH-4 別途追加が必要

## Mode 判定

**モード**: `high-risk`

**判定根拠**:
- 変更ファイル数: 6 → standard
- 変更種別: `bin/plangate`（Hardening Override 対象パス）→ **high-risk 強制**
- 影響範囲: plangate verify フロー全体に波及
- **最終判定**: `high-risk`（HO パス例外ルール適用）
- `lite_eligible`: false（HO パス = 強制）
