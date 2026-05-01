# TEST CASES: TASK-0054 / Issue #168

| AC | TC | 検証 |
|----|----|------|
| AC-1 | TC-1 | parser 単体実行 |
| AC-2 | TC-2 | eval-runner 統合 |
| AC-3 | TC-3 | log 不在時 n/a |
| AC-4 | TC-4 | tests/run-tests.sh 24 PASS |
| AC-5 | TC-5 | docs grep |
| AC-6 | TC-6 | schema-validate fixture も pass |

## TC-1
```sh
python3 scripts/parsers/codex_log_parser.py tests/fixtures/codex-log/sample.jsonl
# 期待: JSON 出力に "latency_seconds": 6.553、"completion_tokens": 7
```

## TC-2
```sh
mkdir -p docs/working/TASK-9991/approvals
cp tests/fixtures/eval-runner/sample-task/handoff.md docs/working/TASK-9991/handoff.md
cp tests/fixtures/eval-runner/sample-task/approvals/c3.json docs/working/TASK-9991/approvals/c3.json
sh bin/plangate eval TASK-9991 --no-write \
   --session-log tests/fixtures/codex-log/sample.jsonl 2>&1 | grep "Latency / Cost"
# 期待: "Latency / Cost: **PASS** (latency=6.55s, ...)"
rm -rf docs/working/TASK-9991
```

## TC-3
```sh
# log 不在で従来動作
mkdir -p docs/working/TASK-9991/approvals
cp tests/fixtures/eval-runner/sample-task/handoff.md docs/working/TASK-9991/handoff.md
cp tests/fixtures/eval-runner/sample-task/approvals/c3.json docs/working/TASK-9991/approvals/c3.json
sh bin/plangate eval TASK-9991 --no-write 2>&1 | grep "Latency / Cost"
# 期待: "Latency / Cost: n/a (provide --session-log to capture metrics)"
rm -rf docs/working/TASK-9991
```

## TC-4
```sh
sh tests/run-tests.sh
# 期待: Results: 24 passed, 0 failed
```

## TC-5
```sh
grep -E "session-log|Issue #168" docs/ai/eval-runner.md | head -3
```
