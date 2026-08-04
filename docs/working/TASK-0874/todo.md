# EXECUTION TODO — TASK-0874

> plan: [`plan.md`](./plan.md) / test-cases: [`test-cases.md`](./test-cases.md)
> Mode: **critical**（実装タスクは `rollback:` 記載必須）。L-0〜V-4・PR 作成は workflow-conductor が制御するため含めない。
> 実装は TDD（RED → GREEN → REFACTOR）で並べる。
> **不変（一行も触らない）**: `scripts/ai-loop/delivery.py` / `c3_contract.py` / `c3prime_verify.py` / `arbiter.py` / `metrics.py` / `schemas/`（HO）/ `docs/working/ai-loop-runs/` の既存 28 件 / `tests/run-tests.sh`
> **タスク総数: 44**（T-1 〜 T-44・欠番なし。**C-2 反映でタスクの新設・削除は行っていない** — 22 件の指摘はすべて既存タスクの内容是正に収まる）
> **対応 TC 総数: 65**（TC-01 〜 TC-65・欠番なし。C-2 で 56 → 65）
> **C-1 FAIL 是正（2026-08-02）**: ①`depends_on` の**循環（T-24 → T-32 → … → T-25 → T-24）を解消**（T-25 の依存を T-24 → T-23 へ是正）②旧 T-38 の **5 責務混在を 4 タスクに分割**（T-38 〜 T-41）③issue DoD の未カバー 2 項目（T-42 / T-43）と U-6 の帰結（T-44）を追加。
> **C-2 反映（2026-08-02 / `review-external.md` R-001 〜 R-C10・計 22 件）**: ①**`ta-58` → `ta-59`**（main に `ta-58-git-destructive-guard.sh` が実在・#968）②受理器の入力契約と schema 機械束縛（T-8 / T-10）③D3 負側 TC の追加（T-13 / T-16）④`--pr-number` 注入と `unavailable` fallback（T-12 / T-15）⑤`quality_metrics` の run 単位限定（T-12 / T-15 / T-20）⑥privacy の値レベル検査と入力ソース allowlist（T-22 / T-23）⑦EH-8 実走を ta-59 に内蔵（T-24 / T-33）⑧**T-18 の完了条件を exit 0 → exit 11 に是正**（R-006）⑨行番号 → **記号アンカー**（T-15 / T-26）⑩#874 の close 条件未達の明記（T-42）。

## 🤖 Agentタスク

### 準備フェーズ

- [x] 🚩 T-1: Scope / 受入基準（**AC-1〜AC-16 の 16 件**）と Out of scope（#869 clustering / #811 decision table の再定義・AI merge・active run への hot patch・SaaS 必須化）を再掲し作業範囲を固定。**C-3 で確定した Questions/Unknowns の未決 8 件（U-1 / U-4 / U-5 / U-8 / U-9 / U-10 / U-11 / U-12）の判断結果を反映**してから着手（U-2 / U-3 / U-6 / **U-7** は plan 段階で確定済み・追認のみ）+ **「#874 を OPEN のまま残す」の追認結果**（C-2 R-007） [Owner: agent] [depends_on: -] [files: -] rollback:不要
#### T-1 完了記録: C-3 で確定した Questions / Unknowns の判断結果（exec の前提・2026-08-04）

> 本表が exec 実装の唯一の前提。plan.md の「未決」記述より本表が優先する（plan.md は
> `plan_hash` 束縛のため一行も編集しない — `approvals/c3.json` は legacy 形式で
> `plan.md` の hash のみを束縛する。実測: `bin/plangate validate TASK-0874` = PASS）。

| ID | 確定内容 |
|----|---------|
| **U-1** | `harness_version` は **object 3 値** `{plugin_version, cli_version, corpus_hash}`。単一文字列にしない。schema の型を object にし、AC-12（active run 中に harness version が変化しない）は **3 値すべて**で検証する |
| **U-2** | `replan_count` は **Phase 1 は `unavailable` 固定**（plan 段階で確定済み・追認） |
| **U-3** | `cost_metrics` は **Phase 1 は `unavailable` 固定**（同上） |
| **U-4** | **plan 既定を採用**: 非終端 run は RunEvidence を**発行しない**（安全側。`IN_PROGRESS` の 4 値目を作らない） |
| **U-5** | **`repository` は owner 除去**（`s977043/plangate` → `plangate`）。**PR / コメント URL は番号のみに還元**（`https://github.com/…/pull/940#issuecomment-5140067809` → PR 番号 `940` + コメント ID `5140067809`）。**TC-51 の判定基準はこれで確定**（値レベルで `github.com` を含む URL・owner 名を保存しない。下流が URL を再構成する前提） |
| **U-6** | `schemas/` 昇格 PBI は**予約起票する**（plan 段階で確定済み・T-44） |
| **U-7** | schema / fixture は **Phase 1 では plugin 配布しない**（plan 段階で確定済み・追認） |
| **U-8** | **plan 既定を採用**: adapter IF は `source_run_ids` + `baseline_version` の**最小 2 フィールドから開始**し、下流が埋める境界を契約 doc に明記する |
| **U-9** | fixture 9（paired replay）/ 10（canary rollback）は **#874 の最小定義で作る**（Deferred にしない）。`len(glob) == 10` を維持。**#869 / #811 が別定義を採った場合に追従する前提**を handoff に記録する。代替案 (a)（`routing_decisions[]` の item schema 暫定定義）は**採らない** → fixture 6 の vacuity は明示して進む |
| **U-10** | Phase 1 は **`complete` に到達させない = producer 出力は全件 partial**（plan 既定・安全側）。known-unavailable allowlist は**置かない**。受理器の `exit 0` 経路は**合成 complete EV（TC-56）でのみ検証**する |
| **U-11** | 受理器 exit code は **前例準拠**（`0`=complete / `1`=NG / `10`=legacy / `11`=partial）（plan 既定の追認） |
| **U-12** | **plan 既定を採用**: `blocked_by[]` は **fail-closed**（キー欠落 = 判定不能 → `BLOCKED`、明示 `[]` のときのみ非 BLOCKED） |
| **追加** | **本 PBI 完了後も #874 は OPEN のまま残す**（close 条件は #869 / #811 完了後）— T-42 のコメント文面要件に反映する |

> **U-4 / U-8 / U-12 は「Phase 1 の既定」**であり、下流（#869 / #811）の plan 確定時に
> 見直す前提。**この見直し前提を契約 doc と handoff の両方に明記すること**（T-4 / T-41）。

- [x] T-2: **baseline 実測**（固定値を plan から持ち込まない）— 同一 checkout・同一ブランチで `sh tests/run-tests.sh </dev/null` を 1 回実行し PASS/FAIL 件数を `status.md` に記録 / `python3 scripts/ai-loop/metrics.py --format json` の現行出力（`legacy_count` / `run_count` / `invalid_run_meta_count` / `skipped_count`）を記録 / `git diff --stat origin/main -- '不変 7 対象のパスを列挙'` = 0 行を記録（⚠️ 山括弧はシェルのリダイレクト記号として解釈されるため、実行時はプレースホルダを実パスへ置換する） / **新規 ta 番号を再実測**（`git ls-tree origin/main --name-only tests/extras/ | grep -oE 'ta-[0-9]+' | sed 's/ta-//' | sort -n | tail -1`（⚠️ **`sort -u | tail` は辞書順**のため `ta-9` が `ta-58` より後ろに来て最大値を誤認する。数値部分を切り出して `sort -n` すること）。plan の `59` を鵜呑みにせず空き番号を確定する = C-2 追加是正） [Owner: agent] [depends_on: T-1] [files: -] rollback:不要
#### T-2 完了記録: baseline 実測値（worktree `plangate-wt-0874exec` / branch `feat/task-0874-exec` / base `origin/main` = `a667c0d`・2026-08-04）

| 項目 | 実測値 |
|------|-------|
| `sh tests/run-tests.sh </dev/null` | **513 passed / 0 failed**（exit 0）。統合担当の実測と再現一致 |
| `python3 scripts/ai-loop/metrics.py --format json` | `legacy_count=25` / `run_count=3` / `invalid_run_meta_count=0` / `skipped_count=0`（exit 0） |
| 不変 7 ファイル + `docs/working/ai-loop-runs/` + `tests/run-tests.sh` の `git diff --stat origin/main` | **0 行** |
| **新規 ta 番号** | **`ta-60`**（⚠️ plan / todo / test-cases が記載する `ta-59` は**使用済み**。`git ls-tree origin/main --name-only tests/extras/ \| grep -oE 'ta-[0-9]+' \| sed 's/ta-//' \| sort -n \| tail -1` = **59** で `ta-59-apply-settings-merge.sh`〔#976〕が実在。自 worktree で再実測して確認済み） |

> ⚠️ **`ta-60` は `plan_package.extract_allowed_paths(plan.md)` の `allowed_paths` に含まれない**（実測）。
> plan.md は `tests/extras/ta-59-run-evidence.sh` を**リテラルで固定**しているため、
> `arbiter.check_allowed_paths(["tests/extras/ta-60-run-evidence.sh"], allowed_paths)` = `(False, [...])` /
> `delivery._path_allowed(...)` = `False` になる（**両 matcher とも out-of-scope 判定**）。
> plan.md は `plan_hash` 束縛のため編集できない ⇒ **T-33 着手前に人間の scope 判断が必要**（本ワーカーのスコープ外・報告のみ）。

- [x] T-3: 接続点の契約を実測確認（`c3_contract.RECORD_REQUIRED_KEYS` 14 / `ARTIFACTS` 6 / `VALID_DECISIONS` 3 / `delivery.STATES` 7 + `EXITS` 2 / `delivery._completed_rounds()` / `delivery.load_entries()` の `entry_id` 再計算照合 / `c3prime_verify.main()` の exit 0/1/10 / `plan_package.serialize_c3_prime()` の serialization 形式 / `c3_contract.canonical_hash()`）。`delivery._completed_rounds(entries, None)` が **例外でなく `0` を返す**こと / `arbiter.check_allowed_paths()` と `delivery._path_allowed()` が **plan の `allowed_paths` を両方 in-scope と判定する**こと〔C-2 R-C02 / R-C04〕）。**再実装せず import 再利用する対象を確定** [Owner: agent] [depends_on: T-2] [files: -] rollback:不要

#### T-3 完了記録: 接続点の契約実測（2026-08-04・すべて plan 記述と一致）

| 接続点 | 実測値 | 再利用方針 |
|--------|-------|-----------|
| `c3_contract.RECORD_REQUIRED_KEYS` | **14**（`approval_kind` / `artifact_hashes` / `c1_evidence_ref` / `c2_evidence_ref` / `decision` / `issued_at` / `issued_by` / `phase` / `plan_hash` / `plan_package_hash` / `policy_ref` / `reviewers` / `source_sha` / `task_id`） | import 再利用 |
| `c3_contract.ARTIFACTS` | **6**（`pbi-input.md` / `plan.md` / `todo.md` / `test-cases.md` / `review-self.md` / `review-external.md`） | import 再利用 |
| `c3_contract.VALID_DECISIONS` | **3**（`AUTO_APPROVED` / `HUMAN_ESCALATED` / `BLOCKED`） | import 再利用 |
| `c3_contract.canonical_hash(obj)` | `-> str`・`sha256:` prefix 付き | **import 再利用**（独自 hash 実装ゼロ） |
| `delivery.STATES` / `EXITS` / `TERMINAL` | **7** / **2** / `MERGE_READY` | import 再利用（D3 の非終端 7 = STATES 6 + EXITS の `EXEC_RETURN`） |
| `delivery._completed_rounds(entries, None)` | **`0` を返す（例外にならない）** — 実 record（TASK-0917 e2e・3 行）で `(entries, 940) = 1` / `(entries, None) = 0` を再実測 | **`0` に倒さず `unavailable`**（C-2 R-C04 の fail-open 経路を塞ぐ） |
| `delivery.load_entries()` | 保存 `entry_id` を信用せず `entry_id(row)` で再計算照合し、不一致は `RecordError` | 受理器の tampered 検出に同型転写 |
| `delivery.entry_id(entry)` | `at` / `entry_id` を除いた core の `canonical_hash` | 同上 |
| `delivery.verify_c3(task_dir, expected_sha)` | `redirect_stderr(buf)` で `c3prime_verify.main(argv)` を呼び `(rc, stderr)` を返す | **実装形をそのまま転写**（検証ロジックを再実装しない） |
| `c3prime_verify.main()` exit | `0` 受理 / `1` NG（`_fail()` が stderr へ理由） / `10` legacy（`approval_kind` キーが**物理的に無い**場合のみ。未知値・型違いは `_fail`） | rc 意味論を本受理器に整合させる |
| `c3prime_verify` の未知キー allowlist | `unknown = [k for k in data if k not in ALLOWED_KEYS and not k.startswith("_")]` + `if k.startswith("_") and not isinstance(v, str): return _fail(...)` | 転写 |
| `c3prime_verify` の task_dir 束縛 | `if task_dir.name != task_id: return _fail(...)` | 転写 |
| `plan_package.serialize_c3_prime()` | `json.dumps(record, ensure_ascii=False, indent=2, sort_keys=True) + "\n"` | 転写 |
| `plan_package.PlanPackageError` | `Exception` 直下・errors リスト保持 | `RunEvidenceError(errors)` として同型実装 |
| `arbiter.check_allowed_paths()` / `delivery._path_allowed()` | 本 PBI の新規 6 ファイルは**両 matcher とも in-scope**（`(True, [])` / 全 `True`） | — |
| `schemas/c3-prime.schema.json`（構造前例） | `$schema` = draft 2020-12 / `$id` = `https://github.com/s977043/plangate/schemas/…` / `additionalProperties: false` / `patternProperties: {"^_": {"type": "string", "description": …}}` / `required` **14** / **`schema_version` を properties にも required にも持たない** | schema の構造前例（`schema_version` の非対称は契約 doc に明記） |
| `docs/schemas/` の現況 | 実在ファイルは **`child-pbi.yaml` 1 件のみ**（JSON Schema は 0 件） | `docs/schemas/run-evidence.schema.json` が同ディレクトリ初の JSON Schema |

### 契約 / schema フェーズ（AC-1 / AC-5）

- [ ] 🚩 T-4: `docs/workflows/ai-loop/run-evidence-contract.md` 新設 — 20 フィールド定義 + `evidence_status`（`complete`/`partial`）+ **D3 正規化マッピング表**（`delivery` 7+2 語彙 / `c3_contract` 3 語彙 → RunEvidence 3 値）+ versioning policy（破壊的変更は #872/#873/#874 の 3 issue 合意）+ **`observation` と `cause_hypothesis` のフィールド分離**（AC-5）+ **`terminal_state` × フィールドの必須/`unavailable` マトリクス**（`MERGE_READY` / `HUMAN_ESCALATED` / `BLOCKED` の 3 行。**`BLOCKED` は `record.jsonl` 不在のため delivery 層 4 フィールドが構造的に `unavailable`** = C-2 R-003）+ **known-unavailable の 2 分類**（(a) Phase 1 固定 3 / (b) `terminal_state` 依存 最大 4）+ **両受理器の rc 対応表**（`c3prime_verify.py` 0/1/10 と本受理器 0/1/10/11。**`bin/plangate` は 0/1 以外を catch-all で legacy にする**ため本受理器の rc を `_plangate_c3_dispatch` 経路へ流さない制約を併記 = C-2 R-C07）+ **受理器の署名 `run_evidence_verify.py <ev.json> <task_dir>` と再検証対象表**（C-2 R-004）+ **producer の入力ソース allowlist 4 種**（`approvals/c3.json` / `delivery/record.jsonl` / `docs/working/ai-loop-runs/*.json` / 注入値。C-2 R-010）+ **注入値 5 つと欠落時の既定**（`--now` / `--started-at` / `--repository` / `--run-id` は fail-closed / **`--pr-number` は `unavailable`** = C-2 R-C04）+ **producer 出力キーの全集合**（required 21 + `observation` / `cause_hypothesis` / `escalation`。`properties` と 1:1 = C-2 R-008）+ **`quality_metrics{}` の許可指標列挙**（当該 run で閉じる `first_pass` / `rounds` のみ。corpus 集計値を禁止 = C-2 R-005）+ **`schemas/c3-prime.schema.json` が `schema_version` を持たない非対称**の明記（C-2 R-C10 ②）+ EH-3 実効パターン（`schemas/*.schema.json`）と `ho-paths.md`（`schemas/**`）の**範囲差**の明記 + `docs/schemas/**` が rollout-policy §2 carve-out ①②③ の**いずれにも含まれない**非対称の明記 + **「`docs/schemas/` は schema 検証 CI 経路 0 本」だが「privacy CI（`**/*.json`）の走査対象には入る」**の書き分け（C-2 R-C09(b)）。⚠️ **リンクはインライン記法のみ**（参照定義 `[x]: ../y` と autolink `<../y>` は `_ai_loop_link_rewrite.py` が変換せず **ta-54 TC-01 が FAIL する** = C-2 R-C08）。⚠️ **禁止キー 14 個の一覧は本 doc（`.md`）側に置く**（schema の `properties` に禁止キー名を書くと EH-8 strict が BLOCK する = C-2 R-C09(b)）。**対応 TC: TC-05 / TC-17** [Owner: agent] [depends_on: T-3] [files: docs/workflows/ai-loop/run-evidence-contract.md] rollback: ファイル削除
- [ ] 🚩 T-5: `docs/schemas/run-evidence.schema.json` 新設（JSON Schema **draft 2020-12**・`$id` は**昇格後の URL** `https://github.com/s977043/plangate/schemas/run-evidence.schema.json` で先に固定 = HO patch を `git mv` 1 手に収める・`additionalProperties: false` **かつ `patternProperties: {"^_": {"type": "string"}}`**（前例 `schemas/c3-prime.schema.json` の**実値**と同型。`{}` だと**任意の型を許し**、`{"_note": {"a": 1}}` が schema を通って受理器が reject する**逆向きの食い違い**になる = C-2 R-C05。これが無いと **schema が `_note` を拒否し受理器が許容する**食い違いにもなる）・`task_id` は `^TASK-[0-9]{4}$`・hash は `^sha256:[0-9a-f]{64}$`・**`required` = 21**（issue の 20 フィールド + `schema_version`。`evidence_status` は受理器導出のため record に持たせない = plan D7-2 / D8）・**`properties` に `observation` / `cause_hypothesis` / `escalation` を必ず登録**（`additionalProperties: false` 下で `escalation` 未登録だと **privacy 違反や未知 `kind` を検知した EV だけが reject される** = C-2 R-008））。**対応 TC: TC-01〜TC-05 / TC-62** [Owner: agent] [depends_on: T-4] [files: docs/schemas/run-evidence.schema.json] rollback: ファイル削除
- [ ] T-6: schema と契約 doc の整合を機械確認（schema の `required` を `len()` で数えて **21**。内訳は**契約 doc の 20 フィールド表の行数 + `schema_version` 1 行**と一致すること。**目視で数えない**）+ **契約 doc の「producer 出力キー全集合」表と schema の `properties` キー集合が 1:1 で一致**（C-2 R-008）。**対応 TC: TC-04 / TC-05 / TC-62**[Owner: agent] [depends_on: T-5] [files: -] rollback:不要

### 受理器フェーズ（AC-4 / negative first）

- [ ] 🚩 T-7: `test_run_evidence_verify.py` RED その 1 — exit code 契約 4 値（`0` complete / `1` NG / **`10` legacy** / **`11` partial**。**`10` の意味は姉妹受理器 `c3prime_verify.py` L67 と一致させる** = plan D6 / U-11）の骨格。**対応 TC: TC-06 / TC-07 / TC-32 / TC-56** [Owner: agent] [depends_on: T-6] [files: scripts/ai-loop/test_run_evidence_verify.py] rollback: ファイル削除
- [ ] T-8: `test_run_evidence_verify.py` RED その 2 — tampered 群（`plan_hash` 1 文字改変 / `entry_id` 不一致 / `artifact_hashes` 不一致）が **exit 1**。未知トップレベルキーは reject、`^_` 注釈キーのみ許容（**値が string でなければ reject** = 前例 `c3prime_verify.py` の `if k.startswith("_") and not isinstance(v, str)` と同型 / C-2 R-C05）+ **schema 束縛の RED**（`schema["required"]` == 受理器の必須キー集合 / producer 出力キー ⊆ `properties` ∪ `^_`）。⚠️ **tampered の TC-08 は `<task_dir>` を渡す前提**（EV 単体入力では `sha256:`+64hex 形式を保った 1 文字改変を検出できず **exit 11 で通過する** = C-2 R-004）。**対応 TC: TC-08 / TC-09 / TC-61 / TC-62** [Owner: agent] [depends_on: T-7] [files: scripts/ai-loop/test_run_evidence_verify.py] rollback: git restore -- scripts/ai-loop/test_run_evidence_verify.py
- [ ] T-9: テスト実行し FAIL 確認（RED） [Owner: agent] [depends_on: T-8] [files: -] rollback:不要
- [ ] 🚩 T-10: `run_evidence_verify.py` 実装（GREEN）— **署名は `run_evidence_verify.py <ev.json> <task_dir>`**（姉妹受理器 `c3prime_verify.py <task_dir> [expected_sha]` と同型の task_dir 束縛 = C-2 R-004）。**schema を唯一の正として読み `required` / 許可キー集合を導出する**（ハードコードしない = C-2 R-008）+ `task_id` を `task_dir` 名に束縛（**記号アンカー = `c3prime_verify.py` の `task_dir.name != task_id` 分岐**を転写）+ **`plan_hash` / `source_sha` / `c3_prime_decision_ref` を `<task_dir>/approvals/c3.json` と、`final_head_sha` / `repair_rounds` を `<task_dir>/delivery/record.jsonl` の再計算値と再照合**（tampered 検出の唯一の経路）+ **`unavailable` 検出 → exit 11（partial）で `unavailable` フィールド名を stderr に全数列挙**（C-2 R-003）+ **legacy 判別 → exit 10**（**記号アンカー = `c3prime_verify.py` の `return 10  # legacy` 分岐**と同型）+ **`^_` 注釈キーは string のみ許容**（C-2 R-C05）。**合成 complete EV では exit 0 を返す**（TC-56。Phase 1 の producer 出力からは到達しないため、この経路を必ず 1 件検証する）。**`_fail()` は理由文字列を stderr に出す**（**記号アンカー = `c3prime_verify.py` の `_fail()`**）。**判定不能はすべてエラー側に倒す** [Owner: agent] [depends_on: T-9] [files: scripts/ai-loop/run_evidence_verify.py] rollback: ファイル削除

### producer フェーズ（AC-2 / AC-3 / AC-12）

- [ ] 🚩 T-11: `test_run_evidence.py` RED その 1 — **決定論**（同一入力 2 回 → byte 一致 / キー挿入順を変えても一致 / `--now` 未指定はエラー / ソースに `datetime.now`・`time.time`・`utcnow` が 0 件）。**対応 TC: TC-10〜TC-12** [Owner: agent] [depends_on: T-10] [files: scripts/ai-loop/test_run_evidence.py] rollback: ファイル削除
- [ ] T-12: `test_run_evidence.py` RED その 2 — **20 フィールドの供給元マッピング**（`plan_hash`/`source_sha`/`c3_prime_decision_ref` ← `c3.json` / `final_head_sha`/`ci_outcomes`/`review_findings`/`repair_rounds` ← `record.jsonl` / `human_interventions` ← 両方）。`repair_rounds` は `delivery._completed_rounds()` の戻り値と一致（import して照合・再実装しない）+ **`pr_number` が解決できない場合は `repair_rounds` が `unavailable`**（⚠️ 実測で `_completed_rounds(entries, None)` は**例外にならず `0` を返す**ため、`0` に倒すと fail-open する = C-2 R-C04）+ **`quality_metrics{}` が `first_pass` / `rounds` の 2 指標のみ**で corpus 集計値（`decision_counts` / `round_distribution` / `hotl_health` / `first_pass_rate`）を含まない（C-2 R-005）+ **`terminal_state` の 3 値導出**（`MERGE_READY` / `BLOCKED` / 非終端 7 状態）。**対応 TC: TC-13〜TC-16 / TC-57 / TC-58 / TC-59 / TC-60 / TC-64** [Owner: agent] [depends_on: T-11] [files: scripts/ai-loop/test_run_evidence.py] rollback: git restore -- scripts/ai-loop/test_run_evidence.py
- [ ] T-13: `test_run_evidence.py` RED その 3 — **`unavailable` と `0` / 空配列の区別**（`routing_decisions` 未供給 = `unavailable` ≠ 空配列の明示供給）+ **未知 `kind` entry**（`notice` 等）を握り潰さず `escalation` に記録 + `harness_version` の run 中変化で fail-closed。+ **`evidence_refs[]` をディスク走査で列挙しない**（注入値または record 由来のみ = C-2 R-012）。**対応 TC: TC-52（`unavailable` ≠ 空配列）/ TC-53（未知 `kind`）/ TC-30 / TC-31**（C-1 是正: 旧記載の「対応 TC: TC-30 / TC-31」は `harness_version` の TC しか指しておらず、本タスクが宣言する挙動に対応 TC が無かった） [Owner: agent] [depends_on: T-12] [files: scripts/ai-loop/test_run_evidence.py] rollback: git restore -- scripts/ai-loop/test_run_evidence.py
- [ ] T-14: テスト実行し FAIL 確認（RED） [Owner: agent] [depends_on: T-13] [files: -] rollback:不要
- [ ] 🚩 T-15: `run_evidence.py` 実装（GREEN）— **転写する具体パターン**: ①`plan_package.serialize_c3_prime()` L343 の `json.dumps(ensure_ascii=False, indent=2, sort_keys=True) + "\n"` ②`c3_contract.canonical_hash()` を **import 再利用**（独自 hash 実装ゼロ）③`plan_package.PlanPackageError` 型の **errors リスト保持例外**（1 件目で止めず全件収集）④`delivery.py` module docstring の **「決定論:」箇条**（`timestamp は --now 注入 / now() を直接参照しない`）の転写。⚠️ **記号アンカーで特定すること** — 当初記載の「docstring L15-16」は実測で **「純判定器: ネットワーク・外部プロセスを一切呼ばない」の行**を指しており内容が違う（`--now` 注入の記述は L9-10）。行番号に従うと **`--now` 必須化（TC-12）が落ちる**（C-2 R-C06）。**ネットワーク・外部プロセスを一切呼ばない**・**読むファイルは入力ソース allowlist 4 種のみ**（C-2 R-010）。**注入値は 5 つ**（`--now` / `--started-at` / `--repository` / `--run-id` は未注入でエラー、**`--pr-number` は未解決なら `repair_rounds` 等を `unavailable`** = C-2 R-C04）。**`quality_metrics{}` は当該 run で閉じる指標のみ**・**`evidence_refs[]` はディスク走査しない**（AC-2 の決定論保護 = C-2 R-005 / R-012）。**出力先**: 既定は **stdout へ 1 record**（保存先は呼び出し側が決める）。`--out <path>` 指定時のみファイルへ書き、**拡張子が `.json` でなければ reject**（`.jsonl` は EH-8 の走査対象から外れる） [Owner: agent] [depends_on: T-14] [files: scripts/ai-loop/run_evidence.py] rollback: ファイル削除
- [ ] 🚩 T-16: **D3 正規化マッピングの実装** — `MERGE_READY` は `record.jsonl` に `kind=merge_ready` entry が**物理的に存在する**ときのみ（**記号アンカー = `delivery.assess()` の `state = "MERGE_READY"` 分岐**が刻む唯一の経路）。`BLOCKED`/`HUMAN_ESCALATED` は c3-prime `decision` と最終 `state` entry から。**`BLOCKED` は `record.jsonl` 自体が存在しない**ため delivery 層 4 フィールド（`final_head_sha` / `ci_outcomes` / `review_findings` / `repair_rounds`）を **`unavailable`** に倒す（ダミー sha や空文字で埋めない = C-2 R-003）。**非終端 7 パターン（`WAITING_FOR_CHECKS`/`WAITING_FOR_REVIEW`/`CHECKS_FAILED`/`CONFLICT`/`REVIEW_REPAIR`/`MERGE_READY_CANDIDATE`/`EXEC_RETURN`）はすべて `evidence_status=partial`** で発行しない（U-4 が C-3 で `IN_PROGRESS` 採用に決まった場合は本タスクを改訂）。**対応 TC: TC-57（`MERGE_READY` 正側）/ TC-58（`BLOCKED` 正側）/ TC-59（非終端 7 状態を parametrized で発行拒否）**（⚠️ **当初は本タスクだけ「対応 TC」を持たず、plan が「最重要の設計論点」とした D3 に負側 TC が 1 件も無かった** = C-2 R-001）[Owner: agent] [depends_on: T-15] [files: scripts/ai-loop/run_evidence.py] rollback: git restore -- scripts/ai-loop/run_evidence.py
- [ ] T-17: `observation` / `cause_hypothesis` の分離実装（AC-5）— producer は `cause_hypothesis` を**自動生成しない**（未注入なら `null`/`unavailable`）。**対応 TC: TC-18** [Owner: agent] [depends_on: T-16] [files: scripts/ai-loop/run_evidence.py] rollback: git restore -- scripts/ai-loop/run_evidence.py
- [ ] T-18: テスト実行し PASS 確認（GREEN）+ `run_evidence_verify.py` が producer 出力を **exit 11（partial）で受理し、`unavailable` フィールド名を stderr に列挙する**ことを確認。⚠️ **当初記載の「exit 0 で受理」は plan D7-1 により構造的に達成不能**（Phase 1 は known-unavailable により必ず partial）であり、そのままだと exec が本タスクで必ず停止し、実装者が最短の是正として **`routing_decisions` を `[]` で埋める fail-open** へ誘導される（= plan が TC-52 / Risks 第 1 行で最も避けようとしている型 / C-2 R-006）。**U-10 が known-unavailable allowlist 採用に決まった場合のみ exit 0 に戻す** [Owner: agent] [depends_on: T-17] [files: -] rollback:不要

### legacy 互換フェーズ（AC-15）

- [ ] 🚩 T-19: `test_run_evidence.py` に legacy 4 分類の RED を追加 — `metrics.py` の分類ラベル（`legacy` = `"run" not in record` / `invalid run meta` = `run_id` 非空文字列でない / `skipped` = 破損 JSON・非 dict・`decision` 欠落で**理由文字列必須** / `run record`）と恒等式 **`total_records == len(legacy_records) + len(invalid_meta_records) + len(run_records)`**（⚠️ `run_count` **ではない**。実測で `metrics.py` L240 の `run_count = len(grouped)` は **distinct `run_id` 数**であり、1 run が複数 record を持つ入力では `len(run_records)` と一致しない。現データ 28 件では偶然一致するため回帰では検出できない）+ **`run_count == len(set(run_id))`** を別 assert にする。**対応 TC: TC-42〜TC-44 / TC-54** [Owner: agent] [depends_on: T-18] [files: scripts/ai-loop/test_run_evidence.py] rollback: git restore -- scripts/ai-loop/test_run_evidence.py
- [ ] T-20: `run_evidence.py` に分類関数を実装（GREEN・`metrics.py` を import せず**同一ロジックを転写**して独立させる。`metrics.py` は不変対象のため依存を増やさない）。⚠️ **本タスクの対象は legacy 4 分類のみ**であり `quality_metrics{}` は別（`quality_metrics` も `metrics.py` を import せず、**当該 run で閉じる `first_pass` / `rounds` の導出規則のみ**を転写する = C-2 R-005）。⚠️ **`metrics.py` の `skipped` は `{"file": str(path), …}` を記録し絶対パスになりうる**（キー名が `file` のため EH-8 では捕捉できず素通り = 実測）。転写先では **repo 相対パスへ正規化するか EV に載せない**（C-2 R-C09(a)）[Owner: agent] [depends_on: T-19] [files: scripts/ai-loop/run_evidence.py] rollback: git restore -- scripts/ai-loop/run_evidence.py
- [ ] 🚩 T-21: **実データ 28 件で回帰確認** — `docs/working/ai-loop-runs/` を入力に `legacy_count=25` / `run_count=3` / `invalid_run_meta_count=0` / `skipped_count=0` が T-2 の記録値と一致。かつ `git diff --stat docs/working/ai-loop-runs/` が**空**（既存 28 件を 1 バイトも変更していない）。**対応 TC: TC-42 / TC-45** [Owner: agent] [depends_on: T-20] [files: -] rollback:不要

### privacy フェーズ（AC-6）

- [ ] 🚩 T-22: `test_run_evidence.py` に privacy の RED を追加 — **禁止キー 14 個**（`file_path`/`file_paths`/`stack_trace`/`stacktrace`/`command_output`/`stdout`/`stderr`/`raw_response`/`raw_request`/`api_key`/`user_prompt`/`system_prompt`/`prompt_text`/`absolute_path`）が出力に 0 件 / `evidence_refs` の絶対パス reject / 出力拡張子が `.json`（`.jsonl` にすると EH-8 の走査対象から外れる）/ **account 識別子（GitHub username 等）が出力に現れない**（EH-8 の禁止キー 14 個に account 系は無く機械層を素通りするため、producer 側で検査する。⚠️ **判定基準は U-5 の C-3 結論に従う** — 実 record の `comment_url` / `result_ref` は `s977043` を含み、厳格適用すると AC-11 の `improvement_refs[]` と両立しない = C-2 B→A-5）+ **全フィールドの値に絶対パス（`^/` / `/Users/`）が 0 件**（⚠️ EH-8 は**キー名の grep のみで値を見ない** — `{"file": "/var/folders/…"}` は strict でも PASS を実測 = C-2 R-C09(a)。`evidence_refs` 限定の検査では不足）+ **producer が読むファイルが入力ソース allowlist 4 種に閉じる**（ソース走査 + monkeypatch。AC-6 の「**要求しない**」側 = C-2 R-010）。**対応 TC: TC-19〜TC-21 / TC-51 / TC-63 / TC-65** [Owner: agent] [depends_on: T-21] [files: scripts/ai-loop/test_run_evidence.py] rollback: git restore -- scripts/ai-loop/test_run_evidence.py
- [ ] T-23: `run_evidence.py` に privacy フィルタを実装（GREEN）— 禁止キーを**握り潰さず** `escalation` に記録して fail-closed。`evidence_refs` は repo 相対パスのみ。**絶対パス検査は `evidence_refs` 限定でなく全フィールドの値**に適用する（C-2 R-C09(a)）。**入力ソース allowlist 4 種以外を open しない**（C-2 R-010） [Owner: agent] [depends_on: T-22] [files: scripts/ai-loop/run_evidence.py] rollback: git restore -- scripts/ai-loop/run_evidence.py
- [ ] 🚩 T-24: **EH-8 実走で証明**（自主規制で終わらせない）— fixture 生成後に **`PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_FILES="<10 fixture のパス>" sh scripts/hooks/check-metrics-privacy.sh`** を実行し PASS を確認し、**同じ実行を ta-59（T-33 ③）にも内蔵する**。⚠️ **`git add` だけに頼らない**: `.github/workflows/metrics-privacy.yml` の scan 対象は `grep -v '^tests/fixtures/'` で **`tests/fixtures/` を明示除外**しており（実測）、`.claude/settings.example.json` の hooks にも EH-8 は**存在しない**。⇒ **本 PBI が commit する 10 fixture に対してだけ CI の自動強制が効かない**（C-2 R-C03）。TASK-0917 では同 hook が実際に `stdout`/`stderr` を BLOCK した実績がある。**対応 TC: TC-22**。⚠️ **本タスクだけ実行順序が前後する**（fixture 生成 T-32 の完了後に実行する。番号順に流すと fixture が存在せず空振りするため） [Owner: agent] [depends_on: T-32] [files: -] rollback: 違反検出時は該当 fixture を再生成（unstage → 修正 → 再 add）

### c3-prime 接続フェーズ（AC-14）

- [ ] 🚩 T-25: `docs/workflows/ai-loop/c3-prime-contract.md` **§7 に #874 consumer 節を additive 追記** — 読むフィールド 5 つ（`task_id`/`decision`/`source_sha`/`plan_hash`/`plan_package_hash`）+ trust boundary（§7 の「decision 値を無検証で信頼してはならない」を #874 にも適用）。**§1〜§6 と §8 は一行も触らない**（§8 は既に「#872/#873/#874 の 3 issue 合意」を含むため**重複追記しない**）。**対応 TC: TC-38 / TC-39** [Owner: agent] [depends_on: T-23] [files: docs/workflows/ai-loop/c3-prime-contract.md] rollback: git restore -- docs/workflows/ai-loop/c3-prime-contract.md
- [ ] 🚩 T-26: producer に **§4 全規則の fail-closed 再検証**を組み込む — `c3prime_verify.main([_, task_dir, expected_sha])` を呼んで rc==0 を要求（**記号アンカー = `delivery.verify_c3()`** の `redirect_stderr(buf)` 実装形をそのまま転写し、検証ロジックを再実装しない。⚠️ 当初記載の「L498-509」は実測 L498-505 で範囲過大 = C-2 R-C06）。`decision` を無検証で信頼しない。**対応 TC: TC-40 / TC-41** [Owner: agent] [depends_on: T-25] [files: scripts/ai-loop/run_evidence.py] rollback: git restore -- scripts/ai-loop/run_evidence.py
- [ ] T-27: `git diff origin/main -- docs/workflows/ai-loop/c3-prime-contract.md` を確認し **§7 以外の行が変更されていない**ことを機械照合 [Owner: agent] [depends_on: T-26] [files: -] rollback:不要

### consumer adapter フェーズ（AC-7 / AC-8 / AC-9 / AC-11 / AC-13）

- [ ] 🚩 T-28: `test_run_evidence.py` に adapter の RED を追加 — `to_shadow_candidate_input()`（3 件以上必須 / 2 件は `insufficient_evidence` / `harness_version` 混在は `mixed_baseline` で reject / **綴りは `source_run_ids` と `baseline_version`**。⚠️`baseline_harness_version` は repo にも issue にも 0 件のため使わない）+ `to_promotion_provenance()`（#811 Trust Ledger の実測綴り / **`blocked_by[]` 非空 → `BLOCKED`** / **`blocked_by` キーが物理的に存在しない（未注入）→ 判定不能として `BLOCKED`**（fail-closed。空配列を「未解決なし」と解釈するのは**明示注入された `[]` のときだけ**。この既定が無いと誰も埋めない限り常に非 BLOCKED = AC-13 が fail-open する）/ **issue 番号ハードコード禁止**）+ improvement TASK 記述子（`skip_c3`/`auto_merge` 等の迂回キーが現れたら FAIL）。**対応 TC: TC-23〜TC-29 / TC-33 / TC-36 / TC-37 / TC-55** [Owner: agent] [depends_on: T-27] [files: scripts/ai-loop/test_run_evidence.py] rollback: git restore -- scripts/ai-loop/test_run_evidence.py
- [ ] 🚩 T-29: adapter 実装（GREEN）— **再実装せず provenance 橋渡しのみ**（#869 clustering / #811 decision table を作らない）。adapter は **`EV` 以外の I/O を持たない**（AC-7 の構造保証・monkeypatch で固定）[Owner: agent] [depends_on: T-28] [files: scripts/ai-loop/run_evidence.py] rollback: git restore -- scripts/ai-loop/run_evidence.py
- [ ] T-30: paired replay / rollback の橋渡し実装（AC-10）— `baseline_run_ids` と `candidate_run_ids` が互いに素 / failed canary で `candidate.status` が `rolled_back` に遷移し `rollback_count` が +1。**対応 TC: TC-34 / TC-35** [Owner: agent] [depends_on: T-29] [files: scripts/ai-loop/run_evidence.py] rollback: git restore -- scripts/ai-loop/run_evidence.py
- [ ] T-31: テスト実行し PASS 確認（GREEN） [Owner: agent] [depends_on: T-30] [files: -] rollback:不要

### fixture / E2E フェーズ（AC-16）

- [ ] 🚩 T-32: **golden fixture 10 件**を生成し commit（`fx-01-first-pass` / `fx-02-ci-repair` / `fx-03-review-repair` / `fx-04-human-escalated` / `fx-05-blocked` / `fx-06-routing-escalation` / `fx-07-tampered-expected-errors` / `fx-08-shadow-candidate-input` / `fx-09-paired-replay` / `fx-10-canary-rollback`）。**入力 events は test 内で構築**し golden 出力のみ commit。**fixture 2 の入力形状は実在の `docs/working/TASK-0917/evidence/e2e/run/delivery/record.jsonl`（実測 3 行 = intent/notice/receipt）に照らす**（手書き fixture の乖離防止）。⚠️ **この実 record は `kind=state` も `kind=merge_ready` も含まない**ため、D3 マッピングの中核については裏を取れない — fixture 表に「**実 record で裏が取れる範囲**」と「**手書きに留まる範囲**」を書き分ける（C-2 B→A-4）。⚠️ **fixture 6（routing escalation）は Phase 1 で fixture 4 と区別不能**（`routing_decisions` が常に `unavailable` のため routing 実カバレッジ 0 = 実質 9 fixture）。**この vacuity を fixture 表に明示する**（C-2 R-002。U-9 の代替案 (a) が C-3 で採用された場合は item schema 注入型に改訂）。`len(glob)` == **10** を assert（**11 件に増やさない** — issue が必須 fixture を 10 件と verbatim 指定）。**期待受理器 exit は fixture 1〜6 が すべて `11`（partial）**（Phase 1 は known-unavailable により exit 0 に到達しない = plan D7）。**fixture 5（`BLOCKED`）は `record.jsonl` 不在のため delivery 層 4 フィールドも `unavailable`** になる（exit は同じ `11` だが **`unavailable` の内訳が違う**ため TC-58 で内訳まで assert する = C-2 R-003）、**fixture 7 はケースごとに一意**（`tampered` → `1` / `partial` → `11`。「1 または 10」のような二値の期待値を golden に残さない）。**対応 TC: TC-48 / TC-58 + fixture↔AC 対応表** [Owner: agent] [depends_on: T-31] [files: tests/fixtures/run-evidence/] rollback: ディレクトリ削除（producer が決定論なので完全再生成可能）
- [ ] 🚩 T-33: `tests/extras/ta-59-run-evidence.sh` 新設（⚠️ **番号は T-2 で再実測した空き番号**。`ta-58` は main に `ta-58-git-destructive-guard.sh` が実在するため使えない = #968 / C-2 追加是正）— ①10 fixture の golden 再生成 + byte 比較 ②受理器 exit code 4 値の検証 ③**`python3 <root>/scripts/ai-loop/test_run_evidence.py` と `test_run_evidence_verify.py` の 2 本を 1 モジュール 1 PASS 行で実行**（**これが無いと新規 unit test が一度も実行されない** — `run-tests.sh` は python を呼ばず `ta-*.sh` を glob source するだけ / TASK-0917 R-020 の実害型）④**EH-8 本体の実走**（`PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_FILES="<10 fixture>" sh "$PG_ROOT/scripts/hooks/check-metrics-privacy.sh"`。privacy CI が `tests/fixtures/` を除外しているため CI 任せにできない = C-2 R-C03）。**規約**: `pass`/`fail` 直接更新 / `trap` 不使用 / `register_cleanup` + 末尾明示 `rm -rf` の二重 / 変数は `_t59_` プレフィクス / `rc=0` 初期化してから `out="$(cmd)" || rc=$?`。**対応 TC: TC-22 / TC-46〜TC-48** [Owner: agent] [depends_on: T-32] [files: tests/extras/ta-59-run-evidence.sh] rollback: ファイル削除
- [ ] T-34: `sh tests/run-tests.sh </dev/null` を 1 回実行し exit 0 + **T-2 の baseline + ta-59 の新規 PASS 行数**を下回らないことを確認（2 本の PASS 行が出力に現れることを **grep で**確認・目視不可）。**`</dev/null` を付けないと `precompact-memory-guard.sh` でハングする**。あわせて `git diff origin/main -- tests/run-tests.sh` = 0 行（TC-49） [Owner: agent] [depends_on: T-33] [files: -] rollback:不要

### 配布同期フェーズ

- [ ] 🚩 T-35: `scripts/sync-plugin-plangate.sh` の **2 箇所**へ新規 4 本（`run_evidence.py` / `test_run_evidence.py` / `run_evidence_verify.py` / `test_run_evidence_verify.py`）を追加 — **記号アンカーで位置特定**（行番号 L348 / L360 は 2026-08-02 時点の目安で stale 化する）: ①`for _f in "$AI_LOOP_SCRIPTS_DIR/arbiter.py" …` ②`arbiter.py|test_arbiter.py|…) : ;;`。**現行は各 24 エントリ（実測）→ 各 28 になる** [Owner: agent] [depends_on: T-34] [files: scripts/sync-plugin-plangate.sh] rollback: git restore -- scripts/sync-plugin-plangate.sh
- [ ] 🚩 T-36: **2 箇所の basename 集合を diff して差分 0** を機械照合（片方漏れ = sync drift の検出専用タスク） [Owner: agent] [depends_on: T-35] [files: -] rollback:不要
- [ ] T-37: sync 実行 → 2 回目 no-op → `git diff --quiet plugin/` 確認。`docs/workflows/ai-loop/run-evidence-contract.md` は **glob 同期のため whitelist 追加不要**であることも確認（`plugin/plangate/skills/ai-loop-cycle/references/` に出現する）[Owner: agent] [depends_on: T-36] [files: plugin/plangate/] rollback: git restore -- plugin/ scripts/sync-plugin-plangate.sh

### 検証フェーズ

> **C-1 是正（C1-SUP-PLAN-02 FAIL）**: 旧 T-38 は「R1 / R2 / 49 TC 全件実行 / 不変差分 0 / commit 整理 + status + handoff」の
> **5 責務を 1 チェックボックスに束ねており**、reviewer が Task 単位で approve / reject を判断できず（「R1 は通ったが handoff 未記載」の
> 部分状態を表現できない）、rollback も**タスク単位でない**戻し手順になっていた。critical の failure_policy「責務混在は FAIL」に直接該当するため、
> **独立に検証可能な 4 タスク（T-38 〜 T-41）へ分割**した。

- [ ] 🚩 T-38: **敵対レビュー R1**（複数エージェント・観点: fail-open していないか / `unavailable` と `0`・空配列の混同 / privacy 迂回路 / 下流語彙の乖離）を実施し、**検出された critical / major の全件に「是正 commit」または「却下理由」を 1:1 で対応付ける**。完了判定: R1 レポートが `docs/working/TASK-0874/evidence/` に存在し、**未対応の critical / major が 0 件** [Owner: agent] [depends_on: T-37] [files: docs/working/TASK-0874/evidence/] rollback: R1 起因の是正 commit を `git revert`（push 前なら `git restore`）
- [ ] 🚩 T-39: **敵対レビュー R2**（R1 是正後の深掘り。**契約層は 1 ラウンドでは表層しか出ない** — #889 / TASK-0917 の教訓）を実施し **critical・major ゼロ収束**まで回す。完了判定: R2 レポートが存在し、**最終ラウンドの critical = 0 かつ major = 0** [Owner: agent] [depends_on: T-38] [files: docs/working/TASK-0874/evidence/] rollback: R2 起因の是正 commit を `git revert`（push 前なら `git restore`）
- [ ] 🚩 T-40: **全 TC の機械実行 + 不変対象の差分 0 確認**。①`test-cases.md` の **65 TC を全件機械実行**して PASS（**未実行 / SKIP 0 件**。SKIP は環境依存を理由に許容しない）②`git diff --stat origin/main -- scripts/ai-loop/delivery.py scripts/ai-loop/c3_contract.py scripts/ai-loop/c3prime_verify.py scripts/ai-loop/arbiter.py scripts/ai-loop/metrics.py docs/working/ai-loop-runs/ tests/run-tests.sh` が **0 行**。⚠️ **T-24（EH-8 実走）の完了も本タスクの前提**（依存に明示） [Owner: agent] [depends_on: T-39, T-24] [files: -] rollback:不要
- [ ] 🚩 T-41: **完了処理** — コミット整理（1 コミット 1 種類・`Refs:` 付き。**`docs/working/_audit/` への hook 由来追記（`skip-decision-log.jsonl` 等）は本 branch に含めず別 PR に分離**）+ `status.md` / `current-state.md` / `handoff.md` を更新し、**AC↔fixture 対応表**（AC-16 が要求）と V2 候補（`harness_version` 構造検証 TC / `cost_metrics` 収集経路 / schema・fixture の plugin 配布 / U-10 が allowlist 採用に決まった場合の fixture 期待値差し戻し）を記録。完了判定: handoff の**必須 6 要素がすべて非空** [Owner: agent] [depends_on: T-40] [files: docs/working/TASK-0874/] rollback: `git restore -- docs/working/TASK-0874/`

### DoD 外部反映フェーズ（issue #874 DoD の未カバー 2 項目 / C1-PLAN-01 ② 是正）

> 当初 plan / todo には issue 本文 DoD の 2 項目（issue コメントの link / #870 Evolution DoD への反映）に
> 対応する Step / T が**存在しなかった**。以下 2 タスクで明示的に担う。**PR 作成後・C-4 前**に実行する。

- [ ] T-42: **issue #874 に DoD コメントを投稿** — schema（`docs/schemas/run-evidence.schema.json`）/ test command（`python3 scripts/ai-loop/test_run_evidence.py` 他）/ sample record（golden fixture 1 件）/ integration log（ta-59 の実行結果）への **4 link を含める**。⚠️ **コメント本文に「Phase 1 契約層のみ充足・close 条件未達」を必ず明記する**（issue DoD は「#869 shadow mode の統合 test」「#811 promotion provenance test」を要求し、末尾で「**効果測定なしでは close しない**」と明示している。#869 / #811 未実装のため **本 PBI 完了時点で DoD は充足不能**であり、4 link だけを投稿すると DoD が形式上埋まったように見えて「効果測定なしの close」に加担する = C-2 R-007）+ **routing 実カバレッジ 0（fixture 6 の vacuity）も併記する**（C-2 R-002）。完了判定: `gh issue view 874 --comments` に当該コメントが存在し 4 link すべてが解決可能、**かつ close 条件未達の明記がある** [Owner: agent] [depends_on: T-41] [files: -] rollback: `gh issue comment --edit-last` で訂正（コメント削除は行わない）
- [ ] T-43: **#870 の Evolution DoD へ evidence link を反映** — 親 EPIC #870 に本 PBI の evidence link（PR / fixture / 契約 doc）を反映する。完了判定: `gh issue view 870` に当該 link が存在 [Owner: agent] [depends_on: T-42] [files: -] rollback: `gh issue comment --edit-last` で訂正
- [ ] T-44: **`schemas/` 昇格 PBI の予約起票**（U-6 の plan 段階判断の帰結 — 裁定正本 §8-3 が「予約起票するかを plan 段階で判断」と指定）。#870 の後続として issue を起票し、本文に「`docs/schemas/run-evidence.schema.json` → `schemas/` への `git mv` + `$id` 1 行変更（**HO patch = 適用は Human-owned**）」「昇格判定は Gate 接続 PR の Human C-3 チェックリスト」を記載。完了判定: issue 番号が handoff に記録されている。⚠️ **起票のみ（AI-owned）。昇格 patch の適用は行わない** [Owner: agent] [depends_on: T-43] [files: -] rollback: 起票した issue を close

## 👤 Humanタスク

- [ ] **C-3**: plan / todo / test-cases の人間レビュー（**critical のため詳細レビュー必須・autonomous APPROVE 不可**）。**Questions / Unknowns の未決 8 件（U-1 / U-4 / U-5 / U-8 / U-9 / U-10 / U-11 / U-12）の明示判断**（U-7 は C-2 R-009 で plan 確定へ降格・追認のみ）+ **「本 PBI 完了後も #874 は OPEN のまま」の追認**（C-2 R-007）+ `approvals/c3.json` 発行。⚠️ **U-10（Phase 1 で complete に到達させるか）と U-11（exit code 値割当）は下流 2 PBI の受理条件・既存受理器との整合に関わるため、plan の既定を追認するか覆すかを明示すること** [Owner: human]
- [ ] **C-4**: PR レビュー・承認・マージ（GitHub 上。**merge は Human-owned / NO MERGE BY AI**）[Owner: human]
- [ ] `schemas/` 昇格 PBI（HO patch）の**適用**判断 — 予約起票自体は plan 段階で「する」と確定済み（U-6 / T-44）。**HO patch の適用は Human-owned**であり本 PBI の完了条件外 [Owner: human]

## ⚠️ 依存関係

- Agent 実装（T-4 以降）→ **Human C-3 APPROVED（`approvals/c3.json`）後に exec 開始**（critical のため autonomous APPROVE 不可）
- **T-1 は C-3 の判断結果（未決 8 件）を入力とする**。特に **U-1（`harness_version` の定義）が未確定のまま T-15 / T-16 に進まない**（AC-12 の実装が確定しないため）
- **U-4（非終端 run の扱い）が `IN_PROGRESS` 採用に決まった場合、T-16 と TC-07 / TC-16 / Edge cases を改訂**してから実装する
- **U-10（Phase 1 の complete 到達可否）が known-unavailable allowlist 採用に決まった場合、T-10 / T-32 と fixture 1〜6 の期待 exit・TC-56 を改訂**してから実装する
- **U-11（exit code 値割当）が独自割当（`10`=partial / `11`=legacy）に決まった場合、T-7 / T-10 / TC-07 / TC-32 / Edge cases / fixture 表を一括改訂**してから実装する
- **U-5（`repository` / PR 参照と privacy）の結論が TC-51 の判定基準を確定させる**（C-2 R-011 / B→A-5）。厳格側（account 識別子を値レベルで 0 件）に決まった場合、**AC-11 の `improvement_refs[]` の表現方法**（PR 番号のみ / repo 名を除いた相対参照 等）を T-28 / T-30 と併せて改訂してから実装する
- **U-9 の代替案 (a)（`routing_decisions[]` の item schema を暫定定義）が採用された場合、T-4 / T-5 / T-32 / TC-50 / fixture 6 を改訂**してから実装する（C-2 R-002）
- **T-24（EH-8 実走）は番号順に流さない** — `depends_on: T-32`（fixture 生成）であり、T-32 完了後に実行する。番号順（T-23 → T-24 → T-25）で流すと fixture が未生成で空振りする。これが唯一の番号順と依存順が食い違うタスク（意図的）
  - ⚠️ **C-1 是正（C1-TODO-09 FAIL）**: 当初は T-24 を後方参照（`depends_on: T-32`）にした一方で **T-25 が `depends_on: T-24` のまま**だったため、
    **T-24 → T-32 → T-31 → T-30 → T-29 → T-28 → T-27 → T-26 → T-25 → T-24 の閉路**が成立し、T-25〜T-32 の 8 タスクが依存解決不能（機械的実行器ならデッドロック）だった。
    **T-25 の依存を T-23 へ是正**した（T-25 は c3-prime-contract の doc 追記であり、privacy hook の実走 T-24 を前提としない。producer 側の直前タスクは T-23）。
    これにより閉路が解け、**T-24 は「T-32 完了後に実行する遅延タスク」**として枝になる。
  - 遅延タスクが完了処理より後ろにずれ込まないよう、**T-40（全 TC 実行 + 不変差分確認）が `depends_on: T-39, T-24` で T-24 を明示的に取り込む**（T-24 が dependent を持たない孤立枝になることを防ぐ）
- PR 作成 → **Human C-4 承認後にマージ**（NO MERGE BY AI）
- **carve-out ①②該当のため ai-loop 自走時は escalate 固定**（auto-approve 不可。`rollout-policy.md` §2）
- #869 / #811 / #894 / #908 が先に merge された場合は **Replan Trigger**（接続前提の変更）
