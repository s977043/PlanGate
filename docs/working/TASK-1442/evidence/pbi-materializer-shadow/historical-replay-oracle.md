# TASK-1442 — Historical Replay Oracle

> Scope: delivery-target PBI materializer shadow evaluation.  
> Evidence class: `historical_replay`.  
> This is not live-shadow evidence and does not authorize automatic writes.

## HR-010 — legacy run 010 / test_shortage

Evidence:
- `docs/working/ai-loop-runs/20260707T073726Z-e752626-run010-final.json`
- observed: overall `AUTO_APPROVED`, while `model_b=reject`, `reject_category=test_shortage`, severity minor

Reviewed expectation:
- materialization decision: `create_new`
- matched ref: none
- readiness: `ready / future_run`

Rationale:
- the historical record contains a concrete reviewer signal that can be retained as follow-up delivery work;
- the replay does not claim the historical run was wrong or reopen it;
- no existing PBI candidate is injected into this replay.

## HR-012 — legacy run 012 / logic escalation

Evidence:
- `docs/working/ai-loop-runs/20260707T092419Z-9d7af43-run012-r3.json`
- observed: `HUMAN_ESCALATED`, `model_b=reject`, `model_c=reject`, `reject_category=logic`, severity minor

Reviewed expectation:
- materialization decision: `create_new`
- matched ref: none
- readiness: `ready / future_run`

Rationale:
- the historical record contains an explicit logic-quality escalation signal;
- the replay packages that signal as future delivery work only;
- it does not infer a Harness change or bypass the historical Human escalation.

## Limitations

- Both cases are positive materialization examples.
- Neither case tests a `no_action` admission decision; the current materializer receives already-admitted PBI payloads.
- Neither case is `live_shadow`.
- Both expected outcomes were reviewed in the same repository context; independent oracle isolation is **not** claimed.
- Harness replay remains owned by #874/#869 Candidate/Evolution flow.
