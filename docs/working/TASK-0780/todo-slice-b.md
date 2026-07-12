# TASK-0780 (Slice B) TODO

## 前提（BLOCKED 解除条件）

- BLOCKED: #809（feat/809-arbiter-fail-closed）が **main にマージ済み** であること（validate_input / arbitrate の入力契約が確定してから着手。owner=human・unblock=#809 merged）

## 🤖 Agent（委託: sonnet / worktree / TDD・#809 マージ後の main 起点）

- [ ] SB-1: B-1..B-11 のテスト先行追加（RED） rollback:不要
- [ ] SB-2: 入力 `gates: {c1, breakdown}` を必須フィールド化（validate_input） rollback:revert
- [ ] SB-3: arbitrate に priority 1.7 を追加（scope=1.5 の後・lite=2 の前）。c1!="PASS" or breakdown!="pass" → HUMAN_ESCALATED rollback:revert
- [ ] SB-4: provenance に gates を刻む + POLICY_REF @v2 rollback:revert
- [ ] SB-5: decision-table.md に priority 1.7 行 + gates フィールド定義（HO 非対象 docs） rollback:revert
- [ ] SB-6: ai-loop-cycle SKILL 4 配置の Step 0（breakdown-gate 実行）+ Step 1（c1 evidence パス記録）+ 入力例に gates 追加 rollback:revert
- [ ] SB-7: sync + 全テスト + 敵対的レビュー（承認境界隣接のため必須）

## 👤 Human

- [ ] C-3（承認境界隣接＝mode 引き上げ。ただしユーザー自律指示の範囲内なら autonomous・status に記録）
- [ ] C-4 レビュー・マージ

## ⚠️ 依存

- SB-3 の priority 1.7 挿入位置は #809 の最終 arbitrate 構造（1.5 scope の実装）に依存。マージ後に実コードを読んで確定
