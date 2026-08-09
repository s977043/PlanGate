---
task_id: TASK-1025
artifact_type: review-external
schema_version: 1
status: completed
verdict: reject
review_independence: no-maker-context
---

# TASK-1025 外部レビュー結果（C-2）

> レビュー日: 2026-08-09
> 対象Plan SHA-256: `3d9027bb9ecd538c290448648b29579da0084948759b040fbd7c3c11bcdbf121`
> Lane A: contract / security / testability — **reject**（critical 0 / major 6 / minor 1）
> Lane B: focused adversarial review — **reject**（critical 1 / major 4）
> 総合: **reject**。production変更およびC-3移行を停止する。

C2-VERDICT: reject plan=sha256:3d9027bb9ecd538c290448648b29579da0084948759b040fbd7c3c11bcdbf121

## Findings

### R-001 — major — revision CASがmulti-process writerを直列化しない

- evidence: `expected_revision`比較から`os.replace`までを保護するlockがなく、2 writerが同じrevisionを読み両方成功できる。TC-15は逐次stale writerのみ。
- required action: run単位のinter-process lock内で再読込→revision比較→commitを行う。barrier付き2-process testで成功1 / `revision_conflict` 1 / record fork 0を固定する。
- disposition: 未反映。

### R-002 — major — stateとJSONL recordのcrash-consistent commit protocolがない

- evidence: stateのatomic replaceはあるが、record appendとの順序、transaction ID、fsync、途中停止後のrecoveryが未定義。receiptとstateが食い違うcrash windowがある。
- required action: WAL / prepare+commit marker等のprotocol、write/fsync/replace/directory-fsync順、各crash windowのreplay/rollback規則を固定しfault injection testを追加する。
- disposition: 未反映。

### R-003 — critical — legacy Human C-3 artifactだけではrun/action/source bindingを証明できない

- evidence: 正規`schemas/c3-approval.schema.json`と`bin/plangate approve`生成物には`run_id`、`action_id`、`source_sha`がない。`source=cli`、task、plan hashの検証だけでは同じartifactの別Run流用をartifact自身から拒否できない。identityも`_approver_identity_unverified=true`である。
- required action: 次のどちらかをHumanが選ぶ。
  1. HO scopeを維持し、legacy C-3をplan authorityとして扱い、harnessのcanonical task ledgerが生成するconsumption recordでrun/action/sourceと全run一度消費を束縛するようACの意味を精緻化する。
  2. Human-owned CLI/schemaへaction-bound receiptを追加する別scope / 別Planへ分割する。
- disposition: **Human decision待ち**。現scopeのまま達成済みとは扱わない。

### R-004 — major — resume bindingがcaller供給値に依存する

- evidence: current source SHAとreceipt pathをcaller入力にすると、保存済み値の再提示や任意fixtureを独立検証できない。task directory、plan bytes、git HEADの実測責務も未定義。
- required action: CLIはrepo root、canonical task dir、現在plan SHA-256、実git HEADを内部解決する。C-3は固定`approvals/c3.json`のregular fileのみno-follow/read-onlyで開き、path escape/symlinkを拒否する。
- disposition: 未反映。

### R-005 — major — hash chainのsuffix truncation / pair rollbackを検出できない

- evidence: self digestとprev-entry chainだけでは末尾切詰め、古い完全chainへの差替え、state+record pairの旧revision replayを検出できない。stateにrecord tail/countのcross-bindingがない。
- required action: stateへrecord tail hash / entry count / transaction IDを束縛し、load時に双方向照合する。truncation、reorder、duplicate、別run chain、片側rollbackをtest化し、両ファイル同時rollbackを防げないtrust limitを文書化する。
- disposition: 未反映。

### R-006 — major — adversarial testとGitHub Actions導線が不足する

- evidence: 真の同時CAS、各crash window、truncation、actual plan/HEAD drift、symlinkを独立TCにしていない。またActionsは`tests/run-tests.sh`だけを実行し、新規Python unit fileへ現行の自動導線はない。
- required action: `tests/extras/ta-61-durable-run.sh`を追加してunit suiteをCI入口へ接続し、R-001〜R-005を破壊するadversarial testsと全artifact不変条件を追加する。全ai-loop discoveryを除外する場合はbaseline実測と理由を記録する。
- disposition: 未反映。

### R-007 — minor — Human C-3がTODO dependency graphへ入っていない

- evidence: T-01の`depends_on`が空で、文章上のStop Conditionしかexec開始を防がない。
- required action: T-01をH-01依存とし、H-01をAgent実装全体の単一gateとして明記する。
- disposition: 未反映。

## 指摘なし観点

- Goal、AC mapping、In/Out scope、critical mode判定
- rollout-policyのai-loop self-protection carve-out認識
- C-3/C-4/mergeをHuman-ownedに維持する宣言
- stable action ID、restart、duplicate / one-shotの基本方針
- state単体のtemp + fsync + replace + directory fsync方針

## C-3移行条件

1. R-003のHuman decisionを確定する。
2. R-001〜R-007をPlan / TODO / Test Casesへ反映する。
3. 新Plan hashでC-1とmaker-context非共有C-2を再実行する。
4. critical / major 0、C-2 approve、Plan Package integrity PASSを満たす。

条件成立まではproduction変更を行わない。
