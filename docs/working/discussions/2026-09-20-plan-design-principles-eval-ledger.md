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
- generator input hash
- baseline skill hash
- candidate skill hash
- baseline bundled-reference manifest/hash
- candidate bundled-reference manifest/hash
- independent reviewer identity/role
- raw output保存先
- rubric version/hash

## Sandbox / contamination controls

Generatorに見せてよい:
- generator inputs
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

## Run manifest

| Field | Value |
| --- | --- |
| eval_version | PDP-EVAL-v1 |
| model_id | TBD |
| effort | TBD |
| max_input_tokens | TBD |
| max_output_tokens | TBD |
| timeout_seconds | TBD |
| tool_policy | TBD |
| network | off |
| input_ref | `2026-09-20-plan-design-principles-eval-inputs.md` |
| input_hash | TBD |
| rubric_ref | `2026-09-20-plan-design-principles-eval-rubric.md` |
| rubric_hash | TBD |
| reviewer | TBD |
| adjudicator | TBD |
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
| input_hash | TBD |
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
