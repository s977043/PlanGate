---
task_id: TASK-1025
artifact_type: pbi-input
schema_version: 1
status: ready
related_issue: https://github.com/s977043/PlanGate/issues/1025
---

# PBI INPUT PACKAGE — TASK-1025 Durable Run State

## Context / Why

ai-loop の Human C-3 待機中に Agent セッションと TTY 入力ハンドルが失われ、Plan hash と作業状態が不変でも新しい nonce を繰り返し要求した。会話や生存プロセスを正本にすると、別 Agent / 別 Session が中断地点を安全に復元できず、承認疲労と誤配送リスクを生む。

#869 の外側 Evolution Loopへ進む前に、1 Runを中断・待機・再開できる最小のDurable Run Harnessを確立する。

## What — Scope

### In scope

- Run stateをリポジトリ内へ原子的・機械可読に永続化する
- stable action IDを持つintent / receiptを記録する
- Human / External待機を明示し、同一要求の再発行を抑止する
- task / plan hash / source SHA / action IDを再開時に再照合する
- state / record破損、stale writer、receipt再利用をfail-closedにする
- #1023相当のTTY消失ケースを回帰テスト化する
- Python標準ライブラリのみで独立モジュール・テスト・契約文書を追加する

### Out of scope

- C-3 / C-4 / merge権限の変更
- nonce、c3.json、Human receiptのAI代理発行
- `.plangate.yml` の承認モード変更
- `bin/plangate`、`schemas/**`、Hook、policy、HO、Core Contractの変更
- 常駐daemon、外部DB、外部SaaSの導入
- #869のcandidate生成・canary・promotion全体
- 既存`current-state.md`の一括移行

## Acceptance Criteria

- [ ] AC-01: stateを書いたプロセス終了後、別プロセスが同じrun ID・revision・pending actionを復元できる
- [ ] AC-02: Human待機への遷移でstable action IDを持つrequestが1件だけ記録される
- [ ] AC-03: 同一要求を複数回実行してもHuman request / action IDが増殖しない
- [ ] AC-04: receiptは一度だけ消費され、再消費・別Run流用を拒否する
- [ ] AC-05: task ID・plan hash・source SHA・action IDの不一致をfail-closedで拒否する
- [ ] AC-06: state / record破損、未知enum、revision後退を成功扱いしない
- [ ] AC-07: Human承認artifactは既存正規経路でのみ発行し、本実装に自己承認・merge経路が存在しない
- [ ] AC-08: External待機も同じintent / receipt契約で再開できる
- [ ] AC-09: TTY消失後に同じHuman要求を繰り返さない回帰テストがPASSする
- [ ] AC-10: 新規unit test、既存ai-loop回帰、`git diff --check`がPASSする

## Notes from Refinement

- Parent Epicは#870。#1025を#874 / #869より前のP0 close blockerとする。
- #873 / #917のcanonical hash、intent / receipt、決定論、fail-closedパターンを再利用する。
- v1は非HOの独立モジュールとし、`bin/plangate` / JSON Schemaへの昇格は別Human判断とする。
- `current-state.md`は人間向けビューに留め、機械正本はJSON state + append-only recordとする。
- Human C-3 resumeでは既存`approvals/c3.json`を読み取り専用で検証し、書き込まない。

判断詳細は `decision-log.jsonl` を正本とする。

## Estimation Evidence

### Risks

- approval境界隣接: receipt検証が緩いと自己承認経路になり得る。既存c3.jsonをread-onlyで検証し、本モジュールは承認artifactを生成しない。
- 同時実行: lost updateがstateを巻き戻し得る。revision compare-and-swapを全mutationで必須化する。
- 永続化中断: partial writeでstateが壊れ得る。同一directoryのtemporary file、fsync、`os.replace`を使う。
- record改竄: receipt抑止を偽装し得る。entry ID再計算とprev-entry chainを読込時に全件検証する。

### Unknowns

- なし。`bin/plangate`統合、schema昇格、RunEvidence正式接続は本PBIの完了後に別判断する。

### Assumptions

- `main@9f9af945` の `delivery.py` intent / receipt契約を既存パターンとして利用できる。
- Python 3標準ライブラリが利用できる。
- Human C-3は既存`bin/plangate approve`が生成した`source=cli`のartifactを正規receiptとして扱う。
