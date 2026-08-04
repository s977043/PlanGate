# EXECUTION PLAN — TASK-0981（#981 PR1）

> Issue: [#981](https://github.com/s977043/plangate/issues/981)「Plan Contract を定義し、Planner と Executor の分離実行を安全にする」
> 入力: [`pbi-input.md`](./pbi-input.md)（main マージ済み確定版・本 plan では**改変しない**）
> 基点: main **`73e6a15`**（2026-08-05 再実測 / C-2 R-101 反映。旧基点 `7de7baa` から 4 commit 進行し #989 = TASK-0874 RunEvidence 契約が入った）
> **基点更新に伴う行番号ドリフトの実測結果**（R-101。「コードファイルの行番号は不変」という旧記述はこの表で置き換える）:
> `bin/plangate` / `schemas/**` / `scripts/ai-loop/c3_contract.py` / `c3prime_verify.py` / `plan_package.py` は**無変更**で本 plan が引用する行番号はそのまま有効。
> 一方 `docs/workflows/ai-loop/c3-prime-contract.md` は **+41 行**で §8 が **L135-137 → §8 見出し L176 / 追記対象文 L178** へ移動、`scripts/ai-loop/test_*.py` は **13 → 15 本**、`tests/extras/*.sh` は **57 本**、`sh tests/run-tests.sh` の baseline は **514 → 524 passed / 0 failed** へ変化した（いずれも本反映時に実測）。`scripts/sync-plugin-plangate.sh` / `tests/extras/ta-58` / `ta-59` も変更されている。
> スコープ: issue コメント（2026-08-04 / Human 確定の実行方針）§4「PR 1: 棚卸し・ADR・契約差分」**のみ**。PR2〜PR4 は Out of Scope
> 成果物の性質: **文書のみ**（コードを 1 行も変更しない）

## Goal

既存の Plan Package / c3-prime 契約を **Plan Contract の唯一の正本**として棚卸し・整理し、Planner と Executor が異なる場合に不足する差分（実行主体・実行参照・revision / resume）の**実装先と機構を ADR で確定**する。PR2 以降が「どこに何を足すか」を迷わず着手できる状態にすることが PR1 の完了地点であり、**PR1 自身は実装を含まない**。

## Constraints / Non-goals

### Constraints（Human 確定 / 逸脱不可）

1. **新しい Plan Contract 基盤をゼロから作らない**。既存の Plan Package（[`c3_contract.py`](../../../scripts/ai-loop/c3_contract.py) `ARTIFACTS` = 6 要素）/ c3-prime 契約を正本として拡張する
2. **二重正本を作らない**。`plan_version` は実行許可の判定要素にしない。実行同一性の正本は `plan_hash` / `plan_package_hash`
3. **#980（Principal / ActorSession）を先取りしない**。参照用 ID は opaque string の定義まで
4. **実行許可の正本は exec preflight の strict verifier**（[`c3prime_verify.py`](../../../scripts/ai-loop/c3prime_verify.py) / `bin/plangate` preflight）。[`check-plan-hash.sh`](../../../scripts/hooks/check-plan-hash.sh) は**補助防衛**のまま。責務を集中させない
5. **`NO MERGE BY AI` / Human C-4 のみが `MERGED` へ到達**、は本 PBI のいかなる成果物でも変更しない
6. **`pbi-input.md` を改変しない**（main マージ済みの確定版。是正が必要な記述は ADR 側の付表で上書き記録する）
7. **Hardening Override（HO）対象パスに触れない**。PR1 の変更対象に `schemas/*.schema.json` / `bin/plangate` / `scripts/hooks/*.sh` / `.claude/**` / `.github/workflows/**` / `CLAUDE.md` / `AGENTS.md` は**含まない**
8. **`docs/workflows/ai-loop/**` は rollout-policy §2 判定基盤 carve-out**（[`rollout-policy.md`](../../workflows/ai-loop/rollout-policy.md) §2「判定基盤 carve-out（自己改変防止・glob）」②）。Step 8 で `c3-prime-contract.md` を編集するため本 run は **escalate 固定 = 同期 Human C-3**。これは規範層であり `arbiter.py` の `boundary_check` は `boundary=clean` と機械判定する（実行者が escalate する責務を負う）

### Non-goals

- 実装（exec preflight 拡張 / execution record 追加 / revision / resume）→ **PR2・PR3**
- `#980` の Principal / ActorSession / Delegation / 署名の実装 → **#980**
- 既存 Markdown artifact の廃止・破壊的 migration・新規外部依存の追加
- `PR_CREATED` / `MERGE_READY` / `MERGED` の責務境界の変更
- Plan Package 6 要素の集合そのものの変更（sidecar を足しても 6 要素は不変）

## Approach Overview

PR1 は「**決めること**」の集合であり、成果物は ADR 1 本と working context artifact に集約する。実装先が定まらないまま PR2 に進むと `approvals/c3.json` と sidecar の両方に情報が散る（＝二重正本の実害化）ため、以下 10 個の決定を**すべて PR1 で確定**する。

### 決定事項 D-1〜D-10（本 plan で確定し、ADR が記録媒体になる）

> 各決定は「PR1 で確定」する。ADR はその**記録**であり、ADR 作成時に再検討して結論を変えない（変える必要が生じた場合は Replan Trigger RT-2 に従い plan を差分改訂し C-1 を再実行する）。

| # | 論点 | 選択肢 | **決定** | 根拠（main `73e6a15` 実測 / C-2 反映時に再確認） |
|---|------|--------|---------|---------------------------|
| **D-1** | Plan Contract の**契約正本の配置** | ① `c3-prime-contract.md` 拡張 / ② `approvals/c3.json` 拡張 / ③ 新規契約ファイル | **①（単一正本）** | [`c3-prime-contract.md`](../../workflows/ai-loop/c3-prime-contract.md) が既に §1 Plan Package 定義（L8-33）/ §2 フィールド定義（L34-56）/ §4 stale・受理規則（L71-96）/ §7 delivery 引き渡し（L129-133）を保持し、Plan Contract の実体そのもの。③ は「Plan Contract という新ファイルを作る」誤読を招く並行正本 |
| **D-2** | `plan_version` / `plan_revision` | ① 必須化 / ② 任意導入 / ③ **導入しない** | **③ 導入しない**。実行同一性の正本は `plan_hash`（`plan.md` 単体）+ `plan_package_hash`（6 要素の正規化集合）。将来導入する場合の**唯一の許容形式**は `^_plan_revision`（string・注釈キー）で、判定分岐に使わないことを ADR で規定。**あわせて `plan_id` を新規採番しない**（`task_id` を再利用する。pbi-input の結論を決定として確定 — C-2 R-009） | `grep -rn "plan_version\|plan_revision" scripts/ schemas/ bin/` = **0 件**（実測）。番号は「同じ番号のまま中身を変える」ことができ hash より弱く、判定に使うと**弱い方が正本**になる。任意キーですら素の `plan_revision` は受理器が reject する（`c3prime_verify.py:73` の未知キー検査。`^_` のみ除外） |
| **D-3** | execution reference の**物理的な置き場** | ① `approvals/c3.json` へ additive / ② sidecar `docs/working/TASK-XXXX/execution/plan-contract.json` / ③ `run.ndjson` の additive イベント | **②（sidecar）を主・③を補助**。①は採らない | ① を採らない理由は HO コストではなく**設計上の帰属**: `approvals/c3.json` は承認時点の不変スナップショットで、`bin/plangate:2380-2383` が `--force` なしの上書きを block する。**1 承認 : N 実行**（resume / retry / executor 切替）を 1 ファイルでは表現できない。さらに `plangate approve` は c3.json を**固定キー集合で丸ごと再生成**するため（`bin/plangate:2400-2423` の Python heredoc が `task_id` / `phase` / `c3_status` / `approved_by` / `approved_at` / `plan_hash` / `source` / `_approved_by_source` / `_approver_identity_unverified` / `_note` のみを `json.dump`）、**`--force` 再承認で手書きの `_execution_ref` は消失する**（C-2 R-105）。③ は `run.ndjson` に **schema 検証**経路が無い（後述 D-4） |
| **D-4** | **新規 schema の要否**（AC-3） | (a) `^_` 注釈キー / (b) `run-event.schema.json` の既存未使用プロパティ / (c) sidecar + 新規 schema / **(d) 既存 `c3-prime.schema.json` へ型付き additive** / **(e) `docs/schemas/`（非 HO）配置 → 後日 `git mv` で昇格** | **(c) を採用**（PR2 で `schemas/plan-contract.schema.json` を新設 = **HO patch 提示 → Human 適用**）。(b) は PR2 の最小差分として**併用**（`plan_hash` / `agent` / `by` を `session_started` に刻む。HO 無変更）。(a) は D-2 の将来拡張枠としてのみ残す。**(d) / (e) は不採用**（C-2 R-006 / R-102 で追加した比較経路。理由は下表） | **enforcement の非対称が決め手**: `.github/workflows/schema-validate.yml` の `on.pull_request.paths`（L5-7）は `docs/working/**/*.json` と `schemas/**/*.json` を**含む** → sidecar は CI 検証経路に載せられる。**ただし enforcement の実体は 1 点しかない**（C-2 R-103）: `validate-schemas.py:34-41` の `validate_one()` は `lookup_schema()` が `None` を返すと **`SKIP`** を返し、`:139-143` の exit code 判定は `ERROR` / `FAIL` しか見ないため、**`scripts/schema_mapping.py` への 1 行登録を忘れると CI は沈黙して PASS する**。この 1 行が唯一の強制点であることを ADR に明記し PR2 へ申し送る。一方 `run.ndjson` は拡張子が `.ndjson` で `validate-schemas.py:80` の `rglob("*.json")` にも `schema_mapping.py` にも掛からず **schema 検証経路が 0 本**（ただし `metrics-privacy.yml` の `**/*.ndjson` trigger には載る = 「一切の CI に触れない」ではない — C-2 R-109）。(a) は c3-prime 経路で string 型固定のため `plan_ref` / `approval_ref` の構造を表現できない |
| **D-5** | **#980 との責務境界** | ① 主体検証も #981 で実装 / ② opaque string に留める | **②**。ActorSession ID は**非検証の opaque string**（形式検査のみ）。真正性・職務分離 policy の正本は #980 | issue コメント §1 の責務分担（Human 確定）。#980 未実装期間に「検証済み主体」と誤読させないため、ADR と PR2 の record 説明文の**両方**に「非検証」を明記する |
| **D-6** | **legacy 経路（人間 C-3）の preflight 強度**（ギャップ #5 / S-8） | ① 明示的に非対象 / ② 全面的に c3-prime 相当へ強化 / ③ **fail-open の 1 点のみ塞ぐ** | **③**。PR2 で `bin/plangate:2092` の `if [ -n "$recorded_hash" ]` による**無言 skip を BLOCK 化**する patch を提示（`bin/plangate` = HO → **AI は patch 提示まで・適用は Human-owned**）。evidence marker 再検証・`artifact_hashes` 照合の legacy への全面移植は**行わない** | **塞ぐ対象の正確な記述（C-2 R-002 是正）**: `bin/plangate:2092` が塞ぐのは「**`plan_hash` が記録されて**いないから照合しない」fail-open である（記録が「ある」ケースは `:2098` で既に mismatch 判定されている）。旧記述「記録があるのに照合しない」は pbi-input `:39` の実測（「`plan_hash` が**無ければ**無言 skip」）と論理が逆だった。**③ が ② より後方互換に安全である根拠（実測）**: 追跡下の `docs/working/*/approvals/c3.json` は **80 件**あり、`plan_hash` を持たないのは **1 件のみ**（`TASK-0038`）。したがって ③ が invalid 化するのは 1/80 に限定される一方、② は evidence marker / `artifact_hashes` を持たない**ほぼ全件**を invalid 化する（AC-6 と #981 全体 AC「既存 artifact・CLI・record の後方互換」に反する）。**穴の大きさの正確な表現（C-2 R-106 是正）**: 旧記述「本番フロー大多数の穴」は過大。`plangate approve` は必ず `plan_hash` を書き（`bin/plangate:2408`）、`schemas/c3-approval.schema.json:7-13` は `plan_hash` を `required` に含み、`approvals/c3.json` は `docs/working/**/*.json` として schema-validate CI の対象である。実際の fail-open 窓は「**CLI 非経由で手書きされ、かつ schema 違反の c3.json**」に限定され、**多層防御の最後の 1 層が抜けている**状態と表現するのが正確。① はその 1 層の欠落を恒久化する。なお `bin/plangate:1024` の `validate` は同じ状況で `[WARN] plan_hash not found in c3.json` を出しており、**exec だけが無言**という非対称の是正でもある |
| **D-7** | **受理側 presence の意味範囲**（EC-1 / U-6） | ① 現状維持 + 明記 / ② 受理側にも非空検査を追加 | **② 補強（PR2）+ ADR に意味範囲を明記** | 受理側は `is_file()` + hash 全数一致（`c3prime_verify.py:131-139`）のみで、**0 byte artifact の hash を持つ record を手書きすれば受理される**（生成側 `plan_package.check_presence()` を通らない偽造経路）。補強先 `scripts/ai-loop/c3prime_verify.py` は **HO 対象外**でコストが小さく、fail-closed 原則と一貫する |
| **D-8** | `prohibited_actions` / `stop_conditions` の**宣言フィールド**（EC-10 / U-3） | ① 宣言する / ② **宣言しない（実装が正）** | **②**。record 側に `prohibited_actions` / `allowed_actions` を持たせない。ADR に「`NO MERGE BY AI` は実装層で強制され、record 側の宣言は行わない」と明記 | `gh_exec.py:29-46`（allowlist の**補集合**として merge を自動禁止・`graphql` を allowlist に載せない）+ `check_exec_boundary.py`（AST で実行系トークンを機械強制）で既に強制済み。宣言を足すと「宣言と実装のどちらが正か」という**新しい二重正本**が生まれ Constraint 2 に反する。`gh_exec.py:39-46` が自認する「別プロセスからの `gh pr merge` は塞げない」ギャップは**宣言を足しても閉じない**（規範層 + C-4 に残る） |
| **D-9** | **evidence stale 判定の束縛先**（U-8） | ① `plan.md` 単体を維持 / ② `plan_package_hash` へ拡張 | **① 維持**（②は**現行の marker 形式では原理的に不可能**であることを ADR に根拠付きで記録）。レビュー対象 3 要素（`plan.md` / `todo.md` / `test-cases.md`）の部分集合 hash による束縛は **PR3 の revision 契約の候補**として残す | **循環依存**: `ARTIFACTS`（`c3_contract.py:26-33`）は `review-self.md` / `review-external.md` を**含む**。`plan_package_hash` = `canonical_hash(artifact_hashes)` は 6 要素すべてに依存するため、C-1 marker（`review-self.md` の中身）に `plan_package_hash` を書き込むと自分自身の hash に依存する。したがって **marker 埋め込み方式（現行）では②は実装不能**であり、「拡張しない」は妥協ではなく**構造的帰結**。ただし *marker 以外の* 束縛（record 側フィールドでの束縛 / レビュー対象 3 要素の部分集合 hash）は循環しないため不可能ではなく、PR3 候補として残す |
| **D-10** | `c3-prime-contract.md` **§8 但し書き**（S-9） | ① 追記する / ② ADR にのみ書く | **① 追記する**（1 文追加。ファイル数 +1） | §8（基点 `73e6a15` 実測: **見出し L176 / 対象文 L178**。旧基点 `7de7baa` では L135-137 だった — C-2 R-101）「additive な任意フィールド追加は本ファイルの改版のみでよい」は `^_` 注釈キー以外では**実態と乖離**する: 素の record フィールド追加は `RECORD_OPTIONAL_KEYS`（`c3_contract.py:50-51`）と `schemas/c3-prime.schema.json`（HO 対象）の**同時更新が必須**で、契約だけ改版しても `c3prime_verify.py:73` が reject する。契約正本を D-1 で①に一本化する以上、正本自身の記述が誤っている状態を残せない |

> **pbi-input からの決定の進行（C-1 C1-B1B2-16 是正 / C-3 の確認対象）**: pbi-input の AC-4 は 「`plan_revision` は**任意**・監査表示用の連番」と**起案**していたが、本 plan の **D-2 でこれを 「PR1 では導入しない」へ確定**した（将来導入する場合の唯一の許容形式は `^_plan_revision`（string・注釈キー）で、受理器の判定分岐に使わない）。根拠は、受理器 `c3prime_verify.py:73` の未知キー検査により**素の `plan_revision` は任意キーであっても reject される**ため、pbi-input が想定した「任意フィールドとして足す」形は 現行契約では成立しないこと。**pbi-input は Constraint 6 により改変しない**ので、この差分は本注記で可視化する。

### D-4 の補足: 5 経路の比較（AC-3 の評価軸 / C-2 R-006・R-102 で 3 → 5 経路へ拡張）

| 経路 | HO 接触 | 構造表現力 | CI enforcement | 承認 record の不変性 | 判定 |
|------|--------|-----------|----------------|-------------------|------|
| (a) `approvals/c3.json` の `^_` 注釈キー | **なし**（`c3prime_verify.py:73` が `^_` を allowlist 検査から除外・`schemas/c3-prime.schema.json:113-118` の `patternProperties: {"^_": {"type":"string"}}` が例外） | **c3-prime 経路では string のみ**（`plan_ref` / `approval_ref` の入れ子を表現できない）。**legacy `schemas/c3-approval.schema.json:88-92` の `^_` には型制約が無い**が、legacy 側には構造検査器が存在せず（exec preflight は `bin/plangate:2070-2076` の grep のみ）**機械検証されないものは正本にできない**（C-2 R-104 で限定表現へ是正） | 既存 schema に載る | **壊す**（execution 情報を承認 record に混ぜる。さらに `plangate approve --force` の固定キー再生成で消失する — R-105） | D-2 の将来拡張枠としてのみ残す |
| (b) `run-event.schema.json` の既存未使用プロパティ | **なし**（`plan_hash` `:56-60` / `agent` `:48-51` / `by` `:52-55` が定義済み・`bin/plangate` の `plangate_append_ndjson` 3 箇所 `:1279` `:2005` `:2112` で未使用） | 平坦なキーのみ。`event` enum（`:23-46`）に `ExecutionStarted` 等が無く追加は HO 変更。`:77` が `additionalProperties: false` で `^_` の逃げ道も無い | **schema 検証経路は 0 本**（`.ndjson` は `validate-schemas.py:80` の `rglob("*.json")` にも `schema_mapping.py` にも掛からない）。ただし `metrics-privacy.yml:11-12` の `**/*.ndjson` trigger には載る（R-109） | 壊さない | **PR2 の最小差分として併用**（トレース用。契約の正本にはしない）。**語彙定義と writer 所有権は PR1 の ADR で確定する**（R-003 / #980 が待機中） |
| (c) sidecar `execution/plan-contract.json` + 新規 `schemas/plan-contract.schema.json` | **あり**（`schemas/*.schema.json` は HO = `check-plan-hash.sh:131`。`scripts/schema_mapping.py` は HO 対象外） | 入れ子構造を自由に表現 | **あり。ただし強制点は 1 つだけ**（`schema-validate.yml:5-7` の `docs/working/**/*.json` に載るが、`validate-schemas.py:34-41` は schema 未登録なら `SKIP` を返し `:139-143` は `SKIP` を失敗にしない = **`schema_mapping.py` の 1 行を忘れると沈黙 PASS** — R-103） | 壊さない（1 承認 : N 実行を表現できる） | **採用**。HO 接触は不可避なので PR1 handoff に Human 適用タスクを BLOCKED として先出しする |
| **(d) 既存 `schemas/c3-prime.schema.json` へ型付きプロパティを additive 追加**（`RECORD_OPTIONAL_KEYS`（`c3_contract.py:50-51`）と同時更新） | **あり**（`schemas/*.schema.json`） | 型付きなので (a) より強い。ただし追加先が **c3-prime record = 承認 record そのもの** | **あり**（既存の schema-validate 経路にそのまま載る。新規登録が不要な分 (c) より強い） | **壊す**（承認時点の不変スナップショットに実行時情報を混ぜる。`bin/plangate:2380-2383` の上書き block と **1 承認 : N 実行**が両立しない） | **不採用**。CI enforcement では (c) より優れるが、D-3 で棄却した「承認 record への追加」と同じ帰属の誤りになる。HO 接触量も (c) と同等（どちらも `schemas/` を 1 回触る） |
| **(e) `docs/schemas/plan-contract.schema.json`（非 HO）に置き、後日 `git mv` で `schemas/` へ昇格** | **PR2 時点では なし**（`docs/schemas/` は HO パターン外 = AI が直接作成できる）。**昇格時に あり** | (c) と同じ | **PR2 時点では 無い**（`schema-validate.yml` の trigger paths に `docs/schemas/**` が無く、`SCHEMAS_DIR` も `REPO_ROOT / "schemas"` 固定 = `scripts/_paths.py:23`）。昇格後に (c) と同じ | 壊さない | **不採用**。#874 が確立した実績ある段階案（`docs/working/TASK-0874/plan.md:26` / `:63` D1-A。`$id` を昇格後 URL で先に固定して昇格を `git mv` 1 手に収める）だが、**PR1 は実装を含まないため段階化の利得が無い**。かつ sidecar インスタンスを CI 検証させるには結局 `schemas/` 昇格が必要（TASK-0874 handoff **K-12** が既知課題として登録済み）で **HO 適用回数は減らず、schema 未検証期間だけが増える**。PR2 が「作って即検証」できる (c) を採る |

### 「二重正本を作らない」ことの具体的な担保（AC-2）

ADR に以下の**配置表**を置き、同一情報のコピーが 2 箇所以上に存在しないことを宣言する。

| 情報 | 唯一の正本 | 他の場所での扱い |
|------|-----------|-----------------|
| Plan Package 6 要素の定義 | `c3_contract.py` `ARTIFACTS` + `c3-prime-contract.md` §1 | 参照のみ |
| 実行同一性（Plan の版） | `approvals/c3.json` の `plan_hash` / `plan_package_hash` | sidecar は**書かず参照**（`approval_ref.path` で指す）。`run.ndjson` の `plan_hash`（D-4(b)）は**非正本のトレース複製**であり、不一致時は `approvals/c3.json` が勝つ。判定・受理のいずれにも使わない（C-2 R-007） |
| 承認の事実 | `approvals/c3.json`（`decision` / `source_sha` / reviewers） | sidecar は `approval_ref` で参照のみ |
| 実行主体・実行参照 | sidecar `execution/plan-contract.json` | `run.ndjson` は既存プロパティでトレースを刻むのみ（正本ではない） |
| `run-event.schema.json` の `agent` / `by` の**語彙と writer 所有権** | **本 PBI（#981 PR1）の ADR**（`docs/working/TASK-0980/pbi-input.md:181` / `:190` が #981 PR1 へ明示的に委ねている） | #980 は独自語彙を割り当てず本 ADR の定義に従う（C-2 R-003） |
| 変更可能範囲（`allowed_paths`） | `plan.md` の `## Files / Components to Touch` 節（`plan_package.extract_allowed_paths()` が単一実装） | Collector / LoopSpec は**再実装せず再利用** |
| merge 禁止 | 実装層（`gh_exec.py` allowlist 補集合 + `check_exec_boundary.py`） | record 側に宣言しない（D-8） |

## 受入基準（確定版）

> pbi-input の AC-1〜AC-6 を PR1 の完了条件として確定する（内容は不変。検証方法を機械判定可能な形に具体化した）。

| AC | 内容 | 機械判定の方法 |
|----|------|---------------|
| **AC-1** | 追加実装対象が「未対応差分」だけに限定されている | **(1) 表①（ギャップ 12 項目）**: 12 項目すべてに判定 + 根拠（file:line または関数名アンカー）が付き、**「既存で満たす」5 項目（#1・#2・#3・#4・#6）に PR2 以降の割当が 0 件**。**「一部満たす」3 項目（#5・#7・#11）は満たす側 / 満たさない側が分離記載**され、満たさない側が PR2 / PR3 に割り当てられている。**「未対応」3 項目（#8・#9・#10）の PR 割当が全件非空**（＝欠落の抑制 / C-2 R-010）。**(2) 表②（#981 全体 AC × PR1 で扱う範囲）**: **14 項目すべてが行として存在**し、各行の「PR1 で扱う範囲」列が非空である（C-2 R-001。TC-26 で検査） |
| **AC-2** | 正本が 1 つに決まっている | ADR に Plan Contract の正本が**単一パス**で明記され、上記「配置表」で「唯一の正本 / 参照のみ」が全行に付く。同一情報のコピーが 2 箇所以上に存在しないことを宣言し根拠を示す |
| **AC-3** | 新規 schema 追加の必要性が説明されている | ADR に**5 経路（(a) `^_` / (b) `run-event` 既存プロパティ / (c) sidecar + 新規 schema / (d) 既存 `c3-prime.schema.json` へ型付き additive / (e) `docs/schemas/` 配置 → 後日 `git mv` 昇格）すべての検討記録**があり、採用理由と不採用理由が HO 接触 / 構造表現力 / CI enforcement / 承認 record の不変性の 4 軸で比較されている（**5 × 4 = 20 セルすべて非空**）。加えて **(c) の CI enforcement が `scripts/schema_mapping.py` への 1 行登録に依存し、未登録なら `SKIP` で沈黙 PASS になる**ことが明記されている（C-2 R-006 / R-102 / R-103） |
| **AC-4** | `plan_version` と hash の役割が決定され、二重正本にならない根拠が記録されている | ADR に「実行同一性の正本 = `plan_hash` / `plan_package_hash`」「`plan_version` は新設しない」「将来 `^_plan_revision`（string）で導入する場合も判定分岐に使わない」が明記され、`grep -rn "plan_version\|plan_revision" scripts/ schemas/ bin/` が **0 件**であること（= 番号で実行許可を判定する経路が存在しないこと）を根拠として示す |
| **AC-5** | #980 との責務境界が記録されている | ADR に「#981 が担当 / #980 が担当」の分界表があり、**「PR1〜PR3 の ActorSession ID は非検証の opaque string」**が明記されている。加えて **`run-event.schema.json` の `agent` / `by` について (1) 語彙の定義（各フィールドに何を入れるか）と (2) writer 所有権（どのコード経路が書くか）が本 ADR で確定**しており、「#980 は独自語彙を割り当てない」ことが分界表に記載されている（C-2 R-003。`docs/working/TASK-0980/pbi-input.md:181` が #981 PR1 に委ねている論点） |
| **AC-6** | 既存挙動が不変であることが確認できる | `git diff origin/main --name-only` に **コード配下（`schemas/` / `bin/` / `scripts/` / `tests/` / `.claude/` / `.github/`）の変更が 0 件**であり、変更ファイルが「Files / Components to Touch」A + B の集合に収まる（**`.md` 限定・ファイル数固定では判定しない** — C-1 F-2 是正。`approvals/c3.json` / `decision-log.jsonl` は `.md` ではないが正規の承認フロー成果物）。`sh tests/run-tests.sh` が PR 前後で **`failed == 0` かつ `passed` 同一**。**baseline は絶対値をハードコードせず、exec 開始時に `origin/main` の最新でその場で再取得した値を採用する**（C-2 R-101。参考値: 基点 `73e6a15` での実測 = **524 passed / 0 failed**。旧基点 `7de7baa` では 514 だった）。`scripts/ai-loop/test_*.py` は **`ls` で列挙した全件**が各 exit 0（**本数をハードコードしない**。参考値: `73e6a15` で **15 本**。旧基点では 13 本）。`bin/plangate validate TASK-0981` が `Result: PASS`（TC-18 注記のとおり H-01 で c3.json が発行済みのため） |

## Work Breakdown

### Step 1: 基点更新と棚卸し 2 表の再実測

- **Output**: pbi-input のギャップ 12 項目表と `EC-1`〜`EC-10` 表を main **`73e6a15`** 基点で再走査し、行番号ドリフトの有無を `status.md` に記録する。ドリフトがあれば **ADR 側の付表で是正**する（pbi-input は改変しない — Constraint 6）。**あわせて `origin/main` が `73e6a15` から進んでいないかを exec 開始時に再確認**し、進んでいれば本 Step で再度 merge して確定値（§8 行番号 / `test_*.py` 本数 / `run-tests.sh` の `passed`）を取り直す（C-2 R-101）
- **Owner**: agent
- **Risk**: 低（読み取りのみ）
- 🚩 **チェックポイント**: 12 項目 + 10 条件のすべてに**関数名または記号アンカー**（`check_evidence()` / `build_c3_prime()` / `extract_allowed_paths()` / `_plangate_c3_dispatch` / `RECORD_ALLOWED_KEYS` 等）が併記され、**行番号のみに依拠する根拠が 0 件**であること（行番号は PR 進行中に stale 化する — pbi-input Risks）
- 実測済みの事実（C-2 反映時に基点 `73e6a15` で確認、Step 1 で再確認する）: `bin/plangate` / `schemas/**` / `c3_contract.py` / `c3prime_verify.py` / `plan_package.py` は `7de7baa` から**無変更**で、本 plan が引用する行番号はそのまま有効。ドリフトしたのは `docs/workflows/ai-loop/c3-prime-contract.md`（+41 行 / §8 が L176・対象文 L178 へ移動）・`scripts/ai-loop/test_*.py`（13 → 15 本）・`run-tests.sh` baseline（514 → 524）
- `rollback:` 不要（読み取りのみ）

### Step 2: ADR の新規作成と誤読防止の冒頭宣言

- **Output**: `docs/decisions/adr-002-plan-contract-canonical-source.md` を新規作成。命名は既存慣行 `docs/decisions/adr-NNN-<slug>.md`（実在は `adr-001-approve-out-of-band.md` の 1 件のみ。`docs/adr/` は不在、`docs/rfc/` は provider 提案等の別系統）に従う。節構成は ADR-001 に揃える（`Status` / `Date` / `PBI` / `Decision Makers` → `Context` → `Problem Statement` → `Decision Drivers` → `Considered Options` → `Decision` → `Consequences` → `Related`）
- **本文冒頭の 1 文（必須）**: 「**Plan Contract は既存の Plan Package + c3-prime 契約の別名であり、新しい artifact ではない**」
- **Owner**: agent
- **Risk**: 中（新語の導入自体が「新ファイルを作るのだ」という並行正本の誤読を生む）
- 🚩 **チェックポイント**: 冒頭 1 文が本文の**最初の段落**に存在し、かつ ADR-001 と同じ節見出しが揃っていること。**`Status` が `Accepted`**（PR1 で確定済みであることを示す。ADR-001 の `Proposed` をそのまま踏襲すると PR2 が「まだ決まっていない」と読む余地が残る — C-2 R-114）。**`Related` 節に ADR 採番の予約**を書く: 「本 ADR が `adr-002` を占有する。#980（Actor / Audit Event model）は `adr-003` 以降を使う」（C-2 R-107。`docs/working/TASK-0980/pbi-input.md:355` U-1 が突き合わせを要求している）
- **ai-loop 非適用の明記（C-2 R-111）**: ADR に「本 run（TASK-0981）は legacy（人間 C-3）経路であり ai-loop の LoopSpec 派生対象ではない」旨を 1 行入れる。`scripts/ai-loop/plan_package.py:216-218` の `derive_loopspec()` は `plan.md` に `` Verification Automation: `<cmd>` `` 行を要求し、無ければ fail-closed で例外になる。本 plan には同行が無いが、legacy 経路のため実害はない
- **U-1 の確定**: ADR とする（RFC ではない）。理由 = `docs/rfc/` は新規サブシステム / provider の**提案**（`plangate-decompose.md` / `provider-*.md` / `ai-self-set-gate-hook-enforcement.md`）を置く系統であり、本 PBI は**既存資産の正本配置を確定する決定記録**なので `docs/decisions/` が適合する。slug は `plan-contract-canonical-source`
- `rollback:` `git rm docs/decisions/adr-002-plan-contract-canonical-source.md`

### Step 3: 要件対応表の確定（AC-1）

- **Output**: ADR に 2 つの表を置く。① ギャップ 12 項目 × 判定 × 根拠 × **PR 割当**、② #981 全体 AC 14 項目 × PR1 で扱う範囲
- **Owner**: agent
- **Risk**: 中（「一部満たす」を「既存で満たす」へ丸めると legacy 経路が構造的にスコープ外へ落ちる — pbi-input MJ-1）
- 🚩 **チェックポイント**: 「既存で満たす」5 項目（#1 / #2 / #3 / #4 / #6）の **PR 割当欄がすべて「なし（再実装しない）」**であること。「一部満たす」3 項目（#5 / #7 / #11）は**満たす側と満たさない側が別行または別セル**に分離され、満たさない側に PR2 / PR3 が割り当たっていること
- `rollback:` `git checkout -- docs/decisions/adr-002-plan-contract-canonical-source.md`

### Step 4: 正本配置と schema 機構の決定を記録（D-1 / D-3 / D-4 / AC-2 / AC-3）

- **Output**: ADR に「D-1 契約正本 = `c3-prime-contract.md`（単一）」「D-3 execution reference = sidecar」「D-4 schema 機構 = (c) 採用・(b) 併用・(a) は将来枠・**(d) / (e) は不採用**」を記録し、上記「配置表」（唯一の正本 / 参照のみ）と「**5 経路比較表**」（HO 接触 / 構造表現力 / CI enforcement / 承認 record の不変性）を掲載する（C-2 R-006 / R-102）
- **Owner**: agent
- **Risk**: 高（PR1 の中核。ここが決まらないと PR2 の実装先が定まらず、`approvals/c3.json` と sidecar に情報が散る = 二重正本の実害化）
- 🚩 **チェックポイント**: 配置表の**全行**に「唯一の正本」列と「他の場所での扱い（参照のみ / 書かない）」列が埋まり、**5 経路比較表の全経路 × 全 4 軸（20 セル）**が埋まっていること（空欄・「検討中」を残さない）
- **HO 接触の先出し**: (c) 採用に伴い PR2 で `schemas/plan-contract.schema.json`（HO）と `bin/plangate`（HO・D-6）の変更が必要になる。**AI は patch 提示まで**であることと Human 適用タスクを Step 9 で handoff に BLOCKED として記載する
- **PR2 への事前制約の先出し（C-2 R-103 / R-108）**: (1) sidecar を CI に載せるには **`scripts/schema_mapping.py` へ basename を 1 行登録**する必要があり、忘れると `validate-schemas.py` は `SKIP` を返して**沈黙 PASS** する（`:34-41` / `:139-143`）。(2) sidecar は `.github/workflows/metrics-privacy.yml:11-12`（`**/*.json`）の走査対象であり、`scripts/hooks/check-metrics-privacy.sh:37` の `FORBIDDEN_KEYS`（`file_path` / `absolute_path` / `stdout` / `stderr` / `command_output` 等）を **JSON キー名として使うと BLOCK される**（`:96` の `grep -E "($FORBIDDEN_KEYS)[[:space:]]*:"`）。両方を ADR の PR2 申し送り事項として記録する
- `rollback:` `git checkout -- docs/decisions/adr-002-plan-contract-canonical-source.md`

### Step 5: `plan_version` と hash の役割決定を記録（D-2 / AC-4）

- **Output**: ADR に「実行同一性の正本 = `plan_hash` / `plan_package_hash`」「`plan_version` は新設しない」「将来 `plan_revision` を導入する場合の唯一の許容形式 = `^_plan_revision`（string・判定分岐に不使用）」を記録
- **Owner**: agent
- **Risk**: 中（「せっかくだから」番号を判定に混ぜると、番号を偽って承認済み Plan を騙る経路が生まれる）
- 🚩 **チェックポイント**: `grep -rn "plan_version\|plan_revision" scripts/ schemas/ bin/` の実行結果（**0 件**）を ADR に根拠として掲載し、「番号だけで実行許可を判定する経路が設計上存在しない」ことを示していること
- `rollback:` `git checkout -- docs/decisions/adr-002-plan-contract-canonical-source.md`

### Step 6: #980 との責務境界を記録（D-5 / AC-5）

- **Output**: ADR に以下 3 点を記録する。
  1. 「#981 が担当するもの / #980 が担当するもの」の分界表
  2. 「**PR1〜PR3 の ActorSession ID は非検証の opaque string** であり、主体の真正性は #980 まで保証されない」の明記
  3. **`run-event.schema.json` の `agent` / `by` の語彙定義と writer 所有権の確定**（C-2 R-003 / 新規）。`docs/working/TASK-0980/pbi-input.md:181` の責務境界表が「**#981 PR1 の ADR で先に確定する。本 PBI は決めない。**」と明示的に委ねている論点であり、同 `:190` は #980 の Non-goal としても宣言されている。確定すべき内容は (i) `agent` に入れる値の語彙（現行 `bin/plangate:2037` の `PLANGATE_IMPL_AGENT` 由来の**ツール種別**文字列を継続するのか、Executor 主体識別子へ意味を移すのか）、(ii) `by` に入れる値の語彙（gate イベントの Human / Agent 識別子）、(iii) それぞれを書く writer の所有権（`plangate_append_ndjson` の 3 呼び出し `bin/plangate:1279` / `:2005` / `:2112` のうちどれが何を書くか）
- **Owner**: agent
- **Risk**: 中（opaque string を「検証済み主体」と誤読し、職務分離が担保されていないのに担保されたと report する）。加えて **`schemas/run-event.schema.json:77` は `additionalProperties: false` かつ `^_` の patternProperties も無い**ため、1 フィールドに 2 語彙が入ると逃げ場がなく是正が HO patch になる（所有権を先に決める必要性の根拠）
- 🚩 **チェックポイント**: 「非検証」の語が ADR 本文に存在し、かつ **PR2 で追加する record の説明文にも同旨を残すこと**が ADR の決定事項として書かれていること（PR2 への申し送り）
- 🚩 **チェックポイント（C-2 R-003 / 新規）**: `agent` / `by` の **(i) 語彙定義**と **(ii) writer 所有権**が ADR 本文に明記され、分界表に「**#980 は `agent` / `by` / `plan_hash` に独自語彙を割り当てない**」の 1 行があること（#980 の AC-P2(b)（`docs/working/TASK-0980/pbi-input.md:223`）が本 ADR を参照して検査する）
- `rollback:` `git checkout -- docs/decisions/adr-002-plan-contract-canonical-source.md`

### Step 7: 現状維持 / 補強の 4 判断を記録（D-6 / D-7 / D-8 / D-9）

- **Output**: ADR に D-6（legacy 経路）/ D-7（受理側 presence）/ D-8（prohibited_actions 宣言）/ D-9（evidence stale 束縛先）の決定と根拠を記録し、PR2 / PR3 のスコープ表へ反映する
- **Owner**: agent
- **Risk**: 高（D-6 は HO 対象 `bin/plangate` への変更方針を含む。D-9 は「拡張しない」を妥協と誤読されると PR3 の revision 契約の前提がぶれる）
- 🚩 **チェックポイント**: **D-9 の循環依存**（`ARTIFACTS` が `review-self.md` / `review-external.md` を含むため C-1 marker に `plan_package_hash` を書き込むと自己参照になる）が `c3_contract.py:26-33` を根拠に明記され、**「現行の marker 形式では不可能」という限定表現**（record 側束縛・3 要素部分集合は可能）になっていること
- 🚩 **チェックポイント**: **D-6 の後方互換根拠**（②全面強化は既存 TASK の `c3.json` を一斉 invalid 化する）が明記され、③ の変更範囲が `bin/plangate:2092` の 1 箇所に限定されていること
- 🚩 **チェックポイント（後段 / todo T-09 対応）**: PR2 / PR3 のスコープ表に **PR1 → PR2 → PR3 → #980 Phase 0〜2 → PR4 の順序制約**が記載され、**U-4 / U-5 / U-7 の送り先が全件明示**されていること
- `rollback:` `git checkout -- docs/decisions/adr-002-plan-contract-canonical-source.md`

### Step 8: `c3-prime-contract.md` §8 への但し書き追記（D-10 / S-9）

- **Output**: [`docs/workflows/ai-loop/c3-prime-contract.md`](../../workflows/ai-loop/c3-prime-contract.md) §8（基点 `73e6a15` 実測: **見出し L176 / 追記対象の文 L178**。旧基点 `7de7baa` の L135-137 から +41 行ドリフト — C-2 R-101。**exec 時に再 grep して確定する**）に**1 文を追記**。趣旨: 「additive な任意フィールド追加が本ファイルの改版のみで足りるのは `^_` 注釈キーの場合であり、素の record フィールドを追加する場合は `RECORD_OPTIONAL_KEYS`（`c3_contract.py`）と `schemas/c3-prime.schema.json` の同時更新を要する（後者は Hardening Override 対象）」
- **Owner**: agent
- **Risk**: 中（`docs/workflows/ai-loop/**` は rollout-policy §2 carve-out。ただし本 run は Mode=high-risk で同期 Human C-3 が既に必須のため、追加の承認コストは発生しない）
- 🚩 **チェックポイント**: 既存 §8 の本文を**削除・書き換えせず追記のみ**であること（`git diff` で追加行のみを確認）。契約の破壊的変更手続き（「#872 / #873 / #874 の 3 issue 合意 + plan Replan」）に**触れていない**こと
- `rollback:` `git checkout -- docs/workflows/ai-loop/c3-prime-contract.md`

### Step 9: 非退行確認と handoff への BLOCKED 先出し（AC-6）

- **Output**: 以下をすべて実行し結果を `status.md` / `evidence/verification/` に記録する。加えて handoff に PR2 の Human 適用タスク（`schemas/plan-contract.schema.json` 新設 / `bin/plangate:2092` の BLOCK 化 patch）を **BLOCKED**（`blocker` / `owner` / `unblock_condition`）として先出しする
- **Owner**: agent
- **Risk**: 低（読み取り + 検証のみ）
- 🚩 **チェックポイント**: `git diff origin/main --name-only` に **コード配下（`schemas/` / `bin/` / `scripts/` / `tests/` / `.claude/` / `.github/`）が 0 件**であり、全変更が Files 表 A + B の集合に収まること。`sh tests/run-tests.sh` が **`failed == 0`** かつ `passed` が exec 開始時に取得した baseline と**同一**であること（**絶対値をハードコードしない**。参考値: 基点 `73e6a15` で 524）
- `rollback:` 不要（検証のみ）

## Files / Components to Touch

> **本節の記載規約（C-1 F-1 是正 / C1-PLAN-03）**: 抽出器 extract_allowed_paths()（実装は scripts/ai-loop/plan_package.py の \_PATH\_RE）は、**本節の本文だけ**を走査し「backtick で囲まれスラッシュを含む語」を allowed_paths として機械抽出する。したがって**本節には「変更してよいファイル」以外を backtick で書かない**（リンク記法も、両側の backtick に挟まれた URL が誤抽出されるため本節では使わない）。変更禁止領域は次節「Scope Boundary」に backtick なしで記載する。
>
> **実測による裏付け（C-2 R-110）**: 本節の記載規約に従った plan.md に対し `extract_allowed_paths()` を実行すると **14 件**が抽出され、「Scope Boundary」節のパス（backtick なし）は 1 件も混入しない。抽出範囲は A + B の両表（`_extract_section` の終端判定は h2 見出し（`##` + 空白）のみで `### A.` / `### B.` は貫通するため、意図どおり両方が入る）。**C-2 反映後の plan.md でも同じ実行を行い、禁止パスの混入が 0 件であることを確認済み**。

### A. 本 PBI の変更対象（PR1 の成果物）

| ファイル | 変更種別 | Step | HO | carve-out |
|---------|---------|------|----|-----------|
| `docs/decisions/adr-002-plan-contract-canonical-source.md` | 新規 | 2〜7 | 非該当 | 非該当 |
| `docs/working/TASK-0981/plan.md` | 新規（本ファイル） | B | 非該当 | 非該当 |
| `docs/working/TASK-0981/todo.md` | 新規 | B | 非該当 | 非該当 |
| `docs/working/TASK-0981/test-cases.md` | 新規 | B | 非該当 | 非該当 |
| `docs/working/TASK-0981/review-self.md` | 新規 | C-1 | 非該当 | 非該当 |
| `docs/working/TASK-0981/review-external.md` | 新規 | C-2 | 非該当 | 非該当 |
| `docs/working/TASK-0981/status.md` | 新規 | Step 1〜9 | 非該当 | 非該当 |
| `docs/working/TASK-0981/handoff.md` | 新規 | Step 9 / WF-05 | 非該当 | 非該当 |
| `docs/workflows/ai-loop/c3-prime-contract.md` | 追記（1 文） | 8 | 非該当 | **該当**（rollout-policy §2 ②） |

**計 9 ファイル**（すべて Markdown）。これが **Mode 判定の「変更ファイル数」の母数**である。

### B. PlanGate 標準 artifact（ワークフローが phase 遷移で生成 / C-1 C1-PLAN-04 是正）

[`working-context.md`](../../../.claude/rules/working-context.md) が標準 artifact と定めるもの。本リポジトリでは git 追跡対象（TASK-0873 等で実測）であり、**本 PBI の差分にも現れる**。許可パスには含めるが、**Mode 判定のファイル数（9）には算入しない**。

| ファイル | 生成主体 / タイミング | 拡張子 |
|---------|--------------------|-------|
| `docs/working/TASK-0981/INDEX.md` | ワークフロー（plan 完了時） | `.md` |
| `docs/working/TASK-0981/current-state.md` | ワークフロー（タスク完了ごと） | `.md` |
| `docs/working/TASK-0981/decision-log.jsonl` | ワークフロー（判断のたび append） | **`.jsonl`** |
| `docs/working/TASK-0981/approvals/c3.json` | **Human**（H-01 の `plangate approve`） | **`.json`** |
| `docs/working/TASK-0981/evidence/verification/**` | agent（Step 9 / T-10 の検証ログ） | 任意 |

**算入しない理由**: これらは PBI の設計判断ではなく **workflow の副産物**であり、算入すると Mode 判定が「どの phase まで進んだか」で揺れる。なお **算入した場合でも計 14 ファイルで high-risk 帯（6-15）に収まり、Mode 判定の結論は変わらない**（安全側の確認）。

## Scope Boundary（変更禁止領域 / allowed_paths 非対象）

> 本節のパスは **backtick で囲まない**。前節の記載規約のとおり、囲むと `extract_allowed_paths()` が許可側として抽出してしまうため（C-1 F-1 の再発防止）。

**変更禁止（読み取りのみ / Hardening Override 対象・Constraint 7）**:
schemas/ 配下すべて、bin/plangate、scripts/ 配下すべて、tests/ 配下すべて、.claude/ 配下すべて、.github/workflows/ 配下すべて、CLAUDE.md、AGENTS.md

**改変禁止（main マージ済みの入力確定版 / Constraint 6）**:
docs/working/TASK-0981/pbi-input.md

## Testing Strategy

PR1 は文書のみのため、検証は「**機械的に確認できる形**」に落とす。詳細は [`test-cases.md`](./test-cases.md)。

| 層 | 内容 |
|----|------|
| **成果物構造検査（静的）** | ADR の必須節・必須文・決定事項 `D-1`〜`D-10` の見出しが揃うことを grep で確認（TC-01〜TC-03） |
| **要件対応表の検査（静的）** | 表①: 12 項目すべてに根拠アンカー / 「既存で満たす」5 項目の PR 割当 0 件 / 「一部満たす」3 項目の分離記載 / 「未対応」3 項目の PR 割当が全件非空を grep + 目視突合（TC-04〜TC-06）。表②: #981 全体 AC **14 項目**が全行存在し「PR1 で扱う範囲」列が非空（TC-26 / C-2 R-001・R-010） |
| **正本単一性の検査（静的）** | 配置表の全行に「唯一の正本」と「他の場所での扱い」が埋まる。**5 経路 × 4 軸**の比較表が埋まる（TC-07〜TC-10 / C-2 R-006・R-102） |
| **決定根拠の検査（静的）** | D-6 の変更範囲限定と後方互換根拠（TC-13）/ D-9 の循環依存（TC-14）/ D-7 の意味範囲（TC-23）/ D-8 の二重正本回避（TC-24）/ #980 境界と「非検証 opaque string」（TC-22）|
| **入力の不変性** | `pbi-input.md` の差分が 0 行（TC-25。Constraint 6）|
| **根拠の実測再現** | ADR が引用する grep 結果（`plan_version` 0 件 / `arbiter.py` の maker・checker 0 件）を **exec 時に再実行**して一致を確認（TC-12） |
| **リンク到達性** | 新規・変更 `.md` 内の相対リンクをすべて抽出し `test -f` で到達確認（TC-20）。doc 専用 V-1 の観点（リンク切れ / 正本整合 / 実行例の到達性） |
| **Lint** | `npx --no-install markdownlint-cli2 "docs/decisions/*.md" "docs/working/TASK-0981/*.md" "docs/workflows/ai-loop/c3-prime-contract.md"` = **0 issues**（TC-19） |
| **Regression（非退行 / AC-6）** | `sh tests/run-tests.sh` = **`failed == 0`** + `passed` が PR 前後で同一（**baseline は exec 開始時にその場で再取得**。参考値: 基点 `73e6a15` = **524 passed / 0 failed**）。`scripts/ai-loop/test_*.py` は **`ls` で列挙した全件**を個別実行し各 exit 0（**本数をハードコードしない**。参考値: `73e6a15` で 15 本。`unittest` 実装。CI は `tests/extras/ta-55` 等を経由して `run-tests.sh` に内包）。`bin/plangate validate TASK-0981` が `Result: PASS`（TC-16〜TC-18 / C-2 R-101） |
| **差分の性質検査** | `git diff origin/main --name-only` が `schemas/` / `bin/` / `scripts/` / `tests/` / `.claude/` / `.github/` を **1 件も含まず**、全変更が Files 表 A + B の集合に収まる（TC-15。`.md` 限定・ファイル数固定では判定しない） |

> **変異注入は適用しない**: PR1 に新規テストコードは無く（文書のみ）、検証は既存 baseline との同一性確認である。検出力の実証は PR2 の実装テストで行う（handoff へ申し送り）。

## Risks & Mitigations

| Risk | 影響 | Mitigation |
|------|------|-----------|
| **正本配置の判断を先送りしたまま PR2 に進む** | PR2 の実装先が定まらず `approvals/c3.json` と sidecar の両方に情報が散る = 二重正本の実害化 | AC-2 を PR1 の**ブロッキング完了条件**とする。Step 4 🚩 で配置表の空欄 0 を確認するまで Step 5 以降へ進まない。issue コメント §8 の順序制約（PR1 → PR2 → PR3 → #980 → PR4）を handoff に明記 |
| **Plan Contract という新語が並行正本の印象を生む** | 後続実装者が「Plan Contract という新ファイルを作るのだ」と誤読 | Step 2 で ADR 冒頭 1 文を必須化（🚩）。TC-02 で機械確認 |
| **「一部満たす」を「既存で満たす」に丸める** | legacy 経路（本 TASK-0981 自身を含む大多数）の穴が恒久的にスコープ外へ落ちる | AC-1 の判定に「分離記載」を含める。Step 3 🚩 + TC-06 |
| **D-6 の legacy 強化が後方互換を壊す方向へ拡大する** | 既存 TASK の `c3.json` が一斉に invalid 化し全 TASK の exec が止まる | D-6 の変更範囲を `bin/plangate:2092` の**1 箇所**に固定。全面移植は明示的に非対象と ADR に記録（Step 7 🚩） |
| **HO 接触（`schemas/` / `bin/plangate`）で PR2 が停滞する** | PR2 が「patch 提示のみ」で終わり実装が Human 適用待ちで止まる | PR1 の Step 9 で handoff に **BLOCKED**（`blocker` / `owner` / `unblock_condition`）として先出しする。sidecar 採用により HO 接触が `schemas/` の 1 ファイル追加に限定されることも併記 |
| **`check-plan-hash.sh` に責務を寄せたくなる** | EH-3 は `PLANGATE_BYPASS_HOOK` で常時 exit 0 になり、既定（`PLANGATE_HOOK_STRICT` 未設定）では違反しても WARN で通る = **バイパス可能な承認**になる | Constraint 4 / Non-goals に明記。ADR で「実行許可の正本 = exec preflight strict verifier / EH-3 = 補助防衛」を層として固定し、PR2 / PR3 の変更対象から `scripts/hooks/` を外す |
| **ギャップ表の行番号が PR 進行中に stale 化する** | 「対象 / 対象外」の判定が反転し PR2 で誤った箇所を触る | Step 1 🚩 で全根拠に関数名・記号アンカーを併記（行番号のみ依拠 0 件）。Step 1 で main 基点を再走査 |
| **`docs/workflows/ai-loop/**` 編集による carve-out 見落とし** | 規範層の escalate 責務を実行者が果たさず auto-approve 経路に流れる | Constraint 8 に明記。Mode=high-risk により **autonomous APPROVE 不可 = 同期 Human C-3** が機械的にも要求される（二重の担保） |
| **PR1 が「決めずに書くだけ」で終わる** | ADR に「検討中」「PR2 で決める」が残り、PR2 が再び設計から始まる | D-1〜D-10 を**本 plan で確定**し ADR は記録媒体と位置付ける。TC-03 で `D-1`〜`D-10` の見出し 10 個を機械確認し、TC-07〜TC-10 で空欄 0 を確認 |

## Questions / Unknowns

pbi-input の U-1〜U-8 を **PR1 で決めるもの / PR2 以降へ送るもの**に仕分ける。

| U | 内容 | 仕分け | 対応 |
|---|------|--------|------|
| **U-1** | ADR の配置と採番 | **PR1 で確定** | Step 2。`docs/decisions/adr-002-plan-contract-canonical-source.md`。RFC ではなく ADR とする理由も記録 |
| **U-2** | execution reference の物理的な置き場 | **PR1 で確定** | D-3 / D-4（Step 4）。sidecar 主 + `run.ndjson` 既存プロパティ補助 |
| **U-3** | `prohibited_actions` / `stop_conditions` の宣言フィールド要否 | **PR1 で確定** | D-8（Step 7）。宣言しない（実装が正） |
| **U-4** | `ExecutionRequested` と `ExecutionStarted` を分けるか | **PR1 で schema 骨格レベルのみ確定 / フィールド詳細は PR2**（C-2 R-005 で「PR2 へ全送り」から変更） | **変更理由（HO 適用の 1 回化）**: record 数（1 record か 2 record か）は sidecar schema のトップレベル構造そのものであり、PR2 で `schemas/plan-contract.schema.json`（HO）を Human 適用したあとに「2 record」と決まると**構造改訂で 2 回目の HO patch 適用が必要**になる（#980 も同型リスクを `docs/working/TASK-0980/pbi-input.md:345` に登録している）。したがって **PR1 の ADR で「record 数」と「必須トップレベルキーの有無」だけを確定**し、各 record に載せるフィールド詳細（timestamp 粒度・任意フィールド）は PR2 の field set 設計へ送る。分離の主目的（requester / decision maker の分離）の**検証**は #980 の責務であり、#980 未実装期間は主体差を検証できない点は変わらない |
| **U-5** | `plangate resume` の扱い | **PR3 へ送る** | ギャップ #11。PR1 では ADR に「`resume` 拡張（HO 接触）と `exec` 再実行規定（HO 非接触）の 2 案がある」ことのみ記録し、選択は PR2 の execution reference 確定後に行う |
| **U-6** | 受理側 presence の意味範囲 | **PR1 で方針確定 / 実装は PR2** | D-7（Step 7）。補強する（`c3prime_verify.py` は HO 対象外） |
| **U-7** | `derive_loopspec()` の maker / checker を record に刻むか | **PR2 へ送る** | PR1 は**機構**（D-4）を決める。どのフィールドを載せるかは PR2 の field set 設計。`arbiter.py` に maker / checker の検証が **0 件**である事実は Step 1 で再確認し ADR の要件対応表に記録する |
| **U-8** | evidence stale 判定の適用範囲 | **PR1 で確定** | D-9（Step 7）。`plan.md` 単体を維持。`plan_package_hash` への拡張は**循環依存で不可能**。3 要素部分集合案は PR3 候補 |

**PR1 で決める = U-1 / U-2 / U-3 / U-6 / U-8（5 件）+ U-4 の骨格部分（record 数と必須トップレベルキーの有無）。PR2 以降へ送る = U-4 のフィールド詳細 / U-5 / U-7。**

> **後送の扱い（C-2 R-004 関連）**: 上記の後送は**計画済みの意図的な仕分け**であり、Stop Condition 7 のカウント対象ではない。Stop Condition 7 が数えるのは「**PR1 で確定すると宣言した D-1〜D-10 が未確定のまま残った件数**」のみ。

## Stop Condition（即停止条件）

以下のいずれかに達したら exec を止めて Human 判断を仰ぐ（自律継続しない）。

1. **変更ファイル数が 16 以上**に達した（= critical 帯。Mode 再判定が必要）
2. **HO 対象パスへの変更が PR1 内で必要**になった（現計画は非該当。必要になった時点で C-3 再承認）
3. **D-1〜D-10 のいずれかで、本 plan の決定を覆す実測根拠**が見つかった（例: `c3-prime-contract.md` を正本にできない構造的制約が判明）
4. **`sh tests/run-tests.sh` の failed > 0**（文書のみの変更で失敗するなら前提が崩れている）
5. **`git diff origin/main --name-only` にコード配下（`schemas/` / `bin/` / `scripts/` / `tests/` / `.claude/` / `.github/`）が 1 件でも出現**した（`.md` 以外＝`approvals/c3.json` / `decision-log.jsonl` の出現は**正常**であり停止条件にしない）
6. **`pbi-input.md` の改変が必要**と判断された（Constraint 6 違反。ADR 付表での是正に切り替えられない場合のみ停止）
7. **D-1〜D-10 のうち「PR1 で確定する」と宣言した決定が、未確定のまま残った件数が 1 件以上**になった（= PR1 の目的未達）。
   **カウント対象外**（計画済みの意図的な後送であり誤発火させない — C-2 R-004）: U-4 のフィールド詳細 / U-5 / U-7、D-4 の sidecar field set、D-6 の patch 本文。これらは Questions / Unknowns 表と Step 7 後段で送り先が明示されている
   （旧条件「『PR2 で決める』項目が 3 件以上」は、plan 自身が U-4 / U-5 / U-7 の 3 件を意図的に後送しているため **exec 開始時点で既に閾値に達しており正常フローで誤発火**した。C-1 が是正した Stop Condition 5 と同型の欠陥）

## Replan Triggers（機械値）

| # | トリガー（機械判定可能な値） | 再計画の内容 |
|---|------------------------------|-------------|
| RT-1 | 変更ファイル数 `> 15` | Mode を critical へ引き上げ V-4 を追加。C-3 再承認 |
| RT-2 | D-1〜D-10 のいずれかの決定が exec 中に変更された | 該当決定の根拠を plan に差分反映し、簡易 C-1 を再実行してから続行 |
| RT-3 | Step 1 の再走査で **根拠アンカーが失われた項目が 1 件以上**（対象コードが main で改廃された） | 該当項目のギャップ判定を再実測し、要件対応表と PR 割当を更新 |
| RT-4 | `sh tests/run-tests.sh` の `failed > 0`、または `passed` が **exec 開始時に取得した baseline と不一致** | baseline を 2 回取得し直して安定値を確認したうえで、差分原因が本 PR 由来か切り分ける |
| RT-5 | `git diff origin/main --name-only` に **コード配下（`schemas/` / `bin/` / `scripts/` / `tests/` / `.claude/` / `.github/`）が 1 件以上**、または Files 表 A + B に無いファイルが 1 件以上 | 混入経路を特定して revert。ブランチ base を `origin/main` から作り直す |
| RT-6 | markdownlint issues `> 0` が自動修正で解消しない | 該当記法を書き換え、L-0 を再実行 |

## Mode判定

**モード**: **high-risk**

**判定根拠**:

- **変更ファイル数**: **9**（ADR 1 + working context 7 + `c3-prime-contract.md` 1）→ **high**（6-15）
- **受入基準数**: **6**（AC-1〜AC-6）→ **high**（6-10）
- **タスク数（見込み）**: 9 Step / todo で **13 タスク**（T-04 を T-04a / T-04b / T-04c へ 3 分割 — C-1 C1-TODO-08 是正）→ **high**（11-20）
- **変更種別**: doc（**変更対象 A の 9 ファイルはすべて Markdown**。差分には workflow 標準 artifact B の `approvals/c3.json` / `decision-log.jsonl` も現れるが、これらは PBI の設計判断ではなく承認フローの副産物であり 変更種別判定の対象にしない）。ただし **`doc-light` は適用しない**。除外条件「ドキュメントが API 仕様・契約の正本で、コード側の追従を要する」に該当する（[`c3-prime-contract.md`](../../workflows/ai-loop/c3-prime-contract.md) は契約正本であり、ADR は PR2 の実装先を決定する）→ 通常モードへフォールバック
- **リスク**: **高**（承認境界に接する設計判断。正本配置を誤ると二重正本が生まれ、承認済み Plan を騙る経路の設計余地を残す）
- **影響範囲**: 複数レイヤーに波及（PR2 / PR3 / #980 の実装先を規定する）
- **ロールバック**: 計画的に必要（Step 単位で `git checkout --` 可）
- **HO 対象パス**: **非該当**（`docs/decisions/` / `docs/working/` / `docs/workflows/` はいずれも HO 9 カテゴリ外）。したがって「承認境界周辺の変更 → 最低でも高」の**機械判定ルートでは high にならない**が、定量 3 軸・定性 2 軸がいずれも high に落ちるため結論は変わらない
- **rollout-policy §2 carve-out**: **該当**（Step 8 で `docs/workflows/ai-loop/**` を編集）→ **escalate 固定**。規範層のため `arbiter.py` の `boundary_check` は `boundary=clean` と判定する。実行者が escalate する責務を負う
- **`lite_eligible`**: **false**（新規設計あり = 正本配置の確定。安全側不変条件 AC-8 に従い判定不能な軸があれば false 側へ倒す）
- **最終判定**: **high-risk** — 定量・定性ともに high。**C-3 は Human 必須**（mode-classification: high-risk は autonomous APPROVE 不可）。C-2 外部レビューは複数観点で実施。V-2（コード最適化）はコード変更が無いため実質 N/A、V-3 は実施、V-4 は critical 専用のため非該当
