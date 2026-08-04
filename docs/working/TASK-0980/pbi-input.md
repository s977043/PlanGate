# PBI INPUT PACKAGE — TASK-0980

> Issue: [#980](https://github.com/s977043/plangate/issues/980)「Agent Identity と署名付きイベントを PlanGate の Actor／監査モデルへ段階導入する」
> スコープ: **本 PBI は Phase 0〜2 のみ**を対象とする（issue の 2026-08-04 実行指示コメント verbatim: 「まず **Phase 0〜Phase 2 を 1 つの実装単位**として進めてください」）。Phase 3 以降は Out of scope（順序依存を明記）
> 作成: 2026-08-05（**作成時点 main = `7de7baab9c09efe059f7be4a5ad21cd600f53eb9`（`7de7baa`）で実測**。裏取り結果は下表）
> 関連: [#981](https://github.com/s977043/plangate/issues/981)（Plan Contract — **実行順で先行**。責務境界は専用セクション参照）/ [#928](https://github.com/s977043/plangate/issues/928)（承認境界の技術層・repo-wide 層の穴 3 件 — 自己承認ガードの機械層）/ [#873](https://github.com/s977043/plangate/issues/873)・[#905](https://github.com/s977043/plangate/issues/905)（`delivery.py`）/ [#917](https://github.com/s977043/plangate/issues/917)・[#941](https://github.com/s977043/plangate/issues/941)（Collector / Executor / Reconciler）/ [#872](https://github.com/s977043/plangate/issues/872)・[#896](https://github.com/s977043/plangate/issues/896)（c3-prime 契約）

## Context / Why

PlanGate は現在 `ai-dev`（`PR_CREATED` まで）/ `ai-loop Delivery`（`MERGE_READY` まで）/ `Human`（最終判断と merge）の責務を分離し、Plan → Review → Approval → Execution → Verification を状態遷移として扱う。この設計を発展させ、**Human / AI Agent / System を統一的な Principal として扱い、各判断・実行・状態遷移について「誰が、どの役割・権限・委譲の下で、どの policy と evidence に基づいて決定したか」を追跡可能にする**のが #980 の目的である。

**ただし本 PBI は「監査基盤の新設」ではなく「既存 record への主体軸の additive 追加」である**。issue 本文の採用方針が正であり、以下は本 PBI の前提として固定する（issue verbatim）:

```text
Current State = 正本
Audit Event   = append-only な監査・説明記録
```

- **完全 Event Sourcing は採用しない**（状態をイベントから再構築しない）
- 初期実装の中心を暗号署名に置かない（Phase 5 / 6 へ後置）
- 優先順位: ① Actor / Role / Session / Delegation の分離 → ② append-only 監査イベント → ③ 既存状態遷移との統合 → ④ 職務分離・自己承認禁止 policy → ⑤ GitHub イベント正規化 → ⑥ hash chain → ⑦ 署名付き外部イベント

**本 PBI が塞ぐ穴の本質**: 現行 PlanGate は「**何が起きたか**」（state / plan_hash / decision / verdict）はきわめて厳密に記録するが、「**誰がそれをしたか**」はほぼ記録していない。裏取りのとおり、実行主体として記録される唯一の値はツール種別文字列（`agent=codex`）と判断エンジン定数（`issued_by="arbiter-v0.1"`）であり、Principal・Session・Delegation に相当する概念は実装・schema のいずれにも存在しない。既存の規範（sockpuppet 禁止 / `NO MERGE BY AI` / maker-checker 分離）は主体の分離を要求しているが、**その分離を機械が照合できる主体識別子が record 上に存在しない**。

---

## 裏取り結果: 「誰が何をしたか」の記録状況（作成時点 main = `7de7baa`・すべて実コード / 実ファイルで確認）

判定は **既存で満たす / 一部満たす / 未対応** の 3 値。根拠はファイル:行。**推測で「実装済み」と書いていない**。

### 1. run.ndjson（ai-dev 実行ログ）

| # | 観点 | 判定 | 根拠（ファイル:行） |
|---|---|---|---|
| A-1 | 実行主体の記録 | **一部満たす**（ツール種別のみ・Principal / Session ではない） | `bin/plangate:2037`（`agent="${PLANGATE_IMPL_AGENT:-codex}"`）→ `bin/plangate:2110-2113`（`session_started` を `"detail":"agent=$agent"` として書く）。実物で確認: `docs/working/TASK-0896/run.ndjson` は 1 行のみで `{"ts":...,"task_id":"TASK-0896","phase":"D","event":"session_started","detail":"agent=codex"}`。**`codex` / `opencode` / `cursor` はツール種別であって主体識別子ではない** |
| A-2 | schema 側の actor 用プロパティ | **既存で満たす（定義）／未対応（利用）** | `schemas/run-event.schema.json:48-51` に `agent`（"Agent or tool that produced the event"）、`:52-55` に `by`（"Human or agent identifier (used for gate events)"）、`:56-60` に `plan_hash` が**既に定義されている**。一方 `bin/plangate` の `plangate_append_ndjson` 呼び出しは **3 箇所のみ**（`:1279` `session_ended` / `:2005` `parallel_review`（→ `decision-log.jsonl` 宛）/ `:2112` `session_started`）で、**いずれも `agent` / `by` / `plan_hash` を使っていない**（すべて `detail` 文字列に詰めるか省略）。→ **schema 無変更で刻める既存プロパティが 3 つ空いている** |
| A-3 | 追加キーの可否 | **未対応（制約）** | `schemas/run-event.schema.json:77` は `additionalProperties: false`。`actor_session_id` / `principal_id` / `correlation_id` / `causation_id` / `idempotency_key` / `schema_version` という**名称の新キーは schema 違反**になる。`^_` 注釈キーの `patternProperties` も**本 schema には無い**（`c3-approval.schema.json:88-92` / `c3-prime.schema.json` にはある — 対比） |
| A-4 | event 語彙 | **未対応** | `schemas/run-event.schema.json:25-46` の `event` enum は 20 値（`plan_generated` … `session_ended`）。issue の Phase 1 対象イベント名（`PlanApproved` / `ExecutionRequested` / `ExecutionStarted` / `MergeReadyDeclared` / `HumanDecisionRecorded` 等）は**いずれも不在**。近縁の既存値は `approved` / `exec_started` / `session_started` / `pr_created` / `pr_merged` |
| A-5 | CI による schema 強制 | **未対応** | `scripts/schema_mapping.py:36` の対応キーは basename **`run-event.json`**（`.ndjson` ではない）。`scripts/validate-schemas.py:80` は `base.rglob("*.json")` のみを収集する。したがって実ファイル名 `run.ndjson` は**どちらにも掛からず CI 検証されない**。同 `schema_mapping.py:38-40` のコメントも「NDJSON である `plangate-event.schema.json` は本マッピングに含めない」と明記 |
| A-6 | 実運用量 | **一部満たす（ほぼ未計装）** | `git ls-files 'docs/working/*/run.ndjson'` → **3 件のみ**（TASK-0106 / TASK-0872 / TASK-0896）。全 TASK の大多数は `run.ndjson` を持たない。`gitignore` 対象ではない（`.gitignore` に `run.ndjson` の記載なし）ため「書かれていない」が正確 |

### 2. その他の既存記録層

| # | 記録層 | actor 情報 | 判定 | 根拠 |
|---|---|---|---|---|
| A-7 | `approvals/c3.json`（legacy 人間 C-3） | `approved_by`（**必須**）+ `_approved_by_source` + `_approver_identity_unverified` + `_note` | **一部満たす**（presence は強い / identity は未検証） | 生成側 `bin/plangate:2402-2413`。`approved_by` は `git config user.email` → `user.name` → `$USER` の順でフォールバック（`bin/plangate:2392-2394`）。schema 必須は `schemas/c3-approval.schema.json:7-14`（required 配列に `approved_by` を含む `:11`）+ `:32-35`（`approved_by` は `{"type":"string"}` のみ・形式制約なし）。実物: `docs/working/TASK-0917/approvals/c3.json` の `"approved_by": "s977043@users.noreply.github.com"` + `"_approver_identity_unverified": true`。**注記 verbatim**（`bin/plangate:2412`）: 「Human presence verified via L1-L4; identity (approved_by) is git-config derived and NOT cryptographically verified.」 |
| A-8 | Human presence 検証（L1-L4） | 主体の**クラス**（人間か AI か）のみ判定・**個体**は判定しない | **一部満たす** | `bin/plangate:2294-2342`。L1 = isatty（`:2305-2310`）/ L2 = env barrier（`CI` `CLAUDE_AGENT` `CURSOR_AGENT` `PLANGATE_BYPASS_HOOK`・`:2312-2318`）/ L3 = 親プロセス comm heuristic（`claude` / `codex` / `cursor` の grep・`:2325-2329`）/ L4 = 対話 nonce challenge（`:2331-2338`）。監査は `docs/working/_audit/hook-events.log` へ `ts` / `event`（`{context}_presence_attempt`）/ `verdict` / `ppid` / `isatty_stdin` / `detail` の 6 キーを append（`:2298-2304`）。**「人間が居た」ことは検証するが「どの人間か」は検証しない** |
| A-9 | `approvals/c4.json`（Human C-4） | `approved_by`（必須）/ `pr_number` / `pr_sha` | **一部満たす**（同上・identity 未検証） | `schemas/c4-approval.schema.json:7,21-23`。`_` 注釈キーは `patternProperties` で許容（`:37-41`） |
| A-10 | c3-prime record（ai-loop 自動承認） | `issued_by`（**必須**）+ `reviewers.model_a` / `model_b`（**役割スロット**） | **一部満たす**（発行元は自己申告・reviewer は identity を持たない） | 必須キー 14 は `scripts/ai-loop/c3_contract.py:44-49`（`issued_by` を含む）。schema は `schemas/c3-prime.schema.json` の `required` 14 + `additionalProperties: false`、`issued_by` は `{"type":"string","minLength":1}` のみ。`reviewers` は `model_a` / `model_b` の 2 スロット固定（`additionalProperties: false`）で、snapshot の 5 キーは `verdict` / `plan_hash` / `source_sha` / `plan_package_hash` / `evidence_ref`（`c3_contract.py:41`）＝**model 名・session・principal を持たない**。契約側の説明も `docs/workflows/ai-loop/c3-prime-contract.md:53`「`issued_by` … 例: `arbiter-v0.1`」 |
| A-11 | arbiter provenance record | `issued_by` は**ハードコード定数** | **一部満たす**（engine 識別のみ） | `scripts/ai-loop/arbiter.py:559`（`ISSUED_BY = "arbiter-v0.1"`）/ `:560`（`POLICY_REF = "auto-approve-lite-clean@v4"`）→ `:781-782` で provenance へ刻印。実物: `docs/working/ai-loop-runs/20260707T031707Z-b8876ff-run003-r3.json` は `{"boundary_check","class_check","decision","issued_by":"arbiter-v0.1","lite_check","policy_ref","target_sha","timestamp","w_check":{"model_a":"approve","model_b":"approve"}}` — **`w_check` は verdict のみで、どのモデル／どのセッションが返したかは記録されない**。`docs/working/ai-loop-runs/*.json` は `schema_mapping.py` に**未登録** = CI 未検証 |
| A-12 | `delivery/record.jsonl`（Delivery 実行記録） | **なし** | **未対応** | `grep -n "issued_by\|actor\|principal\|session_id\|requested_by\|decided_by" scripts/ai-loop/{delivery,collector,executor,reconciler}.py` → **0 件**。entry 4 種は `intent` / `receipt` / `state` / `merge_ready`（`delivery.py:407,417,426,589`）。実測したフィールドは `kind` / `action_id` / `action_kind` / `payload` / `state` / `head_sha` / `pr_number` / `reasons` / `round` / `result_ref`（receipt: `delivery.py:589-594`）/ `finding_type`（`repair_review` intent 時のみ: `delivery.py:421-422`、receipt 側は `:596`）/ `record`（merge_ready: `:426`）/ 付与される `at` / `entry_id`（契約: `docs/workflows/ai-loop/delivery-state-machine.md:83-96`）。**このいずれにも主体を表すフィールドは無い** = 「誰が intent を出し、誰が receipt を書いたか」は記録されない。**U-9 の `entry_id` 影響見積りはこの実測キー集合を前提に行うこと**（`entry_id` は `at` / `entry_id` を除く**全キー**の正規化 JSON の sha256 — `delivery.py:180-181`。したがってキーを 1 つ足すだけで既存 entry と別 id になる） |
| A-13 | `decision-log.jsonl` | `chosen_by`（enum `agent` / `human` / `auto`）— **テンプレート定義上** | **一部満たす**（役割クラスのみ・かつ**実運用が定義から乖離**） | 定義: `docs/working/templates/decision-log-schema.md:23`（`chosen_by` は必須・3 値 enum）。**実測の乖離**: `docs/working/TASK-0917/decision-log.jsonl` は `chosen_by` が **0 件**、代わりに `by`（`"human"`）が **36 件**。`ts` / `phase` / `decision` / `by` / `ref` の 5 キーのみで `task` / `type` / `reason` / `alternatives` も欠落。**`schemas/` に decision-log 用の JSON Schema は存在せず**（`schema_mapping.py` にも未登録）機械検証がないため乖離が検出されていない。追跡対象ファイルは 19 件（`ls docs/working/*/decision-log.jsonl \| wc -l`） |
| A-14 | `docs/working/_audit/hook-events.log` | **なし**（hook 名 + task_id のみ） | **未対応** | 形式は TSV: `printf '%s\t%s\tcheck-plan-hash\t%s\t%s\n' ts level task_id msg`（`scripts/hooks/check-plan-hash.sh:31`）。同型の `AUDIT_LOG` 定義が 10 本以上の hook に存在（`check-forbidden-files.sh:30` / `check-merge-approvals.sh:29` / `check-v3-review.sh:29` 等）。**`.gitignore:21` で追跡対象外** = 監査証跡がリポジトリに残らない（`:58` で `.bak.*` も除外） |
| A-15 | `docs/working/_audit/skip-decision-log.jsonl` | `acknowledged_by`（人間 ID） | **一部満たす** | 実物 177 行。1 行例: `{"ts":...,"event":"EH-3_SKIP","target":...,"skip_reason":...,"acknowledged_by":"s977043","acknowledged_at":...}`。**追跡対象**（`.gitignore:59` は `.bak` のみ除外）。ただし `acknowledged_by` は自由文字列・schema なし・発行元検証なし |
| A-16 | metrics `events.ndjson`（`plangate-event.schema.json`） | `by`（"agent / human の識別子（**人名・社名は不可**）"）/ `schema_version`（**必須**）/ `parent_event_id` / `gate_id` / `plan_hash` / `model_profile` / `tool_name` | **既存で満たす（設計の先例として）／未対応（本 PBI の目的には使えない）** | `schemas/plangate-event.schema.json` の `required` は `["ts","task_id","event","schema_version"]`、`additionalProperties: false`。`parent_event_id` は "Causal link to a prior event id"（= causation の先例）、`gate_id` とともに `^[A-Za-z0-9._:-]{1,64}$` で識別子のみに制約。**ただし出力先 `docs/working/_metrics/events.ndjson` は `.gitignore:56` で追跡対象外**であり、かつ後述のプライバシー制約により人名・identity を載せられない |
| A-17 | Delegation（委譲）の概念 | **否定形 1 軸のみ実在**（`no-commit` 境界）。主体 ID / 有効期限 / resource は不在 | **一部満たす** | **EH-9（`scripts/hooks/check-delegation-commit-boundary.sh`）が委譲スコープ強制を既に実装している**: 宣言（todo.md メタ `delegation_commit_boundary: no-commit`）→ 伝播（親が `PLANGATE_DELEGATION_NOCOMMIT=1` を注入）→ 強制（`:62-65` 未宣言は従来動作・`:95-118` で `git commit` / `git push` / `gh pr merge` / `gh repo sync` / `sh -c '...'` 二段実行を決定論 block）→ 監査（`:45-52` `log_event` が `hook-events.log` へ `VIOLATION` を記録・command 全文でなく class + hash）まで揃う。仕様は `:2-7` の docstring。宣言の正本は `docs/ai/core-contract.md:135` / `docs/ai/hook-enforcement.md:141`、配線は `.claude/settings.example.json:58`。**すなわち issue の Delegation モデル（`allowed_actions` / `allowed_resources` / `valid_until` / `policy_ref`）のうち「禁止 action の宣言と強制」1 軸は実在する**。**不在なのは** `delegation_id` / `issuer_principal_id` / `subject_principal_id` / `valid_from` / `valid_until` / `allowed_resources` / 許可側（allow-list）の表現。`docs/ai/subagent-delegation/` は派遣プロンプトの**規範**であり機械的な権限委譲 record ではない（こちらは従来どおり未対応） |

### 3. 職務分離 / 自己承認禁止（issue の Phase 3 前提となる現状）

| # | 観点 | 判定 | 根拠 |
|---|---|---|---|
| A-18 | 規範層（sockpuppet 禁止 / merge = Human-owned） | **既存で満たす** | `.claude/rules/responsibility-classes.md`「4 分類」表（merge / C-3・C-4 ゲート判断は Human-owned）+ 「**merge は Human-owned 固定**（sockpuppet 禁止と一貫。AI は merge-ready report と branch 整備まで）」 |
| A-19 | maker / checker 分離（I-2） | **一部満たす**（LoopSpec 派生時のみ強制・record 未刻印） | 強制点は `scripts/ai-loop/plan_package.py:196-199`（`derive_loopspec()`: `maker` / `checker` 必須・同一値は `PlanPackageError`）。正本は `docs/workflows/ai-loop/loopspec.md:69-70,111-112,247-249`。**c3-prime record の必須 14 キーに maker / checker は無い**（`c3_contract.py:44-49`）→ 分離の事実は下流の record に残らない |
| A-20 | W チェック（2 モデル非対称二重判定） | **一部満たす**（verdict は残る / 主体は残らない） | 思想正本 `docs/ai/ai-loop/design-philosophy.md:90-94`（「同一の動機を持つ主体は、自分の仮定を疑えない。独立性と非対称性を**構造**で強制する」）。しかし A-11 のとおり record に残るのは `model_a` / `model_b` の verdict 文字列のみで、**実際に別モデル・別セッションだったことを事後照合できない** |
| A-21 | 発行元真正性の未検証（既知の限界として明文化済み） | **未対応（明文化済み）** | `docs/ai/ai-loop/design-philosophy.md:96-109`（I-3「AI の自己申告を信用しない」に対する honest 注記: 偽装不可能性までは主張しない）/ `docs/workflows/ai-loop/execution-runbook.md:296`「provenance の `issued_by` は自己申告であり、署名等の発行元検証機構は…」/ `docs/workflows/ai-loop/decision-table.md:240`「`issued_by` … 真正性担保には署名等が別途必要」/ `docs/workflows/ai-loop/stop-rollback.md:386`。**さらに `docs/workflows/ai-loop/delivery-state-machine.md:71` は同型問題を明示**: `ci_failure_taxonomy` の manual entry は `source:"manual"` の**自己申告のみ**で受理され「append-only の record に 1 行足せる主体は AI ループ自身も含む」「EH-3 / `maintenance.json` の『発行元未検証』と**同型の未解決課題**」 |
| A-22 | 自己承認ガードの機械層 | **一部満たす**（経路により非対称） | `scripts/ai-loop/gh_exec.py` の default-deny allowlist により **ai-loop Executor 経路**では `gh pr review --approve` / `gh pr merge` が組み立て不能。ただし同 module docstring 自身が「同一セッションの Bash や別プロセスからの `gh` は塞がらない」と明示。`grep -rn "pr review" scripts/hooks/*.sh` → **0 件**（セッション層のガードは不在）。詳細な現状分析は **#928 / `docs/working/TASK-0928/pbi-input.md` が正本**（本 PBI では再分析しない） |
| A-23 | 昇格経路の入口条件（署名の位置づけ） | **混合**（要件として定義済み・**現状は未適用**） | `docs/ai/ai-loop/hotl-merge-entry-criteria.md:44-48`「**条件 1: provenance 発行元検証（署名 / HMAC）** — `issued_by`（誰が承認したか）の自己申告を解消し、署名 / HMAC 等で発行元の真正性を検証可能にする」。**ただし同表 `:49` の「現状」行は「❌ 未適用」**（充足条件は `:50` に (a) provenance schema への `hmac_signature` 定義 / (b) 署名検証ロジックの test PASS / (c) 署名なし・改竄 provenance の reject test）。関連する条件（`:94` 「現状 ❌ 未検証」/ `:95` 「auto-approve 経路が『別アカウントでの自己承認』と機能的に等価にならないこと」）も同様に未充足。→ **#980 Phase 5 / 6 はこの既存 entry criteria の充足手段であり新しい要求ではない**が、**現状の充足度は 0**（A-2 / A-16 と同じ「定義あり・適用なし」パターン） |

### 集計

全 23 項目（A-1〜A-23）の内訳。**同一項目内で判定が割れるもの（定義あり・適用/利用なし）は「混合」に分離**し、二重計上しない（合計 1 + 13 + 6 + 3 = 23）。

| 判定 | 件数 | 項目 |
|---|---|---|
| 既存で満たす | **1** | A-18 規範層（sockpuppet 禁止 / merge = Human-owned） |
| 一部満たす | **13** | A-1 実行主体 / A-6 実運用量 / A-7 `approved_by` / A-8 presence L1-L4 / A-9 C-4 / A-10 c3-prime `issued_by` / A-11 arbiter provenance / A-13 `decision-log.jsonl` / A-15 skip-decision-log / **A-17 Delegation（EH-9 の `no-commit` 1 軸）** / A-19 maker-checker / A-20 W チェック / A-22 自己承認ガード機械層 |
| 未対応 | **6** | A-3 追加キー不可（`additionalProperties: false`）/ A-4 event 語彙 / A-5 CI 強制 / A-12 Delivery record の actor / A-14 hook 監査ログ（非追跡・actor なし）/ A-21 発行元真正性 |
| 混合（定義あり・適用/利用なし） | **3** | A-2 `agent` / `by` / `plan_hash`（schema 定義済み・writer 未使用）/ A-16 metrics event schema（設計先例としては満たす・格納先としては使えない）/ **A-23 hotl 条件 1（要件定義済み・`:49` 現状 ❌ 未適用）** |

#### 本 PBI（Phase 0〜2）の実装対象 — 明示列挙

「未対応 6 件を潰す」ではない。**未対応 6 件のうち 3 件（A-5 / A-14 / A-21）は本文書の別箇所で明示的に scope 外**としており、逆に「一部満たす」の A-17 は実装対象に入る。判定を取り違えないよう以下に**列挙で固定**する。

| 区分 | 項目 | 扱い |
|---|---|---|
| **実装対象（Phase 0〜2）** | **A-3**（追加キーを表現できる格納先の決定）/ **A-4**（Audit Event 語彙の定義）/ **A-12**（Delivery record への actor 軸追加）/ **A-17**（Delegation モデル定義。判定は「一部満たす」だが**不足分の実装対象**。**EH-9 の既存宣言との関係〔吸収 / 併存 / 参照〕を ADR で先に決める** — S-6。決めずに新 schema を作ると宣言が 2 箇所に並立し、本 PBI が最も避けたい二重正本〔F-1 と同型〕を自ら作る） | 実装する |
| 実装対象（一部満たすのうち主体軸） | A-1 / A-7 / A-9 / A-10 / A-11 / A-13 / A-19 / A-20 のうち、**主体識別子を刻む部分に限る**（各 record の判定ロジック・hash 契約には触れない） | additive に実装する |
| **scope 外（未対応だが本 PBI では扱わない）** | **A-5**（CI schema 強制の経路新設）→ 「スコープ外の発見」**F-3 の別 Issue 候補** / **A-14**（hook 監査ログの追跡対象化）→ **Assumptions で「本 PBI で変更しない」と宣言済み**（プライバシー判断を伴うため U-5 の決定後）/ **A-21**（発行元真正性）→ **Out of scope の Phase 6**（Risk 表でも「Phase 6 まで保証されない」と明記） | 扱わない |
| scope 外（既存正本を参照するのみ） | **A-18**（規範層）/ **A-23**（hotl entry criteria） | 再定義しない |
| scope 外（別 PBI） | **A-22** 自己承認ガードの機械層 → **#928 の scope**（本 PBI は policy 層の宣言語彙まで） | 扱わない |

> **AC-P1（Phase 境界の遵守）はこの表を判定基準とする**。A-5 / A-14 / A-21 に触れる diff が出た時点で AC-P1 違反。

---

## What（Scope）

### In scope — Phase 0〜2 のみ

issue の実行指示コメント §「今回の対応範囲」6 項目に 1:1 対応する。

| # | 作業 | Phase | 成果物（想定） |
|---|---|---|---|
| S-1 | `docs/working/TASK-0980/` の標準 artifact 作成 | — | `plan.md` / `todo.md` / `test-cases.md` / `review-self.md` / `review-external.md` / `handoff.md`（本 `pbi-input.md` を含め Plan Package 6 要素） |
| S-2 | **現行構造の棚卸し**（本 pbi-input の裏取り表を plan で確定版に昇格） | Phase 0 | plan の付表 + 既存状態機械との対応図 |
| S-3 | **Actor model ADR**（Principal / Role / ActorSession / Delegation の定義と正本配置） | Phase 0 | `docs/decisions/adr-00N-<slug>.md`（既存慣行 = `docs/decisions/adr-001-approve-out-of-band.md` の **1 件のみ実在**。採番・slug は U-1 で確定） |
| S-4 | **Audit Event model ADR**（append-only record の格納先・必須項目・失敗時方針） | Phase 0 | 同上（S-3 と同一 ADR に含めるか分割するかは U-1） |
| S-5 | **Event Sourcing 採否 ADR**（`Current State = 正本` の明文化と根拠） | Phase 0 | 同上 |
| S-6 | **Principal / ActorSession / Delegation の最小 schema 定義**。**EH-9 の既存 Delegation 宣言（`delegation_commit_boundary: no-commit`）との関係を ADR で決定する**（吸収 / 併存 / 参照のいずれか。裏取り A-17） | Phase 1 | 新規 schema または既存 schema の additive 拡張（配置は U-2） |
| S-7 | **append-only Audit Event の最小 schema 定義**。**必須項目は下記「最小 Audit Event 必須項目 21 個（issue コメント verbatim）」節を正とする** | Phase 1 | 同上 |
| S-8 | **既存 record 形式への additive 実装**（既存状態を正本として維持・新基盤を別に作らない） | Phase 1 | 実装（対象モジュールは U-2 の決定に従う） |
| S-9 | **状態遷移の監査イベント化**（対象は issue 指定の 5 点: C-3' 承認 / escalation・`EXEC_RETURN`・`HUMAN_ESCALATED`・`PR_CREATED`・`MERGE_READY`） | Phase 2 | 実装 + 契約文書追記 |
| S-10 | **requester と decision maker を別々に記録する契約の定義** | Phase 2 | schema フィールド + 契約文書 |
| S-11 | **Human C-4 の判断を記録できる契約の定義**（記録契約のみ。**`MERGED` 遷移を AI 側から実装しない**） | Phase 2 | 契約定義（実装は記録側のみ） |
| S-12 | テスト・サンプルイベント・利用手順 | Phase 0〜2 | `scripts/ai-loop/test_*.py` 相当 + `docs/` の利用手順 |

### Out of scope（Phase 3 以降 / 順序依存あり）

issue の「作業中に別 Issue へ切り出す条件」に該当するものは**本 PBI の PR へ混ぜず、Issue 候補として報告のみ**行う。

```text
#981 PR1〜PR3（Plan Contract 棚卸し・ADR → Executor handoff → revision/resume）
  ↓
#980 Phase 0〜2  ← 本 PBI
  ↓
#981 PR4: #980 との監査統合
  ↓
#980 Phase 3: 職務分離 / 自己承認禁止 policy（role-action matrix / transition authority matrix / deny reason taxonomy）
  ↓
#980 Phase 4: GitHub event normalization（External Event Envelope / 重複排除 / mapping）
  ↓
#980 Phase 5: tamper-evident audit（canonical serialization / previous_record_digest / hash chain）
  ↓
#980 Phase 6: 署名付き外部イベント（Buzz / Nostr・public key binding・replay prevention・key rotation）
```

| 対象 | 理由 |
|---|---|
| Phase 3 の policy 実装（Executor 自己承認拒否 / AI `MERGED` 拒否 / delegation scope・expiry 検証） | Phase 1 の Principal / ActorSession schema が確定しないと比較対象が定義できない。また自己承認ガードの**機械層**は **#928 の scope**（重複させない） |
| Phase 4 の GitHub webhook / API adapter 本実装 | issue「別 Issue へ切り出す条件」に明記 |
| Phase 5 の hash chain | 同上。`integrity.previous_record_digest` は Phase 1 では **schema 上 nullable / 将来拡張可能**に留める（issue 指示 verbatim） |
| Phase 6 の Buzz / Nostr 連携・暗号署名検証・key rotation / revocation | 同上。`NO PRIVATE KEY IN PLANGATE` は非目標として維持 |
| 完全 Event Sourcing / DB migration を伴う永続化基盤変更 / 認証・認可基盤の再設計 | issue「別 Issue へ切り出す条件」に明記 |

### Non-goals（issue「非目標」+ 実行制約 verbatim）

- 既存の ai-dev / ai-loop / Human 責務境界の変更
- `PR_CREATED` / `MERGE_READY` / `MERGED` の正本定義の変更
- **`NO MERGE BY AI` の緩和**（AI 側から `MERGED` へ遷移させる実装を行わない。Human decision を**記録する契約**のみ定義する）
- 完全 Event Sourcing への移行 / **完全 Event Sourcing 基盤を構築すること**
- **既存状態管理を一括置換すること**（issue 非目標 verbatim。既存状態を正本として維持し additive に接続する）
- **暗号署名だけで承認の正当性を保証すること**（issue 非目標 verbatim。署名は発行元の真正性を示すのみで、policy 承認の正当性とは別軸 — AC-13 の「署名検証済みと policy 承認済みを別々に表現できる」と表裏。Phase 5 / 6 を「署名を入れれば承認が正当になる」と誤読しないこと）
- **初期段階で全イベントを Nostr へ公開すること**（issue 非目標 verbatim。Core への依存追加の禁止とは別命題）
- Buzz / Nostr 依存の Core への追加
- Agent ごとの秘密鍵管理基盤を PlanGate Core へ実装すること / PlanGate が秘密鍵を保持すること
- Actor Identity を認証基盤全体の置換として扱うこと
- **単一 `trust_level` の導入**（issue 設計原則 3: 主体固定の信頼値は初期モデルに入れない）
- 破壊的 migration / 既存 schema・CLI・record との後方互換の破壊
- 秘密鍵・token・prompt 全文・個人情報の監査 payload への保存
- **#981 が担当する領域の先取り**（下記「#981 との責務境界」参照）

---

## #981 との責務境界

> 出典: issue #981 の 2026-08-04 コメント（Human 確定）および #980 の同日コメント「#980 では Plan Artifact や approval hash を再定義せず、#981 が確定した参照を Audit Event の `plan_ref` / `approval_ref` として利用してください」「#981 実装中は Principal / ActorSession ID を opaque な参照値として扱い、主体モデル・委譲・職務分離の完全な検証は本 Issue に残します」

| 領域 | 担当 | 本 PBI での扱い |
|---|---|---|
| 実行対象 Plan の識別と不変性（`plan_id` / `plan_hash` / `plan_package_hash`） | **#981** | **再定義しない**。Audit Event からは `plan_ref` として**参照**するのみ |
| Plan Package・c3-prime との統合 | **#981** | 同上。`docs/workflows/ai-loop/c3-prime-contract.md` は #981 が正本整理する。本 PBI は追記しない（するなら #981 の ADR 確定後） |
| Planner と Executor が異なる場合の handoff 契約 | **#981** | 参照のみ |
| `ExecutionRequested` / `ExecutionStarted` の **Plan 参照** | **#981** | 参照フィールドの**定義**は #981。本 PBI は同イベントの **actor 部分**（`actor.principal_id` / `actor.actor_session_id` / `actor.role`）を実体化する |
| Plan revision・approval invalidation | **#981** | 参照のみ |
| Resume・Retry 時の Plan 再検証 | **#981** | 参照のみ |
| **Principal / ActorSession / Delegation の主体モデル** | **#980（本 PBI）** | **実体化する**。#981 が opaque string として置いた参照用 ID フィールドに、型・語彙・生成規則・検証規則を与える |
| **requester と decision maker の監査** | **#980（本 PBI）** | 実体化する（S-10） |
| **append-only Audit Event** | **#980（本 PBI）** | 実体化する（S-7 / S-9） |
| 職務分離 policy（role-action / transition authority matrix） | **#980（Phase 3）** | 本 PBI では**宣言に必要な語彙の定義まで**。policy 実装は Phase 3 |
| 外部イベント正規化 | **#980（Phase 4）** | Out of scope |
| **`run-event.schema.json` の既存プロパティ `agent` / `by` の語彙定義と writer 所有権** | **未定（衝突リスクあり）** | **#981 PR1 の ADR で先に確定する。本 PBI は決めない。** 理由: main 既在の `docs/working/TASK-0981/pbi-input.md:43`（ギャップ #9）が同じ `plan_hash` / `agent` / `by` の 3 プロパティを「**PR2 の最小差分候補**」として押さえており、同 `:123` の PR2 スコープには **#8「Planner / Executor 分離」= actor 側**が含まれる。実行順は **#981 PR2 が先**。`run-event.schema.json:77` は `additionalProperties: false` かつ `^_` patternProperties も無いため、**1 フィールドに 2 語彙が入ると逃げ場がなく、拡張は HO patch になる** |

**関係の要約**: #981 は「**どの Plan を**実行してよいか」の契約、#980 は「**誰が**その実行・判断を行ったか」の契約。#981 が定義する参照用 ID フィールド（opaque string）を #980 が実体化する **前方参照関係**であり、逆方向の依存を作らない。したがって **#981 の PR1〜PR3 完了後に本 PBI を着手する**（issue #980 の 2026-08-04 コメントの推奨順序）。

**重複回避の具体規律**（plan / C-1 で検査する）:

- 本 PBI の成果物は `plan_hash` / `plan_package_hash` / `artifact_hashes` / `source_sha` の**算出規則・検証規則を一切定義しない**（参照のみ）
- 本 PBI の裏取り表は #981 の pbi-input と**重複する項目を再掲しない**（`allowed_paths` 抽出・evidence stale 判定・exec preflight の強度差・`plan_version` 要否は #981 が正本）
- `c3-prime-contract.md` への追記は #981 の ADR で正本配置が決まるまで行わない
- **`run-event.schema.json` の既存プロパティ（`agent` / `by` / `plan_hash`）に本 PBI が独自の語彙を割り当てない**（所有権が #981 PR1 の ADR で確定するまで。上表最終行）

---

## 受入基準

> **1:1 保持と起案の区別**: 以下 **AC-1〜AC-20 は issue #980 本文の「受け入れ条件」20 項目を 1:1 で保持**したものである（文言は issue verbatim、検証方法と Phase 帰属を付与）。**AC-P1〜AC-P4 は本 pbi-input が起案した Phase 0〜2 完了条件**であり、plan で最終確定する。
>
> **issue コメント由来の 5 項目（1 Run に複数 ActorSession / Planner と Executor が別 Principal でも同一 Run を継続 / Executor は承認済み Plan のみ実行 / Plan 変更時に再承認 / Planner = Executor 時の職務分離 policy）は、責務分担の確定により Plan 契約側が #981、主体モデル側が #980 に分割された**。本 PBI では AC-1・AC-2・AC-4 の中で主体側のみを扱い、Plan 参照側は #981 の AC に委ねる（重複させない）。

| AC | 内容（issue 本文 verbatim） | Phase 帰属 | 検証方法 |
|---|---|---|---|
| **AC-1** | Human・Agent・Service・System を共通 Principal として表現できる | Phase 1 | schema に `principal_type` の 4 値 enum（`human` / `agent` / `service` / `system`）が定義され、4 種すべてのサンプル record が schema 検証を通る |
| **AC-2** | Principal、Role、ActorSession、Delegation が区別されている | Phase 1 | (a) 4 概念が**別の型 / 別のフィールド群**として定義され、ADR に「同一 Principal が複数 Role・複数 ActorSession を持ちうる」ことが明記されている。**(b) 1 つの `run_id` に複数の `actor_session_id` が関連付く関係（Run : ActorSession = 1 : N）が schema 上で表現でき、Planner と Executor が別 Principal / 別 ActorSession のサンプル record が schema 検証を通る**（issue コメントの主体側 AC 2 件に対応。`TASK-0981/pbi-input.md:168` は当該 AC を「実装は PR2 + #980」として #980 へ送っており、**本 AC が無いとどちらの PBI にも検証点が無くなる**。`run_id` の定義そのものは U-7 に依存する） |
| **AC-3** | Actor の capability と policy 上の permission が区別されている | Phase 1（語彙）/ Phase 3（強制） | ADR に `capability` / `permission` / `delegation` / `authority` の 4 語の定義と、`gh pr merge` を例とした「capability = true / permission = false / authority = false」の対応表がある |
| **AC-4** | 各状態遷移について requester、decision maker、policy、evidence、correlation を追跡できる | Phase 2 | Audit Event schema に `actor`（requester）/ `decision.decision_maker_*` / `decision.policy_ref` / `evidence_refs` / `correlation_id` が存在し、S-9 の 5 イベントすべてで非空に埋まるサンプルがある |
| **AC-5** | Executor による自己レビュー・自己承認を policy で禁止できる | **Phase 3**（本 PBI は語彙まで） | 本 PBI では独立性レベル（Level 0〜4）の語彙と、issue が列挙する**比較対象 7 項目**（`principal_id` / `actor_session_id` / `parent_session_id` / `delegation_id` / `provider` / `model_id` / **`credential` ないし `execution environment`（= `execution_environment_id`）**）が schema 上比較可能であることまで。**`execution_environment_id` は Level 2「別 session・同一 provider / credential」の判定に必須**（欠けると Level 2 と Level 3 を区別できない。生成主体は U-6）。**禁止の実装は Phase 3 / 機械層ガードは #928** |
| **AC-6** | AI による `MERGED` 遷移を禁止できる | **Phase 3**（本 PBI は不変条件の再確認まで） | 本 PBI が `MERGED` 遷移経路を**追加しない**ことを diff で確認（`NO MERGE BY AI` 不変） |
| **AC-7** | Human approval 必須遷移を宣言的に定義できる | Phase 2（契約定義）/ Phase 3（強制） | 契約文書に「どの遷移が Human approval 必須か」の表があり、C-4 / `MERGED` が含まれる |
| **AC-8** | event schema が version を持つ | Phase 1 | Audit Event schema の `required` に `schema_version` が含まれる（先例: `schemas/plangate-event.schema.json` の `required` は `["ts","task_id","event","schema_version"]`） |
| **AC-9** | 未知 schema / 未知 actor / 未知 policy を fail-closed で扱える | Phase 1 | 未知 `schema_version` / 未知 `role` / 未知 `policy_ref` を与えた negative test が**成功扱いにならない**（既存 `c3prime_verify.py` の allowlist + `additionalProperties: false` の前例に倣う） |
| **AC-10** | event 再配送を idempotency key または external event id で排除できる | Phase 1 | 同一 `idempotency_key` の重複記録が拒否または安全に無視される test（既存前例: `delivery.py` の `entry_id` 冪等 append `delivery.py:476-487`） |
| **AC-11** | 外部イベントの raw payload または digest を追跡できる | **Phase 4**（本 PBI は schema 上の nullable 予約まで） | `source.external_event_id` / `integrity.payload_digest` のフィールドが定義され nullable であること |
| **AC-12** | policy、model、tool、harness の version または digest を記録できる | Phase 1 | ActorSession schema に `tool_name` / `model_id` / `model_version` / `harness_version`、Audit Event に `decision.policy_ref` / `policy_digest` が存在する |
| **AC-13** | 署名検証済みと policy 承認済みを別々に表現できる | Phase 1（表現）/ Phase 6（検証） | `integrity.signature_ref`（署名）と `decision.result`（policy）が**別フィールド**であり、署名不在でも `decision.result` が成立しうることを ADR に明記 |
| **AC-14** | 暗号署名が利用できない連携先でも運用可能である | Phase 1 | `signature_ref: null` のサンプル record が schema 検証を通り、かつ既存フローが不変であること |
| **AC-15** | PlanGate が秘密鍵を直接保持しない | 全 Phase（不変条件） | 本 PBI の diff に鍵素材・鍵生成・鍵保管の実装が 1 行も含まれないことを確認 |
| **AC-16** | Audit Event 保存失敗時に重要状態遷移を成功扱いしない方針が定義されている | Phase 1（方針）/ Phase 2（実装） | ADR に方針が明記され、Phase 2 で「audit 保存失敗時に重要状態遷移だけが進まない」test が PASS |
| **AC-17** | audit log の欠損・改ざん・順序変更を検出できる設計判断が記録されている | Phase 0（設計判断）/ Phase 5（実装） | ADR に hash chain の設計と「Phase 1 では `previous_record_digest` を nullable に留める」判断・その理由が記録されている |
| **AC-18** | 完全 Event Sourcing を前提としない | Phase 0 | ADR に `Current State = 正本` / `Audit Event = append-only 監査記録` が明記され、状態をイベントから再構築する経路が設計上存在しないことを確認 |
| **AC-19** | 現行の ai-dev / ai-loop / Human 責務境界を壊さない | 全 Phase | 既存 Delivery 判定結果が変わらない回帰テストが PASS（既存 `scripts/ai-loop/test_delivery.py` 等）+ 既存 CLI / schema / fixture が壊れていない |
| **AC-20** | 既存テストが維持され、新規テストが追加されている | 全 Phase | 既存テスト全 PASS + 新規テストの追加（issue「必須テスト」10 項目を test-cases に展開） |
| **AC-P1**（起案） | Phase 0〜2 の境界が成果物上で明確に区切られている | Phase 0 | Phase 3 以降に属する実装（policy 強制 / GitHub adapter / hash chain / 署名検証）が diff に 1 件も含まれないことを確認。切り出し推奨 Issue が handoff に列挙されている |
| **AC-P2**（起案） | **#981 との重複・衝突が発生していない** | Phase 0 | (a) ADR / schema に `plan_hash` / `plan_package_hash` / `artifact_hashes` の**算出規則・検証規則の再定義がない**ことを確認。Plan 側は `plan_ref` / `approval_ref` として参照のみであることが ADR に明記されている。**(b) 既存 schema プロパティの語彙が #981 と衝突しないこと** — 具体的には `run-event.schema.json` の `agent` / `by` / `plan_hash` に本 PBI が独自語彙を割り当てておらず、所有権が #981 PR1 の ADR へ送られていることを責務境界表で確認できる（`run-event.schema.json:77` は `additionalProperties: false` で 1 フィールド 2 語彙の回避手段が無いため、**算出規則だけでなく物理フィールドの所有権も検査対象に含める**） |
| **AC-P3**（起案） | 新規 schema 追加の必要性と格納先が説明されている | Phase 0 | ADR に格納先候補の比較（既存 schema の additive 拡張 / `^_` 注釈キー / 新規 sidecar schema / 既存未使用プロパティの活用）が残り、**HO 接触の有無**と **CI 強制の有無**が判断軸として明示されている（裏取り A-3 / A-5 / A-16） |
| **AC-P4**（起案） | 主体識別子のプライバシー方針が決定されている | Phase 1 | ADR に「Principal に人名・メールアドレス等の identifiable info を載せるか」の判断が記録され、`docs/ai/metrics-privacy.md` §4「プロジェクト固有名・社名・人名 → 完全除外」との整合が説明されている（→ U-5） |

---

## Notes from Refinement

### 設計上の非対称: 「何が起きたか」は厳密 / 「誰がしたか」は空白

裏取りから見える構造は次のとおり。**PlanGate の既存 record は content-addressed（hash 中心）であり、subject-addressed（主体中心）ではない**。

| 軸 | 現状 | 記録層 |
|---|---|---|
| 何を（What） | `plan_hash` / `plan_package_hash` / `artifact_hashes` / `source_sha` / `head_sha` | 厳密（受理器で全数再検証） |
| どう判断したか（How） | `decision` / `verdict` / `policy_ref` / `boundary_check` / `lite_check` / `reasons` | 厳密（決定論エンジン） |
| いつ（When） | `ts` / `issued_at` / `timestamp`（注入可能・決定論） | 厳密 |
| **誰が（Who）** | ツール種別文字列（`agent=codex`）/ エンジン定数（`issued_by="arbiter-v0.1"`）/ git-config 由来の未検証 identity（`approved_by`） | **ほぼ空白** |

この非対称は偶然ではなく、既存設計が **「AI の自己申告を信用しない」（I-3）を「主体を信用する代わりに内容を hash で固定する」方向で解いた** 結果である。#980 は逆方向、すなわち**主体そのものを表現可能にする**アプローチであり、**既存の hash 束縛を置き換えるものではなく直交して追加する**。この直交性を ADR の冒頭に置くことを plan の完了条件に含める。

### 格納先の候補比較（S-6 / S-7 / AC-P3 の起案根拠 — plan / ADR で確定）

issue の推奨最小構成は `.plangate/runs/<run_id>/{state.json, actors.json, audit.ndjson}` だが、同時に「**既存の保存場所・命名・schema がある場合はそれに合わせてください**」と指示している。実測に基づく候補は以下。

| 候補 | HO 接触 | CI schema 強制 | EH-8 strict 走査 | 追跡（git） | 評価 |
|---|---|---|---|---|---|
| ① `run.ndjson` の既存未使用プロパティ（`agent` / `by` / `plan_hash`）を使う | **なし** | **なし**（A-5） | **対象**（`.ndjson`） | あり | **最小差分**。ただし `by` は 1 個の文字列であり Principal / ActorSession / Role の 3 概念を表現できない。`schema_version` も無い（`run-event.schema.json` の `required` は 4 キーのみ）→ **Phase 1 の受け皿としては不足** |
| ② `run-event.schema.json` を additive 拡張（新キー + `^_` patternProperties 追加） | **あり**（`schemas/*.schema.json` は HO 対象） | なし（A-5） | **対象**（`.ndjson`） | あり | schema を直せば表現力は足りるが、**HO patch 運用（AI は patch 提示まで・適用は Human-owned）**になる。かつ CI 強制が無いままなので「schema に書いたが検証されない」状態が残る |
| ③ 新規 sidecar schema + `docs/working/TASK-XXXX/audit/*.json` | **あり**（新規 `schemas/*.schema.json` 作成も HO 対象） | **あり**（`*.json` は `validate-schemas.py` の rglob と `schema_mapping.py` 登録で検証可能） | **対象**（`.json`） | あり | 新規 schema の追加は HO だが、**CI 強制を得られる唯一の経路**。`.ndjson` を選ぶと A-5 のとおり CI から外れる |
| ④ `delivery/record.jsonl` へ actor 系 entry を additive 追加 | なし（`scripts/ai-loop/**` は HO 外だが **rollout-policy §2 carve-out で escalate 固定**） | なし | **対象外**（`.jsonl`） | あり | 既存の append-only + `entry_id` 冪等機構（`delivery.py:476-487`）と `RecordError` fail-closed（`:450-470`）を**そのまま再利用できる**。ただし ai-loop Delivery 経路に閉じ、ai-dev 経路（`run.ndjson`）を覆わない |
| ⑤ metrics `events.ndjson`（`plangate-event.schema.json`） | あり | なし（設計上 `plangate metrics --validate` で検査） | **対象**（`.ndjson`）だが gitignore で PR に載らない | **なし**（`.gitignore:56`） | `schema_version` 必須 + `parent_event_id`（causation）の**設計先例**として参照価値が高いが、**追跡対象外**かつ `by` に人名不可の privacy 制約があるため監査正本にはできない |

**起案の骨子**（ADR で確定）: ai-dev 経路と ai-loop 経路の**両方を覆う単一の格納先は現状存在しない**。したがって (a) 単一の Audit Event 形式を定義したうえで (b) 書き込み口を経路ごとに 2 つ（`run.ndjson` 系 / `record.jsonl` 系）持たせるか、(c) 新規 sidecar に一本化するか、の 2 択になる。**「1 つの正本 + 複数 writer」を第一候補**とし、コピーを 2 箇所に持たない設計を要求する。

### Mode 判定案（plan で確定）

| 制約 | 適用 |
|---|---|
| **Hardening Override** | `schemas/*.schema.json`（新規追加・既存拡張とも）に触れる場合、および `bin/plangate` に触れる場合は HO 対象 → **`lite_eligible=false` 強制 + Standard・同期 C-3 固定**（[`mode-classification.md`](../../../.claude/rules/mode-classification.md)「承認境界周辺の変更 → 最低でも高」）。AI は **patch 提示まで・適用は Human-owned**（EH-3 は maintenance 窓内でも常時 block） |
| **rollout-policy §2 判定基盤 carve-out** | `scripts/ai-loop/**`（① 強制エンジンコード）/ `docs/workflows/ai-loop/**` **および `docs/ai/ai-loop/**`**（② ai-loop policy／spec 文書 corpus **全体**。`rollout-policy.md:54` 参照。**本 PBI の ADR は `design-philosophy.md` / `hotl-merge-entry-criteria.md` を参照するため追記が発生しうる**）に触れる場合、[`rollout-policy.md`](../../workflows/ai-loop/rollout-policy.md) §2 の判定基盤 carve-out に該当し **escalate 固定**。**これは規範層**であり、`arbiter.py` の `boundary_check` は `ho-paths.md` の HO 表からのみ touches-HO を導出するため当該パスは **`boundary=clean` と機械判定される** → **実行者が escalate する責務を負う**（同 §2 の「規範層である旨の明示」）。**③ ai-loop 実行手順スキル（`.agents/skills/ai-loop-cycle/**` / `.claude/skills/ai-loop-cycle/**`・`rollout-policy.md:55`）は本 PBI では触れない**（触れる必要が生じたら scope 再確認） |

- 定量（Phase 0〜2 全体想定）: ADR 1〜3 + schema 1〜3 + 実装 2〜4 + テスト 2〜4 + working context 6〜7 + 契約文書追記 1〜2 → **13〜23 ファイル** → **high-risk〜critical 帯**。AC は 24 個（AC-1〜20 + AC-P1〜4）→ **critical 帯**（11+）
- 定性: 承認境界（誰が承認したかの表現）に直接触れる新規設計であり、**リスクは「高」以上**
- **安全側の初期値: `critical`**（HO 接触 + 承認境界の主体モデル新設 + AC 24 個）。`doc-light` は適用しない
- **PR 分割の推奨**（issue 指示 verbatim）: ① 棚卸し + ADR + schema / ② audit writer / reader + validation / ③ C-3' / Delivery 状態遷移との統合 / ④ tests / docs / examples。1 PR にまとめる場合も commit を同じ境界で分割する。**Phase 0（ADR のみ）を先行 PR にすれば doc 中心の high-risk に落とせる**可能性があり、分割単位は U-3 で確定する

### 最小 Audit Event 必須項目 21 個（issue コメント verbatim・S-7 の入力）

issue #980 の 2026-08-04 実行指示コメント §「最小Audit Event必須項目」verbatim。**Phase 1 の schema はこの 21 フィールドを満たすこと**（本 pbi-input が独自に減らさない）。

1. `event_id`
2. `schema_version`
3. `event_type`
4. `occurred_at`
5. `recorded_at`
6. `run_id`
7. `aggregate.type`
8. `aggregate.id`
9. `aggregate.version`
10. `actor.actor_session_id`
11. `actor.principal_id`
12. `actor.role`
13. `action`
14. `decision.result`
15. `decision.policy_ref`
16. `decision.reasons`
17. `evidence_refs`
18. `correlation_id`
19. `causation_id`
20. `idempotency_key`
21. `source.system`

同コメント verbatim の除外指示: 「`integrity.previous_record_digest` と署名は今回必須にせず、schema 上 **nullable または将来拡張可能**にしてください」（→ AC-11 / AC-13 / AC-17 と整合）。

> **設計上の注記（plan で扱う論点）**:
>
> - **`occurred_at` と `recorded_at` の二重タイムスタンプ**は「事象の発生時刻」と「監査への記録時刻」を分離するもので、**AC-16（audit 保存失敗時に重要状態遷移を成功扱いしない）と `Current State = 正本` の一貫性設計に直結する**。既存 record の timestamp は単一（`delivery.py` の `--now` 注入 / `arbiter.py` の `timestamp` 注入）であり、**決定論（timestamp 注入）の慣行を 2 フィールドに拡張できるか**を Phase 1 で検証する
> - `run_id` の定義は **U-7**（既存 `task_id` を再利用するか新規採番するか）、`aggregate.version` の供給元は **U-8** に未確定として残る
> - `event_type` は A-4 のとおり既存 `run-event.schema.json:25-46` の `event` enum と**語彙が重ならない**。既存 enum を拡張するか別語彙空間にするかは U-2 の格納先決定に従属する

### issue「完了時の報告形式」8 項目（handoff / PR 本文の必須要素）

同コメント §「完了時の報告形式」verbatim。**handoff.md（Rule 5 必須 6 要素）に加えて以下 8 点を PR 本文または handoff に含める**ことを plan の完了条件とする。

1. 棚卸し結果と確認した正本
2. 採用した設計と代替案を退けた理由
3. 変更ファイル一覧
4. 後方互換性への影響
5. security / privacy 上の判断
6. 実行したテストと結果
7. 未対応 Phase と切り出し推奨 Issue
8. 受け入れ条件の対応表

> 4.（後方互換性）は AC-19 / AC-20、5.（security / privacy）は **AC-P4 と U-5**、7.（未対応 Phase）は **AC-P1 と「実装対象 — 明示列挙」表**、8.（AC 対応表）は AC-1〜AC-20 + AC-P1〜P4 に対応する。**最終的な merge 判断は Human C-4 に残す**（issue コメント verbatim）。

### issue「必須テスト」10 項目（test-cases への展開元・plan で確定）

issue 指示コメント verbatim。本 PBI の test-cases はこれを起点に作る。

1. 同一 `idempotency_key` の重複記録を拒否または安全に無視する
2. 未知 `schema_version` を成功扱いしない
3. 未知 role / principal / policy を fail-closed で扱う
4. Executor が自分の実行結果を最終承認できない
5. AI Actor が `MERGED` を要求しても拒否される
6. requester と decision maker が別々に記録される
7. evidence なしの重要遷移を成功扱いしない
8. audit 保存失敗時に重要状態遷移だけが進まない
9. 既存 Delivery 判定結果が変わらない回帰テスト
10. 既存 CLI・schema・fixture が壊れていない

> **4. と 5. の帰属注記**: この 2 件は **Phase 3（policy 実装）の受入テスト**であり、Phase 0〜2 では「比較に必要なフィールドが揃っていること」までしか検証できない。plan で Phase 帰属を明示し、Phase 0〜2 の完了条件から外すか、フィールド充足の形に読み替えるかを確定する（→ U-4）。

---

## Estimation Evidence

### Risks

| Risk | 影響 | 一次緩和 |
|---|---|---|
| **`Current State = 正本` と `Audit Event = append-only 記録` の一貫性が破れる** — 完全 Event Sourcing を採らないため、状態と監査記録が食い違ったときの優先順位が未定義になる | 「audit には遷移が記録されているが state はそこに無い」「state は遷移済みだが audit に記録が無い」の 2 方向の乖離が生まれ、監査記録が信頼できなくなる。とくに後者は AC-16（保存失敗時に成功扱いしない）の裏返し | ADR で **(a) 状態と audit の不一致時は常に state を正とする、(b) ただし audit 書き込み失敗時は重要状態遷移をコミットしない**（fail-closed）の 2 点を明記し、Phase 2 で「audit 保存失敗 → 状態遷移が進まない」test（issue 必須テスト 8）を先に書く。既存前例: `delivery.py:450-470` の `RecordError`（record 破損・`entry_id` 改竄は握り潰さず送出） |
| **#981 未完了のまま #980 を先行させた場合の手戻り** — Audit Event の `plan_ref` / `approval_ref` が指す先を #981 が変更すると、#980 の schema と実装が追従改版になる | Phase 1 の schema 定義とサンプル record が丸ごと作り直しになり、**HO patch（`schemas/`）の Human 適用が 2 回発生する** | (1) issue の推奨順序どおり **#981 PR1〜PR3 完了後に着手**する（本 pbi-input の整備のみ先行してよい、が実装は待つ）。(2) やむを得ず先行する場合、`plan_ref` / `approval_ref` を **opaque string の 1 フィールド**として定義し、内部構造を #980 側で解釈しない（構造を持たせない = #981 の変更に影響されない）。(3) `plan_ref` の**構造化は #981 PR4（監査統合）に明示的に後置**する |
| **identity が暗号的に未検証のまま職務分離 policy を機械化することの限界** — `approved_by` は git-config 由来（A-7）、`issued_by` は自己申告（A-11・A-21）。この上に「Executor ≠ Reviewer」を機械判定しても、**主体を詐称すれば通る** | 「職務分離が機械強制されている」という**誤った安心**を生む。既存文書が honest に限界を明記している（A-21）のに対し、新機構が限界を隠すと退行になる | (1) ADR に「**Phase 0〜2 の主体識別子は非検証の自己申告であり、真正性は Phase 6（署名）まで保証されない**」を明記し、schema の description にも同旨を残す（既存前例: `bin/plangate:2412` の `_note` / `_approver_identity_unverified: true`）。(2) 独立性レベル（Level 0〜4）を「**検証済みの独立性**」ではなく「**申告された独立性**」として定義する。(3) `docs/ai/ai-loop/hotl-merge-entry-criteria.md:44-48` 条件 1 を ADR から参照し、「本 PBI は条件 1 を充足しない」ことを明示する |
| **既存 record 形式に新フィールドを足す = 後方互換の破壊** | 既存の 3 件の `run.ndjson` / 19 件の `decision-log.jsonl` / 既存 c3-prime record が invalid になる | すべて **additive・optional** で追加し、`required` に加えない。既存 fixture の回帰テスト（issue 必須テスト 10）を先に固定する。新規 `required` を作るのは**新規 schema 側だけ**にする |
| **`schemas/` が HO 対象のため AI が直接変更できない** | Phase 1 が「patch 提示のみ」で停滞し、Phase 2 に進めない | Phase 0 の ADR 段階で **HO 接触の有無を格納先選択の評価軸に含める**（上記候補比較表に列挙済み）。HO 接触が不可避なら適用順序と Human タスクを Phase 0 の handoff に **BLOCKED**（blocker / owner / unblock_condition）として先出しする。前例: `docs/working/TASK-0871/approvals/ho-apply-approval.md` / `docs/working/TASK-0872/patches/` |
| **監査ログにプライバシー上載せられない情報を載せる** — issue の Principal モデルは `display_name` / `external_subject` / `provider` を持つが、`docs/ai/metrics-privacy.md` §4 は「プロジェクト固有名・社名・人名 → **完全除外**」と規定 | **リスクは一方向**（実測で確定）: EH-8 の検出は**固定キー名 14 個の完全一致**（`scripts/hooks/check-metrics-privacy.sh:37` の `FORBIDDEN_KEYS` = `file_path` / `file_paths` / `stack_trace` / `stacktrace` / `command_output` / `stdout` / `stderr` / `raw_response` / `raw_request` / `api_key` / `user_prompt` / `system_prompt` / `prompt_text` / `absolute_path`）を `grep -E "($FORBIDDEN_KEYS)[[:space:]]*:"` で拾うだけ（`:96`）。**`display_name` / `external_subject` / メールアドレスは 1 つも検出しない**。したがって「EH-8 が誤発火する」のではなく「**無検出のまま identifiable info が commit される**」側にしか倒れない | Phase 1 の ADR で **(a) Audit Event を metrics events と別の privacy レジームに置く**（監査は追跡目的で pseudonymous ID を使う）か **(b) metrics-privacy を正本として identifiable info を排除する**かを決定する。**現状の `approvals/c3.json` は git-config メールを commit している**（A-7 実物）ため、既に非対称が存在する事実を ADR に記録する（→ U-5） |
| **`decision-log.jsonl` の定義と実運用の乖離を放置したまま新 audit を足す** | 「actor を記録する場所」が 3 系統（decision-log / run.ndjson / record.jsonl）に分散し、どれが正本か不明になる。乖離（A-13: `chosen_by` 定義に対し実運用は `by`）が新機構にも伝播する | Phase 0 の棚卸しで **既存 3 系統の役割分界を確定**し、ADR で「actor 情報の正本はどこか」を単一に決める。`decision-log.jsonl` の定義乖離そのものの是正は**本 PBI の scope 外**とし、発見事項として別 Issue 候補に挙げる |
| 裏取り表の行番号が PR 進行中に stale 化する | 「対象 / 対象外」の判定が反転する | 行番号だけでなく**関数名・記号アンカー**を併記済み（`plangate_append_ndjson` / `_plangate_presence_gate` / `ISSUED_BY` / `derive_loopspec()` / `RECORD_REQUIRED_KEYS` 等）。plan では exec 直前に現 main 基点で再走査する |

### Unknowns

- **U-1**: **ADR の分割数と配置・採番**。issue の成果物は Actor model ADR / Audit Event model ADR / Event Sourcing 採否 ADR の **3 本**を挙げるが、既存慣行は `docs/decisions/` に **`adr-001-approve-out-of-band.md` の 1 件のみ**（`docs/adr/` は存在しない。`docs/rfc/` は RFC で別系統）。3 本に分けるか 1 本にまとめるか、採番（`adr-002` 〜 `adr-004`）と slug を plan で確定する。**#981 も同じ `docs/decisions/` へ ADR を置く予定**のため、採番衝突の回避を #981 の進行と突き合わせる必要がある
- **U-2**: **Audit Event の物理的な格納先**（上記候補比較表の ①〜⑤）。判断軸は (a) HO 接触の有無、(b) CI 強制の有無（`.json` か `.ndjson` かで `validate-schemas.py` の rglob 対象が変わる — A-5）、(c) ai-dev / ai-loop の両経路を覆えるか、(d) git 追跡対象か（A-14 / A-16 は非追跡）、(e) 既存の冪等 append 機構（`delivery.py` の `entry_id`）を再利用できるか、**(f) EH-8 strict（CI）の走査対象に入るか** — `.github/workflows/metrics-privacy.yml` は PR の `**/*.json` / `**/*.ndjson` を対象とし（`on.pull_request.paths` および収集段の `grep -E '\.(json|ndjson)$'`）、**`.jsonl` は対象外**（`docs/workflows/ai-loop/delivery-state-machine.md:92` が「`.jsonl` は EH-8 走査対象外」と明記）。プライバシー方針（U-5）と組み合わせると「機械検査が届く場所に置くか」自体が設計判断になる
- **U-3**: **PR 分割単位と Phase 0 の先行可否**。Phase 0（ADR のみ）を単独 PR にすれば HO 非接触の doc PR に落とせるが、schema を伴わない ADR だけでは「格納先が決まった」と言えるかの判断が要る。issue 推奨の 4 分割をそのまま採るか、Phase 0 / Phase 1+2 の 2 分割にするか
- **U-4**: **issue 必須テスト 4.（Executor の自己承認拒否）・5.（AI の `MERGED` 拒否）の Phase 帰属**。これらは policy 実装（Phase 3）の受入テストであり、Phase 0〜2 では成立しない。Phase 0〜2 の完了条件から外すか、「比較に必要なフィールドが揃っている」形に読み替えるか
- **U-5**: **Principal の identifiable info 方針**。`display_name` / `external_subject` に人名・メール・GitHub ログインを載せるか。既存は**非対称**（`approvals/c3.json` は git-config メールを commit / `plangate-event.schema.json` の `by` は「人名・社名は不可」）。pseudonymous ID（hash）+ 別管理の対応表という選択肢も含めて確定する
- **U-6**: **`ActorSession` の生成主体と生成タイミング**。誰が `actor_session_id` を採番するか（CLI / hook / 各エージェント自身）。自己採番なら詐称可能であり、Level 1（別 subagent だが同一親 session）と Level 2（別 session）を機械的に区別できない可能性がある。`parent_session_id` の取得経路も未確定
- **U-7**: **`run_id` の定義**。issue の Audit Event 案は `run_id` を持つが、PlanGate の既存識別子は `task_id`（`^TASK-[0-9]{4}$`）であり、ai-loop 側には別途 `run.run_id`（`arbiter.py` の additive `run` フィールド / `metrics.py` の集計単位）が存在する。**新規採番するか既存を再利用するか**（#981 の `plan_id` = `task_id` 再利用の結論と整合させる）
- **U-8**: **`aggregate.version` の意味と供給元**。issue の Audit Event 案は `aggregate: {type, id, version}` を持つが、PlanGate に集約バージョンの概念は現存しない（`delivery.py` の `round` が近縁）。単調増加の版番号を新設するか、既存の `round` / `head_sha` で代替するか
- **U-9**: **`EXEC_RETURN` / `HUMAN_ESCALATED` の監査イベント化の実装点**。両者は `delivery.py` の状態遷移結果であり、record への書き込みは既に `state` entry で行われている（`delivery.py:407`）。**新 entry を足すのか、既存 `state` entry に actor を additive 付与するのか**（後者なら `entry_id` の算出対象が変わり、既存 record との冪等性に影響しうる — `delivery.py:180-181` は `at` / `entry_id` を除いた全キーで id を計算するため、**フィールド追加は entry_id を変える**）

### Assumptions

- issue 本文の「採用方針」と 2026-08-04 のコメント群が **Human 確定の実行方針**であり、コメント（Phase 0〜2 を 1 実装単位 / 実装順は #981 PR1〜PR3 の後）が本文の Phase 一覧より優先されること
- 上記裏取り表の実測が現 main（`7de7baa`）で有効であること（exec 時に再走査して確定する）
- **#981 が本 PBI の着手時点で PR1〜PR3 まで完了している**か、少なくとも PR1（ADR / 正本整理）が確定していること。未完了で先行する場合は Risk 表の緩和（`plan_ref` を opaque string に留める）を適用する
- `NO MERGE BY AI` / Human C-4 のみが `MERGED` へ到達、は本 PBI のいかなる成果物によっても変更されない
- Plan Package 6 要素の定義（`scripts/ai-loop/c3_contract.py:26-33`）および `plan_hash` / `plan_package_hash` の算出規則は本 PBI で変更しない（#981 の領域）
- 自己承認ガードの**機械層実装**は #928 の scope であり、本 PBI は policy 層の**宣言語彙**までを担う（重複しない）
- 既存の `docs/working/_audit/hook-events.log` が gitignore 対象である現状（A-14）は本 PBI で変更しない（追跡対象化はプライバシー判断を伴うため U-5 の決定後に別途判断する）

---

## スコープ外の発見（本 PBI では扱わず、別 Issue 候補として報告）

裏取り中に検出したが #980 Phase 0〜2 の scope 外である事項。**本 PBI では是正しない**。

| # | 発見 | 根拠 | 提案 |
|---|---|---|---|
| F-1 | `decision-log.jsonl` の**テンプレート定義と実運用の乖離** | 定義は `chosen_by` 必須 + 7 キー（`docs/working/templates/decision-log-schema.md:13-23`）。実測 `docs/working/TASK-0917/decision-log.jsonl` は `chosen_by` 0 件 / `by` 36 件、`task` / `type` / `reason` / `alternatives` も欠落。`schemas/` に対応 schema なし・`schema_mapping.py` にも未登録 = **機械検証が存在しないため乖離が検出されていない** | 別 Issue: decision-log の schema 化と定義／実運用の整合（#960 と同型の「宣言と実体の乖離」） |
| F-2 | `run.ndjson` が**ほぼ未計装** | `git ls-files 'docs/working/*/run.ndjson'` → **3 件のみ**（TASK-0106 / TASK-0872 / TASK-0896）。`plangate_append_ndjson` の呼び出しは 3 箇所のみで、`exec_started` / `pr_created` / `approved` 等の enum 値を書く writer が存在しない | 別 Issue: `run.ndjson` の計装範囲（enum 20 値に対し writer 2 値）の是正要否判断。#980 Phase 2 の前提に影響しうる |
| F-3 | `run.ndjson` が **CI schema 検証の対象外** | `schema_mapping.py:36` の basename は `run-event.json`、`validate-schemas.py:80` は `rglob("*.json")` → 拡張子 `.ndjson` は両方に掛からない | 別 Issue: NDJSON 系（`run.ndjson` / `record.jsonl` / `decision-log.jsonl`）の CI 検証経路の新設要否 |
| F-4 | `bin/plangate:2005` の `parallel_review` エントリが **`decision-log.jsonl` 宛なのに `run-event` 形式に近い** | 書き込み先は `$_rp_work_dir/decision-log.jsonl` だが、キーは `ts` / `event` / `phase` / `reviewers` / `task_mode` で decision-log スキーマ（`ts` / `phase` / `task` / `type` / `decision` / `reason` / `alternatives` / `chosen_by`）と一致しない | F-1 と同じ Issue に統合可 |
