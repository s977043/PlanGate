# TASK-0112 review-external (C-2 individual proactive)

> 個別 C-2 proactive review (2026-05-27): Codex (設計妥当性) + Gemini (コードベース整合)

## 判定サマリ

| Reviewer | 判定 | 内訳 |
|----------|------|------|
| Codex | **CONDITIONAL** | major 3 + minor 2 |
| Gemini | **概ね APPROVE** | minor 2 |

## 集約 (R-001..R-007)

| ID | Lane | Sev | 内容 | reflected_in |
|----|------|-----|------|--------------|
| R-001 (codex) | 設計/セキュリティ | major | Mode 自己例外: 本 PBI が「承認境界周辺は最低 high-risk」を導入するのに自身は light で進める矛盾。設計レーン上は high-risk 相当扱いに補正 | _次 PR で plan 反映_ |
| R-002 (codex) | 設計/保守性 | major | T-02 を「maintenance window 経由」ではなく Human-owned patch / 明示的な承認境界変更手順に修正 | _次 PR で plan 反映_ |
| R-003 (codex) | 設計/可読性 | major | AC-2 と TC-02 を check-plan-hash.sh の override パターンへ完全一致 (実体は 9 カテゴリ (個別 case 15 entry を 9 カテゴリに分類)、.claude/skills/ scripts/_*.py は対象外) | _次 PR で plan 反映_ |
| R-004 (codex) | 設計 | minor | 正本同期の仕組みが手動依存 | acknowledged (Out of scope) |
| R-005 (codex) | テスト | minor | TC の grep 偽陽性リスクを anchor 付き grep に強化 | _次 PR で plan 反映_ |
| R-006 (gemini) | コードベース | minor | 対象パスパターンを check-plan-hash.sh と厳密に同期 (R-003 と同領域) | _次 PR で plan 反映_ |
| R-007 (gemini) | コードベース | minor | working-context.md AC-10 との関係明示 (mode 引き上げが lite_eligible=false を包含) | _次 PR で plan 反映_ |

## 反映方針

Codex R-001/R-002 が major で承認境界の運用フローに関わる重大指摘。次 PR で plan/todo/test-cases を反映:

- Mode を light → standard に補正 (R-001、自己例外の矛盾解消)
- T-02 適用方法を maintenance window 経由 から Human-owned patch (PR ベース) に修正 (R-002)
- 対象パス一覧を 9 カテゴリに修正 (R-003/R-006)
- TC の grep を anchor/section 範囲付きに強化 (R-005)
- AC-10 関係を pbi-input に明記 (R-007)
