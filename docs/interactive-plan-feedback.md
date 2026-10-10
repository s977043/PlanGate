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
- Browser download and keyboard smoke is covered in Chrome/Chromium by #1542.
  The extended matrix checks `file://`, focus/labels, synthetic 50-question
  desktop/mobile layout, print media and attempted network requests.
  A self-contained `file://` page has no HTTP CSP response header. This
  **does not claim a CSP enforcement audit** or a native screen-reader test.

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
The browser smoke probes `--version` and records the exact executable path and
reported browser version in the CI test log; it fails if that evidence is missing.
Local tests report an explicit skip if a browser is not installed.
GitHub's isolated hosted test runner sets `PLANGATE_CHROME_NO_SANDBOX=1`
because its Chrome user-namespace sandbox cannot initialize. The test page
uses fixed local fixtures only. Local non-root runs keep sandboxing enabled
unless the operator explicitly opts in to this compatibility flag.
No external requests or third-party browser-test dependencies are needed.
## Persistent download and keyboard E2E (#1535)

An additional Chrome DevTools Protocol test uses a real browser download,
not an intercepted anchor. The test enables downloads into a temporary
directory and reads the saved JSON file from disk. It then calls the
existing PlanGate validator with the current local plan and questions.

~~~sh
python3 -m unittest discover -s tests -p test_review_feedback_chromium.py -v
~~~

This test uses Node.js 22's built-in WebSocket API, the Chrome/Chromium
binary and local DevTools endpoints. It does not require Playwright,
Selenium, a CDN, or a network service. The test checks keyboard Tab focus
from the question status field to the response field.

The isolated GitHub Actions runner explicitly sets the Chrome sandbox
compatibility flag described above. Local non-root tests retain sandboxing.
File-download persistence is an E2E observation, not user approval.
## Extended browser evidence (#1524)

The optional 50-question matrix creates **synthetic-only** C-3 files. Chrome
opens the generated HTML using a real `file://` URL (no web server).
The DevTools protocol checks per-control associated labels, keyboard Tab
focus, AX-tree export button name, real responsive widths (1280/375 px),
print-mode button visibility, inert XSS strings, and attempted HTTP(S) or
WebSocket requests. Desktop/mobile screenshots and machine-readable metrics
are retained as short-lived GitHub Actions test artifacts (7 days).

~~~sh
python3 -m unittest discover -s tests -p test_review_feedback_browser_matrix.py -v
~~~

Browser E2E is evidence for these bounded assertions, **not** a complete WCAG
or human screen-reader audit, a firewall proof or a Firefox functional test.
The absence of a CSP HTTP header for a local file does not mean CSP was
exercised. Do not claim cross-browser or CSP verification without separate
evidence. Generated reviews may include sensitive business plans; only
synthetic fixtures are captured or uploaded by CI.

## Follow-ups

See River Review #2577 for optional validator/importer and read-only
projection into the existing Decision Surface / Review Resolution contracts.
The River Review Phase A-C read-only projection and opt-in CLI were merged
through #2584, #2620, and #2621. See River Review #2577/#2601 for the
non-authoritative trust boundary.
