# STATUS: TASK-0128

## モード判定
critical（承認境界中核 / R-007）

## フェーズ履歴
- 2026-06-12 05:00 B: plan/todo/test-cases 生成
- 2026-06-12 05:10 C-1: PASS（WARN minor 1）
- 2026-06-12 05:20 C-2: codex(gpt-5.5) R-001..R-008 → 全件反映（CONDITIONAL→確定反映→簡易C-1 PASS）
- 2026-06-12 05:40 exec: コア実装 + 検証（AI-owned 分）

## 実装状態（AI-owned 完了分）
| ファイル | 状態 |
|---------|------|
| scripts/apply-task-0128-approve.sh | ✅ 作成（cmd_approve + presence gate）・dry-run/構文/機能検証済 |
| scripts/apply-task-0128-token-guard-wiring.sh | ✅ 作成（Edit\|Write + Bash 配線）・dry-run 検証済 |
| scripts/check-approval-token-write.sh | ✅ 強化（Bash matcher 対応 / R-002）・全分岐検証済 |
| docs/c3-approval-command.md | ✅ 作成 |

## 検証結果（テストコピー / 単体）
- TC-04 非対話拒否（L1）exit=1・c3.json 未生成 ✅（AI 自己承認不可）
- TC-11 plan 不在 exit=1 ✅
- TC-06 --reject reason 必須 / 排他 ✅
- TC-11(schema) APPROVED/CONDITIONAL/REJECTED 全て schema VALID ✅（R-004/R-008）
- R-002 Bash `cat > c3.json` block / 読み取り許可 / approve は通す ✅
- 構文 sh -n / bash -n ✅

## 残タスク
- [ ] H02（人間）: apply-task-0128-approve.sh / token-guard-wiring.sh を dry-run → 適用（bin/plangate + settings）
- [ ] TC-01/17（TTY 正常系統合）: 適用後に人間 TTY で approve→validate PASS 確認
- [ ] TC-R1（maintenance 回帰）: maintenance は不変方針のため自明だが適用後に確認
- [ ] follow-up: working-context.md（HO）の C-3 手順を approve へ更新（別 apply-script）
- [ ] follow-up: maintenance の L1-L4 を _plangate_presence_gate へ移行（現状は重複・zero regression 優先）

## C-3 Gate
未（bootstrap: 機構適用後に plangate approve で正規承認予定）

## モード波及
critical → V-4 リリース前チェック対象
