# TASK-0917 T-35 実走ログ（実 PR #940 / 2026-07-31）

すべて**実測値**。実行できなかったものは「未実行」と明記する。

## 0. 環境

| 項目 | 実測値 |
|------|-------|
| worktree | `/Users/user/Documents/GitHub/plangate-wt-0917` |
| branch | `chore/task-0917-e2e-probe` |
| origin | `git@github-s977043:s977043/PlanGate.git` |
| gh account | `s977043`（各 `gh` 実行の直前に `gh auth switch` → `gh api user --jq .login` で確認） |
| repo 引数 | `s977043/PlanGate` |
| PR | 940（draft / OPEN / base `main`） |
| PR head（実走前） | `fe0abc66d426ce13b18c58d407ecfa6f68808450` |
| `source_sha` | `d64e36f6c275a15506b4d3956a9bd6c6c7d3f41d`（probe branch の base commit = `origin/main`） |
| 実装の取得元 | `feat/task-0917-delivery`（`git show` でバイト等価に取り出し・**改変ゼロ**） |

## 1. 実行コマンドと exit code

| # | コマンド | exit | 備考 |
|---|---------|------|------|
| 1 | `git fetch origin` | 0 | 読み取り |
| 2 | `gh auth switch --user s977043` + `gh api user --jq .login` | 0 | `s977043` |
| 3 | `gh pr view 940 --repo s977043/PlanGate --json ...` | 0 | head = `fe0abc6…` |
| 4 | `python3 harness/driver.py collect1` | 0 | Collector + `assess()` 1 回目 |
| 5 | `git add … && git commit …`（repair commit 作成） | 0 | `7b229223b21a40708d1262fa86ff287977621ee4` |
| 6 | `python3 harness/exec_step.py` | 0 | **Executor 実走（外部書き込み）** |
| 7 | `gh pr view 940 --json headRefOid,state,isDraft,comments` | 0 | 実物照合 |
| 8 | `python3 harness/driver.py collect2` | 0 | 最新 head で再評価 |
| 9 | `python3 harness/idem_recon.py` | 0 | 冪等 + Reconciler + 負検証 |
| 10 | `gh pr checks 940` | 0 | CI 収束確認（全 pass） |
| 11 | `python3 harness/driver.py collect3` | 0 | CI 収束後の再評価 |

## 2. Step 1 — Collector（1 回目 / head `fe0abc6…`）

`collector.collect(task_id="TASK-0917", repo="s977043/PlanGate", pr_number=940,
source_sha="d64e36f…", plan_text=<plan.md>, findings=[], cwd=<worktree>)`

実行された 6 本（`raw/gh-calls-1.json` に生 stdout あり）:

| # | 種別 | 実 argv | rc | 結果 |
|---|------|--------|----|------|
| 1 | REST GET | `gh api repos/s977043/PlanGate/pulls/940` | 0 | `head.sha` / `base.ref=main` / `mergeable=true` |
| 2 | REST GET | `gh api repos/s977043/PlanGate/commits/fe0abc6…/check-runs?per_page=100 --paginate` | 0 | `total_count=7` |
| 3 | REST GET | `gh api repos/s977043/PlanGate/pulls/940/reviews?per_page=100 --paginate` | 0 | `[]`（空配列） |
| 4 | REST GET | `gh api repos/s977043/PlanGate/rules/branches/main` | 0 | ruleset 4 件 |
| 5 | git（読み取り） | `git diff --name-only origin/main...fe0abc6…` | 0 | 1 ファイル |
| 6 | git（読み取り） | `git merge-base --is-ancestor d64e36f… fe0abc6…` | 0 | ancestry = `True` |

組み上がった snapshot（`snapshot-1.json`）の主要フィールド:

| キー | 実測値 |
|------|-------|
| `head_sha` | `fe0abc66d426ce13b18c58d407ecfa6f68808450` |
| `mergeable` | `MERGEABLE`（生 `true` → 写像） |
| `checks` | 7 件・全 `success`・全件 `sha` が head と一致 |
| `raw_check_runs` | 7 件（`id` / `name` / `status` / `conclusion` / `head_sha` / `completed_at`） |
| `required_checks` | `["Markdown lint"]` |
| `review` | `{"state": "none", "sha": "fe0abc6…"}` |
| `changed_files` | `["docs/working/TASK-0917/evidence/e2e/probe.md"]` |
| `allowed_paths` | 21 件（plan.md `## Files / Components to Touch` から抽出。`docs/working/TASK-0917/` を含む） |
| `source_sha_ancestry` | `true` |
| `dod_evaluated` | `false` |
| `findings` | `[]`（**明示供給**したため `findings_unavailable` は積まれない） |
| `escalation_flags` | **`[]`（空）** |
| `conflict_resolution` | 出力なし（三点未充足のため正しく省略） |

### `assess()` 1 回目

`delivery.assess(snapshot, entries=[], plan_hash=None)` →

```json
{ "state": "WAITING_FOR_REVIEW",
  "actions": [],
  "reasons": ["required review が最新 head で未着弾"] }
```

`changed_files` の 1 件は `allowed_paths` の `docs/working/TASK-0917/` に
内包されるため `plan_deviation` は発火しなかった（`_path_allowed()` の
ディレクトリ境界一致が実データで機能）。

## 3. Step 2 — repair commit の作成（Executor の scope 外）

`probe.md` に無害な 1 行を追記して commit。

- commit SHA: **`7b229223b21a40708d1262fa86ff287977621ee4`**
- 変更: `docs/working/TASK-0917/evidence/e2e/probe.md` の 1 行追記のみ
- この時点では **未 push**（PR head は `fe0abc6…` のまま）

`ExecContext.repair_commit_sha` は「呼び出し側（exec レーン）が実測して渡す」
契約であり、commit 生成は Executor の責務ではない（設計どおり）。

## 4. Step 3 — Executor 実走

### 入力

`delivery._action("repair_ci", {...})`（**実物のコンストラクタ**）で組み立て:

```json
{ "action_kind": "repair_ci",
  "action_id": "sha256:6cc2520b2024d22f228016f50008da1deb45cf8df55398b8cad4b123c57b7456",
  "pr_number": 940,
  "head_sha": "fe0abc66d426ce13b18c58d407ecfa6f68808450",
  "round": 1,
  "taxonomy": "code",
  "failed_checks": ["Markdown lint"] }
```

`executor.verify_action_id(action)` → **`True`**（`c3_contract.canonical_hash()`
での再計算照合が実データで通ることを外部作用の前に確認）。

同形の `intent` entry を `delivery.append_entries()` で record へ追記（1 行）。
`delivery.py` の `receipt` サブコマンドは intent 先行を必須とするため。

`ExecContext(repo="s977043/PlanGate", branch="chore/task-0917-e2e-probe",
task_dir=<evidence/e2e/run>, gh=gh_exec, cwd=<worktree>,
repair_commit_sha="7b22922…")`

### 実行順序の実証（`raw/spawn-ledger-exec.json`）

`gh_exec._spawn`（唯一の `subprocess` 起動点）で捕捉した**全プロセス起動**を
時系列で示す。**この 6 件が本実走で起動された外部プロセスの全件**である。

| seq | argv | rc | 対応する段階 |
|-----|------|----|-------------|
| 1 | `gh pr comment 940 --body-file /…/plangate-gh-exec-*.md --repo s977043/PlanGate` | 0 | **① 通知コメント** |
| 2 | `gh pr view chore/task-0917-e2e-probe --json headRefOid --repo s977043/PlanGate` | 0 | **② pre-check**（`push_already_applied`） |
| 3 | `gh pr view chore/task-0917-e2e-probe --json headRefName,baseRefName --repo s977043/PlanGate` | 0 | ③ push 事前検査 1・2 |
| 4 | `git ls-remote --get-url origin` | 0 | ③ push 事前検査 3 |
| 5 | `git merge-base --is-ancestor fe0abc6… HEAD` | 0 | ③ push 事前検査 4（fast-forward） |
| 6 | `git push origin HEAD:refs/heads/chore/task-0917-e2e-probe` | **0** | **③ repair push** |

- **④ receipt は subprocess を起動しない**（`delivery.main()` の in-process 呼び出し）。
  ledger に現れないこと自体が「実行系境界を広げない」という設計主張の実測裏付け。
- seq 2 の pre-check は `head == expected_parent_sha`（`fe0abc6…`）で早期
  `False` を返すため、`is_ancestor` を呼ばず gh 1 本で終わっている。
- seq 6 の stderr（実出力）は 2 行:

  ```text
  To github-s977043:s977043/PlanGate.git
     fe0abc6..7b22922  HEAD -> chore/task-0917-e2e-probe
  ```

  `+` 記号を伴わない **fast-forward** 更新であることが読み取れる。
- 組み立てられた push argv は `git push origin HEAD:refs/heads/<branch>` のみ。
  `+` / `--force*` / `--delete` 等は**一度も現れていない**。

### push の終了コード検査（R2 B2-1）

`gh_exec.push_pr_head()` は `_spawn` の `returncode`（実測 0）を見て
`PushResult(pushed=True, …)` を返し、`executor.perform_push()` は
`getattr(result, "pushed", False)` を検査して `PushOutcome(True)`。
**成功パスで rc が実際に参照されていること**を実環境で確認した。
失敗パス（rc != 0）は本実走では発生させられなかった → `findings.md` F-4 参照。

### 出力（`execution-report.json`）

```json
{ "outcomes": [{
    "action_id": "sha256:6cc2520b…",
    "action_kind": "repair_ci",
    "status": "executed",
    "result_ref": "adopted:7b229223b21a40708d1262fa86ff287977621ee4|comment:https://github.com/s977043/PlanGate/pull/940#issuecomment-5140067809",
    "comment_url": "https://github.com/s977043/PlanGate/pull/940#issuecomment-5140067809",
    "pushed": true,
    "escalation_flags": [],
    "reason": null }],
  "escalation_flags": [] }
```

### record.jsonl（`run/delivery/record.jsonl` / 3 行）

| 行 | kind | 要点 |
|----|------|------|
| 1 | `intent` | `action_id: sha256:6cc2520b…` / payload に `pr_number` `head_sha` `round` `taxonomy` `failed_checks` |
| 2 | `notice` | `comment_url` / `repair_commit_sha: 7b22922…`（抑止キー `(pr_number, head_sha, repair_commit_sha)`） |
| 3 | `receipt` | `result_ref` に `adopted:` と `comment:` / `round: 1` / `pr_number: 940` |

### 実物照合（`gh pr view 940`）

```json
{ "headRefOid": "7b229223b21a40708d1262fa86ff287977621ee4",
  "state": "OPEN", "isDraft": true, "comment_count": 3 }
```

- 本実走が投稿したコメント: `s977043` /
  `https://github.com/s977043/PlanGate/pull/940#issuecomment-5140067809` /
  本文冒頭 `## ai-loop: repair push 通知（TASK-0917 / #917 / R-005）`
- 他 2 件は PR 作成時に bot（`gemini-code-assist` / `github-actions`）が
  自動投稿したもので、本実走の作用ではない。

## 5. Step 4 — 最新 head で再評価

### collect 2 回目（push 直後・head `7b22922…`）

| キー | 実測値 |
|------|-------|
| `head_sha` | `7b229223b21a40708d1262fa86ff287977621ee4`（**変化を確認**） |
| `checks` | **6 件**（`CodeQL` がまだ未登録） |
| `raw_check_runs` の生 status | `plangate CLI tests: in_progress / conclusion=null`、`Analyze (python): in_progress / conclusion=null`、他 4 件 `completed / success` |
| `checks[].conclusion` | 上記 2 件が **`"in_progress"` に写像**（R-019） |
| `escalation_flags` | `[]` |

`assess()` →

```json
{ "state": "WAITING_FOR_CHECKS",
  "actions": [],
  "reasons": ["最新 head の CI が pending / 未着（stale checks は無効）"] }
```

### collect 3 回目（CI 収束後・同 head）

| キー | 実測値 |
|------|-------|
| `checks` | **7 件**・全 `success`（`CodeQL` が遅れて登録された） |
| `escalation_flags` | `[]` |

`assess()` → `WAITING_FOR_REVIEW` /
`["required review が最新 head で未着弾"]`

### state 遷移まとめ（実出力）

| run | head | checks | state |
|-----|------|--------|-------|
| 1 | `fe0abc6…` | 7 件 全 success | `WAITING_FOR_REVIEW` |
| 2 | `7b22922…` | 6 件（2 件 `in_progress`） | `WAITING_FOR_CHECKS` |
| 3 | `7b22922…` | 7 件 全 success | `WAITING_FOR_REVIEW` |

### 冪等性（`idempotency-rerun.json`）

同一 action で `executor.execute_actions()` を再実行:

```json
{ "outcomes": [{ "status": "already_receipted", "pushed": false,
                 "result_ref": null, "comment_url": null }],
  "spawn_calls_during_rerun": 0,
  "record_lines_after": 3 }
```

**subprocess 起動 0 回**・record 行数不変。receipt 済み action が
再要求も再実行もされないことを実環境で確認した。

## 6. Step 5 — Reconciler（`reconcile.json`）

```json
{ "intent_action_ids": ["sha256:6cc2520b…"],
  "receipt_action_ids": ["sha256:6cc2520b…"],
  "pending": [],
  "orphan_receipts": [],
  "dispositions": {},
  "conflict_resolution": null,
  "escalation_flags": [],
  "filter_unexecuted_of_same_action": [],
  "is_applied": true }
```

- intent ↔ receipt が 1:1 で突合。未実行 (`pending`) / 記録なき実行
  (`orphan_receipts`) ともにゼロ。
- `reconciler.filter_unexecuted([action], entries)` が空リストを返す
  = Executor へ二度渡さない防御が実データで機能。
- `dispositions` が空なのは `repair_review` / `record_disposition` を
  実走していないため（`repair_ci` は finding に紐づかない）。

## 7. `push_pr_head()` 事前検査の負検証（`precheck-probes.json`）

いずれも **`git push` の argv は一度も spawn されていない**（ledger で確認）。

| probe | 結果 | 実メッセージ |
|-------|------|-------------|
| 事前検査 1: `branch="main"` | `Denied(PRECHECK)` | `gh pr view に失敗（rc=1）: 'no pull requests found for branch "main"'` |
| 事前検査 4: fast-forward でない SHA | `Denied(PRECHECK)` | `fast-forward でない（… は HEAD の祖先でない / rc=128）` |
| 入力検査: `expected_parent_sha="HEAD~1"` | `Denied(PRECHECK)` | `SHA が許可形式でない: 'HEAD~1'`（gh / git を 1 本も起動せず） |
| 入力検査: `branch="../evil"` | `Denied(PRECHECK)` | `branch 名が許可形式でない: '../evil'`（同上） |
| 事前検査 3: origin URL 一致 | 実測値で純関数評価 | 実 origin `git@github-s977043:s977043/PlanGate.git` に対し `_origin_matches(url, "s977043/PlanGate") = True` / `_origin_matches(url, "s977043/other") = False` |

事前検査 2（`baseRefName` と一致する branch へ push しない）は、
`headRefName == baseRefName` となる PR がこの環境に存在しないため
**実 PR では到達不能**だった（`findings.md` F-6）。

## 8. 未実行 / 本実走で確認できなかったこと

- `delivery.py assess` **CLI**（`_cmd_assess`）経由の実行 — c3-prime 承認
  （`approvals/c3.json`）を要求するため、本実走では `assess()` 関数を
  直接呼んだ。**c3-prime ゲートの実 PR 実走は未実行**。
- `git push` の**失敗パス**（reject / 認証失敗 / ネットワーク断）— 意図的に
  失敗させるには禁止操作（`main` への push 等）が必要なため未実行。
- `repair_review` / `record_disposition` / `resolve_conflict` /
  `dod_reevaluate` / `feedback_loop_referral` の実 PR 実走 — 本実走は
  `repair_ci` 1 件のみ。
- Collector の**失敗系**（rate limit / 403 / shallow clone / 破損 record）—
  実 API では発生しなかったため未観測（`escalation_flags` は 3 回とも空）。
- `MERGE_READY` への到達 — review が着弾しないため未到達（PR #940 は
  DO NOT MERGE であり、到達させるべきでもない）。

## 9. 書き込んだ外部作用の全件

| 種別 | 件数 | 内容 |
|------|------|------|
| PR コメント | **1** | `https://github.com/s977043/PlanGate/pull/940#issuecomment-5140067809` |
| branch への push | **1** | `fe0abc6..7b22922` → `chore/task-0917-e2e-probe`（fast-forward） |
| その他 | **0** | merge / review / close / reopen / ready / edit / branch 削除 / force push / 非 GET の `gh api` / `main` への push / 他 PR への操作 — **いずれもゼロ** |
