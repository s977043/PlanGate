# TASK-0117 review-external (C-2 individual proactive)

> 個別 C-2 proactive review (2026-05-27): Codex + Gemini

## 判定サマリ

| Reviewer | 判定 | 内訳 |
|----------|------|------|
| Codex | **CONDITIONAL** | minor 5 (major なし) |
| Gemini | **CONDITIONAL APPROVE** | minor 3 |

## 集約 (R-001..R-007)

| ID | Lane | Sev | 内容 |
|----|------|-----|------|
| R-001 (codex) | 可読性 | minor | メトリクス未取得時の分岐追加要 |
| R-002 (codex) | 拡張性 | minor | Hook 強制を scope 外、additive 変更方針良好 |
| R-003 (codex) | パフォーマンス | minor | grep -rln / find . が .git / node_modules を舐めるリスク → rg --files 優先、または -path ./.git -prune 明示 |
| R-004 (codex) | セキュリティ | minor | 承認境界・Lite 不可条件を明文化 |
| R-005 (codex) | 保守性 | minor | ta-19 は extras 自動 source、dispatcher 編集不要。grep 対象を skill + docs + 必須契約に広げる |
| R-006 (gemini) | コードベース | minor | docs/ai-driven-development.md ### Prompt 1 に Metrics Evidence セクション追加、B-1 指示組込 |
| R-007 (gemini) | 検証 | minor | TC-09 ta-19 に docs/ai-driven-development.md プロンプト更新も検証対象 |

## 反映方針 (次 PR)

- T-02/T-03 に Metrics Evidence 必須契約の置き場所明示 (R-005/R-006)
- T-03 コマンド例に exclude pattern 追加 (R-003)
- TC-09 ta-19 検証範囲拡大 (R-007)
- 未取得時の分岐 (実数取得不能 → 安全側 Mode 引き上げ) を skill に追記 (R-001/R-004)

**Codex major なし、Gemini も major なし** のため C-3 直近で APPROVE_FOR_C3 想定。
