#!/usr/bin/env python3
"""Reproduce baseline manifest ownership bug using only disposable fixture files."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
import subprocess
import tempfile
from pathlib import Path

EXPECTED_BLOB = '6f5433b70cd4b05574226e55d9109bfb48f76587'

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('baseline_installer', type=Path)
    args = parser.parse_args()
    raw = args.baseline_installer.read_bytes()
    sha = hashlib.sha1(f'blob {len(raw)}\0'.encode() + raw).hexdigest()
    if sha != EXPECTED_BLOB:
        raise ValueError('Wrong baseline installer blob; refusing to execute unreviewed source')
    with tempfile.TemporaryDirectory(prefix='plangate-uninstall-repro-') as name:
        root = Path(name)
        source = root / 'source'
        source.mkdir()
        installer = source / 'install.sh'
        installer.write_bytes(raw)
        plugin = source / 'plugin/plangate'
        (plugin / '.claude-plugin').mkdir(parents=True)
        (plugin / '.claude-plugin/plugin.json').write_text('{"version":"8.24.0"}\n')
        (plugin / 'agents').mkdir()
        (plugin / 'agents/example.md').write_text('PACKAGED CONTENT\n')
        target = root / 'project/.claude'
        (target / 'agents').mkdir(parents=True)
        existing = target / 'agents/example.md'
        existing.write_text('USER PREEXISTING CONTENT\n')
        original = existing.read_bytes()
        (root / 'home').mkdir()
        env = {**os.environ, 'HOME': str(root/'home'), 'PLANGATE_SETUP_HINT': '0'}
        observations = []
        def run(*options: str) -> subprocess.CompletedProcess[str]:
            proc = subprocess.run(['sh', str(installer), *options, '--target', str(target)], cwd=root, env=env, text=True, capture_output=True, timeout=10)
            observations.append({'options': list(options), 'exit_code': proc.returncode, 'stdout': proc.stdout.replace(str(root), '<fixture>'), 'stderr': proc.stderr.replace(str(root), '<fixture>')})
            proc.check_returncode()
            return proc
        run('--claude')
        preserved = existing.read_bytes() == original
        manifest = json.loads((target/'plangate-manifest.json').read_text())
        recorded = str(existing) in manifest['files']
        dry = run('--uninstall', '--dry-run')
        dry_preserved = existing.read_bytes() == original
        dry_lists_existing = str(existing) in dry.stdout
        run('--uninstall')
        deleted = not existing.exists()
        result = {'baseline_blob': sha, 'fixture_only': True,
                  'preexisting_file_preserved_on_install': preserved,
                  'preexisting_file_wrongly_recorded': recorded,
                  'dry_run_preserves_file': dry_preserved,
                  'dry_run_lists_preexisting_for_deletion': dry_lists_existing,
                  'preexisting_file_deleted_on_uninstall': deleted,
                  'bug_reproduced': all((preserved, recorded, dry_preserved, dry_lists_existing, deleted)),
                  'commands': observations}
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0 if result['bug_reproduced'] else 1

if __name__ == '__main__':
    raise SystemExit(main())
