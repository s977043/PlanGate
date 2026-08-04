# EXECUTION TODO — TASK-0981（#981 PR1）

> Plan: [`plan.md`](./plan.md) / Test Cases: [`test-cases.md`](./test-cases.md) / 入力: [`pbi-input.md`](./pbi-input.md)
> Mode: **high-risk**（C-2 複数観点 + **C-3 Human 必須**・autonomous APPROVE 不可）
> 基点: main **`73e6a15`**（C-2 R-101 で `7de7baa` から更新。#989 = TASK-0874 RunEvidence 契約を取り込み済み）/ 成果物は**文書のみ**（コードを 1 行も変更しない）
> rollout-policy §2 carve-out 該当（T-08 で `docs/workflows/ai-loop/**` を編集）→ **escalate 固定 = 同期 Human C-3**

## 依存関係

```text
H-01（👤 C-3 ゲート）
  └→ T-01（基点更新・棚卸し 2 表の再実測）🚩
        └→ T-02（ADR 新規作成 + 冒頭 1 文）🚩
              └→ T-03（要件対応表の確定）🚩
                    └→ T-04a（配置表 D-1 / D-3）🚩 ← PR1 の中核
                          └→ T-04b（5 経路比較表 D-4）🚩
                                └→ T-04c（Decision 節の断定文）🚩 ← ブロッキング
                                      ├→ T-05（plan_version D-2）🚩
                                      ├→ T-06（#980 境界 D-5）🚩
                                      └→ T-07（4 判断 D-6/D-7/D-8/D-9）🚩
                                            └→ T-08（c3-prime-contract §8 追記 D-10）🚩
                                                  └→ T-09（PR2/PR3 スコープ表の反映）🚩
                                                        └→ T-10（非退行確認 AC-6）🚩
                                                              └→ T-11（handoff: BLOCKED 先出し）🚩
                                                                    └→ [L-0 / V-1 / V-3 / PR 作成]
                                                                          └→ H-02（👤 C-4 ゲート）
```

- **H-01（👤 human・T-01 の前）**: C-3 ゲート判断。**high-risk のため必須**（autonomous APPROVE 不可）。`plan.md` / `todo.md` / `test-cases.md` / `review-self.md` / `review-external.md` を確認 → `bin/plangate approve TASK-0981` で APPROVED な `c3.json` を発行
- **H-02（👤 human・PR 作成後）**: C-4 ゲート（GitHub 上でレビュー → **マージは Human-owned**。`NO MERGE BY AI`）
- ⚠️ **T-02 → T-07 は同一ファイル（ADR）を編集するため並行不可**。T-01 は読み取りのみで T-02 の入力になる
- ⚠️ **T-04a〜T-04c は PR1 のブロッキング完了条件**（AC-2 / AC-3）。**T-04c の 🚩 が通るまで T-05 以降へ進まない**
- ⚠️ **T-04 は 3 分割**（C-1 C1-TODO-08 是正）。ADR は 1 ファイルのため分割してもコミット単位は分かれないが、**中断時の再開点**が「どの表まで書けたか」で確定する
- ⚠️ **T-08 は別ファイル**（`docs/workflows/ai-loop/c3-prime-contract.md`）だが、追記内容が D-4 の結論に依存するため T-04c の後に置く

---

## 🤖 Agent タスク

### 準備フェーズ

- [ ] **T-01**: 基点更新と棚卸し 2 表の再実測（plan Step 1 / U-7 の裏取り含む）
  - main を **`73e6a15`**（またはそれ以降の `origin/main` 最新）として、pbi-input のギャップ 12 項目表と `EC-1`〜`EC-10` 表の根拠を**再走査**する。**`origin/main` が進んでいれば先に merge し、下記の確定値を取り直す**（C-2 R-101）:
    - `grep -n "^## 8\." docs/workflows/ai-loop/c3-prime-contract.md` → §8 の**現在の行番号**（`73e6a15` 実測: 見出し L176 / 追記対象文 L178。旧基点では L135-137 だった）
    - `ls scripts/ai-loop/test_*.py | wc -l` → **現在の本数**（`73e6a15` 実測: 15 本。旧基点では 13 本）
    - `ls tests/extras/*.sh | wc -l` → **現在の本数**（`73e6a15` 実測: 57 本）
    - `sh tests/run-tests.sh` → **`passed` の baseline**（`73e6a15` 実測: 524 passed / 0 failed。旧基点では 514。**絶対値をハードコードせず、この場で 2 回取得して安定値を採用**する）
  - 少なくとも以下を実測して `status.md` に記録:
    - `grep -rn "plan_version\|plan_revision" scripts/ schemas/ bin/` → **0 件**（D-2 / AC-4 の根拠）
    - `grep -c "actors\|maker\|checker" scripts/ai-loop/arbiter.py` → **0**（ギャップ #7 / U-7 の根拠）
    - `scripts/ai-loop/c3_contract.py` の `ARTIFACTS` に `review-self.md` / `review-external.md` が**含まれる**こと（D-9 循環依存の根拠）
    - `scripts/ai-loop/c3prime_verify.py` の未知キー検査が `^_` を除外していること（D-2 / D-4(a) の根拠）
    - `bin/plangate` の legacy 経路で `plan_hash` 不在時に**無言 skip** すること、および `validate` 側は `[WARN] plan_hash not found in c3.json` を出すこと（D-6 の非対称の根拠）
    - `.github/workflows/schema-validate.yml` の PR トリガに `docs/working/**/*.json` が**含まれる**こと / `scripts/validate-schemas.py` が `rglob("*.json")` であること（D-4 enforcement 軸の根拠）
    - **`scripts/validate-schemas.py` の `validate_one()` が `lookup_schema()` = None のとき `SKIP` を返し、exit code 判定が `SKIP` を失敗にしない**こと（= `schema_mapping.py` 未登録なら沈黙 PASS / D-4 の enforcement 唯一点の根拠 / C-2 R-103）
    - **`docs/schemas/` が HO パターン外**（`scripts/hooks/check-plan-hash.sh` の case 文は `schemas/*.schema.json` のみ）で、**`SCHEMAS_DIR` が `REPO_ROOT / "schemas"` 固定**（`scripts/_paths.py`）であること（D-4 の第 5 経路 (e) の評価根拠 / C-2 R-102）
    - **`schemas/c3-approval.schema.json` の `patternProperties."^_"` に型制約が無い**一方、**`schemas/c3-prime.schema.json` は `"type": "string"` を持つ**こと（D-4(a) の限定表現の根拠 / C-2 R-104）
    - **追跡下の `docs/working/*/approvals/c3.json` の総数と `plan_hash` 欠落件数**（C-2 反映時の実測: **80 件中 1 件**（`TASK-0038`）。D-6 の後方互換影響の定量根拠 / C-2 R-002・R-106）
    - **`.github/workflows/metrics-privacy.yml` の trigger paths に `**/*.json` / `**/*.ndjson` が含まれる**こと + `scripts/hooks/check-metrics-privacy.sh` の `FORBIDDEN_KEYS` 一覧（sidecar の field set 設計の事前制約 / C-2 R-108・R-109）
  - 行番号ドリフトがあれば **ADR 側の付表で是正**する（`pbi-input.md` は改変しない — plan Constraint 6）
  - 🚩 **チェックポイント**: 12 項目 + 10 条件のすべてに**関数名または記号アンカー**が併記され、**行番号のみに依拠する根拠が 0 件**
  - Owner: agent / `rollback:` 不要（読み取りのみ）

### 実装フェーズ

- [ ] **T-02**: ADR を新規作成し、誤読防止の冒頭 1 文を置く（plan Step 2 / U-1）
  - 作成先: `docs/decisions/adr-002-plan-contract-canonical-source.md`
  - 命名は既存慣行 `docs/decisions/adr-NNN-<slug>.md` に従う（実在は `adr-001-approve-out-of-band.md` の 1 件のみ）
  - 節構成は ADR-001 に揃える: `Status` / `Date` / `PBI` / `Decision Makers` → `Context` → `Problem Statement` → `Decision Drivers` → `Considered Options` → `Decision` → `Consequences` → `Related`
  - **本文最初の段落に必須の 1 文**: 「Plan Contract は既存の Plan Package + c3-prime 契約の別名であり、新しい artifact ではない」
  - ADR とする理由（RFC ではない）を記録: `docs/rfc/` は新規サブシステム / provider の**提案**の系統、本件は**既存資産の正本配置を確定する決定記録**
  - **`Status` は `Accepted`** とする（PR1 で確定済みであることを示す。ADR-001 の `Proposed` を踏襲しない — C-2 R-114）
  - **`Related` 節に採番予約**を書く: 「本 ADR が `adr-002` を占有する。#980 は `adr-003` 以降を使う」（C-2 R-107。`docs/working/TASK-0980/pbi-input.md:355` U-1 が突き合わせを要求）
  - **ai-loop 非適用の 1 行**を入れる: 「本 run は legacy（人間 C-3）経路であり ai-loop の LoopSpec 派生対象ではない」（C-2 R-111。`plan_package.py` の `derive_loopspec()` は `Verification Automation:` 行を要求し無ければ fail-closed）
  - 🚩 **チェックポイント**: 冒頭 1 文が本文の**最初の段落**に存在（TC-02）+ ADR-001 と同じ節見出しが揃う（TC-01）+ `Status` = `Accepted` + `Related` に採番予約がある
  - Owner: agent / `rollback:` `git rm docs/decisions/adr-002-plan-contract-canonical-source.md`

- [ ] **T-03**: 要件対応表を ADR に確定（plan Step 3 / AC-1）
  - 表①: ギャップ 12 項目 × 判定（既存で満たす / 一部満たす / 未対応）× 根拠（file:line + 関数名アンカー）× **PR 割当**
  - 表②: #981 全体 AC 14 項目 × PR1 で扱う範囲。**14 行すべてを書き、各行の「PR1 で扱う範囲」列を非空にする**（行を落とさない — C-2 R-001）
  - ⚠️ **転記元の行数差に注意**（簡易 C-1 R-3）: `pbi-input.md` の同名テーブルは issue 第 1 項（1 つの Run に複数 ActorSession）と第 2 項（Planner と Executor が異なる Principal でも継続）を **1 行に統合しており 13 行**。素直に転記すると 13 行になり TC-26 (2) が FAIL する。**issue 実測の 14 が正**なので、この 2 項を分割して表②は 14 行で作る（TC-26 を 13 に下げない）
  - 「既存で満たす」5 項目（#1 / #2 / #3 / #4 / #6）の **PR 割当欄はすべて「なし（再実装しない）」**
  - 「一部満たす」3 項目（#5 / #7 / #11）は**満たす側と満たさない側を分離**して書き、満たさない側に PR2 / PR3 を割り当てる
  - **「未対応」3 項目（#8 / #9 / #10）の PR 割当欄を全件非空にする**（欠落の抑制 — C-2 R-010）
  - 🚩 **チェックポイント**: TC-04 / TC-05 / TC-06 / **TC-26** が PASS（根拠アンカー全行 / 既存充足への割当 0 件 / 分離記載 / 未対応 3 項目の割当全件 / 表② 14 行全存在）
  - Owner: agent / `rollback:` `git checkout -- docs/decisions/adr-002-plan-contract-canonical-source.md`

> **T-04 は 3 分割**（C-1 C1-TODO-08 是正）。3 タスクは plan Step 4 に対応し、成果物はいずれも同一 ADR ファイル内の別セクション。共通の `rollback:` は `git checkout -- docs/decisions/adr-002-plan-contract-canonical-source.md`。

- [ ] **T-04a**: 配置表を ADR に作成（D-1 / D-3 / **AC-2**）
  - **D-1**: Plan Contract の契約正本 = `docs/workflows/ai-loop/c3-prime-contract.md`（単一）。新規契約ファイルを作らない
  - **D-3**: execution reference の物理的な置き場 = sidecar `docs/working/TASK-XXXX/execution/plan-contract.json`。`approvals/c3.json` へ execution 情報を追加しない（承認 record は**承認時点の不変スナップショット**。`bin/plangate` の approve は `--force` なしの上書きを block する。**1 承認 : N 実行**を 1 ファイルで表現できない）
  - 成果物: 「配置表」（情報 × 唯一の正本 × 他の場所での扱い。最低 6 行）
  - 🚩 **チェックポイント**: 配置表の**全行 3 列が非空**（空欄・`—` のみ・「検討中」が 0 件）。TC-07 が PASS
  - Owner: agent / `rollback:` 上記共通

- [ ] **T-04b**: **5 経路比較表**を ADR に作成（D-4 / **AC-3** / C-2 R-006・R-102 で 3 → 5 経路へ拡張）
  - **D-4**: schema 機構は (c) sidecar + 新規 `schemas/plan-contract.schema.json`（PR2 で **HO patch 提示 → Human 適用**）を採用。(b) `run-event.schema.json` の既存未使用プロパティ（`plan_hash` / `agent` / `by`）を PR2 の最小差分として**併用**。(a) `^_` 注釈キーは D-2 の将来拡張枠としてのみ残す。**(d) 既存 `schemas/c3-prime.schema.json` へ型付き additive** と **(e) `docs/schemas/` 配置 → 後日 `git mv` で昇格** は**不採用**（理由は plan の 5 経路比較表を参照）
  - 成果物: 「5 経路比較表」（(a)/(b)/(c)/(d)/(e) × HO 接触 / 構造表現力 / CI enforcement / 承認 record の不変性）
  - **(c) の CI enforcement の限界を明記**する: `scripts/schema_mapping.py` への 1 行登録が唯一の強制点で、忘れると `validate-schemas.py` が `SKIP` を返し**沈黙 PASS** する（C-2 R-103）。PR2 申し送り事項に含める
  - **sidecar の field set 事前制約**を PR2 申し送りに含める: EH-8 privacy CI（`**/*.json`）が `file_path` / `absolute_path` / `stdout` 等を**キー名として**検出して BLOCK する（C-2 R-108）
  - 🚩 **チェックポイント**: **5 経路 × 4 軸 = 20 セルすべてが非空**で、採用 / 併用 / 将来枠 / 不採用の判定が明示されている。TC-09 / TC-10 が PASS
  - Owner: agent / `rollback:` 上記共通

- [ ] **T-04c**: Decision 節に正本の断定文を書く（**AC-2 / PR1 のブロッキング条件**）
  - Plan Contract の契約正本を **1 パスのみ**（`docs/workflows/ai-loop/c3-prime-contract.md`）として断定する。複数パスを「正本」と呼ばない
  - 「同一情報のコピーが 2 箇所以上に存在しない」旨の宣言と、その根拠（配置表の「他の場所での扱い」列がすべて「参照のみ / 書かない」であること）を書く
  - 代替案（②・③）は Considered Options 節に**不採用**として置く（Decision 節に両論併記しない）
  - 🚩 **チェックポイント（PR1 のブロッキング条件）**: TC-08 が PASS。かつ **ADR の `Decision` 節**に `TBD` / `TODO` / `検討中` / `後で決める` / `必要に応じて` が **0 件**（TC-03 の前倒し確認）
  - ⚠️ **禁止語の検査範囲は `Decision` 節に限る**（C-2 R-008）。T-09 の PR2 / PR3 スコープ表は未決事項を明示するのが目的であり、ADR 全体を対象にすると T-04c と T-09 が同一ファイル上で衝突する
  - **この 🚩 が通るまで T-05 以降へ進まない**
  - Owner: agent / `rollback:` 上記共通

- [ ] **T-05**: `plan_version` と hash の役割を ADR に確定（plan Step 5 / D-2 / AC-4）
  - 「実行同一性の正本 = `plan_hash`（`plan.md` 単体）+ `plan_package_hash`（6 要素の正規化集合）」
  - 「`plan_version` は**新設しない**」「将来 `plan_revision` を導入する場合の**唯一の許容形式**は `^_plan_revision`（string・注釈キー）で、受理器の判定分岐に使わない」
  - T-01 で実測した `grep` 結果（**0 件**）を根拠として掲載
  - 🚩 **チェックポイント**: 「番号だけで実行許可を判定する経路が設計上存在しない」ことが grep 実測付きで示されている（TC-11 / TC-12）
  - Owner: agent / `rollback:` `git checkout -- docs/decisions/adr-002-plan-contract-canonical-source.md`

- [ ] **T-06**: #980 との責務境界を ADR に記録（plan Step 6 / D-5 / AC-5）
  - 「#981 が担当するもの / #980 が担当するもの」の分界表（issue コメント §1 に 1:1 対応）
  - 「**PR1〜PR3 の ActorSession ID は非検証の opaque string** であり、主体の真正性は #980 まで保証されない」を明記
  - 「PR2 で追加する record の説明文にも同旨を残す」ことを ADR の決定事項として書く（PR2 への申し送り）
  - **`run-event.schema.json` の `agent` / `by` の語彙定義と writer 所有権を確定する**（C-2 R-003 / 新規。`docs/working/TASK-0980/pbi-input.md:181` が「#981 PR1 の ADR で先に確定する」と明示委譲している論点）
    - (i) `agent` の語彙（現行 `bin/plangate:2037` の `PLANGATE_IMPL_AGENT` 由来のツール種別文字列を継続するか、Executor 主体識別子へ意味を移すか）
    - (ii) `by` の語彙（gate イベントの Human / Agent 識別子）
    - (iii) writer 所有権（`plangate_append_ndjson` の 3 呼び出し `bin/plangate:1279` / `:2005` / `:2112` のどれが何を書くか）
    - 分界表に「**#980 は `agent` / `by` / `plan_hash` に独自語彙を割り当てない**」の 1 行を入れる（#980 の AC-P2(b) が本 ADR を参照して検査する）
    - 根拠として `schemas/run-event.schema.json:77` が `additionalProperties: false` かつ `^_` の patternProperties も無く、**1 フィールドに 2 語彙が入ると是正が HO patch になる**ことを書く
  - 🚩 **チェックポイント**（C-1 C1-TODO-10 是正 / plan Step 6 と対称化）: ADR 本文に**「非検証」の語が存在**し、分界表が issue コメント §1 の項目を漏れなく含み、**PR2 への申し送りが決定事項として明記**されていること。**加えて `agent` / `by` の語彙定義と writer 所有権が明記され、「#980 は独自語彙を割り当てない」が分界表にあること**。TC-22 が PASS
  - Owner: agent / `rollback:` `git checkout -- docs/decisions/adr-002-plan-contract-canonical-source.md`

- [ ] **T-07**: 現状維持 / 補強の 4 判断を ADR に記録（plan Step 7 / D-6・D-7・D-8・D-9）
  - **D-6（legacy 経路 / ギャップ #5）**: PR2 で `bin/plangate` の legacy 経路にある「**`plan_hash` が記録されていないから** hash 突合を無言 skip する」という **fail-open 1 点のみ**を BLOCK 化する patch を提示（`bin/plangate` は HO → **AI は patch 提示まで**）。evidence marker 再検証・`artifact_hashes` 照合の全面移植は**行わない**
    - ⚠️ **記述の向きに注意**（C-2 R-002）: 塞ぐのは「記録が**無い**から照合しない」経路。「記録があるのに照合しない」ではない（記録がある場合は `bin/plangate:2098` で既に mismatch 判定される）
    - **後方互換の定量根拠を ADR に載せる**: 追跡下の `docs/working/*/approvals/c3.json` **80 件中、`plan_hash` 欠落は 1 件のみ**（`TASK-0038`）。② の全面強化はほぼ全件を invalid 化するのに対し ③ は 1/80 に留まる（T-01 で再実測する）
    - **穴の大きさは層で書く**（C-2 R-106）: `plangate approve` は必ず `plan_hash` を書き（`:2408`）、`c3-approval.schema.json` は `required` に含め、CI も検証する。実際の fail-open 窓は「CLI 非経由の手書き かつ schema 違反」に限定 = **多層防御の最後の 1 層が抜けている**
  - **D-7（EC-1 / U-6）**: 受理側にも非空検査を**追加する**（PR2。`scripts/ai-loop/c3prime_verify.py` は HO 対象外）。ADR に「受理側 presence の現在の意味範囲 = artifact が record と byte 同一であること。**非空であることではない**」を明記
  - **D-8（EC-10 / U-3）**: `prohibited_actions` / `stop_conditions` の宣言フィールドを**新設しない**（実装 allowlist が正）。理由 = 宣言を足すと「宣言と実装のどちらが正か」という新しい二重正本が生まれる。`gh_exec.py` が自認する「別プロセスからの `gh pr merge` は塞げない」ギャップは宣言を足しても閉じないことも併記
  - **D-9（U-8）**: evidence stale の束縛先は `plan.md` 単体を**維持**。`plan_package_hash` への拡張は**循環依存で原理的に不可能**（`ARTIFACTS` が `review-self.md` / `review-external.md` を含むため、C-1 marker に `plan_package_hash` を書くと自己参照になる）。3 要素部分集合（`plan.md` / `todo.md` / `test-cases.md`）による束縛は **PR3 の revision 契約の候補**として残す
  - 🚩 **チェックポイント**: D-9 の循環依存が `c3_contract.py` の `ARTIFACTS` を根拠に明記され「妥協ではなく構造的帰結」と読める（TC-14）+ D-6 の変更範囲が 1 箇所に限定され後方互換根拠が書かれている（TC-13）
  - Owner: agent / `rollback:` `git checkout -- docs/decisions/adr-002-plan-contract-canonical-source.md`

- [ ] **T-08**: `c3-prime-contract.md` §8 に但し書きを 1 文追記（plan Step 8 / D-10 / S-9）
  - 追記趣旨: 「additive な任意フィールド追加が本ファイルの改版のみで足りるのは `^_` 注釈キーの場合であり、素の record フィールドを追加する場合は `RECORD_OPTIONAL_KEYS`（`scripts/ai-loop/c3_contract.py`）と `schemas/c3-prime.schema.json` の同時更新を要する（後者は Hardening Override 対象）」
  - ⚠️ **既存 §8 の本文を削除・書き換えしない（追記のみ）**。特に破壊的変更の手続き（「#872 / #873 / #874 の 3 issue 合意 + plan Replan を要する」）には触れない
  - ⚠️ `docs/workflows/ai-loop/**` は rollout-policy §2 判定基盤 carve-out → **escalate 固定**（規範層。`arbiter.py` の `boundary_check` は `boundary=clean` と機械判定するため実行者が escalate 責務を負う）。本 run は Mode=high-risk で同期 Human C-3 が既に必須のため追加の承認コストは発生しない
  - 🚩 **チェックポイント**: `git diff docs/workflows/ai-loop/c3-prime-contract.md` が**追加行のみ**（削除行 0）であること（TC-21）
  - Owner: agent / `rollback:` `git checkout -- docs/workflows/ai-loop/c3-prime-contract.md`

- [ ] **T-09**: PR2 / PR3 のスコープ表を ADR に反映（plan Step 7 の後段）
  - D-6（legacy fail-open の 1 点）/ D-7（受理側 presence 補強）を PR2 スコープへ追加
  - **U-4（`ExecutionRequested` / `ExecutionStarted` の粒度）は PR1 で骨格のみ確定**（C-2 R-005）: ADR に「**record 数**（1 or 2）と**必須トップレベルキーの有無**」を明記し、フィールド詳細（timestamp 粒度・任意フィールド）のみを PR2 の未決事項として送る。理由 = PR2 で sidecar schema（HO）を Human 適用したあとに record 数が変わると **2 回目の HO patch 適用**が発生するため
  - U-7（maker・checker の field set）を PR2 の未決事項として明示
  - U-5（`plangate resume`）/ D-9 の 3 要素部分集合案を PR3 候補として明示
  - issue コメント §8 の順序制約（PR1 → PR2 → PR3 → #980 Phase 0〜2 → PR4）を記載し、「PR1 の ADR で正本が決まるまで PR2 に着手しない」を明記
  - 🚩 **チェックポイント**（C-1 C1-TODO-10 是正 / plan Step 7 の後段 🚩 に対応）: スコープ表に **PR1 → PR2 → PR3 → #980 Phase 0〜2 → PR4 の順序制約**が記載され、**U-4（骨格 = PR1 / 詳細 = PR2）/ U-5 / U-7 の送り先が全件明示**（1 件も未記載でない）であること。**加えて U-4 の骨格が確定値として書かれている**（sidecar の record 数 = 1 or 2 / 必須トップレベルキーの有無。「PR2 で決める」「検討中」は不可 — AC-3 / TC-09 で検査 / 簡易 C-1 R-2）
  - Owner: agent / `rollback:` `git checkout -- docs/decisions/adr-002-plan-contract-canonical-source.md`

### 検証フェーズ

- [ ] **T-10**: 非退行確認（plan Step 9 / AC-6）
  - `git diff origin/main --name-only` → **コード配下（`schemas/` / `bin/` / `scripts/` / `tests/` / `.claude/` / `.github/`）が 0 件**、かつ全変更が plan「Files / Components to Touch」A + B の集合に収まる
  - ⚠️ **`.md` 限定・ファイル数固定では判定しない**（C-1 F-2 是正）。H-01 で発行される `approvals/c3.json` と `decision-log.jsonl` は `.md` ではないが**正規の承認フロー成果物**であり、これらの出現を停止条件にしてはならない
  - `git diff origin/main --stat` を `status.md` に記録
  - `sh tests/run-tests.sh` → **`failed == 0`** かつ `passed` が **T-01 でその場取得した baseline と同一**（**絶対値をハードコードしない** — test-cases TC-16 注記を参照。参考値: 基点 `73e6a15` = 524 passed / 0 failed）
  - `ls scripts/ai-loop/test_*.py` で列挙した**全件**を `python3 <path>` で個別実行し**各 exit 0**（**件数をハードコードせず全件をループする**。参考値: `73e6a15` で 15 本 = 旧 13 本 + `test_run_evidence.py` / `test_run_evidence_verify.py`）
  - `bin/plangate validate TASK-0981` → **`Result: PASS`（FAIL 0 件）**。H-01 で c3.json が発行済みのため C-3 Gate も PASS する（C-1 F-2 是正: 旧記述「FAIL は c3.json not found のみ」は H-01 → T-10 の依存順と両立しなかった）
  - `npx --no-install markdownlint-cli2 "docs/decisions/*.md" "docs/working/TASK-0981/*.md" "docs/workflows/ai-loop/c3-prime-contract.md"` → **0 issues**
  - 新規・変更 `.md` 内の相対リンクをすべて抽出し `test -f` で到達確認 → **未到達 0 件**
  - 実行ログを `evidence/verification/` に保存
  - 🚩 **チェックポイント**: 上記 7 項目すべて期待どおり。1 つでも外れたら Stop Condition / Replan Trigger に従う
  - Owner: agent / `rollback:` 不要（検証のみ）

### 完了フェーズ

- [ ] **T-11**: handoff を発行し PR2 の Human 適用タスクを BLOCKED として先出しする（plan Step 9 後段 / WF-05）
  - `docs/working/TASK-0981/handoff.md` を [`templates/handoff.md`](../templates/handoff.md) に従って作成（必須 6 要素）
  - **BLOCKED として先出しする Human-owned タスク**（`blocker` / `owner` / `unblock_condition` の 3 フィールド必須）:
    - `schemas/plan-contract.schema.json` の新設（HO 対象。owner=human。unblock = PR2 の patch 提示後に Human が適用）
    - `bin/plangate` legacy 経路の fail-open BLOCK 化（HO 対象。owner=human。unblock = 同上）
  - **V2 候補 / 妥協点**として記録: U-4 / U-5 / U-7 の PR2・PR3 送り理由、D-9 の 3 要素部分集合案、`run.ndjson` に CI 強制が無いこと
  - `status.md` にフェーズ履歴を `YYYY-MM-DD HH:mm`（分まで）で記録
  - 🚩 **チェックポイント**: handoff 必須 6 要素が揃い、BLOCKED タスクに 3 フィールドがすべて埋まっていること
  - Owner: agent / `rollback:` `git rm docs/working/TASK-0981/handoff.md`

---

## 👤 Human タスク

- [ ] **H-01（C-3 ゲート・T-01 の前）**: 計画承認
  - **high-risk のため必須**（autonomous APPROVE 不可 / mode-classification）。rollout-policy §2 carve-out により **escalate 固定 = 同期**
  - 確認対象: `plan.md`（特に D-1〜D-10 の決定）/ `todo.md` / `test-cases.md` / `review-self.md` / `review-external.md`
  - 三値判断: APPROVE → exec 開始 / CONDITIONAL → `review-external.md` に `R-NNN` 集約 → 1 回確定反映 → 簡易 C-1 → APPROVED な `c3.json` 発行 / REJECT → plan 再生成
  - 発行: `bin/plangate approve TASK-0981`（`c3_status=APPROVED` + 確定後 `plan.md` の `plan_hash`）
  - ⚠️ **c3.json 発行は確定反映の後**（先に発行すると EH-3 が後続反映を mismatch 検知する）

- [ ] **H-02（C-4 ゲート・PR 作成後）**: PR レビューとマージ
  - GitHub 上で三値判断（APPROVE / REQUEST CHANGES / REJECT）
  - **マージは Human-owned 固定**（`NO MERGE BY AI`）。AI は MERGE_READY まで

---

## 完了条件

- [ ] T-01〜T-11（**T-04 は T-04a / T-04b / T-04c の 3 分割** = 計 13 タスク）のすべてが完了し、各 🚩 チェックポイントが PASS
- [ ] `test-cases.md` の TC-01〜**TC-26** がすべて PASS（V-1 受け入れ検査。TC-26 は C-2 R-001 で新設）
- [ ] AC-1〜AC-6 がすべて充足（handoff の要件適合確認結果に PASS / FAIL / WARN で記載）
- [ ] `git diff origin/main --name-only` に **コード配下（`schemas/` / `bin/` / `scripts/` / `tests/` / `.claude/` / `.github/`）が 0 件**で、全変更が plan「Files / Components to Touch」A + B の集合に収まる（変更対象 A = 9 ファイル + workflow 標準 artifact B）
- [ ] `pbi-input.md` が**変更されていない**（`git diff origin/main -- docs/working/TASK-0981/pbi-input.md` が空）
