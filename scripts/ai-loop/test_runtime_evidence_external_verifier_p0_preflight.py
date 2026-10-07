#!/usr/bin/env python3
from __future__ import annotations

import copy
import hashlib
import pathlib
import sys
import unittest

HERE = pathlib.Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import runtime_evidence_external_verifier_p0_preflight as p0


PROPOSED = """# ADR-007: Decision Packet

**Status**: Proposed
**Decision Makers**: Human / external-boundary administrator — UNASSIGNED

## Decision

**Decision state: NOT_MADE.**

### Human Decision Record

```text
selected_option = UNDECIDED
external_verifier_location = UNDECIDED
external_verifier_admin = UNDECIDED
nonce_ledger_owner = UNDECIDED
trusted_issuer = UNDECIDED
decision_recorded_by = UNDECIDED
decision_recorded_at = UNDECIDED
decision_evidence_ref = UNDECIDED
```

### Decision-state transition contract
"""

ACCEPTED = PROPOSED.replace("**Status**: Proposed", "**Status**: Accepted")
ACCEPTED = ACCEPTED.replace(
    "**Decision Makers**: Human / external-boundary administrator — UNASSIGNED",
    "**Decision Makers**: Example Human Owner",
)
ACCEPTED = ACCEPTED.replace(
    "**Decision state: NOT_MADE.**",
    "**Decision state: RECORDED_BY_HUMAN.**",
)
_ACCEPTED_VALUES = {
    "selected_option": "Option A",
    "external_verifier_location": "example/verifier",
    "external_verifier_admin": "separate-admin-team",
    "nonce_ledger_owner": "external-nonce-service",
    "trusted_issuer": "https://token.actions.githubusercontent.com",
    "decision_recorded_by": "Example Human Owner",
    "decision_recorded_at": "2026-10-07",
    "decision_evidence_ref": "https://example.invalid/human-decision/1",
}
for _key, _value in _ACCEPTED_VALUES.items():
    ACCEPTED = ACCEPTED.replace(f"{_key} = UNDECIDED", f"{_key} = {_value}")


def _hash(text: str) -> str:
    return "sha256:" + hashlib.sha256(text.encode()).hexdigest()


class P0PreflightTests(unittest.TestCase):
    def test_proposed_is_valid_but_blocked(self):
        result = p0.evaluate_text(PROPOSED, adr_sha256=_hash(PROPOSED))
        self.assertTrue(result["decision_record_structurally_valid"])
        self.assertFalse(result["human_decision_recorded_candidate"])
        self.assertFalse(result["p1_preflight_candidate"])
        self.assertEqual(result["state"], "blocked_on_human_decision")

    def test_accepted_complete_record_is_candidate_only(self):
        result = p0.evaluate_text(ACCEPTED, adr_sha256=_hash(ACCEPTED))
        self.assertTrue(result["human_decision_recorded_candidate"])
        self.assertTrue(result["p1_preflight_candidate"])
        self.assertEqual(
            result["state"], "human_decision_record_present_candidate"
        )
        for field in p0.STRONG_FALSE_FIELDS:
            self.assertFalse(result[field], field)

    def test_accepted_with_undecided_field_fails_closed(self):
        bad = ACCEPTED.replace(
            "trusted_issuer = https://token.actions.githubusercontent.com",
            "trusted_issuer = UNDECIDED",
        )
        with self.assertRaises(p0.P0PreflightError):
            p0.evaluate_text(bad, adr_sha256=_hash(bad))

    def test_accepted_without_recorded_by_fails_closed(self):
        bad = ACCEPTED.replace(
            "decision_recorded_by = Example Human Owner",
            "decision_recorded_by = UNDECIDED",
        )
        with self.assertRaises(p0.P0PreflightError):
            p0.evaluate_text(bad, adr_sha256=_hash(bad))

    def test_proposed_with_partial_decision_fails_closed(self):
        bad = PROPOSED.replace(
            "selected_option = UNDECIDED", "selected_option = Option A"
        )
        with self.assertRaises(p0.P0PreflightError):
            p0.evaluate_text(bad, adr_sha256=_hash(bad))

    def test_duplicate_record_key_fails_closed(self):
        bad = PROPOSED.replace(
            "selected_option = UNDECIDED",
            "selected_option = UNDECIDED\nselected_option = UNDECIDED",
        )
        with self.assertRaises(p0.P0PreflightError):
            p0.evaluate_text(bad, adr_sha256=_hash(bad))

    def test_unexpected_record_key_fails_closed(self):
        bad = PROPOSED.replace(
            "decision_evidence_ref = UNDECIDED",
            "decision_evidence_ref = UNDECIDED\nauthority_verified = true",
        )
        with self.assertRaises(p0.P0PreflightError):
            p0.evaluate_text(bad, adr_sha256=_hash(bad))

    def test_mismatched_status_state_fails_closed(self):
        bad = ACCEPTED.replace(
            "**Decision state: RECORDED_BY_HUMAN.**",
            "**Decision state: NOT_MADE.**",
        )
        with self.assertRaises(p0.P0PreflightError):
            p0.evaluate_text(bad, adr_sha256=_hash(bad))


if __name__ == "__main__":
    unittest.main()
