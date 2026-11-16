#!/usr/bin/env python3
"""Targeted documentation contracts; not a runtime/plugin installation test."""
from __future__ import annotations
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path


def checks(text: str, stage: int) -> list[dict[str, object]]:
    out: list[dict[str, object]] = []
    def check(name: str, ok: bool) -> None:
        out.append({'name': name, 'passed': bool(ok)})
    blocks = re.findall(r'^```(?:bash|sh)\n(.*?)^```', text, re.M | re.S)
    if stage >= 1:
        install_blocks = [b for b in blocks if 'codex plugin marketplace add s977043/PlanGate' in b]
        check('codex-install-examples-exist', len(install_blocks) >= 1)
        check('codex-marketplace-followed-by-plugin-add', all('codex plugin add plangate@plangate' in b and b.index('codex plugin marketplace add') < b.index('codex plugin add') for b in install_blocks))
        check('codex-installed-state-check', 'codex plugin list --json' in text and '`installed`' in text and '`enabled`' in text)
        check('remove-obsolete-marketplace-list-claim', '現行 Codex CLI では未実装' not in text)
    if stage >= 2:
        first = blocks[0].strip() if blocks else ''
        check('recommended-path-first', first.startswith('claude plugin marketplace add'))
        check('qualified-claude-install', 'claude plugin install plangate@plangate --scope local' in text)
        check('legacy-install-not-presented-as-one-command', '### ワンコマンドインストール（install.sh）' not in text)
        check('legacy-anchor-preserved', '<a id="ワンコマンドインストールinstallsh"></a>' in text)
        check('duplicate-install-warning', '二重' in text and '併用は推奨しません' in text)
    if stage >= 3:
        check('matching-uninstall-scope', 'claude plugin uninstall plangate@plangate --scope local' in text)
        check('codex-uninstall-command', 'codex plugin remove plangate@plangate' in text)
        check('residual-files-warning', '自動では戻りません' in text)
        check('no-settings-plugins-array', '"plugins": [' not in text)
        check('documented-session-local-plugin-dir', 'claude --plugin-dir /path/to/plangate/plugin/plangate' in text)
        check('no-broad-directory-delete-advice', 'temporarily rename or remove files in `.claude/`' not in text)
    if stage >= 4:
        usage = text.split('### Start a workflow\n', 1)[-1].split('### Invoke skills explicitly', 1)[0]
        plan = usage.find('/plangate:ai-dev-workflow TASK-XXXX plan')
        gate = usage.find('C-3')
        execute = usage.find('/plangate:ai-dev-workflow TASK-XXXX exec')
        check('plan-human-gate-exec-order', -1 not in (plan, gate, execute) and plan < gate < execute)
        check('expected-plan-artifacts', all(x in usage for x in ('plan.md', 'todo.md', 'test-cases.md')))
        check('plan-only-first-success', '初回体験は計画の確認まで' in usage)
        check('no-auto-enforcement-claim', '導入しただけでは hook 強制は有効になりません' in text)
        check('approval-is-not-missing-from-english', 'human review' in usage and 'approval' in usage)
    if stage >= 5:
        check('utf8-no-replacement-character', '\ufffd' not in text)
        check('final-newline', text.endswith('\n'))
        # Count headings outside code fences: shell comments are not headings.
        outside = re.sub(r'^```[^\n]*\n.*?^```[^\n]*$', '', text, flags=re.M | re.S)
        check('one-h1', len(re.findall(r'^# ', outside, re.M)) == 1)
        opened = None
        ok = True
        for line in text.splitlines():
            m = re.match(r'^\s*(`{3,}|~{3,})(.*)$', line)
            if not m:
                continue
            mark, suffix = m.groups()
            if opened is None:
                opened = mark
            elif mark[0] == opened[0] and len(mark) >= len(opened) and not suffix.strip():
                opened = None
        check('balanced-code-fences', ok and opened is None)
        check('official-cli-sources', 'https://learn.chatgpt.com/docs/cli/reference' in text and 'https://code.claude.com/docs/en/plugins/cli-reference' in text)
        check('no-trailing-whitespace', not any(line.rstrip() != line for line in text.splitlines()))
        check('poc-install-example-fixed', 'codex plugin add plangate@plangate' in text.split('## ai-loop-workflow', 1)[-1])
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('readme', type=Path)
    ap.add_argument('--stage', type=int, choices=range(1, 6), default=5)
    args = ap.parse_args()
    try:
        raw = args.readme.read_bytes()
        results = checks(raw.decode('utf-8'), args.stage)
    except (OSError, UnicodeError) as exc:
        print(json.dumps({'error': str(exc)}, ensure_ascii=False))
        return 2
    passed = all(r['passed'] for r in results)
    print(json.dumps({'stage': args.stage, 'sha256': hashlib.sha256(raw).hexdigest(), 'passed': passed, 'checks': results}, ensure_ascii=False, indent=2))
    return 0 if passed else 1

if __name__ == '__main__':
    sys.exit(main())
