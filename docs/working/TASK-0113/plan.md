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

(1) T-01 既存 hook scripts / `tests/hooks/` パターン把握 + 既存 `ta-15-codex-hook-bridge.sh` 連番衝突回避確認、(2) T-02 `scripts/hooks/check-ai-memory-pollution.sh` 新規 (git pre-commit 専用、python3 で YAML 読み)、(3) T-03 設定 schema `schemas/plangate-pollution-patterns.schema.json` (R-010 命名整合)、(4) T-04 `scripts/templates/pre-commit.sample` (R-008) + `scripts/install-pre-commit.sh`、(5) T-05 運用ガイド、(6) T-06 **`tests/extras/ta-16-pollution-guard.sh`** (R-007 CRITICAL: ta-15 衝突回避)。

**R-001..R-010 反映済** (review-external.md 参照)。

## Design Contract (R-002/R-004/R-009 確定)

- **scope**: git pre-commit 層のみ。PreToolUse JSON プロトコル経路は本 PBI scope 外 (将来 PBI で別検討)
- **--auto-revert 安全性**: 対象ファイルに unstaged diff がある場合は **auto-revert せず block**。`git diff --name-only` で unstaged を判定
- **allowlist marker 適用範囲**: pattern id 単位 + 対象ファイル単位。同一ファイル内で `<!-- plangate-pollution-allowlist:<pattern-id> -->` があればその pattern のみ無効化、他 pattern は引き続き検出
- **YAML parser**: python3 (PlanGate 既存依存) で読む。YAML 不在時は scripts 内埋め込み JSON 既定で fallback

## Work Breakdown

| # | Step | Output | Owner | Risk | 🚩 |
|---|------|--------|-------|------|----|
| 1 | **T-01 調査**: `.claude/hooks/` / `scripts/hooks/check-*` の既存 pattern 把握、`tests/hooks/` test patterns 確認 | 調査メモ | AI | low | 既存資産マップ |
| 2 | **T-02 hook 本体 (R-002/R-003/R-009)**: `scripts/hooks/check-ai-memory-pollution.sh` (POSIX sh、staged diff scan、**python3 sub-process で YAML 読み**、pattern matching、exit 1 on match)。**--auto-revert は unstaged diff 検出時 block**。git pre-commit 専用 (PreToolUse 経路 scope 外) | scripts/hooks/check-ai-memory-pollution.sh | AI | **high** (承認境界 + 破壊操作可) | pre-commit 経由検出 + unstaged 保護 + exit 1 |
| 3 | **T-03 設定 (R-010)**: `.plangate-pollution-patterns.yaml` + **`schemas/plangate-pollution-patterns.schema.json`** (既存命名規約整合) + 既定 pattern (claude-mem-context) + 対象ファイル既定 (AGENTS.md) | .plangate-pollution-patterns.yaml + schemas/plangate-pollution-patterns.schema.json | AI | low | schema valid |
| 4 | **T-04 install (R-008)**: **`scripts/templates/pre-commit.sample`** + `scripts/install-pre-commit.sh` (Human が opt-in で実行) | scripts/templates/pre-commit.sample / scripts/install-pre-commit.sh | AI | low | install 後 pre-commit で発火 |
| 5 | **T-05 doc**: `docs/ai/ai-memory-pollution-guard.md` (検知/対処/設定/false positive/allowlist marker) | docs/ai/ai-memory-pollution-guard.md | AI | low | Human が読んで対処可能 |
| 6 | **T-06 test (R-007 CRITICAL / R-005)**: **`tests/extras/ta-16-pollution-guard.sh`** (ta-15 既存衝突回避)。fixture 7 case: clean / claude-mem 挿入 / カスタム pattern / allowlist marker / **巨大 file (>1MB) / binary / rename / deleted** (R-005) / **unstaged 併存** (R-002) | tests/extras/ta-16-pollution-guard.sh | AI | low | tests/run-tests.sh + ta-16 全 PASS |
| 7 | **T-07 handoff + V-1** | handoff.md | AI | low | AC-1..8 PASS |

## Files / Components to Touch

| ファイル | 性質 |
|---------|------|
| `scripts/hooks/check-ai-memory-pollution.sh` | 新規 (POSIX sh + python3 sub-process for YAML) |
| `.plangate-pollution-patterns.yaml` | 新規 (既定設定) |
| `schemas/plangate-pollution-patterns.schema.json` | 新規 (R-010 命名整合) |
| `scripts/templates/pre-commit.sample` | 新規 (R-008 配置) |
| `scripts/install-pre-commit.sh` | 新規 |
| `docs/ai/ai-memory-pollution-guard.md` | 新規 |
| **`tests/extras/ta-16-pollution-guard.sh`** | 新規 (R-007 CRITICAL: ta-15 衝突回避) |
| `docs/working/TASK-0113/handoff.md` | WF-05 |

`.claude/settings.json` には触れない (PreToolUse 経路 scope 外 / R-009)。

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
| **unstaged 人間編集を auto-revert で破棄 (R-002)** | high | unstaged diff 検出時は auto-revert せず block、`git diff --name-only` で判定 |
| **ta-15 連番衝突 (R-007 CRITICAL)** | resolved | ta-16 に変更済 |
| **PreToolUse 経路混在で JSON プロトコル非対応 (R-009)** | resolved | git pre-commit 専用に scope 限定 |
| **承認境界対象が standard mode で進行 (R-001)** | resolved | high-risk に補正済 |

## Mode 判定

**high-risk** (lite_eligible=false / R-001 反映)

- 変更ファイル数: 9 (新規)
- 受入基準数: 8
- 変更種別: 新規 hook + 設定 + テンプレ + doc + test
- リスク: **高** (承認境界 `scripts/hooks/` に新規 hook 追加、auto-revert は破壊操作)
- ロールバック: 容易 (新規 file 削除)
- 影響範囲: 本 PBI 配置時点では効果なし (Human が install するまで)

## 承認境界 / mode 補正 (R-001)

`scripts/hooks/` 配下は Hardening Override 対象。TASK-0112 (PR #357 merged) の例外ルール「承認境界周辺→最低『高』」に該当 → **high-risk に補正済**。C-3 packet で Hardening Override 対象であることを明記し、maintenance window 経由で適用する想定。
