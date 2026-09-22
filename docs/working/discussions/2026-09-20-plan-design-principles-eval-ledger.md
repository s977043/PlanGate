# Plan Design Principles Eval — Run Ledger Template

- Issue: #1337
- Evaluation version: `PDP-EVAL-v1`
- Baseline SHA: `612c3dacacf76c0bfd72559fbbe0bc41bc41443d`
- Candidate SHA: `4b3f4017ad6c2a64813524ec8567a289f722cb45`
- Status: TEMPLATE — run evidenceを記録するまで結果を主張しない

## Preconditions

以下が1つでも未確定なら run を開始せず、statusを `INCONCLUSIVE_NOT_RUN` とする。

- model_id
- effort / reasoning level
- token/output budget
- timeout
- tool policy / network policy
- generator input source hash
- materialized pbi-input.md hash
- baseline skill hash
- candidate skill hash
- baseline bundled-reference manifest/hash
- candidate bundled-reference manifest/hash
- independent reviewer identity/role
- raw output保存先
- rubric version/hash

## Sandbox / contamination controls

Generatorに見せてよい:
- 選択1ケースの frozen derived PBI
- 共通依頼
- 対象variantと同じSHAの `ai-dev-plan/SKILL.md`
- そのSkillが通常解決する bundled references / rules
- 評価fixture内で明示した synthetic evidence

Generatorに見せない:
- reviewer-only rubric
- expected behavior / failure examples
- 他variant・他trialのraw output
- 採点結果
- candidate-only documentsをbaselineへ補完したコピー

実行後に `rubric_visible_to_generator=false` を証跡付きで記録できなければ、そのrunは contaminated として除外する。

## Materialized PBI contract

materializationはrun前に一度だけ実施済み。各generationは `docs/working/eval-inputs/PDP-EVAL-v1/` の選択ケースを
**byte-for-byte copy** して `docs/working/TASK-EVAL-PDPXX/pbi-input.md` に配置して開始する。
正本manifest: `docs/working/eval-inputs/PDP-EVAL-v1/manifest.md`。

記録必須:
- source input hash
- frozen derived PBI Git blob
- runtime copied PBI path
- runtime copied PBI SHA256
- case ID / task ID
- baseline/candidate間でbytes一致したか

同一pairでmaterialized PBI hashが一致しなければ、そのpairは `INCONCLUSIVE_INPUT_MISMATCH` として採点対象から除外する。


## Frozen PBI manifest

| Case | Git blob |
| --- | --- |
| PDP-01 | `e5f9f46397ca85ea82c0f72f19c3ad81fe4e722f` |
| PDP-02 | `f6cfd3a3bf4c23729a6bd407c3a7c1281058b253` |
| PDP-03 | `aec24092eec9ab9bc8b4dd692e4941bf0b88489f` |
| PDP-04 | `6ea5585de848fb11e5848d2a669ad8538c952363` |
| PDP-05 | `38b267c1930e36d5700e3aed437c0a59ed909282` |
| PDP-06 | `f8d538e7e2530e0bbebc0d4ffc5a8d96880f98fc` |
| PDP-07 | `b34035d35f2b5b15a4466889a70a290f1fc41208` |
| PDP-08 | `8a72f5d3694853487db2f8a031679932296cd5aa` |

Source Git blob: `1a6176ff18c19f7cf1141c38aab9a23e1968ce0b`。
field-by-field semantic equality: **8/8 PASS**。

## Frozen variant manifest

| Surface | baseline | candidate |
| --- | --- | --- |
| repo SHA | `612c3dacacf76c0bfd72559fbbe0bc41bc41443d` | `4b3f4017ad6c2a64813524ec8567a289f722cb45` |
| plugin Skill | `139fadd69c39fa0079ee8b44ca20d3f4830819fd` | `e8d773fc47e224d1d1a9fcf179ec970aa271c4e0` |
| ai-driven-development ref | `3ec9e74bdd65ee72fe88edc4a101d2f1252be3d6` | same |
| metrics ref | `c763b06d79bc281bb336a38cc7be42f93f774822` | same |
| core-contract ref | `914b6467afe49928c364ca277aed6e9a4a2072d5` | same |
| plan-template ref | `3735169a24bc94c09c76720435d0d372720207ab` | `5f0c37ea4a2539a70aa78c06584d9b54ec804f03` |
| todo ref | `339fd09dd7abd26b8cb9cb16c4374114d7648232` | same |
| test-cases ref | `c6d9da1c9be660c648d594fe847bb42caa110263` | `1832e6c084e487c8b0e59ccac3f910f44bcdd6d3` |

実行時Skillは `plugin/plangate/skills/ai-dev-plan/SKILL.md` を明示的に読む。
上流 `.agents/skills/ai-dev-plan/` の `references/` を期待しない。

## Run manifest

| Field | Value |
| --- | --- |
| eval_version | PDP-EVAL-v1 |
| model_id | `gpt-5.6-sol` |
| effort | `high` |
| max_input_tokens | 64000 (measured ceiling) |
| max_output_tokens | 16000 (measured ceiling) |
| timeout_seconds | 600 |
| tool_policy | Codex read-only shell/file inspection only; no write/MCP/network |
| network | off |
| input_ref | `docs/working/eval-inputs/PDP-EVAL-v1/manifest.md` + selected frozen PBI |
| input_source_hash | git blob `1a6176ff18c19f7cf1141c38aab9a23e1968ce0b` |
| materialized_pbi_hash | TBD |
| materialized_pbi_path | TBD |
| rubric_ref | `2026-09-20-plan-design-principles-eval-rubric.md` |
| rubric_hash | git blob `0fe2983377a0a61f58e2d4b796e85fe9355410ba` |
| reviewer | isolated Codex `gpt-5.6-terra` / high |
| reviewer_model_id | `gpt-5.6-terra` |
| reviewer_effort | `high` |
| reviewer_max_input_tokens | 64000 (measured ceiling) |
| reviewer_max_output_tokens | 8000 (measured ceiling) |
| reviewer_timeout_seconds | 600 |
| generator_total_ceiling | 3840000 tokens |
| reviewer_total_ceiling | 3456000 tokens |
| combined_total_ceiling | 7296000 tokens |
| adjudicator | Human |
| started_at | TBD |
| completed_at | TBD |

## Activation evidence contract

各runで以下を記録する。

- `skill_ref`: repo SHA + path
- `skill_hash`
- `references_loaded`: path + hash のlist
- `principle_activation`: output内で判断に影響した箇所の参照
- `resolution_failures`: 読めなかったrequired reference
- `variant_identity_verified`: true/false

`variant_identity_verified=false` または required skill activation が確認できない場合、効果比較は `INCONCLUSIVE`。

## 48-run matrix

順序効果を偏らせないため、trialごとに開始variantを交互にする。

| pair_id | case | trial | first | second | status |
| --- | --- | ---: | --- | --- | --- |
| P01 | PDP-01 | 1 | baseline | candidate | NOT_RUN |
| P02 | PDP-01 | 2 | candidate | baseline | NOT_RUN |
| P03 | PDP-01 | 3 | baseline | candidate | NOT_RUN |
| P04 | PDP-02 | 1 | candidate | baseline | NOT_RUN |
| P05 | PDP-02 | 2 | baseline | candidate | NOT_RUN |
| P06 | PDP-02 | 3 | candidate | baseline | NOT_RUN |
| P07 | PDP-03 | 1 | baseline | candidate | NOT_RUN |
| P08 | PDP-03 | 2 | candidate | baseline | NOT_RUN |
| P09 | PDP-03 | 3 | baseline | candidate | NOT_RUN |
| P10 | PDP-04 | 1 | candidate | baseline | NOT_RUN |
| P11 | PDP-04 | 2 | baseline | candidate | NOT_RUN |
| P12 | PDP-04 | 3 | candidate | baseline | NOT_RUN |
| P13 | PDP-05 | 1 | baseline | candidate | NOT_RUN |
| P14 | PDP-05 | 2 | candidate | baseline | NOT_RUN |
| P15 | PDP-05 | 3 | baseline | candidate | NOT_RUN |
| P16 | PDP-06 | 1 | candidate | baseline | NOT_RUN |
| P17 | PDP-06 | 2 | baseline | candidate | NOT_RUN |
| P18 | PDP-06 | 3 | candidate | baseline | NOT_RUN |
| P19 | PDP-07 | 1 | baseline | candidate | NOT_RUN |
| P20 | PDP-07 | 2 | candidate | baseline | NOT_RUN |
| P21 | PDP-07 | 3 | baseline | candidate | NOT_RUN |
| P22 | PDP-08 | 1 | candidate | baseline | NOT_RUN |
| P23 | PDP-08 | 2 | baseline | candidate | NOT_RUN |
| P24 | PDP-08 | 3 | candidate | baseline | NOT_RUN |

各pairは2 generationなので全48 generation。

## Runtime-only placeholders

以降の `TBD` は**設計未確定ではない**。run開始後にのみ確定する以下の実測値用placeholderである。

- pair/case/trial/variantの個別record値
- runtime copied PBI SHA256 / path
- context/session ID
- started/completed timestamp
- actual raw output path/hash
- actual activation evidence / contamination / missing-data
- blind scoring evidence / rationale

model / effort / timeout / tool policy / per-run ceiling / pilot-wide ceiling / reviewer identity / frozen input・rubric・variant manifest は上のsectionsで確定済み。

## Per-run record

各generationごとに1 recordを作る。

| Field | Value |
| --- | --- |
| pair_id | TBD |
| case_id | TBD |
| trial | TBD |
| variant | baseline/candidate |
| repo_sha | TBD |
| generator_context_id | TBD |
| input_source_hash | TBD |
| materialized_pbi_hash | TBD |
| materialized_pbi_path | TBD |
| skill_hash | TBD |
| references_manifest_hash | TBD |
| model_id | TBD |
| effort | TBD |
| tool_policy | TBD |
| budget | TBD |
| started_at | TBD |
| completed_at | TBD |
| raw_output_ref | TBD |
| raw_output_hash | TBD |
| rubric_visible_to_generator | false/TBD |
| variant_identity_verified | true/false |
| activation_evidence | TBD |
| contamination | none/TBD |
| missing_data | none/TBD |

## Blind scoring record

| Field | Value |
| --- | --- |
| pair_id | TBD |
| anonymous_output_id | TBD |
| reviewer | TBD |
| current_need | PASS/FAIL/N_A/INCONCLUSIVE |
| contract_source | PASS/FAIL/N_A/INCONCLUSIVE |
| verification_strategy | PASS/FAIL/N_A/INCONCLUSIVE |
| conditional_guidance | PASS/FAIL/N_A/INCONCLUSIVE |
| b2_comparison | PASS/FAIL/N_A/INCONCLUSIVE |
| scope_honesty | PASS/FAIL/N_A/INCONCLUSIVE |
| output_load | PASS/FAIL/N_A/INCONCLUSIVE |
| stop_validity | PASS/FAIL/N_A/INCONCLUSIVE |
| critical_regression | true/false/unknown |
| evidence_refs | TBD |
| rationale | TBD |

## Completion boundary

このtemplateの作成、input/rubric固定、CI successは **評価効果の証明ではない**。

#1337をcloseできるのは、少なくとも:
1. 48 generationのrun recordsが揃う、または未実行理由を明示してACを再スコープする
2. blind scoringが完了
3. pair-level結果が Improvement / Regression / No demonstrated difference / INCONCLUSIVE に分類
4. raw evidenceと判定理由が保存
5. 次施策が決定

した後。

## 記録と再試行の補足

- 生成status（NOT_RUN / GENERATED / REVIEWED / ERROR / BLOCKED）と採点verdictは別項目。未実行・未記入を0／PASSに変換しない。
- provider error / timeout / output打切りは欠測。完成したFAIL出力は除外しない。
- retryが必要なら理由を保存し、pair全体を新run setへ移す。旧証跡を上書きしない。
- budgetは1試行のinput/output上限に加え、総額または総token上限と単位を固定する。
- context manifestに実際に読み込んだ全参照のpath・SHA256・repo SHA・読取証跡を残す。「読みました」という自己申告だけではactivation成立としない。
- PDP-01はPlan/ToDo/Test Cases本文のUnicode文字数・空セクション数・無関係test数を分けて記録。未取得は空欄と理由を記録する。
