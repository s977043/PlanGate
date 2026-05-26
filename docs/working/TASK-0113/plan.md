# TASK-0113 EXECUTION PLAN

> Source: pbi-input.md / Issue #355 / Mode: **standard**
> Generated: 2026-05-26 / Codex 推奨優先順 C

## Goal

PlanGate 標準テンプレに AI memory 自動挿入検知 pre-commit hook を提供し、`<claude-mem-context>` 等の自動挿入による SSoT 汚染を構造的に防ぐ。PocketEitan の 5 リリース手動 revert 実害ベース。

## Constraints / Non-goals

### Constraints

- 既存 12/12 EH hook (Claude Code PreToolUse) には触らない (本 PBI は git pre-commit 層)
- `--auto-revert` は **opt-in 既定 OFF**
- false positive 防止のため allowlist marker を提供
- 既存テスト regression なし

### Non-goals

- claude-mem 本体改修
- PreToolUse 経路への配線 (別 PBI)
- AGENTS.md content lint 全般

## Approach Overview

(1) T-01 既存 hook scripts / `tests/hooks/` パターン把握、(2) T-02 `scripts/hooks/check-ai-memory-pollution.sh` 新規、(3) T-03 設定 schema (`.plangate-pollution-patterns.yaml`) 新規 + 既定 pattern 埋め込み、(4) T-04 `templates/pre-commit.sample` 提供 + `scripts/install-pre-commit.sh` 新規 (Human が opt-in 配置)、(5) T-05 `docs/ai/ai-memory-pollution-guard.md` 運用ガイド、(6) T-06 `tests/extras/ta-15-pollution-guard.sh` unit test。

## Work Breakdown

| # | Step | Output | Owner | Risk | 🚩 |
|---|------|--------|-------|------|----|
| 1 | **T-01 調査**: `.claude/hooks/` / `scripts/hooks/check-*` の既存 pattern 把握、`tests/hooks/` test patterns 確認 | 調査メモ | AI | low | 既存資産マップ |
| 2 | **T-02 hook 本体**: `scripts/hooks/check-ai-memory-pollution.sh` (POSIX sh, staged diff scan, pattern matching, exit 1 on match) | scripts/hooks/check-ai-memory-pollution.sh | AI | medium | pre-commit 経由で `<claude-mem-context>` 検出 + exit 1 |
| 3 | **T-03 設定**: `.plangate-pollution-patterns.yaml` schema + 既定 pattern (claude-mem-context) + 対象ファイル既定 (AGENTS.md) | .plangate-pollution-patterns.yaml + schemas/pollution-patterns.schema.json | AI | low | schema valid + 既定 pattern 動作 |
| 4 | **T-04 install**: `templates/pre-commit.sample` + `scripts/install-pre-commit.sh` (Human が opt-in で実行) | templates/pre-commit.sample / scripts/install-pre-commit.sh | AI | low | install 後 pre-commit で発火 |
| 5 | **T-05 doc**: `docs/ai/ai-memory-pollution-guard.md` (検知/対処/設定/false positive/allowlist marker) | docs/ai/ai-memory-pollution-guard.md | AI | low | Human が読んで対処可能 |
| 6 | **T-06 test**: `tests/extras/ta-15-pollution-guard.sh` (fixture 4 case: clean / claude-mem 挿入 / カスタム pattern / allowlist marker) | tests/extras/ta-15-pollution-guard.sh | AI | low | tests/run-tests.sh + ta-15 全 PASS |
| 7 | **T-07 handoff + V-1** | handoff.md | AI | low | AC-1..8 PASS |

## Files / Components to Touch

| ファイル | 性質 |
|---------|------|
| `scripts/hooks/check-ai-memory-pollution.sh` | 新規 (POSIX sh) |
| `.plangate-pollution-patterns.yaml` | 新規 (既定設定) |
| `schemas/pollution-patterns.schema.json` | 新規 |
| `templates/pre-commit.sample` | 新規 |
| `scripts/install-pre-commit.sh` | 新規 |
| `docs/ai/ai-memory-pollution-guard.md` | 新規 |
| `tests/extras/ta-15-pollution-guard.sh` | 新規 |
| `docs/working/TASK-0113/handoff.md` | WF-05 |

`.claude/settings.json` には触れない (Hardening Override 回避)。

## Testing Strategy

- **Unit**: fixture 4 case で hook 単体動作
- **Integration**: `git add` → `git commit` (pre-commit 経由) で発火確認
- **回帰**: 既存 tests/run-tests.sh + tests/hooks/run-tests.sh 維持
- **markdownlint + shellcheck**: 新規 sh / md 全件

## Risks & Mitigations

| Risk | Sev | Mitigation |
|------|-----|------------|
| false positive で正規 commit が block | medium | allowlist marker (`<!-- plangate-pollution-allowlist:... -->`) + 設定可能 pattern |
| pre-commit install 漏れ | low | doctor 拡張は follow-up、本 PBI は template + install script 提供のみ |
| 既存 husky / pre-commit との衝突 | low | template 提供のみ、配置は Human |
| 他 AI memory ツール pattern 未対応 | low | 設定可能 pattern で吸収、本 PBI は claude-mem のみ既定 |

## Mode 判定

**standard** (lite_eligible=false)

- 変更ファイル数: 8 (新規)
- 受入基準数: 8
- 変更種別: 新規 hook + 設定 + テンプレ + doc + test
- リスク: 中 (false positive リスク有、auto-revert opt-in で軽減)
- ロールバック: 容易 (新規 file 削除)
- 影響範囲: 本 PBI 配置時点では効果なし (Human が install するまで)

## 承認境界 / 自動 mode 補正

`scripts/hooks/` 配下は Hardening Override 対象 → mode-classification.md (PR #357 で更新予定) の例外ルール「承認境界周辺→最低 高」に該当する見込み。standard と high の境界だが、内容が **新規 file 追加** (既存 hook 改修ではない) + opt-in install で影響範囲が限定的なため **standard で C-3 判定を仰ぐ**。Human が C-3 で「高」必要と判断したら昇格可。
