"""Read-only exported feedback validation: valid and malicious fixtures."""
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from validate_plan_feedback import validate_feedback


class FeedbackValidationTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.plan = self.root / "plan.md"
        self.plan.write_text("# plan\n", encoding="utf8")
        self.questions_file = self.root / "review-questions.json"
        self.questions_file.write_text(json.dumps({
            "version": 1,
            "questions": [
                {"id": "Q-1", "prompt": "Choose", "choices": ["Canary", "Flag"]},
                {"id": "Q-2", "prompt": "Explain"}
            ]
        }), encoding="utf8")
        self.feedback_file = self.root / "feedback.json"
        self.payload = {
            "schemaVersion": 1,
            "kind": "plan-review-feedback",
            "taskId": "TASK-0001",
            "source": {
                "plan": {"path": "plan.md", "sha256": self.digest(self.plan)},
                "questions": {"path": "review-questions.json", "sha256": self.digest(self.questions_file)}
            },
            "feedback_only": True,
            "approval_granted": False,
            "generatedAt": "2026-10-08T09:00:00.000Z",
            "answers": [
                {"questionId": "Q-1", "status": "answered", "response": "Canary", "note": ""},
                {"questionId": "Q-2", "status": "deferred", "response": "", "note": "Need evidence"}
            ]
        }
        self.save()

    @staticmethod
    def digest(path):
        return hashlib.sha256(path.read_bytes()).hexdigest()

    def save(self):
        self.feedback_file.write_text(json.dumps(self.payload), encoding="utf8")

    def validate(self):
        return validate_feedback(self.root, "TASK-0001", self.feedback_file)

    def test_valid_sidecar_remains_non_authoritative(self):
        result = self.validate()
        self.assertEqual(result["status"], "VALID_REVIEW_FEEDBACK")
        self.assertEqual(result["counts"], {"answered": 1, "deferred": 1, "unanswered": 0})
        self.assertFalse(result["approval_granted"])
        self.assertTrue(result["feedback_only"])

    def test_unanswered_empty_is_allowed(self):
        self.payload["answers"][1] = {
            "questionId": "Q-2", "status": "unanswered", "response": "", "note": ""
        }
        self.save()
        self.assertEqual(self.validate()["counts"]["unanswered"], 1)

    def test_source_plan_change_invalidates(self):
        self.plan.write_text("# new plan\n", encoding="utf8")
        with self.assertRaisesRegex(ValueError, "stale source"):
            self.validate()

    def test_source_questions_change_invalidates(self):
        self.questions_file.write_text('{"version":1,"questions":[]}', encoding="utf8")
        with self.assertRaisesRegex(ValueError, "stale source"):
            self.validate()

    def test_wrong_source_path_rejected(self):
        self.payload["source"]["plan"]["path"] = "../../etc/passwd"
        self.save()
        with self.assertRaisesRegex(ValueError, "source path"):
            self.validate()

    def test_forged_approval_rejected(self):
        self.payload["approval_granted"] = True
        self.save()
        with self.assertRaisesRegex(ValueError, "non-authoritative"):
            self.validate()

    def test_wrong_task_rejected(self):
        self.payload["taskId"] = "TASK-0002"
        self.save()
        with self.assertRaisesRegex(ValueError, "task mismatch"):
            self.validate()

    def test_choice_outside_definition_rejected(self):
        self.payload["answers"][0]["response"] = "Delete production"
        self.save()
        with self.assertRaisesRegex(ValueError, "allowed choices"):
            self.validate()

    def test_duplicate_answer_rejected(self):
        self.payload["answers"][1]["questionId"] = "Q-1"
        self.save()
        with self.assertRaisesRegex(ValueError, "duplicate"):
            self.validate()

    def test_unknown_status_rejected(self):
        self.payload["answers"][0]["status"] = "approved"
        self.save()
        with self.assertRaisesRegex(ValueError, "status"):
            self.validate()

    def test_missing_note_rejected(self):
        self.payload["answers"][1]["note"] = ""
        self.save()
        with self.assertRaisesRegex(ValueError, "reason note"):
            self.validate()

    def test_unknown_json_property_rejected(self):
        self.payload["verified"] = True
        self.save()
        with self.assertRaisesRegex(ValueError, "structure"):
            self.validate()

    def test_duplicate_json_property_rejected(self):
        self.feedback_file.write_text(
            '{"schemaVersion":1,"schemaVersion":1}', encoding="utf8"
        )
        with self.assertRaisesRegex(ValueError, "feedback JSON"):
            self.validate()

    def test_symlinked_plan_rejected(self):
        path = self.root / "original-plan.md"
        self.plan.rename(path)
        try:
            self.plan.symlink_to(path)
        except (OSError, NotImplementedError):
            self.skipTest("symlink unavailable")
        with self.assertRaisesRegex(ValueError, "regular file"):
            self.validate()

    def test_oversized_input_rejected(self):
        self.feedback_file.write_bytes(b" " * (512 * 1024 + 1))
        with self.assertRaisesRegex(ValueError, "too large"):
            self.validate()

    def test_cli_positive_and_fail_closed(self):
        exe = Path(__file__).resolve().parents[1] / "scripts" / "validate_plan_feedback.py"
        cmd = [sys.executable, str(exe), "--task", "TASK-0001",
               "--work-dir", str(self.root), "--feedback", str(self.feedback_file)]
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["status"], "VALID_REVIEW_FEEDBACK")
        self.payload["approval_granted"] = True
        self.save()
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, "")
        self.assertIn("invalid", result.stderr)


if __name__ == "__main__":
    unittest.main()
