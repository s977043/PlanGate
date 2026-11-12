#!/usr/bin/env python3
"""Black-box regression tests for Issue #1636, using disposable fixtures only.

Run: PLANGATE_TEST_INSTALLER=/absolute/path/install.sh python3 installer_tests.py -v
The script under test must be self-contained or ship its helper relative to the
installer. Set PLANGATE_TEST_HELPER to that helper's relative path if needed.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

INSTALLER = Path(os.environ.get('PLANGATE_TEST_INSTALLER', Path(__file__).resolve().parents[1] / 'install.sh')).resolve()

class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='plangate-1636-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / 'repo'
        self.repo.mkdir()
        shutil.copy2(INSTALLER, self.repo / 'install.sh')
        helper = os.environ.get('PLANGATE_TEST_HELPER')
        if helper:
            helper_path = Path(helper)
            if helper_path.is_absolute() or '..' in helper_path.parts:
                raise ValueError('helper must be a repository-relative path')
            (self.repo / helper_path).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(INSTALLER.parent / helper_path, self.repo / helper_path)
        self.plugin = self.repo / 'plugin' / 'plangate'
        self.put(self.plugin / '.claude-plugin/plugin.json', '{"version":"1.0.0"}')
        self.put(self.plugin / 'agents/existing.md', 'distribution existing\n')
        self.put(self.plugin / 'agents/new.md', 'distribution new\n')
        self.put(self.plugin / 'skills/example/SKILL.md', 'distribution skill\n')
        self.put(self.plugin / 'skills/example/sub/data.txt', 'distribution data\n')
        self.dest = self.root / 'target'
        self.manifest = self.dest / 'plangate-manifest.json'

    def put(self, path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding='utf-8')

    def run_installer(self, *args, ok=True):
        result = subprocess.run(['sh', str(self.repo / 'install.sh'), '--target', str(self.dest), *args], cwd=self.root,
                                env={**os.environ, 'PLANGATE_SETUP_HINT':'0'}, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout)
        return result

    def install(self, *args):
        return self.run_installer('--claude', *args)

    def uninstall(self, *args, ok=True):
        return self.run_installer('--uninstall', *args, ok=ok)

    def snapshot(self):
        if not self.dest.exists():
            return None
        result = {}
        for p in sorted(self.dest.rglob('*')):
            key = str(p.relative_to(self.dest))
            result[key] = ('symlink', os.readlink(p)) if p.is_symlink() else ('file', p.read_bytes()) if p.is_file() else ('dir',)
        return result

    def test_preexisting_and_new_file_lifecycle(self):
        existing = self.dest / 'agents/existing.md'
        self.put(existing, 'original user content\n')
        self.install()
        self.assertEqual(existing.read_text(), 'original user content\n')
        new = self.dest / 'agents/new.md'
        self.assertTrue(new.is_file())
        self.uninstall()
        self.assertEqual(existing.read_text(), 'original user content\n')
        self.assertFalse(new.exists())
        self.assertFalse((self.dest / 'skills/example/SKILL.md').exists())

    def test_reinstall_preserves_owned_file(self):
        self.install()
        self.install()
        self.uninstall()
        self.assertFalse((self.dest / 'agents/new.md').exists())
        self.assertFalse((self.dest / 'skills/example/SKILL.md').exists())

    def test_modified_file_survives_uninstall_after_reinstall(self):
        self.install()
        edited = self.dest / 'agents/new.md'
        edited.write_text('user edits\n')
        self.install()
        self.uninstall()
        self.assertEqual(edited.read_text(), 'user edits\n')
        self.assertFalse((self.dest / 'agents/existing.md').exists())

    def test_user_added_file_inside_owned_directory_survives(self):
        self.install()
        extra = self.dest / 'skills/example/user.txt'
        self.put(extra, 'user content\n')
        self.uninstall()
        self.assertEqual(extra.read_text(), 'user content\n')

    def test_legacy_manifest_never_authorizes_deletion(self):
        existing = self.dest / 'agents/existing.md'
        self.put(existing, 'user data\n')
        self.put(self.manifest, json.dumps({'version':'old', 'files':[str(existing)]}))
        old = self.manifest.read_bytes()
        self.uninstall()
        self.assertEqual(self.manifest.read_bytes(), old)
        self.assertEqual(existing.read_text(), 'user data\n')

    def test_legacy_manifest_followed_by_install_and_uninstall(self):
        existing = self.dest / 'agents/existing.md'
        self.put(existing, 'user data\n')
        self.put(self.manifest, json.dumps({'version':'old', 'files':[str(existing)]}))
        result = self.run_installer('--claude', ok=False)
        self.assertEqual(existing.read_text(), 'user data\n')
        if result.returncode == 0:
            self.uninstall(ok=False)
            self.assertEqual(existing.read_text(), 'user data\n')
        else:
            self.assertEqual(json.loads(self.manifest.read_text())['files'], [str(existing)])

    def test_install_dry_run_does_not_write(self):
        self.put(self.dest / 'agents/existing.md', 'user data\n')
        before = self.snapshot()
        self.install('--dry-run')
        self.assertEqual(self.snapshot(), before)

    def test_uninstall_dry_run_does_not_write_and_matches_candidates(self):
        self.install()
        edited = self.dest / 'agents/new.md'
        edited.write_text('user edits\n')
        owned = self.dest / 'agents/existing.md'
        before = self.snapshot()
        result = self.uninstall('--dry-run')
        self.assertEqual(self.snapshot(), before)
        self.assertIn('existing.md', result.stdout)
        expected = {line.split('WOULD DELETE: ', 1)[1] for line in result.stdout.splitlines() if 'WOULD DELETE: ' in line}
        deletion_lines = [line for line in result.stdout.splitlines() if 'WOULD DELETE:' in line]
        self.assertFalse(any('new.md' in line for line in deletion_lines), result.stdout)
        files_before = {str(p.relative_to(self.dest)) for p in self.dest.rglob('*') if p.is_file()}
        self.uninstall()
        files_after = {str(p.relative_to(self.dest)) for p in self.dest.rglob('*') if p.is_file()}
        self.assertEqual(files_before - files_after, expected)
        self.assertFalse(owned.exists())
        self.assertEqual(edited.read_text(), 'user edits\n')

    def test_force_protects_unowned_and_edited_files(self):
        existing = self.dest / 'agents/existing.md'
        self.put(existing, 'user original\n')
        self.install()
        edited = self.dest / 'agents/new.md'
        edited.write_text('user edits\n')
        self.run_installer('--claude', '--force', ok=False)
        self.assertEqual(existing.read_text(), 'user original\n')
        self.assertEqual(edited.read_text(), 'user edits\n')
        self.uninstall(ok=False)
        self.assertEqual(existing.read_text(), 'user original\n')
        self.assertEqual(edited.read_text(), 'user edits\n')

    def test_force_updates_owned_unchanged_file(self):
        self.install()
        self.put(self.plugin / 'agents/new.md', 'updated distribution\n')
        self.install('--force')
        installed = self.dest / 'agents/new.md'
        self.assertEqual(installed.read_text(), 'updated distribution\n')
        self.uninstall()
        self.assertFalse(installed.exists())

    def test_missing_receipt_expires_on_uninstall(self):
        self.install()
        p = self.dest / 'agents/new.md'
        original = p.read_bytes()
        p.unlink()
        self.uninstall()
        p.write_bytes(original)
        self.uninstall()
        self.assertEqual(p.read_bytes(), original)

    def test_same_content_replacement_is_protected(self):
        self.install()
        p = self.dest / 'agents/new.md'
        replacement = self.dest / 'agents/replacement.tmp'
        replacement.write_bytes(p.read_bytes())
        replacement.replace(p)
        self.uninstall()
        self.assertTrue(p.exists())

    def test_metadata_edit_is_protected(self):
        self.install()
        p = self.dest / 'agents/new.md'
        p.chmod(p.stat().st_mode ^ 0o100)
        self.uninstall()
        self.assertTrue(p.exists())

    def test_malformed_v2_manifest_fails_closed(self):
        self.install()
        p = self.dest / 'agents/new.md'
        (self.dest / 'plangate-owned-v2.json').write_text('{bad')
        self.assertNotEqual(self.uninstall(ok=False).returncode, 0)
        self.assertTrue(p.exists())

    def test_existing_symlinked_parent_is_not_written(self):
        outside = self.root / 'outside-directory'
        outside.mkdir()
        self.dest.mkdir()
        (self.dest / 'agents').symlink_to(outside, target_is_directory=True)
        self.run_installer('--claude', ok=False)
        self.assertEqual(list(outside.iterdir()), [])

    def test_parent_replaced_with_symlink_is_not_traversed(self):
        self.install()
        (self.dest / 'agents').rename(self.root / 'original-agents')
        outside = self.root / 'outside-directory'
        outside.mkdir()
        self.put(outside / 'new.md', 'distribution new\n')
        (self.dest / 'agents').symlink_to(outside, target_is_directory=True)
        self.uninstall(ok=False)
        self.assertEqual((outside / 'new.md').read_text(), 'distribution new\n')

    def test_symlink_replacement_does_not_delete_target(self):
        self.install()
        outside = self.root / 'outside.txt'
        self.put(outside, 'outside user data\n')
        owned = self.dest / 'agents/new.md'
        owned.unlink()
        owned.symlink_to(outside)
        self.uninstall(ok=False)
        self.assertEqual(outside.read_text(), 'outside user data\n')
        self.assertTrue(owned.is_symlink())

if __name__ == '__main__':
    unittest.main()
