---
task_id: TASK-0140
artifact_type: pbi-input
schema_version: 1
status: final
---

# PBI INPUT PACKAGE — TASK-0140

## Context / Why

全体監査（2026-06-10 / PR #512）で `bin/plangate` の多数のサブコマンドが CLI テストスイート未カバーであることが発覚（issue #515）。  
現スイートは 297+ PASS と広いが、init / status / handoff / verify / eval など主要サブコマンドの正常系・異常系が未テスト。  
これにより bin/plangate の回帰を CI が検知できない状態が継続している。

また、issue #529（dogfooding）では「次 PBI から metrics 採取 + WF-06 retro opt-in」を試行することが求められており、本 PBI がその first run となる。

## What — Scope

### In scope

- 優先 1: `init` / `status` / `handoff` の正常系 + 異常系テスト
- 優先 2: `verify` / `eval` の正常系（smoke）テスト
- テストファイル: `tests/extras/ta-42-cli-subcommands.sh`
- `tests/run-tests.sh` へのエントリ登録
- テストは mktemp サンドボックス + register_cleanup パターンを必須適用
- metrics 収集: 各フェーズで `bin/plangate metrics TASK-0140 --collect`

### Out of scope

- timeline / keep-rate / context / resume / abort（優先度 3 以降、別 PBI）
- validate / plan-check / report（CI で実行済み）
- HO ファイル（bin/plangate / scripts/hooks / .claude/settings / .github）の変更
- #500 / #527 の hook 強化（別 PBI）

## Acceptance Criteria

- [ ] AC-1: `bin/plangate init TASK-XXXX` の正常系（新規作成）・異常系（既存 TASK での再実行）が各 1 ケース PASS
- [ ] AC-2: `bin/plangate status TASK-XXXX` の正常系（INDEX.md 存在）・異常系（TASK なし）が各 1 ケース PASS
- [ ] AC-3: `bin/plangate handoff TASK-XXXX` の正常系（テンプレートコピー）・異常系（TASK なし）が各 1 ケース PASS
- [ ] AC-4: `bin/plangate verify / eval` の smoke テスト（exit 0 or 1 の確定）が各 1 ケース PASS
- [ ] AC-5: 新規テストが tracked ファイル・docs/working/ を汚染しない（mktemp サンドボックス確認）
- [ ] AC-6: ta-42 が tests/run-tests.sh で認識・実行される

## Notes from Refinement

- mktemp サンドボックスパターン: tests/extras/ta-39-eh3-doc-light.sh を参照
- register_cleanup: tests/run-tests.sh の register_cleanup() を使用
- FIXTURES_DIR / PLANGATE_BIN は既存 extras と同じ参照方法

## Estimation Evidence

**Risks**: verify/eval は設定ファイル依存が深く、sandbox 環境で確実な異常系を構築しにくい  
**Unknowns**: handoff サブコマンドのテンプレートパスが環境依存する可能性  
**Assumptions**: 既存 ta-39/ta-41 パターンを踏襲できる
