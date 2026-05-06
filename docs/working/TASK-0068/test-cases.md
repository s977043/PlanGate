# TEST CASES: TASK-0068

| ID | AC | 検証 |
|----|----|------|
| TC-01 | --markdown-section 構造 | "## 7. Metrics summary" / "| events |" / "Privacy: §3 Allowed only" |
| TC-02 | --since 範囲外 | --since 2030-01-01 で event_count=0 |
| TC-03 | --since 範囲内 | --since 2026-01-01 で全 event 維持 |
| TC-04 | --since YYYY-MM-DD 略記 | 同上で動作 |
| TC-05 | doctor --json | scope == "v8.6.0 Metrics & Privacy" / passed == True / checks > 10 |
| TC-06 | doctor --json exit 0 | 成功時 exit 0 |
| TC-07 | handoff template 例 | grep "--markdown-section" docs/working/templates/handoff.md |
| TC-08 | metrics.md §3.7 | grep "K-1" "K-2" "K-3" docs/ai/metrics.md |
| TC-09 | 既存 regress | tests/run-tests.sh 48 → 52 (+5 cases including K-1/K-2×2/K-3/H-3) |
