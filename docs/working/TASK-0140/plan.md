---
task_id: TASK-0140
artifact_type: plan
schema_version: 1
---

# EXECUTION PLAN — TASK-0140

## Goal

`bin/plangate` の主要サブコマンド（init / status / handoff / verify / eval）に
CI テストスイートのカバレッジを追加し、回帰検知を機械化する。
併せて #529 dogfooding として metrics 採取 + WF-06 retro opt-in を本 PBI で初実施する。

## Constraints / Non-goals

- HO ファイル（bin/plangate / scripts/hooks / .github / .claude/settings）は変更しない
- tests/extras/ と tests/run-tests.sh の変更のみ
- timeline / keep-rate / context / resume は本 PBI scope 外

## Approach Overview

既存の ta-39/ta-41 のパターン（mktemp サンドボックス + register_cleanup）を踏襲し、
`ta-42-cli-subcommands.sh` を新規作成する。各サブコマンドの正常系・異常系を検証。

## Work Breakdown

### Step 1: 既存パターン調査（準備）
- Output: 実装ガイドライン確認
- Owner: AI
- Risk: 低

### Step 2: ta-42 テストファイル実装 🚩
- Output: `tests/extras/ta-42-cli-subcommands.sh` (TC-01〜12)
- Owner: AI
- Risk: 中（verify/eval の sandbox 環境依存）
- rollback: `git checkout tests/extras/ta-42-cli-subcommands.sh`

### Step 3: run-tests.sh へのエントリ登録 🚩
- Output: `tests/run-tests.sh` に ta-42 の source 追記
- Owner: AI
- Risk: 低
- rollback: `git checkout tests/run-tests.sh`

### Step 4: ローカルテスト実行・修正
- Output: 全テスト PASS 確認
- Owner: AI
- Risk: 中

### Step 5: metrics 収集 + V-1 受け入れ検査
- Output: events.ndjson 更新 + V-1 PASS
- Owner: AI

## Files / Components to Touch

- `tests/extras/ta-42-cli-subcommands.sh` (新規)
- `tests/run-tests.sh` (ta-42 エントリ追記)

## Testing Strategy

- Unit: ta-42 の各 TC がサブコマンドの期待動作を検証
- Integration: `sh tests/run-tests.sh` で全スイート PASS
- Verification: 既存テスト回帰なし

## Risks & Mitigations

| リスク | 対応 |
|--------|------|
| verify/eval が sandbox で予期しない副作用 | smoke のみ（exit code 確認）、実際の V-1 処理の副作用を mktemp で隔離 |
| handoff コマンドがテンプレートパスに絶対パスを使用 | テスト実行前に PLANGATE_ROOT 相当を確認 |

## Mode 判定

**モード**: standard

**判定根拠**:
- 変更ファイル数: 2 → light
- 受入基準数: 6 → standard
- 変更種別: test-only / 非HO → standard
- リスク: 中（サブコマンド依存の sandbox 挙動）→ standard
- **最終判定**: standard
