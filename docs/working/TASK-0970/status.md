# STATUS — TASK-0970（#970 経路1 mass-delete guard の集計/削除 非対称の解消）

> Mode: `standard` / lite 4 軸 = true / `boundary = clean`
> 実行方式: ai-loop（C-3' 裁定）
> 基点: `origin/main` = `4448420` / plan 基点 head = `f95ac4a`（`docs/970-plan`）

## フェーズ履歴

| 日時 | フェーズ | 内容 |
|------|---------|------|
| 2026-08-05 01:38 | **C-3'** | `arbiter.py` exit 0 / priority 6（approve-approve 合意）→ **AUTO_APPROVED**。record: `docs/working/ai-loop-runs/20260805T013823Z-4448420-run028.json` / LoopSpec + W チェック理由 + オーガナイザー判断 2 件: 同ディレクトリ `-run028-loopspec.md` |
| 2026-08-05 10:44 | A-1 | baseline 再実測（clean env）。`sh tests/run-tests.sh` = **538 passed / 0 failed**、`sh tests/extras/ta-26-plugin-sync.sh` = **30 passed / 0 failed** |
| 2026-08-05 10:47 | A-5 | `scripts/sync-plugin-plangate.sh` の dst 側 stale 集計ループから `[ -L "$_rf" ] && continue`（L206）を削除 + 直上コメント L195-196 を実装へ追従（R-003）。`sh -n` rc=0 |
| 2026-08-05 10:49 | A-6 | `tests/extras/ta-26-plugin-sync.sh` に **TC-35** 追加 → ta-26 **31 passed / 0 failed / exit 0** |
| 2026-08-05 10:52 | A-7 | **変異注入 M-1** — 複製ツリーへ L206 を復元すると TC-35 が **FAIL**（rc=0 / 残存 4 = 9 件中 5 件削除）。復元後の同一複製で 31 passed に戻り、変異が唯一の原因であることを分離 |
| 2026-08-05 10:55 | A-8 | Verification Automation: ta-26 exit 0（31 passed）+ `sh tests/run-tests.sh` **539 passed / 0 failed / exit 0**（= baseline+1） |
| 2026-08-05 10:58 | A-9 | AC-1〜4 突合（下表）・status / decision-log / todo 更新 |
| 2026-08-05 11:12 | **強化セルフレビュー反映** | critical/major 0・minor 2 + info 1 を反映。**TC-36 追加**（逆方向: 非発火帯で symlink が実削除されることを固定）+ 削除ループ直上の相互注記 + src 側コメントへメンバシップ判定のズレを付記 → ta-26 **32 passed**・`run-tests.sh` **540 passed / 0 failed**（= baseline+2） |
| 2026-08-05 11:16 | **変異注入 2 種** | **M-1'（新規・削除ループにだけ `-L` 注入）→ TC-36 のみ FAIL / TC-35 は PASS**（TC-35 単独では逆方向を検出できないことを実証）。**M-1（集計ループへ `-L` 復元）→ TC-35 のみ FAIL / TC-36 は PASS**。復元後 32 passed / exit 0 |

## C-3' Gate: AUTO_APPROVED（ai-loop run-028）

- `decision = AUTO_APPROVED` / `policy_ref = auto-approve-lite-clean@v4` / `issued_by = arbiter-v0.1`
- `boundary_check = clean`（HO 21 パターン突合）/ `class_check = no-merge` / `scope_check = in_scope` / `lite_check = true`
- `w_check.model_a = approve` / `w_check.model_b = approve`（severity none・2 体とも sandbox 実走で独立再現）
- 正本: `docs/working/ai-loop-runs/20260805T013823Z-4448420-run028.json`（逐語保存・1 文字も改変しない）

## 受入基準の突合（V-1）

| AC | 判定 | 根拠 |
|----|------|------|
| AC-1 | **PASS** | 集計ループと削除ループの条件式が `[ -f "$_rf" ] \|\| continue` + `[ ! -f "$_src_refs/$_rb" ]` で厳密一致（差分レビュー）。**双方向を機械固定**: TC-35（集計 ⊋ 削除 を検出）+ **TC-36（削除 ⊊ 集計 を検出）** |
| AC-2 | **PASS** | 変異注入 M-1 で TC-35 が FAIL、**M-1' で TC-36 が FAIL**（いずれも空振り fixture でないことを実測）。`evidence/test-runs/b3-mutation-m1-ta26.log` / `b3-mutation-m1prime-ta26.log` |
| AC-3 | **PASS** | ta-26 = 32 passed / 0 failed（既存 30 + TC-35 + TC-36）。TC-29 / TC-32 / TC-34 いずれも判定不変 |
| AC-4 | **PASS** | `sh tests/run-tests.sh` = 540 passed / 0 failed = **baseline(538) + 2** |

## Replan Triggers の発火状況

| # | 判定 | 実測 |
|---|------|------|
| RT-1（差分 > 2 ファイル） | 非発火 | 実装差分は 2 ファイル（sync 1 + ta-26 1） |
| RT-2（M-1 が期待 FAIL しない） | 非発火 | M-1 で TC-35 が FAIL を実測（M-1' で TC-36 も FAIL） |
| RT-3（同一原因の failed 3 連続） | 非発火 | failed 0 |
| RT-4（総テスト数 ≠ baseline+1） | **要判断（許容）** | 538 → **540**（+2）。強化セルフレビューで TC 1 本を追加したため。TC の重複・未登録ではなく**意図した追加**であり、RT-4 の想定した異常（TC の重複・未登録）には該当しない |
| RT-5（HO 該当ファイルへの変更） | 非発火 | `boundary = clean` |

## 計画からの変更点

- **plan A-5 checkpoint の「実リポジトリ `--dry-run` で guard 非発火」を実施していない**。
  派遣時の規律で「`sh scripts/sync-plugin-plangate.sh` を repo 全体に対して実行しない
  （派生を書き換える）・検証は ta-26 の sandbox 経由のみ」が明示されたため指示を優先した。
  代替担保は既存 TC-32（dry-run と実行の guard 判定一致）+ 全系 539 passed。
  → `decision-log.jsonl` に逸脱として記録済み。
- **強化セルフレビュー（PR 作成前）の反映**: critical/major = 0 だが minor 2 + info 1 を取り込んだ。
  1. **TC-36 追加**（minor・最重要）— TC-35 は guard 発火帯のため削除ループが実行されず、
     「削除ループにだけ `[ -L ]` を足す」変異（**M-1'**）が生存していた。非発火帯
     （`stale == base`）で symlink が実削除されることを `DELETE:` ログで固定し、
     **集計 = 削除の逆方向**を塞いだ。plan の test-cases が「検出できない変異 M-X」として
     既知の限界に挙げ V2 候補としていた項目を、本 PBI 内で前倒し解消した形。
  2. **削除ループ直上の相互注記**（minor）— `sync_dir`（`:112-114` / `:130-131`）と
     経路2（`:378-380`）が持つ「集計と削除を必ず同時に更新せよ」の対注記が経路1 の
     削除側だけ欠けていた。`sync_dir:130-131` の文言を踏襲して 3 経路で表現を揃えた。
  3. **src 側コメントへの付記**（info）— stale 判定の `[ ! -f "$_src_refs/$_rb" ]` は
     symlink を辿るため base 集合と一致しない旨を明記（fail-closed 方向・Non-goal のため是正はしない）。
  → **総テスト数が baseline+1 → baseline+2 に変化**（RT-4 の数値前提が動いたが、
  TC の重複・未登録ではなく意図した 1 本追加のため再計画は不要と判断）。
- **ブランチ**: `docs/970-plan` が別セッションの worktree で checkout 済みのため、本 worktree では
  同一 commit `f95ac4a` を base とするローカルブランチ `wt/970-exec` で作業した
  （push 先は `origin/docs/970-plan` のまま）。

## 残タスク

- [x] A-1 baseline 再実測
- [x] A-5 集計ループの `-L` 除外削除 + コメント追従
- [x] A-6 TC-35 追加
- [x] A-7 変異注入 M-1
- [x] A-8 Verification Automation
- [x] A-9 AC 突合・記録
- [ ] A-10 `handoff.md` 発行 → PR 作成（**オーガナイザー担当**。rubric grader + 強化セルフレビュー後）
- [ ] H-1 C-4 ゲート（PR レビュー → merge。**Human-owned 固定 / NO MERGE BY AI**）

## 参照ファイル

- 計画: `docs/working/TASK-0970/{plan.md,todo.md,test-cases.md}`（**exec 中 1 バイトも変更していない**）
- C-3' record: `docs/working/ai-loop-runs/20260805T013823Z-4448420-run028{.json,-loopspec.md}`
- evidence: `docs/working/TASK-0970/evidence/test-runs/`（a1 baseline ×2 / a6 / a7 変異 ×2 / a8）
