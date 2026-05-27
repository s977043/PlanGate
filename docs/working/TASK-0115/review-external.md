# TASK-0115 review-external (C-2 individual proactive)

> 個別 C-2 proactive review (2026-05-27): Codex + Gemini

## 判定サマリ

| Reviewer | 判定 | 内訳 |
|----------|------|------|
| Codex | **CONDITIONAL** | major 2 + minor 3 |
| Gemini | **概ね APPROVE** | minor 3 |

## 集約 (R-001..R-008)

| ID | Lane | Sev | 内容 |
|----|------|-----|------|
| R-001 (codex) | 設計/セキュリティ | major | main は直接コミット禁止 (project-rules.md L66)。新ルール文言で「事前確認で OK」と読ませない注意 — main は禁止、その他 protected は明示確認必須に分ける |
| R-002 (codex) | 設計 | major | TASK-0114 (P-1) と層分離良好だが本 rule のスコープ明確化要 |
| R-003 (codex) | 保守性/テスト | minor | TC-02..TC-06 grep がファイル全体に当たる → 新セクション範囲を切ってから grep |
| R-004 (codex) | 拡張性 | minor | 重複定義回避設計は妥当 |
| R-005 (codex) | 可読性 | minor | section 構造明確 |
| R-006 (gemini) | コードベース | minor | TASK-0112 (PR #357) 例外ルールが未反映の可能性 → 安全側 (lite_eligible=false 明示扱い) |
| R-007 (gemini) | 検証 | minor | TC-05 INC 参照のリンク健全性を明示確認 |
| R-008 (gemini) | 構造 | minor | responsibility-classes.md 追記位置: 「既存ルール対応」セクション直前 |

## 反映方針 (次 PR)

- 新ルール文言で「main は禁止」「他 protected は明示確認」を分けて記述 (R-001)
- TC grep を section anchor 範囲付きに強化 (R-003)
- TASK-0112 未適用時の安全側明示 (R-006)
- TC-05 にリンク健全性確認追加 (R-007)
- 追記位置を「既存ルール対応」直前に明示 (R-008)
