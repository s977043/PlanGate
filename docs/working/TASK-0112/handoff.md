# TASK-0112 handoff

> WF-05 Verify & Handoff 完了パッケージ (Rule 5)
> TASK-0106 Retrospective Try アクション構造化

## 概要

`.claude/rules/mode-classification.md` の例外ルールに「承認境界周辺の変更 → 最低でも『高』」を追加。Hardening Override 対象パス改修 PBI の Mode 自動補正を構造化、自己例外矛盾の解消 (本 PBI 自身が standard、過去 plan の light は R-001 で補正済)。

## 1. 要件適合確認結果 (AC-1..AC-6)

| AC | 結果 |
|----|------|
| AC-1 例外ルール追記 (「承認境界周辺 → 最低 高」) | ✅ PASS |
| AC-2 対象パス 9 カテゴリ (check-plan-hash.sh 完全一致 / R-003) | ✅ PASS |
| AC-3 working-context.md AC-10/AC-8 相互参照 | ✅ PASS |
| AC-4 監査ログ一括変更 CLI 例外 (TASK-0110 例示) | ✅ PASS |
| AC-5 自動推定の安全側 (該当不確実→該当扱い / AC-8 一貫) | ✅ PASS |
| AC-6 markdownlint + リンク健全性 | PR CI で確認 |

## 2. 既知課題一覧

| ID | 内容 | 重要度 |
|----|------|--------|
| K-1 | TASK-0117 (#351 事前メトリクス検証) と相互参照のみ、機械統合は別 PBI (V2) | info |
| K-2 | 本 PBI 適用後の自動補正 (plan health 等) 機械実装は scope 外 | info |
| K-3 | `.claude/skills/` と `scripts/_*.py` は実 check-plan-hash.sh L124-134 の case 文に**含まれていない** ため、本 rule からも除外 (R-003/R-006) — 将来 hook 側を更新する場合は本 rule も同期要 | info |

## 3. V2 候補

- V2-A: plan-health 機械実装で本 rule を自動判定
- V2-B: bin/plangate validate で例外ルール該当 PBI を機械検出
- V2-C: scripts/hooks/check-plan-hash.sh 側で `.claude/skills/` `scripts/_*.py` を override 追加検討 (本 rule との同期前提)

## 4. 妥協点

- Hook 強制化は scope 外 (本 PBI は文言追記のみ、AC-8 安全側ルールは LLM 解釈依存)
- 9 カテゴリ厳密一致 → 将来の hook パターン拡張時は本 rule も同期要 (K-3)
- Human-owned patch (R-002): maintenance window 経由を不採用、PR ベース直接 patch (本 PBI exec で同一 PR に含めた)

## 5. 引き継ぎ文書 (5 分把握サマリ)

1. **新例外ルール**: 「承認境界周辺の変更 → 最低でも『高』」
2. **対象パス 9 カテゴリ**: check-plan-hash.sh L124-134 case 文と完全一致
3. **強制条件**: `lite_eligible=false` + Standard C-3 同期固定 (AC-10 と整合)
4. **監査ログ CLI 例外**: TASK-0110 batch acknowledge を例示
5. **安全側ルール**: 該当不確実 → 該当扱い (AC-8 と一貫)
6. **TASK-0117 (#351) との境界**: 本 PBI = mode 自動補正、TASK-0117 = plan 前メトリクス検証 (相互参照のみ、重複定義なし)
7. **TASK-0106 Retrospective Try 構造化**: 「承認境界周辺は最低 high-risk」を例外ルールとして明文化

## 6. テスト結果サマリ

| カテゴリ | 結果 |
|---------|------|
| 機械検証 (grep) | ✅ 新セクション存在、9 カテゴリ・AC-10 参照・AC-8 参照を確認 |
| markdownlint | PR CI で確認 |
| リンク健全性 | check-plan-hash.sh / working-context.md への相対 link 確認 |
| 規模メトリクス (#351 自己適用) | plan 1 file vs 実 1 file = 1.0 倍 → standard 維持 (R-001 反映で light→standard 補正済) |

## 7. Refs

- C-3 APPROVED: PR #393 merged 2026-05-28
- C-2 individual: PR #378 (Codex CONDITIONAL major 3 → 反映後 APPROVE / Gemini 概ね APPROVE)
- T-01 evidence: `evidence/t01-investigation.md`
- 出自: [TASK-0106 Retrospective](../TASK-0106/retrospective.md) §2 Problem / Try
- 関連 PBI: TASK-0117 (#351 事前メトリクス検証、相互参照) / TASK-0115 (rules error guard、同 file 階層) / TASK-0116 (release tag Iron Law)
