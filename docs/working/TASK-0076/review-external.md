---
task_id: TASK-0076
artifact_type: review-external
schema_version: 1
status: done
phase: V-3
---

# V-3 外部レビュー — TASK-0076（F5-BC）

standard。Codex + Gemini 実行。

## 判定: Codex=critical0/major3/minor2、Gemini=major級境界指摘 → fix-loop で全反映

| # | Sev | 指摘 | 対応 |
|---|-----|------|------|
| MJ-1 | major | working-context CONDITIONAL が bin/plangate exec(APPROVED必須)/EH-3(plan_hash)と矛盾。c3.json 発行後反映だと mismatch | 順序固定: 集約→1回確定反映→簡易C-1→**人間が APPROVED c3.json(確定後plan_hash)発行**→exec。発行は反映の後と明記 |
| MJ-2 | major | scripts/ai-dev-plan.sh:86 旧ルール(WARN/FAIL で都度修正)が F5-C と衝突・AC-7 未完 | ai-dev-plan.sh を review-external 追記専用集約+exec開始時1回確定+Refs に整合 |
| MJ-3 | major | 2レーンでコード起因 AC/スコープ欠落の捕捉責任が空く | コードベース整合レーン出力を「追加すべきAC候補」として設計妥当性レーンへ返却・最終統合者が網羅判定に取り込む責務を明記（§2 不変） |
| mn-1 | minor | R-NNN→Refs がコミット依存のみで squash/rebase に弱い | review-external.md に `R-NNN|status|reflected_in|notes` 追記専用監査表 |
| mn-2 | minor | #227/#230 接続が参照止まり | #230 events 最小フィールド案 `{review_id,lane,severity,reflected_in,status}` 明記 |

## Gemini
- 「承認境界は変更しない」明言によりレーン分離の判定甘えは抑制されている＝妥当
- critical なし

## 確認
- 再 V-1: AC-1〜8 + MJ-1〜3 + minor 全 PASS、hook 48/0、§2〜4 無改変

## 出典
- Codex: /tmp/t0076-codex-v3.md（critical0/major3）
- Gemini: /tmp/t0076-gemini-v3.md
