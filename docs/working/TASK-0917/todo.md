# EXECUTION TODO — TASK-0917

> plan: [`plan.md`](./plan.md) / test-cases: [`test-cases.md`](./test-cases.md)
> Mode: **critical**（実装タスクは `rollback:` 記載必須）。L-0〜V-4・PR 作成は workflow-conductor が制御するため含めない。
> 実装は TDD（RED → GREEN → REFACTOR）で並べる。**`delivery.py` / `c3_contract.py` / `c3prime_verify.py` は一行も触らない**（AC-7）。

## 🤖 Agentタスク

### 準備フェーズ

- [x] 🚩 T-1: Scope / 受入基準（AC-1〜9）と Out of scope（merge / 承認状態変更 / 判定規則変更）を再掲し作業範囲を固定 [Owner: agent] [depends_on: -] [files: -] rollback:不要
- [x] T-2: AC-7 baseline を実測記録（`git diff --stat origin/main -- <3 ファイル>` = 0 行 / `python3 scripts/ai-loop/test_delivery.py` = 57 OK / `sh tests/run-tests.sh` = 430 passed） [Owner: agent] [depends_on: T-1] [files: -] rollback:不要
- [x] T-3: 接続点の契約を確認（`delivery.py` の `validate_snapshot()` **必須 12 キー + 任意 `conflict_resolution` 1** / `PRIORITY_ORDER` の `plan_deviation` = 2 位・`escalation_flags` = 3 位 / `receipt` の intent 先行必須 / `c3_contract.canonical_hash()`）。**R-026: `pbi-input.md` の「必須 13 キー」は誤りで、plan の記述（12 + 任意 1）を正とする** [Owner: agent] [depends_on: T-2] [files: -] rollback:不要

### 境界検査器フェーズ（先に守りを作る）

- [x] 🚩 T-4: `test_check_exec_boundary.py` — AST 検査の RED（`gh_exec.py` 以外での**実行系トークン**検出 / **`test_*.py` の argv 先頭要素 不変条件（精緻化版）**＝`sys.executable` **または**読み取り専用 git サブコマンド allowlist（`status` / `rev-parse` / `diff` / `log` / `merge-base` / `ls-remote` / `show`）/ **grandfather 例外リストが 1 件（`test_c3prime_verify.py` の `_run()`）から増えないことの固定** / **argv が静的追跡不能なら例外リスト外は FAIL（fail-closed）** / 現行ツリー clean / **`gh_exec.py` に対する逆向きホワイトリスト**＝`subprocess` のみ許可・他は 0 件）。**対応 TC: TC-31 / TC-31b** [Owner: agent] [depends_on: T-3] [files: scripts/ai-loop/test_check_exec_boundary.py] rollback: ファイル削除
- [x] T-5: `check_exec_boundary.py` 実装（GREEN・stdlib `ast` のみ。**substring 走査を使わない** = `discovery.py` docstring の偽陽性回避）。**検査対象トークン集合は pbi AC-5 と同一まで拡張**（R-025）: `subprocess` / `os.system` / `os.popen` / `os.exec*` / `os.spawn*` / `urllib` / `socket` / `http.client` / `requests` / `importlib.import_module` の動的 import。`gh_exec.py` は**除外せず**逆向きホワイトリスト検査にかける（除外すると `gh_exec.py` 内の `os.system("gh pr merge 1")` を止めるものが存在しなくなる）。**`test_*.py` の argv 先頭要素 不変条件は精緻化版で実装**（`sys.executable` または読み取り専用 git サブコマンド allowlist + **ファイル名 + 関数名で特定する grandfather 例外リスト 1 件** + **静的追跡不能は例外リスト外なら violation**） [Owner: agent] [depends_on: T-4] [files: scripts/ai-loop/check_exec_boundary.py] rollback: ファイル削除
- [x] T-6: 現行 `scripts/ai-loop/*.py` に対し clean 判定を実測確認（偽陽性ゼロ。**精緻化版の不変条件 + 例外リスト 1 件を適用した状態で clean** であること。`test_discovery.py` の `["git","status","--porcelain"]` 2 箇所は allowlist で恒久許容され、例外リストには載せない） [Owner: agent] [depends_on: T-5] [files: -] rollback:不要

### gh 実行ラッパフェーズ（AC-5 の中核）

- [x] 🚩 T-7: `test_gh_exec.py` — 負側 RED その 1: allow 経路の一意性（rule table を空にすると全 allow が Denied）+ 関数末尾の無条件 deny [Owner: agent] [depends_on: T-6] [files: scripts/ai-loop/test_gh_exec.py] rollback: ファイル削除
- [x] T-8: `test_gh_exec.py` — 負側 RED その 2: 既知禁止 9 種の検算（`gh pr merge` / `gh pr review --approve` / `gh pr close` / `gh pr reopen` / `gh pr ready` / `gh pr edit` / `gh api -X DELETE .../git/refs/...` / `gh api -X PUT .../pulls/1/merge` / `gh repo sync`）。**docstring に「これは allowlist の正しさの担保ではなく取りこぼしの検算」と明記** [Owner: agent] [depends_on: T-7] [files: scripts/ai-loop/test_gh_exec.py] rollback: git restore
- [x] T-9: `test_gh_exec.py` — 負側 RED その 3: 補集合の自動追随（サブコマンド語彙 × 動詞の直積を回し allowlist 外が全件 Denied） [Owner: agent] [depends_on: T-8] [files: scripts/ai-loop/test_gh_exec.py] rollback: git restore
- [x] T-10: `test_gh_exec.py` — 負側 RED その 4: フラグ次元（`gh pr comment --delete-last --yes` / `--edit-last` / `-w` / `-e` / `--create-if-none`） [Owner: agent] [depends_on: T-9] [files: scripts/ai-loop/test_gh_exec.py] rollback: git restore
- [x] T-11: `test_gh_exec.py` — 負側 RED その 5: 正規化回避（`--method=post` / `-XPOST` / `--method` 2 回 / `--` 以降に `pr merge` / endpoint に `{owner}` / 他 repo の endpoint / `graphql` / `--cache`）+ **短縮形は全て deny**（`-X` / `-f` / `-F` / `-q` / `-b` / `-w` / `-e` — R-029: `-F` は `gh api` では `--field`、`gh pr comment` では `--body-file` と意味がサブコマンド依存のため、グローバル正規化表を持たず即 deny する） [Owner: agent] [depends_on: T-10] [files: scripts/ai-loop/test_gh_exec.py] rollback: git restore
- [x] T-12: `test_gh_exec.py` — 負側 RED その 6: argv[0] 固定（`["sh","-c","gh pr merge 1"]` 等を渡しても組み立たない）+ deny ケースで `subprocess` が一度も呼ばれない [Owner: agent] [depends_on: T-11] [files: scripts/ai-loop/test_gh_exec.py] rollback: git restore
- [x] T-13: `test_gh_exec.py` — 負側 RED その 7: git 側の危険形（`--force*` / `-d` / refspec 先頭 `+` / 空 src `:branch` / `--mirror` / `--prune` / `--receive-pack` / `-c core.hooksPath=/dev/null`） [Owner: agent] [depends_on: T-12] [files: scripts/ai-loop/test_gh_exec.py] rollback: git restore
- [x] T-14: `test_gh_exec.py` — 正側 RED（`gh api` GET 3 条件 AND の正常系 / `gh pr view --json headRefName,baseRefName` / `gh pr comment --body-file <wrapper temp>` / 読み取り系 git） [Owner: agent] [depends_on: T-13] [files: scripts/ai-loop/test_gh_exec.py] rollback: git restore
- [x] T-15: テスト実行し FAIL 確認（RED） [Owner: agent] [depends_on: T-14] [files: -] rollback:不要
- [x] 🚩 T-16: `gh_exec.py` 実装（GREEN）— argv 正規化（`--k=v` 分解 / **短縮形は long 化せず即 deny**・`-XPOST` は分解したうえで deny / R-029）+ 未知フラグ即 deny + 位置引数完全一致 + rule 固有 constraint + 末尾無条件 `raise Denied`。**wrapper 自身は常に long 形で argv を組み立てる** [Owner: agent] [depends_on: T-15] [files: scripts/ai-loop/gh_exec.py] rollback: ファイル削除
- [x] T-17: `gh_exec.py` — `push_pr_head(*, repo, branch, expected_parent_sha, cwd)` の構造化 API（argv を自ら組み立て・危険形を「組み立てない」）+ 事前検査 4 点（headRefName 一致 / baseRefName 不一致 / origin URL 一致 / fast-forward） [Owner: agent] [depends_on: T-16] [files: scripts/ai-loop/gh_exec.py] rollback: git restore
- [x] T-18: テスト実行し PASS 確認（GREEN）+ `check_exec_boundary.py` が `gh_exec.py` のみを除外対象として clean 判定 [Owner: agent] [depends_on: T-17] [files: -] rollback:不要

### 供給経路フェーズ

- [x] T-19: `test_plan_package.py` に `extract_allowed_paths(plan_text)` のテスト追加（RED） [Owner: agent] [depends_on: T-18] [files: scripts/ai-loop/test_plan_package.py] rollback: git restore
- [x] 🚩 T-20: `plan_package.py` — `extract_allowed_paths` を public 化（**抽出だけ切り出し `derive_loopspec` の maker/checker 検証を巻き込まない**）+ 既存テスト全 PASS 確認 [Owner: agent] [depends_on: T-19] [files: scripts/ai-loop/plan_package.py] rollback: git restore
- [x] T-21: `test_ci_taxonomy.py` RED（manual entry 優先 / 狭い自動 allowlist で `environment` / `code` を断定しない / 未該当は出力なし） [Owner: agent] [depends_on: T-20] [files: scripts/ai-loop/test_ci_taxonomy.py] rollback: ファイル削除
- [x] T-22: `ci_taxonomy.py` 実装（GREEN・AC-8 の供給主体） [Owner: agent] [depends_on: T-21] [files: scripts/ai-loop/ci_taxonomy.py] rollback: ファイル削除

### Collector フェーズ

- [x] 🚩 T-23: `test_collector.py` RED その 1: AC-1（head SHA 束縛）/ AC-2（required_checks ⊇ の負側・正側・取得失敗 fail-closed）。fixture 注入で `gh_exec` を差し替え [Owner: agent] [depends_on: T-22] [files: scripts/ai-loop/test_collector.py] rollback: ファイル削除
- [x] T-24: `test_collector.py` RED その 2: AC-9（raw check-run 同梱 + `checks[]` の導出照合 / 改竄拒否）+ `source_sha_ancestry` の 3 値 + `dod_evaluated` 導出 + `allowed_paths` 抽出 0 件 [Owner: agent] [depends_on: T-23] [files: scripts/ai-loop/test_collector.py] rollback: git restore
- [x] 🚩 T-25: `collector.py` 実装（GREEN）— REST GET 4 本（check-runs / reviews / pull / **`rules/branches/{base_ref}`**（R-022 で `rulesets/{id}` から差し替え・複数ルールは union））+ 読み取り系 git（`git diff --name-only <base>...<head>` で `changed_files` / R-017）+ **`status != "completed"` → `conclusion = status` の写像**（R-019）+ **`review` の縮約規則 6 点**（head 束縛 / 最新 `submitted_at` / `DISMISSED` 除外 / `state.lower()` 正規化 / 該当ゼロは `{"state":"none","sha":head_sha}` / `per_page` 明示の全件取得。R-018）+ snapshot 組み立て（**必須 12 キー。`conflict_resolution` は三点が揃うときのみ出力**・R-026）+ pre-check 失敗を `escalation_flags` へ（**破棄・例外 exit しない**）。**`changed_files` を空リストで埋めない**（`plan_deviation` の fail-open 化。取得失敗は `changed_files_unavailable:<reason>`） [Owner: agent] [depends_on: T-24] [files: scripts/ai-loop/collector.py] rollback: ファイル削除
- [x] T-26: `collector.py` — ネットワーク I/O 層と純関数の組み立て層を分離（`discovery.py` 慣習に沿う）+ テスト PASS 確認 [Owner: agent] [depends_on: T-25] [files: scripts/ai-loop/collector.py] rollback: git restore

### Executor / Reconciler フェーズ

- [x] 🚩 T-27: `test_executor.py` RED（6 action_kind / repair push / 通知コメント内包（新 action_kind を作らない）/ コメント失敗を握り潰さず escalation / receipt に comment URL / **通知コメントが repair push より先に打たれること**（R-021: コメント失敗なら push しない = 中断時の残骸を可逆な「余分なコメント 1 件」に限定）/ **実行前 pre-check「`expected_parent_sha` が既に PR head の祖先なら実行済みとみなし skip」**（push 済み・receipt 未記録での resume 時に二重 push しない）） [Owner: agent] [depends_on: T-26] [files: scripts/ai-loop/test_executor.py] rollback: ファイル削除
- [x] T-28: `executor.py` 実装（GREEN・外部書き込みは `gh_exec.py` 経由のみ。**実行順序 = 通知コメント → pre-check（祖先判定で skip）→ repair push → receipt**） [Owner: agent] [depends_on: T-27] [files: scripts/ai-loop/executor.py] rollback: ファイル削除
- [x] 🚩 T-51: **`finding_type` 語彙の単一定数表化（R-034）** — Collector の `findings[]` 変換アダプタと Executor の `repair_review` receipt が**同一の定数表を import** する形にし（定数表の置き場は `collector.py`・`executor.py` はそこから import。新規モジュールを作らず `allowed_paths` を増やさない）、アダプタが生成する `id` を入力 finding に対して**決定論的**にする。あわせて **TC-40**（`repair_review` receipt 済みの `finding_type` を持つ finding を再投入 → `REVIEW_REPAIR` + `feedback_loop_referral` が出る正側 / 語彙不一致だと `_past_repair_finding_types()` の集合積が空になり再発検知が空振りする負側の変異注入）を実装する。根拠 = `delivery.py` L229-231 の `_past_repair_finding_types()` と L305 の `recurrence` は snapshot 側（Collector アダプタ生成）と receipt 側（Executor 記録）の `finding_type` が同一語彙でないと**恒久 fail-open**、`id` が run 間で不安定だと `_resolved()` の disposition 突合が壊れ `unresolved_hard` が消えず `MERGE_READY` に到達しない [Owner: agent] [depends_on: T-28] [files: scripts/ai-loop/collector.py, scripts/ai-loop/executor.py, scripts/ai-loop/test_reconciler.py] rollback: git restore -- scripts/ai-loop/collector.py scripts/ai-loop/executor.py scripts/ai-loop/test_reconciler.py
- [x] T-29: `test_reconciler.py` RED（AC-3 冪等: 同一 `action_id` 再実行で二重作用しない / intent↔receipt 突合 / `result_ref` convention からの disposition 再構成 / `record.jsonl` 破損） [Owner: agent] [depends_on: T-51] [files: scripts/ai-loop/test_reconciler.py] rollback: ファイル削除
- [x] 🚩 T-30: `reconciler.py` 実装（GREEN・`c3_contract.canonical_hash()` を **import 再利用**し独自実装しない） [Owner: agent] [depends_on: T-29] [files: scripts/ai-loop/reconciler.py] rollback: ファイル削除
- [x] T-31: 統合テスト — Collector → `delivery.py assess()` → Executor → `delivery.py receipt` → Reconciler の 1 周を fixture 上で通す（`delivery.py` は実物を呼ぶ） [Owner: agent] [depends_on: T-30] [files: scripts/ai-loop/test_reconciler.py] rollback: git restore
- [x] 🚩 T-32: **AC-6 接続点の統合テスト（TC-12 / TC-13）**— Collector が `escalation_flags` に積んだ opaque reason code が `assess()` を素通しして `HUMAN_ESCALATED` に到達し `record.jsonl` に state entry が残ることを検証（連続 2 run で「何も起きていない run」と区別できること）。**語彙の妥当性は検証しない**（enum は #894 が決める）。R-023: AC-6 に実装タスクが 0 件で「誰も書かないテスト」になっていた状態の是正 [Owner: agent] [depends_on: T-31] [files: scripts/ai-loop/test_reconciler.py] rollback: git restore

### E2E フェーズ

- [x] 🚩 T-33: `ta-57-pr-convergence.sh` — ①fixture シナリオ（CI 失敗 → repair → 最新 head 再評価 → MERGE_READY の 1 周）②**新規 unit test 6 本 + `test_plan_package.py` の計 7 本を `python3 <root>/scripts/ai-loop/test_*.py` で実行し 1 モジュール 1 PASS 行を出す**（R-020: `run-tests.sh` は python を呼ばず、`test_plan_package.py` は ta-55 / ta-56 から fixture helper として import されるだけで本体未実行のため、導線が無いと Stop Condition が空振りする）③`check_exec_boundary.py` 実行 ④AC-7 の 3 点再確認 [Owner: agent] [depends_on: T-32] [files: tests/extras/ta-57-pr-convergence.sh] rollback: ファイル削除
- [x] T-34: `sh tests/run-tests.sh` クリーン 1 回実行 exit 0（**baseline 430 + 新規 PASS 行数 7 = 最低 437 を下回らない**ことを確認。7 本すべてが PASS 行として現れることも目視ではなく出力の grep で確認） [Owner: agent] [depends_on: T-33] [files: -] rollback:不要
- [x] 🚩 T-35: 実 PR 1 周の手動実走（AC-4 / Q2）— 検証用 PR に対し repair push + コメントのみ。**close / branch 削除はしない**。**前提: `gh auth status` で active account を確認**してから実行（U-8 / R-030。実行主体は `gh` 認証済みの手元環境） [Owner: agent] [depends_on: T-34] [files: docs/working/TASK-0917/] rollback: L3（revert commit + 訂正コメント。force push / 削除は禁止のまま）
- [x] T-36: 手動実走の証跡とコマンド手順を `evidence/e2e/` に保存 [Owner: agent] [depends_on: T-35] [files: docs/working/TASK-0917/] rollback: ファイル削除

### 配布 / doc フェーズ

- [x] 🚩 T-37: `sync-plugin-plangate.sh` の**コピー元 for ループ**へ新規 12 本を追加（**記号アンカー** `for _f in "$AI_LOOP_SCRIPTS_DIR/arbiter.py" …` で位置特定。行番号 L345 は 2026-07-31 時点の**目安**） [Owner: agent] [depends_on: T-36] [files: scripts/sync-plugin-plangate.sh] rollback: git restore -- scripts/sync-plugin-plangate.sh
- [x] 🚩 T-38: `sync-plugin-plangate.sh` の **case 許可判定**へ新規 12 本を追加（**記号アンカー** `arbiter.py|test_arbiter.py|…) : ;;` で位置特定。行番号 L355 は**目安**。T-37 とは別タスク。片方漏れ = sync drift / R-011） [Owner: agent] [depends_on: T-37] [files: scripts/sync-plugin-plangate.sh] rollback: 同上
- [x] T-39: **2 箇所の列挙が同一集合であることを機械照合**（for ループ側と case 側の basename 集合を diff して差分 0 を確認）— 片方漏れの検出タスク [Owner: agent] [depends_on: T-38] [files: -] rollback:不要
- [x] T-40: sync 実行 → 2 回目 no-op → `git diff --quiet plugin/` 確認 [Owner: agent] [depends_on: T-39] [files: plugin/plangate/] rollback: git restore -- plugin/
- [x] T-41: `delivery-state-machine.md` §4 へ **5 文**を additive 追記（①AC-8 供給主体 = `ci_taxonomy.py` ②AC-5 scope 限界 = Executor 経路のみ ③**AC-9 の限界** = 手作り snapshot の直接投入は塞がない ④**⊇ 照合は Collector pre-check として Phase 1 実装済み**・`required_checks[]` のフィールド化は引き続き V2 ⑤**branch protection は `required_approving_review_count: 0` のため後段防衛として当てにしない**（issue #928 参照））。④⑤ は §4 の現行記述が本 PBI で stale 化することの是正（R-027）。③ の記載先は plan 冒頭 Q1 帰結・test-cases の AC-9 注記と一致させる（R-024）。**`<!-- contract:begin/end -->` ブロックには触れない** [Owner: agent] [depends_on: T-40] [files: docs/workflows/ai-loop/delivery-state-machine.md] rollback: git restore
- [x] T-42: `execution-runbook.md` に D2-B（既存 hook / branch protection）を**多層防御の補助**として記載（設計は依存しない旨を明記）。R-024: 宣言した doc 更新先を Files / `allowed_paths` に含める是正 [Owner: agent] [depends_on: T-41] [files: docs/workflows/ai-loop/execution-runbook.md] rollback: git restore
- [x] T-43: `ta-56-delivery.sh` L29 の stale コメント「51 テスト」→「57 テスト」を是正（1 行・R-013） [Owner: agent] [depends_on: T-42] [files: tests/extras/ta-56-delivery.sh] rollback: git restore
- [x] T-44: contract byte 一致（`cmp -s`）を再確認し doc 追記が contract ブロックを壊していないことを実測 [Owner: agent] [depends_on: T-43] [files: -] rollback:不要

### 検証フェーズ

- [x] 🚩 T-45: 敵対レビュー R1（複数エージェント・allowlist の迂回路 / fail-open / 承認境界観点）→ 是正 [Owner: agent] [depends_on: T-44] [files: docs/working/TASK-0917/] rollback: 是正 commit 単位で git revert
- [x] 🚩 T-46: 敵対レビュー R2（R1 是正後の深掘り — **外部作用層は 1 ラウンドでは表層しか出ない** / #889 教訓）→ critical / major ゼロ収束まで [Owner: agent] [depends_on: T-45] [files: docs/working/TASK-0917/] rollback: 同上
- [x] T-47: AC-7 最終確認（`git diff --stat origin/main -- <3 ファイル>` = 0 行 / 57 テスト PASS / contract byte 一致） [Owner: agent] [depends_on: T-46] [files: -] rollback:不要
- [x] T-48: 受入基準 **AC-1〜AC-9 全確認**（`test-cases.md` 突合・全 TC 機械実行。**AC-6 は T-32 で実装したテストで確認**） [Owner: agent] [depends_on: T-47] [files: -] rollback:不要

### 完了フェーズ

- [x] T-49: コミット整理（1 コミット 1 種類・`Refs:` 付き）。**`docs/working/_audit/` への hook 由来追記（`skip-decision-log.jsonl` 等）は本 branch に含めず別 PR に分離する**（同ファイルは tracked かつ `allowed_paths` 21 件の**外**であり、混入すると `plan_deviation` → `EXEC_RETURN` を誘発する。`allowed_paths` を広げる方向の是正はしない = AC-5 / scope を緩めないため。R-035 系の RR-08 反映） [Owner: agent] [depends_on: T-48] [files: -] rollback: git reset（push 前のみ）
- [x] T-50: `status.md` / `current-state.md` 最終更新 + V2 候補（required checks の config キャッシュ / プロセス外の物理ガード / 実 API drift 検出 / **`ta-56-delivery.sh` のテスト件数ラベルの動的抽出**（R-033））を handoff へ記録 [Owner: agent] [depends_on: T-49] [files: docs/working/TASK-0917/] rollback:不要

## 👤 Humanタスク

- [x] **C-3**: plan / todo / test-cases の人間レビュー（critical 詳細・**Questions / Unknowns 10 件の明示判断**（うち R-021 の外部作用順序 / R-032 の plugin 配布同梱は C-2 由来の追加論点）・`approvals/c3.json` 発行） [Owner: human]
- [ ] **C-4**: PR レビュー・承認・マージ（GitHub 上。**merge は Human-owned / NO MERGE BY AI**） [Owner: human]
- [ ] E2E 後片付け: 検証用 PR の close / branch 削除（**Executor は原理的に実行できない**） [Owner: human]
- [ ] Q3 起票 issue（repo 設定の穴 3 件）の対応判断 — 本 PBI の完了条件外 [Owner: human]

## ⚠️ 依存関係

- Agent 実装（T-4 以降）→ **Human C-3 APPROVED（`approvals/c3.json`）後に exec 開始**
- T-35（実 PR への外部作用）→ **C-3 で D4-A と検証用 PR の選定が承認されていること**が前提。実行主体は **`gh` 認証済みの手元環境（人間起動）に固定**し CI 実行は scope 外（U-8 / R-030）
- PR 作成 → **Human C-4 承認後にマージ**（NO MERGE BY AI）
- carve-out ①② 該当のため **ai-loop 自走時は escalate 固定**（auto-approve 不可）
- #894 / #916 が先に merge された場合は Replan Trigger（接続前提の変更）で判断
