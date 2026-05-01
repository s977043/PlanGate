# EXECUTION PLAN: TASK-0048 / Issue #157

> Mode: **critical**

## Goal

PlanGate v8.3 で仕様化済の Hook 強制条件のうち、**EH-2 / EHS-2 / EHS-3** の 3 件を実装する。誤検出時の作業妨害を防ぐ 3 モード設計（default / strict / bypass）+ 監査ログで運用安全性を確保する。

## Constraints / Non-goals

- 既存ワークフロー（/ai-dev-workflow）の挙動は **default モードでは変更しない**
- 実 `.claude/settings.json` への登録は PR 後の手動操作（PR では example のみ）
- 全 Hook の実装は本 PBI 範囲外（EH-1 / EH-3〜7 / EHS-1 は次回 PBI）

## Approach Overview

### 1. Hook 実装（POSIX sh 3 件）

| Hook | 役割 | 入出力 |
|------|------|-------|
| `check-c3-approval.sh` | EH-2 PreToolUse | stdin: hook event JSON、stdout: `{"continue":bool,"stopReason":...}`、env: `PLANGATE_HOOK_TASK` で対象 TASK 明示 |
| `check-handoff-elements.sh` | EHS-2 CLI | arg: `<handoff path | TASK-XXXX>`、exit: 0/1 |
| `check-fix-loop.sh` | EHS-3 CLI | arg: `<TASK-XXXX> [increment]`、exit: 0/1、counter: `.fix-loop-count` |

### 2. 3 モード共通

| モード | 環境変数 | 挙動 |
|-------|---------|------|
| default | なし | warning + continue:true（exit 0）|
| strict | `PLANGATE_HOOK_STRICT=1` | block + continue:false（exit 1）|
| bypass | `PLANGATE_BYPASS_HOOK=1` | 常時 pass + 監査ログに `BYPASS` |

### 3. 監査ログ

`docs/working/_audit/hook-events.log` に append-only:

```text
<ISO8601 UTC>\t<level>\t<hook-name>\t<task-id>\t<message>
```

### 4. opt-in 設定

`.claude/settings.example.json` を新設。実適用は PR マージ後にユーザーが手動コピー。

### 5. テスト

- `tests/hooks/run-tests.sh`: 12 ケース（各 hook につき bypass / default / strict / increment）
- `tests/run-tests.sh` の TA-06 で子テストを呼び出し（PASS/FAIL のみ集計）

## Work Breakdown

| Step | Output | 🚩 |
|------|--------|----|
| 1 | scripts/hooks/check-c3-approval.sh | bypass / default / strict / approved 4 ケース手動確認 |
| 2 | scripts/hooks/check-handoff-elements.sh | complete/incomplete + strict 動作確認 |
| 3 | scripts/hooks/check-fix-loop.sh | counter 読み書き + increment + strict 動作確認 |
| 4 | tests/hooks/run-tests.sh + fixtures | 12 件 PASS |
| 5 | tests/run-tests.sh TA-06 統合 | 11 件 PASS（既存 10 + TA-06）|
| 6 | .claude/settings.example.json | yaml syntax + matcher Edit\|Write 確認 |
| 7 | docs/ai/hook-enforcement.md 更新 | Status v2 / Implementation: Done 明記 |
| 8 | TASK-0048/handoff.md | Rule 5 必須 |

## Files / Components to Touch

| ファイル | 種別 |
|---------|------|
| `scripts/hooks/check-c3-approval.sh` | 新規 |
| `scripts/hooks/check-handoff-elements.sh` | 新規 |
| `scripts/hooks/check-fix-loop.sh` | 新規 |
| `tests/hooks/run-tests.sh` | 新規 |
| `tests/fixtures/hooks/{has-c3,handoff-{complete,incomplete},...}` | 新規 |
| `tests/run-tests.sh` | 編集（TA-06 追加）|
| `.claude/settings.example.json` | 新規 |
| `docs/ai/hook-enforcement.md` | 編集（Status v2 / § 4 書き換え）|
| `docs/working/TASK-0048/*` | 新規 |

## Testing Strategy

- Unit: 各 hook が default / strict / bypass モードで期待通り動作（12 件）
- Integration: `tests/run-tests.sh` から子テストとして呼び出し（PASS / FAIL 集計）
- E2E: 本 PR 自身では実 settings.json には登録せず、example のみ。動作確認は手動 / 次回 PBI

## Risks & Mitigations

| Risk | Mitigation |
|------|----------|
| 実 settings.json 登録後の誤検出で AI 作業全体が止まる | default = warning モード、strict 切替は環境変数明示時のみ |
| bypass の濫用 | 監査 log に `BYPASS` レベルで append-only 記録、後追い検証可 |
| Claude Code hook spec の変更 | 公式仕様に従った最小実装（matcher / type:command / stdin JSON）|
| 本 PBI 範囲を超えた hook 実装誘惑（EH-1, EH-3〜7, EHS-1）| plan で明示的に out_of_scope、次回 PBI に分割 |

## Mode判定

**モード**: critical

**判定根拠**:
- 変更ファイル数: 9 → high-risk
- 受入基準数: 7 → high-risk
- 変更種別: **実行 block を伴うハード強制** → critical
- リスク: 誤検出 = 開発作業全体停止、ロールバックは settings.json 削除で容易だが影響大 → 高
- **最終判定**: critical（影響範囲広 + ロールバック手段必要）

## Questions / Unknowns

- 解決済: `.claude/settings.json` への直接登録はせず、example のみ提供（運用判断は user）
- 解決済: 3 モード設計で誤検出時の作業妨害を最小化

## 確認方法

- `sh tests/hooks/run-tests.sh` → 12 件 PASS
- `sh tests/run-tests.sh` → 11 件 PASS（TA-06 含む）
- 各 hook の bypass / default / strict 動作を手動確認済
- `docs/ai/hook-enforcement.md` Status が v2 / Implementation: Done
