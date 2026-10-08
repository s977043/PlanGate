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

## Optional local feedback validation (#1533)

An exported JSON file is untrusted until checked against the **current**
task files. Run the standalone validator before discussing its contents:

~~~sh
python3 scripts/validate_plan_feedback.py --task TASK-XXXX \
  --feedback docs/working/TASK-XXXX/TASK-XXXX-review-feedback.json
~~~

You may pass `--work-dir PATH` if the task folder is elsewhere. Success
prints `VALID_REVIEW_FEEDBACK` with answer counts and explicit
`approval_granted: false`; errors exit 2 and produce no success JSON.

Validation requires exact source SHA-256 hashes and question IDs. It
rejects unsupported fields, duplicate JSON properties, missing answers,
malformed statuses, forged approval, and stale or symlinked source files.
Choices must match the local question definitions. Deferred answers
require a reason; unanswered entries must remain empty.

Source hash matching proves file freshness at validation time, **not**
reviewer identity or authorization. This validator does not import or
write feedback, modify PlanGate C-3 approval, or change River Review gate.

~~~sh
python3 -m unittest discover -s tests -p test_validate_plan_feedback.py -v
~~~
## Browser E2E smoke (#1535)

The optional browser smoke executes the generated HTML in a real
Chrome/Chromium renderer. It verifies DOM interaction, response
validation, SHA-256 metadata, escaped input, and exported Blob JSON.
The test intercepts the anchor click to inspect Blob content; it does
**not** claim the browser wrote a file into a downloads folder.

~~~sh
python3 -m unittest discover -s tests -p test_review_feedback_chromium.py -v
~~~

The CI job requires Chrome/Chromium and fails if it is unavailable.
Local tests report an explicit skip if a browser is not installed.
GitHub's isolated hosted test runner sets `PLANGATE_CHROME_NO_SANDBOX=1`
because its Chrome user-namespace sandbox cannot initialize. The test page
uses fixed local fixtures only. Local non-root runs keep sandboxing enabled
unless the operator explicitly opts in to this compatibility flag.
No external requests or third-party browser-test dependencies are needed.
## Follow-ups

See River Review #2577 for optional validator/importer and read-only
projection into the existing Decision Surface / Review Resolution contracts.
None of those are implied by this initial HTML-only slice.
