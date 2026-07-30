# TEST CASES — TASK-0917

> plan: [`plan.md`](./plan.md) / todo: [`todo.md`](./todo.md)
> **AC-1〜AC-9 は全件が最低 1 TC でカバーされる**（下表）。`delivery.py` は実物を呼び、**一行も変更しない**（AC-7）。

## 受入基準 → テストケース マッピング

| 受入基準 | テストケース ID | 種別 |
|---------|----------------|------|
| **AC-1** snapshot が head SHA に束縛（`checks[].sha` / `review.sha` = `head_sha`） | TC-01, TC-02, TC-03 | Unit |
| **AC-2** `required_checks[]` ⊇ 照合で部分登録 green を拒否 | TC-04, TC-05, TC-06 | Unit |
| **AC-3** intent → 実行 → receipt → reconcile が冪等 | TC-07, TC-08, TC-09, TC-09b | Unit / Integration |
| **AC-4** 実 PR の repair E2E が 1 周通る | TC-10（fixture・機械化された合格基準）, TC-11（実 PR 手動実走の証跡）, TC-39（未完了 check-run の写像。**これが無いと repair 直後に `invalid_snapshot` へ落ち 1 周が実 PR で回らない**） | E2E / Unit |
| **AC-5** 破壊的操作を実行する経路が存在しない | TC-20〜TC-31, TC-31b, TC-31c | Unit |
| **AC-6** #894 Loop Control Contract との接続点 | TC-12, TC-13 | Integration |
| **AC-7** `delivery.py` / `c3_contract.py` / `c3prime_verify.py` が不変 | TC-14, TC-15, TC-16 | E2E |
| **AC-8** `ci_failure_taxonomy` の供給元が機械的に特定できる | TC-17, TC-18, TC-19 | Unit |
| **AC-9** raw check evidence を同梱し `checks[]` の導出を機械照合 | TC-32, TC-33, TC-34 | Unit |
| （AC 横断）**snapshot 供給契約の健全性**（C-2 反映 / R-017・R-018・R-019・R-026 + River Review 反映 / **R-034**） | TC-35, TC-36, TC-37, TC-38, TC-39, TC-40 | Unit / Integration |

## AC-1: head SHA 束縛（Collector）

### TC-01: 全 check が head SHA に束縛される（正側）+ `review` の縮約規則（R-018）

- 前提条件: `repos/{o}/{r}/commits/{sha}/check-runs` fixture（全 `head_sha` = `H1`）
- 入力: PR head = `H1`
- 期待出力: snapshot の `checks[].sha` が全件 `H1`。`review.sha` は `reviews[].commit_id` 由来で `H1`
- 種別: Unit

**追加ケース（R-018 / `review` 配列 → 単一 dict の縮約）**:

| # | 入力 | 期待出力 |
|---|------|---------|
| TC-01a | `reviews[]` に `{"state": "APPROVED", "commit_id": H1}`（**大文字**） | snapshot の `review.state` = **`"approved"`**（`state.lower()` 正規化。`delivery.py:290` は `review["state"] == "approved"` と**小文字**で比較するため、正規化しないと恒久的に `review_ok = False`） |
| TC-01b | `reviews[]` に `commit_id = H1` の review が複数（`COMMENTED` → `APPROVED` の順で `submitted_at` 昇順）+ `DISMISSED` 1 件 | `submitted_at` が最新の非 `DISMISSED` review 1 件へ縮約され `review.state` = `"approved"`。`DISMISSED` は候補から除外される |
| TC-01c | `reviews[]` に `{"state": "APPROVED", "commit_id": H0}`（**旧 head**）のみ | **旧 head の APPROVED を採用しない**。`review` = `{"state": "none", "sha": H1}`（キー欠落にせず `invalid_snapshot` に落とさない）→ `review_ok = False` |

### TC-02: 旧 head の check-run が混入した場合（負側）

- 前提条件: check-run fixture に `head_sha = H0`（旧）が混在
- 入力: PR head = `H1`
- 期待出力: `H0` 由来の要素を `checks[]` に**採用しない**。結果として `delivery.py` 側で `WAITING_FOR_CHECKS`（正本 §4 の stale 規定に従う。`HUMAN_ESCALATED` を要求しない = AC-7 と整合）
- 種別: Unit

### TC-03: `gh pr view --json statusCheckRollup` を経路に使っていない（設計固定）

- 前提条件: `collector.py` 実装済み（ソースの静的検査のみで外部 API を呼ばない）
- 入力: `collector.py` ソース
- 期待出力: `statusCheckRollup` / `latestReviews` を snapshot 生成の経路に使っていない。**根拠を docstring に明記**（実測: statusCheckRollup は per-check の sha を持たず `latestReviews[].commit.oid` は空文字のため AC-1 を満たせない）
- 種別: Unit

## AC-2: `required_checks[]` ⊇ 照合

### TC-04: 部分登録 green（負側 / 本 AC の中核）

- 前提条件: ruleset fixture の required checks = `["A", "B"]`
- 入力: snapshot の `checks[]` = `[{name: "A", conclusion: "success"}]`（`B` が未登録）
- 期待出力: Collector が `escalation_flags` に `required_checks_missing:B` を積む → `assess()` が **`HUMAN_ESCALATED`**（`PRIORITY_ORDER` 上 `escalation_flags` は 3 位で `checks[]` 評価より先に短絡する）。**`MERGE_READY` にならない**
- 種別: Unit

### TC-05: 全件登録済み（正側）

- 前提条件: ruleset fixture の required checks = `["A", "B"]`
- 入力: required checks = `["A", "B"]` / `checks[]` に `A` `B` が全て success
- 期待出力: `escalation_flags` に `required_checks_*` を積まない。通常フロー（`MERGE_READY` 候補へ）
- 種別: Unit

### TC-06: required checks の取得失敗（fail-closed）

- 前提条件: ruleset API の異常応答 fixture（403 / rate limit / 想定外形式）が注入可能
- 入力: ruleset API が 403 / rate limit / 想定外形式を返す fixture
- 期待出力: **config fallback を使わず** `escalation_flags` に `required_checks_fetch_failed:<reason>` を積む → `HUMAN_ESCALATED`。**snapshot を破棄せず `assess()` を通す**（`record.jsonl` に state entry が残る = AC-6 の no-progress 検知と接続可能）
- 種別: Unit

## AC-3: 冪等（intent → 実行 → receipt → reconcile）

### TC-07: 同一 `action_id` の再実行で二重作用しない

- 前提条件: intent + receipt が `record.jsonl` に記録済み
- 入力: 同一 snapshot で Executor を再実行
- 期待出力: 外部作用が**発生しない**（`gh_exec` が一度も呼ばれない）。receipt の重複追記もない
- 種別: Unit

### TC-08: `action_id` は `c3_contract.canonical_hash()` を import 再利用

- 前提条件: `reconciler.py` / `executor.py` 実装済み（ソースの静的検査のみ）
- 入力: `reconciler.py` / `executor.py` ソース
- 期待出力: `canonical_hash` の**再実装がない**（`sha256` / `json.dumps(..., sort_keys=True)` の独自記述が存在しない）。`c3_contract` から import している
- 種別: Unit

### TC-09: 外部作用**前**の中断 → resume で再要求される

- 前提条件: intent あり / receipt なし
- 入力: resume で同一 snapshot を再投入
- 期待出力: 当該 action を**再要求する**（実行ゼロ回に終わらない）。`delivery.py` の `test_tcE5_intent_without_receipt_rerequested` と同じ挙動を外側 2 層でも維持
- 種別: Integration

### TC-09b: 外部作用**後**・receipt **前**の中断 → resume で二重作用しない（R-021）

- 前提条件: intent あり / receipt **なし** / **repair push は既に PR に反映済み**（`expected_parent_sha` が現在の PR head の祖先）
- 入力: resume で同一 snapshot を再投入
- 期待出力: Executor の**実行前 pre-check** が「実行済み」と判定し **push を再実行しない**（`gh_exec.push_pr_head` が呼ばれない）。receipt のみが記録される。あわせて**通知コメントが repair push より先**に打たれる順序であることを検証（コメント投稿が失敗した run では push が発生しない = 中断時の残骸が「余分なコメント 1 件」に限定される）
- 種別: Integration

## AC-4: repair E2E

### TC-10: fixture E2E 1 周（機械化された合格基準）

- 前提条件: `tests/extras/ta-57-pr-convergence.sh` の fixture（check-runs / reviews / pull / **`rules/branches/{base_ref}`** の各レスポンス。R-022 で `rulesets/{id}` から差し替え）
- 入力: CI 失敗 snapshot → repair action 実行 → 新 head の fixture → 再評価
- 期待出力: `CHECKS_FAILED` → repair → 最新 head で再評価 → **`MERGE_READY`** に到達。`sh tests/run-tests.sh` が exit 0 かつ **「baseline 430 + 新規 PASS 行数 7」= 最低 437 を下回らない**（R-020: ta-57 が `test_gh_exec` / `test_check_exec_boundary` / `test_collector` / `test_ci_taxonomy` / `test_executor` / `test_reconciler` / `test_plan_package` の 7 本を 1 モジュール 1 PASS 行で実行すること。7 本の PASS 行が出力に現れることを grep で確認する）
- 種別: E2E

### TC-11: 実 PR 1 周の手動実走証跡（Q2 回答）

- 前提条件: 本リポジトリの検証用 PR 1 本（新規 test repository は作らない）
- 入力: 手順書に従い Collector → assess → Executor（repair push + 通知コメント）→ 再 Collect → assess
- 期待出力: 実行ログが `docs/working/TASK-0917/evidence/e2e/` に保存される。**実 PR への書き込みが repair push とコメントのみ**であることがログで確認できる（close / branch 削除・approve・merge が 0 件）
- 種別: E2E（手動・1 回。CI 常設しない）

## AC-6: #894 Loop Control Contract 接続点（D5 = I/F 先行固定）

### TC-12: opaque reason code の素通し

- 前提条件: `collector.py` 実装済み / `delivery.py` は main の実物を使用 / `record.jsonl` は空で初期化済み
- 入力: Collector が `escalation_flags` に任意の reason code 文字列（例 `loop_control:budget_exceeded`）を積んだ snapshot
- 期待出力: `assess()` が `HUMAN_ESCALATED` を返し、reason 文字列が `record.jsonl` に残る。**語彙の妥当性は検証しない**（enum は #894 が決める）
- 種別: Integration

### TC-13: no-progress 検知の前提（state entry が残る）

- 前提条件: `collector.py` 実装済み / `record.jsonl` は空で初期化済み / pre-check が必ず失敗する fixture
- 入力: pre-check 失敗が連続する 2 回の run
- 期待出力: いずれの run でも `record.jsonl` に state entry が追記される（「何も起きていない run」と区別できる）
- 種別: Integration

## AC-7: `delivery.py` 判定エンジン不変

### TC-14: 3 ファイルの差分 0 行

- 前提条件: 作業ブランチが `origin/main`（`b45ab17`）から分岐済み（`git fetch` 済み）
- 入力: `git diff --stat origin/main -- scripts/ai-loop/delivery.py scripts/ai-loop/c3_contract.py scripts/ai-loop/c3prime_verify.py`
- 期待出力: **出力 0 行**（exit 0）
- 種別: E2E

### TC-15: 既存 57 テストが全 PASS

- 前提条件: repo root を cwd とし `scripts/ai-loop/` が import 可能
- 入力: `python3 scripts/ai-loop/test_delivery.py`（repo root 起点）
- 期待出力: `Ran 57 tests ... OK` / exit 0
- 種別: E2E

### TC-16: contract ブロックの byte 一致

- 前提条件: `delivery.py contract` の emit が可能 / `delivery-state-machine.md` が存在
- 入力: `ta-56-delivery.sh` の `cmp -s`（`delivery.py contract` の emit ↔ `delivery-state-machine.md` の `<!-- contract:begin/end -->` ブロック）
- 期待出力: 一致。§4 への additive 追記が contract ブロックを壊していない
- 種別: E2E

## AC-8: `ci_failure_taxonomy` の供給元

### TC-17: manual entry を正とする

- 前提条件: `ci_taxonomy.py` 実装済み / manual taxonomy entry を含む `record.jsonl` fixture
- 入力: `record.jsonl` に manual taxonomy entry（`code`）
- 期待出力: `ci_taxonomy` モジュールが `code` を返す。自動分類より **manual が優先**
- 種別: Unit

### TC-18: 狭い自動 allowlist（`environment` のみ）

- 前提条件: `ci_taxonomy.py` 実装済み / CI ログ断片 fixture が読める
- 入力: CI ログ断片 `rate limit` / `ECONNRESET` / `runner has received a shutdown signal`
- 期待出力: `environment` と判定。**`code` を機械が積極的に断定しない**（`code` を返す自動分類ルールが存在しない）
- 種別: Unit

### TC-19: 未該当は taxonomy を出力しない（fail-closed に委譲）

- 前提条件: `ci_taxonomy.py` 実装済み / manual entry を持たない `record.jsonl` fixture
- 入力: 既知パターンに一致しない CI ログ + manual entry なし
- 期待出力: snapshot に `ci_failure_taxonomy` を**出力しない** → `delivery.py` の既存 fail-closed（未知値/欠落 → `HUMAN_ESCALATED`）に委ねる
- 種別: Unit

## AC-5: 破壊的操作の封じ込め（`gh_exec.py` allowlist）

> ⚠️ TC-21 の docstring には「**これは allowlist の正しさの担保ではなく取りこぼしの検算**」と明記する（既知禁止の列挙は網羅性を証明しない。網羅性は TC-20 / TC-22 の構造的検査が担う）。

### TC-20（T-A）: allow 経路の一意性

- 前提条件: `gh_exec.py` 実装済み / rule table を差し替え可能な構造になっている
- 入力: rule table を空にした状態で、通常なら allow される全コマンドを投入
- 期待出力: **全件 `Denied`**（= allow は rule table 経由でしか成立しない。関数末尾の無条件 `raise Denied` が効いている）
- 種別: Unit

### TC-21（T-B）: 既知禁止の検算

- 前提条件: `gh_exec.py` 実装済み / `subprocess` を monkeypatch した spy を注入
- 入力: `gh pr merge 1` / `gh pr review 1 --approve` / `gh pr close 1` / `gh pr reopen 1` / `gh pr ready 1` / `gh pr edit 1` / `gh api -X DELETE repos/o/r/git/refs/heads/x` / `gh api -X PUT repos/o/r/pulls/1/merge` / `gh repo sync`
- 期待出力: **全件 `Denied`**（exit 非 0）
- 種別: Unit

### TC-22（T-C）: 補集合の自動追随

- 前提条件: `gh_exec.py` 実装済み / サブコマンド語彙 × 動詞の直積を機械生成できる
- 入力: サブコマンド語彙 × 動詞の直積（`pr` / `issue` / `repo` / `api` / `release` / `run` × `merge` / `close` / `reopen` / `ready` / `edit` / `delete` / `create` / `review` …）を機械生成して全件投入
- 期待出力: **allowlist に載っていない組合せが全件 `Denied`**。allowlist を将来拡張しても本 TC が自動追随する（列挙の手作業更新を要さない）
- 種別: Unit

### TC-23（T-D）: フラグ次元

- 前提条件: `gh_exec.py` 実装済み / `subprocess` spy を注入
- 入力: `gh pr comment 1 --delete-last --yes` / `gh pr comment 1 --edit-last` / `gh pr comment 1 -w` / `gh pr comment 1 -e` / `gh pr comment 1 --create-if-none`
- 期待出力: **全件 `Denied`**（サブコマンド名だけの allow では「PR の履歴を変える操作」を通してしまうため、flag 単位の allowlist が必須）
- 種別: Unit

### TC-24（T-E）: 正規化回避 + 短縮形の一律 deny（R-029 反映）

- 前提条件: `gh_exec.py` 実装済み / `subprocess` spy を注入
- 入力: `gh api --method=post ...` / `gh api -XPOST ...` / `--method GET --method POST`（2 回指定）/ `gh pr view 1 -- pr merge` / endpoint に `{owner}` プレースホルダ / 他 repo の endpoint（`repos/other/other/...`）/ `gh api graphql ...` / `gh api --cache 1h ...` / `gh api --raw-field k=v ...` / `gh api --field k=v ...` / `gh api --input -`
- **短縮形ケース（追加）**: `gh api -X GET ...`（**GET でも deny**）/ `gh api -f k=v` / `gh api -F k=v` / `gh api -q .x` / `gh pr comment 1 -b x` / `gh pr comment 1 -F file`
- 期待出力: **全件 `Denied`**。
  - GET 強制は 3 条件 AND（`--method` があるなら値が `GET` に完全一致 / `--raw-field` `--field` `--input` が 1 つでもあれば deny / endpoint 完全一致・owner-repo は実値束縛）
  - **短縮形は long へ正規化せず、「短縮形が使われた」ことを理由に一律 deny**する（`-XPOST` の結合形は分解したうえで deny）。理由 = 短縮形の意味は**サブコマンド依存**（`-F` は `gh api` では `--field`、`gh pr comment` では `--body-file`）で単一のグローバル正規化表が成立しないため。wrapper は常に long 形で argv を組み立てるので正側に影響しない
- 種別: Unit

### TC-25（T-F）: argv[0] 固定

- 前提条件: `gh_exec.py` 実装済み（wrapper が `argv[0]` を caller から受け取らない契約）
- 入力: `["sh", "-c", "gh pr merge 1"]` / `["/usr/bin/env", "gh", "pr", "merge", "1"]` / `["gh"]` を caller から渡す
- 期待出力: wrapper が `argv[0]` を caller から受け取らないため**組み立たない**（型/契約レベルで拒否 or `Denied`）
- 種別: Unit

### TC-26（T-G）: 負側テストの無害性

- 前提条件: `gh_exec.py` 実装済み / `subprocess.run` / `check_output` を monkeypatch した spy を注入
- 入力: 上記 deny ケース全件
- 期待出力: `subprocess.run` / `check_output` が **一度も呼ばれない**（monkeypatch した spy の呼び出し回数 = 0）
- 種別: Unit

### TC-27（T-H）: git 側の危険形

- 前提条件: `gh_exec.py` の `push_pr_head()` 実装済み / `subprocess` spy を注入
- 入力: `git push origin --force ...` / `--force-with-lease` / `-d branch` / `--delete` / refspec 先頭 `+HEAD:branch` / 空 src `:branch` / `--mirror` / `--prune` / `--receive-pack=...` / `git -c core.hooksPath=/dev/null push ...`
- 期待出力: **全件 `Denied`**（= `push_pr_head()` が argv を自ら組み立てるため、これらは原理的に生成されない。allowlist 経由の任意 push 経路が存在しないことも併せて検証）
- 種別: Unit

### TC-28: `graphql` / `--cache` が allowlist に存在しない

- 前提条件: `gh_exec.py` 実装済み / rule table が読み取り可能
- 入力: `gh_exec.py` の rule table
- 期待出力: `graphql` / `--cache` を許可する rule が **0 件**（GraphQL は常に POST で `mergePullRequest` / `addPullRequestReview` の直接経路。`--cache` は stale が AC-1 と衝突）
- 種別: Unit

### TC-29: `gh api` GET の正側（R-022 で endpoint 差し替え）

- 前提条件: `gh_exec.py` 実装済み / owner・repo が呼び出し時の実値で束縛済み
- 入力: 次の **4 endpoint**（owner/repo は実値束縛）
  1. `repos/{o}/{r}/commits/{sha}/check-runs`
  2. `repos/{o}/{r}/pulls/{n}/reviews`
  3. `repos/{o}/{r}/pulls/{n}`
  4. **`repos/{o}/{r}/rules/branches/{base_ref}`**（旧 `repos/{o}/{r}/rulesets/{id}` から差し替え）
- 期待出力: **allow**。それ以外の endpoint（例 `repos/{o}/{r}/pulls/{n}/merge`）は `Denied`。**ruleset 一覧 `repos/{o}/{r}/rulesets` も allowlist 外で `Denied`**（id 解決経路を作らないことの固定 = 配布先で壊れる repo 固有 id の埋め込みを防ぐ）
- 種別: Unit

### TC-30: `push_pr_head()` の事前検査

- 前提条件: `gh_exec.py` の `push_pr_head()` 実装済み / `gh pr view` と `git remote get-url` の応答 fixture
- 入力: branch が `gh pr view --json headRefName` の実測値と不一致 / `baseRefName` と一致 / `git remote get-url origin` が repo と不一致 / non-fast-forward
- 期待出力: いずれのケースも push に到達せず拒否
- 種別: Unit

### TC-31: subprocess 境界の AST 検査

- 前提条件: `check_exec_boundary.py` 実装済み / 現行ツリー（違反注入は一時コピー上で行い作業ツリーを汚さない）
- 入力: `python3 scripts/ai-loop/check_exec_boundary.py`
- 期待出力: ①現行ツリーが **clean**（`discovery.py` の docstring 禁止宣言文に HIT しない = substring 走査を使っていない。**判定は下記「argv 先頭要素 不変条件（精緻化版）」＝読み取り専用 git allowlist + grandfather 例外 1 件を適用した状態で行う**）②`gh_exec.py` 以外に**実行系トークン**の import を注入すると **FAIL** ③`test_*.py` 内の `subprocess.run` / `check_output` の argv 先頭要素が **`sys.executable` でも読み取り専用 git サブコマンド allowlist（`status` / `rev-parse` / `diff` / `log` / `merge-base` / `ls-remote` / `show`）でもなく**、かつ **grandfather 例外リストにも載っていない**場合 **FAIL**（テスト単純除外を迂回路にしない）。**照合は `import subprocess as X` / `from subprocess import run, check_output` 等の import 形を AST で解決してから行う**（別名・直接 import も同一扱い。解決できない import 形は fail-closed）。属性呼び出し形（`ast.Attribute(value=Name('subprocess'))`）だけを見る実装では、**exec で新規作成する test 6 本が別名・直接 import を使った瞬間に照合をすり抜け検査器が clean を返す**（R-035。現行ツリーは `import subprocess` のみのため今は空振りしないが、新規コードで穴になる）④**`gh_exec.py` に対する逆向きホワイトリスト検査**: `subprocess` **のみ**許可し、その他の実行系トークンが 1 件でもあれば **FAIL**（例: `gh_exec.py` に `os.system("gh pr merge 1")` を注入すると FAIL）⑤**argv がリテラルでなく変数経由で静的追跡不能なとき**は、例外リストに載っていない限り **FAIL に倒す（fail-closed）**。**`delivery.py` 系の既存 substring 走査（`test_tc18_pure_verdict_source` / ta-56）は不変**
- **argv 先頭要素 不変条件（精緻化版 / C-1 F-1 の裁定）**: 許可は `sys.executable` **または**読み取り専用 git サブコマンド allowlist。**grandfather 例外は `test_c3prime_verify.py` の `_run()`（`args = ["python3", ...]`）1 件のみ**で、`check_exec_boundary.py` に**ファイル + 関数名で特定して列挙**し凍結する（`"python3"` は PATH 依存で実行中インタプリタと一致しない潜在不具合のため、正当化ではなく凍結扱い）。`test_discovery.py` の `["git", "status", "--porcelain"]` 2 箇所は allowlist で**恒久的に許容**され例外リストには載せない。`test_c3prime_verify.py` の `sys.executable` 化は **V2 候補**（本 PBI では触らない = `allowed_paths` を増やさない）
- **検査対象トークン集合（R-025 反映 / pbi AC-5 と同一）**: `subprocess` / `os.system` / `os.popen` / `os.exec*` / `os.spawn*` / `urllib` / `socket` / `http.client` / `requests` / `importlib.import_module` による動的 import。**`subprocess` の import のみを検査する縮小版では `gh_exec.py` 内の `os.system("gh pr merge 1")` を止められない**ため、集合を pbi AC-5 の列挙まで戻す
- 種別: Unit / E2E

### TC-31b: grandfather 例外リストが増えないことの固定（負側 / C-1 F-1 の裁定）

- 前提条件: `check_exec_boundary.py` 実装済み / 例外リストが 1 件（`test_c3prime_verify.py` の `_run()`）で初期化されている
- 入力: ①例外リストの実体（`check_exec_boundary.py` が公開する定数）を読む ②例外リストに 2 件目のエントリを追加した状態でテストを実行する
- 期待出力: ①例外リストの件数が **厳密に 1** であり、そのエントリが `test_c3prime_verify.py` の `_run()` を指す ②**2 件目を追加すると本 TC が FAIL する**（= 例外リストの増加が機械的にブロックされ、新規コードには不変条件が厳格に適用される）。**変異注入で検出力を実証する**（1 件固定のアサートを外すと本 TC が空振りすることを確認）
- 種別: Unit

### TC-31c: import 形の解決（別名 / 直接 import の変異注入 / R-035）

- 前提条件: `check_exec_boundary.py` 実装済み / 違反注入は一時コピー上で行い作業ツリーを汚さない（TC-31 と同様式）
- 入力: 一時コピーの `test_*.py` に次の 3 形を注入する
  1. `import subprocess as sp` + `sp.run(["python3", "x.py"])`
  2. `from subprocess import run` + `run(["python3", "x.py"])`
  3. `from subprocess import check_output as co` + `co(["python3", "x.py"])`
- 期待出力: **3 形すべてで FAIL**（`"python3"` は `sys.executable` でも読み取り専用 git サブコマンドでもなく grandfather 例外リストにも無いため）。**検出力の実証（変異注入）**: import 形の解決を外し `ast.Attribute(value=Name('subprocess'))` のみを見る実装に差し替えると、3 形すべてが**すり抜けて clean になる**ことを確認する。あわせて **`import subprocess as sp` + `sp.run([sys.executable, ...])` は PASS**（正側 — 別名解決が過剰検出になっていないこと）
- 種別: Unit

## AC-9: raw check evidence（縮小実施 / Q1 回答）

> ⚠️ **限界の明示**: 本 AC がカバーするのは「**Collector が生成した snapshot** の内部整合」まで。**手作りの snapshot を `delivery.py` に直接投入する経路は塞がない**（Phase 1 の信頼境界は解消しきらない）。この注記の記載先は **`delivery-state-machine.md` §4（doc）/ handoff / 実装の docstring の 3 箇所**で統一する（plan 冒頭 Q1 帰結・plan Step 11 の §4 追記 5 文の 3 番目と一致。R-024 反映）。

### TC-32: raw 同梱と導出照合（正側）

- 前提条件: `collector.py` 実装済み / check-run の生レスポンス fixture
- 入力: check-run の生レスポンス（`id` / `head_sha` / `conclusion` / `completed_at`）を同梱した snapshot
- 期待出力: `checks[]` の各要素が raw の対応要素から導出されていることを Collector が照合して PASS
- 種別: Unit

### TC-33: 改竄された `checks[]` を拒否（負側）

- 前提条件: `collector.py` 実装済み / raw と `checks[]` が不整合な fixture
- 入力: raw では `conclusion = "failure"` なのに `checks[]` は `"success"` になっている snapshot
- 期待出力: Collector が不整合を検出し `escalation_flags` に `raw_evidence_mismatch:<name>` を積む → `HUMAN_ESCALATED`
- 種別: Unit

### TC-34: raw 欠落（負側）

- 前提条件: `collector.py` 実装済み / raw エントリが欠落した fixture
- 入力: `checks[]` に存在する name の raw エントリが無い
- 期待出力: 同上（fail-closed）。**raw が無いことを「照合 OK」と扱わない**
- 種別: Unit

## snapshot 供給契約の健全性（AC 横断 / C-2 反映）

> `validate_snapshot()` の必須キーは **12**（`task_id` / `pr_number` / `head_sha` / `source_sha_ancestry` / `mergeable` / `checks` / `review` / `findings` / `changed_files` / `allowed_paths` / `escalation_flags` / `dod_evaluated`）で、`conflict_resolution` は **任意キー**（`cr = snap.get(...)` / `if cr is not None and ...`）。`pbi-input.md` の「必須 13 キー」は誤りであり、**plan の記述（12 + 任意 1）を正とする**（R-026）。

### TC-35: `changed_files` を読み取り系 git で実測供給（正側 / R-017）

- 前提条件: base / head が既知のローカル repo
- 入力: `git diff --name-only <base>...<head>` の出力（読み取り系 git allowlist 経由。**`gh api` の 4 endpoint allowlist を広げない**）
- 期待出力: snapshot の `changed_files` が実測パス集合と一致する
- 種別: Unit

### TC-36: `changed_files` を空リストで埋めない（負側 / fail-open 封じ / R-017）

- 前提条件: `collector.py` 実装済み / `git diff --name-only` が失敗する fixture
- 入力: `git diff --name-only` が失敗する（非 0 終了 / 実行不能）fixture
- 期待出力: **空リストで `assess()` に通さない**。`escalation_flags` に `changed_files_unavailable:<reason>` を積み `HUMAN_ESCALATED`。
  - 補足検証: 空リストのまま通すと `deviated = [p for p in snapshot["changed_files"] if not _path_allowed(p, allowed)]` が常に空になり、`PRIORITY_ORDER` 2 位 `plan_deviation`（→ `EXEC_RETURN`）が**恒久的に不発（fail-open）**になることを、空リスト snapshot を直接 `assess()` に与えて確認する
- 種別: Unit

### TC-37: `conflict_resolution` は三点が揃うときのみ出力（正側 / R-017）

- 前提条件: `reconciler.py` / `collector.py` 実装済み / `resolve_conflict` receipt を含む `record.jsonl`
- 入力: `resolve_conflict` の receipt から Reconciler が `base_sha` / `head_sha` / `result_sha` を再構成できる fixture
- 期待出力: snapshot に `conflict_resolution` が三点そろって出力される。三点のいずれかが再構成できない場合は**キーを出力しない**（部分 dict を出さない）
- 種別: Unit

### TC-38: conflict 未発生時は `conflict_resolution` キー自体を出さない（負側 / 恒久 CONFLICT 封じ / R-026）

- 前提条件: `collector.py` 実装済み / conflict 未発生（`mergeable = "MERGEABLE"`）の PR fixture
- 入力: `mergeable = "MERGEABLE"` で conflict が発生していない PR の snapshot
- 期待出力: snapshot に **`conflict_resolution` キーが存在しない**（`"conflict_resolution" not in snapshot`）。
  - 補足検証: 空 dict / 部分 dict を常時出力すると `cr_incomplete = isinstance(cr, dict) and not all(cr.get(k) for k in ("base_sha","head_sha","result_sha"))` → `conflict_need = True` となり **どの PR も永久に `CONFLICT`（`MERGE_READY` 到達不能）**になることを、部分 dict 入り snapshot を `assess()` に与えて確認する
- 種別: Unit

### TC-39: 未完了 check-run の `status` → `conclusion` 写像（R-019 / AC-4 の 1 周が実 PR で回る前提）

- 前提条件: check-run fixture に `{"status": "in_progress", "conclusion": null, "head_sha": H1}` を含む（repair push 直後の実挙動）
- 入力: Collector が snapshot を生成 → `assess()`
- 期待出力:
  1. `checks[].conclusion` が **`"in_progress"`**（`status != "completed"` のとき `conclusion = status` へ写像）で、`validate_snapshot()` の `isinstance(conclusion, str)` を満たす
  2. `assess()` が **`WAITING_FOR_CHECKS`** に倒れる（`CHECK_PENDING = ("pending", "queued", "in_progress")` に一致）
  3. 写像を外した実装では `conclusion = None` により **優先度 1 の `invalid_snapshot`** に落ち `WAITING_FOR_CHECKS` に到達しないことを負側で確認する（**変異注入で検出力を実証**。fixture が手書きだと乖離が隠れるため）
- 種別: Unit

### TC-40: `finding_type` 語彙の同一性と `id` の決定論（R-034 / `same_type_recurrence` の fail-open 封じ）

- 前提条件: `collector.py`（`findings[]` 変換アダプタ）/ `executor.py` / `reconciler.py` 実装済み / `delivery.py` は main の実物を使用 / `record.jsonl` に当該 PR の `repair_review` receipt（`finding_type` 付き）が記録済み
- 入力:
  1. **正側**: 既存 `repair_review` receipt と**同じ `finding_type`** を持つ未解消 finding を、変換アダプタ経由で生成した snapshot に載せて `assess()` に投入する
  2. **負側（変異注入）**: 変換アダプタ側の `finding_type` を receipt 側と**別語彙**（例 `security` → `sec`）にした snapshot を同条件で投入する
  3. **`id` の決定論**: 同一の入力 finding（`docs/ai/external-reviewer-interface.md` §3.2 形式）から 2 回アダプタを実行する
- 期待出力:
  1. 正側: `assess()` が `REVIEW_REPAIR` を返し、actions に **`feedback_loop_referral`** が含まれる（`delivery.py` L305 の `recurrence` が非空 = 同型指摘の再発として検知される）
  2. 負側: `_past_repair_finding_types()` との**集合積が空**になり `feedback_loop_referral` が出ない（= 語彙不一致だと再発検知が**恒久 fail-open** になることを実証する。この負側が FAIL しない実装は語彙の同一性を担保できていない）
  3. `id` の決定論: 2 回の実行で同一 `id` が生成される。負側として `id` を run ごとに変える実装では、`_resolved()` の disposition 突合が壊れ `unresolved_hard` が解消されず `MERGE_READY` に到達しないことを確認する
- 種別: Integration

## エッジケース

### TC-E1: GitHub API の rate limit

- 前提条件: `collector.py` 実装済み / check-runs 取得が 403 rate limit を返す fixture
- 入力: check-runs 取得が 403 rate limit を返す
- 期待出力: 例外を握り潰さず `escalation_flags` へ（`HUMAN_ESCALATED`）。**部分的な `checks[]` で MERGE_READY に到達しない**
- 種別: Unit

### TC-E2: timeout

- 前提条件: `collector.py` 実装済み / `gh_exec` が timeout を返す fixture
- 入力: `gh_exec` が timeout を返す
- 期待出力: 固定回数の retry 後に fail-closed（backoff の既存実装は repo 内に無いため最小限に留める）
- 種別: Unit

### TC-E3: shallow clone で ancestry 解決不能

- 前提条件: shallow clone 相当の repo（`merge-base --is-ancestor` が exit 0 / 1 以外を返す）
- 入力: `git merge-base --is-ancestor` が exit 0 / 1 以外を返す
- 期待出力: `source_sha_ancestry = None` → `delivery.py` の `is not True` 判定で `HUMAN_ESCALATED`
- 種別: Unit

### TC-E4: `plan.md` から `allowed_paths` 抽出 0 件

- 前提条件: `## Files / Components to Touch` 節を欠く（またはバッククォート囲みパス 0 件の）plan.md fixture
- 入力: `## Files / Components to Touch` 節が無い / バッククォート囲みパスが 0 件の plan.md
- 期待出力: `escalation_flags` に `allowed_paths_empty` を積む（空リストのまま `assess()` を通すと全変更が `EXEC_RETURN` になり原因が判別できないため）
- 種別: Unit

### TC-E5: `record.jsonl` 破損

- 前提条件: 破損行を含む `record.jsonl` fixture
- 入力: 不正 JSON 行 / 途中で切れた行を含む `record.jsonl`
- 期待出力: `dod_evaluated = False`（fail-closed）+ `escalation_flags` に破損理由。**append-only 契約を破って書き直さない**
- 種別: Unit

### TC-E6: 通知コメントの投稿失敗

- 前提条件: `executor.py` 実装済み / `gh pr comment` が非 0 で終了する fixture + `push_pr_head` の spy
- 入力: `gh pr comment` が非 0 で終了
- 期待出力: **握り潰さず** `escalation_flags` へ。receipt に成功として記録しない。**かつ通知コメントは repair push より先に打たれるため、この run では repair push が実行されない**（`gh_exec.push_pr_head` の呼び出し回数 = 0）。次 run で同一 intent が再要求されても TC-09b の pre-check により二重 push にならない（R-021）
- 種別: Unit

### TC-E7: `dod_evaluated` の head 束縛

- 前提条件: `record.jsonl` に旧 head へ束縛された `dod_reevaluate` receipt が記録済み
- 入力: 直近の `dod_reevaluate` receipt が**旧 head** に束縛されている
- 期待出力: `dod_evaluated = False`（`MERGE_READY_CANDIDATE` 止まり）
- 種別: Unit

### TC-E8: sync 列挙の片方漏れ検出

- 前提条件: `sync-plugin-plangate.sh` の 2 箇所（**記号アンカー** で特定: for ループ `for _f in "$AI_LOOP_SCRIPTS_DIR/arbiter.py" …` / case `arbiter.py|test_arbiter.py|…) : ;;`。行番号 L345 / L355 は 2026-07-31 時点の**目安**）へ新規 12 本を追加済み（T-37 / T-38 完了後）
- 入力: `sync-plugin-plangate.sh` の for ループ側（上記記号アンカー）と case 側（同）の basename 集合
- 期待出力: 2 集合の差分が **0**（片方だけに追加された状態を検出して FAIL）
- 種別: E2E
