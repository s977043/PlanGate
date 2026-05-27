# TASK-0113 handoff

> WF-05 Verify & Handoff 完了パッケージ (Rule 5)
> Issue: [#355](https://github.com/s977043/plangate/issues/355)

## 概要

AI memory ツール (claude-mem 等) による AGENTS.md 等 SSoT 汚染を git pre-commit 層で検知 + block する hook を整備。PR #376/#383 で実害発生中の構造解消。

## 1. 要件適合確認結果 (AC-1..AC-8)

| AC | TC | 結果 |
|----|-----|------|
| AC-1 pre-commit 経由検知 + exit 1 | TC-01..03 | ✅ PASS |
| AC-2 検知パターン設定可能 (YAML) | TC-04/05 | ✅ PASS (schema validation) |
| AC-3 対象ファイル設定可能 | TC-06 | ✅ PASS |
| AC-4 --auto-revert mode + unstaged 保護 | TC-07 | ✅ PASS |
| AC-5 install テンプレ + script | TC-01b/TC-12 | ✅ PASS |
| AC-6 運用ガイド | TC-03 | ✅ PASS |
| AC-7 ta-16 unit test | TC-01..12 | ✅ **13/13 PASS** |
| AC-8 CI regression | tests/run-tests.sh | PR CI で確認 |

## 2. 既知課題一覧

| ID | 内容 | 重要度 | 取扱い |
|----|------|--------|--------|
| K-1 | full integration test (実 git repo で claude-mem 挿入 → block 確認) は CI 外 | info | manual / V-3 |
| K-2 | PyYAML 不在環境では JSON-like fallback 動作、CI 環境次第 | info | ta-16 TC-05 で SKIP 扱い |
| K-3 | PreToolUse 経路 (Claude/Codex/Cursor) には未配線 | info | V2 候補、scope 限定 (R-009) |

## 3. V2 候補

- PreToolUse hook 経路への配線 (JSON プロトコル対応)
- claude-mem 本体設定との連動 (本 hook は検知のみ)
- pattern auto-learn (誤検出データから機械学習)

## 4. 妥協点

- PreToolUse 経路は scope 外 (R-009、git pre-commit 専用)
- PyYAML 不在環境は JSON-like fallback (R-003)
- allowlist marker 適用範囲は pattern id 単位 + ファイル単位 (R-004)
- skip 条件で巨大 file (>1MB) / binary / rename / deleted を除外 (R-005、性能保護)

## 5. 引き継ぎ文書 (5 分把握サマリ)

1. **scripts/hooks/check-ai-memory-pollution.sh** (185 行、Hardening Override path)
   - YAML 設定 + 既定 fallback
   - allowlist marker (pattern id 単位)
   - skip 条件 (巨大 / binary / rename / deleted)
   - auto-revert mode + unstaged guard
2. **`.plangate-pollution-patterns.yaml`** + `schemas/plangate-pollution-patterns.schema.json`
3. **scripts/templates/pre-commit.sample** + scripts/install-pre-commit.sh (TASK-0114 並列構造)
4. **docs/ai/ai-memory-pollution-guard.md** (165 行、運用ガイド)
5. **tests/extras/ta-16-pollution-guard.sh** (13 case、ta-15 衝突回避済 / R-007 CRITICAL)
6. **Defense in Depth 3 層**: 本 hook (pre-commit) / TASK-0114 (pre-push) / TASK-0115 (rules)

## 6. テスト結果サマリ

| カテゴリ | 結果 |
|---------|------|
| ta-16 単体 | ✅ **13/13 PASS** |
| tests/run-tests.sh (全体) | PR CI で最終確認 (ta-16 追加で +13) |
| syntax check (sh -n) | ✅ hook + install 両 PASS |
| schema validation | ✅ VALID (PyYAML 環境) |
| 規模メトリクス (#351 自己適用) | plan 8 file vs 実 6 file = 0.75 倍 → standard 維持 |

## 7. Refs

- Issue: [#355](https://github.com/s977043/plangate/issues/355)
- C-3 APPROVED: PR #390 merged 2026-05-28
- C-2 individual: PR #358 (CRITICAL R-007 ta-15 衝突 → ta-16 リネーム解消、major 4 反映)
- 実害背景: PR #376 (TASK-0108) / PR #383 (TASK-0117) で AGENTS.md 誤混入
- 並列構造: TASK-0114 (#360) pre-push hook / TASK-0115 (#361) rules guard
- Defense in Depth: 3 層防御の最深層 (コンテンツ層)

<!-- plangate-pollution-allowlist:claude-mem-context -->
