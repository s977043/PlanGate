# EXECUTION PLAN — TASK-0917

> Issue: [#917](https://github.com/s977043/plangate/issues/917)（enhancement / ai-loop / **priority:P0**）
> Parent EPIC: [#870](https://github.com/s977043/plangate/issues/870)（**close blocker**）
> 由来: [#873](https://github.com/s977043/plangate/issues/873) / TASK-0873 が V2 送りとした「実 PR 収束系」の実装
> 入力: [`pbi-input.md`](./pbi-input.md) / [`review-external.md`](./review-external.md)（`R-001`〜`R-016` 全件反映済み）
> 作成: 2026-07-31（B-1 確認 3 問 → 事前メトリクス検証 → B-2 比較（D1〜D4）→ B-3 生成）
> 基点: `origin/main` = `b45ab17`

## 確認事項（B-1 / Human 回答済み 2026-07-31）

| # | 質問 | Human 回答 | 帰結 |
|---|------|-----------|------|
| Q1 | In scope 5「raw check evidence 検証」/ AC-9 の去就（(a) 実施 / (b) V2 送り） | **縮小実施（同梱＋自己照合・限界を明記）** | AC-9 を「Collector が check-run の生レスポンスを snapshot に同梱し、`checks[]` が生値から導出されたことを **Collector 内で機械照合**する」に縮小して採用。**限界＝手作りの snapshot を直接 `delivery.py` に投入する経路は塞がない**ことを plan / handoff / doc に明記する（Phase 1 の信頼境界は解消しきらない） |
| Q2 | AC-4 の E2E 実現方式（U-1） | **fixture 主体＋実 PR 1 周の手動実走証跡** | `tests/extras/` の固定シナリオ（fixture record/replay）を**機械化された合格基準**とし、実 PR 1 周は**手動実走の証跡**（`evidence/e2e/`）として別途 1 回記録する。CI 常設はしない |
| Q3 | 実測で判明した repo 設定の穴 3 件（`required_approving_review_count: 0` / `dismiss_stale_reviews_on_push: false` / classic branch protection 404）の扱い | **3 件まとめて issue 起票する**（起票はオーガナイザーが実施） | 本 PBI は **repo 設定に依存しない設計**とする。起票された issue は Risks の残存リスク欄から参照する（本 PBI の完了条件には含めない） |

## Goal

`delivery.py`（純判定器 / TASK-0873）の**外側 2 層**として **GitHub Collector / Action Executor / Reconciler** を新設し、`PR → CI/review repair → 最新 head 再評価 → MERGE_READY` の**実 PR 収束**を成立させる。あわせて `required_checks[]` ⊇ 照合（AC-2）と **in-process allowlist による破壊的操作の構造的封じ込め**（AC-5）を実装し、AC-1〜AC-9 を機械検証可能にする。`delivery.py` / `c3_contract.py` / `c3prime_verify.py` は**一行も変更しない**。

## Constraints / Non-goals

- **NO MERGE BY AI（Iron Law）**: `MERGED` 状態は `STATES` に存在せず、Executor は merge を実行しない。**merge は Human-owned**（`.claude/rules/responsibility-classes.md`）
- **判定エンジン不変（AC-7）**: `git diff --stat origin/main -- scripts/ai-loop/delivery.py scripts/ai-loop/c3_contract.py scripts/ai-loop/c3prime_verify.py` = **0 行**。既存 57 テスト全 PASS。`<!-- contract:begin/end -->` ブロックは**手編集禁止**（`ta-56-delivery.sh` の `cmp -s` で byte 一致検証）
- **PR の承認状態・存在・履歴を変える操作すべてを禁止**（approve / close / reopen / ready / force push / branch 削除 / 非 GET api）。R-002 の包括ルール
- **HO 非接触**: touch は `scripts/ai-loop/**` / `tests/extras/**` / `docs/workflows/ai-loop/**` / `scripts/sync-plugin-plangate.sh` / `plugin/**` / `docs/working/**` のみ。`.github/workflows/` / `bin/plangate` / `schemas/` / `.claude/**` は**触らない**（E2E を GitHub Actions 化しない理由でもある）
- **rollout-policy §2 判定基盤 carve-out ①②に該当**（`scripts/ai-loop/**` / `docs/workflows/ai-loop/**`）→ **ai-loop 自走は escalate 固定**（#916 の機械強制が入るまでは規範層で担保）
- **stdlib only**（`json` / `pathlib` / `re` / `sys` / `argparse` / `ast` / `subprocess`）。`requests` / `PyGithub` は追加しない（pip hash pin の運用コストを増やさない）
- Non-goals: merge 実行 / `delivery.py` の判定規則変更 / disposition `evidence_ref` の内容真正性検証（C-4 責務）/ Run Evidence の正規化・Evolution Loop 接続（#874 / #869）

## アプローチ比較（B-2）

### 論点 D1: `required_checks[]` ⊇ 照合の実装層（U-3 / R-015 / In scope 4）

| 案 | 内容 | 長所 | 短所 |
|----|------|------|------|
| **D1-A（採用）** | **Collector 側 pre-check**。ruleset API から required checks を取得し、snapshot の `checks[]` 名集合が ⊇ でなければ `escalation_flags` に `required_checks_missing:<name>,...` を積んで `assess()` を**通す** | `delivery.py` 差分 0（AC-7 と両立）。`escalation_flags` は `PRIORITY_ORDER` 上 **3 位**（`invalid_snapshot` / `plan_deviation` の次）で、`assess()` の `checks[]` 評価ブロックより**先に短絡**する（`delivery.py` L271-274「# 1. escalation_flags」実測）→ 部分登録 green は機械的に `HUMAN_ESCALATED` へ倒れる。`record.jsonl` に state entry が残るので AC-6（#894 no-progress 検知）と接続できる | ⊇ 照合の正しさは Collector のテストでしか担保されない（`delivery.py` の契約には現れない） |
| D1-B | `validate_snapshot()` / `assess()` に `required_checks[]` フィールドと分岐を追加 | 契約に現れる・doc §4 の字面に忠実 | **AC-7 と正面衝突**（Out of scope の改訂 + AC-7 緩和が必要）。#873 の 57 テストと contract byte 一致を再設計する羽目になる |
| D1-C | ⊇ 照合を V2 送り | 実装ゼロ | issue #917 の In scope 4 を削ることになる。doc §4 が名指しで警告した穴（部分登録 green）が残る |

**採用: D1-A**。加えて **required checks の取得失敗（403 / rate limit / 想定外形式）は config fallback を入れず、`escalation_flags` に `required_checks_fetch_failed:<reason>` を積んで fail-closed** とする（config キャッシュ案は「取得できない環境で古い集合を正と誤認する」逆リスクがあるため **V2 候補として handoff に記録**）。

**取得元（R-022 反映）**: `gh api repos/{o}/{r}/rules/branches/{base_ref}` の `[.[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context]`（実測: `gh api repos/s977043/plangate/rules/branches/main --jq ...` → `["Markdown lint"]` / exit 0）。**ruleset id を使わない**理由は 3 点: ①`repos/{o}/{r}/rulesets/{id}` の `{id}` を解決する手段が設計に無く、一覧 endpoint `repos/{o}/{r}/rulesets` は `gh api` allowlist（TC-29）の外で `Denied` になる ②id `14939019` は本リポジトリ固有の実値で、埋め込むと Q3 帰結「repo 設定に依存しない設計」と矛盾し配布先で壊れる ③`rules/branches/{ref}` は **base が default branch 以外でも当該 ref の実効ルールを返す**。**複数ルールが返る場合は全 `required_status_checks` ルールの context 集合の union を required 集合とする**（いずれか 1 本を選ぶと取りこぼす）。

### 論点 D2: 破壊的操作の封じ込め方式（AC-5 / R-001 / R-002）

| 案 | 内容 | 長所 | 短所 |
|----|------|------|------|
| **D2-A（採用）** | **in-process の gh/git 実行ラッパ `gh_exec.py` に集約し、argv トークン列の構造照合 allowlist で強制**。禁止は allowlist の**補集合**として自動成立。境界（ラッパ以外が `subprocess` を import しない）は **AST ベース**の検査器で機械強制 | 列挙漏れが構造的に塞がる。Python の `subprocess.run(["gh", ...])` 形でも効く（PreToolUse hook は Bash の command 文字列しか見ないので効かない）。テスト可能 | **この Python プロセス経由の作用しか守らない**（下記ギャップ） |
| D2-B | 既存 hook（`check-delegation-commit-boundary.sh`）+ branch protection に依拠 | 追加実装ゼロ | **3 重に不成立**（R-001 実測）: ①`PLANGATE_DELEGATION_NOCOMMIT != 1` で L62-65 が即 allow ②`.claude/settings.json` は `PreToolUse` 未配線（`bin/plangate doctor` = `[FAIL] PlanGate hooks not wired (7/10)`・**`permissions` キー自体が存在しない**（トップレベルキーは `["hooks"]` のみ = deny 設定 0 件・R-031 実測）・`.git/hooks/` は `.sample` のみで非 sample hook 0 件）③Bash の command 文字列しか見ない。ruleset 側も `required_approving_review_count: 0` で承認を強制していない |
| D2-C | トークン権限のスコープ分離（merge できない token を配る） | プロセス外も守れる | **分離不可**。merge も comment も同じ `pull_requests:write` スコープ |

**採用: D2-A**（D2-B は多層防御の *補助* としてのみ runbook に書き、**設計は依存しない**）。

#### D2-A の設計詳細（実装契約）

- `scripts/ai-loop/gh_exec.py` を **リポジトリ内で唯一 `subprocess` を import してよいモジュール**とする（gh と git を同一モジュール・allowlist テーブルは 2 つ）。`from __future__ import annotations` / stdlib only / `shell=False` / argv リスト（既存 `scripts/doctor_check.py` の `subprocess.run([...], capture_output=True, text=True, check=False)` 慣習を踏襲）
- **allowlist は argv トークン列の構造照合**:
  1. `argv[0]` は wrapper が固定（caller から受け取らない）
  2. `--k=v` を `--k` + `v` に正規化。**短縮形は正規化せず即 deny**（R-029 反映）: `-X` `-f` `-F` `-q` `-b` `-w` `-e` 等の 1 文字フラグと `-XPOST` の結合形は**分解したうえで「短縮形が使われた」ことを理由に `Denied`** とする。理由 = 短縮形の意味は**サブコマンド依存**で単一のグローバル正規化表が成立しない（実測: `-F` は `gh api` では `--field`、`gh pr comment` では `--body-file`）。**wrapper 自身は常に long 形で argv を組み立てる**ため運用上の不利益はない
  3. **未知フラグは即 deny**
  4. 位置引数列を rule の `verbs` と**完全一致**照合（prefix / 部分一致を使わない）
  5. rule 固有 constraint を適用
  6. **関数末尾は無条件 `raise Denied`**（fallthrough allow を作らない）
- **flag 単位の allowlist が必須**。根拠（実測）: `gh pr comment` には **`--delete-last` / `--edit-last` / `--yes` / `--create-if-none`** が実在し、サブコマンド名だけの allow は Out of scope の「PR の履歴を変える操作」を通してしまう
- **`gh api` の GET 強制は 3 条件 AND**: ①`--method` があるなら値が `GET` に完全一致（無ければ GET）②**`--raw-field`(-f) / `--field`(-F) / `--input` が 1 つでもあれば deny**（gh の help に「adding request parameters will automatically switch the request method to POST」）③endpoint が正規表現の**完全一致**。owner/repo は呼び出し時の `repo` 実値で束縛（自由変数にしない・`{owner}` プレースホルダ禁止）
- **`graphql` は allowlist に載せない**（GraphQL は常に POST で `mergePullRequest` / `addPullRequestReview` の直接経路になる。REST GET だけで必要な入力が揃うことを実測済み）。**`--cache` も除外**（stale が AC-1 の head SHA 束縛と衝突）
- **git push は allowlist ではなく構造化 API**: `push_pr_head(*, repo, branch, expected_parent_sha, cwd)` が argv を自ら組み立てる。`+`（force 相当）/ 空 src `:branch`（削除）/ `--force*` / `--delete` / `--mirror` / `--prune` / `--receive-pack` は「**組み立てない**」ことで原理的に発生させない。事前検査: branch が `gh pr view --json headRefName` の実測値と一致 / `baseRefName` と不一致 / `git remote get-url origin` が repo と一致 / fast-forward であること。読み取り系 git（`rev-parse` / `merge-base` / `log` / `status` / `diff` / `ls-remote` / `show`）のみ argv 検査型 allowlist
- **subprocess 境界検査は AST ベース**（`scripts/ai-loop/check_exec_boundary.py`・stdlib `ast`）。**substring 走査は使わない**: 実測で ta-56 様式の grep を `scripts/ai-loop/` 全体へ広げると `discovery.py` の **docstring の禁止宣言文**に HIT して偽陽性になる（AST 版は clean）。対象 = `scripts/ai-loop/*.py`、除外 = `test_*.py`。ただし**テストの単純除外は迂回路**になるため、`test_*.py` にも**追加不変条件（精緻化版）**を AST で課す。**`delivery.py` 系の既存 substring 走査（`test_tc18_pure_verdict_source` / ta-56）は AC-7 のため一字も変えない**
- **検査対象トークン集合（R-025 反映 / pbi AC-5 と同一集合まで拡張）**: `subprocess` / `os.system` / `os.popen` / `os.exec*` / `os.spawn*` / `urllib` / `socket` / `http.client` / `requests` / `importlib.import_module` による動的 import。**`subprocess` の import だけを見る設計では `gh_exec.py` 内の `os.system("gh pr merge 1")` を止めるものが存在しない**ため、集合を pbi AC-5 の列挙へ揃える
- **`gh_exec.py` は「除外」ではなく逆向きのホワイトリスト検査**（R-025）: `gh_exec.py` に対しては「`subprocess` **のみ**許可・上記のその他の実行系トークンは **0 件**」を AST で課す。除外扱いにすると唯一の実行境界そのものが無検査になる

##### `test_*.py` の argv 先頭要素 不変条件（精緻化 / C-1 F-1 の裁定）

現行ツリーには「argv 先頭要素 = `sys.executable` に限る」という素朴な不変条件の違反が 3 箇所実在し（`test_c3prime_verify.py` の `_run()` 1 箇所 / `test_discovery.py` の 2 箇所）、**いずれも `## Files / Components to Touch` の 21 パスの外**にある。素朴版のままでは exec が「allowed_paths 外を編集して `plan_deviation` → `EXEC_RETURN`」か「承認済み不変条件を無断で弱める」かに追い込まれるため、不変条件を次のとおり精緻化する:

1. **許可条件**: `test_*.py` 内の `subprocess.run` / `check_output`（および `Popen` / `call` / `check_call`）の **argv 先頭要素**は、**`sys.executable`**、**または読み取り専用 git サブコマンドの allowlist**（argv = `["git", <sub>, ...]` かつ `<sub>` ∈ `status` / `rev-parse` / `diff` / `log` / `merge-base` / `ls-remote` / `show`）に限る。→ `test_discovery.py` の 2 箇所（`["git", "status", "--porcelain"]`）は**正当な用途として恒久的に許容**される（テストが git 状態を確認するのは妥当）
2. **grandfather 例外の凍結**: `test_c3prime_verify.py` の `_run()` が組み立てる `args = ["python3", str(VERIFY), str(task_dir)]` は、**`check_exec_boundary.py` に列挙された例外リスト（ファイル + 関数名で特定）に 1 件だけ載せて凍結**する。**例外リストが増えないことをテストで固定**し、新規コードには厳格に適用する。理由 = `"python3"` は PATH 依存で実行中インタプリタと一致しない潜在不具合であり、**正当化ではなく凍結**が正しい扱いである
3. **静的証明できない場合の既定は violation（fail-closed）**: argv がリテラルでなく変数経由で追跡不能なときは、**例外リストに載っていない限り FAIL に倒す**
4. `test_c3prime_verify.py` の `sys.executable` 化は **V2 候補**（本 PBI では触らない = `allowed_paths` を増やさない。Risks 表下の V2 候補に記載）

#### ⚠️ 回避不能なギャップ（AC-5 の scope 明示）

in-process allowlist は **この Python プロセス経由の作用しか守らない**。同一セッションの Bash や別プロセスからの `gh pr merge` は塞がらない。トークン権限でも分離できない（D2-C）。したがって **AC-5 の scope は「Executor 経路のみを守る」**と plan / handoff / doc に明示する。プロセス外は既存の規範層（`.claude/rules/`）+ C-4 Human レビューに残る。

#### R-005（repair push が C-4 承認を stale にする）への対処

| 案 | 判定 |
|----|------|
| ① 既存 approve を dismiss する | **不採用**。Out of scope の包括ルール「PR の承認状態を変える操作」＋「非 GET api 禁止」に**二重抵触** |
| **② 明示通知コメント（採用）** | repair push 時に「承認後に head が変わった」旨を PR コメントで**明示通知**。通知は `repair_ci` / `repair_review` の実行に**内包**し **新 action_kind を作らない**（= U-7 への回答。新設は `delivery.py` 変更＝Out of scope に触れる）。本文は決定論生成で wrapper が temp file へ書き **`--body-file` で渡す**（`--body-file` は wrapper 生成 temp path のみ許可）。**receipt に comment URL を `result_ref` として必ず記録**し、コメント投稿失敗は握り潰さず `escalation_flags` へ |

##### 外部作用の実行順序と二重作用の封じ込め（R-021 反映 / C-3 論点）

`delivery.py` は `actions = [a for a in actions if a["action_id"] not in receipts]` により **receipt が無い intent を次 run で再要求**する（`test_tcE5_intent_without_receipt_rerequested` が固定）。したがって「外部作用**後**・receipt 記録**前**」に中断すると、**同じ repair push が次 run で再実行**され二重作用が起きる。AC-3（冪等）と案②（コメント失敗を成功として receipt に記録しない）はこの一点で衝突する。

**裁定（採用）**:

1. **通知コメントを repair push より先に打つ**（コメント失敗なら push しない）。逆順だと「不可逆な push 済み・receipt 無し」が残るが、この順序なら中断時の残骸は **「余分なコメント 1 件」に限定**される（可逆・かつ receipt / `escalation_flags` に記録される）
2. **Executor に実行前 pre-check を置く**: `expected_parent_sha` が**既に PR head の祖先**であれば「当該 push は実行済み」とみなし **skip** して receipt だけを記録する（`git merge-base --is-ancestor` の読み取り系 allowlist で判定）
3. コメントについても同様に、直近の同一 `action_id` 由来コメントが PR 上に既に存在する場合は再投稿しない

**C-3 論点**: 「不可逆な外部作用の順序」と「残骸をコメント側に寄せる」判断は Human 判断事項として明示承認を仰ぐ（Questions / Unknowns 参照）。

### 論点 D3: snapshot の非 GitHub 由来キーの供給経路（U-10 / R-004）

| キー | 案 | 採用 |
|------|----|------|
| `allowed_paths` | (a) c3 record から読む / (b) **plan.md から再導出** / (c) 手渡し | **(b)**。c3 record には値ではなく `derived_loopspec_hash` しか無い。`plan_package.py` の `derive_loopspec()` が `plan.md` の `## Files / Components to Touch` から `_PATH_RE`（バッククォート内の `a/b` 形式）で抽出する経路が**既存**なので、**`extract_allowed_paths(plan_text)` を public 化して共有**する（`derive_loopspec` の maker/checker 検証を巻き込まないよう抽出だけ切り出す）。抽出 0 件は `escalation_flags` へ |
| `findings[]` | (a) 新 producer を作る / (b) **薄い変換アダプタ + receipt convention** / (c) #874 に委譲 | **(b)**。producer は repo 内に**存在しない**（`repair_commit` / `dod_evaluated` は `delivery.py` + そのテスト + 正本 doc にしか出現しない = consumer のみ・実測）。**#874 は下流（RunEvidence の事後集約）なので委譲不可**。2 段構成で最小実装: ①発見（`id` / `finding_type` / `severity`）は `docs/ai/external-reviewer-interface.md §3.2` の `{finding, severity, evidence, location}` からの**薄い変換アダプタ** ②`disposition` の書き戻しは **`delivery.py receipt --result-ref <str>` の既存汎用文字列**を convention で使う（例 `adopted:<repair_commit_sha>` / `rejected:<evidence_ref_path>`）。Reconciler が `record.jsonl` の intent と receipt を `action_id` で突合して `disposition` を再構成する（**`delivery.py` 本体は不変のまま**） |
| `dod_evaluated` | (a) 別ファイル / (b) **record.jsonl から導出** | **(b)**。「直近の `dod_reevaluate` receipt が現在の `head_sha` に束縛されて存在するか」で導出（Collector 内の 1 関数）。不一致・未存在・破損は `False`（`delivery.py` は False を `MERGE_READY_CANDIDATE` 止まりとして扱うので既に fail-closed） |
| `source_sha_ancestry` | (a) 手渡し / (b) **git 実測** | **(b)**。`git merge-base --is-ancestor <c3.source_sha> <head_sha>`（exit 0→`True` / exit 1→`False` / それ以外→`None`）。**実装は repo 内に 0 件で新規**。shallow clone では解決できないため明示 fetch の前処理を入れる |
| `ci_failure_taxonomy` | (a) CI ログから全自動分類 / (b) **人間 or 別層が明示 + 狭い自動 allowlist**（採用） / (c) 常に未指定 | **(b)**。実 CI（`.github/workflows/ci.yml` / `test.yml`）は**全ジョブが単発 shell 実行**で retry / JUnit 構造化出力 / flaky マーカーが無く、`code` / `flaky` / `environment` の**自動判別信号が事実上ない**。既定は「`record.jsonl` の manual taxonomy entry を Collector が**読むだけ**」とし、補助的に**狭い allowlist 自動分類**（`rate limit` / `ECONNRESET` / `runner has received a shutdown signal` 等の既知パターン一致時のみ `environment`）を足す。**`code` を機械が積極的に断定しない**。未該当は taxonomy を出力せず `delivery.py` の既存 fail-closed（`HUMAN_ESCALATED`）に委ねる。AC-8 が要求するのは「供給主体の機械的特定 + モジュール境界 + 単体テスト」であって分類精度の保証ではない |
| `changed_files` | (a) 手渡し / (b) **読み取り系 git allowlist で実測**（採用）/ (c) `gh api .../pulls/{n}/files` | **(b)**（R-017 反映）。`git diff --name-only <base>...<head>` を**既存の読み取り系 git allowlist**で取得する（新 endpoint を足さない = `gh api` の 4 endpoint allowlist を広げない）。**このキーは `_path_allowed()` と `deviated = [p for p in snapshot["changed_files"] if not _path_allowed(p, allowed)]` を経て `PRIORITY_ORDER` 2 位 `plan_deviation`（→ `EXEC_RETURN`）を駆動する**ため、**空リストで埋めると逸脱検知が常に無効化される（fail-open）**。取得失敗・0 件は空リストで通さず `escalation_flags` に `changed_files_unavailable:<reason>` を積む |
| `conflict_resolution` | (a) 常に出力 / (b) **三点が揃うときのみ出力**（採用）/ (c) 出力しない | **(b)**（R-017 反映）。**任意キー**（`validate_snapshot()` は `cr = snap.get(...)` / `if cr is not None and ...` で必須にしていない）。Executor の `resolve_conflict` receipt から Reconciler が `base_sha` / `head_sha` / `result_sha` の**三点を再構成し、三点が揃うときのみ出力**する。常時出力すると `cr_incomplete = isinstance(cr, dict) and not all(cr.get(k) for k in ("base_sha","head_sha","result_sha"))` → `conflict_need = True` となり **どの PR も永久に `CONFLICT`（`MERGE_READY` 到達不能）**になる |

#### `review` の縮約規則（R-018 反映）

`repos/{o}/{r}/pulls/{n}/reviews` は review を**配列**で返すが snapshot の `review` は**単一 dict**（`{state, sha}`）であり、縮約規則が無いと供給値が非決定になる。かつ `delivery.py:290` は `review_ok = review["state"] == "approved"` と **小文字**で比較するのに対し、REST の `state` は **大文字**（実測で `COMMENTED` を確認）。以下を Collector の規則として固定する:

1. `commit_id == head_sha` の review **のみ**を対象にする（旧 head の approve を採用しない）
2. 対象のうち `submitted_at` が**最新**のものを採用する
3. `DISMISSED` は**除外**する
4. `state` は `state.lower()` へ**正規化**してから snapshot に載せる（`APPROVED` → `approved`）
5. 該当ゼロなら `{"state": "none", "sha": head_sha}` を出力する（キー欠落にして `invalid_snapshot` に落とさない）
6. **ページング方針**: `per_page` を明示し全件取得する（既定ページのみだと最新 review を取りこぼす）

### 論点 D4: E2E の実現方式（U-1 / AC-4 / R-014）

| 案 | 内容 | 長所 | 短所 |
|----|------|------|------|
| **D4-A（採用 / Q2 回答）** | **fixture record/replay 主体 + 実 PR 1 周の手動実走証跡**。`tests/extras/ta-57-pr-convergence.sh` に固定シナリオ（CI 失敗 → repair → 最新 head 再評価 → MERGE_READY）を置き、`gh_exec` を fixture 注入で差し替える。実 PR 1 周は 1 回だけ手動実行し `evidence/e2e/` にログを保存 | 合格基準が機械化される（`sh tests/run-tests.sh` の一部として毎回走る）。外部依存の非決定性が CI に入らない。fixture 注入の前例あり（`test_discovery.py` の `_issue()` / ta-56 の snapshot 自前生成） | 実 API のレスポンス形状の drift は fixture では検出できない（→ 手動実走 1 周でカバー） |
| D4-B | 実 test repository を新設して CI 常設 | 実挙動を継続検証 | 認証・レート制限・後片付け・`.github/workflows/` 変更（**HO 該当**）が必要。one-off の既成事実化リスク（R-014） |
| D4-C | mock のみ | 最軽量 | 「実 PR 収束が成立する」ことを一度も示さない = EPIC #870 の close 条件 3 を満たせない |

**採用: D4-A**。実 PR は**本リポジトリの検証用ブランチ / PR を 1 本使う**（新規 test repository は作らない = Q3 の repo 設定に依存しない方針と整合）。後片付け（検証用 PR の close / branch 削除）は **Human-owned**（Executor は close も branch 削除もできない）。

### 論点 D5: AC-6（#894 Loop Control Contract 接続点）の固定方法（U-5 / agent 判断・C-3 論点）

`#894` は pbi-input のみで enum / reason code が**未確定**。(a) I/F だけ先に固定 / (b) #894 の一部確定を待つ / (c) AC-6 を #894 側へ移す の 3 案のうち **(a) を採用**する: 接続点は `escalation_flags` への **opaque な reason code 文字列の追記**という 1 点に限定し、統合テストは「Collector が積んだ reason code が `assess()` を素通しして `HUMAN_ESCALATED` に到達し `record.jsonl` に残る」ことだけを固定する（**値の語彙は #894 が決める**）。理由: (b) は P0 の close blocker を未着手 issue に従属させる / (c) は issue #917 の AC を削る。**C-3 論点として明示判断を仰ぐ**。

## Approach Overview

```text
plan.md ──(extract_allowed_paths)──┐
c3 record ──(source_sha)──┐        │
                          ▼        ▼
GitHub REST GET ──▶ collector.py ──▶ snapshot.json ──▶ delivery.py assess()（不変）
   (gh_exec.py)          │  ▲                                  │
                         │  └── ci_taxonomy.py                 │ actions(intent)
                         │  └── record.jsonl（dod_evaluated）  ▼
                         │                              executor.py ──(gh_exec.py)──▶ 実 PR
                         └────────── reconciler.py ◀── receipt（delivery.py receipt）
```

1. **`gh_exec.py`**（唯一の `subprocess` 境界 / allowlist）→ **`check_exec_boundary.py`**（AST で境界を機械強制）
2. **`collector.py`**: REST GET **3〜4 本**で snapshot を組み立てる。`gh pr view --json statusCheckRollup` は**使わない**（後述の実測理由）
   - `repos/{o}/{r}/commits/{sha}/check-runs` → `id` / `head_sha` / **`status`** / `conclusion` / `completed_at`（**AC-1 と AC-9 の両方をこれ 1 本で賄える**）
     - **`status` → `conclusion` 写像（R-019 反映・必須）**: `CHECK_PENDING = ("pending", "queued", "in_progress")` は check-run の **`status` の値**であって `conclusion` の値ではない。未完了 check-run の `conclusion` は **null** で、`validate_snapshot()` は `checks[].conclusion` に `str` を要求するため（`None` 不可 → `invalid_snapshot`）、**`status != "completed"` のときは `conclusion = status`（`queued` / `in_progress`）へ写像する**。この写像が無いと repair push 直後（check-run が queued / in_progress）に優先度 1 の `invalid_snapshot` へ落ち、**`WAITING_FOR_CHECKS` に到達せず AC-4 の「repair → 最新 head 再評価 → MERGE_READY」の 1 周が実 PR で回らない**（fixture は手書きのため乖離が隠れる）
   - `repos/{o}/{r}/pulls/{n}/reviews` → `id` / `state` / `commit_id` / `submitted_at`（`per_page` 明示・全件取得。縮約規則は D3 §`review` の縮約規則）
   - `repos/{o}/{r}/pulls/{n}` → `mergeable` / `head.sha` / `base.ref`
   - `repos/{o}/{r}/rules/branches/{base_ref}` → required checks（AC-2 / **R-022 で `rulesets/{id}` から差し替え**。複数ルールは union）
   - `changed_files` は上記 4 本ではなく**読み取り系 git allowlist**（`git diff --name-only <base>...<head>`）で取得する（D3 参照）
   - pre-check 失敗（AC-1 / AC-2 / AC-9 / 抽出 0 件 / 取得失敗）は**破棄・例外 exit せず** `escalation_flags` に理由コードを積んで `assess()` を通す（R-003）
3. **`ci_taxonomy.py`**: `record.jsonl` の manual entry を正とし、補助的に狭い allowlist 自動分類（AC-8 の供給主体 = 本モジュール）
4. **`executor.py`**: 6 種の `action_kind`（`repair_ci` / `resolve_conflict` / `repair_review` / `record_disposition` / `feedback_loop_referral` / `dod_reevaluate`）を実行。repair push は `gh_exec.push_pr_head()`、通知コメントは `repair_ci` / `repair_review` に**内包**
5. **`reconciler.py`**: intent ↔ receipt を `action_id`（`c3_contract.canonical_hash()` を**変更せず import 再利用**）で突合し、冪等を担保。`disposition` を receipt の `result_ref` convention から再構成
6. **配布 / doc**: `sync-plugin-plangate.sh` の **L345 のコピー元 for ループ**と **L355 の case 許可判定**の**両方**へ 12 本を追加。doc は `delivery-state-machine.md` §4（contract ブロック**外**）へ AC-8 供給主体を 1 文追記

### ⚠️ 設計を変えた実測: Collector の主経路は REST GET

`gh pr view --json statusCheckRollup` は **per-check の sha を持たない**（キーは `__typename` / `completedAt` / `conclusion` / `detailsUrl` / `name` / `startedAt` / `status` / `workflowName` のみ）。`latestReviews[].commit.oid` は **空文字**。したがって **AC-1（head SHA 束縛）は `gh pr view` では満たせない**。この実測により Collector の主経路を REST GET（`gh api` の GET）に確定した。

## Work Breakdown (Steps)

1. **Step 1: 境界検査器を先に作る**（`check_exec_boundary.py` TDD RED→GREEN）
   - Output: `scripts/ai-loop/check_exec_boundary.py` / `scripts/ai-loop/test_check_exec_boundary.py`
   - Owner: agent / Risk: 中
   - 🚩 チェックポイント: 現行 `scripts/ai-loop/*.py` に対し **AST 版が clean**（`discovery.py` の docstring 偽陽性が出ない）ことを実測で確認。**判定は「argv 先頭要素 不変条件（精緻化版）」＝読み取り専用 git サブコマンド allowlist（`status` / `rev-parse` / `diff` / `log` / `merge-base` / `ls-remote` / `show`）と grandfather 例外 1 件（`test_c3prime_verify.py` の `_run()`）を適用したうえで**行う。例外リストは 1 件から増えないことをテストで固定する。`delivery.py` 系の既存 substring 走査には**一切触れない**
2. **Step 2: `gh_exec.py`（TDD・negative first）**
   - Output: `scripts/ai-loop/gh_exec.py` / `scripts/ai-loop/test_gh_exec.py`
   - Owner: agent / Risk: **高**（AC-5 の中核・破壊的操作の唯一の関門）
   - 🚩 チェックポイント: allow 経路の一意性（rule table を空にすると全 allow が Denied）/ 既知禁止 9 種の検算 / 補集合の自動追随 / deny ケースで `subprocess` が一度も呼ばれない
3. **Step 3: `plan_package.extract_allowed_paths()` public 化**
   - Output: `scripts/ai-loop/plan_package.py`（抽出関数の切り出しのみ・`derive_loopspec` の挙動不変）/ `scripts/ai-loop/test_plan_package.py`
   - Owner: agent / Risk: 中
   - 🚩 チェックポイント: 既存 `test_plan_package.py` が全 PASS（`derive_loopspec` の maker/checker 検証を巻き込まない）
4. **Step 4: `ci_taxonomy.py`（AC-8）**
   - Output: `scripts/ai-loop/ci_taxonomy.py` / `scripts/ai-loop/test_ci_taxonomy.py`
   - Owner: agent / Risk: 中
   - 🚩 チェックポイント: `code` を機械が断定しない / 未該当は taxonomy を出力しない（`delivery.py` の fail-closed に委ねる）
5. **Step 5: `collector.py`（AC-1 / AC-2 / AC-9 / D3）**
   - Output: `scripts/ai-loop/collector.py` / `scripts/ai-loop/test_collector.py`
   - Owner: agent / Risk: **高**（snapshot 供給者責務・fail-closed 設計）
   - 🚩 チェックポイント: pre-check 失敗が **`escalation_flags` 経路**であり例外 exit しないこと / `validate_snapshot()` の **必須 12 キー**（`task_id` / `pr_number` / `head_sha` / `source_sha_ancestry` / `mergeable` / `checks` / `review` / `findings` / `changed_files` / `allowed_paths` / `escalation_flags` / `dod_evaluated`）を埋めること / **`conflict_resolution` は任意キーであり三点（`base_sha` / `head_sha` / `result_sha`）が揃うときのみ出力すること**（R-026）
     - > ⚠️ `pbi-input.md` の「必須 13 キー」は**誤り**（正: **必須 12 + 任意 `conflict_resolution` 1**）。`pbi-input.md` は main マージ済みのため訂正せず、**本 plan の記述を正とする**。13 キーを常に埋める実装にすると `cr_incomplete` → `conflict_need = True` で**どの PR も永久に `CONFLICT`** になる
6. **Step 6: `executor.py`（AC-3 / R-005 通知）**
   - Output: `scripts/ai-loop/executor.py` / `scripts/ai-loop/test_executor.py`
   - Owner: agent / Risk: **高**（唯一の外部書き込み層）
   - 🚩 チェックポイント: 新 `action_kind` を作っていない / コメント失敗を握り潰さない / receipt に comment URL を記録
7. **Step 7: `reconciler.py`（AC-3 冪等 / D3 findings 再構成）+ AC-6 接続点の統合テスト**
   - Output: `scripts/ai-loop/reconciler.py` / `scripts/ai-loop/test_reconciler.py`（**AC-6 の接続点統合テスト TC-12 / TC-13 を含む** — R-023 反映）
   - Owner: agent / Risk: 中
   - 🚩 チェックポイント: `canonical_hash()` を import 再利用（独自実装ゼロ）/ 同一 `action_id` の再実行で二重作用しない / **AC-6（opaque reason code の素通し・state entry の残存）を実際に書いたテストで検証していること**（test-cases が AC-6 に TC を割り当てているのに実装タスクが 0 件、という状態を作らない）
8. **Step 8: E2E fixture シナリオ + 新規 unit test の実行導線 + AC-7 回帰**
   - Output: `tests/extras/ta-57-pr-convergence.sh`
   - Owner: agent / Risk: 中
   - **新規 unit test の実行導線（R-020 反映・必須）**: `tests/run-tests.sh` は python を一切呼ばず `$EXTRAS_DIR` の `ta-*.sh` を glob source するだけで、`test_plan_package.py` は ta-55 / ta-56 から **fixture helper（`import plan_package, test_plan_package as tpp`）としてのみ import され、テスト本体は一度も実行されていない**。したがって ta-56 / ta-55 の前例どおり `ta-57-pr-convergence.sh` に **`python3 <root>/scripts/ai-loop/test_*.py` を 7 本**（`test_gh_exec.py` / `test_check_exec_boundary.py` / `test_collector.py` / `test_ci_taxonomy.py` / `test_executor.py` / `test_reconciler.py` / **`test_plan_package.py`**）**1 モジュール 1 PASS 行**で追加する。これが無いと Stop Condition の「全成功」が新規 6 本に対して**空振り**する
   - 🚩 チェックポイント: `sh tests/run-tests.sh` クリーン exit 0（**baseline 430 + 新規 PASS 行数 7 = 最低 437 を下回らない**）/ 7 本すべてが PASS 行として出力に現れること / AC-7 の 3 点（差分 0 行 / 57 テスト / contract byte 一致）を ta-57 側でも再確認
9. **Step 9: 実 PR 1 周の手動実走証跡（AC-4 / Q2）**
   - Output: `docs/working/TASK-0917/evidence/e2e/`（実行ログ・手動実行手順）
   - Owner: agent（実行）/ human（検証用 PR の後片付け）/ Risk: 中
   - 🚩 チェックポイント: **実 PR に対する書き込みは repair push とコメントのみ**であることをログで確認。close / branch 削除は行わない
10. **Step 10: 配布同期（R-011）**
    - Output: `scripts/sync-plugin-plangate.sh`（**L345 と L355 の 2 箇所**）+ `plugin/plangate/` 再生成
    - Owner: agent / Risk: 中（片方漏れ = sync drift）
    - 🚩 チェックポイント: sync 2 回目 no-op / `git diff --quiet plugin/` / **2 箇所の列挙が同一集合**であることを機械照合
11. **Step 11: doc 追記 + stale 是正**
    - Output: `docs/workflows/ai-loop/delivery-state-machine.md` §4 へ **計 5 文**を additive 追記 / `tests/extras/ta-56-delivery.sh` L29 の「51 テスト」→「57 テスト」 / `docs/workflows/ai-loop/execution-runbook.md`（D2-B を多層防御の補助として記載 — R-024）
      - §4 追記の 5 文（R-024 / R-027 反映）:
        1. AC-8（`ci_failure_taxonomy`）の**供給主体**は `ci_taxonomy.py`
        2. AC-5 の **scope 限界**（in-process allowlist は Executor 経路のみを守る）
        3. **AC-9 の限界**（Collector が生成した snapshot の内部整合まで。**手作り snapshot を `delivery.py` へ直接投入する経路は塞がない**）
        4. required check 集合の **⊇ 照合は Collector pre-check として Phase 1 で実装済み**（`escalation_flags` 経由。`required_checks[]` の**フィールド化**は引き続き V2）
        5. **branch protection 側は現状 `required_approving_review_count: 0` のため後段防衛として当てにしない**（Q3 起票 issue #928 参照）
      - ※ 4. / 5. は §4 の現行記述「required checks の機械束縛は V2 候補。Phase 1 の後段防衛は C-4 Human レビュー + branch protection」が本 PBI で **stale 化する**ことへの是正（R-027）
      - ※ AC-9 の限界の記載先は **§4（doc）と handoff と実装 docstring** で統一する（plan 冒頭 Q1 帰結・test-cases の AC-9 注記と同一）
    - Owner: agent / Risk: 低
    - 🚩 チェックポイント: `<!-- contract:begin/end -->` ブロックを**触っていない**こと（`cmp -s` PASS）/ 追記が §4 の 5 文すべてを含むこと
12. **Step 12: 敵対レビュー R1 / R2**
    - Output: `docs/working/TASK-0917/evidence/`（レビュー記録・是正 commit）
    - Owner: agent / Risk: 中
    - 🚩 チェックポイント: **外部作用層は 1 ラウンドでは表層しか出ない**（#889 教訓）— critical / major ゼロ収束まで
13. **Step 13: AC-1〜AC-9 突合**
    - Output: `docs/working/TASK-0917/`（V-1 入力）
    - Owner: agent / Risk: 低
    - 🚩 チェックポイント: `test-cases.md` の全 TC を機械実行して PASS
14. **Step 14: 👤 C-3 / 👤 C-4**
    - Output: `docs/working/TASK-0917/approvals/c3.json`（Human 発行）
    - Owner: human / Risk: —
    - 🚩 チェックポイント: 下記 Questions / Unknowns の **10 件**を明示判断

## Files / Components to Touch

| # | ファイル | 種別 |
|---|---------|------|
| 1 | `scripts/ai-loop/gh_exec.py` | 新設（唯一の subprocess 境界 / allowlist） |
| 2 | `scripts/ai-loop/test_gh_exec.py` | 新設 |
| 3 | `scripts/ai-loop/check_exec_boundary.py` | 新設（AST 境界検査器） |
| 4 | `scripts/ai-loop/test_check_exec_boundary.py` | 新設 |
| 5 | `scripts/ai-loop/collector.py` | 新設（AC-1 / AC-2 / AC-9） |
| 6 | `scripts/ai-loop/test_collector.py` | 新設 |
| 7 | `scripts/ai-loop/ci_taxonomy.py` | 新設（AC-8 供給主体） |
| 8 | `scripts/ai-loop/test_ci_taxonomy.py` | 新設 |
| 9 | `scripts/ai-loop/executor.py` | 新設（唯一の外部書き込み層） |
| 10 | `scripts/ai-loop/test_executor.py` | 新設 |
| 11 | `scripts/ai-loop/reconciler.py` | 新設（AC-3 冪等） |
| 12 | `scripts/ai-loop/test_reconciler.py` | 新設 |
| 13 | `tests/extras/ta-57-pr-convergence.sh` | 新設（E2E fixture シナリオ） |
| 14 | `scripts/ai-loop/plan_package.py` | 改変（`extract_allowed_paths` public 化のみ） |
| 15 | `scripts/ai-loop/test_plan_package.py` | 改変（public 化のテスト追加） |
| 16 | `tests/extras/ta-56-delivery.sh` | 改変（L29「51 テスト」→「57 テスト」の 1 行是正） |
| 17 | `scripts/sync-plugin-plangate.sh` | 改変（**L345 の for ループ + L355 の case の 2 箇所**） |
| 18 | `docs/workflows/ai-loop/delivery-state-machine.md` | 改変（§4 に **5 文** additive。**contract ブロックは不変**） |
| 19 | `docs/workflows/ai-loop/execution-runbook.md` | 改変（D2-B を多層防御の**補助**として記載。R-024 — 宣言した doc 更新先を `allowed_paths` に含める） |
| 20 | `plugin/plangate/` | sync 自動再生成 |
| 21 | `docs/working/TASK-0917/` | 本 PBI の作業成果物（plan / todo / test-cases / status / handoff / evidence） |

> ⚠️ **本節はバッククォート囲みのパスが `plan_package.py` の `_PATH_RE` で機械抽出され `allowed_paths` を駆動する**。以下の 2 つの注記では、許可対象に混入させないため意図的にバッククォートを使わない。
>
> **不変（AC-7 / 触ってはいけない）**: scripts/ai-loop/delivery.py ・ scripts/ai-loop/c3\_contract.py ・ scripts/ai-loop/c3prime\_verify.py ・ delivery-state-machine.md の `<!-- contract:begin/end -->` ブロック
>
> **tests/run-tests.sh の改変は不要**（実測: `$EXTRAS_DIR`/ta-\*.sh を for ループで glob source する箇所が実体。**行番号ではなく記号アンカー（`if [ -d "$EXTRAS_DIR" ]` 直下の `for extra in "$EXTRAS_DIR"/ta-\*.sh` ）で参照する** — R-028。TASK-0873 も ta-56 追加時に run-tests.sh を触っていない）
>
> **ただし glob source は「ta-\*.sh を拾う」だけで python の unit test は起動しない**。新規 6 本 + `test_plan_package.py` の実行導線は **ta-57 側に明示追加する**（Step 8 / R-020）

## Metrics Evidence（事前メトリクス検証 / mandatory gate）

| 対象 | 実数（実測コマンド） | AI 見積もり | ratio | 判定 |
|------|---------------------|------------|-------|------|
| 触るファイル数（手作業・plugin / working 除く） | **19**（上表 #1〜#19。R-024 で `execution-runbook.md` を追加） | 12（`review-external.md` §Mode 妥当性の「9〜12 本」） | **1.58** | 採用。1〜3 倍のため Risks に記録（sync 列挙 12 本 ×2 箇所の drift リスク） |
| `sh tests/run-tests.sh`（baseline） | **430 passed / 0 failed / exit 0**（本セッションで実測） | — | — | 新規 unit test の PASS 行 **7 本**（R-020）を ta-57 に足すため、**完了時は 437 を下回らない**ことを Stop Condition に置く |
| `python3 scripts/ai-loop/test_delivery.py`（AC-7 baseline） | **`Ran 57 tests ... OK` / exit 0** | — | — | TASK-0873 handoff の「51」は **stale**。正は **57**（ta-56 L29 も是正対象） |
| `git diff --stat origin/main -- scripts/ai-loop/delivery.py scripts/ai-loop/c3_contract.py scripts/ai-loop/c3prime_verify.py` | **0 行**（出力なし / exit 0） | — | — | AC-7 の baseline。exec 完了時も 0 行であること |
| `required_checks` のコード実装 | **0 件**（`grep -rn "required_check" scripts/ --include='*.py'` の行数） | — | — | greenfield（既存実装の改修ではない） |
| `repair_commit` / `dod_evaluated` の **producer** | **0 件**。`grep -rln` の HIT は `scripts/ai-loop/delivery.py` / `scripts/ai-loop/test_delivery.py` / 正本 doc（`delivery-state-machine.md`）/ **`tests/extras/ta-56-delivery.sh`** / **`plugin/plangate/skills/ai-loop-cycle/` の mirror 3 本** / TASK-0873 の docs / 本 PBI の docs（R-028 で HIT 一覧を補完。**いずれも consumer or 記述であり結論「producer 0 件」は不変**） | — | — | D3 の「producer 新設が必要」判断の根拠 |
| required status checks（AC-2 の取得元） | **1 件**（`Markdown lint`）。`gh api repos/s977043/plangate/rules/branches/main --jq '[.[] \| select(.type=="required_status_checks") \| .parameters.required_status_checks[].context]'` → `["Markdown lint"]` / **exit 0**（R-022 で `rulesets/{id}` から差し替え・ruleset id 不要） | — | — | AC-2 の ⊇ 照合対象。1 件しかないため負側テストは fixture で作る |
| 新規 extras の CI 配線 | **不要**（`tests/run-tests.sh` は `if [ -d "$EXTRAS_DIR" ]` 直下の `for extra in "$EXTRAS_DIR"/ta-*.sh` で glob 自動 source。**記号アンカーで参照**。R-028 で「L155-160」を訂正 — 当該行は**コメント行**で、実体は `PG_HARNESS_SOURCED=1` の直後の `if`/`for` 2 行） | 1 ファイル改変 | 0 | Files から `tests/run-tests.sh` を除外（Mode は他要因で critical のため据え置き） |
| `scripts/ai-loop/test_*.py` の実行導線 | **0 本**（`tests/run-tests.sh` は python を呼ばない。`test_plan_package.py` は ta-55 / ta-56 から `import ... as tpp` の **fixture helper としてのみ** import され本体は未実行） | — | — | R-020 の根拠。ta-57 に **7 本**の `python3 .../test_*.py` を追加する |

## Testing Strategy

- **Unit**
  - `test_gh_exec.py`: allowlist の正側 / 負側（T-A〜T-H 相当・`test-cases.md` TC-20〜TC-30。**TC-31 / TC-31b は `test_check_exec_boundary.py` の担当**）。**deny ケースで `subprocess` が一度も呼ばれない**ことを monkeypatch で固定
  - `test_check_exec_boundary.py`: 現行ツリーに対する clean 判定 / 違反注入で FAIL / `test_*.py` の argv 先頭要素 不変条件（**精緻化版**: `sys.executable` または読み取り専用 git サブコマンド allowlist）/ **grandfather 例外リストが 1 件から増えないことの固定**（負側）/ **argv が静的追跡不能なら例外リスト外は FAIL（fail-closed）**（`test-cases.md` TC-31 / TC-31b）
  - `test_collector.py`: fixture 注入（`gh_exec` を差し替え）で snapshot 組み立て・pre-check・AC-9 自己照合
  - `test_ci_taxonomy.py`: manual entry 優先 / 自動 allowlist / 未該当は出力なし
  - `test_executor.py`: 6 action_kind / 通知内包 / 失敗時の escalation
  - `test_reconciler.py`: intent↔receipt 突合 / 冪等 / disposition 再構成
- **Integration**: Collector → `delivery.py assess()` → Executor → `delivery.py receipt` → Reconciler の 1 周を **fixture 上で**通す（`delivery.py` は実物を呼ぶ）
- **E2E**: `tests/extras/ta-57-pr-convergence.sh`（CI 失敗 → repair → 最新 head 再評価 → MERGE_READY）+ AC-7 の 3 点再確認
- **手動 E2E（AC-4 / 1 回のみ）**: 実 PR 1 周。手順と実行ログを `docs/working/TASK-0917/evidence/e2e/` に保存
- **Edge cases**: rate limit / timeout / shallow clone で ancestry 解決不能 / `plan.md` からの `allowed_paths` 抽出 0 件 / `record.jsonl` 破損 / required checks 取得 403
- **Verification Automation**（R-020 反映 / 新規 unit test を空振りさせない）:
  - `python3 scripts/ai-loop/test_delivery.py`（AC-7 baseline・57 tests）
  - **ta-57 から起動する 7 本**（1 モジュール 1 PASS 行）: `python3 scripts/ai-loop/test_gh_exec.py` / `test_check_exec_boundary.py` / `test_collector.py` / `test_ci_taxonomy.py` / `test_executor.py` / `test_reconciler.py` / **`test_plan_package.py`**
  - `python3 scripts/ai-loop/check_exec_boundary.py`
  - `sh tests/run-tests.sh`（上記 7 本の PASS 行を含む。**437 を下回らない**）

## Loop Scope

単一 PBI（TASK-0917）の exec 内における「テスト失敗 → 自己修正」の反復のみ。Collector / Executor / Reconciler が扱う **PR 収束ループはプロダクト仕様**であり本 plan の Loop ではない。

## Stop Condition

変更が Files / Components to Touch 内 / Verification Automation が全成功（`sh tests/run-tests.sh` exit 0 かつ **「baseline 430 + 新規 PASS 行数」を下回らない**）/ AC-1〜AC-9 の全 TC が PASS / 敵対レビュー critical・major ゼロ収束 / 残課題は handoff に明示。

> **数え方（R-020 反映）**: baseline = 430（本セッション実測）。新規 PASS 行数 = ta-57 が追加する `python3 .../test_*.py` の **1 モジュール 1 PASS 行 × 7 本** + ta-57 の fixture E2E シナリオが出す PASS 行。したがって **最低 437**（= 430 + 7）を閾値とし、これを下回ったら Stop。「430 を下回らない」だけでは新規 6 本が 1 本も実行されていなくても通ってしまうため、**下限を 437 に引き上げる**。

## Resume Condition

stop 後の再開は、原因・修正方針・検証手順を本 plan に追記し Replan 判定を通す。**外部作用（実 PR への push / コメント）を伴う Step 9 の再開は、直前の receipt を確認してから**（冪等の前提）。

## Replan Triggers

- 変更ファイル数 > **24**（= 想定 19 + 5。R-024 で `execution-runbook.md` を追加したことに伴う再計算）
- 同一検証コマンドの連続失敗 3 回
- 同一ファイルへの修正反復 3 回
- plan 外ディレクトリへの波及 1 件（特に `.github/workflows/` / `bin/plangate` / `schemas/` / `.claude/**` の必要性が判明した時点で**即停止**。いずれも HO 該当）
- `delivery.py` / `c3_contract.py` / `c3prime_verify.py` への変更が必要と判明した時点で**即停止**（AC-7 / Out of scope の改訂は C-3 再承認事項）
- required checks の取得に **repo admin 権限が必須**と判明し、想定実行主体で取得できない場合
- #894 / #916 が先に merge され接続前提が変わった場合

## Revert Policy（critical / 段階的ロールバック）

| Level | 対象 | 手順 | 判断者 |
|-------|------|------|--------|
| **L1** | Scope 内の単一ファイルの誤変更 | `git restore -- <path>`（ブランケットな `git stash` は使わない） | agent |
| **L2** | 外部作用層の無効化（Executor だけ止めたい） | `gh_exec.py` の **allowlist テーブルを空にする**（設計上、空テーブル = 全 deny。TC-20 で保証）→ Collector / Reconciler は読み取りのみで継続可能 | agent |
| **L3** | 実 PR へ既に加えた作用の巻き戻し | repair push は **revert commit を積んで戻す**（`--force*` / branch 削除は禁止のまま）。コメントは**削除せず訂正コメントを追記**（`--delete-last` は allowlist 外）。receipt に巻き戻しを記録 | agent（実行）/ human（承認） |
| **L4** | PBI 全体の撤回 | feature branch を破棄し `docs/working/TASK-0917/` に無効化を明記。**PR の close は Human-owned** | human |
| **L5** | 検証用 PR / branch の後片付け | close / branch 削除は **Human-owned**（Executor は原理的に実行できない） | human |

Loop Attempts:（exec 中に追記）

- attempt: / changed: / verification: / result: / next decision:

## Risks & Mitigations

| リスク | 検証手段 | Fallback |
|--------|---------|---------|
| Executor が `gh pr merge` を発行する（**NO MERGE BY AI 違反 / 最重大**） | `gh_exec.py` の allowlist（補集合で自動 deny）+ 既知禁止 9 種の検算 TC + 補集合の自動追随 TC + AST 境界検査器 | L2（allowlist テーブルを空に）→ Executor 経路を完全停止 |
| **in-process allowlist はプロセス外を守れない**（同一セッションの Bash / 別プロセス） | 設計上回避不能。AC-5 の scope を「Executor 経路のみ」と plan / handoff / doc に明示 | 規範層（`.claude/rules/`）+ C-4 Human レビュー。多層防御の物理層は Q3 起票 issue 側 |
| Collector が head SHA 束縛を破り古い check で MERGE_READY | `checks[].sha` / `review.sha` を `head_sha` と照合（AC-1 TC）。**`gh pr view --json statusCheckRollup` は per-check sha を持たないので使わない**（実測） | 不一致は `escalation_flags` へ（正本 §4 の stale = `WAITING_FOR_CHECKS` は `delivery.py` 側が担う） |
| 部分登録 green（required check 未登録の瞬間） | AC-2 の ⊇ 照合 pre-check + 負側 TC | 取得失敗は `required_checks_fetch_failed:<reason>` で fail-closed（config fallback を入れない） |
| **required checks の取得に repo admin 権限が要るか未確認** | 非 admin トークンで反証していない（Unknowns に残す） | 取得失敗 = fail-closed なので安全側に倒れる。恒常的に取得できないなら Replan Trigger |
| repair push が C-4 承認を stale にする（`dismiss_stale_reviews_on_push: false` 実測） | R-005 案② 明示通知コメント（`repair_ci` / `repair_review` に内包）+ receipt に comment URL 記録 | コメント投稿失敗は握り潰さず `escalation_flags` へ |
| `delivery.py` に手を入れてしまう | AC-7 の 3 点（差分 0 行 / 57 テスト / contract byte 一致）を ta-57 と CI 双方で機械検証 | 検知即 `git restore -- scripts/ai-loop/delivery.py` + Replan |
| sync 列挙の片方漏れ（**L345 / L355 の 2 箇所**・新規 12 本） | 2 箇所の列挙が同一集合であることを機械照合する検証タスク（**todo T-39**。R-028 で T-30（= `reconciler.py` 実装）からの誤参照を訂正）+ sync 2 回目 no-op | 漏れ検知時は両方へ追加し `git diff --quiet plugin/` を再確認 |
| **新規 unit test 6 本が一度も実行されない**（`run-tests.sh` は python を呼ばず extras の `ta-*.sh` を glob source するだけ） | ta-57 に 7 本の `python3 .../test_*.py` を明示追加（R-020）+ Stop Condition の下限を **437** に引き上げ | 7 本の PASS 行を出力から grep して不足を検出。不足時は ta-57 を是正するまで Stop |
| **`changed_files` を空リストで埋めて逸脱検知が fail-open 化**（`plan_deviation` が常に不発） | `changed_files` を読み取り系 git で実測（R-017）+ 取得失敗は `changed_files_unavailable:<reason>` で fail-closed + 空リスト時の負側 TC | 空のまま `assess()` に渡さない（`escalation_flags` 経由で `HUMAN_ESCALATED`） |
| **`conflict_resolution` を常時出力して恒久 `CONFLICT`**（`cr_incomplete` → `conflict_need = True` で `MERGE_READY` 到達不能） | 三点（`base_sha` / `head_sha` / `result_sha`）が揃うときのみ出力（R-026）+ 「conflict 未発生時はキー自体を出さない」TC | 出力を止めれば任意キーのため `assess()` は素通しする |
| **未完了 check-run の `conclusion` が null で `invalid_snapshot`**（repair 直後に `WAITING_FOR_CHECKS` へ到達できず AC-4 の 1 周が実 PR で回らない） | `status != "completed"` → `conclusion = status` の写像（R-019）+ 「in_progress が `WAITING_FOR_CHECKS` に倒れる」TC | 写像が無いまま実 PR で詰まった場合は Replan（fixture は手書きのため乖離が隠れる点に注意） |
| `ci_failure_taxonomy` の自動分類が誤る（`code` の誤断定） | `code` を機械が断定しない設計 + 未該当は出力せず既存 fail-closed に委ねる（TC-17〜19） | manual entry を正とする（人間 or 別層が明示） |
| GitHub API の rate limit / 一時障害で不完全な snapshot | 取得失敗は例外を握り潰さず `escalation_flags` へ（fail-closed）。**リポジトリ内に既存 backoff 実装は無い**ため retry は最小限（固定回数）に留める | 失敗のまま `HUMAN_ESCALATED` に倒す（誤 MERGE_READY より安全） |
| shallow clone で `merge-base --is-ancestor` が解決不能 | 明示 fetch の前処理 + exit code 3 値判定（0/1/その他→`None`） | `None` は `delivery.py` 側で `source_sha_ancestry is not True` → `HUMAN_ESCALATED` |
| `plan.md` から `allowed_paths` が 0 件抽出（書式崩れ） | Collector で 0 件を検出し `escalation_flags` へ | `plan_package.derive_loopspec()` と同じ失敗理由文言を再利用 |
| 実 PR 手動 E2E が one-off の既成事実化になる（R-014） | 機械化された合格基準は fixture E2E（ta-57）側に置き、手動実走は**証跡**として位置づける | 手順書を `evidence/e2e/` に残し再実行可能にする |
| 実装規模が見積り超過（19 本 / ratio 1.58） | Replan Trigger（**> 24 本**） | モジュール統合（`ci_taxonomy.py` を `collector.py` へ吸収する等）を C-3 で相談 |

> **V2 候補（handoff へ記録）**:
>
> 1. `ta-56-delivery.sh` L27-29 は `python3 test_delivery.py` の**終了コードのみ**を見て「51 テスト」というラベルを**ハードコード出力**する。本 PBI では 51→57 の静的是正に留めるが（scope 据え置き）、**将来また乖離する構造が残る**ため「テスト件数ラベルの動的抽出」を V2 候補として handoff に記録する（R-033）。
> 2. `test_c3prime_verify.py` の `args = ["python3", ...]` を `sys.executable` へ移行する（D2-A の「`test_*.py` の argv 先頭要素 不変条件（精緻化 / C-1 F-1 の裁定）」で凍結した grandfather 例外 1 件の解消）。**本 PBI では触らない**（`allowed_paths` を増やさないため）。V2 候補として handoff に記録する。

## Questions / Unknowns（→ C-3 論点・10 件）

1. **D1-A の採否**: `required_checks[]` ⊇ 照合を **Collector 側 pre-check + `escalation_flags`** に限定すること（`delivery.py` へ分岐を足す D1-B を選ぶ場合は Out of scope 改訂と AC-7 緩和が必要）
2. **D2-A の採否と AC-5 の scope 限定**: 「in-process allowlist は **Executor 経路のみを守る**」という限界を受け入れるか。プロセス外（Bash / 別プロセス）は規範層 + C-4 に残る
3. **R-005 案②（明示通知コメント）の採否 + 外部作用の実行順序（R-021 反映）**: dismiss（案①）は Out of scope に二重抵触するため不採用としたが、「承認済みコードと merge されるコードの不一致」を通知だけで許容してよいか。あわせて **「通知コメントを repair push より先に打つ」順序**（中断時の残骸を可逆な「余分なコメント 1 件」に限定する代わりに、push しない run でもコメントが残りうる）と、**Executor の実行前 pre-check（`expected_parent_sha` が既に PR head の祖先なら skip）** を承認するか。**不可逆な外部作用の順序は Human 判断事項**として明示判断を仰ぐ
4. **AC-9 の縮小実施（Q1 回答）の追認**: 「同梱 + Collector 内自己照合」まで。**手作り snapshot を `delivery.py` へ直接投入する経路は塞がない**という限界の明示承認
5. **D5（AC-6 の I/F 先行固定）の採否**: `escalation_flags` への opaque reason code 追記 1 点に限定し、語彙は #894 に委ねる
6. **D3 の `findings[]` 供給（receipt `result_ref` の convention 利用）の採否**: `adopted:<sha>` / `rejected:<path>` という**文字列規約**で `disposition` を再構成する設計（`delivery.py` を変えないための妥協）
7. **D4-A の採否と実 PR の選定**: 本リポジトリの検証用 PR を 1 本使う（新規 test repository を作らない）。後片付け（close / branch 削除）が Human-owned であることの承認
8. **未確認事項の受容**: `gh api repos/{o}/{r}/rules/branches/{base_ref}` の取得に **repo admin 権限が必須かどうかを非 admin トークンで反証していない**（R-022 で `rulesets/{id}` から差し替え済み。`rules/branches` は ruleset id を要さない分だけ前提は軽い）。取得失敗時は fail-closed に倒れる設計だが、恒常的に取得できない環境では AC-2 が常時 escalate になる
9. **Executor の実行主体（U-8 / R-030 反映）**: Executor の実行主体を **`gh` 認証済みの手元環境（人間起動）に固定**し、**CI 実行は本 PBI の scope 外**とすることの承認。実 PR 手動実走（T-35）の前提に `gh auth status` による active account 確認を置く。pbi の再利用資産表が挙げた `scripts/gh-s977043.sh` / `scripts/gh-pin-account.sh`（active account 強制切替）は**本 PBI の設計には組み込まない**（Files にも含めない）
10. **外部書き込み層の plugin 配布同梱の可否（R-032 反映）**: 新規 12 本を `sync-plugin-plangate.sh` の whitelist に足して **plugin 配布へ同梱する**方針（`delivery.py` を既に配布している前例と一貫・carve-out で保護される）でよいか。**同梱すると `executor.py` / `gh_exec.py`（唯一の外部書き込み層）が下流リポジトリに渡る**。なお `sync-plugin-plangate.sh` の drift-check CI は「sync 実行後に diff が無いこと」しか見ないため、**whitelist に足さなくても CI は通る**＝配布は必須ではなく**選択**である（C-3 判断事項）

## Mode判定

**モード**: critical

**判定根拠**:

- **受入基準数: 9 件**（AC-1〜9）→ 高（6-10）
- **変更ファイル数: 19**（手作業・plugin / working 除く。R-024 で `execution-runbook.md` を追加）→ **超高（16+）**
- タスク数（見込み）: 21+（`todo.md` **実数 50**。`grep -oE 'T-[0-9]+' todo.md | sort -u | wc -l` = 50・T-1〜T-50 欠番なし。R-028 で「32」を訂正 — `decision-log.jsonl` は当時 48 と記録しており **plan 本文だけが自己矛盾**していた。C-2 反映で R-023 / R-024 由来の 2 タスクが増え 48 → 50）→ **超高**
- 変更種別（定性が支配的）:
  - **リポジトリに初めて「外部作用を実行する層」を導入する**（現状 ai-loop は全て純判定器 + ファイル I/O のみ）
  - 実 GitHub API への**書き込み**（repair push / コメント）を伴い、**副作用の巻き戻しが容易でない**（Revert Policy L3 が必要）
  - **承認境界の隣接**（`gh pr review --approve` は `MERGE_READY` の load-bearing 入力。sockpuppet 承認の経路を構造的に塞ぐ設計が本 PBI の中核）
  - E2E 基盤が新規（fixture record/replay + 実 PR 手動実走）
- **前例との一貫性**: 接続先を作った **TASK-0873 は Mode=critical**（`docs/working/TASK-0873/plan.md`「critical（定量・定性の最大値）。V-4 実行対象・人間 C-3 詳細レビュー必須」）。本 PBI はそれに**外部作用を足す上位互換のリスク**を持つため、critical を下回ることはない
- **最終判定**: **critical**（定量・定性の最大値）。**V-4 リリース前チェック実行対象・人間 C-3 詳細レビュー必須**

**lite_eligible**: **false**（critical は原則 false — `mode-classification.md` AC-11。autonomous APPROVE 不可・Human C-3 必須）

**carve-out**: 本 PBI の成果物は **rollout-policy §2 判定基盤 carve-out ①（`scripts/ai-loop/**`）②（`docs/workflows/ai-loop/**`）に該当**するため、**ai-loop で自走させる場合は escalate 固定**（auto-approve 対象になり得ない）。#916 の機械強制が入るまでは規範層（実行者が escalate する責務）で担保する。

**HO 該当性**: **非該当**（`scripts/ai-loop/**` / `tests/extras/**` / `docs/workflows/ai-loop/**` / `scripts/sync-plugin-plangate.sh` / `plugin/**` はいずれも `check-plan-hash.sh` の 9 カテゴリ外）。**`.github/workflows/` を触る必要が生じた時点で HO 該当となるため即停止**（Replan Trigger）。
