# TASK-0118 handoff

> WF-05 Verify & Handoff 完了パッケージ (Rule 5)
> Issue: [#352](https://github.com/s977043/plangate/issues/352)

## 概要

規模 L 以上の機能を最小 MVP (Phase 1) に分割する `codex-mvp-split` skill / command を整備。属人化された Codex 相談プロセスを標準化。TASK-0117 (#351 事前メトリクス検証) の規模判定と AND 連携。

## 1. 要件適合確認結果 (AC-1..AC-8)

| AC | TC | 結果 |
|----|-----|------|
| AC-1 slash command 新規 | TC-01 | ✅ PASS |
| AC-2 skill 新規 + frontmatter | TC-02/TC-08 | ✅ PASS |
| AC-3 質問テンプレ 4 選択肢 + 工数 + 3 軸 | TC-03/TC-03b | ✅ PASS |
| AC-4 Phase 分割表 template | TC-04 | ✅ PASS (templates/README.md + doc) |
| AC-5 TASK-0117 連携明記 | TC-05 | ✅ PASS |
| AC-6 PocketEitan 実例 ≥ 2 件 | TC-06 | ✅ PASS (例文音読カード / TASK-srs-unification) |
| AC-7 ta-21 機械検証 | TC-01..08 | ✅ 9/9 PASS |
| AC-8 markdownlint + regression | tests/run-tests.sh | PR CI で確認 |

## 2. 既知課題一覧

| ID | 内容 | 重要度 |
|----|------|--------|
| K-1 | `docs/working/templates/pbi-input.md` template が不在 → Phase 分割表 は templates/README.md + codex-mvp-split.md に記述 (AC-4 該当 doc 解釈) | info |
| K-2 | proactive C-2 は本 PBI で skip (review-self PASS + PocketEitan 参考) → V-3 で補完可 | info |
| K-3 | CLI 自動 dispatch (bin/plangate mvp-split) は V2 候補 | info |

## 3. V2 候補

- V2-A: `bin/plangate mvp-split <topic>` で Codex 自動 dispatch
- V2-B: pbi-input.md template 新規作成 (現状 README 参照のみ)
- V2-C: TASK-0117 事前メトリクス検証から自動で本 skill 起動推奨表示

## 4. 妥協点

- pbi-input.md template 不在のため Phase 分割表 は templates/README.md に記述 (AC-4 「該当 doc」解釈)
- proactive C-2 skip (review-self PASS + 既存 PocketEitan 実装で risk 低)
- 質問テンプレは PocketEitan PR #371 最小ポート (literal text)

## 5. 引き継ぎ文書 (5 分把握サマリ)

1. **command**: `.claude/commands/codex-mvp-split.md` (slash command、質問テンプレ + Phase 分割表)
2. **skill**: `.agents/skills/codex-mvp-split/SKILL.md` (薄い skill、doc 正本参照、ai-dev-plan と同 pattern)
3. **doc**: `docs/ai/codex-mvp-split.md` (正本、質問テンプレ + 判定基準 + PocketEitan 実例 2 件 + TASK-0117 連携)
4. **template ref**: `docs/working/templates/README.md` に Phase 分割表
5. **test**: `tests/extras/ta-21-codex-mvp-split.sh` (9 case 全 PASS)
6. **質問テンプレ**: 4 選択肢 (A 独立 / B 拡張 / C 最小導線 / D Codex 独自) + 工数 S/M/L + 判断 3 軸 (ユーザ価値 / 実装独立性 / 次フェーズ拡張性)
7. **TASK-0117 (#351) 連携**: AND 関係、相互参照のみ (TASK-0117=規模判定、本 PBI=L 判定後の Phase 分割)

## 6. テスト結果サマリ

| カテゴリ | 結果 |
|---------|------|
| ta-21 単体 | ✅ **9/9 PASS** |
| tests/run-tests.sh 全体 | PR CI で確認 (ta-21 追加で +9) |
| markdownlint | PR CI で確認 |
| 規模メトリクス (#351 自己適用) | plan 6 file vs 実 6 file = 1.0 倍 → standard 維持 |

## 7. Refs

- Issue: [#352](https://github.com/s977043/plangate/issues/352)
- C-3 APPROVED: PR #399 merged 2026-05-28
- 前提 PBI: TASK-0117 (#351、merged 2026-05-27) 事前メトリクス検証
- 参考実装: PocketEitan PR #371 (`.claude/commands/codex-mvp-split.md`)
- 連携 doc: [`docs/ai/plan-metrics-verification.md`](../../ai/plan-metrics-verification.md)
