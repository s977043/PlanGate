# TASK-1623 EXECUTION TODO

## Mode

high-risk（plan.md「Mode判定」）。全実装タスクに rollback を記載。

## 🤖 Agent タスク

### 1. 準備

> 対象は前半（#1623-a）のみ（plan.md D-1）。後半（I-11 接続）は別スライス・別 C-3。

- [ ] T-01 Q-2 の確定記録を status.md に転記し、未確定なら停止（Owner: agent, depends_on: H-02）🚩 rollback: 不要（読取のみ）
- [ ] T-00 MC-2a の C-3 時点分（R-025）: plan.md MC-2a の行範囲（計画段階で実測済み）の `git show` 出力と、fixture の前提構造の文章仕様（キー集合・`json.dumps` 引数）の突き合わせを `evidence/mc2a-c3.txt` に保存し Human に提示。同じファイルに `origin/feat/1391-phase1b-exec` の tip SHA と RT-2 の diff 結果（`git diff 6756a597 <tip> -- scripts/ai-loop-v2/run_event.py`）を同時記録する（R-030）。Human の確認を status.md に記録。**C-3 より前に行う**（Owner: agent 提示 / human 確認, depends_on: なし）🚩 rollback: ファイル revert
- [ ] T-02 RT-2 再確認（R-030）: `origin/feat/1391-phase1b-exec` の tip が **T-00 で `mc2a-c3.txt` に記録した tip から変わっていないか**を確かめ、変わっていれば `git diff <記録 tip> <現 tip> -- scripts/ai-loop-v2/run_event.py` で MC-2a の行範囲の定義が変わっていないかを測る（変わっていれば RT-2 / RT-9）（Owner: agent, depends_on: T-01）rollback: 不要

### 2. 実装

- [ ] T-03 RED: outcome 別の最悪ケース fixture と境界テスト、`test_no_byte_constants` の置換テストを追加し FAIL を確認（Owner: agent, depends_on: T-02）🚩 rollback: 追加したテスト・fixture を revert
- [ ] T-04 GREEN: `limits.py` に 3 定数と導出根拠コメント（実測値と切り上げ規則）を追加（Owner: agent, depends_on: T-03）🚩 rollback: `limits.py` を main の blob に戻す
- [ ] ~~T-05 ズレ検出テスト~~ — **D-3 で #1391 後半へ移管**（plan.md H-1391-4〜6）。前半では実施しない（Rev 4 の内容: 定義行 sha256 照合・振る舞い判定の番兵・分岐明示行）
- [ ] T-05b ta-118 に `skipped=` / `expected failures=` が 1 件でもある、または `Ran 0 tests` なら FAIL とする判定を追加（AC-4 / R-003 / R-027）。判定は行頭固定の正規表現で unittest の要約行だけを対象にする（R-027 補足）。Rev 4 の `verbosity=2`・必須テスト名固定リスト・分岐明示行は **D-3 で移管**（H-1391-5）（Owner: agent, depends_on: T-03）rollback: `tests/extras/ta-118-ai-loop-v2-limits.sh` を main の blob に戻す
- [ ] T-05c MC-2a の C-4 時点分（R-013 / R-023 / R-025）: plan.md MC-2a の行範囲の `git show` 出力と **fixture 実物**の前提構造の diff を `evidence/mc2a-c4.txt` に保存し Human に提示。fixture の blob SHA と前半 PR の head SHA を記録する（R-029）。前半 C-4 前の**最後に**作るタスクとし、以後 fixture を変えたら作り直す。Human の確認を status.md に記録（C-3 時点分は T-00）（Owner: agent 提示 / human 確認, depends_on: T-02, T-03, T-09, T-11）🚩 rollback: 不要
- [ ] T-05d MC-4 本文案（R-022 / R-026）: #1391 Issue への H-1391-1〜6 チェックリストコメントの本文案（plan.md の書き直し後の文面）と投稿先を `evidence/mc4-draft.md` に作成し、前半 C-4 前に Human に提示（Owner: agent 作成 / human 確認, depends_on: T-04）🚩 rollback: ファイル revert
- [ ] T-07 #1392 reserve 契約 fixture（`test_limits` 系に配置、`TERMINAL_RESERVE` は fixture 内の契約値、同じ定数を import）（R-007）（Owner: agent, depends_on: T-04）rollback: fixture revert

### 3. 検証

- [ ] T-08 mutation 注入（定数 −1 / escape 無視 / 区分二重計上 / outcome 1 種欠落 / テストを skip させる）が全て検出される。Rev 4 の構造キー増減・番兵系・未収集系の mutation は **D-3 で移管**（Owner: agent, depends_on: T-05b, T-07）rollback: 不要
- [ ] T-09 敵対レビュー R1 → 是正 → R2（§7-quater、回避クラス台帳）。R2 で新しい回避クラス 0 件なら終了、1 件以上で R3（R-009）（Owner: agent, depends_on: T-08）🚩 rollback: 不要
- [ ] T-11 MC-2b（D-3 で縮小、R-027 で拡張）: 前半 PR の CI ログで ta-118 の `skipped=` 0 件・`expected failures=` 0 件・`Ran 0 tests` でない・rc=0 を確認し evidence に保存。欠落ありなら RT-7 で停止。MC-2a'（ハッシュ照合）は D-3 で移管（Owner: agent, depends_on: T-05b）🚩 rollback: 不要

### 4. 完了

- [ ] T-10 status.md / handoff.md 更新（AC-2 未達・後半待ち、後半マージまで byte 上限は強制されていない、#1623 Open 維持、PR 本文は `Refs #1623` のみ = MC-1 / R-006。#1391 への引き継ぎ事項 H-1391-1〜6 を転記。残存脅威モデル（R-013 / D-3 で更新）を転記）（Owner: agent, depends_on: T-09, T-11, T-05c）rollback: 不要
- [ ] T-12 MC-4（R-015 / R-022）: 前半マージ後、H-03c で確認済みの本文案（`evidence/mc4-draft.md`）を #1391 の Issue へコメントし、URL を handoff の evidence に記録。投稿前にコメント先と本文を名指しして承認を取る。計画段階では投稿しない。URL の記録は #1623-b の C-3 前提（Owner: agent, depends_on: H-04, H-03c）🚩 rollback: コメントを削除（承認を取ってから）

## 後半（参考・本 todo の exec 対象外）

- T-06 I-11 byte 検査の接続（`make_decision_input`、#1393 core と同時かその直後。別 C-3）

## 👤 Human タスク

- [x] H-01 Q-1 順序の決定 → 案 B（2026-11-26、plan.md D-1）
- [x] H-01b MC-2 の移管 → D-2（2026-11-26）
- [x] H-01c 前半からズレ検出を外す → D-3（2026-11-26）
- [x] H-01d R-024 は TASK-1391 文書に C-4 前提を書いて閉じる → D-4（2026-11-26）。記載はオーガナイザー、記載先と commit を exec 前に status.md へ記録（記載はオーガナイザーが commit `3a7373f0` の `docs/working/TASK-1391/c4-preconditions.md` で実施済み。H-1391-1〜6 の文面の正本は同ファイル, R-031）
- [ ] H-01e exec 開始条件（R-032）: TASK-1391 の todo の C-4 行から `c4-preconditions.md` が参照されていることを確認する。TASK-1391 の status / todo には別セッションの未 commit 変更があり未追記のため、その変更の扱いと追記を Human が決める（本 TASK の worker は TASK-1391 を変更しない）
- [ ] H-02 Q-2 の owner 確認（#1392 / #1393 / #1395）。期限: 初回確認から 5 営業日（RT-3 / R-010）
- [ ] H-03 C-3（c3.json 発行）。MC-2a の C-3 時点分（`evidence/mc2a-c3.txt`、行範囲と前提構造の文章仕様の突き合わせ）を確認（R-013 / R-023 / R-025）
- [ ] H-03b 前半 C-4 時点の MC-2a（`evidence/mc2a-c4.txt`、fixture 実物との突き合わせ）を確認（R-013 / R-023 / R-025）。記録された PR head SHA が PR の現在の head と一致することを確かめ、不一致なら T-05c の作り直しを求める（R-029）
- [ ] H-03c 前半 C-4 前に MC-4 本文案と投稿先（`evidence/mc4-draft.md`）を確認（R-022）
- [ ] H-05 #1623-b の C-3 で MC-4 投稿 URL と H-1391-1〜6 すべての evidence を条件に含める（R-015 / R-022 / R-024、本 todo の exec 対象外）
- [ ] H-04 C-4（PR レビュー・merge）

## ⚠️ 依存関係

- H-03（C-3）← T-00（MC-2a の C-3 時点分。exec の成果物に依存しない, R-025）/ T-01 ← H-02 / exec 開始 ← H-03・H-01e（R-032）/ T-05c ← T-09・T-11（R-029）/ C-4 ← T-11（MC-2b）・H-03b（MC-2a の C-4 時点分、T-05c）・H-03c（MC-4 本文案）/ T-12（MC-4 投稿）← H-04 / #1623-b の C-3 ← T-12・H-1391-1〜6 の evidence（R-024）
- T-11 は前半 PR の CI run で完結する（D-2）。実 validator 照合・ズレ検出は #1391 スライス B の C-4 前提（plan.md H-1391-1〜6、D-3 / D-4）で本 todo の対象外
- 後半 T-06 は #1393 core（`DecisionInputError` 導入）と同時かその後
