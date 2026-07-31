# TASK-0917 T-35 / T-36: 実 PR 1 周の手動実走（AC-4 / TC-11）

fixture E2E（`tests/extras/ta-57-pr-convergence.sh`）では担保できない
「実 REST レスポンスの形状 / `git push` の実終了コード / `push_pr_head()` の
事前検査 4 点の実挙動 / 非同期 check 登録タイミングでの `conclusion` 写像」を、
**実物の実装をそのまま**使って実 PR に対して 1 周させた記録。

- 対象 PR: [#940](https://github.com/s977043/PlanGate/pull/940)（`chore/task-0917-e2e-probe` → `main` / draft / **DO NOT MERGE**）
- 実施日: 2026-07-31
- 実行アカウント: `s977043`

## 結果サマリ

| 項目 | 結果 |
|------|------|
| Collector（REST GET 4 本 + 読み取り系 git 2 本） | 6/6 成功・`escalation_flags` は 3 回とも空 |
| `assess()` の state 遷移 | `WAITING_FOR_REVIEW` → `WAITING_FOR_CHECKS` → `WAITING_FOR_REVIEW` |
| Executor の実行順序 | ① コメント → ② pre-check → ③ push → ④ receipt（spawn ledger で実証） |
| 外部書き込み | **コメント 1 件 / push 1 回のみ**（それ以外ゼロ） |
| 冪等性 | 同一 action の再実行は `already_receipted` / subprocess 起動 **0 回** |
| Reconciler | intent 1 / receipt 1 / pending 0 / orphan 0 |
| fixture との差異 | [`findings.md`](./findings.md) 参照（**差異あり**・critical なし） |

詳細な入出力は [`run-log.md`](./run-log.md)。

## 前提条件

1. **実装の在り処**: `scripts/ai-loop/{gh_exec,collector,executor,reconciler,delivery,ci_taxonomy,plan_package,c3_contract}.py`
   はブランチ `feat/task-0917-delivery` にある。probe ブランチ
   `chore/task-0917-e2e-probe` は `main` 由来のため**実装を含まない**。
2. **gh アカウント**: 本リポジトリの操作は `s977043` で行う。ローカル環境では
   active account が別アカウントへ戻る事象があるため、**`gh` を使う処理は
   同一シェル呼び出し内で** `gh auth switch --user s977043` →
   `gh api user --jq .login` で確認 → 本処理、の順に atomic 実行する。
3. **origin**: `git@github-s977043:s977043/PlanGate.git`（SSH host alias 付き）。
4. **repo 文字列は `s977043/PlanGate`**（大文字小文字を含めて実値と一致させる。
   `gh_exec.api_endpoint_patterns()` が repo 実値で endpoint を束縛するため）。

## 再現手順

```sh
# 0) worktree を用意し probe ブランチへ
cd <worktree>
git fetch origin
git switch chore/task-0917-e2e-probe

# 1) 実装を feat/task-0917-delivery からバイト等価に取り出す
mkdir -p /tmp/ai-loop-impl
for f in $(git ls-tree --name-only feat/task-0917-delivery scripts/ai-loop/); do
  git show "feat/task-0917-delivery:$f" > "/tmp/ai-loop-impl/$(basename "$f")"
done
# harness スクリプトは impl/ を sys.path へ入れる想定。以下のいずれかで配置:
#   cp -r /tmp/ai-loop-impl <harness ディレクトリ>/impl

# 2) Collector + assess（1 回目）
gh auth switch --user s977043 && gh api user --jq .login
python3 harness/driver.py collect1

# 3) repair 用の無害な 1 行コミットを probe ブランチに作る（Executor の scope 外）
printf -- '- repair push probe: ...\n' >> docs/working/TASK-0917/evidence/e2e/probe.md
git add docs/working/TASK-0917/evidence/e2e/probe.md
git commit -m "chore(e2e): repair push probe"
git rev-parse HEAD           # → harness/exec_step.py の REPAIR_COMMIT に設定

# 4) Executor 実走（**ここだけが外部書き込み**: コメント 1 件 + push 1 回）
gh auth switch --user s977043 && gh api user --jq .login
python3 harness/exec_step.py

# 5) 最新 head で再評価
python3 harness/driver.py collect2

# 6) 冪等性の再確認 + Reconciler + pre-check の負検証
python3 harness/idem_recon.py

# 7)（任意）CI 収束後にもう 1 回評価
python3 harness/driver.py collect3
```

`harness/*.py` の定数（`HEAD_AT_APPROVAL` / `REPAIR_COMMIT` / `PR` / `BRANCH`）は
実走ごとに実測値へ書き換えること。

## 注意事項

- **`gh pr merge` / `gh pr review` / `gh pr close` / `gh pr edit` / branch 削除 /
  force push / `main` への push は禁止**。`gh_exec` の allowlist はこれらを
  「補集合として」deny するが、**同一セッションの別プロセスからの `gh` は
  塞がらない**（`gh_exec.py` module docstring の「回避不能なギャップ」）。
  実走者が規律で守る必要がある。
- harness は `gh_exec._spawn`（実装が「テストが差し替えられる唯一の口」と
  明記している seam）を**素通しの記録ラッパ**で包むだけで、挙動は変えていない。
  実装ファイルは 1 バイトも変更していない。
- `record.jsonl` は `docs/working/TASK-0917/evidence/e2e/run/delivery/record.jsonl`
  に出る（`task_dir` を `evidence/e2e/run` にしているため）。実運用の
  `docs/working/TASK-0917/delivery/record.jsonl` とは分離してある。
- PR #940 は検証専用。**検証完了後に人間が close + branch 削除**すること
  （Executor は原理的にどちらも実行できない）。

## ファイル一覧

| ファイル | 内容 |
|---------|------|
| `README.md` | 本ファイル（再現手順） |
| `run-log.md` | 各ステップの入出力・state 遷移・実行順序の実証 |
| `findings.md` | fixture では検出できなかった差異 |
| `snapshot-1.json` / `snapshot-2.json` / `snapshot-3.json` | 実 PR から取得した snapshot |
| `assess-1.json` / `assess-2.json` / `assess-3.json` | `delivery.assess()` の戻り値 |
| `action-repair-ci.json` | Executor に渡した `repair_ci` action |
| `execution-report.json` | `executor.execute_actions()` の結果 |
| `idempotency-rerun.json` | 同一 action 再実行の結果（冪等性） |
| `reconcile.json` | `reconciler.reconcile()` の結果 |
| `precheck-probes.json` | `push_pr_head()` 事前検査の負検証 |
| `raw/gh-calls-{1,2,3}.json` | Collector が実行した gh / git 呼び出しと**生 stdout** |
| `raw/spawn-ledger-exec.json` | Executor 実走中に起動された全 argv（時系列） |
| `raw/spawn-ledger-idem-recon.json` | 冪等再実行 + 負検証中の全 argv |
| `run/delivery/record.jsonl` | intent / notice / receipt の append-only 記録 |
| `harness/*.py` | 実走に使ったハーネス（実装ではない） |
| `probe.md` | push 対象の無害なダミーファイル |
