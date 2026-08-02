---
task_id: TASK-0874
artifact_type: review-self
schema_version: 1
status: draft
verdict: FAIL
created_by: orchestrator
---

# TASK-0874 セルフレビュー結果（C-1）

> レビュー日: 2026-08-02
> 対象: `plan.md`（444 行）/ `todo.md`（104 行）/ `test-cases.md`（198 行）@ `feat/task-0874-plan` `388677d`（base = `origin/main` = `a4afacb`）
> Mode: **critical** → **簡易版でなく全項目版**を実行
> 実行項目数: **25**（`grep -c "^### C1-" docs/working/templates/review-self.md` = 25。内訳 PLAN 9 / SUP 2 / TODO 6 / TEST 3 / B1B2 2 / SEC 1 / SCOPE 1 / UI 1。`working-context.md` 等の「17 項目」表記は実体と乖離しており（issue #960）、テンプレート実体の 25 項目すべてを実行した）
> 判定: **FAIL** — critical=0, major=8, minor=4

## サマリー

| result | 件数 |
|--------|------|
| PASS | 12 |
| WARN | 8 |
| FAIL | 4 |
| N/A | 1 |
| **合計** | **25** |

### FAIL 一覧（先出し）

| check_id | 要旨 |
|----------|------|
| **C1-PLAN-04** | Phase 1 では `evidence_status=complete` / 受理器 exit 0 が**構造的に到達不能**なのに fixture 1〜5 が exit 0 を期待している |
| **C1-SUP-PLAN-02** | T-38 が 5 責務混在（敵対レビュー R1/R2・49 TC 実行・不変差分確認・commit 整理・status/handoff 更新）で Task 単位の approve/reject が不能 |
| **C1-TODO-09** | `depends_on` に**循環依存**（T-24 → T-32 → T-31 → … → T-25 → T-24） |
| **C1-TEST-14** | TC-04（`required` を `len()` で数えて 20）と TC-05 / T-5（`required` に `schema_version` を含む＝21）が**両立しない** / TC-43 の恒等式が `metrics.py` 実装と不一致 |

### 数値の再カウント結果（plan の記述との突合）

**plan の記述と食い違った実測値は 0 件**（全 21 項目一致）。以下すべて `feat/task-0874-plan` @ `388677d` で実測。

| plan の記述 | 実測 | 一致 |
|------------|------|------|
| arbiter record 28 件（9 キー 25 / 14 キー 3） | 28（`{9: 25, 14: 3}`） | ✅ |
| `schemas/*.schema.json` 28 本 / `$id` 28/28 / `additionalProperties` 78 中 72 が false | 28 / 28 / 78・72 | ✅ |
| `$schema` 2020-12 が 23 本・draft-07 が 5 本 | 23 / 5 | ✅ |
| `docs/schemas/` は `child-pbi.yaml` 1 ファイル | 1 | ✅ |
| `docs/schemas` 参照 5 件・全て `check-orchestrator-docs.sh`・被参照 0 件 | 5 件 / 1 ファイル / 外部参照 0 | ✅ |
| `tests/extras/ta-*.sh` 54 ファイル・最大 57・ta-14 のみ重複 | 54 / 57 / `ta-14` 2 本 | ✅ |
| `scripts/ai-loop/*.py` 26 本 | 26 | ✅ |
| `docs/workflows/ai-loop/*.md` 15 本 | 15 | ✅ |
| `docs/working/ai-loop-runs/` の `.md` 21 件 | 21 | ✅ |
| EH-8 禁止キー 14 個 / 走査対象 `*.json\|*.ndjson` のみ | 14 / `case "$f" in *.json\|*.ndjson)` | ✅ |
| `delivery.STATES` 7 + `EXITS` 2 / `PRIORITY_ORDER` 15 / `TERMINAL=MERGE_READY` | 7 / 2 / 15 / MERGE_READY | ✅ |
| `c3_contract.VALID_DECISIONS` 3 / `RECORD_REQUIRED_KEYS` 14 / `ARTIFACTS` 6 | 3 / 14 / 6 | ✅ |
| sync whitelist for ループ 24 / case 24・両者一致 | 24 / 24 / basename 集合 diff = 0 | ✅ |
| `bin/plangate` 0.2.0 / plugin 8.18.0 / `git describe` v8.18.0 | 同一 | ✅ |
| `delivery.py` 27139 B | 27139 | ✅ |
| RunEvidence 既存実装 0 件 | `grep -rn 'run_evidence\|RunEvidence\|harness_version' scripts/ bin/` = 0 | ✅ |
| TASK-0917 の `record.jsonl` 実測 3 行（intent/notice/receipt） | 3 行・`kind` = intent/notice/receipt（全 `action_kind=repair_ci`） | ✅ |
| `metrics.py` 現行出力 legacy 25 / run 3 / invalid 0 / skipped 0 | 完全一致（`total_records` 28） | ✅ |
| RunEvidence 20 フィールド（issue 本文） | issue #874 本文 YAML ブロック = 20 キー | ✅ |
| AC 16 件（issue verbatim 13 + In scope 3） | issue AC チェックボックス 13 / pbi AC-14〜16 | ✅ |
| TC 総数 49（欠番なし）/ タスク総数 38（欠番なし）/ 変更ファイル 19（新設 7 + fixture 10 + 改変 2） | 49 / 38 / 7+10+2=19 | ✅ |
| #873 CLOSED / #862 CLOSED / #866 OPEN / #870 OPEN | `gh issue view` で一致 | ✅ |

**実装先例の実在確認（plan が「転写する」と書いたパターンが実際にその形で存在するか）**: 全件実在。

| plan の主張 | 実測 |
|------------|------|
| `plan_package.serialize_c3_prime()` の `json.dumps(record, ensure_ascii=False, indent=2, sort_keys=True) + "\n"` | L343 に**逐語で存在** |
| `c3_contract.canonical_hash()` = `json.dumps(sort_keys=True, separators=(",",":"))` の sha256 + `sha256:` prefix | L71-74 に存在 |
| `plan_package.PlanPackageError` が errors リスト保持例外 | L35-40 に存在 |
| `delivery._completed_rounds()` L213-218 | L213 定義・`max(rounds, default=0)` |
| `delivery.assess()` が `kind=merge_ready` を刻む唯一の経路 | L390 付近「優先度 8: DoD 充足 → MERGE_READY（唯一の到達経路）」・`check_summary` / `review_disposition` / `round` / `plan_hash` を含む record を実測 |
| `delivery.load_entries()` の `entry_id` 再計算照合 | L463-471 に存在（改竄兆候で `RecordError`） |
| `delivery.verify_c3()` が `redirect_stderr` で `c3prime_verify.main()` を呼ぶ | L498-506 に存在 |
| `c3prime_verify.py` の allowlist（`^_` 許容） | L73「`not k.startswith("_")`」 |
| `c3prime_verify.py` の `task_dir` 束縛 | L83-84「`task_dir.name != task_id`」 |
| `metrics.py` の skip 3 分岐（理由文字列必須） | L79-95 に JSON parse error / not object / missing 'decision' |
| c3-prime-contract §6 L127 / §7 L129・L131・L133 / §8 L137 | 全て実在（§8 に「#872 / #873 / #874 の 3 issue 合意」も実在） |
| `ho-paths.md` L28 = `schemas/**` | `docs/ai/ai-loop/ho-paths.md` L28 で一致 |
| `check-plan-hash.sh` の HO 9 カテゴリ | L124 `case` 〜 L134 `esac`、エントリ 9 個で一致 |
| rollout-policy §2 carve-out ①②③ / `docs/schemas/**` は非該当 | `docs/workflows/ai-loop/rollout-policy.md` §2 で一致 |
| markdownlint globs に `docs/workflows/**/*.md` あり・`docs/working/**` なし | `.github/workflows/ci.yml` L64 で一致 |
| schema-validate の trigger paths に `docs/schemas/**` なし | 一致（ただし `docs/working/**/*.json` は**含まれる** → 後述 C1-SUP-PLAN-01） |
| `tests/run-tests.sh` L165 の `for extra in "$EXTRAS_DIR"/ta-*.sh` glob source | L165 で一致 |
| `tests/extras/README.md` L35「本体には触れない」 | L35 で一致 |

---

## Plan チェック（7項目 + AEE 2項目 / #544 Phase1）

### C1-PLAN-01: 受入基準網羅性

- **result**: WARN
- **category**: plan
- **finding**: AC 16 件は plan 末尾の対応表で全数が Step と TC に割当済みで、**TC の union は TC-01〜TC-49 と過不足なく一致**（欠落 0 / 重複 0 を機械照合）。ただし AC 本文と割当先の中身を突合すると 2 点の実質欠落がある。①**AC-13 の fail-closed が空振りしうる**: 判定条件が「入力 candidate の `blocked_by[]` が非空なら BLOCKED」という汎用条件のみで、`blocked_by[]` を**誰が埋めるか**が plan / todo / test-cases のどこにも定義されていない。供給者不在なら常に空 → 常に非 BLOCKED となり、AC-13 の「未解決の正本へ自動 promotion しない」が構造的に成立しない（fail-open）。②**DoD の 2 項目に対応する Step / T が無い**: issue DoD の「Issue コメントに schema・test command・sample record・integration log への link がある」「#870 の Evolution DoD へ evidence link が反映されている」。T-38 は status / handoff 更新までで issue コメント発行を含まない。
- **evidence_ref**: 本ファイル §evidence-1
- **impacted_files**: [`docs/working/TASK-0874/plan.md`, `docs/working/TASK-0874/todo.md`, `docs/working/TASK-0874/test-cases.md`]
- **suggested_action**: ① `blocked_by[]` の供給元（呼び出し側注入 / 契約 doc 側の未解決正本リスト参照）を Step 7 と TC-36 に明記する。② DoD 2 項目を T-38 のサブ項目に追加するか、「本 PBI の完了条件外」と plan に明示する。
- **owner**: agent
- **resolved**: false

### C1-PLAN-02: Unknowns処理

- **result**: WARN
- **category**: plan
- **finding**: U-1〜U-9 の 9 件はいずれも「未解決である理由」と「plan 既定（安全側）」がセットで書かれており、放置ではない。ただし **3 件は人間判断を要さない可能性が高い**。①**U-2（`replan_count` の供給元）**: 提示された 3 択のうち「`record.jsonl` に新 entry kind を足す」は plan 自身の Constraints（`delivery.py` 不変）で**既に排除済み**であり、残りは「plan の Loop Attempts を数える」か「`unavailable` 固定」。Phase 1 shadow なら安全側既定（`unavailable`）を plan が確定できる。②**U-3（`cost_metrics`）**: `events.ndjson` が `.gitignore` L53 で除外されている実測により、Phase 1 では `unavailable` 以外を取り得ない（＝調べれば決まる）。③**U-6（`schemas/` 昇格 PBI の予約起票）**: 裁定正本 §8-3 が「昇格 PBI（HO patch）を #870 の後続タスクとして予約起票するかを **plan 段階で判断**」と明示指定しているのに、plan は「起票は C-3 後の判断とした」として先送りしている（裁定が plan に割り当てた判断の未消化）。
- **evidence_ref**: 本ファイル §evidence-2
- **impacted_files**: [`docs/working/TASK-0874/plan.md`]
- **suggested_action**: U-2 / U-3 は plan 側で「Phase 1 は `unavailable` 固定・定義は V2」と確定し、Unknowns から降格（C-3 の判断負荷を減らす）。U-6 は裁定の指定どおり plan 段階で「起票する / しない」を書く。
- **owner**: agent
- **resolved**: false

### C1-PLAN-03: スコープ制御

- **result**: PASS
- **category**: plan
- **finding**: Non-goals は issue の Non-goals を verbatim で保持し、加えて「不変（触ってはいけない）」7 対象（`delivery.py` / `c3_contract.py` / `c3prime_verify.py` / `arbiter.py` / `metrics.py` / `schemas/` / `ai-loop-runs/` 既存 28 件 / `tests/run-tests.sh`）を plan・todo・test-cases の 3 ファイルすべてに重複記載している。さらに Files 節が「バッククォート囲みパスが `plan_package.extract_allowed_paths()` に機械抽出される」ことを理解した上で、不変対象を**意図的にバッククォート無し**で書いて `allowed_paths` への混入を防いでいる（スコープ制御が機械層まで届いている珍しい例）。Replan Triggers に「`schemas/` / `bin/plangate` / `.github/workflows/` / `.claude/**` / `scripts/hooks/**` を触る必要が判明した時点で即停止」があり、スコープクリープの検知点も定義済み。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-04: テスト戦略

- **result**: **FAIL**
- **category**: plan
- **finding**: **Phase 1 では受理器 exit 0（`evidence_status=complete`）が構造的に到達不能**であるのに、fixture 1〜5 が exit 0 を期待している。plan の 20 フィールド供給元表は `routing_decisions[]` を「#868 未実装 → **空配列で埋めない**。`unavailable` として明示」、`replan_count` を「供給元が main に存在しない（U-2）」、`cost_metrics{}` を「供給元が実質存在しない（U-3）」としている。一方で受理器の exit 契約は「`10` = partial（必須フィールドは揃うが **`unavailable` を含む**）」。したがって Phase 1 に生成されるすべての RunEvidence は最低 1〜3 個の `unavailable` を含み、**常に exit 10** になる。ところが `test-cases.md` の fixture 表は fx-01〜fx-05 の期待受理器 exit を **0** とし、fx-06 のみ 10 として「`routing_decisions` が `unavailable` を含むため partial」と注記している。この注記は「fx-01〜05 は routing が available」であることを含意するが、#868 未実装下でそれを満たすには fixture 側で routing を**捏造**するしかなく、plan の「空配列で埋めない」方針および「手書き fixture が実 record と乖離しない」方針と衝突する。exit 0 に至る経路が定義されていない状態で TC-48（golden 10/10 byte 一致）と fixture 表を実装すると、Step 8 で必ず矛盾に突き当たる。
- **evidence_ref**: 本ファイル §evidence-3
- **impacted_files**: [`docs/working/TASK-0874/plan.md`, `docs/working/TASK-0874/test-cases.md`]
- **suggested_action**: 「Phase 1 で構造的に未供給と分かっているフィールド（`routing_decisions` / `replan_count` / `cost_metrics`）」を **known-unavailable allowlist** として契約 doc と受理器に明示し、それらのみの `unavailable` は `complete` を妨げない（あるいは第 3 の status `complete_phase1` を置く）等の設計を確定してから fixture 期待値を書く。決められない場合は fixture 1〜5 の期待 exit を 10 に統一し、「Phase 1 で exit 0 は出ない」ことを契約 doc に明記する。いずれにせよ**C-3 の判断事項（U-10 として追加）**にすべき。
- **owner**: agent
- **resolved**: false

### C1-PLAN-05: Work Breakdown Output

- **result**: PASS
- **category**: plan
- **finding**: Step 1〜13 の 13 Step すべてに `Output:` / `Owner:` / `Risk:` / 🚩チェックポイントが揃っている（`grep -c 'チェックポイント'` = 13 = Step 数）。Output はファイルパス粒度で具体（例: Step 2 = `scripts/ai-loop/run_evidence_verify.py` + `test_run_evidence_verify.py`）。チェックポイントも「同一入力で 2 回生成して byte 一致（`cmp -s`）」「2 箇所の basename 集合を diff して差分 0」のように**検証コマンド粒度**まで落ちている。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-06: 依存関係

- **result**: WARN
- **category**: plan
- **finding**: Step 1〜13 の順序（契約 → 受理器 → producer → legacy → privacy → c3-prime → adapter → fixture → E2E → sync → レビュー → 突合 → Human ゲート）は前段の Output が後段の入力になっており矛盾はない。ただし **AC↔Step 対応表と todo の実装フェーズが 2 件ずれている**: AC-9 を「Step 8（fixture）」、AC-10 を「Step 8」に割り当てているが、対応する TC-27 / TC-34 / TC-35 を実装するのは todo の **adapter フェーズ（T-28 / T-30）= Step 7 相当**である。V-1 で「AC-9 は Step 8 の成果物で検証」と読むと突合先を取り違える。
- **evidence_ref**: 本ファイル §evidence-4
- **impacted_files**: [`docs/working/TASK-0874/plan.md`]
- **suggested_action**: AC↔Step 表の AC-9 / AC-10 を `Step 7・Step 8` に修正（fixture 依存があるため両方併記が正確）。
- **owner**: agent
- **resolved**: false

### C1-PLAN-07: 動作検証自動化

- **result**: PASS
- **category**: plan
- **finding**: Verification Automation が単一コマンド列（`python3 scripts/ai-loop/test_run_evidence.py && python3 scripts/ai-loop/test_run_evidence_verify.py && sh tests/run-tests.sh`）で定義され、`test-cases.md` §V-1 実行時の突合手順に 6 手順（unit 2 本 / run-tests / EH-8 実走 / 不変 7 対象の差分 0 / SKIP 0 件）へ展開されている。加えて「`sh tests/run-tests.sh` は `</dev/null` 必須（`precompact-memory-guard.sh` が stdin を待つ）」「glob source は python unit test を起動しないため ta-58 に明示導線が要る（TASK-0917 R-020 の実害型）」という**過去の実害に基づく落とし穴**まで自動化手順に織り込まれている。baseline を固定値で置かず T-2 で実測記録する設計（かつ「開始時の値を下回らない」だけでは新規 test 0 本でも通るため下限を必ず引き上げる、と明記）も妥当。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-08-AEE: Stop Condition 記入（#544 Phase1）

- **result**: PASS
- **category**: plan
- **finding**: `## Stop Condition` 節が存在し、5 条件（Files 内に閉じる / Verification Automation 全成功 / AC-1〜16 全 TC PASS / 敵対レビュー critical・major ゼロ収束 / 残課題は handoff 明示）+ テスト件数の数え方の注記を持つ。`## Resume Condition` も併記。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-09-AEE: Replan Triggers 機械値（#544 Phase1）

- **result**: WARN
- **category**: plan
- **finding**: 機械値は複数記入済み（変更ファイル数 > **24** / 同一検証コマンド連続失敗 **3** 回 / 同一ファイル修正反復 **3** 回）で本項目の要件（機械値 1 つ以上）は満たす。ただし「変更ファイル数 > 24」の**計測対象が未定義**。plan の 19 は「手作業ファイル数（`plugin/` 自動生成と `docs/working/TASK-0874/` を除く）」だが、実際の `git diff --name-only` には T-37 の sync が生成する `plugin/plangate/skills/ai-loop-cycle/{scripts,references}/` の新規 5 ファイルと `docs/working/TASK-0874/` の 7〜9 ファイルが乗るため、正常進行でも 30 前後に達し**閾値を即超過して誤発火**する。
- **evidence_ref**: 本ファイル §evidence-5
- **impacted_files**: [`docs/working/TASK-0874/plan.md`]
- **suggested_action**: トリガーを「`git diff --name-only origin/main -- ':!plugin/' ':!docs/working/'` の件数 > 24」のように**計測コマンドごと**書く。
- **owner**: agent
- **resolved**: false

## Plan 品質追加チェック（Superpowers 由来 / #581）

### C1-SUP-PLAN-01: No Placeholders Rule

- **result**: WARN
- **category**: plan
- **finding**: `TBD` / `後で実装` / `必要に応じて` / `適切に` の類は 0 件で、転写元は行番号付きで特定済み（実測でも全件実在）。一方で **exec に必要な仕様が 2 点未定義**。①**実運用時の RunEvidence 出力先パスが未定義**: 保存形式は「`.json`（1 run 1 ファイル）」と決めているが、producer が実行時にどこへ書くか（`docs/working/TASK-XXXX/` 配下か、stdout 返しで呼び出し側が決めるか）がどこにも書かれていない。TC-21 は「producer が書き出すファイル名の拡張子」を検査するのに、その書き出し先が未定義。なお `docs/working/**/*.json` は `.github/workflows/schema-validate.yml` の trigger paths に**含まれる**ため、置き場所によっては CI 経路が変わる（`schema_mapping.FILENAME_TO_SCHEMA` 未登録 basename は skip されるので CI は壊れないが、「`docs/schemas/` に置いたものは CI で検証されない」という plan の前提整理に対し出力側の扱いが空白のまま）。②**schema の `^_` 注釈キー扱いが未定義**: TC-09 が「`^_` 始まりの注釈キーは許容され exit 0」とする一方、T-5 / TC-03 は `additionalProperties: false` のみを指定し `patternProperties` に触れていない。前例 `schemas/c3-prime.schema.json` は `additionalProperties: false` **かつ** `patternProperties: {"^_": ...}` の両方を持つ（実測）。このまま実装すると schema（`_note` を拒否）と受理器（`_note` を許容）が食い違う。
- **evidence_ref**: 本ファイル §evidence-6
- **impacted_files**: [`docs/working/TASK-0874/plan.md`, `docs/working/TASK-0874/todo.md`, `docs/working/TASK-0874/test-cases.md`]
- **failure_policy**: standard 以上は重大な曖昧表現を FAIL。本件は「exec で決めれば動くが決め方が 2 通りある」レベルのため WARN 止まりとする。
- **suggested_action**: ① Step 3 / T-15 に「producer は stdout へ返し、保存先は呼び出し側が指定する（Phase 1 は fixture のみ commit）」等を明記。② T-5 に `patternProperties: {"^_": {}}` を追加し、TC-03 を「`additionalProperties == false` かつ `patternProperties` に `^_` を持つ」に更新。
- **owner**: agent
- **resolved**: false

### C1-SUP-PLAN-02: Task Sizing Rules

- **result**: **FAIL**
- **category**: plan
- **finding**: 38 タスク中 37 は変更対象ファイル・検証コマンド・期待結果・依存が具体で Task 単位に検証可能だが、**T-38 が 5 つの独立した責務を 1 チェックボックスに束ねている**: (a) 敵対レビュー R1（複数エージェント・4 観点）→ 是正、(b) R2（深掘り・critical/major ゼロ収束まで）→ 是正、(c) 49 TC の全件機械実行、(d) 不変 7 対象の差分 0 確認、(e) commit 整理（`_audit/` 分離を含む）+ `status.md` / `current-state.md` / `handoff.md` 更新 + AC↔fixture 対応表 + V2 候補記録。reviewer は「T-38 を approve するか」を単位として判断できず（R1 は通ったが handoff が未記載、等の部分状態を表現できない）、rollback も `rollback: 是正 commit 単位で git revert` と**タスク単位でない**戻し手順になっている。テンプレートの failure_policy「high-risk/critical では Task 単位の検証不能・**責務混在**・依存不明を FAIL」に直接該当する。副次的に T-15（producer 本体実装・転写 4 パターン）と T-32（golden fixture 10 件生成）も 2〜5 分粒度を大きく超える（C1-TODO-08 と重複計上）。
- **evidence_ref**: 本ファイル §evidence-7
- **impacted_files**: [`docs/working/TASK-0874/todo.md`]
- **failure_policy**: high-risk/critical では Task 単位の検証不能・責務混在・依存不明を FAIL
- **suggested_action**: T-38 を最低 4 分割する（T-38a 敵対レビュー R1 / T-38b R2 収束 / T-38c 49 TC 全件実行 + 不変差分 0 / T-38d commit 整理 + status/current-state/handoff + AC↔fixture 対応表）。分割後は総タスク数が 41 になるため plan の「タスク数 38」と todo 冒頭の「T-1〜T-38」を同時更新すること。
- **owner**: agent
- **resolved**: false

## ToDo チェック（6項目）

### C1-TODO-08: タスク粒度

- **result**: WARN
- **category**: todo
- **finding**: 大半のタスク（T-1〜T-3 の実測系、T-6 / T-9 / T-14 / T-18 / T-27 / T-31 / T-34 / T-36 の検証系）は数分粒度で妥当。一方で **T-15（producer 実装・転写 4 パターン）/ T-16（D3 正規化マッピング実装・非終端 7 パターン）/ T-32（golden fixture 10 件生成）/ T-33（ta-58 の 4 機能）/ T-38（5 責務）** は 2〜5 分粒度を大きく超える。critical モードで「1 タスク = 1 検証単位」を保つには分割が要る。
- **evidence_ref**: 本ファイル §evidence-7
- **impacted_files**: [`docs/working/TASK-0874/todo.md`]
- **suggested_action**: T-32 を「fixture 1〜5（terminal 系）/ 6〜7（partial・tampered）/ 8〜10（下流接続）」の 3 分割、T-38 は C1-SUP-PLAN-02 の提案どおり 4 分割。
- **owner**: agent
- **resolved**: false

### C1-TODO-09: depends_on設定

- **result**: **FAIL**
- **category**: todo
- **finding**: 38/38 タスクに `depends_on` が記入されている（欠落 0）が、**`depends_on` グラフに循環がある**。T-24（EH-8 実走）を fixture 生成後に回すため `depends_on: T-32` に変更した一方で、**T-25 の `depends_on` は T-24 のまま**であり、T-32 → T-31 → T-30 → T-29 → T-28 → T-27 → T-26 → T-25 → T-24 → T-32 という閉路が成立する。todo の「⚠️ 依存関係」節は「T-24 は番号順と依存順が食い違う唯一のタスク（意図的）」と述べるが、**閉路の発生には気づいていない**。この依存グラフではトポロジカル順序が存在せず、T-25〜T-32 のいずれも開始条件を満たせない（機械的に依存解決する実行器なら即デッドロック、人手なら暗黙に依存を無視することになる）。
- **evidence_ref**: 本ファイル §evidence-8
- **impacted_files**: [`docs/working/TASK-0874/todo.md`]
- **suggested_action**: **T-25 の `depends_on` を T-24 → T-23 に変更**する（T-24 は privacy hook 実走であり c3-prime 接続フェーズの前提ではない）。これで閉路が解け、T-24 のみが「T-32 完了後に実行する遅延タスク」として孤立枝になる。修正後に再度トポロジカルソートで閉路 0 を確認すること。
- **owner**: agent
- **resolved**: false

### C1-TODO-10: チェックポイント設定

- **result**: PASS
- **category**: todo
- **finding**: 🚩 マーカーが 21 箇所（todo 内）に設定され、準備 / 契約 / 受理器 / producer / legacy / privacy / c3-prime / adapter / fixture / sync / 検証の全フェーズに最低 1 つ以上ある。plan 側も 13 Step すべてにチェックポイントを持つ（13/13）。ToDo 更新タイミングとしての機能を満たしている。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-11: Iron Law遵守

- **result**: PASS
- **category**: todo
- **finding**: 「Agent 実装（T-4 以降）→ **Human C-3 APPROVED（`approvals/c3.json`）後に exec 開始**（critical のため autonomous APPROVE 不可）」が依存関係節の先頭に明記され、Human タスクとして C-3 / C-4 / U-6 判断が分離されている。「merge は Human-owned / NO MERGE BY AI」も明記。さらに TC-27 が improvement TASK 記述子に `skip_c3` / `auto_merge` 等の**ゲート迂回キーが現れたら FAIL** とする allowlist を置いており、生成物側にも Iron Law を持ち込ませない設計。carve-out ①②該当のため ai-loop 自走時は escalate 固定である旨も記載（rollout-policy §2 と実測一致）。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-12: 完了条件

- **result**: PASS
- **category**: todo
- **finding**: 全 38 タスクに `[files: ...]` と完了判定可能な記述があり、検証系タスクは判定条件が数値・コマンドで書かれている（例: T-21「`legacy_count=25` / `run_count=3` / `invalid_run_meta_count=0` / `skipped_count=0` が T-2 の記録値と一致」、T-36「2 箇所の basename 集合を diff して差分 0」、T-34「`git diff origin/main -- tests/run-tests.sh` = 0 行」）。「対応 TC: TC-xx」の逆引きも 12 タスクに付与されている。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-RB: rollback（戻し手順）

- **result**: PASS
- **category**: todo
- **finding**: **38/38 タスクに `rollback:` が記述されている**（機械照合で欠落 0）。実装タスクは `ファイル削除` / `git restore -- <path>` と対象パス明示、検証・読取のみのタスクは `rollback:不要` と明記（`rollback:不要` かつ `[files:` が `-` でないタスクは 0 件 = 誤って「不要」にした実装タスクなし）。plan 側にも Revert Policy L1〜L5 の段階的ロールバック表（critical 要件）があり、L5 で「PR の close は Human-owned」と責務境界を守っている。
- **evidence_ref**: —
- **impacted_files**: []

## テストケースチェック（3項目）

### C1-TEST-13: 受入基準→テストケース網羅性

- **result**: WARN
- **category**: test
- **finding**: AC 16 件 ↔ TC 49 件が**全単射**（各 TC がちょうど 1 つの AC に属し、plan の対応表と `test-cases.md` の節構成が完全一致。機械照合で欠落・重複 0）で、形式上の網羅は満点。ただし **AC 本文の要求要素に対して TC が存在しない箇所が 3 件**ある。①**AC-3 の "routing"**: AC-3 は「Plan hash、C-3'、final head SHA、CI、review、**routing**、terminal state が同一 run へ結合される」だが、割当先 TC-13〜TC-16 は plan_hash / source_sha / c3_prime_decision_ref / final_head_sha / ci_outcomes / review_findings / repair_rounds / terminal_state / human_interventions のみを検査し、**`routing_decisions[]` の結合を検査する TC が 1 件も無い**（fixture 6 の記載のみ）。②**AC-6 の "account 識別子"**: issue Scope と plan Constraints が「hidden CoT / raw transcript / secret / **account 識別子**を要求も保存もしない」とするが、TC-19〜22 は EH-8 の禁止キー 14 個・絶対パス・拡張子・hook 実走のみで、**account 識別子（GitHub username 等）を検査する TC が無い**。禁止キー 14 個に account 系は含まれないため機械層でも素通りする（U-5 で `repository` を論点化しているのと同じ穴）。③**todo T-13 が宣言する挙動に TC が無い**: T-13 は「`unavailable` と `0` / 空配列の区別」「未知 `kind` entry を握り潰さず `escalation` に記録」の RED を書くとし「対応 TC: TC-30 / TC-31」と記すが、TC-30 / TC-31 は `harness_version` の run 中変化のみを扱う。producer 側の unavailable 区別・未知 kind の TC は `test-cases.md` に存在しない（TC-07 は受理器側、TC-19 は禁止キー側）。
- **evidence_ref**: 本ファイル §evidence-9
- **impacted_files**: [`docs/working/TASK-0874/test-cases.md`, `docs/working/TASK-0874/todo.md`]
- **suggested_action**: AC-3 に routing 結合の TC を 1 件追加、AC-6 に account 識別子非保存の TC を 1 件追加、AC-3 または AC-4 に「producer 側の unavailable ≠ 空配列 / 未知 kind → escalation」の TC を 2 件追加（計 4 件 → TC 総数 53）。追加時は plan の対応表と `test-cases.md` 冒頭の「TC 総数 49」も同時更新。
- **owner**: agent
- **resolved**: false

### C1-TEST-14: テストケースの具体性

- **result**: **FAIL**
- **category**: test
- **finding**: 大半の TC は値レベルで具体（byte 一致 / `len()` で数える / stderr 文字列 / exit code / 実データ 28 件の期待値）だが、**互いに矛盾する assert が 2 組**ある。①**`required` の件数が 20 か 21 か決まっていない**: TC-04 は「schema の `required` … 件数を `len()` で数えて **20** を assert する」、TC-05 は「**`schema_version` フィールドが schema の `required` に含まれる**」、T-5 は「`required` に **20 フィールド + `schema_version`**」、T-6 は「schema の `required` **20 件**を `len()` で数え、契約 doc の表の行数と一致」。TC-04 / T-6（20）と TC-05 / T-5（21）は**同時に PASS しない**。critical では V-1 が全 TC を機械実行するため、この矛盾は必ず顕在化する。②**TC-43 の恒等式が `metrics.py` 実装と不一致**: TC-43 は「`total_records == legacy_count + invalid_run_meta_count + run_count`（`metrics.py` L235-237 の構造転写）」とするが、実装は `total_records = len(legacy_records) + len(invalid_meta_records) + len(run_records)` に対し `run_count = len(grouped)`（= `_group_by_run()` 後の**distinct run_id 数**）である。現データでは run record 3 件が 3 run に散っているため偶然一致するが、1 run が複数 record を持つ入力ではこの恒等式は破れる。転写元の恒等式は `total_records == legacy + invalid + len(run_records)` であり、TC-43 の式は誤り。③軽微: fixture 7 の期待受理器 exit が「**1 または 10**」と二値のまま golden 化されており、決定論 producer の golden としては期待値が一意でない。
- **evidence_ref**: 本ファイル §evidence-10
- **impacted_files**: [`docs/working/TASK-0874/test-cases.md`, `docs/working/TASK-0874/todo.md`]
- **suggested_action**: ① `required` を **21（20 + `schema_version`）** に統一し、TC-04 を「issue の 20 フィールドをすべて含み `len(required) == 21`」に、T-6 を「required 21 件 = 契約 doc の表 20 行 + `schema_version` 行」に修正。② TC-43 を「`total_records == legacy_count + invalid_run_meta_count + len(run_records)`。加えて `run_count == len(set(run_id))`」の 2 本に分離。③ fixture 7 の期待 exit を一意に固定（tampered なら 1、partial なら 10 で fixture を 2 本に割る）。
- **owner**: agent
- **resolved**: false

### C1-TEST-15: エッジケースの考慮

- **result**: PASS
- **category**: test
- **finding**: `## Edge cases（TC への割当）` に 10 行の表があり、全行が具体 TC に割当済み（未割当 0）。境界値・異常系・空入力がバランスよく含まれる: `record.jsonl` 破損行 / `entry_id` 改竄 / legacy `c3.json` / 非終端 run 7 状態 / **arbiter record 0 件（分母 0 → `None` + `N/A`）** / 絶対パス / `harness_version` の run 中変化 / `harness_version` 混在 / 同型 Run が 2 件（閾値 3 の直下）/ 出力を `.jsonl` にしてしまう誤り。negative TC は 49 中 12 件（TC-06〜09・TC-12・TC-18・TC-20・TC-26・TC-31・TC-32・TC-33・TC-35〜37）で、受理器側は negative first の順序（T-7 → T-8 → T-9 RED → T-10 GREEN）で設計されている。
- **evidence_ref**: —
- **impacted_files**: []

## B-1/B-2チェック（2項目）

### C1-B1B2-16: B-1確認質問

- **result**: PASS
- **category**: plan
- **finding**: `## 確認事項（B-1）` 節で「Human への追加質問は行わず、pbi-input と main 実測で確定できる範囲に閉じた。確定できなかった論点は勝手に決めず Questions / Unknowns に 9 件残す」と方針を明示し、pbi-input で既に裁定済みで**再オープンしないもの** 3 件（schema 配置 / producer 配置 / Mode）も列挙している。さらに **pbi-input と main 実測の乖離 4 点（A〜D）を表で明示**し「pbi-input.md は main マージ済みのため訂正せず、本 plan を正とする」と扱いを固定している。乖離 A（#873 は CLOSED・`delivery.py` は main 実在）は本レビューでも `gh issue view 873` = CLOSED / `delivery.py` 27139 B 実在で裏取りでき、**plan の記述が正しい**ことを確認した。この乖離の扱いは plan 内で一貫している（Approach Overview「#873 は実装済みなので delivery 層は fixture ではなく実物の契約から取る」/ Risks 表に fixture 先行の対象を #811・#869・#868 のみと記載 / D3 で `delivery.STATES` 実測値を根拠にマッピング / Step 3・T-12 で `delivery._completed_rounds()` を import 再利用、と 5 箇所で整合）。逆に pbi-input 由来の記述をそのまま持ち越した箇所（「#873 未実装」を前提にした fixture 先行）は plan 内に**残っていない**ことも確認した。
- **evidence_ref**: —
- **impacted_files**: []

### C1-B1B2-17: B-2アプローチ比較

- **result**: WARN
- **category**: plan
- **finding**: `## アプローチ比較（B-2）` で 6 論点（D1 schema 表現形式 / D2 producer 入力 / D3 terminal_state 語彙 / D4 harness_version / D5 privacy 強制層 / D6 モジュール分割）を扱い、D1・D2・D6 は 2 案の表比較 + 採用理由 + 実測根拠を明記しており要件を満たす。ただし **D6 で決めた exit code の値割当が既存前例と衝突しており、その比較検討が無い**。plan は「exit code 契約（`c3prime_verify.py` L13-15 の転写・値は本 PBI で新規に定義）」として `0`=complete / `1`=NG / **`10`=partial** / **`11`=legacy** を採用しているが、転写元と称する `c3prime_verify.py` の実装は **`10` = legacy**（L13-15 の docstring および L67 `return 10  # legacy → 呼び出し側 shell へ委譲`）である。すなわち同一ディレクトリの姉妹スクリプト間で **exit 10 の意味が逆転**する。さらに `test-cases.md` の Edge cases 表は「`c3.json` が legacy → **exit 11**（legacy 委譲。`c3prime_verify.py` L62-67 の分岐と**同型**）」と書くが、L62-67 の分岐は 10 を返すため**同型ではない**（記述が誤り）。呼び出し側（将来の `bin/plangate` や ai-loop 側 shell）が 2 つの受理器の rc を同じ意味で扱うと legacy を partial と誤読する経路が生まれる。
- **evidence_ref**: 本ファイル §evidence-11
- **impacted_files**: [`docs/working/TASK-0874/plan.md`, `docs/working/TASK-0874/test-cases.md`]
- **suggested_action**: (a) 前例に合わせて **`10`=legacy / `11`=partial** に入れ替える、または (b) 現割当を維持したうえで「なぜ前例と逆にするか」を D6 に比較として明記し、契約 doc に**両受理器の rc 対応表**を置く。いずれにせよ `test-cases.md` の「L62-67 の分岐と同型」は事実誤認なので削除・修正する。C-3 論点（U-11）に上げることを推奨。
- **owner**: agent
- **resolved**: false

### C1-SEC-01: 秘密情報 非接触（#578）

- **result**: PASS
- **category**: plan
- **finding**: `.env` / APIキー / トークンに触れる設計は無い。むしろ本 PBI は privacy そのものを AC-6 として扱い、①producer 側の禁止キー 14 個検査（TC-19）②`evidence_refs` の絶対パス reject（TC-20）③保存形式を `.json` に固定して EH-8 の走査対象（`case "$f" in *.json|*.ndjson`）に**必ず載せる**（TC-21。`.jsonl` は素通りすることを case glob で実測済み）④10 fixture を `git add` した状態で `scripts/hooks/check-metrics-privacy.sh` を**実走**して PASS を証明（TC-22）— の 4 層で検証計画を持つ。「自主規制でなく hook で証明する」と明記し、TASK-0917 で同 hook が実際に `stdout` / `stderr` を BLOCK した実績（`evidence/e2e/RAW-EXCLUDED.md`）を根拠に置いている。残る論点（`repository` に `s977043/plangate` を書いてよいか）は U-5 として C-3 に上げ済み。
- **evidence_ref**: —
- **impacted_files**: []

### C1-SCOPE-DISC-01: 発見事項の予防的分離（#578）

- **result**: PASS
- **category**: plan
- **finding**: スコープ外の発見をその場で直さない方針が複数箇所で機械的に担保されている。① Replan Triggers に「`delivery.py` / `c3_contract.py` / `c3prime_verify.py` / `arbiter.py` / `metrics.py` への変更が必要と判明した時点で**即停止**（Out of scope の改訂は C-3 再承認事項）」「`docs/working/ai-loop-runs/` の既存 28 件を変更する必要が判明した時点で即停止」「`schemas/` 等 HO を触る必要が判明した時点で即停止」。② T-38 に V2 候補（`schemas/` 昇格 PBI の起票 / `harness_version` 構造検証 TC / cost_metrics 収集経路 / schema・fixture の plugin 配布）を handoff へ記録する指示。③ `docs/working/_audit/` への hook 由来追記を「本 branch に含めず別 PR に分離」と明示（混入による plan 逸脱の予防）。④ TC-31 の注記で「定義が確定したら構造検証 TC を追加する（V2 候補）」と将来分離を宣言。
- **evidence_ref**: —
- **impacted_files**: []

### C1-UI-01: UI デザインシステム準拠（#579・is_ui_task 時のみ）

- **result**: N/A
- **category**: plan
- **finding**: `is_ui_task = false`。本 PBI の成果物は JSON Schema / Python producer・validator / shell test / fixture / 契約 doc のみで UI コンポーネントを含まない（Files / Components to Touch 12 行に UI 資産なし）。
- **evidence_ref**: —
- **impacted_files**: []

---

## Evidence

### §evidence-1（C1-PLAN-01）

AC↔TC の全単射確認（機械照合）:

```text
$ python3 -  # plan.md の AC 対応表を展開して TC-01..TC-49 と突合
union size 49
missing from AC table: []
extra: []
# test-cases.md 側の節帰属も plan 表と完全一致（TC-01..05→AC-1, TC-06..09/32→AC-4, ...）
```

AC-13 の `blocked_by[]` 供給元不在:

```text
$ grep -n 'blocked_by' docs/working/TASK-0874/*.md
plan.md: 入力 candidate の `blocked_by[]` が非空なら BLOCKED という汎用条件で実装
todo.md: `blocked_by[]` 非空 → `BLOCKED`
test-cases.md(TC-36): `blocked_by = ["#866"]` を持つ candidate
→ いずれも「blocked_by を誰が / 何を根拠に埋めるか」を定義していない
```

DoD 未カバー 2 項目（issue #874 本文 DoD より verbatim）:

```text
- [ ] Issueコメントにschema、test command、sample record、integration logへのlinkがある
- [ ] #870のEvolution DoDへevidence linkが反映されている
→ plan の Step 1-13 / todo の T-1..T-38 に対応タスクなし
```

### §evidence-2（C1-PLAN-02）

```text
$ grep -n 'events.ndjson' .gitignore
53:docs/working/_metrics/events.ndjson        # U-3 は「調べれば決まる」（Phase 1 は unavailable 以外に選択肢がない）

$ sed -n '/^## 8. 裁定後のアクション/,/^## 9/p' docs/working/discussions/2026-07-31-schema-placement-ho-arbitration.md
3. 段階方式の場合、昇格 PBI（HO patch）を #870 の後続タスクとして予約起票するかを plan 段階で判断
→ plan.md U-6: 「本 plan では起票していない（起票は C-3 後の判断とした）」= 裁定が plan に割り当てた判断の先送り

# U-2 の 3 択のうち 1 つは plan 自身の Constraints で既に排除済み
plan.md Constraints: 「delivery.py / c3_contract.py / c3prime_verify.py / arbiter.py / metrics.py を改変しない」
plan.md U-2:        「record.jsonl に新 entry kind を足すのか（後者は delivery.py 改変 = Out of scope 抵触）」
```

### §evidence-3（C1-PLAN-04）

plan の供給元表（構造的に unavailable になるフィールド）:

```text
| 11 | routing_decisions[] | #868 未実装 | 空配列で埋めない。unavailable として明示 |
| 15 | replan_count        | 供給元が main に存在しない → U-2 |
| 19 | cost_metrics{}      | 供給元が実質存在しない（.gitignore L53）→ U-3 |
```

受理器の exit 契約（plan D6）:

```text
| 10 | partial（必須フィールドは揃うが unavailable を含む = ready 扱いしない） |
```

fixture 表の期待値（test-cases.md L162-167）:

```text
| 1 | first-pass MERGE_READY | fx-01-first-pass.json | ... | MERGE_READY / 0 |
| 5 | BLOCKED                | fx-05-blocked.json    | ... | BLOCKED / 0 |
| 6 | routing escalation あり| fx-06-...             | ... | HUMAN_ESCALATED / 10（routing_decisions が unavailable を含むため partial）|
```

⇒ #868 未実装下では fx-01〜05 も `routing_decisions = unavailable` を含むため exit 10 になるはずで、exit 0 は到達不能。fx-06 の注記が「fx-01〜05 では routing が available」を含意している点が設計の穴。

```text
$ gh issue view 868 --json state -q .state
OPEN
$ grep -rn 'run_evidence\|RunEvidence\|harness_version' scripts/ bin/ | wc -l
0      # routing producer も harness_version producer も main に存在しない
```

### §evidence-4（C1-PLAN-06）

```text
plan.md AC 対応表:
| AC-9  | improvement TASK が通常の Plan-first / C-3' / PR 収束を通る | Step 8 | TC-27 |
| AC-10 | paired replay / 独立 grader / activation check / rollback  | Step 8 | TC-34、TC-35 |

todo.md（consumer adapter フェーズ = Step 7 相当）:
T-28: ... + improvement TASK 記述子（skip_c3/auto_merge 等の迂回キーが現れたら FAIL）。対応 TC: ... TC-27 ...
T-30: paired replay / rollback の橋渡し実装（AC-10）... 対応 TC: TC-34 / TC-35
```

### §evidence-5（C1-PLAN-09-AEE）

```text
plan.md Replan Triggers: 「変更ファイル数 > 24（= 想定 19 + 5）」
plan.md Files 脚注:      「手作業ファイル数 = 19（#11 plugin は自動生成 / #12 は working context のため除外）」

$ grep -n 'AI_LOOP_SCRIPTS_DIR\|AI_LOOP_WORKFLOWS_DIR' scripts/sync-plugin-plangate.sh | head -4
202:AI_LOOP_WORKFLOWS_DIR="$REPO_ROOT/docs/workflows/ai-loop"
246:if [ -d "$AI_LOOP_WORKFLOWS_DIR" ]; then
247:  for _f in "$AI_LOOP_WORKFLOWS_DIR"/*.md; do
348:  for _f in "$AI_LOOP_SCRIPTS_DIR/arbiter.py" ...
→ T-37 の sync で plugin 配下に新規 5 ファイル（scripts 4 + references 1）が生成され、
  さらに docs/working/TASK-0874/ に 7〜9 ファイルが乗るため git diff ベースでは 30 前後になる。
```

### §evidence-6（C1-SUP-PLAN-01）

```text
# ① 出力先パス未定義
$ grep -n 'tests/fixtures/run-evidence\|書き出す\|出力先' docs/working/TASK-0874/plan.md docs/working/TASK-0874/todo.md | head
→ fixture パス（tests/fixtures/run-evidence/）以外の出力先指定は 0 件

$ sed -n '4,10p' .github/workflows/schema-validate.yml
    paths:
      - 'docs/working/**/*.json'     # ← 出力先を docs/working 配下にすると CI trigger 対象になる
      - 'schemas/**/*.json'
      ...

# ② ^_ 注釈キーの schema 側定義が未指定（前例は patternProperties を持つ）
$ python3 -c "import json;d=json.load(open('schemas/c3-prime.schema.json'));print(d.get('additionalProperties'), list(d.get('patternProperties',{}).keys()))"
False ['^_']

todo.md T-5:  「additionalProperties: false・task_id は ^TASK-[0-9]{4}$・...」← patternProperties の記載なし
test-cases.md TC-09: 「`^_` 始まりの注釈キーは許容され exit 0」
test-cases.md TC-03: 「additionalProperties == false」のみ
```

### §evidence-7（C1-SUP-PLAN-02 / C1-TODO-08）

`todo.md` T-38（1 チェックボックスに 5 責務）:

```text
- [ ] 🚩 T-38: 敵対レビュー R1 / R2 → AC-1〜AC-16 突合 → 完了処理。内訳:
  - R1（複数エージェント・観点: fail-open していないか / ...）→ 是正
  - R2（R1 是正後の深掘り。... 契約層は 1 ラウンドでは表層しか出ない）→ critical・major ゼロ収束まで
  - test-cases.md の 49 TC を全件機械実行して PASS（未実行 / SKIP 0 件）
  - 不変対象の差分 0 確認: git diff --stat origin/main -- <7 対象>
  - コミット整理（1 コミット 1 種類・Refs: 付き）。_audit/ への hook 由来追記は別 PR に分離
  - status.md / current-state.md / handoff.md を更新し、AC↔fixture 対応表と V2 候補を記録
  [Owner: agent] [depends_on: T-37] [files: docs/working/TASK-0874/] rollback: 是正 commit 単位で git revert
```

### §evidence-8（C1-TODO-09 / 循環依存）

```text
$ python3 -  # todo.md の [depends_on: ...] を全抽出して DFS で閉路検出
T-22 <- ['T-21']
T-23 <- ['T-22']
T-24 <- ['T-32']      ← fixture 生成後に回すため意図的に後方参照
T-25 <- ['T-24']      ← ここが T-23 のままなら閉路にならなかった
T-26 <- ['T-25']
...
T-32 <- ['T-31']
CYCLE: T-24 -> T-32 -> T-31 -> T-30 -> T-29 -> T-28 -> T-27 -> T-26 -> T-25 -> T-24
cycle found: True
```

`todo.md` の「⚠️ 依存関係」節は閉路に言及していない:

```text
- **T-24（EH-8 実走）は番号順に流さない** — `depends_on: T-32`（fixture 生成）であり、
  T-32 完了後に実行する。...これが唯一の番号順と依存順が食い違うタスク（意図的）
```

（参考・PASS 側の機械照合）

```text
tasks: 38 / no rollback: [] / no files field: [] / no depends_on: []
rollback:不要 だが files を持つタスク: []
```

### §evidence-9（C1-TEST-13）

```text
# ① AC-3 の routing に対応する TC が無い
$ grep -n 'routing' docs/working/TASK-0874/test-cases.md
38:| TC-07 | ... routing_decisions が "unavailable" の EV ... exit 10   ← 受理器側（AC-4）
167:| 6 | routing escalation あり | fx-06-routing-escalation.json | ...  ← fixture 表のみ
→ AC-3 節（TC-13〜TC-16）に routing_decisions の結合を検査する TC は 0 件

# ② AC-6 の account 識別子に対応する TC が無い
$ grep -n 'account' docs/working/TASK-0874/*.md
plan.md: 「hidden CoT / raw transcript / secret / account 識別子を要求も保存もしない（AC-6）」
→ test-cases.md に account 識別子の TC は 0 件。EH-8 禁止キー 14 個にも account 系は無い:
$ sed -n '37p' scripts/hooks/check-metrics-privacy.sh
FORBIDDEN_KEYS='"file_path"|"file_paths"|"stack_trace"|"stacktrace"|"command_output"|"stdout"|"stderr"|"raw_response"|"raw_request"|"api_key"|"user_prompt"|"system_prompt"|"prompt_text"|"absolute_path"'

# ③ todo T-13 の対応 TC ラベルが実体とずれる
todo.md T-13: 「unavailable と 0 / 空配列の区別 ... 未知 kind entry ... 対応 TC: TC-30 / TC-31」
test-cases.md TC-30/TC-31: いずれも harness_version の run 中変化のみ（AC-12 節）
```

### §evidence-10（C1-TEST-14）

```text
# ① required 20 vs 21 の矛盾（4 箇所が 2 派に分裂）
test-cases.md TC-04: 「schema の required ... 件数を len() で数えて 20 を assert する」
test-cases.md TC-05: 「schema_version フィールドが schema の required に含まれる」
todo.md T-5:        「required に 20 フィールド + schema_version」
todo.md T-6:        「schema の required 20 件を len() で数え、契約 doc の表の行数と一致」

# ② TC-43 の恒等式が実装と不一致
test-cases.md TC-43: 「total_records == legacy_count + invalid_run_meta_count + run_count
                       （metrics.py L235-237 の構造転写）」
$ sed -n '234,241p' scripts/ai-loop/metrics.py
    return {
        "total_records": len(legacy_records)
        + len(invalid_meta_records)
        + len(run_records),        ← run_records（レコード数）
        "legacy_count": len(legacy_records),
        "invalid_run_meta_count": len(invalid_meta_records),
        "run_count": len(grouped), ← grouped（distinct run_id 数）≠ len(run_records)
$ grep -n 'grouped = ' scripts/ai-loop/metrics.py
184:    grouped = _group_by_run(run_records)

# 参考: 現データでは偶然一致するため回帰では検出できない
$ python3 scripts/ai-loop/metrics.py --format json | head -5
{"total_records": 28, "legacy_count": 25, "invalid_run_meta_count": 0, "run_count": 3, ...}

# ③ fixture 7 の期待 exit が一意でない
test-cases.md L168: | 7 | partial / tampered evidence | ... | — / 1 または 10（0 を返さない）|
```

### §evidence-11（C1-B1B2-17）

```text
$ sed -n '13,16p' scripts/ai-loop/c3prime_verify.py
  exit 0  = c3-prime として受理（AUTO_APPROVED・全束縛整合）
  exit 10 = legacy（approval_kind キー無し）→ 呼び出し側が legacy 経路で処理
  exit 1  = c3-prime だが検証 NG（fail-closed。理由を stderr に出力）
$ sed -n '63,68p' scripts/ai-loop/c3prime_verify.py
    if data.get("approval_kind") != "c3-prime":
        if "approval_kind" in data:
            return _fail(f"approval_kind が未知値/型違い: {data.get('approval_kind')!r}")
        return 10  # legacy → 呼び出し側 shell へ委譲

plan.md D6:  「| 10 | partial ... | / | 11 | legacy ... |」（= 前例と 10 の意味が逆転）
test-cases.md Edge cases: 「c3.json が legacy（approval_kind キーなし）| TC-32 | exit 11
                          （legacy 委譲。c3prime_verify.py L62-67 の分岐と同型）」← L62-67 は 10 を返すため非同型
```

---

## 総合判定

**FAIL** — critical=0 / major=8 / minor=4。**C-3 へは進めない**（先に下記 4 件の FAIL を是正し、簡易 C-1 を再実行すること）。

### 判定理由

plan の**事実精度は極めて高い**。再カウントした 21 項目の数値・件数はすべて plan の記述と一致し（食い違い 0 件）、plan が「転写する」と宣言した実装先例 14 件はすべて実在し、引用した行番号もほぼ正確だった。pbi-input との乖離 4 点も plan 側で明示・追跡され、`#873 CLOSED` / `delivery.py` 実在という上流事実は plan 内 5 箇所で一貫して扱われている（この点で **plan が正しく、pbi-input が stale** であることを本レビューでも独立に確認した）。

しかし **plan 内部の自己整合性に 4 件の実行阻害欠陥**がある。いずれも「実装に入ってから必ず衝突する」種類で、critical モードで plan 段階の是正が必要:

1. **循環依存**（C1-TODO-09）— T-24 の後方参照に対して T-25 の前方参照を直し忘れた結果、T-25〜T-32 の 8 タスクが依存解決不能になっている。修正は 1 箇所（T-25 の depends_on）で済む。
2. **`required` 件数の矛盾**（C1-TEST-14）— TC-04 と TC-05 が同時に PASS しない。V-1 で全 TC 機械実行するため必ず露見する。
3. **exit 0 到達不能**（C1-PLAN-04）— Phase 1 の構造上すべての RunEvidence が `unavailable` を含むのに、fixture 1〜5 が exit 0 を期待している。これは fixture 実装時ではなく**契約設計時**に決めるべき論点（known-unavailable の扱い）。
4. **T-38 の責務混在**（C1-SUP-PLAN-02）— critical の failure_policy に明示的に該当。

加えて WARN 8 件のうち、**C1-B1B2-17（exit 10 の意味が既存 `c3prime_verify.py` と逆転）** と **C1-PLAN-01（`blocked_by[]` 供給元不在で AC-13 が fail-open しうる）** は設計判断を伴うため、是正案とともに **C-3 の追加論点（U-10 / U-11）として提示**することを推奨する。

### C-3 へ上げる追加論点（提案）

| ID | 論点 | 出所 |
|----|------|------|
| **U-10** | Phase 1 で `evidence_status=complete` / exit 0 を到達可能にするか（known-unavailable allowlist を設けるか、Phase 1 は全 run partial とするか） | C1-PLAN-04 |
| **U-11** | 受理器 exit code の値割当を既存前例（`c3prime_verify.py`: 10=legacy）に合わせるか、本 PBI 独自（10=partial / 11=legacy）を通すか | C1-B1B2-17 |
| **U-12** | `blocked_by[]` の供給元（誰が未解決正本を candidate に注入するか）。未定義のままだと AC-13 の fail-closed が空振りする | C1-PLAN-01 |

### 是正後の再チェック対象（簡易 C-1）

C1-PLAN-01 / C1-PLAN-02 / C1-PLAN-04 / C1-PLAN-06 / C1-PLAN-09-AEE / C1-SUP-PLAN-01 / C1-SUP-PLAN-02 / C1-TODO-08 / C1-TODO-09 / C1-TEST-13 / C1-TEST-14 / C1-B1B2-17 の 12 項目（PASS 12 項目 + N/A 1 項目は再実行不要）。

## 自動修正ログ

| check_id | 修正内容 | 修正先ファイル |
|----------|---------|--------------|
| — | **本 C-1 では plan.md / todo.md / test-cases.md を一切修正していない**（C-1 は指摘の記録まで。是正は指摘確定後に別途実施する運用のため） | — |
