---
task_id: TASK-0070
artifact_type: plan
schema_version: 1
status: draft
---

# EXECUTION PLAN — TASK-0070

## Goal

Hook EH-3 (`scripts/hooks/check-plan-hash.sh`) を、TASK 文脈が無い汎用編集を
不必要にブロックせず、かつ `plan.md` の C-3 ハッシュ強制力は維持する
「ファイルパス感応型 SKIP」(P4(d)) に改修する。

## Constraints / Non-goals

- POSIX sh (`dash`) 準拠を維持（bashism 禁止）
- 既存の `PLANGATE_BYPASS_HOOK` / `PLANGATE_HOOK_STRICT` / ハッシュ検査ロジックは不変
- settings wiring 追加は C-3(F1-b) で In scope 化（target_file 供給を保証しセキュリティ穴を塞ぐ）
- 草案パッチ /tmp/p4d-check-plan-hash.patch は参考。最終形は本 PBI で検証

## Approach Overview

`check-plan-hash.sh` の「TASK resolution」ブロック（現状: task_id 空なら
即 exit 2）を、対象ファイルパス解決 + 3 分岐に置換する:

1. `task_id = PLANGATE_HOOK_TASK | $1`
2. `target_file = PLANGATE_HOOK_FILE | $2 | stdin JSON file_path`
3. task_id 空のとき:
   - `target_file` が `*/plan.md`|`plan.md` → VIOLATION ログ + exit 2 (BLOCK)
   - `PLANGATE_HOOK_STRICT=1` → exit 2（後方互換）
   - それ以外 → SKIP ログ + exit 0
4. task_id ありは従来の plan_file/c3_file/ハッシュ検査へ（不変）

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 |
|------|------|--------|-------|------|----|
| S1 | 既存スクリプト構造と慣行 (check-forbidden-files.sh) を再確認 | 調査メモ | agent | low | - |
| S2 | テスト先行: TC-1〜TC-7 をシェルテストとして作成 | tests/hooks/test-check-plan-hash-p4d.sh | agent | med | 🚩テスト失敗を確認 |
| S3 | check-plan-hash.sh の TASK resolution 部を P4(d) に置換 | 差分 | agent | high | 🚩dash -n PASS |
| S4 | 全テスト green + 既存テスト回帰なし | テスト結果 | agent | med | 🚩全 AC 充足 |
| S4b | EH-3 wiring に PLANGATE_HOOK_FILE 追加 + 反映確認 | settings 差分 | agent | med | 🚩AC-8 |
| S5 | V-1 受け入れ検査 / V-3 外部レビュー(Codex+Gemini) | review-external.md | agent | med | - |

## Files / Components to Touch

- `scripts/hooks/check-plan-hash.sh`（中核改修）
- `tests/hooks/test-check-plan-hash-p4d.sh`（新規テスト。既存テスト配置に合わせる）
- `settings.example.json` / `.claude/settings.json` / `.claude/settings.example.json`（EH-3 wiring に `PLANGATE_HOOK_FILE` 追加・該当ファイルを S1 で特定）

## Testing Strategy

- Unit/Behavior: POSIX sh テストスクリプトで exit code + 監査ログ内容を検証
- 回帰: 既存 check-plan-hash 関連テストがあれば全実行
- Verification: `dash -n` 構文チェック、実際の hook 呼び出しシミュレーション
- E2E: PreToolUse 経由の plan.md 編集ブロック・非plan SKIP を手動確認

## Risks & Mitigations

- R1: stdin JSON 形式変動 → env/arg fallback を最優先にし stdin は最終手段
- R2: plan.md パターン誤判定（部分一致漏れ） → `*/plan.md` と `plan.md` 両対応 + テストで境界確認
- R3: セキュリティ強制力後退 → AC-1/AC-3 で BLOCK 経路を明示テスト + V-3 外部レビュー必須

## Questions / Unknowns

- 既存 hook テストの配置ディレクトリ（S1 で確認し test-cases.md に確定）

## Mode判定

**モード**: standard

**判定根拠**:
- 変更ファイル数: 3-5（スクリプト+テスト+settings群） → 中
- 受入基準数: 7 → 中
- 変更種別: セキュリティ強制 Hook の挙動変更 → 例外ルール「セキュリティ関連→最低中」
- リスク: 中〜高（強制力に直結）
- **最終判定**: standard（V-2 スキップ、V-3 外部レビュー必須。C-3=CONDITIONAL/F1-b 反映済み）
