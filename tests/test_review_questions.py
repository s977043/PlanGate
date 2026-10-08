"""Regression tests for the optional feedback widget."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from review_questions import render_review_questions


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

    def test_bad_identifier_rejected(self):
        self.put([{"id": 'x"><img>', "prompt": "one"}])
        with self.assertRaises(ValueError):
            render_review_questions(self.root, "TASK-0001")


if __name__ == "__main__":
    unittest.main()
