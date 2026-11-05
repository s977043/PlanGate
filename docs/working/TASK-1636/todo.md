# TASK-1636 EXECUTION TODO

## Mode

**モード**: high-risk（`plan.md` の Mode判定と一致）

## 🤖 Agent タスク

### 1. 準備

- [ ] T-01: `decision-log.jsonl` を初期化し、`plan.md` の棄却案を `alternatives_rejected` として記録する。`status.md` を作る
  - Owner: agent
  - depends_on: H-01, H-02
  - files: `docs/working/TASK-1636/decision-log.jsonl`, `docs/working/TASK-1636/status.md`
  - rollback: `git checkout -- docs/working/TASK-1636/`
  - 🚩 チェックポイント: `plan_hash` 一致と `PLANGATE_HOOK_TASK=TASK-1636` を確認。不一致なら停止
- [ ] T-02: `sh tests/run-tests.sh` のベースラインを記録する
  - Owner: agent
  - depends_on: T-01
  - files: `docs/working/TASK-1636/evidence/test-runs/`
  - rollback: 不要（検証のみ）
  - 🚩 チェックポイント: ベースラインが失敗なら Replan

### 2. テスト（RED）

- [ ] T-03: `setUp` の realpath 化、docstring 修正、`run_installer(rc=, expect=)` への置き換え
  - Owner: agent
  - depends_on: T-02
  - files: `tests/test_installer_ownership.py`
  - rollback: `git checkout -- tests/test_installer_ownership.py`
  - 🚩 チェックポイント: なし
- [ ] T-04: TC-01〜09、TC-E01、TC-E03 を追加する
  - Owner: agent
  - depends_on: T-03
  - files: `tests/test_installer_ownership.py`
  - rollback: `git checkout -- tests/test_installer_ownership.py`
  - 🚩 チェックポイント: なし
- [ ] T-05: TC-10〜16、TC-E02、TC-E04 を追加し、legacy テストの if/else を除く
  - Owner: agent
  - depends_on: T-04
  - files: `tests/test_installer_ownership.py`
  - rollback: `git checkout -- tests/test_installer_ownership.py`
  - 🚩 チェックポイント: なし
- [ ] T-06: TC-20 を実行し、`e683fd4d` の installer に対する RED を保存する
  - Owner: agent
  - depends_on: T-05
  - files: `docs/working/TASK-1636/evidence/test-runs/`
  - rollback: 不要（検証のみ）
  - 🚩 チェックポイント: RED 列と不一致なら停止してテストを直す

### 3. 実装

- [ ] T-07: target の事前検査と `realpath` 正規化
  - Owner: agent
  - depends_on: T-06
  - files: `install.sh`
  - rollback: 当該 commit を `git revert`
  - 🚩 チェックポイント: TC-01〜09、TC-E01、TC-E03 が GREEN
- [ ] T-08: v1 ガードと撤去の文言
  - Owner: agent
  - depends_on: T-07
  - files: `install.sh`
  - rollback: 当該 commit を `git revert`
  - 🚩 チェックポイント: TC-10〜13、TC-E02、TC-E04 が GREEN
- [ ] T-09: 移行手順の節を追加する
  - Owner: agent
  - depends_on: T-08
  - files: `docs/plangate-plugin-migration.md`
  - rollback: 当該 commit を `git revert`
  - 🚩 チェックポイント: TC-14 が GREEN
- [ ] T-10: `_print_caveats` の呼び出し復旧、更新コマンドの訂正、`_skip` の削除
  - Owner: agent
  - depends_on: T-08
  - files: `install.sh`
  - rollback: 当該 commit を `git revert`
  - 🚩 チェックポイント: TC-15 が GREEN
- [ ] T-11: 残存脅威を `install.sh` と review 文書に書き、旧記述を置き換える
  - Owner: agent
  - depends_on: T-07, T-08
  - files: `install.sh`, `docs/working/TASK-1636/installer-ownership-review.md`
  - rollback: 当該 commit を `git revert`
  - 🚩 チェックポイント: TC-19 が PASS

### 4. 検証

- [ ] T-12: TC-16〜19 と全テストを既定 TMPDIR と実パス TMPDIR の両方で実行する
  - Owner: agent
  - depends_on: T-09, T-10, T-11
  - files: 読取: `tests/test_installer_ownership.py`
  - rollback: 不要（検証のみ）
  - 🚩 チェックポイント: なし
- [ ] T-13: TC-21（MU-1〜12）をスクラッチパッドのコピーで実行し、結果を保存する
  - Owner: agent
  - depends_on: T-12
  - files: `docs/working/TASK-1636/evidence/verification/`
  - rollback: 不要（検証のみ）
  - 🚩 チェックポイント: 検出できない変異があれば Replan Trigger を判定
- [ ] T-14: 敵対レビュー R1 を実施し、台帳に記録して是正する
  - Owner: agent
  - depends_on: T-13
  - files: `docs/working/TASK-1636/installer-ownership-review.md`
  - rollback: 不要（記録のみ。是正は個別 commit）
  - 🚩 チェックポイント: なし
- [ ] T-15: 敵対レビュー R2（R1 の是正を疑う）を実施し、収束を判定する
  - Owner: agent
  - depends_on: T-14
  - files: `docs/working/TASK-1636/installer-ownership-review.md`
  - rollback: 不要（記録のみ。是正は個別 commit）
  - 🚩 チェックポイント: 2 ラウンド連続で新クラスなら停止
- [ ] T-16: macOS の実機 1 周を fixture で実行する（実 `~/.claude` には触れない）
  - Owner: agent
  - depends_on: T-13
  - files: `docs/working/TASK-1636/evidence/verification/`
  - rollback: 不要（検証のみ）
  - 🚩 チェックポイント: なし
- [ ] T-17: `git diff --stat e683fd4d...HEAD` が plan の Files 内か確認する
  - Owner: agent
  - depends_on: T-15, T-16
  - files: 読取のみ
  - rollback: 不要（検証のみ）
  - 🚩 チェックポイント: 範囲外があれば停止

### 5. 完了

- [ ] T-18: `status.md` / `current-state.md` / `INDEX.md` を更新する
  - Owner: agent
  - depends_on: T-17
  - files: `docs/working/TASK-1636/status.md`, `docs/working/TASK-1636/current-state.md`, `docs/working/TASK-1636/INDEX.md`
  - rollback: 不要（記録のみ）
  - 🚩 チェックポイント: なし

## 👤 Human タスク

- [ ] H-01: **C-3 ゲート**（`plan.md` Q-1〜Q-4 の判断を含む）。`bin/plangate approve TASK-1636` を TTY で実行する
  - Owner: human
  - depends_on: なし
  - files: `docs/working/TASK-1636/approvals/c3.json`
  - rollback: 不要（判断のみ）
  - 🚩 チェックポイント: APPROVED が出るまで exec を開始しない
- [ ] H-02: `PLANGATE_HOOK_TASK=TASK-1636` を付けて Claude Code を再起動する
  - Owner: human
  - depends_on: H-01
  - files: なし
  - rollback: 不要
  - 🚩 チェックポイント: `.md` 以外の編集の前提
- [ ] H-03: **C-4 ゲート**（PR #1639）。draft 解除と merge も Human
  - Owner: human
  - depends_on: T-18
  - files: GitHub PR
  - rollback: 不要（判断のみ）
  - 🚩 チェックポイント: merge は Human-owned 固定

## ⚠️ 依存関係（Agent ↔ Human）

| タスク | depends_on | 種別 | 備考 |
| --- | --- | --- | --- |
| T-01 | H-01, H-02 | Human → Agent | C-3 APPROVED と再起動まで exec に入れない |
| H-03 | T-18 | Agent → Human | 完了記録の更新後に PR レビュー |
