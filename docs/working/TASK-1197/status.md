# TASK-1197 作業ステータス

> 最終更新: 2026-11-12 08:14
> 現在フェーズ: verify（L-0 / V-1〜V-4）
> モード: critical
> 発行時点 SHA (issued_at_commit): 82395dbe1221c29357509cb2877c6ca8b5c08054
>
> 本ファイルの commit 数・変更ファイル数は `issued_at_commit` 時点の測定値であり、契約値ではない。

## フェーズ履歴

| 日時 (YYYY-MM-DD HH:mm) | フェーズ | 結果 / メモ |
|------------------------|---------|------------|
| 2026-11-06 00:00 | A / B: PBI INPUT・plan 生成 | scratchpad で下書き（時刻は記録なし。00:00 は不明を示す） |
| 2026-11-07 00:00 | C-3 Gate | CONDITIONAL（時刻は記録なし）。確定反映後に Human が c3.json を発行 |
| 2026-11-12 07:39 | D: exec（HO 適用） | Human が `scripts/hooks/check-plan-hash.sh` を適用（82395dbe）、pending flag 削除 |
| 2026-11-12 08:00 | verify: run-tests | 1693 passed / 1 failed（ta-10 TC-7、環境依存と帰属） |
| 2026-11-12 08:14 | V-1 | WARN（AC は 4/4 PASS。settings タスクロック FAIL・T-02 未実施のため完了扱いにしない） |

## 全体構成（PR 一覧）

| PR | ブランチ | 状態 |
|----|---------|------|
| 未作成 | feat/1197-eh3-plan-create | 未 push（origin/main 9c5b3262 の上に 82395dbe 時点で 6 commit） |

## 残タスク

- [ ] `bin/plangate doctor --check-settings` を PASS させる（feat worktree で rc=1: `.claude/settings.json` 不在）。Human-owned（`sh scripts/apply-claude-settings.sh`）
- [ ] T-02: 実 Claude Code の Write payload で `PLAN_CREATE_ALLOW` を 1 回確認し evidence に保存
- [ ] `docs/working/_reports/1197-eh3-plan-create-patch.md` の「適用状態: 未適用」を適用済みに更新（82395dbe 時点で未更新）
- [ ] V-2 / V-3 / V-4（critical モード）
- [ ] push・PR 作成・C-4

## 計画からの変更点

逸脱 D-1〜D-14（D-1 は D-6 で取り消し）。要約は `handoff.md` §4。主なもの:

- D-2: 相対パスの file_path は常に block（TC-09a を allow→block）
- D-4: 条件 4（common dir）は置かない（worktree 一覧照合で代替）
- D-6: prunable worktree は件数を記録して skip・allow（Human 裁定。untracked approvals の列挙はベストエフォート、保証の主体は exec の plan_hash 拒否）
- D-7 / D-10: payload を python で再解析し制御文字を block、pipe 渡しで E2BIG を回避
- D-9: 等価変異 5 件（M19 / M21b / M22 / M24 / M26）を EQUIV として別枠集計
- D-11: 孤立サロゲートの既存の穴（#1647、範囲外）
- D-12: plugin 配下の rollout-policy.md copy に差分（version bump ゲート #1257 の対象）
- D-13: 変異は `PG_T119_MUTATION=1` の opt-in
- D-14: 許可分岐の入口に字句判定を置き fork 増加を是正

## V 系ステップ進捗

| ステップ | 結果 |
|---------|------|
| L-0 | WARN: 新規 / 更新した 4 ファイルは markdownlint 0 件。コピーした plan.md（2 件）・review-self.md（50 件）は plan worktree の版と byte 一致を保つため未修正 |
| V-1 | WARN |
| V-2 | 未実施 |
| V-3 | 未実施 |
| V-4 | 未実施 |

## 次の作業（Claude Code プロンプト）

TASK-1197（#1197 案 B）は HO 適用済み（82395dbe）。`docs/working/TASK-1197/handoff.md` と本ファイルの残タスクを読み、(1) Human に `sh scripts/apply-claude-settings.sh` 実行を依頼して `doctor --check-settings` を再測定、(2) T-02 を実施、(3) patch 文書の適用状態を更新、(4) V-2〜V-4 を経て push・PR 作成（`Refs #1197`、closing keyword なし）へ進む。`approvals/c3.json` は plan worktree にのみあり commit しない。
