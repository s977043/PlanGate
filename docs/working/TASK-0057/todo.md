# EXECUTION TODO: TASK-0057 / Issue #169 セッション B

> Mode: **critical**

- [x] PBI INPUT
- [x] plan + test-cases
- [x] scripts/hooks/check-test-cases.sh（EH-4）
- [x] scripts/hooks/check-verification-evidence.sh（EH-5）
- [x] scripts/hooks/check-forbidden-files.sh（EH-6、python3 委譲）
- [x] tests/fixtures/hooks/{test-cases-exists, evidence-ok, forbidden-parent}/
- [x] tests/hooks/run-tests.sh に EH-4/5/6 ケース 12 件追加 → 33 PASS
- [x] sh tests/run-tests.sh → 24 PASS 維持
- [x] .claude/settings.example.json に EH-6 PreToolUse 追加
- [x] docs/ai/hook-enforcement.md Status v3 → v4、5/10 → 8/10 hooks Done
- [x] handoff.md
- [x] commit + push + PR
- [ ] CI 緑 → C-4
- [ ] **#169 は close せず**、進捗コメントで段階記録（残 EH-7 + EHS-1 を C へ）
