# TASK-0107 INDEX

> L0 entry per `.claude/rules/working-context.md` Progressive Disclosure protocol.

- **Source**: User request 2026-05-21（Claude cowork `/setup-cowork` 相当を PlanGate に）
- **Title**: PlanGate Setup Command — `/plangate-setup` 三層構成（Command + Agent + Skill）+ Workflow-owned 永続ロック
- **Phase**: ✅ **完了** — PR #312 (実装) / PR #313 (cleanup) / PR #316 (Codex compat) 全 main マージ済。残: PR #314 OPEN (F-04 投資) + manual TC 実機確認 + 採用案判断
- **Mode 判定**: **high-risk**（`lite_eligible=false` 確定、Hardening Override 対象）
- **Status**: 全 working context + 実装ファイル main 反映済。**Claude Code + Codex CLI 両環境で動作可能**

## Files

| File | Role | Status |
|------|------|--------|
| `brainstorm.md` | 0: 検討ログ（履歴文書、r1 で更新済の注記あり） | ✅ |
| `pbi-input.md` | A: PBI INPUT PACKAGE (r1 + U7 / AC 13 件) | ✅ |
| `plan.md` | B: EXECUTION PLAN（8 Steps / high-risk） | ✅ |
| `todo.md` | B: EXECUTION TODO（T-01〜T-15） | ✅ |
| `test-cases.md` | B: テストケース定義（TC-01〜TC-22 + EC-01〜EC-04） | ✅ |
| `review-external.md` | C-2 R1 + R2 + R3 外部レビュー集約（R-001〜R-013 reflected pre-commit） | ✅ |
| `review-self.md` | C-1 セルフレビュー（17/17 PASS、blocker 0） | ✅ |
| `approvals/c3.json` | C-3 ゲート判定（user-explicit-delegation, AI 発行）| ✅ APPROVED |
| `status.md` | フェーズ履歴アーカイブ | ✅ |
| `current-state.md` | 現状スナップショット | ✅ |
| `decision-log.jsonl` | 判断履歴（append-only / 20+ entries） | ✅ |
| `handoff.md` | WF-05 完了パッケージ（Rule 5 必須 6 要素網羅） | ✅ T-08 で生成済 |

## Next action

1. ✅ C-2 R3 完了（R-009〜R-013 全 reflected pre-commit）
2. ✅ C-1 17/17 PASS
3. **👤 Human が C-3 ゲート判定**（`docs/working/TASK-0107/approvals/c3.json` 発行: `decision: APPROVED`、`plan_hash`、`c3_status: APPROVED`）
4. C-3 APPROVED → workflow-conductor が exec（T-01〜T-08）+ L-0/V-1/V-2/V-3/PR を制御
5. C-4 GitHub PR レビュー（👤）

## 重要

- 本 PBI は **責務 4 分類・Shadow Config 防止に直接接続**する Critical Infra 領域
- C-3 は **同期固定**（lite_eligible=false、Hardening Override 適用）
- AC-12 自己言及デッドロック注意: TASK-0107 自身の handoff 生成時、`bin/plangate doctor --check-settings PASS` が前提となるため、開発中に手動 wiring 完了が必要（Gemini 助言）
