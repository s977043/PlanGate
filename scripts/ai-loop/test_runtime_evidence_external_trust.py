#!/usr/bin/env python3
""":"
# --- PG-SH-GUARD (#1169): sh / bash 誤起動ガード ---
echo "ERROR: $0 is a Python script; do not run it with sh/bash." >&2
echo "       Use: python3 $0 [args...]" >&2
exit 2
":"""

from __future__ import annotations

import copy
import unittest
import sys
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import runtime_evidence_external_trust as trust  # noqa: E402


REPO = "s977043/PlanGate"
ISSUE = 1448
COMMENT = 12345
REQ = "sha256:" + "a" * 64
CONFIG = "sha256:" + "b" * 64


def _fixture(*, body=None):
    repo_url = "https://api.github.com/repos/s977043/PlanGate"
    issue_url = repo_url + "/issues/1448"
    comment_url = repo_url + "/issues/comments/12345"
    values = {
        repo_url: {
            "full_name": REPO,
            "owner": {"login": "s977043", "type": "User"},
        },
        issue_url: {
            "number": ISSUE,
            "repository_url": repo_url,
            "state": "open",
        },
        comment_url: {
            "id": COMMENT,
            "issue_url": issue_url,
            "user": {"login": "s977043", "type": "User"},
            "author_association": "OWNER",
            "performed_via_github_app": None,
            "created_at": "2026-10-03T09:00:00Z",
            "updated_at": "2026-10-03T09:00:00Z",
            "body": body or f"/plangate runtime-r1 approve request={REQ}",
        },
    }
    return values


def _fetch(values):
    def fetch(url):
        return copy.deepcopy(values[url])
    return fetch


class HumanRolloutVerificationTests(unittest.TestCase):
    def test_exact_owner_comment_is_candidate_but_not_human_authority(self):
        result = trust.verify_human_rollout_comment(
            repo_full_name=REPO,
            issue_number=ISSUE,
            comment_id=COMMENT,
            request_hash=REQ,
            fetch_json=_fetch(_fixture()),
        )
        self.assertTrue(result["owner_account_decision_candidate"])
        self.assertTrue(result["live_github_metadata_verified"])
        self.assertFalse(result["human_presence_verified"])
        self.assertFalse(result["human_identity_verified"])
        self.assertFalse(result["human_rollout_decision_verified"])
        self.assertFalse(result["authority"]["agent_invoke_allowed"])
        self.assertFalse(result["authority"]["dispatch_allowed"])
        self.assertFalse(result["authority"]["merge_allowed"])
        self.assertFalse(result["authority"]["deploy_allowed"])

    def test_owner_api_credential_limitation_is_explicit(self):
        result = trust.verify_human_rollout_comment(
            repo_full_name=REPO,
            issue_number=ISSUE,
            comment_id=COMMENT,
            request_hash=REQ,
            fetch_json=_fetch(_fixture()),
        )
        self.assertIn("API automation", result["verification_limit"])
        self.assertFalse(result["human_rollout_decision_verified"])

    def test_github_app_comment_is_rejected(self):
        values = _fixture()
        url = "https://api.github.com/repos/s977043/PlanGate/issues/comments/12345"
        values[url]["performed_via_github_app"] = {
            "id": 1,
            "slug": "chatgpt-codex-connector",
        }
        with self.assertRaises(trust.ExternalTrustError) as ctx:
            trust.verify_human_rollout_comment(
                repo_full_name=REPO,
                issue_number=ISSUE,
                comment_id=COMMENT,
                request_hash=REQ,
                fetch_json=_fetch(values),
            )
        self.assertTrue(any("app-authored" in e for e in ctx.exception.errors))

    def test_non_owner_comment_is_rejected(self):
        values = _fixture()
        url = "https://api.github.com/repos/s977043/PlanGate/issues/comments/12345"
        values[url]["user"] = {"login": "someone-else", "type": "User"}
        values[url]["author_association"] = "CONTRIBUTOR"
        with self.assertRaises(trust.ExternalTrustError):
            trust.verify_human_rollout_comment(
                repo_full_name=REPO,
                issue_number=ISSUE,
                comment_id=COMMENT,
                request_hash=REQ,
                fetch_json=_fetch(values),
            )

    def test_edited_comment_is_rejected(self):
        values = _fixture()
        url = "https://api.github.com/repos/s977043/PlanGate/issues/comments/12345"
        values[url]["updated_at"] = "2026-10-03T09:01:00Z"
        with self.assertRaises(trust.ExternalTrustError) as ctx:
            trust.verify_human_rollout_comment(
                repo_full_name=REPO,
                issue_number=ISSUE,
                comment_id=COMMENT,
                request_hash=REQ,
                fetch_json=_fetch(values),
            )
        self.assertTrue(any("must not be edited" in e for e in ctx.exception.errors))

    def test_wrong_request_hash_is_rejected(self):
        values = _fixture(
            body="/plangate runtime-r1 approve request=sha256:" + "c" * 64
        )
        with self.assertRaises(trust.ExternalTrustError) as ctx:
            trust.verify_human_rollout_comment(
                repo_full_name=REPO,
                issue_number=ISSUE,
                comment_id=COMMENT,
                request_hash=REQ,
                fetch_json=_fetch(values),
            )
        self.assertTrue(any("request_hash mismatch" in e for e in ctx.exception.errors))

    def test_extra_comment_text_is_rejected(self):
        values = _fixture(
            body=f"/plangate runtime-r1 approve request={REQ}\nplease proceed"
        )
        with self.assertRaises(trust.ExternalTrustError):
            trust.verify_human_rollout_comment(
                repo_full_name=REPO,
                issue_number=ISSUE,
                comment_id=COMMENT,
                request_hash=REQ,
                fetch_json=_fetch(values),
            )

    def test_closed_issue_is_rejected(self):
        values = _fixture()
        url = "https://api.github.com/repos/s977043/PlanGate/issues/1448"
        values[url]["state"] = "closed"
        with self.assertRaises(trust.ExternalTrustError):
            trust.verify_human_rollout_comment(
                repo_full_name=REPO,
                issue_number=ISSUE,
                comment_id=COMMENT,
                request_hash=REQ,
                fetch_json=_fetch(values),
            )

    def test_comment_bound_to_other_issue_is_rejected(self):
        values = _fixture()
        url = "https://api.github.com/repos/s977043/PlanGate/issues/comments/12345"
        values[url]["issue_url"] = (
            "https://api.github.com/repos/s977043/PlanGate/issues/999"
        )
        with self.assertRaises(trust.ExternalTrustError):
            trust.verify_human_rollout_comment(
                repo_full_name=REPO,
                issue_number=ISSUE,
                comment_id=COMMENT,
                request_hash=REQ,
                fetch_json=_fetch(values),
            )


class RuntimeAttestationGapTests(unittest.TestCase):
    def test_existing_canary_pattern_is_explicitly_insufficient(self):
        result = trust.assess_runtime_attestation_gap(
            request_hash=REQ,
            config_sha=CONFIG,
        )
        self.assertTrue(result["reusable_pattern"]["read_only_tool_surface"])
        self.assertFalse(result["request_bound_runtime_attestation_available"])
        self.assertFalse(result["runtime_probe_attestation_verified"])
        self.assertFalse(result["dispatch_ready"])
        self.assertFalse(result["dispatch_allowed"])
        self.assertIn("request_hash", result["missing_bindings"])
        self.assertIn("Explorer config_sha", result["missing_bindings"])

    def test_invalid_hash_is_rejected(self):
        with self.assertRaises(trust.ExternalTrustError):
            trust.assess_runtime_attestation_gap(
                request_hash="not-a-hash",
                config_sha=CONFIG,
            )


if __name__ == "__main__":
    unittest.main()
