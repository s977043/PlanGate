# TASK-0114 handoff

> WF-05 Verify & Handoff 完了パッケージ (Rule 5)
> INC-2026-05-26-001 Prevention P-1 実装

## 概要

main / master / release/* への AI 直接 push を物理 block する pre-push hook template を整備。INC-2026-05-26-001 で発生した empty commit 49448c5 main 直接 push 事故への構造対策。Human-owned merge boundary を技術層で強化。

## 1. 要件適合確認結果 (AC-1..AC-7)

| AC | TC | 結果 |
|----|-----|------|
| AC-1 protected branch block + 明確メッセージ | TC-02 | ✅ PASS |
| AC-2 install + .bak 退避 | TC-01b/TC-08 | ✅ PASS |
| AC-3 env override 動作 | TC-04/TC-05 | ✅ PASS |
| AC-4 運用ガイド存在 + 主要 section | TC-07 | ✅ PASS |
| AC-5 ta-17 fixture | TC-01..09b | ✅ 全 11 case PASS |
| AC-6 regression なし | tests/run-tests.sh | PR CI で確認 |
| AC-7 shellcheck + markdownlint | PR CI で確認 |

## 2. 既知課題一覧

| ID | 内容 | 重要度 | 取扱い |
|----|------|--------|--------|
| K-1 | `--no-verify` で容易 bypass | info | 仕様 (緊急脱出弁)、最後の防衛線は P-2 GitHub branch protection |
| K-2 | TASK-0113 (claude-mem 検知) 未 exec のため scripts/templates/ は本 PBI で初作成 | info | TASK-0113 exec 時は本 PBI と並列共存 |
| K-3 | 本 hook は opt-in install、未 install では機能しない | info | install ガイド明記 |

## 3. V2 候補

- V2-A: shared library 化 (TASK-0113 install スクリプトと共通ロジック)
- V2-B: bin/plangate doctor で hook install 状態を検証

## 4. 妥協点

- `--no-verify` bypass を許容 (緊急脱出弁、P-2 が repo-wide enforcement)
- opt-in install (Human が自主的に sh install で配置)
- local hook のため AI が install 後すぐ自己防止できる構造

## 5. 引き継ぎ文書 (5 分把握サマリ)

1. **scripts/templates/pre-push.sample** (63 行、POSIX sh + set -f noglob)
2. **scripts/install-pre-push.sh** (idempotent + .bak rotation)
3. **docs/ai/direct-push-prevention.md** (118 行、install / bypass / Defense in Depth)
4. **tests/extras/ta-17-pre-push-guard.sh** (11 case 全 PASS)
5. **設計原則** (Gemini bot PR #379 反映):
   - `set -f` noglob でファイルシステム glob 暴発防止 (R-001)
   - case 右辺 unquoted で glob 評価 (R-007)
   - Defense in Depth: 第一防衛線 (本 hook) / 最後の防衛線 (P-2)

## 6. テスト結果サマリ

| カテゴリ | 結果 |
|---------|------|
| ta-17 | ✅ 11/11 PASS |
| tests/run-tests.sh (全体) | PR CI で確認 |

## 7. Refs

- INC: [INC-2026-05-26-001](../incidents/2026-05-26-empty-commit-direct-push.md) Prevention P-1
- C-3 APPROVED: PR #387 merged 2026-05-28
- C-2 individual: PR #377 (Codex CONDITIONAL major 2 → 反映後 APPROVE / Gemini CONDITIONAL APPROVE)
- Gemini bot PR #379: set -f noglob / Defense in Depth / TC-04 glob 強化
- 並列 PBI: TASK-0113 (claude-mem 検知 pre-commit) / TASK-0115 (rules error guard / INC P-3)
