# Interactive Plan Feedback (opt-in)

Tracking: PlanGate #1521, River Review #2577. Reuses existing HTML render #547/#549.

## Why and boundaries

The generated HTML is a *review surface*, not the authoritative plan or an
approval record. The canonical content remains plan.md and existing C-3
approval evidence. This feature does not alter the C-3 decision, gate, plan
hash checks, or automatic execution. No third-party html-plan code is copied.

## Input

Place a file named review-questions.json next to plan.md under
docs/working/TASK-XXXX, with explicit questions. Example:

~~~json
{
  "version": 1,
  "questions": [
    {
      "id": "Q-1",
      "prompt": "Which rollout plan should be used?",
      "choices": ["Feature flag", "Canary", "Rollback first"],
      "artifactRefs": ["plan.md#rollout"]
    },
    {
      "id": "Q-2",
      "prompt": "What evidence should be required for acceptance?",
      "artifactRefs": ["test-cases.md#AC-1"]
    }
  ]
}
~~~

Run the existing renderer:

~~~sh
plangate render TASK-XXXX --html
# equivalent standalone renderer
python3 scripts/render_review.py --task TASK-XXXX
~~~

When review-questions.json is missing, the interactive section is omitted
without changing the prior page. When present, each question offers
unanswered (default), answered, or deferred states. A deferred question
requires an explicit note and must not retain an answer. Optional choices are
a single-select; without choices an accessible textarea is presented.

Export downloads a local TASK-XXXX-review-feedback.json, containing:

- schemaVersion (1), kind (plan-review-feedback), taskId
- source.plan.sha256 and source.questions.sha256
- answers: questionId, status, response, note
- feedback_only: true and approval_granted: false
- generatedAt

No HTTP request, storage API, CDN, or third-party dependency is used. The
page is self-contained; it does not modify the plan, approval log, or River
Review finding status.

## Validation and threat model

- Only explicit JSON questions are rendered; there is no inferred approval
  or LLM-generated question extraction.
- Non-UTF-8, malformed JSON, wrong versions, duplicate IDs, unknown fields,
  oversized inputs and symlinks fail closed. A question requires plan.md.
- User-derived strings are HTML-escaped before rendering; embedded metadata
  is JSON-encoded with angle brackets and ampersands escaped.
- Exports are not trusted blindly. A future importer must verify the source
  SHA-256 values against the exact current files and question IDs against
  the question definition, including any approval-context checks.
- Never accept unanswered/deferred entries as approval, or a feedback JSON
  as independent review or a verification result.
- The HTML contains local plan content. Avoid distributing internal
  plans, credentials, or the feedback file without redaction.
- Browser interaction (download, keyboard navigation, CSP behavior) needs
  a real-browser validation before being represented as E2E tested.

## Tests

~~~sh
python3 -m unittest discover -s tests -p test_review_questions.py
~~~

## Follow-ups

See River Review #2577 for optional validator/importer and read-only
projection into the existing Decision Surface / Review Resolution contracts.
None of those are implied by this initial HTML-only slice.
