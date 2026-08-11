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
- stable action IDを持つintent / receiptとtask-wide `action_reserved`→`action_consumed` lifecycleを記録する
- Human / External待機を明示し、同一要求の再発行を抑止する
- task / plan hash / action IDと、request時SHAに対するresume時HEADの許可関係を再開時に再照合する
- state / record破損、stale writer、receipt再利用をfail-closedにする
- #1023相当のprocess/session消失を独立module境界で回帰テスト化する
- ambient `GIT_*`を権威入力にせず、同一Git common-dirのlinked worktree間でlock / ledgerを共有する
- Python標準ライブラリのみの独立モジュール・テスト・契約文書を追加し、canonical hashはself-contained、runtime repo importはcontrolled canonical sourceの`gh_exec`だけにする
- production moduleからdirect `subprocess` / `multiprocessing`を使わず、既存`gh_exec`境界と正規plugin syncを拡張する

### Out of scope

- C-3 / C-4 / merge権限の変更
- nonce、c3.json、Human receiptのAI代理発行
- `.plangate.yml` の承認モード変更
- `bin/plangate`、`schemas/**`、Hook、policy、HO、Core Contractの変更
- 常駐daemon、外部DB、外部SaaSの導入
- #869のcandidate生成・canary・promotion全体
- plugin bundle内の配布copyをtarget repositoryへ直接接続するoperational adapter
- 既存`current-state.md`の一括移行
- 別clone / 別machineへのruntime state同期
- native Windows locking（v1 operational CLIはLinux/WSLの`/usr/bin/python3 -I -S -B`、`/usr/bin/git`、POSIX `fcntl.flock`を前提）

## Acceptance Criteria

- [ ] AC-01: stateを書いたプロセス終了後、別プロセスが同じrun ID・revision・pending actionを復元できる
- [ ] AC-02: Human / External待機への遷移でstable action IDを持つrequestとtask-wide `action_reserved`が各1件だけ記録される
- [ ] AC-03: 同一要求を複数回実行してもHuman / External request / action reservationが増殖せず、消費後の再提示でもWAITINGへ戻らない
- [ ] AC-04: Human C-3のsemantic Plan authority、全receiptのaction ID、External receipt IDはtask-wide consumption ledgerで一度だけ消費され、同一Run再消費・別Run流用・同一actionのresult差替えをharness境界内で拒否する
- [ ] AC-05: task ID・plan hash・action IDの不一致、および未承認のsource relationをfail-closedで拒否する。`request_source_sha`と内部観測した`actual_resume_head`を別fieldで保存し、Humanはsame HEADまたはcanonical C-3だけを含むdescendant/dirty差分、Externalはexact HEAD + clean worktreeだけを許可する。resumeでは初回検証後、WAL prepare直前にHEAD-before / status・diff・ancestor / HEAD-afterを再観測し、安定かつ初回snapshotと同一の最終snapshotをsource relationの線形化点として記録する
- [ ] AC-06: state / record / ledger破損、duplicate key・非標準数・未知key/event enum、revision後退、runtime path、actual loader/source identity、`gh_exec.py` / `durable_run.py` sourceまたはroot-owned Python/Git executable fingerprint driftを成功扱いしない
- [ ] AC-07: Human承認artifactは既存正規経路でのみ発行し、本実装に自己承認・merge経路が存在しない
- [ ] AC-08: External待機も同じintent / receipt契約で再開できる
- [ ] AC-09: 独立Durable Run module内ではprocess/session消失後の同一Human要求が同じaction IDを返し、request/nonce相当recordを増殖させない回帰テストがPASSする。`bin/plangate` nonce/TTY producerへの接続は本PBI対象外で、既存CLIのend-to-end実害解消を完了条件として主張しない
- [ ] AC-10: TC-01〜TC-46のmachine-readable coverage、gh_exec isolated boundary 4 exact method、最低46 unit tests、既存ai-loop / exec boundary回帰、標準CI route、正規plugin sync、`git diff --check`がPASSする

## Notes from Refinement

- Parent Epicは#870。#1025を#874 / #869より前のP0 close blockerとする。
- #873 / #917のcanonical hash、intent / receipt、決定論、fail-closedパターンを再利用する。
- v1は非HOの独立モジュールとし、`bin/plangate` / JSON Schemaへの昇格は別Human判断とする。
- `current-state.md`は人間向けビューに留め、機械正本はJSON state + append-only recordとする。
- Human C-3 resumeでは既存`approvals/c3.json`を読み取り専用で検証し、書き込まない。
- Human決定A（2026-08-09）: legacy C-3をPlan承認の正本として維持し、task-wide consumption ledgerを採用し、CLI/schema/HOを変更しない。Round 2 checker findingへの設計精緻化として、ledger一意キーはraw artifact digestではなく`task_id` / `phase=C-3` / `c3_status=APPROVED` / `source=cli` / `plan_hash`のsemantic authority IDとする。raw bytes digestは検証snapshotの証拠として`run_id` / `action_id` / `request_source_sha` / `actual_resume_head`へ束縛する。この精緻化は確定PlanのHuman C-3承認待ちである。
- v1の保証限界: `source=cli`は発行provenanceの署名ではなく、legacy C-3自身はrun/action/sourceを署名しない。`approved_by` identity、External receipt producerの真正性、保存領域全体の同時rollbackは暗号学的に検証しない。v1は信頼済みlocal Git repository内のbinding・semantic replay抑止・並行実行・partial write・proper subset rollbackをfail-closedにするharness integrityであり、署名付きattestationではない。
- durability domain: runtime stateはmodule fileから検証したworktree anchorを起点に、全ambient `GIT_*`を除去した`git -C <anchor> rev-parse --git-common-dir`配下へ置く。同一local Git repositoryのprocess / Agent / linked worktree間でlock / manifest / ledgerを共有する。別clone・別machineへの同期はv1非対象。
- runtime execution: operational mutation/statusはroot-owned `/usr/bin/python3 -I -S -B`でrepository canonical `scripts/ai-loop/durable_run.py` sourceをmain実行するCLIだけ。canonical hashはself-containedとし、空のprivate pycache prefixを設定してcanonical sourceとして検証した`gh_exec`だけをstatic importする。ignored pyc / shadow package / PYTHONPATH / sitecustomize / preloaded non-canonical moduleをruntime候補にしない。plugin生成copyはbyte-identical配布ミラーで、bundle内からのdirect mutation/statusはartifact I/O前に`unsupported_runtime_layout`。task lockはtask root外のGit common-dirへ置き、全ancestor inodeをheld common-dirから再照合する。
- Human / Externalのrequestは同じstate machineで生成・復元・冪等再提示し、request transactionでtask-wide ledgerへ`action_reserved` eventを1件だけ追加する。receipt消費時はそのreservationを参照する`action_consumed` eventをappend-onlyで最大1件追加する。消費後に同じrequestが再送された場合は、ledger上の完了済みactionをmutationなしで返し、再びWAITINGへ遷移させない。同じactionへ異なるresult receiptを提示した場合だけ`receipt_conflict`。
- 本Durable Runの`BLOCKED`は`.claude/rules/working-context.md`の外部依存taskに対応する回復可能なorchestration statusで、arbiterの同名terminal decisionとは別語彙とする。RUNNING/WAITINGからblockする際はprior status / pending / action / reasonを`blocked_context`へ保存し、同一reasonの再実行だけno-op、明示unblockだけが保存済み状態へ復帰する。store integrity errorは`BLOCKED`へ書き換えずcontrolled errorにする。
- TASK IDは既存schema / C-3 contractと同じ`TASK-[0-9]{4}`に固定する。schema/HOは変更せず、root正本の新規contract/runtime/testと`gh_exec`変更は正規syncでplugin派生成果物へ反映する。

判断詳細は `decision-log.jsonl` を正本とする。

## Estimation Evidence

### Risks

- approval境界隣接: receipt検証が緩いと自己承認経路になり得る。既存c3.jsonをread-onlyで検証し、本モジュールは承認artifactを生成しない。
- 同時実行: lost updateがstateを巻き戻し得る。task単位のinter-process lock内で再読込→revision compare-and-swap→commitを行う。
- 永続化中断: bootstrapはcommon-dir外部lock + flat file layout + 空task rootの再利用可能prestateへ限定し、state / record / ledger / manifest間のpartial commitをredo型WALで回復する。prepare transactionを先にfsyncし、各targetをatomic replace、manifestを最後に確定してdirectory fsync後にtransactionを除去する。
- record改竄: receipt抑止を偽装し得る。task-wide manifestが全run state / recordとledgerのdigest・count・tail・transaction IDを同一generationへ束縛し、proper subset rollbackを検出する。
- approval再利用: legacy C-3のsemantic authority ID（task + plan authority）のtask-wide一意性をlock内で検証し、whitespace / key order / `_`注釈 / approved_at変更による再消費回避を拒否する。raw digestだけを一意キーにしない。
- source自己参照: runtime stateをGit common-dirへ置き、state commitによるHEAD変化を避ける。Human C-3 resumeだけはrequest時HEADと同一、またはdiffがcanonical C-3 pathだけの子孫HEADを許可し、それ以外のcommit / dirty pathを拒否する。
- Git context汚染: production moduleはdirect subprocessを使わず、`gh_exec.run_git(..., isolated_env=True, binary_output=True)`がroot-owned fixed Git、clean allowlist env、caller非指定のconfig override、必要最小のexact read-only argvだけを使う。既存callerの既定挙動は維持する。caller PATH/HOME/XDG/global configとambient `GIT_*`を継承せず、fsmonitor / untracked cache / worktree / bare / status / diff外部実行をcommand lineで固定する。path一覧はbytesのNUL区切りで解釈する。残るGit object/index/worktree configを含むlocal admin metadataは明示TCBとする。
- 実行契約drift: 実際に実行/ロードする`gh_exec.py` / `durable_run.py`のsource bytesとloader identity、root-owned `/usr/bin/python3` / `/usr/bin/git`のinvoked path / realpath / bytes digestをharness fingerprintへ含め、いずれかのdriftでもactive runを拒否する。

### Unknowns / Trust limits

- 外部immutable anchorまたは署名付きreceiptなしでは、保存領域全体の同時rollback、Human identity、External producer真正性を暗号学的に証明できない。これはAでHuman合意済みのv1 trust limitであり、contractとPRへ明記する。
- root/OS compromiseとGit object/index/local admin metadata自体の改竄はv1対象外。OS-owned `/usr/bin/python3` / `/usr/bin/git`をtrusted computing baseとする。
- `bin/plangate` nonce/TTY producer統合、schema昇格、action-bound署名receipt、RunEvidence正式接続は本PBIの完了後に別判断する。本PBIはmodule-level foundationであり、#1023のend-to-end解消を主張しない。

### Assumptions

- `main@5e630f9d` の `delivery.py` intent / receipt契約を既存パターンとして利用できる。
- Python 3標準ライブラリが利用できる。
- Human C-3は既存`bin/plangate approve`形式の`source=cli` artifactをPlan authority入力として扱う。ただし`source=cli`自体は発行provenance / Human identityの署名証明ではない。
