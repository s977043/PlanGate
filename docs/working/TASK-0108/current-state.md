# TASK-0108 current-state

## 現在のフェーズ

**plan + todo + test-cases + review-self (C-1 v1 総合 94 / blocker 0) 完成**。C-3 ゲート (Human-owned) 待ち。短期 #1+#2 は PR #311 で完了済 (独立)。

## 直近の作業

- 2026-05-22: Codex+Gemini 公開サイト評価 (#310) → HIGH 2 件を短期 PR #311 で即時実装
- 2026-05-22: 残 5 項目 (#3-#7) を TASK-0108 PBI INPUT として起票
- 2026-05-22: Codex 優先順相談 → TASK-0108 先で確定 → plan/todo/test-cases/review-self 自律生成

## 次のアクション

1. **Human**: pbi-input + plan + todo + test-cases + review-self を確認
2. **Human**: C-3 ゲート判定 → approvals/c3.json 発行
3. **AI**: exec 着手 (T-01..T-11) + C-2 外部レビュー (T-10 で Codex+Gemini 再委任)
4. handoff + V-1 → PR → C-4 → merge

## ブロッカー

- なし（#311 マージ待ちのみ、plan_hash 算出には main 反映後が必要）

## 注意点

- 呼称統合 (#7 LOW) は破壊回避のため対応表方式（既存 ABCD 参照は残置）
- #310 の auto-close は本 PBI 完了 PR で（短期 #311 単独では行わない）


## 進捗 (2026-05-27 更新)

| Phase | 状態 |
|-------|------|
| B (plan 生成) | ✅ |
| C-1 (review-self) | ✅ PASS 96/100 |
| C-2 (proactive R-001..R-006) | ✅ 反映済 |
| T-01 (read-only 調査) | ✅ PR #373 merged |
| **#356 で 5 項目先行完了** | ✅ (#1/#2/#4/#5/#6 達成、本 PBI scope 縮小) |
| C-3 (c3.json) | ⏳ Human 発行待ち |
| exec (Step 1 + Step 5 + Step 7) | ⏳ |

## 実 scope

- **Step 1 (#3)**: 30-min first run 統一 (Phase 0 正本明示)
- **Step 5 (#7)**: ABCD ↔ WF 呼称統合
- Step 6 (任意 C-2 再委任)
- Step 7 (handoff)
