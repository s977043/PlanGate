"""Real file:// Chrome browser matrix for 50 synthetic PlanGate review questions."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BROWSER_NAMES = ("chromium", "chromium-browser", "google-chrome", "google-chrome-stable")


class BrowserMatrixTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.browser = next((shutil.which(b) for b in BROWSER_NAMES if shutil.which(b)), None)
        if cls.browser is None:
            raise unittest.SkipTest("real Chrome/Chromium missing: browser matrix unverified")
        version = subprocess.run(
            [cls.browser, "--version"], capture_output=True, text=True,
            check=False, timeout=10,
        )
        if version.returncode != 0 or not (version.stdout.strip() or version.stderr.strip()):
            raise AssertionError("unable to identify browser: " + version.stderr)
        print(
            "Browser matrix binary=%r version=%r" %
            (cls.browser, version.stdout.strip() or version.stderr.strip()),
            flush=True,
        )

    def test_file_page_offline_accessibility_responsive_print_and_xss(self):
        if not shutil.which("node"):
            self.skipTest("Node 22 native WebSocket required for local CDP")
        with tempfile.TemporaryDirectory() as workspace:
            base = Path(workspace)
            questions = []
            for i in range(50):
                q = {"id": "Q-%02d" % (i + 1), "prompt": "Question %d" % (i + 1)}
                if i == 0:
                    q["prompt"] = '<script>window.pwned=1</script> Should we ship?'
                    q["choices"] = ["Canary", '<img src=x onerror="window.hacked=1">']
                    q["artifactRefs"] = ['<svg onload="window.injected=1">']
                elif i % 2:
                    q["choices"] = ["Canary", "Feature flag"]
                questions.append(q)
            (base / "plan.md").write_text(
                "# Goal\nSafe synthetic review fixture, without credentials.\n",
                encoding="utf8",
            )
            (base / "review-questions.json").write_text(
                json.dumps({"version": 1, "questions": questions}),
                encoding="utf8",
            )
            html = base / "TASK-0001-review.html"
            command = [
                sys.executable, str(ROOT / "scripts" / "render_review.py"),
                "--task", "TASK-0001", "--work-dir", str(base), "--out", str(html),
            ]
            render = subprocess.run(
                command, capture_output=True, text=True, check=False, timeout=25,
            )
            self.assertEqual(render.returncode, 0, render.stderr)
            self.assertTrue(html.is_file())

            evidence = Path(os.environ.get("PLANGATE_BROWSER_EVIDENCE_DIR", str(base / "evidence")))
            evidence.mkdir(parents=True, exist_ok=True)
            helper = ROOT / "tests" / "browser_feedback_matrix_cdp.mjs"
            run = subprocess.run(
                ["node", str(helper), self.browser, html.as_uri(), str(evidence)],
                capture_output=True, text=True, check=False,
                env={**os.environ, "HOME": str(base)}, timeout=80,
            )
            self.assertEqual(run.returncode, 0, run.stderr[-6000:])
            result = json.loads(run.stdout.strip())
            self.assertTrue(result["passed"])
            self.assertTrue(result["sourceIsLocalFile"])
            self.assertEqual(result["count"], 50)
            self.assertEqual(result["unlabeled"], 0)
            self.assertTrue(result["browserAXButton"])
            self.assertTrue(result["keyboardTabThroughThreeControls"])
            self.assertTrue(result["printButtonHidden"])
            self.assertTrue(result["keyboardEnterDownloadPersisted"])
            self.assertEqual(result["unansweredExportCount"], 50)
            self.assertEqual(result["attemptedNetworkRequests"], [])
            sys.path.insert(0, str(ROOT / "scripts"))
            from validate_plan_feedback import validate_feedback
            export = evidence / "TASK-0001-review-feedback.json"
            self.assertTrue(export.is_file())
            report = validate_feedback(base, "TASK-0001", export)
            self.assertFalse(report["approval_granted"])
            self.assertEqual(report["counts"]["unanswered"], 50)
            self.assertEqual([v["name"] for v in result["responsive"]], ["desktop", "mobile"])
            for filename in ("desktop-synthetic.png", "mobile-synthetic.png", "matrix-results.json"):
                self.assertTrue((evidence / filename).is_file(), filename)

    def test_questions_absent_and_malformed_fail_closed(self):
        with tempfile.TemporaryDirectory() as workspace:
            base = Path(workspace)
            (base / "plan.md").write_text("# Minimal synthetic plan\n", encoding="utf8")
            html = base / "TASK-0001-review.html"
            command = [
                sys.executable, str(ROOT / "scripts" / "render_review.py"),
                "--task", "TASK-0001", "--work-dir", str(base), "--out", str(html),
            ]
            absent = subprocess.run(
                command, capture_output=True, text=True, check=False, timeout=25,
            )
            self.assertEqual(absent.returncode, 0, absent.stderr)
            self.assertNotIn("pg-plan-feedback", html.read_text(encoding="utf8"))
            html.unlink()
            (base / "review-questions.json").write_text("{invalid", encoding="utf8")
            malformed = subprocess.run(
                command, capture_output=True, text=True, check=False, timeout=25,
            )
            self.assertNotEqual(malformed.returncode, 0)
            self.assertFalse(html.exists(), "failed renderer must not produce success HTML")


if __name__ == "__main__":
    unittest.main()
