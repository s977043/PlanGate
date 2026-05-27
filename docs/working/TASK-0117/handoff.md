# TASK-0117 handoff

> WF-05 Verify & Handoff 完了パッケージ (Rule 5 必須 6 要素)
> Issue: [#351](https://github.com/s977043/plangate/issues/351)

## 概要

plan 段階に「事前メトリクス検証」mandatory gate を導入し、A → B 遷移時の規模見積もりギャップ (process drift の主因) を構造的に防ぐ。PocketEitan PR #371 の最小ポート。

## 1. 要件適合確認結果 (AC-1..AC-8)

| AC | TC | 結果 |
|----|----|------|
| AC-1 skill に「事前メトリクス検証」セクション追加 | TC-01 | ✅ PASS |
| AC-2 検証コマンド例 (grep/find/rg) 明記 | TC-02 | ✅ PASS |
| AC-3 判定基準数値 (3 倍 / 1〜3 倍 / < 1 倍) 明記 | TC-03 | ✅ PASS |
| AC-4 PocketEitan 実例 (1697 file / 17 group) 記載 | TC-04 | ✅ PASS |
| AC-5 TASK-0112 / mode-classification 相互参照 | TC-05 | ✅ PASS |
| AC-6 ta-19 機械検証 | TC-06/TC-10 | ✅ PASS (10/10) |
| AC-7 markdownlint + 既存テスト regression なし | TC-07 | ✅ tests/run-tests.sh 126 passed / 0 failed |
| AC-8 plan.md template `## Metrics Evidence` 欄 | TC-08 | ✅ PASS |

## 2. 既知課題一覧

| ID | 内容 | 重要度 | 取扱い |
|----|------|--------|--------|
| K-1 | CLI 化 (`bin/plangate validate --metrics`) は本 PBI scope 外 (V2 候補) | info | #352 codex-mvp-split / 別 PBI |
| K-2 | TASK-0112 (mode-classification 例外ルール) は plan merged だが exec 未実施。本 doc 適用時点で例外ルール本体未追加 → 安全側 (`lite_eligible=false` 明示扱い) で対応済 (R-006) | info | TASK-0112 exec 後の統合は follow-up |
| K-3 | LLM 解釈依存のソフトルール (Hook 強制ではない)。判定基準数値化 + 実例 + コマンド例の具体性で担保 | info | future hook 化は V2 候補 |

## 3. V2 候補 (今回 scope 外)

| 案 | 内容 |
|----|------|
| V2-A | `bin/plangate validate --metrics` で plan.md の Metrics Evidence 欄を機械検証 |
| V2-B | TASK-0112 exec 完了後、本 doc と例外ルールの統合確認 |
| V2-C | Hook 強制 (PreToolUse で plan 編集時に Metrics Evidence 欄不在を block) |
| V2-D | docs/ai-driven-development.md の `### Prompt 1` template にも Metrics Evidence 欄を追記 (R-006 / Gemini 提案) |

## 4. 妥協点

- skill 本体は薄い設計を維持 (順序のみ)、判定詳細は docs/ai/ 正本 (TASK-0117 R-001..R-005 / Codex 提案)
- Hook 強制化は scope 外 (V2-C 候補)
- TASK-0112 plan は merged だが本 PBI exec 時点で未適用 → 安全側で進行 (R-006)
- PocketEitan PR #371 は literal text で記録 (リンクではなく、外部参照のため)

## 5. 引き継ぎ文書 (5 分把握サマリ)

1. **B-1 → B-2 mandatory gate** として `.agents/skills/ai-dev-plan/SKILL.md` に「事前メトリクス検証」セクション追加
2. **判定基準** 数値化:
   - ≥ 3 倍 → スコープ縮小
   - 1〜3 倍 → 採用、Risks 記録
   - < 1 倍 → 採用、Mode 1 段下げ候補
3. **未取得時** は安全側 (Mode 引き上げ) に倒す (AC-8 一貫)
4. **正本 doc**: `docs/ai/plan-metrics-verification.md` (155 行、PocketEitan 1697 file 実例 + PlanGate TASK-0111/0117/0108 自己適用例 4 件)
5. **plan.md template** に `## Metrics Evidence` 欄を必須化 (AC-8)
6. **機械検証**: `tests/extras/ta-19-plan-metrics-verification.sh` (10 case、tests/run-tests.sh 自動 discovery)
7. **CLI 化** は V2 候補 (#352 等)

## 6. テスト結果サマリ

| カテゴリ | 結果 |
|---------|------|
| ta-19 (本 PBI 新規) | ✅ 10/10 PASS |
| tests/run-tests.sh (全体) | ✅ **126 passed / 0 failed** (ta-19 追加で 116 → 126 件) |
| markdownlint | PR CI で確認 |
| 規模メトリクス (本 PBI 自己適用 / #351) | ✅ 4 file (1.0 倍) → standard 維持 |

## 7. Refs

- Issue: [#351](https://github.com/s977043/plangate/issues/351)
- C-3 APPROVED: PR #382 merged 2026-05-27
- C-2 individual: PR #377 (Codex CONDITIONAL minor 5 / Gemini CONDITIONAL APPROVE minor 3、major 0 / 5 PBI 中最高品質)
- T-01 evidence: PR #371/#373 merged
- plan 更新 (R-001..R-005): PR #367 merged
- 参考実装: PocketEitan PR #371
- memory: `feedback_size_estimate_verify_before_adopt.md`
