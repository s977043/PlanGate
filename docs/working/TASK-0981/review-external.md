# C-2 外部レビュー結果 — TASK-0981（#981 PR1）

> Plan: [`plan.md`](./plan.md) / ToDo: [`todo.md`](./todo.md) / Test Cases: [`test-cases.md`](./test-cases.md) / C-1: [`review-self.md`](./review-self.md)
> レビュー対象: 本ブランチ `docs/981-c1` の `fc60759` 時点の plan / todo / test-cases（+ pbi-input を参照入力として）
> レビュー体制: [`.claude/rules/review-principles.md`](../../../.claude/rules/review-principles.md) §7-bis の **2 レーン責務契約**に従う
> **本ファイルは追記専用**（[`.claude/rules/working-context.md`](../../../.claude/rules/working-context.md)「C-2 指摘の差分管理」）。指摘 ID は `R-NNN`。計画本体への反映は **1 回だけ確定**する

## レーン構成と実施結果

| レーン | 読んだもの | 読まなかったもの | 指摘数 | verdict |
|--------|-----------|----------------|-------|---------|
| **設計妥当性レーン**（R-001〜R-011） | plan / todo / test-cases / pbi-input | 実装コード（原則） | 11 件（major 6 / minor 4 / info 1） | **CONDITIONAL**（critical 0・major 6） |
| **コードベース整合レーン**（R-101〜R-115） | 既存パターン該当箇所（`bin/plangate` / `schemas/` / `scripts/` / `.github/workflows/`） | plan の網羅性判定 | 15 件（major 3 / minor 6 / info 6） | **CONDITIONAL**（critical 0・major 3） |

**総合 verdict: CONDITIONAL**（critical 0 / major 9）。**D-1〜D-10 の決定そのものを覆す実測根拠は両レーンとも 0 件**。指摘は「比較表の経路欠落」「根拠の論理反転」「AC / TC への未落とし込み」「基点 stale」に集中しており、**決定の維持 + 記述・判定条件の是正**で解消する性質のもの。

> **コード起因の AC 欠落の返送**（review-principles §7-bis / V-3 MJ-3）: コードベース整合レーンが検出した R-102（第 4・第 5 経路の未検討）と R-103（enforcement の唯一点）は、**AC-3 の充足性に直結する**ため設計妥当性レーンへ返送し、AC-3 の判定条件の是正として統合した。

## 監査表（追記専用 / squash・rebase 耐性）

`reflected_in` は反映コミットの subject 先頭で識別する（squash 後も追跡できるよう、コミット本文に `Refs: R-NNN` を全列挙する）。

| R-NNN | lane | severity | status | reflected_in | notes |
|-------|------|----------|--------|-------------|-------|
| R-001 | 設計妥当性 | major | reflected | `docs(plan): #981 PR1 の C-2 指摘を 1 回確定反映` | AC-1 に要件対応表②の検査条件を追加 + TC-26 新設 |
| R-002 | 設計妥当性 | major | reflected | 同上 | D-6 の fail-open 記述の論理反転を是正 + ② 棄却理由を実測（80 件中 1 件）で書き直し |
| R-003 | 設計妥当性 | major | reflected | 同上 | Step 6 / D-5 の Output に `agent` / `by` の語彙定義 + writer 所有権を追加。AC-5 / TC-22 に反映 |
| R-004 | 設計妥当性 | major | reflected | 同上 | Stop Condition 7 を「PR1 で確定と宣言した決定の未確定件数」へ置換 |
| R-005 | 設計妥当性 | major | reflected | 同上 | U-4 を「PR1 で schema 骨格レベルのみ確定 / フィールド詳細は PR2」へ変更（HO 適用 1 回化） |
| R-006 | 設計妥当性 | major | reflected | 同上 | D-4 の比較経路に (d) 既存 schema への型付き additive を追加（3 → 5 経路） |
| R-007 | 設計妥当性 | minor | reflected | 同上 | 配置表に `plan_hash` の run.ndjson コピーの位置付けを明記し TC-08 の判定可能性を回復 |
| R-008 | 設計妥当性 | minor | reflected | 同上 | TC-03 の禁止語検査を **Decision 節に限定**（T-09 の未決事項記載と衝突しない形へ） |
| R-009 | 設計妥当性 | minor | reflected | 同上 | D-2 に `plan_id` を新規採番しない（`task_id` 再利用）を追記 |
| R-010 | 設計妥当性 | minor | reflected | 同上 | AC-1 に「未対応 3 項目の PR 割当が全件存在する」（欠落抑制）を追加 |
| R-011 | 設計妥当性 | info | reflected | 同上 | R-103 の実測で解決。D-4 判定根拠に enforcement の唯一点を明記 |
| R-101 | コードベース整合 | major | reflected | 同上 | 基点を main `73e6a15` へ更新し、stale 値（§8 行番号 / テスト本数 / baseline）を全件再実測 |
| R-102 | コードベース整合 | major | reflected | 同上 | D-4 比較表に (e) `docs/schemas/`（非 HO・段階昇格）を第 5 経路として追加し不採用理由を明記 |
| R-103 | コードベース整合 | major | reflected | 同上 | `schema_mapping.py` への 1 行が enforcement の唯一点である旨を D-4 判定根拠と ADR 要求へ落とす |
| R-104 | コードベース整合 | minor | reflected | 同上 | D-4(a) の不採用理由を「c3-prime 限定の事実」として限定表現に是正 |
| R-105 | コードベース整合 | minor | reflected | 同上 | D-3 の根拠に `plangate approve` の固定キー再生成（`^_` 手書き値の消失）を追加 |
| R-106 | コードベース整合 | minor | reflected | 同上 | D-6 の「本番フロー大多数の穴」を多層防御の層表現へ是正 |
| R-107 | コードベース整合 | minor | reflected | 同上 | ADR の `Related` に「#980 は adr-003 以降を使う」の採番予約を追加 |
| R-108 | コードベース整合 | minor | reflected | 同上 | EH-8 privacy CI が sidecar の field set 設計の事前制約であることを D-4 / PR2 申し送りへ追加 |
| R-109 | コードベース整合 | minor | reflected | 同上 | 「`run.ndjson` は CI 強制ゼロ」を「**schema 検証**経路が 0 本」へ限定 |
| R-110 | コードベース整合 | info | reflected | 同上 | `extract_allowed_paths()` の実測（14 件）を plan の記載規約の裏付けとして記録 |
| R-111 | コードベース整合 | info | reflected | 同上 | ADR に「本 run は ai-loop 非適用（LoopSpec 派生対象外）」の 1 行を要求 |
| R-112 | コードベース整合 | info | acknowledged | — | D-9 の循環依存の主張は正確。是正不要 |
| R-113 | コードベース整合 | info | acknowledged | — | D-3 / D-6 / D-8 / U-7 / D-4(b) / D-7 / `^_` 経路の根拠を全数照合し一致。是正不要 |
| R-114 | コードベース整合 | info | reflected | 同上 | Step 2 のチェックポイントに ADR-002 の `Status` 値（`Accepted`）を追加 |
| R-115 | コードベース整合 | info | acknowledged | — | `docs/decisions/` にインデックス・README は無く追加登録作業は不要。是正不要 |

**集計**: 26 件中 **reflected 22 件 / acknowledged（是正不要）4 件 / rejected 0 件**。

---

## A. 設計妥当性レーン（R-001〜R-011）

### R-001 [major] 要件対応表②が AC / TC のいずれからも検証されない

plan Step 3 は ADR に **2 つの表**（① ギャップ 12 項目 / ② #981 全体 AC 14 項目 × PR1 で扱う範囲）を置くと定めるが、AC-1 の機械判定は表①の条件しか列挙しておらず、TC-04 / TC-05 / TC-06 も表①のみを入力にしている。**表②が空でも行が欠落していても全 TC が PASS する**。

- 根拠: `plan.md` Step 3 Output（2 表）/ AC-1 の判定条件（12 項目のみ）/ `test-cases.md` TC-04〜TC-06 の入力欄
- 是正: AC-1 に「表②が #981 全体 AC **14 項目すべて**を行として持ち、各行に PR1 で扱う範囲が非空で入る」を追加し、**TC-26 を新設**する

### R-002 [major] D-6 の棄却理由が採用案 ③ にもそのまま当てはまる／説明文の論理が反転している

2 つの問題が重なっている。

1. **棄却理由の適用漏れ**: D-6 は ②（全面強化）を「既存 TASK の `c3.json` を一斉に invalid 化し後方互換を破壊する」として棄却したが、採用した ③（`recorded_hash` が空なら BLOCK）が塞ぐのは **`plan_hash` を持たない c3.json** であり、これは ② が invalid 化する集合の部分集合である。「③ なら後方互換を壊さない」とは論証されていない。
2. **説明文の論理反転**: D-6 は ③ を「**記録があるのに照合しない** fail-open だけを塞げる」と説明するが、pbi-input ギャップ #5 の実測は「c3.json に `plan_hash` が**無ければ** hash 突合そのものが無言で skip」である。**記録が「ある」ケースは既に照合されている**（`bin/plangate:2098`）。塞ぐ対象は「記録が**無い**から照合しない」経路であり、記述と実装が逆。

- 根拠: `pbi-input.md:39`（ギャップ #5）/ `bin/plangate:2092`（`if [ -n "$recorded_hash" ]`）/ `bin/plangate:2098`（mismatch 判定）
- 是正: 説明文を実装どおりに直し、後方互換の影響を**実測で定量化**する（コードベース整合レーンの実測: 追跡下の `docs/working/*/approvals/c3.json` **80 件中、`plan_hash` を持たないのは 1 件**（`TASK-0038`）。したがって ③ の後方互換影響は ② と桁が違い、決定は維持できる）

### R-003 [major] `run-event.schema.json` の `agent` / `by` の語彙定義と writer 所有権が Step / AC / TC のどこにも落ちていない

`docs/working/TASK-0980/pbi-input.md:181` の責務境界表は、この 3 プロパティの語彙定義と writer 所有権を「**#981 PR1 の ADR で先に確定する。本 PBI は決めない。**」と明示的に #981 側へ委ねている。同 `:190` は #980 の Non-goal としても宣言している。しかし plan の D-4(b) は「`plan_hash` / `agent` / `by` を `session_started` に刻む」と**使う**ことだけを決めており、**語彙（何を入れるか）と所有権（誰が書くか）を確定する要求が Step 6 / D-5 / AC-5 / TC-22 のいずれにも存在しない**。`run-event.schema.json:77` は `additionalProperties: false` で `^_` の patternProperties も無いため、1 フィールドに 2 語彙が入ると逃げ場がなく拡張は HO patch になる。

- 根拠: `docs/working/TASK-0980/pbi-input.md:181` / `:190` / `:223`（AC-P2(b)）/ `schemas/run-event.schema.json:48-60` / `:77`
- 是正: Step 6 / D-5 の Output に語彙定義と writer 所有権の確定を追加し、AC-5 の機械判定と TC-22 の期待出力に反映する

### R-004 [major] Stop Condition 7 が計画済みの後送と衝突し正常フローで誤発火する

Stop Condition 7 は「**『PR2 で決める』項目が 3 件以上**残ったら停止」だが、plan 自身が U-4 / U-5 / U-7 の 3 件を意図的に PR2・PR3 へ送っており（`plan.md` Questions / Unknowns 末尾「PR2 以降へ送る = U-4 / U-5 / U-7（3 件）」）、さらに D-4 sidecar の field set と D-6 patch 内容も PR2 で決める。**exec 開始時点で既に閾値に達している**。C-1 が是正した Stop Condition 5（`.md` 限定判定が承認フローで誤発火）と同型の欠陥。

- 根拠: `plan.md` Stop Condition 7 / Questions & Unknowns 節末尾 / D-4 / D-6
- 是正: 「**D-1〜D-10 のうち PR1 で確定と宣言した決定が未確定のまま残った件数が 1 件以上**」へ置換し、計画済み後送（U-4 / U-5 / U-7）はカウント対象外と明記する

### R-005 [major] U-4 を PR2 へ丸ごと送ると sidecar schema（HO）の Human 適用が 2 回発生しうる

U-4（`ExecutionRequested` / `ExecutionStarted` を分けるか）を PR2 へ送ると、PR2 で `schemas/plan-contract.schema.json`（HO）の patch を適用したあとに U-4 の結論が「2 record」だった場合、record 数に応じた構造改訂で **2 回目の HO patch 適用**が必要になる。#980 の pbi-input も同型のリスクを「HO patch の Human 適用が 2 回発生する」として登録している（`docs/working/TASK-0980/pbi-input.md:345`）。

- 是正: U-4 の仕分けを「**PR1 で schema 骨格レベルのみ確定**（record 数と必須トップレベルキーの有無）／フィールド詳細は PR2」へ改める

### R-006 [major] AC-3 の比較経路から「既存 schema への型付きフィールド追加」が脱落

pbi-input の AC-3 相当は新規 schema の必要性を「既存で足りない」ことの論証として要求しているが、plan の 3 経路には **(d) 既存 `schemas/c3-prime.schema.json` へ型付きプロパティを additive 追加する**（`RECORD_OPTIONAL_KEYS` と schema の同時更新）が含まれていない。これは D-10 が §8 の但し書きとして**まさに手続きを明文化しようとしている経路**であり、比較表に無いのは不整合。

- 根拠: `scripts/ai-loop/c3_contract.py:50-51`（`RECORD_OPTIONAL_KEYS` / `RECORD_ALLOWED_KEYS`）/ `plan.md` D-10
- 是正: D-4 比較表に (d) を追加し、不採用理由（承認 record の不変性を壊す・1 承認 : N 実行を表現できない）を書く。AC-3 / TC-09 / TC-10 の「3 経路」を更新

### R-007 [minor] 「コピーが 2 箇所以上に存在しない」宣言と D-4(b) の整合が ADR に無く TC-08 が判定不能

配置表は「実行同一性 = `approvals/c3.json` の `plan_hash`」「sidecar は書かず参照」とする一方、D-4(b) は `plan_hash` を `run.ndjson` にも刻む。TC-08 は「他の場所での扱い」列がすべて「参照のみ / 書かない」であることを判定条件にしているため、**`run.ndjson` の行が「刻む」となった瞬間に判定不能になる**。

- 是正: 配置表に「`run.ndjson` は**非正本のトレース複製**であり、不一致時は `approvals/c3.json` が勝つ」を明記し、TC-08 の判定条件を「正本列が単一 + 非正本側が正本を上書きしないことが明記されている」へ具体化

### R-008 [minor] T-04c の禁止語検査と T-09 の未決事項記載が同一ファイル上で衝突

T-04c の 🚩 は「ADR 全体に `検討中` / `後で決める` が 0 件」を要求するが、T-09 は「U-4 / U-5 / U-7 を PR2 / PR3 の**未決事項として明示**」せよと要求する。未決事項を素直に書くと禁止語に触れる。

- 是正: TC-03 / T-04c の禁止語検査の適用範囲を「**Decision 節に限る**」へ限定し、PR2 / PR3 スコープ表は対象外と明記

### R-009 [minor] `plan_id` の役割決定が D-1〜D-10 にも AC にも無い

pbi-input は「`plan_id` は `task_id` を再利用し新規採番しない」と結論しているが、plan の決定事項にも AC にも現れないため、PR2 で新規採番されるリスクが残る。

- 是正: D-2（実行同一性）の記述に `plan_id` を新規採番しない旨を追記する

### R-010 [minor] AC-1 が「未対応 3 項目の PR 割当欠落」を検査しない

AC-1 は「既存で満たす 5 項目に PR 割当が 0 件」（過剰の抑制）と「一部満たす 3 項目の分離記載」は検査するが、**未対応 3 項目（#8 / #9 / #10）が PR2 / PR3 に割り当たっているか**（欠落の抑制）を検査しない。表から行が落ちても PASS する。

- 是正: AC-1 に「未対応 3 項目の PR 割当が全件非空」を追加

### R-011 [info] D-4 の「sidecar は CI 検証経路に載る」の裏取りが 1 段足りない

→ コードベース整合レーンが **R-103** で実測回答済み。経路には載るが `schema_mapping.py` への登録が無いと `SKIP` で沈黙 PASS になる。

---

## B. コードベース整合レーン（R-101〜R-115）

### R-101 [major] 基点 stale（main が 4 commit 進行）

plan の基点は main `7de7baa` だが、実 `origin/main` は `73e6a15`（#989 = TASK-0874 RunEvidence 契約の producer / 受理器 / fixture）。以下が stale 化していた（**本反映時に全件再実測済み**）。

| 項目 | plan の記載 | 実測（`73e6a15`） | 影響 |
|------|-----------|------------------|------|
| `c3-prime-contract.md` §8 | L135-137 | **§8 見出し = L176、追記対象の文 = L178**（`+41` 行） | Step 8 / D-10 が誤った行を指す |
| `scripts/ai-loop/test_*.py` | 13 本 | **15 本**（`test_run_evidence.py` / `test_run_evidence_verify.py` 追加） | TC-17 / T-10 の期待値が外れる |
| `tests/extras/*.sh` | （記載なし） | **57 本** | — |
| `sh tests/run-tests.sh` | 514 passed / 0 failed | **524 passed / 0 failed** | AC-6 / TC-16 の baseline が外れる |
| 「コードファイルの行番号は不変」 | 断定 | **部分的に誤り** — `bin/plangate` / `schemas/**` / `c3_contract.py` / `c3prime_verify.py` / `plan_package.py` は無変更で行番号は保持されるが、`docs/workflows/ai-loop/c3-prime-contract.md` は `+41` 行、`scripts/sync-plugin-plangate.sh` / `tests/extras/ta-58` / `ta-59` も変更されている | 「不変」の断定が過大 |

- 是正: 基点を `73e6a15` に更新し、上記の確定値へ差し替える。**AC-6 / TC-16 は絶対値をハードコードせず「exec 開始時に `origin/main` 最新で再取得した値を baseline とする」形に直す**

### R-102 [major] D-4 が第 4 の経路 `docs/schemas/`（非 HO）を検討していない

Hardening Override パターンは `schemas/*.schema.json`（`scripts/hooks/check-plan-hash.sh:131`）であり、**`docs/schemas/` は HO 対象外 = AI が直接作成できる**。#874（`73e6a15`）はこれを利用して `docs/schemas/run-evidence.schema.json` を新設し、`$id` を**昇格後 URL で先に固定**することで `schemas/` への昇格を **`git mv` 1 手の HO patch** に収める設計を確立している（`docs/working/TASK-0874/plan.md:26` / `:63` D1-A / `:463`）。

ただし副作用も既知である。`SCHEMAS_DIR` は `REPO_ROOT / "schemas"` 固定（`scripts/_paths.py:23`）で、`schema-validate.yml` の trigger paths にも `docs/schemas/**` は含まれないため、sidecar インスタンスを CI 検証させるには最終的に `schemas/` 昇格が必要（TASK-0874 handoff **K-12** が既知課題として登録済み）。

- 判定: **決定（(c) 採用）は変えなくてよい**。ただし比較表に第 5 行として記録し、「なぜ段階案（`docs/schemas/` → 後日 `git mv`）を採らないか」を書かないと **AC-3 が実質不十分**
- 是正: D-4 比較表に (e) を追加し、不採用理由（PR1 は実装しないため段階化の利得が無く、sidecar インスタンス検証には結局 `schemas/` 昇格が要る = HO 適用回数は減らない）を明記

### R-103 [major] 「sidecar は CI 検証経路に載る」は条件付き — `schema_mapping.py` の 1 行が enforcement の唯一点

`schema-validate.yml` は変更 JSON を `git diff --name-only --diff-filter=AM | grep -E '^docs/working/.*\.json$'` で抽出し `--files-from` で渡す（`.github/workflows/schema-validate.yml:53-70`）ので、**経路には載る**。しかし `scripts/validate-schemas.py:34-41` の `validate_one()` は `lookup_schema()` が `None` を返すと **`SKIP`** を返し、`:139-143` の exit code 判定は `ERROR` / `FAIL` のみを見る。**`SKIP` は集計上 FAIL にならない = 沈黙 PASS**。

つまり sidecar を新設しても **`scripts/schema_mapping.py` へ basename を 1 行追加し忘れた瞬間に CI は沈黙して通る**。この 1 行が enforcement の唯一の点であることが D-4 の判定根拠から読み取れない。

- 是正: D-4 の CI enforcement 軸に「**登録忘れ = 沈黙 PASS**」を明記し、ADR に「PR2 で `schema_mapping.py` へ登録すること」を申し送り事項として要求する

### R-104 [minor] `^_` 注釈キーの型制約は record 種別で非対称

D-4(a) の不採用理由「string のみで入れ子を表現できない」は **c3-prime 限定の事実**。

| schema | `^_` の型制約 | 構造検査器 |
|--------|-------------|----------|
| `schemas/c3-prime.schema.json:113-118` | **`"type": "string"`** | `c3prime_verify.py:73`（未知キー検査 / `^_` は除外） |
| `schemas/c3-approval.schema.json:88-92` | **型制約なし**（`description` のみ） | 無し（legacy exec preflight は `bin/plangate:2070-2076` の grep のみ） |

TASK-0981 自身を含む legacy 経路では `approvals/c3.json` の `^_` に入れ子を書いても schema 上は通る。

- 是正: D-4(a) の不採用理由を「c3-prime 経路では string 固定。legacy 経路では型制約が無いが、**型制約が無いこと自体が正本にできない理由**（機械検証されない）」へ限定表現で書き直す

### R-105 [minor] `plangate approve` は c3.json を固定キー集合で丸ごと再生成する

`bin/plangate:2382`（既存 c3.json は `--force` なしで abort）/ `:2400-2423`（Python heredoc が `task_id` / `phase` / `c3_status` / `approved_by` / `approved_at` / `plan_hash` / `source` / `_approved_by_source` / `_approver_identity_unverified` / `_note` の**固定キー集合**で `json.dump`）。**`--force` による再承認では、手書きした `_execution_ref` / `_plan_revision` 等は消失する**。

- 是正: D-3（execution reference を `approvals/c3.json` に置かない）の根拠に、この「CLI 再生成による喪失」を追加する（D-3 の決定を補強する材料）

### R-106 [minor] D-6 の「本番フロー大多数の穴」は過大表現

多層防御の実測:

| 層 | 実装 | 効果 |
|----|------|------|
| CLI 発行 | `bin/plangate:2408`（`"plan_hash": phash`） | `plangate approve` 経由なら必ず入る |
| schema | `schemas/c3-approval.schema.json:7-13` の `required` に `plan_hash` | 欠落は schema 違反 |
| CI | `approvals/c3.json` は `docs/working/**/*.json` で `schema-validate.yml` の対象 | PR で検出 |
| exec preflight | `bin/plangate:2092` の `if [ -n "$recorded_hash" ]` | **ここだけ fail-open** |

実際の fail-open 窓は「**CLI 非経由で手書きされ、かつ schema 違反の c3.json**」に限定される。実測でも追跡下 80 件中 `plan_hash` 欠落は 1 件（`TASK-0038`）のみ。

- 是正: 根拠を「多層防御の**最後の 1 層が抜けている**」という層表現に書き直す（決定 ③ は維持）

### R-107 [minor] ADR 採番の衝突予約が無い

`docs/working/TASK-0980/pbi-input.md:355`（U-1）が「採番 `adr-002` 〜 `adr-004` と #981 との突き合わせ」を明示的に要求している。#981 が `adr-002` を取る旨を #981 側の ADR に書かないと、#980 が同じ番号を取る。

- 是正: ADR の `Related` に「本 ADR が `adr-002` を占有する。#980（Actor / Audit Event model）は `adr-003` 以降を使う」を書く

### R-108 [minor] sidecar は EH-8 privacy CI の走査対象

`.github/workflows/metrics-privacy.yml:11-12` の trigger paths は `**/*.json` / `**/*.ndjson`。`scripts/hooks/check-metrics-privacy.sh:37` の `FORBIDDEN_KEYS` は `"file_path"` / `"absolute_path"` / `"stdout"` / `"stderr"` / `"command_output"` 等を **`:96` の `grep -E "($FORBIDDEN_KEYS)[[:space:]]*:"`（= JSON キーの形）**で検出して BLOCK する。

- 是正: execution reference の field set 設計の**事前制約**として D-4 と PR2 申し送りに明記する（`file_path` 等をキー名に使わない）

### R-109 [minor] 「`run.ndjson` は CI 強制ゼロ」は schema 検証限定の話

`.ndjson` は `validate-schemas.py:80` の `rglob("*.json")` にも `schema_mapping.py` にも掛からないため **schema 検証経路は 0 本**だが、`metrics-privacy.yml` は `**/*.ndjson` を trigger に含む。TASK-0874 plan `:77` が同じ論点を「『schema 検証経路が 0 本』と『一切の CI に触れない』は別」として既に是正済み。

- 是正: D-4 の enforcement 軸の記述を「**schema 検証**経路が無い」へ限定する

### R-110 [info] `extract_allowed_paths()` の実測で plan の記載規約の主張が成立

反映前の `plan.md` に対する実測: **14 件**。`## Scope Boundary` 節のパス（backtick なし）は 1 件も混入していない。ただし `_extract_section` の終端判定は h2 見出し（`##` + 空白）のみで、`### A.` / `### B.` は貫通する（= A + B の両表が抽出される。plan の意図どおり）。

### R-111 [info] `plan.md` に `Verification Automation:` 行が無く `derive_loopspec()` は fail-closed

`scripts/ai-loop/plan_package.py:216-218` は `Verification Automation:\s*\`([^\`]+)\`` を要求し、無ければ `PlanPackageError` を送出する。TASK-0981 は legacy（人間 C-3）経路のため実害は無いが、ADR に「本 run は ai-loop 非適用（LoopSpec 派生の対象外）」の 1 行があると誤読を防げる。

### R-112 [info] D-9 の循環依存の主張は正確

`scripts/ai-loop/c3_contract.py:26-33` の `ARTIFACTS` は `review-self.md` / `review-external.md` を含む。marker 文法も完全一致ちょうど 1 回で追記余地がない。**是正不要**。

### R-113 [info] D-3 / D-6 / D-8 / U-7 / D-4(b) / D-7 / `^_` 経路の根拠を全数照合

すべて一致（`bin/plangate:1279` / `:2005` / `:2112` の `plangate_append_ndjson` 3 箇所・`schemas/run-event.schema.json:48-60` の 3 プロパティ定義・`:77` の `additionalProperties: false`・`c3prime_verify.py:73` の `^_` 除外）。**是正不要**。

### R-114 [info] ADR-002 の `Status` 値を Step 2 のチェックポイントに含めるべき

ADR-001（`docs/decisions/adr-001-approve-out-of-band.md:1-10`）の節構成と plan Step 2 の宣言は完全一致。ただし ADR-001 の `Status` は `Proposed`。ADR-002 は「PR1 で確定・PR2 が従う」性格なので、`Status` を `Proposed` のまま出すと PR2 が「まだ決まっていない」と読む余地が残る。

- 是正: Step 2 の 🚩 に「`Status` が `Accepted`（= PR1 で確定済み）であること」を追加

### R-115 [info] `docs/decisions/` にインデックス・README は無い

`ls docs/decisions/` = `adr-001-approve-out-of-band.md` の 1 件のみ。ADR 追加時の登録作業は不要。**是正不要**。

---

## 反映の順序（working-context「C-2 指摘の差分管理」準拠）

1. ✅ **review-external.md に `R-NNN` 集約**（本ファイル）
2. ✅ **1 回だけ確定反映**（`plan.md` / `todo.md` / `test-cases.md`。反映コミットに `Refs: R-NNN` を全列挙）
3. ⏳ **簡易 C-1 再実行**（反映後の plan / todo / test-cases に対して）
4. ⏳ **Human が最終 `c3.json` を発行**（`c3_status=APPROVED` + **確定反映後**の `plan.md` の `plan_hash`。`bin/plangate approve TASK-0981`）
5. ⏳ **exec 開始**

> ⚠️ `c3.json` の発行は **確定反映の後**。先に発行すると EH-3 が後続反映を mismatch として検知する。
