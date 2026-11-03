"""Offline distribution/guidance regression, not a live Plugin or approval test."""
import pathlib
import shutil
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SKILL = pathlib.Path('skills/ai-dev-verify/SKILL.md')


class VerifyPluginGuidanceTest(unittest.TestCase):
    def test_applicability_precedes_doctor_requirement(self):
        text = (ROOT / '.agents' / SKILL).read_text()
        section = text.split('## settings タスクロック', 1)[1].split('## handoff.md', 1)[0]
        table = section.index('| 作業対象・配布状態 |')
        requirement = section.index('PASS を **V-1 / handoff 完了の前提**')
        self.assertLess(table, requirement)
        self.assertIn('CLI 不在でも `N/A` へ降格しない', section)
        self.assertIn('非配布を推測せず', section)
        self.assertIn('完了扱いにせず判断を求める', section)
        self.assertIn('`N/A` は PASS ではなく', section)

    def test_mirrors_agree(self):
        source = (ROOT / '.agents' / SKILL).read_bytes()
        for root in (ROOT / '.codex', ROOT / 'plugin/plangate'):
            self.assertEqual(source, (root / SKILL).read_bytes())

    def test_isolated_distribution_has_references_but_no_enforcement(self):
        # Copy product distribution only. No consumer data, settings, or approval.
        with tempfile.TemporaryDirectory() as tmp:
            package = pathlib.Path(tmp) / 'plugin'
            shutil.copytree(ROOT / 'plugin/plangate', package)
            self.assertFalse((package / 'bin/plangate').exists())
            self.assertFalse((package / 'scripts/hooks/check-plan-hash.sh').exists())
            self.assertFalse(any((package / 'hooks').glob('*.sh')))
            for name in ('handoff.md', 'settings-wiring-contract.md', 'c3-prime-contract.md'):
                self.assertTrue((package / SKILL.parent / 'references' / name).is_file(), name)

    def test_fallback_preserves_distinct_approval_evidence(self):
        text = (ROOT / 'plugin/plangate' / SKILL).read_text()
        self.assertIn('**(a) legacy c3.json', text)
        self.assertIn('**(b) `approval_kind: "c3-prime"`', text)
        for obligation in ('artifact_hashes', 'plan_package_hash', 'source_sha',
                           'reviewer', 'V-1 を PASS と書かない'):
            self.assertIn(obligation, text)


if __name__ == '__main__':
    unittest.main()
