# TASK-1393 STATUS

## モード判定

high-risk（plan「Mode判定」）

## C-3 Gate: APPROVED

- 2026-09-28 22:45 UTC、Human（`bin/plangate approve TASK-1393`）。`plan_hash` は main の plan.md（PR #1407 squash `309d4c93`）の SHA-256 と一致することを確認済み

## フェーズ履歴

| 日時 | フェーズ | 内容 |
|---|---|---|
| 2026-09-29 08:00 | exec | 純関数部分の exec を開始（ブランチ `feat/1393-decision-core-pure`） |

## 計画からの変更点

- **Preflight PF-2〜PF-8 を満たす前に exec を開始**（Human 選択 2026-09-29「exec の純関数部分」）。範囲は #1391 の語彙に依存しない純関数部分に限定する: 値オブジェクト / `artifact_verdicts` / `assess_progress` / `make_decision_input` / `decide`。`decision_to_event_draft`（PF-5 のキー対応に依存）と、#1402 の呼び出し側の移行（PF-1）は範囲外
- モジュールの配置を `scripts/ai_loop_v2_decision.py` とする。#1402 の `scripts/ai-loop-v2/decision_core.py` とは別ファイルにして衝突を避ける。最終的な配置は PF-1 で #1402 の作り直しと合わせる
- I-11 の上限値（`MAX_INPUT_REFS` / `MAX_REQUIRED_VERIFIERS` / `MAX_REF_CHARS` / `MAX_DECISION_EVENT_BYTES` / `DECISION_FIXED_OVERHEAD`）と `make_previous_decision` が読む payload のキー名は暫定値とする（PF-5 で #1391 / #1392 と合意するまで）

## 残タスク

- [ ] 純関数部分の実装（TDD）
- [ ] レビュー → 修正 ループ 1
- [ ] レビュー → 修正 ループ 2
- [ ] レビュー → 修正 ループ 3
- [ ] Preflight PF-1〜PF-8（exec 完了の前提）
- [ ] `decision_to_event_draft`（PF-5 の後）
