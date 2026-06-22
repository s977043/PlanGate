# PBI INPUT PACKAGE — TASK-0141

## Context / Why

Issue #500「承認境界の強制実態ギャップ是正」の最優先サブセット。
EPIC #527 最終 open child。

EH-2（check-c3-approval.sh）は `grep|sed` による c3_status 抽出を使っており、
壊れた/細工された c3.json（コメント行や別キーに "c3_status": "APPROVED"）で
**承認判定が誤って通過するリスク**がある。EH-3 は既に python3 strict JSON 化済みのため、
EH-2 が非対称に脆い状態になっている。

また EH-1/EH-2 は `PLANGATE_HOOK_TASK` 環境変数が未設定 + arg なしの場合に
**無条件 SKIP（allow）** するため、Claude Code が native に env を注入しない
セッションでは**発火しない**。stdin `tool_input.file_path` から TASK-ID を解決する
fallback が必要。

Codex 設計相談 (2026-06-23):
- AC-1〜2 (settings wiring / doctor) は別 TASK に分離
- 本 TASK は AC-3/AC-4/テスト追加に集中

## What（Scope）

### In scope

- **AC-1**: EH-2（check-c3-approval.sh）の c3_status を python3 strict JSON 解析に変更
  - 壊れた JSON / 非 object / フィールド欠落 → fail-safe で空文字（= 非APPROVED）
  - EH-3（check-plan-hash.sh）と対称化
  - apply-script: `scripts/apply-task-0141-eh2-strict.sh`
- **AC-2**: EH-1/EH-2 に stdin `tool_input.file_path` fallback を追加
  - env `PLANGATE_HOOK_TASK` → arg → stdin JSON パースの優先順
  - `docs/working/TASK-XXXX/` パターンで TASK-ID を抽出
  - apply-script: 同スクリプトに統合（EH-1/EH-2 両方をパッチ）
- **AC-3**: `tests/extras/ta-06-hooks.sh` のログ握りつぶし解消
  - `>/dev/null 2>&1` を排除 → `[PASS]/[FAIL]` を run-tests.sh が確認できる形式に
  - 直接編集可（test ファイルは HO 非対象）
- **AC-4**: ta-43 新設（EH-2 strict JSON の自動テスト）
  - 壊れた JSON → allow（warn）
  - コメント埋め込み → allow（warn）
  - 正常 APPROVED JSON → pass
  - run-tests.sh に自動 include

### Out of scope

- AC-1,2 of #500 (settings-wiring-contract / doctor --check-settings) → 別 TASK
- EH-4/5/7 配線、EHS-1/2/3 発火条件 → 別 TASK
- maintenance.json 大規模 fixture（→ 既存 ta-06 の unsilence で先行カバー）

## 受入基準

| ID | 基準 |
|----|------|
| AC-1 | check-c3-approval.sh の c3_status が python3 strict JSON 解析（壊れた JSON → 非APPROVED 扱い） |
| AC-2 | EH-1/EH-2 が stdin `tool_input.file_path` から TASK-ID を解決（env/arg なし時） |
| AC-3 | ta-06 が hook テスト結果を PASS/FAIL として run-tests.sh に報告 |
| AC-4 | ta-43 が壊れた JSON・コメント埋め込み・正常 JSON の 3 ケースを検証 |
| AC-5 | 全テスト（run-tests.sh）が 300+ PASS、FAIL=0 |

## Notes from Refinement

- apply-script は HO パス（scripts/hooks/）をパッチするため Human が実行
- EH-1/EH-2 の stdin 読み込みは `cat 2>/dev/null || true` でハングしない実装必須
- python3 パターンは check-plan-hash.sh の既存実装を参照
- ta-43 はテスト専用の hooks copy を使って実環境を汚染しない（ta-39 パターン踏襲）

## Estimation Evidence

- Risks: HO apply-script のテストが困難（本体 hooks をコピーして dry-run）
- Unknowns: check-plan-exists.sh (EH-1) の stdin 構造（既読済み・同型のため低リスク）
- Assumptions: python3 は CI 環境に存在（既存 hooks で使用中）

**モード判定**: high-risk（承認境界 + HO apply-script + Hardening Override 対象パス）
