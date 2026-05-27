# TASK-0109 handoff

> WF-05 Verify & Handoff 完了パッケージ (Rule 5)
> Issue: [#315](https://github.com/s977043/plangate/issues/315)

## 概要

Codex CLI provider integration を Claude Code parity レベルまで完成。`bin/plangate review --reviewer codex` を実装 (CRITICAL `--sandbox read-only` 含む) + `docs/rfc/provider-codex.md` 新規。

**T-01 hard gate 結論**: CX-2 (hook 配線) は **PR #347 で既達**。残作業は CX-1 + CX-3 + テストのみに scope 縮小。

## 1. 要件適合確認結果 (AC-1..AC-6)

| AC | TC | 結果 |
|----|-----|------|
| AC-1 bin/plangate review codex case 実装 | TC-01..05 | ✅ PASS |
| AC-2 .codex/hooks 配線済 (CX-2) | TC-06/07 | ✅ DONE via PR #347 |
| AC-3 docs/rfc/provider-codex.md | TC-08/08b | ✅ PASS (Role Mapping 含む) |
| AC-4 既存テスト regression なし | tests/run-tests.sh | PR CI で確認 |
| AC-5 ta-20 unit test | TC-01..09 | ✅ 10/10 PASS |
| AC-6 shellcheck + sh -n | TC-09 | ✅ PASS |

## 2. 既知課題一覧

| ID | 内容 | 重要度 | 取扱い |
|----|------|--------|--------|
| K-1 | `--no-verify` 相当の bypass は Codex CLI に標準なし (Claude/Cursor より strict) | info | strict は強み |
| K-2 | `codex exec` 実 実行は CI 環境では困難 (要 OPENAI_API_KEY) → ta-20 は wiring 検証のみ | info | V-3 で manual integration test |
| K-3 | TASK-0117 の事前メトリクス検証を本 PBI で自己適用 (規模 0.5 倍 → standard 維持 / TASK-0117 安全側 AC-8) | info | acknowledged |

## 3. V2 候補

- `bin/plangate exec --agent codex` ラッパ化 (現状 `codex exec` 直接)
- 外部 review の concurrent 実行 (Codex + Gemini 並列起動)
- `.codex/agents/` 動的 subagent 選択

## 4. 妥協点

- T-01 hard gate で CX-2 既達認定 → 元 plan の Step 3-4 を Out of scope に格上げ (PR #347 で先行完了)
- 規模 0.5 倍だが standard 維持 (bin/plangate = 承認境界周辺、TASK-0112 例外ルール該当の見込み)
- codex exec 実 integration test は CI 外 (要 API key)、ta-20 は wiring 検証に限定

## 5. 引き継ぎ文書 (5 分把握サマリ)

1. **CX-1 (本 PBI 新規)**: `bin/plangate review codex` case 実装、CRITICAL `--sandbox read-only` + timeout + --output-last-message + CLI 未 install check 全反映
2. **CX-2 (PR #347 既達)**: `.codex/hooks.json` で EH-1/2/3/6/9 全 5 hook 配線、`.codex/hooks/eh-bridge.sh` 汎用 bridge
3. **CX-3 (本 PBI 新規)**: `docs/rfc/provider-codex.md` (183 行、Architecture diagram + Role Mapping + Setup)
4. **ta-20 (本 PBI 新規)**: 10 case で CX-1/CX-2/CX-3 全要素検証
5. **Provider parity 達成**: Claude Code 同等レベル (hook 強制 + 外部レビュー + exec)

## 6. テスト結果サマリ

| カテゴリ | 結果 |
|---------|------|
| ta-20 単体 | ✅ **10/10 PASS** |
| ta-15 (codex-hook-bridge 既存) | ✅ PASS (再確認) |
| tests/run-tests.sh 全体 | PR CI で最終確認 (ta-20 追加で +10) |
| 規模メトリクス (#351 自己適用) | plan 8-10 → 実 5 file = 0.5 倍 → standard 維持 (安全側) |

## 7. Refs

- Issue: [#315](https://github.com/s977043/plangate/issues/315)
- C-3 APPROVED: PR #386 merged 2026-05-28
- C-2 individual: PR #323 (Codex CONDITIONAL major 3 + Gemini CRITICAL R-005 → 全反映)
- T-01 evidence: `evidence/t01-investigation.md` (CX-2 既達認定)
- CX-2 既達: PR #347 (`feat(.codex/hooks): EH-1/2/3/6/9 physical PreToolUse bridge`)
- 関連 RFC: provider-cursor.md / provider-gemini-cli.md / provider-opencode.md
