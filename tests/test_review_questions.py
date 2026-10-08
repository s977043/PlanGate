"""Regression tests for the optional feedback widget."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from review_questions import JS, render_review_questions


class PlanFeedbackTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        (self.root / "plan.md").write_text("# Plan\n", encoding="utf8")

    def put(self, questions):
        (self.root / "review-questions.json").write_text(
            json.dumps({"version": 1, "questions": questions}), encoding="utf8"
        )

    def test_absent_is_backward_compatible(self):
        self.assertEqual("", render_review_questions(self.root, "TASK-0001"))

    def test_escaping_digest_and_nonapproval(self):
        self.put([{"id": "Q-1", "prompt": "<script>alert(1)</script>",
                   "choices": ['A"<img>', "B"], "artifactRefs": ["plan.md#risk"]}])
        output = render_review_questions(self.root, "TASK-0001")
        self.assertNotIn("<script>alert(1)</script>", output)
        self.assertIn("&lt;script&gt;", output)
        self.assertIn("approval_granted: false", output)
        self.assertIn("feedback_only: true", output)
        self.assertIn(hashlib.sha256((self.root / "plan.md").read_bytes()).hexdigest(), output)

    def test_duplicate_rejected(self):
        self.put([{"id": "Q", "prompt": "one"}, {"id": "Q", "prompt": "two"}])
        with self.assertRaises(ValueError):
            render_review_questions(self.root, "TASK-0001")

    def test_invalid_version_rejected(self):
        (self.root / "review-questions.json").write_text('{"version":true,"questions":[]}')
        with self.assertRaises(ValueError):
            render_review_questions(self.root, "TASK-0001")

    def test_missing_plan_rejected(self):
        self.put([{"id": "Q", "prompt": "one"}])
        (self.root / "plan.md").unlink()
        with self.assertRaises(ValueError):
            render_review_questions(self.root, "TASK-0001")

    def test_oversized_rejected(self):
        (self.root / "review-questions.json").write_bytes(b"z" * 131073)
        with self.assertRaises(ValueError):
            render_review_questions(self.root, "TASK-0001")

    def test_reject_duplicate_json_properties(self):
        (self.root / "review-questions.json").write_text(
            '{"version":1,"version":1,"questions":[{"id":"Q","prompt":"x"}]}',
            encoding="utf8"
        )
        with self.assertRaises(ValueError):
            render_review_questions(self.root, "TASK-0001")

    def test_deferred_requires_note_and_nonapproval_is_explicit(self):
        self.put([{"id": "Q", "prompt": "Choose", "choices": ["A", "B"]}])
        content = render_review_questions(self.root, "TASK-0001")
        self.assertIn("data-note", content)
        self.assertIn('state === "deferred" && !note', content)
        self.assertIn('state !== "answered" && response', content)
        self.assertIn("approval_granted: false", content)

    def test_render_cli_with_questions_and_bad_input(self):
        import subprocess
        renderer = Path(__file__).resolve().parents[1] / "scripts" / "render_review.py"
        self.put([{"id": "Q1", "prompt": "What is next?"}])
        out = self.root / "rendered.html"
        command = [sys.executable, str(renderer), "--task", "TASK-0001",
                   "--work-dir", str(self.root), "--out", str(out)]
        success = subprocess.run(command, capture_output=True, text=True, check=False)
        self.assertEqual(0, success.returncode, success.stderr)
        self.assertIn("pg-plan-feedback", out.read_text(encoding="utf8"))

        (self.root / "review-questions.json").write_text("{broken", encoding="utf8")
        out.unlink()
        failure = subprocess.run(command, capture_output=True, text=True, check=False)
        self.assertEqual(2, failure.returncode)
        self.assertIn("invalid review questions", failure.stderr)
        self.assertFalse(out.exists())

    def test_export_json_trailing_newline_and_js_syntax(self):
        # A literal backslash-n after the closing brace would make the
        # downloaded file invalid JSON. Check the exact JS source sequence.
        self.assertIn('JSON.stringify(feedback, null, 2) + "\\n"', JS)
        self.assertNotIn('JSON.stringify(feedback, null, 2) + "\\\\n"', JS)
        import shutil
        import subprocess
        if shutil.which("node") is None:
            self.skipTest("node not available for JavaScript syntax validation")
        script = self.root / "feedback.js"
        script.write_text(JS.replace(
            "__META__", '{"taskId":"TASK-0001","source":{}}'
        ).replace("<script>", "").replace("</script>", ""), encoding="utf8")
        process = subprocess.run(["node", "--check", str(script)],
                                 capture_output=True, text=True, check=False)
        self.assertEqual(0, process.returncode, process.stderr)

    def test_export_roundtrip_with_node_dom_shim(self):
        """Browser-independent JS smoke: the exported Blob must contain valid JSON."""
        import shutil
        import subprocess
        if shutil.which("node") is None:
            self.skipTest("node not available for JS roundtrip")
        js_file = self.root / "feedback.js"
        js_file.write_text(JS.replace(
            "__META__",
            '{"taskId":"TASK-0001","source":{"plan":{"sha256":"abc"}}}'
        ).replace("<script>", "").replace("</script>", ""), encoding="utf8")
        harness = self.root / "browser-smoke.cjs"
        harness.write_text(r"""
const fs = require("node:fs");
const vm = require("node:vm");
let listener;
let capturedBlob;
let downloaded = false;
const status = {value: "answered", focus() {}};
const answer = {value: "Canary"};
const note = {value: ""};
const row = {
  getAttribute(name) { return name === "data-question-id" ? "Q-1" : null; },
  querySelector(selector) {
    return {"[data-state]": status, "[data-response]": answer,
            "[data-note]": note}[selector];
  }
};
const message = {textContent: ""};
const exportButton = {addEventListener(event, fn) {
  if (event !== "click") throw new Error("wrong event");
  listener = fn;
}};
const panel = {
  querySelector(selector) {
    return {"[data-message]": message, "[data-export]": exportButton}[selector];
  },
  querySelectorAll() { return [row]; }
};
const document = {
  getElementById() { return panel; },
  createElement() { return {click() {downloaded = true;}}; }
};
const URL = {
  createObjectURL(blob) {capturedBlob = blob; return "blob:fake";},
  revokeObjectURL() {}
};
vm.runInNewContext(fs.readFileSync(process.argv[2], "utf8"), {
  document, URL, Blob, Date, requestAnimationFrame(callback) {callback();}
});
if (typeof listener !== "function") throw new Error("no click listener");
listener();
if (!downloaded || !capturedBlob) throw new Error("nothing downloaded");
capturedBlob.text().then(text => {
  const value = JSON.parse(text);
  if (value.kind !== "plan-review-feedback" ||
      value.feedback_only !== true || value.approval_granted !== false ||
      value.answers[0].status !== "answered" ||
      value.answers[0].response !== "Canary") {
    throw new Error("invalid export structure");
  }
}).catch(error => {console.error(error); process.exitCode = 1;});
""", encoding="utf8")
        result = subprocess.run(["node", str(harness), str(js_file)],
                                capture_output=True, text=True, check=False)
        self.assertEqual(0, result.returncode, result.stderr)

    def test_bad_identifier_rejected(self):
        self.put([{"id": 'x"><img>', "prompt": "one"}])
        with self.assertRaises(ValueError):
            render_review_questions(self.root, "TASK-0001")


if __name__ == "__main__":
    unittest.main()
