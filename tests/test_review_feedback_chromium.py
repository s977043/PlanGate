"""True Chromium DOM/Blob smoke test for the opt-in PlanGate review panel.

Uses only a local Chrome/Chromium executable. No external URL, CDN, or
Playwright dependency. The final anchor download click is intercepted because
headless --dump-dom cannot inspect the browser's download directory.
"""
import html
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BROWSER_CANDIDATES = ("chromium", "chromium-browser", "google-chrome", "google-chrome-stable")


class ChromiumPlanFeedbackTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.browser = next((shutil.which(exe) for exe in BROWSER_CANDIDATES if shutil.which(exe)), None)
        if cls.browser is None:
            raise unittest.SkipTest("real Chromium/Chrome unavailable; E2E not verified")

    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.dir = Path(temp.name)
        (self.dir / "plan.md").write_text("# Goal\nRelease safely.\n", encoding="utf8")
        (self.dir / "review-questions.json").write_text(json.dumps({
            "version": 1,
            "questions": [
                {
                    "id": "Q1",
                    "prompt": 'Choose <script>window.pwned=1</script>',
                    "choices": ["Canary", "Flag"]
                },
                {"id": "Q2", "prompt": "Why defer?"}
            ]
        }), encoding="utf8")

        self.page = self.dir / "page.html"
        render = subprocess.run(
            [sys.executable, str(ROOT / "scripts" / "render_review.py"),
             "--task", "TASK-0001", "--work-dir", str(self.dir),
             "--out", str(self.page)],
            capture_output=True, text=True, check=False,
            timeout=20
        )
        self.assertEqual(render.returncode, 0, render.stderr)

    def run_chromium(self, invalid=False):
        script = r"""<script>
(() => {
  const originalCreateElement = document.createElement.bind(document);
  let blob = null;
  let clicked = false;
  document.createElement = (tag) => {
    if (String(tag).toLowerCase() === "a") {
      return {href: "", download: "", click() {clicked = true;}};
    }
    return originalCreateElement(tag);
  };
  URL.createObjectURL = value => {blob = value; return "blob:mock";};
  URL.revokeObjectURL = () => {};
  const rows = document.querySelectorAll('[data-question-id]');
  const q1 = rows[0], q2 = rows[1];
  q1.querySelector('[data-state]').value = "answered";
  q1.querySelector('[data-response]').value = "Canary";
  q2.querySelector('[data-state]').value = "deferred";
  q2.querySelector('[data-note]').value = __NOTE__;
  document.querySelector('[data-export]').click();

  function finish(payload) {
    const marker = originalCreateElement("pre");
    marker.id = "browser-feedback-e2e-result";
    marker.textContent = JSON.stringify(payload);
    document.body.appendChild(marker);
  }
  if (!blob) {
    finish({download: clicked, warning: document.querySelector('[data-message]').textContent});
  } else {
    blob.text().then(text => {
      try {
        finish({
          download: clicked,
          result: JSON.parse(text),
          injected: window.pwned === 1
        });
      } catch (error) {
        finish({error: "invalid JSON export: " + error.message});
      }
    }).catch(error => finish({error: String(error)}));
  }
})();
</script>
""".replace("__NOTE__", '""' if invalid else '"Need evidence"')
        test_page = self.page.read_text(encoding="utf8").replace("</body></html>", script + "</body></html>")
        self.page.write_text(test_page, encoding="utf8")
        cmd = [self.browser, "--headless", "--no-sandbox", "--disable-gpu",
               "--disable-dev-shm-usage", "--disable-background-networking",
               "--no-first-run", "--no-default-browser-check",
               "--virtual-time-budget=3000", "--dump-dom", self.page.as_uri()]
        proc = subprocess.run(cmd, capture_output=True, text=True, check=False,
                              timeout=30, env={**os.environ, "HOME": str(self.dir)})
        self.assertEqual(proc.returncode, 0, proc.stderr[-3000:])
        match = re.search(
            r'<pre id="browser-feedback-e2e-result">([^<]+)</pre>', proc.stdout
        )
        self.assertIsNotNone(match, "Chromium did not finish browser feedback smoke")
        return json.loads(html.unescape(match.group(1)))

    def test_real_browser_exports_valid_review_only_json(self):
        result = self.run_chromium()
        self.assertNotIn("error", result)
        self.assertTrue(result["download"])
        self.assertFalse(result["injected"])
        payload = result["result"]
        self.assertEqual(payload["kind"], "plan-review-feedback")
        self.assertTrue(payload["feedback_only"])
        self.assertFalse(payload["approval_granted"])
        self.assertEqual(payload["answers"][0]["response"], "Canary")
        self.assertEqual(payload["answers"][1]["status"], "deferred")
        self.assertEqual(payload["answers"][1]["note"], "Need evidence")
        self.assertEqual(len(payload["source"]["plan"]["sha256"]), 64)

    def test_real_browser_prevents_defer_without_reason(self):
        result = self.run_chromium(invalid=True)
        self.assertFalse(result["download"])
        self.assertIn("一致しません", result["warning"])


if __name__ == "__main__":
    unittest.main()
