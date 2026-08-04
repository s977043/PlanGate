# HANDOFF — TASK-0874（RunEvidence 契約 / issue #874）

> **Status**: exec 完了（T-1 〜 T-41）。**残るは T-42 〜 T-44（issue コメント / #870 反映 / 予約起票）と C-4** で、
> いずれも統合担当・Human の担当。
> **発行時点**: branch `feat/task-0874-exec`・**コード側 HEAD = `52bd791`**（R2 指摘 MJ-3 / MJ-5 反映 commit）。
> 本 handoff の記載はこの SHA の実測に基づく。以降 commit が積まれた場合は再測定すること。
> ⚠️ **T-38 / T-39（敵対レビュー R1 / R2）のチェックは todo 上で未了のまま**である。レビュー自体は実施され
> R2 の major 5 / minor 4 は本ブランチに反映済みだが、**レポート artifact が `docs/working/TASK-0874/evidence/` に
> 未配置**のため完了判定（「レポートが evidence/ に存在」）を満たしていない（K-2）。

## 1. 要件適合確認結果（AC ごと）

| AC | 内容 | 判定 | 根拠 |
|----|------|------|------|
| AC-1 | RunEvidence schema と versioning policy | **PASS** | `docs/schemas/run-evidence.schema.json`（draft 2020-12・`required` 21）+ 契約 §9。TC-01 〜 TC-05 / TC-61 / TC-62 |
| AC-2 | 同一入力から同一 EV を再生成できる | **PASS（R1 M-1 是正後に再測定）** | TC-10 / TC-11 / TC-12 / TC-60。fixture 10 件の byte 一致（TC-48）。⚠️ **R1 で一度破れていた**: `scan_input_privacy` が `runs_dir` を全件走査していたため、無関係な run の record が `owner` / `login` 等を 1 つ持つだけで `escalation` が伸び byte が変わった（実測再現）。走査を当該 `run_id` に絞って是正し、`test_adding_an_account_bearing_record_does_not_change_the_output` で成長耐性を実証（変異注入で kill 確認済み） |
| AC-3 | plan hash / C-3' / head SHA / CI / review / routing / terminal state の結合 | **PASS（routing はキー存在と run 束縛のみ・値の結合は #868 実装後）** | TC-13 〜 TC-16 / TC-50 / TC-57 〜 TC-59 / TC-64。⚠️ TC-50 は `routing_decisions == "unavailable"` と同一 `EV` 内の run 束縛までで、**routing の値が同一 run に結合されることは Phase 1 では検証していない**（供給元 #868 が OPEN）。→ K-3 |
| AC-4 | missing / partial / tampered を ready 扱いしない | **PASS（R1 C-1 / M-3 / M-5 / m-1 是正後に再測定）** | 受理器 exit 0/1/2/10/11。TC-06 〜 TC-09 / TC-32 / TC-52 / TC-53 / TC-56 + `RederivationTests` / `SchemaStructuralValidationTests` / `NestedUnavailableTests`。⚠️ **R1 で 4 クラスの改竄が exit 0 で通っていた**: (1) `terminal_state` を一切検証していなかった（`WAITING_FOR_CHECKS` が complete で通過）/ (2) `ci_outcomes` / `review_findings` / `quality_metrics` を再導出していなかった / (3) schema の `type` / `enum` / `pattern` / `minLength` がどの層からも強制されていなかった / (4) `unavailable` の走査が深さ 1 の dict までで入れ子を見逃した。いずれも受理器が再導出 + subset validator で強制するよう是正（変異注入で個別に kill 確認済み） |
| AC-5 | observation と cause_hypothesis の分離 | **PASS** | TC-17 / TC-18（producer は推定を自動生成しない） |
| AC-6 | hidden CoT / raw transcript / secret を要求も保存もしない | **PASS（R1 C-2 是正後に再測定）** | TC-19 〜 TC-21 / TC-51 / TC-63 / TC-65 + EH-8 実走（TC-22）+ `test_output_privacy_backstop_is_wired_into_build` / `VerifierPrivacyBackstopTests`。⚠️ **R1 で 2 点が破れていた**: (1) 出力側 backstop の test が**関数の検出力しか固定しておらず配線を 1 行も守っていなかった**（`build()` の call site を削除しても全 test が緑 = 空振り fixture と同型）→ `unittest.mock.patch` で end-to-end 配線を固定し、**実際に call site を削除して FAIL することを確認**（`mutate2.log`）/ (2) 受理器に backstop が無く、producer を通さない EV（owner 付き `repository` / 絶対パス `evidence_refs` / `escalation[].detail` / `@handle` 入り `observation`）が**いずれも exit 0** で通過 → `check_output_privacy()` を受理器から import して同一検査を実施 |
| AC-7 | #869 が RunEvidence のみから candidate を生成できる | **PASS（契約層のみ）** | TC-23 / TC-24 / TC-33。**実フロー検証は #869 実装後** |
| AC-8 | candidate が source_run_ids と baseline version を保持 | **PASS** | TC-25 / TC-26 |
| AC-9 | improvement TASK が通常ゲートを通る | **PASS（記述子レベル）** | TC-27。実フローは #869 実装後 |
| AC-10 | paired replay / grader / activation check / rollback | **PASS（キー存在レベル）** | TC-34 / TC-35。独立 grader も activation check も本 PBI では実装しない |
| AC-11 | promotion decision と改善 PR/commit の追跡 | **PASS** | TC-28 / TC-29（PR 番号 + commit SHA へ還元し双方向に辿れる） |
| AC-12 | active run 中に harness version が変化しない | **PASS** | TC-30 / TC-31（3 値すべての drift で fail-closed）+ **未検査（`--harness-version-end` 未注入）を `escalation.harness_drift_unchecked` に記録し受理器が partial 理由に列挙**（契約 §4-1・R2 MJ-3 反映。追加 4 テスト） |
| AC-13 | 未解決の正本へ自動 promotion しない fail-closed | **PASS（R1 C-3 是正後に再測定）** | TC-36 / TC-37 / TC-55（キー未注入も BLOCKED）+ `test_falsy_non_list_blocked_by_is_blocked`。⚠️ **R1 で破れていた**: 判定が `"blocked_by" not in candidate or bool(blocked_by)` だったため **`null` / `""` / `0` / `{}` が非 BLOCKED に倒れ**、`decision=PROMOTED` と `blocked_by='unavailable'`（取得不能）を**同時に主張する**出力が出ていた（実測再現。`null` は JSON 往復で最も出やすい値）。`isinstance(x, list)` へ是正し 8 値を parametrized で固定 |
| AC-14 | c3-prime-contract §7 追記 + §4 全規則の再検証 | **PASS** | TC-38 〜 TC-41。§7 以外の節が不変であることを機械照合 |
| AC-15 | legacy record の migration / compatibility | **PASS** | TC-42 〜 TC-45 / TC-54（実データ〔T-2 時点 28 件〕で `metrics.py` と同値。**件数の絶対値は assert しない** — corpus 成長で無関係な PR の CI が赤くなるため / R2 MJ-5） |
| AC-16 | 10 fixture が ta-60 で CI 実行され対応表が残る | **PASS** | TC-46 〜 TC-49 + 下記 §5 の対応表 |

> ⚠️ **本 PBI の完了は issue #874 の close 条件充足を意味しない**。#874 の DoD は
> 「#869 shadow mode の統合 test」「#811 promotion provenance test」「効果測定」を要求しており、
> いずれも未実装。**#874 は OPEN のまま残す**（T-42 のコメント文面要件）。

## 1-bis. Phase 1 の既定と「見直し前提」（**下流 PBI は確定契約と読まないこと**）

> 契約正本 [`run-evidence-contract.md` §0](../../workflows/ai-loop/run-evidence-contract.md) の転記。
> **本 PBI は Phase 1 = 契約層のみ**であり、以下は「今の既定」であって確定契約ではない。
> handoff だけを読んで `blocked_by[]` の fail-closed や adapter 最小 2 フィールドを
> **踏襲すべき確定仕様と誤認しない**こと（見直しは契約 §9 versioning policy の手続きに従う）。

| ID | Phase 1 の既定 | 見直しの契機 |
|----|--------------|------------|
| U-4 | **非終端 run は `EV` を発行しない**（4 値目 `IN_PROGRESS` を作らない） | #869 が「失敗パターンも学習源」として非終端 run を要求した場合 |
| U-8 | adapter IF は `source_run_ids` + `baseline_version` の**最小 2 フィールドから開始**し、それ以外は下流が埋める | #869 が候補契約フィールドを確定した時点 |
| U-9 | fixture 9 / 10（paired replay / canary rollback）は **#874 の最小定義**。`routing_decisions[]` の item schema は**定義しない** | #869 / #811 / #868 が別定義を採った場合は**追従する** |
| U-10 | **Phase 1 の producer 出力は全件 `partial`**（known-unavailable allowlist を置かない） | 下流が「`complete` な run のみ学習・promotion 対象」を採り、Phase 1 の全 run が使えないと判明した場合 |
| U-12 | `blocked_by[]` は **fail-closed**（キー欠落 = 判定不能 → `BLOCKED`。明示 `[]` のときのみ非 `BLOCKED`） | #811 が `blocked_by[]` の供給元を確定した時点 |

> **本 PBI の完了は issue #874 の close 条件充足を意味しない**。#874 の DoD は「#869 統合 test」
> 「#811 promotion provenance test」「効果測定」を要求しており、いずれも本契約の下流にある。
> **#874 は本 PBI 完了後も OPEN のまま残す**。

## 2. 既知課題一覧

| # | 課題 | 影響 | 対応 |
|---|------|------|------|
| K-1 | ~~T-37（plugin 同期）が未実施~~ → **完了**（`9ffe144` で統合担当が実施。R2 反映で producer / 契約 doc を変更したため**本ワーカーが再度 sync を実行**し `plugin/` を更新済み） | — | 解消済み。以降 `scripts/ai-loop/*.py` と `docs/workflows/ai-loop/*.md` を変更したら必ず sync を再実行する |
| K-2 | 敵対レビュー R1 / R2 は**実施済み**（R2 の major 5 / minor 4 を本ブランチに反映）だが、**レポート artifact が `evidence/` に未配置** | T-38 / T-39 の完了判定（レポートの存在）を満たせず todo が閉じられない | 統合担当が R1 / R2 レポートを `docs/working/TASK-0874/evidence/c2-review/` 相当へ格納し T-38 / T-39 を閉じる |
| K-3 | fixture 6（routing escalation）の `routing_decisions` は fixture 4 と同じ `"unavailable"` | **routing の値カバレッジが 0**（AC-3 の routing 部分は Phase 1 では未検証） | #868 実装後に item schema を注入して差分を作る。⚠️ 旧記載「fixture 4 と**区別不能**（実質 9 fixture）」は**誤り**（R2 MN-1・実測で反証）: 両 golden は `escalation` / `human_interventions` / `observation` / `run_id` が異なり、fixture 6 は `kind=notice` 入力の escalation 経路を実際にカバーしている。**fixture 数を割り引く必要はない** |
| K-4 | golden fixture は `test_plan_package.py` の sandbox 生成物に依存 | 同ファイルの `PLAN_BODY` を変えると 10 件すべてが byte 不一致になる | `regenerate_fixtures()` で再生成し commit（TC-48 が検出する） |
| K-5 | `--pr-number` は cross-check 専用に降格 | plan の記述（PR 番号の解決経路）と食い違う | 契約 §3-2 に確定として明記済み。受理器の再計算可能性が制約 |
| K-6 | `tests/fixtures/` は privacy CI の scan 対象外 | golden fixture の privacy 回帰を CI が自動検出しない | `ta-60` ④ で EH-8 を実走させて代替（本 PBI で解消済み） |
| K-7 | `sh tests/run-tests.sh` は `ta-54` 経由で**実 repo root に対し sync を実行する** | テスト実行が `plugin/` を一時的に書き換える | 本 PBI の範囲外。テスト実行後は `git status` で `plugin/` を確認すること |
| K-8 | `jsonschema` 依存の fixture 検証 1 件は未導入環境で skip する | CI で skip される可能性 | 65 TC には含まれない追加検証。必要なら CI に依存を追加 |
| K-9 | **TC-46 / TC-49 に機械 assert が無い**（65 TC 中 2 件） | 「65 TC 全件機械実行」と報告すると虚偽になる | **手動確認**として §5-bis に実行コマンドと実測結果を記録した。機械化は見送り（TC-49 は `git diff origin/main` 依存で、shallow clone の CI では `origin/main` が無く**新たな CI 時限爆弾**になるため — R2 MJ-5 と同じ失敗クラス） |
| K-10 | `tests/extras/ta-60-run-evidence.sh` の**失敗経路**が `set -eu` 下で harness ごと落ちていた（`"…（exit $_t60_rc）"` が全角括弧を変数名に取り込み unbound variable になる） | テストが 1 件でも FAIL すると **`tests/run-tests.sh` 全体が中断**し、原因が「unbound variable」としか出ない | 本ワーカーが `${_t60_rc}` へ brace 化して修正（4 箇所）。`PLANGATE_PYTHON=false` で全失敗経路を実走させ `exit 1` が正しく出ることを確認済み |
| K-11 | 同型の `$var` + 全角文字パターンが `scripts/apply-ui-v1-crossref.sh` / `scripts/check-git-destructive.sh` に各 1 件残存 | 当該スクリプトが `set -u` 下で失敗経路に入った場合に同じ事故が起きうる | **本 PBI の scope 外**（報告のみ）。別 PBI で横断是正する |
| K-12 | **`schema-validate.yml` が `docs/schemas/**` を trigger paths に含まない**（R1 M-5 の②）。`run-evidence.schema.json` 自体の JSON Schema 妥当性は CI で検証されない | schema 側の記述ミス（無効な `$ref`・typo した keyword 等）を CI が検出しない。**受理器の subset validator は「解釈できないキーワードを fail-closed」にするため EV 側は守られる**が、schema の自己健全性は守られない | **別 PBI で対応**（`.github/workflows/*.yml` は Hardening Override 対象 = Human-owned のため AI が編集できない）。①`docs/schemas/**/*.json` を trigger paths に追加、または ② `schemas/` 昇格（V2 候補・T-44 の予約起票）で自動解消する。**②で解消するなら K-12 は独立起票不要**。契約 §10-3 に 3 層の状態表を記載済み |
| K-13 | 受理器の schema 強制は **本 repo が実際に使う JSON Schema subset のみ**（`type` / `enum` / `const` / `pattern` / `minLength` / `minimum` / `required` / `properties` / `additionalProperties` / `patternProperties` / `items` / `anyOf` / 局所 `$ref`） | schema に未対応キーワード（`oneOf` / `allOf` / `multipleOf` / `dependentRequired` 等）を足すと受理器が **fail-closed で全 EV を reject** する | 意図的な設計（黙って無視すると「検査した」と「検査できていない」が区別できない）。schema を拡張するときは受理器の `_SUPPORTED_KEYWORDS` を同時に更新する。`test_unsupported_schema_keyword_is_fail_closed` が挙動を固定している |

## 3. V2 候補（今回の scope 外）

- `harness_version` の**構造**を検証する TC（現状は注入値の byte 一致のみ・U-1 の帰結）
- `cost_metrics` の収集経路（`events.ndjson` が gitignore のため Phase 1 では取得不能）
- `replan_count` の供給元（main に存在しない）
- `routing_decisions[]` の item schema（#868 実装後）
- schema / fixture の plugin 配布（U-7 で Phase 1 は配布しない）
- U-10 が known-unavailable allowlist 採用に転じた場合の fixture 期待 exit の差し戻し（11 → 0）
- `docs/schemas/run-evidence.schema.json` → `schemas/` への昇格（HO patch・T-44 で予約起票）
- **TC-46 / TC-49 の機械化**（`origin/main` に依存しない形での代替検証。K-9）
- `escalation` の「検査未実行」kind の拡張（現状 `harness_drift_unchecked` の 1 種のみ。他の検査も未実行を残す形へ揃えるか）
- `$var` + 全角文字の unbound variable パターンの横断是正（K-11）
- `run_evidence.py` への `--expected-sha` 追加（R1 m-4。**信頼済み実行層が解決した値のみ**を受け付ける契約を先に決める必要がある）
- 受理器の subset validator を jsonschema へ置換（`schemas/` 昇格で CI が jsonschema を持つようになった時点。K-13 の保守コストが消える）

## 4. 妥協点（採用しなかった選択肢と理由）

| 論点 | 採用 | 不採用の選択肢と理由 |
|------|------|-------------------|
| `--pr-number` の扱い | record 由来の PR とだけ照合する cross-check | **注入値で `repair_rounds` を実値化**: 受理器が再計算照合できず、生成側の自己申告を信頼する構造になる |
| `BLOCKED` の delivery 層 4 フィールド | `unavailable` | **ダミー sha / 0 で埋める**: EV に自己 hash が無いため tampered 検出も効かない。**reject する**: BLOCKED run の証跡が一切残らない |
| `quality_metrics` が導出不能なとき | 全体を `"unavailable"` | **`{"first_pass": false, "rounds": 0}`**: `unavailable` を 0 で埋める fail-open |
| `decision != AUTO_APPROVED` の c3-prime | 束縛は producer 側で再検証し `decision` 値のみ供給元扱い | **rc==0 を文字どおり要求**: `BLOCKED` / `HUMAN_ESCALATED` の EV が構造的に発行できない |
| 絶対パス / URL / @handle を含む入力 | 還元 + `escalation` 記録 | **fail-closed で EV を発行しない**: 実 record（`comment_url` を持つ）で常に発行不能になる |
| `metrics.py` の 4 分類 | 導出規則を転写 | **import**: 不変対象への依存を増やす |
| `OUTPUT_KEYS` | producer に列挙し TC-62 で schema と束縛 | **schema から導出**: 入力ソース allowlist に schema ファイルが増える |
| `--harness-version-end` 未注入時の AC-12 drift 検査（R2 MJ-3） | **(b) `escalation` へ `harness_drift_unchecked` を記録し、受理器が partial 理由に列挙**（＝検査が欠けていること自体が証跡に残る） | **(a) 必須化（fail-closed）**: 終了時 harness を取得できない経路（run 異常終了後の事後発行等）で `EV` が**一切発行できなくなり**、最も証跡が必要な run の記録が消える。**(c) WARN 降格**: 受理側が「検査済み `EV`」と「未検査 `EV`」を区別できないままで、`baseline_version` を `EV` から取る下流に**未検査 run が同一 baseline として混入**する経路が残る。(b) は既存 fixture を byte 不変に保てる（`_fx_produce` に `--harness-version-end` を注入）点でも実装コストが最小だった |

## 5. AC ↔ fixture 対応表（AC-16 の要求成果物）

| # | fixture | 主に検証する AC | `terminal_state` | 受理器 exit | `unavailable` 件数 |
|---|---------|----------------|-----------------|------------|------------------|
| 1 | `fx-01-first-pass.json` | AC-2 / AC-3 / AC-12（**`--harness-version-end` を注入して生成**＝drift 検査を実走。未注入なら `escalation.harness_drift_unchecked` が付く / R2 MJ-3） | `MERGE_READY` | 11 | 3 |
| 2 | `fx-02-ci-repair.json` | AC-3（`ci_outcomes` / `repair_rounds`） | `MERGE_READY` | 11 | 3 |
| 3 | `fx-03-review-repair.json` | AC-3（`review_findings`） | `MERGE_READY` | 11 | 3 |
| 4 | `fx-04-human-escalated.json` | AC-3 / AC-14 | `HUMAN_ESCALATED` | 11 | 7 |
| 5 | `fx-05-blocked.json` | AC-3 / TC-58 | `BLOCKED` | 11 | **8**（(a)3 + (b)5） |
| 6 | `fx-06-routing-escalation.json` | AC-3（routing の**キー存在のみ**）+ `kind=notice` の escalation 経路 ⚠️ routing の**値**カバレッジは 0 | `HUMAN_ESCALATED` | 11 | 7 |
| 7 | `fx-07-tampered-expected-errors.json` | AC-4（期待エラー列。受理された record ではない） | — | ケースごとに 1 / 1 / 11 | — |
| 8 | `fx-08-shadow-candidate-input.json` | AC-7 / AC-8 | — | — | — |
| 9 | `fx-09-paired-replay.json` | AC-10（**#874 の最小定義**・U-9。#869 / #811 / #868 が別定義を採った場合は**追従**する） | — | — | — |
| 10 | `fx-10-canary-rollback.json` | AC-10 / AC-11 / AC-13（**#874 の最小定義**・U-9。下流が別定義を採った場合は**追従**する） | — | — | — |

> **一次証跡で裏が取れる範囲 / 手書きに留まる範囲**（C-2 レーン B 返送論点 4）:
> fixture 2 の entry 共通キー形状（`action_id` / `action_kind` / `at` / `entry_id` / `kind`）・
> `pr_number` / `round` の型・`repair_ci` の `taxonomy` / `failed_checks` / `head_sha`・
> `comment_url` は実在の `docs/working/TASK-0917/evidence/e2e/run/delivery/record.jsonl` に照らした。
> **`kind=state` / `kind=merge_ready` / `record.check_summary` / `record.review_disposition` /
> `record.plan_hash` は実 record に存在せず手書きに留まる**。

## 5-bis. 65 TC ↔ 実装テスト 対応表（T-40 の要求成果物）

`P` = `scripts/ai-loop/test_run_evidence.py` / `V` = `scripts/ai-loop/test_run_evidence_verify.py` /
`TA60` = `tests/extras/ta-60-run-evidence.sh`。**SKIP は 0 件**。
**機械実行 63 / 手動 2**（TC-46 / TC-49 = K-9。「65 件すべて機械実行」とは報告しない）。

| TC | 実装テスト | 結果 |
|----|-----------|------|
| TC-01 | `V:test_tc01_schema_parses_and_is_draft_2020_12` | PASS（機械） |
| TC-02 | `V:test_tc02_id_is_the_post_promotion_url` | PASS（機械） |
| TC-03 | `V:test_tc03_additional_properties_false_and_annotation_pattern` | PASS（機械） |
| TC-04 | `V:test_tc04_required_is_21_and_covers_the_20_issue_fields` | PASS（機械） |
| TC-05 | `V:test_tc05_versioning_policy_and_schema_version_required` | PASS（機械） |
| TC-06 | `V:test_tc06_each_required_key_missing_is_ng` | PASS（機械） |
| TC-07 | `V:test_tc07_single_unavailable_field_is_partial` / `V:test_tc07_unavailable_is_partial_not_zero` | PASS（機械） |
| TC-08 | `V:test_tc08_entry_id_tamper_in_record_is_ng` / `V:test_tc08_final_head_sha_tamper_is_ng` / `V:test_tc08_plan_hash_one_char_tamper_is_ng` / `V:test_tc08_repair_rounds_tamper_is_ng` / `V:test_tc08_source_sha_tamper_is_ng` / `V:test_tc08_task_id_not_bound_to_task_dir_is_ng` | PASS（機械） |
| TC-09 | `V:test_tc09_annotation_key_non_string_is_ng` / `V:test_tc09_annotation_key_string_is_accepted` / `V:test_tc09_unknown_toplevel_key_is_ng` | PASS（機械） |
| TC-10 | `P:test_tc10_same_input_twice_is_byte_identical` / `P:test_tc10_serialization_matches_c3_prime_form` / `P:test_tc11_input_key_order_does_not_change_output` | PASS（機械） |
| TC-11 | `P:test_tc11_input_key_order_does_not_change_output` | PASS（機械） |
| TC-12 | `P:test_tc12_missing_injected_values_are_errors` / `P:test_tc12_pr_number_is_not_fail_closed` / `P:test_tc12_producer_never_reads_the_clock` | PASS（機械） |
| TC-13 | `P:test_tc13_c3_json_fields_are_carried` | PASS（機械） |
| TC-14 | `P:test_tc14_final_head_sha_and_ci_outcomes_come_from_record` | PASS（機械） |
| TC-15 | `P:test_tc15_review_findings_and_repair_rounds` | PASS（機械） |
| TC-16 | `P:test_tc16_human_escalated_state_is_not_rounded_to_merge_ready` | PASS（機械） |
| TC-17 | `V:test_tc17_observation_and_cause_hypothesis_are_separate_fields` | PASS（機械） |
| TC-18 | `P:test_tc18_cause_hypothesis_is_not_auto_generated` | PASS（機械） |
| TC-19 | `P:test_tc19_forbidden_keys_never_reach_the_output` | PASS（機械） |
| TC-20 | `P:test_tc20_absolute_evidence_ref_is_rejected` / `P:test_tc20_relative_evidence_ref_is_accepted` | PASS（機械） |
| TC-21 | `P:test_tc21_output_extension_must_be_json` | PASS（機械） |
| TC-22 | `TA60` ブロック④（`PLANGATE_HOOK_STRICT=1` で `check-metrics-privacy.sh` を golden 10 件へ実走） | PASS（機械） |
| TC-23 | `P:test_tc23_three_runs_produce_a_candidate_input` | PASS（機械） |
| TC-24 | `P:test_tc24_adapters_have_no_io` | PASS（機械） |
| TC-25 | `P:test_tc25_uses_the_measured_spelling` | PASS（機械） |
| TC-26 | `P:test_tc26_baseline_version_matches_and_mixed_is_rejected` | PASS（機械） |
| TC-27 | `P:test_tc27_improvement_task_goes_through_the_normal_gates` | PASS（機械） |
| TC-28 | `P:test_tc28_trust_ledger_keys_and_evidence_count` | PASS（機械） |
| TC-29 | `P:test_tc29_improvement_refs_are_traceable_in_both_directions` | PASS（機械） |
| TC-30 | `P:test_tc30_harness_version_stable_across_the_run` | PASS（機械） |
| TC-31 | `P:test_tc31_harness_version_drift_is_fail_closed` | PASS（機械） |
| TC-32 | `V:test_tc32_arbiter_record_is_legacy` | PASS（機械） |
| TC-33 | `P:test_tc33_two_runs_are_insufficient` | PASS（機械） |
| TC-34 | `P:test_tc34_paired_replay_keeps_the_two_sides_disjoint` | PASS（機械） |
| TC-35 | `P:test_tc35_failed_canary_rolls_the_candidate_back` | PASS（機械） |
| TC-36 | `P:test_tc36_non_empty_blocked_by_is_blocked` | PASS（機械） |
| TC-37 | `P:test_tc37_no_issue_number_is_hardcoded` | PASS（機械） |
| TC-38 | `P:test_tc38_consumer_section_lists_the_five_fields` | PASS（機械） |
| TC-39 | `P:test_tc39_only_section_7_changed` | PASS（機械） |
| TC-40 | `P:test_tc40_binding_failure_is_fail_closed_for_non_auto_approved` / `P:test_tc40_plan_package_hash_tamper_is_fail_closed` / `P:test_tc40_producer_calls_c3prime_verify` / `P:test_tc40_stale_plan_hash_is_fail_closed` | PASS（機械） |
| TC-41 | `P:test_tc41_decision_is_not_trusted_blindly` | PASS（機械） |
| TC-42 | `P:test_tc42_real_corpus_matches_metrics_py` / `P:test_tc43_identity_holds_and_is_not_vacuous` | PASS（機械） |
| TC-43 | `P:test_tc43_identity_holds_and_is_not_vacuous` | PASS（機械） |
| TC-44 | `P:test_tc44_broken_inputs_are_skipped_with_a_reason` / `P:test_tc44_legacy_and_invalid_meta_are_separated` | PASS（機械） |
| TC-45 | `P:test_tc45_existing_arbiter_records_are_untouched` | PASS（機械） |
| TC-46 | **機械 assert なし** → 手動: `sh tests/run-tests.sh </dev/null` の出力に `=== TA-60: RunEvidence contract (#874) ===` ブロックが現れ exit 0 | **手動 PASS**（§6 の実測ログ） |
| TC-47 | `TA60` ブロック③（2 unit モジュールを 1 PASS 行ずつ実行 = 期待出力そのもの） | PASS（機械） |
| TC-48 | `P:test_tc48_fixture_07_expected_errors_are_reproduced` / `P:test_tc48_ten_goldens_are_byte_identical_after_regeneration` | PASS（機械） |
| TC-49 | **機械 assert なし** → 手動: `git diff --stat origin/main -- tests/run-tests.sh` | **手動 PASS**（0 行・§6） |
| TC-50 | `P:test_tc50_routing_is_bound_to_the_same_run_id` | PASS（機械） |
| TC-51 | `P:test_tc51_account_handles_in_values_are_redacted` / `P:test_tc51_account_identifiers_are_reduced_to_numbers` / `P:test_tc51_account_keys_in_input_are_escalated` | PASS（機械） |
| TC-52 | `P:test_tc52_unsupplied_is_unavailable_and_explicit_empty_is_empty` | PASS（機械） |
| TC-53 | `P:test_tc53_unknown_record_kind_is_escalated_not_swallowed` | PASS（機械） |
| TC-54 | `P:test_tc54_run_count_is_distinct_run_ids_not_record_count` | PASS（機械） |
| TC-55 | `P:test_tc55_missing_blocked_by_key_is_blocked` | PASS（機械） |
| TC-56 | `V:test_tc56_synthetic_complete_ev_is_accepted` | PASS（機械） |
| TC-57 | `P:test_tc57_merge_ready_candidate_is_not_rounded_up` / `P:test_tc57_merge_ready_requires_a_physical_merge_ready_entry` | PASS（機械） |
| TC-58 | `P:test_tc58_blocked_emits_ev_with_delivery_fields_unavailable` / `P:test_tc58_blocked_fixture_has_eight_unavailable_fields` | PASS（機械） |
| TC-59 | `P:test_tc59_non_terminal_states_do_not_emit_evidence` | PASS（機械） |
| TC-60 | `P:test_tc60_adding_an_arbiter_record_does_not_change_the_output` / `P:test_tc60_quality_metrics_has_no_corpus_aggregate` | PASS（機械） |
| TC-61 | `V:test_tc61_required_set_is_derived_from_schema` / `V:test_tc61_required_set_is_not_hardcoded_as_a_literal` / `V:test_tc61_verifier_follows_schema_changes` | PASS（機械） |
| TC-62 | `V:test_tc62_producer_output_keys_subset_of_properties` | PASS（機械） |
| TC-63 | `P:test_tc63_producer_opens_only_the_allowlisted_sources` / `P:test_tc63_producer_source_has_no_environment_or_network_access` | PASS（機械） |
| TC-64 | `P:test_tc64_injected_pr_number_alone_does_not_materialize_rounds` / `P:test_tc64_unresolvable_pr_number_is_unavailable_not_zero` / `V:test_tc64_unresolvable_pr_number_must_be_unavailable_not_zero` | PASS（機械） |
| TC-65 | `P:test_tc65_absolute_paths_in_any_field_are_zero` | PASS（機械） |

> **手動 2 件の実行コマンドと実測結果**（R2 MN-3）:
>
> | TC | コマンド | 実測 |
> |----|---------|------|
> | TC-46 | `sh tests/run-tests.sh </dev/null` | `=== TA-60: RunEvidence contract (#874) ===` ブロックが出力に出現・9 PASS / 0 FAIL・スイート exit 0（§6） |
> | TC-49 | `git diff --stat origin/main -- tests/run-tests.sh` | **出力 0 行**（`tests/run-tests.sh` は未変更。glob loader が `ta-60` を自動発見するため改変不要） |
>
> ⚠️ TC-49 を機械 assert 化しなかった理由: `origin/main` ref に依存するテストは **shallow clone の CI で
> `origin/main` が存在せず落ちる**（R2 MJ-5 と同じ「CI 時限爆弾」クラス）。手動確認に留める方が安全側。

### TC 番号外の追加テスト（R2 MJ-3 由来・4 件）

| 追加テスト | 位置 | 期待 |
|-----------|------|------|
| `test_unchecked_drift_is_recorded_in_escalation` | `P` | `--harness-version-end` 未注入 → `escalation` に `harness_drift_unchecked` |
| `test_checked_drift_leaves_no_unchecked_escalation` | `P` | 注入時は積まない |
| `test_unchecked_harness_drift_is_partial_not_complete` | `V` | 全 available でも `exit 11`（`complete` にしない） |
| `test_other_escalation_kinds_do_not_block_complete` | `V` | `unknown_record_kind` 等は `complete` を妨げない |

## 6. テスト結果サマリ

**測定時点**: code HEAD = `52bd791`（R2 反映）。`docs/working/TASK-0874/*.md` のみ未 commit の状態で測定。

| コマンド | 結果（exit code） |
|---------|------------------|
| `python3 scripts/ai-loop/test_run_evidence.py` | **80 tests / OK（exit 0）**（R2 で +2: MJ-3 の producer 側追加テスト） |
| `python3 scripts/ai-loop/test_run_evidence_verify.py` | **32 tests / OK（exit 0）**（R2 で +2: MJ-3 の受理器側追加テスト） |
| `sh tests/run-tests.sh </dev/null` | **523 passed / 0 failed（exit 0）** |
| `sh tests/extras/ta-60-run-evidence.sh </dev/null` | **pass=9 / fail=0（exit 0）** |
| `python3 scripts/ai-loop/check_exec_boundary.py` | **clean（30 ファイル / 違反 0）（exit 0）** |
| `PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_FILES="<10 fixture>" sh scripts/hooks/check-metrics-privacy.sh` | **PASS（10 files checked）（exit 0）** |
| `npx markdownlint-cli2 <変更 md>` | **0 issues（exit 0）** |
| 不変 7 ファイル + `ai-loop-runs/` + `tests/run-tests.sh` の `git diff --stat origin/main` | **0 行** |
| `git diff --quiet -- plugin/plangate/` | **clean**（R2 で producer / 契約 doc を変更したため sync を再実行済み） |

### 523 の内訳（R2 MN-4 の指摘に対する実測）

旧記載の「523 passed・baseline 513」は **`513 + ta-60 の 9 = 522 ≠ 523`** で +1 が説明できていなかった。
**同一 base commit（`a667c0d`）の fresh clone で baseline を再測定**して内訳を確定した。

| 項目 | 実測 |
|------|------|
| baseline @ `a667c0d`（fresh clone・`/tmp` に `git clone` して測定） | **515 passed / 0 failed** |
| 同 base を**本 worktree 相当**に換算 | **514**（`TA-13 TC-17`「`.claude/settings.json`: no diff vs main」は **git worktree では `[SKIP] not a git repo`** になり 1 件減る。両ログの per-section 差分は**この 1 件と `TA-60` の 9 件のみ**） |
| 本 PBI の増分（`ta-60`） | **+9** |
| **合計（HEAD 実測）** | **523**（= 514 + 9） |

⇒ **本 PBI に起因する増分は `ta-60` の 9 件だけ**であり、旧記載の +1 の正体は
**T-2 で記録した baseline 513 が再現しない**（同 base の再測定は 514 / 515）ことだった。
`513` と `514` の 1 件差の原因は特定できていないが、**本 PBI の変更に起因しない**ことは
per-section 差分（`TA-13` と `TA-60` 以外は全セクション完全一致）で確認済み。

> 参考: 本 suite には環境依存の `[SKIP]` が **4 件**存在する（`F-8` / `TA-13 TC-17` /
> `TA-25 TC-06`（HO patch 未適用）/ `TA-58 TC-13b`（EH-12 は Human の `--apply` 待ち））。
> **いずれも本 PBI の 65 TC とは無関係**であり、65 TC 側の SKIP は 0 件。

### MJ-5 の成長耐性の実証（R2 検証項目 6）

`docs/working/ai-loop-runs/` にダミー record を 1 件足して 29 件（`legacy 25` / `run 4` /
`total_records 29`）にした状態で、成長に晒される 4 test を実行し **OK（exit 0）**:

```text
PYTHONPATH=scripts/ai-loop python3 -m unittest \
  test_run_evidence.LegacyClassificationTests.test_tc42_real_corpus_matches_metrics_py \
  test_run_evidence.LegacyClassificationTests.test_tc43_identity_holds_and_is_not_vacuous \
  test_run_evidence.LegacyClassificationTests.test_tc44_broken_inputs_are_skipped_with_a_reason \
  test_run_evidence.LegacyClassificationTests.test_tc54_run_count_is_distinct_run_ids_not_record_count
→ Ran 4 tests ... OK
```

旧実装なら `assertEqual(got["run_count"], 3)` が `4 != 3` で落ちていた（= 変異注入相当の反証）。
なお probe を置いたまま全モジュールを走らせると **TC-45 のみ FAIL** するが、これは
TC-45 が `git status --porcelain` を見るため **未 commit の probe ファイル**を検出するもので、
実運用の成長（record は commit されて入る）では発生しない。**probe は検証後に削除済み**
（`ls docs/working/ai-loop-runs/*.json | wc -l` = 28 / `git status` clean を確認）。

**変異注入 29 件**（M1 〜 M29）で新規テストの検出力を実証した。**2 件（M17 / M21）が当初 survive**
したため、入力側 reject の識別と出力側 backstop の単体検査を追加して kill した。
一覧は `todo.md` の「T-12 〜 T-36 完了記録」を参照。

## 7. 引き継ぎ文書（5 分で状況把握）

`#874` は **1 回の ai-loop run が終端に達したときに発行する run 単位の証跡（RunEvidence）**の
契約層を作る PBI である。本 exec で以下が揃った。

- **契約正本** `docs/workflows/ai-loop/run-evidence-contract.md` と **schema**（`required` 21）
- **決定論 producer** `scripts/ai-loop/run_evidence.py`（時刻を内部参照せず・ネットワーク / 外部
  プロセスを呼ばず・入力は `task_dir` と `runs_dir` に閉じる）
- **受理器** `scripts/ai-loop/run_evidence_verify.py`（exit 0 / 1 / 10 / 11。`10` の意味は
  姉妹受理器 `c3prime_verify.py` と同一）
- **golden fixture 10 件** と **`tests/extras/ta-60-run-evidence.sh`**（CI 導線 + EH-8 実走）

設計の要は 4 つ。
①**`unavailable` を 0 や空配列で埋めない**（Phase 1 の producer 出力は必ず partial = exit 11）。
②**`MERGE_READY` は `kind=merge_ready` entry の物理存在のみを条件にする**（`MERGE_READY_CANDIDATE`
を丸めない）。
③**生成側の申告を信頼しない**（受理器が `approvals/c3.json` と `delivery/record.jsonl` を
再読込して再計算照合する）。
④**「検査していないこと」も証跡に残す**（R2 MJ-3。`--harness-version-end` 未注入 =
AC-12 の drift 未検査は `escalation.harness_drift_unchecked` に残り、受理器が `complete` を返さない。
「値が取れない」＝`unavailable` と「検査していない」＝`escalation` を**別語彙**にしてある）。

### 敵対レビュー R2 の反映結果（本セッション）

| 指摘 | disposition |
|------|------------|
| MJ-1 handoff / status / current-state が HEAD より前を凍結 | reflected（本 handoff・`status.md`・`current-state.md`・`todo.md` を HEAD 基準へ） |
| MJ-2 AC-3 が無条件 PASS だが routing の実カバレッジ 0 | reflected（§1 の AC-3 行に限定語 + K-3 相互参照） |
| MJ-3 AC-12 の drift 検査が caller opt-in | reflected（**案 (b)** を採用。§4 妥協点に選定理由） |
| MJ-4 C-3 指定の「見直し前提」が handoff に無い | reflected（**§1-bis** を新設し契約 §0 の表を転記） |
| MJ-5 実 corpus 件数のハードコードが CI 時限爆弾 | reflected（下限 assert 化 + 成長耐性を実証） |
| MN-1 「fixture 6 は fixture 4 と区別不能」は事実誤り | reflected（実測で反証し K-3 / 表 / `test-cases.md` を是正） |
| MN-2 `test-cases.md` fixture 5 の `unavailable` が 7 件 | reflected（8 件・`(b)` は 5 へ是正。TC-58 本文も同時是正） |
| MN-3 TC-46 / TC-49 に機械 assert が無い | reflected（**§5-bis** に手動 2 件として明示 + K-9） |
| MN-4 `523` の +1 が未説明 | reflected（§6 に fresh clone での baseline 再測定と内訳） |

**次の担当者（統合担当）がやること**:

1. **T-38 / T-39 の artifact 配置**（R1 / R2 レポートを `docs/working/TASK-0874/evidence/` へ）→ todo を閉じる
2. **T-42**: issue #874 への DoD コメント（**close 条件未達**と **routing 実カバレッジ 0** の明記が必須）
3. **T-43**: #870 への evidence link
4. **T-44**: `schemas/` 昇格 PBI の予約起票（起票のみ・HO patch の適用は Human-owned）
5. PR 作成 → **C-4（merge は Human-owned / NO MERGE BY AI）**

⚠️ `scripts/ai-loop/*.py` または `docs/workflows/ai-loop/*.md` を更に変更した場合は
**`sh scripts/sync-plugin-plangate.sh` の再実行が必須**（CI `sync-plugin-plangate.yml` が drift を検出する）。

### 敵対レビュー R1 の反映結果（本セッション・critical 3 / major 5 / minor 5）

> R1 は「exec + R2 反映まで完了」の状態に対する再レビューであり、**R2 では出ていない
> 深い層の欠陥**（受理器の再導出範囲・変異注入の空振り・型判定の fail-open）を検出した。
> 是正は **すべて変異注入で kill を実証**している（`検証コマンドと結果` を参照）。

| ID | 指摘 | disposition |
|----|------|------------|
| **C-1** | 受理器が `terminal_state` を一切検証していない（schema の `enum` がどの層からも強制されず、`WAITING_FOR_CHECKS` の EV が exit 0） | **reflected** — `_terminal_state_problems()` で §4 マッピングにより再導出照合。語彙 allowlist だけでは 3 値の中での入れ替えを検出できないため、`c3.json.decision` + `record.jsonl` からの**再導出値との一致**まで要求する |
| **C-2** | 変異注入 M21 の kill が空振り（backstop の**配線**を 1 行も守っていない）+ 受理器に privacy backstop が無い | **reflected** — `unittest.mock.patch` で `build()` 経由の end-to-end 配線を固定し、**実際に call site を削除して FAIL することを確認**。受理器は `check_output_privacy()` を import して同一検査を実施（R1 の 4 プローブすべてが exit 1 になることを実測） |
| **C-3** | `to_promotion_provenance` の AC-13 fail-closed が `null` / `""` / `0` / `{}` で破れる（docstring と実装の矛盾・同一関数内の非対称） | **reflected** — `not isinstance(blocked_by, list) or bool(blocked_by)` へ是正。8 値を parametrized で固定 |
| **M-1** | AC-2 決定論の破れ（無関係 run の record 1 件で EV の byte が変わる） | **reflected** — `records_for_run()` で当該 `run_id` に絞る。**別 run の record を 4 件足しても byte 不変**であることをテストで実証（絞り込みが検出の放棄でないことも対で固定） |
| **M-2** | `_recheck_bindings` が `verdict` 語彙 / `evidence_ref` 独立性の 2 件を落としている（契約 §6-5「検証の総量も減らさない」違反） | **reflected** — `c3_contract.VALID_VERDICTS` を使って追加（`c3prime_verify` から転写しない）。`c3_contract.check_snapshot_trio` の docstring が「呼び出し側残置」と明示している 2 件と一致 |
| **M-3** | 受理器が `ci_outcomes` / `review_findings` / `quality_metrics` を再導出しない | **reflected** — producer の純関数（`derive_delivery_fields` / `derive_quality_metrics`）を import して照合（追加 I/O ゼロ・再実装ゼロ） |
| **M-4** | plugin 同梱の受理器が起動不能（schema 未同梱で**常に exit 1**・stderr に絶対パス） | **reflected** — `SCHEMA_CANDIDATES` に bundled レイアウト（`<skill>/schemas/`）のフォールバックを追加、sync 対象に schema を追加、**schema 読み込み失敗を exit 2（起動不能）へ分離**。⚠️ ta-60 ⑤ の drift 検査は `.py` のみを対象にするため、schema は既存の for ループ / case 文とは**別ブロック**で同期する |
| **M-5** | schema の `type` / `enum` / `pattern` / `minLength` が 3 層すべてで強制されない | **partially reflected** — ① 受理器に subset validator を実装して**強制**（jsonschema 依存なし。jsonschema 導入環境では golden 6 件 + 変異 6 件で参照実装と同判定であることを照合）。② `schema-validate.yml` の trigger paths 追加は **`.github/workflows/*.yml` が Hardening Override 対象（Human-owned）のため本 PBI では実施しない** → **K-12**（契約 §10-3 に 3 層の状態表を明記）|
| m-1 | `_unavailable_paths` が深さ 1 の dict までしか降りない | **reflected** — `run_evidence._walk` を再利用して list 内・任意深さまで全数列挙 |
| m-2 | `classify_records` が `build()` から呼ばれない dead code | **rejected（設計として意図的）** — 本関数の戻り値は `runs_dir` **全件**の corpus 集計値であり、`build()` に配線すると契約 §3-3 が明示的に禁じる corpus 汚染（TC-60 が検出する AC-2 違反）になる。AC-15 は「EV に載せる」ではなく「`metrics.py` と同値かつ既存 record を 1 バイトも変更しない」ことで満たす。**docstring に「検証用の公開 API であり producer 本体には接続しない」ことと理由を明記**して誤読を塞いだ |
| m-3 | `c3-prime-contract.md` §7-1 の「読むフィールドは 5 つ」が実装と不一致（正本の事実誤り） | **reflected** — 「`EV` へ**値を運ぶ**フィールドは 5 つ」と「**読む**フィールドはそれに閉じない」を分離し、`artifact_hashes` / `reviewers` / record 全体の privacy 走査を表に追加 |
| m-4 | `verify_c3_prime` が `expected_sha` なしで `delivery.verify_c3` を呼ぶことがコードにも契約にも未明示 | **reflected（判断は維持・明示化）** — producer は純判定器（外部プロセスを呼ばない）であり `expected_sha` の解決には `git rev-parse` 相当が要る。注入値にすると生成側の自己申告になり trust boundary に反する。**docstring と c3-prime-contract §7-1 に理由を明記**し、`--expected-sha` 追加は V2 候補へ |
| m-5 | `int(candidate.get("rollback_count", 0))` が非数値で `ValueError` | **reflected** — `RunEvidenceError` に集約（0 に丸めない）。`bool` も除外（`True` は `int` のサブクラス） |
