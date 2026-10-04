# TASK-1442 — Historical Admission Oracle

> Scope: delivery-target PBI admission shadow evaluation.  
> Evidence class: `historical_replay`.  
> This oracle does not authorize Issue/PBI closure, mutation, or automatic write.

## AD-006 — clean legacy run 006

Evidence:
- `docs/working/ai-loop-runs/20260707T055726Z-7703b50-run006-final.json`
- observed: `AUTO_APPROVED`, boundary clean, both reviewers approve, no reject category

Reviewed admission expectation:
- `no_action`

Rationale:
- the record contains no new reviewer/failure signal requiring follow-up delivery work;
- `no_action` means "do not materialize a new PBI from this signal", not "close existing work";
- this is an observed historical record, not a reported/inferred summary.

## AD-010 — legacy run 010 test-shortage signal

Evidence:
- `docs/working/ai-loop-runs/20260707T073726Z-e752626-run010-final.json`
- observed: overall `AUTO_APPROVED`, while `model_b=reject`, `reject_category=test_shortage`, severity minor

Reviewed admission expectation:
- `materialize`

Rationale:
- the record contains a concrete reviewer follow-up signal;
- admission does not claim the historical run was invalid;
- materialization remains shadow/read-only.

## Limitations

- `discover_more` is not represented in this historical corpus.
- These are historical replays, not live shadow observations.
- Oracle independence is not enforced; this artifact lives in the same repository.
- Admission disposition labels were reviewed for this corpus and are not automatically derived from arbitrary RunEvidence.
