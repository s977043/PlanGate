---
task_id: TASK-0070
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-0070

> P4(d): Hook EH-3 (check-plan-hash.sh) ファイルパス感応型 SKIP
> 起源: TASK-0069 振り返り P4 / Gemini 外部セキュリティレビュー

## Context / Why

Hook EH-3 (`scripts/hooks/check-plan-hash.sh`) は C-3 承認後の `plan.md` 改ざんを
SHA-256 で検出する PreToolUse 強制 Hook。しかし TASK 文脈（`PLANGATE_HOOK_TASK` /
位置引数）が無い汎用 Edit/Write では一律 `exit 2` でブロックされる。

このため TASK-0069 期間中、ブロック回避のための heredoc パターンが常態化し、
編集トレーサビリティが劣化。EH-3 は「回避前提」となり強制力が形骸化した。

P4 改善案を外部レビュー（Gemini）。単純な「TASK 無し→SKIP」(P4(a)) は
**攻撃経路あり**と判定: エージェントが故意に `PLANGATE_HOOK_TASK` を unset して
`plan.md` を編集すれば C-3 ハッシュ検査を完全バイパスできる。
Gemini は P4(d)（ファイルパス感応型 2 段ロジック）を推奨。

## What — Scope

### In scope

- `check-plan-hash.sh` の TASK resolution 部を P4(d) ロジックに置換:
  - TASK 文脈なし & 対象が `*/plan.md` または `plan.md` → BLOCK (exit 2)
  - TASK 文脈なし & plan.md 以外 → SKIP (exit 0) + 監査ログ
  - `PLANGATE_HOOK_STRICT=1` → 従来どおり no-task 一律 block（後方互換）
  - TASK 文脈あり → 従来どおりハッシュ検査
- 対象ファイルパス解決: `PLANGATE_HOOK_FILE` env → `$2` → stdin JSON
  `file_path` の順（codebase 慣行 `check-forbidden-files.sh` に準拠）
- 監査ログに SKIP/VIOLATION 理由と対象パスを記録

- `settings.example.json` / `.claude/settings*.json` への `PLANGATE_HOOK_FILE` wiring 追加（C-3 で F1-b 採用により In scope 格上げ）

### Out of scope

- 他 Hook（EH-1/2/4-8）の同種改修
- stdin JSON パーサの汎用ライブラリ化

## Acceptance Criteria

- [ ] AC-1: TASK 文脈なしで `plan.md` を編集対象にすると exit 2（BLOCK）し、監査ログに VIOLATION + 対象パスが残る
- [ ] AC-2: TASK 文脈なしで plan.md 以外を編集対象にすると exit 0（SKIP）し、監査ログに SKIP 理由が残る
- [ ] AC-3: `PLANGATE_HOOK_STRICT=1` の場合、TASK 文脈なしは対象に関わらず exit 2
- [ ] AC-4: TASK 文脈ありの場合、従来のハッシュ一致 PASS / 不一致挙動が不変
- [ ] AC-5: 対象パスは `PLANGATE_HOOK_FILE` / `\$2` / stdin JSON の優先順で解決
- [ ] AC-6: 既存の bypass (`PLANGATE_BYPASS_HOOK=1`) は不変
- [ ] AC-7: `dash -n` で構文エラーなし（POSIX sh 準拠維持）
- [ ] AC-8: EH-3 wiring が `PLANGATE_HOOK_FILE` を渡し、TASK 文脈なし plan.md 編集を実運用でも BLOCK できる（F-1/F1-b 対策）

## Notes from Refinement

- Gemini 推奨原文: 「"TASK が無いから検査しない" ではなく "検査が必要な
  ファイル(plan.md)なのに TASK が無いから編集させない"」が強制力と柔軟性を両立
- 実装パターンは `check-forbidden-files.sh` の
  `target_file=\${PLANGATE_HOOK_FILE:-\${2:-}}` を踏襲
- 設計パッチ草案 (/tmp/p4d-check-plan-hash.patch) は本 PBI で再検証のうえ反映（草案を鵜呑みにしない）

## Estimation Evidence

**Risks**: セキュリティ強制 Hook の挙動変更 → 攻撃面の再評価必須（V-3 外部レビュー）
**Unknowns**: Claude Code PreToolUse の stdin JSON 形式の安定性（fallback で吸収）
**Assumptions**: read-only・TASK 文脈なし汎用編集が SKIP されてよい（Gemini 合意済み）。Mode: security のため最低「中」(standard)、V-3 外部レビュー必須
