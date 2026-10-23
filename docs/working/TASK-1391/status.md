# TASK-1391 作業ステータス

> 最終更新: 2026-10-23 10:00
> 現在フェーズ: C-3 待ち
> モード: high-risk（plan.md「Mode判定」）
> 発行時点 SHA (issued_at_commit): 該当なし（完了資産ではない。照合基準は `origin/main` `742f63f6`）

> 現在フェーズの値域は `INDEX.md` と共通（正本: `.claude/rules/working-context.md`）。
> TASK-1391 には `INDEX.md` / `current-state.md` / `approvals/` が無い（2026-10-23 時点）。

## フェーズ履歴

| 日時 (YYYY-MM-DD HH:mm) | フェーズ | 結果 / メモ |
|------------------------|---------|------------|
| 2026-09-24 02:35 | plan | Phase 1A plan（`a6b96168`） |
| — | exec | Phase 1A 初期実装は #1402（`3331e5c4`）で main に入った（plan Current verdict） |
| 2026-10-22 09:07 | plan / C-1 / C-2 | Phase 1B 差分計画へ改訂（#1602 / `69387d32`、Revision 2.4）。C-2 R1〜R3 と R3 後スコープ検証を反映、簡易 C-1 PASS（WARN 2 件） |
| 2026-10-22 17:55 | C-3 待ち | #1393 PF-5 の Human 決定を review-external に記録（#1605 / `742f63f6`）。本 plan は変更なし |
| 2026-10-23 10:00 | C-3 待ち | 本 status.md を新設。`approvals/` 無し = C-3 未実施 |

## #1393 PF-5 の合意（2026-10-22、Human 決定 / TASK-1393 R-085〜R-088）

- R-085（PF-5-1）: `MAX_DECISION_EVENT_BYTES` は envelope + binding キーを含む event 全体の canonical size に一本化。#1392 の envelope overhead は 0
- R-086（PF-5-2）: 定数は新設 `scripts/ai-loop-v2/limits.py`（葉 module、所有者 #1393）
- R-087（PF-5-3）: 仮値を fixture で固定（`MAX_INPUT_REFS=256` / `MAX_REQUIRED_VERIFIERS=16` / `MAX_REF_CHARS=256`、`MAX_DECISION_EVENT_BYTES` は算出値を切上げ、例 64KiB）。#1395 budget 確定時に `MAX_INPUT_REFS >= budget 最大件数` を検証
- R-088（PF-5-4）: キー名は #1391 の `artifact_ref` / `failure_fingerprints` / `verdicts`

## R-034 の前提の照合（2026-10-23 再照合）

出典: `review-external.md`「R-034 前提の照合」節（2026-10-22）。

| 前提 | 照合結果 |
|---|---|
| `MAX_*` の値が未合意 | 解消（PF-5-3 の仮値。`MAX_INPUT_REFS` の budget 照合は #1395 確定時） |
| 定数の module 位置が未確定 | 解消（`limits.py`、#1393 所有）。ただし `limits.py` は main に未作成（#1393 の exec で作る） |
| バイト上限の適用範囲が TASK-1393 / TASK-1392 / 旧 EV-22 で不一致 | TASK-1393 は Revision 2.7 で解消。TASK-1392 は 2026-10-23 の改訂（TASK-1392 R-105〜R-108）で event 全体基準に追従（C-3 再承認待ち） |
| decision の 3 キー名 | PF-5-4 で本 plan の名前を採用。再 C-3 条件には該当しない |

D-6 の exec BLOCKED 条件のうち「PF-5 合意」と「module 位置」は満たされた。exec 可否は他の前提（C-3、#1329 preflight、#1392 等）と併せて Human が判断する。

## 残タスク

- [ ] Human C-3（`approvals/c3.json` の発行）
- [ ] exec 前提: #1329 preflight 記録 / reviewed_at_sha 記録 / `limits.py` が main にあること

## 計画からの変更点

- なし（本 status.md 新設時点。plan / todo / test-cases は変更していない）
