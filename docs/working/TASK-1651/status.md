# TASK-1651 status

## 現在フェーズ

plan（plan.md への移動待ち。TASK 文脈付きセッションが必要）

## フェーズ履歴

| 日時 | フェーズ | 内容 |
|------|---------|------|
| 2026-11-13 08:37 | plan | pbi-input.md 作成。plan.md の書き込みは EH-3 に block（TASK 文脈なしのセッション） |
| 2026-11-13 09:01 | plan | plan-draft.md / todo.md / test-cases.md / review-self.md 作成。C-1: WARN（minor 2: C1-PLAN-07 Linux での M-1 は CI 依存、C1-B1B2-16 D-1 の Human 確認未取得） |

## モード判定

standard（HO 対象外。privacy 検査の変更のため V-3 は 2 ラウンド下限）

## 計画からの変更点

- plan.md の代わりに plan-draft.md に本文を置いた（EH-3 block のため。前例: TASK-1544）

## 残タスク

- [ ] plan-draft.md → plan.md へ移動（TASK 文脈付きセッション）
- [ ] C-3: `bin/plangate approve TASK-1651`（Human）
- [ ] exec: todo.md T-1〜T-7

## 次回セッション用プロンプト

`PLANGATE_HOOK_TASK=TASK-1651` で起動し、`docs/working/TASK-1651/INDEX.md` を読んで plan-draft.md を plan.md へ移す（内容は変えない）。移動後に Human へ C-3（`bin/plangate approve TASK-1651`）を依頼する。

## 参照

- issue: https://github.com/s977043/plangate/issues/1651
- `scripts/doctor_check.py` / `tests/extras/ta-10-doctor-fix.sh`（origin/main `8a689907`）
