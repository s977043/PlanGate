# C-1 セルフレビュー — TASK-0137 (#581 残要素3/4)

## Plan チェック（7項目）
- [x] P1 受入基準網羅: AC-01〜06 ↔ S1-S4 — PASS
- [x] P2 Unknowns: dispatch/ 粒度は最小枠・evidence と責務分離を確定 — PASS
- [x] P3 スコープ制御: review-principles(HO)/qa-reviewer(HO)/plugin rules(未tracked) を Out of scope — PASS
- [x] P4 テスト戦略: TC-01〜06 + Edge3、ls/grep/git diff/レビュー — PASS
- [x] P5 Work Breakdown Output: 各 S に Output/Owner/Risk/rollback(対象明示) — PASS
- [x] P6 依存関係: T1→T2→T3/T4 / T1→T5→T6→T7 — PASS
- [x] P7 動作検証自動化: ls/grep/git diff — PASS

## ToDo / TestCases チェック
- [x] タスク粒度 / depends_on / files / rollback(対象明示・high-risk必須) / 完了条件 — PASS
- [x] AC↔TC 紐付き / Edge(dispatch-evidence分離・§2-4不変・TDD条件付き) / 自動化可 — PASS

## 重複・過剰実装 + 承認境界チェック（本 PBI の肝）
- [x] 要素1(#583)/要素2(#584) と重複しない（要素3・4 のみ・AC-06）— PASS
- [x] **review-principles.md §2-4（5観点/Severity/判定基準）不変** — skill/template に追加レーンを置き rules 本体は参照のみ — PASS
- [x] HO 回避: skills/templates のみ・review-principles(HO)/qa-reviewer(HO)/plugin rules(未tracked) は触らない — PASS
- [x] dispatch/ は #584 の evidence/ dir 規約パターン踏襲（既存整合）— PASS

## 判定
**PASS**（high-risk・人間 C-3 必須）。要素3・4 を skills/templates の追加で実装し HO を回避。5観点不変。C-3 後 exec は AI 可。

## 簡易 C-1 再実行（C-2 反映後 / Refs R-001..R-003）
- R-001: todo T2 files に 4 テンプレ（brief/report/review-package/progress-ledger）全列挙 — PASS
- R-002: plugin/plangate/rules 表現を「指定3ファイル不在のため対象外・既存tracked rules も非改変」に訂正 — PASS
- R-003: 変更ファイル数を実数 9 に訂正（high-risk 根拠の整合）— PASS
- 判定: PASS（critical 0、major 1 + minor 2 反映済み）。人間 C-3（high-risk）待ち。
