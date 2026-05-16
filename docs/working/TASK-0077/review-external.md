---
task_id: TASK-0077
artifact_type: review-external
schema_version: 1
status: done
phase: C-2
---

# C-2 外部レビュー — TASK-0077（F5-AD 計画）

critical PBI・計画のみ先行。Codex + Gemini 実行（両者出力あり）。

## 判定: Codex=CONDITIONAL(critical0/major3/minor3) / Gemini=CONDITIONAL(critical0/major1)

両者 critical なし・「計画のみ先行は正しいガバナンス選択」と確認。C-3 提示前に
major を plan/AC へ反映（F5-C の 1 回確定反映フローに従い AC-8〜13 として確定）。

| ID | Sev | 指摘 | 反映先 |
|----|-----|------|--------|
| R-001 | major | 判定不能/根拠不足/Plan Health 未算出/新規設計曖昧は必ず Standard・同期C-3 | AC-8 |
| R-002 | major | reject 巻き戻し具体化（ブランチ破棄/PR close/invalidation/監査/派生） | AC-9 |
| R-003 | major(Codex)+major(Gemini) | TASK-0071 hardening 抵触時 Lite/降格無効化（Hardening Override） | AC-10 |
| R-004 | minor | Lite=mode内包(`lite_eligible`)・critical 原則 Lite 不可/明示承認 | AC-11 |
| R-005 | minor | Lite「外部1本」は critical/major=0 要求・観点固定 | AC-12 |
| R-006 | minor | diff に rules/scripts/bin 実装変更→C-1 FAIL の機械ガード | AC-13 |

## 結論
両者「計画先行で進めてよい」。R-001〜006 を AC-8〜13 に確定反映済。
**次は C-3 = 承認境界可変化の是非の人間判断（本 PBI はここで停止）**。

## 出典
- Codex: /tmp/t0077-codex-c2.md（CONDITIONAL major3）
- Gemini: /tmp/t0077-gemini-c2.md（CONDITIONAL major1・Hardening Override）
