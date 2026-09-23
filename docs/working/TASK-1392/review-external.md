# EXTERNAL / FALLBACK REVIEW — TASK-1392 PLAN

Status: PENDING

Review questions:
1. Is one-file atomic snapshot a valid simpler equivalent to WAL for first slice?
2. Does storing full event history in each snapshot create unacceptable growth or copy cost for the first release?
3. Is conflict evidence generation safe without modifying RunState revision?
4. Is generation/event_seq/revision separation coherent?
5. Are crash points sufficient around fsync/replace?
6. Does #1392 accidentally re-own event semantics?
7. Is trusted runtime_root acceptable for first slice or must repo/common-dir discovery be included now?
8. Does snapshot_ref create false tamper guarantees without external anchor?
