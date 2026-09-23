# TODO — TASK-1391 / #1391

## Plan-only phase

- [x] owner boundary defined
- [x] persistence boundary separated from #1391
- [x] #1392 durable sink dependency identified
- [x] #1393 pure decision dependency identified
- [x] first-slice event vocabulary bounded
- [x] RED categories defined
- [x] event_seq allocation assigned to #1392 durable boundary
- [x] EventDraft vs Accepted RunEvent separated
- [x] duplicate retry vs duplicate accepted event separated
- [x] parse failure vs evidence_status=invalid separated
- [x] precommit validate_append assigned to #1391/#1392 boundary
- [x] event_seq made contiguous, not merely monotonic
- [x] I0 plan self-review
- [ ] I1+ plan review
- [ ] exact reviewed_at_sha

## Before Production implementation

- [ ] #1387 current-head I1 PASS
- [ ] latest main/base SHA recorded
- [ ] M-1 before recorded
- [ ] M-2 before recorded
- [ ] M-3 before recorded
- [ ] semantic invalidation = YES candidate recorded
- [ ] implementation files re-inventoried
- [ ] next-free TA number reserved

## RED

- [ ] event envelope tests
- [ ] reference-integrity tests
- [ ] privacy tests
- [ ] projection tests
- [ ] boundary/static tests
- [ ] mutation tests

## GREEN

- [ ] run_event pure validation
- [ ] run_evidence pure projection
- [ ] no durable writer
- [ ] full suite green
- [ ] TA standalone green
- [ ] plugin/distribution impact reviewed

## Review / handoff

- [ ] I0 implementation review
- [ ] I1+ implementation review
- [ ] #1329 invalidation evidence returned
- [ ] #1392 interface handoff
- [ ] #1393 interface handoff
- [ ] #1383 integration evidence updated
