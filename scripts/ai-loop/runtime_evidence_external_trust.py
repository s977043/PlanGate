#!/usr/bin/env python3
""":"
# --- PG-SH-GUARD (#1169): sh / bash 誤起動ガード ---
echo "ERROR: $0 is a Python script; do not run it with sh/bash." >&2
echo "       Use: python3 $0 [args...]" >&2
exit 2
":"""

from __future__ import annotations

__doc__ = """runtime_evidence_external_trust.py — out-of-band trust verification (#1448).

This module verifies Human rollout intent against live GitHub issue-comment metadata.
Repository-authored files cannot self-create Human rollout authority.

It deliberately does NOT verify runtime attestation yet. The existing Claude
subscription canary is a reusable read-only pattern, but it is not bound to the
R1 request_hash/config_sha and therefore is insufficient for dispatch.

No function in this module dispatches an agent or grants mutation authority.
"""

import argparse
import datetime as dt
import json
import re
import sys
import urllib.error
import urllib.request
from typing import Any, Callable
from urllib.parse import quote

GITHUB_API = "https://api.github.com"
REQUEST_HASH_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
REPO_RE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
APPROVAL_RE = re.compile(
    r"^/plangate runtime-r1 approve request=(sha256:[0-9a-f]{64})$"
)


class ExternalTrustError(ValueError):
    def __init__(self, errors: list[str]):
        self.errors = list(errors)
        super().__init__("; ".join(self.errors))


def _github_json(url: str) -> Any:
    if not url.startswith(GITHUB_API + "/"):
        raise ExternalTrustError(["github: only api.github.com is allowed"])
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "PlanGate-runtime-r1-trust-verifier/1",
            "X-GitHub-Api-Version": "2022-11-28",
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            if response.status != 200:
                raise ExternalTrustError(
                    [f"github: unexpected HTTP status {response.status}"]
                )
            raw = response.read()
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        raise ExternalTrustError([f"github: request failed: {exc}"]) from exc

    if len(raw) > 2 * 1024 * 1024:
        raise ExternalTrustError(["github: response exceeds 2 MiB"])
    try:
        return json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ExternalTrustError(["github: invalid JSON response"]) from exc


def _parse_github_time(value: Any, field: str, errors: list[str]) -> dt.datetime | None:
    if not isinstance(value, str):
        errors.append(f"{field}: RFC3339 string required")
        return None
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        errors.append(f"{field}: invalid RFC3339 timestamp")
        return None
    if parsed.tzinfo is None:
        errors.append(f"{field}: timezone required")
        return None
    return parsed


def verify_human_rollout_comment(
    *,
    repo_full_name: str,
    issue_number: int,
    comment_id: int,
    request_hash: str,
    fetch_json: Callable[[str], Any] = _github_json,
) -> dict[str, Any]:
    """Verify an out-of-band Human approval comment against live GitHub metadata.

    Security properties:
    - exact repository owner must author the comment;
    - GitHub App-authored comments are rejected;
    - edited comments are rejected;
    - exact issue binding is required;
    - exact request_hash binding is required;
    - no repository-local file can substitute for the live API check.
    """
    errors: list[str] = []
    if not REPO_RE.fullmatch(repo_full_name):
        errors.append("repo_full_name: owner/name required")
    if not isinstance(issue_number, int) or isinstance(issue_number, bool) or issue_number < 1:
        errors.append("issue_number: positive integer required")
    if not isinstance(comment_id, int) or isinstance(comment_id, bool) or comment_id < 1:
        errors.append("comment_id: positive integer required")
    if not isinstance(request_hash, str) or not REQUEST_HASH_RE.fullmatch(request_hash):
        errors.append("request_hash: sha256:<64 lowercase hex> required")
    if errors:
        raise ExternalTrustError(errors)

    owner, repo = repo_full_name.split("/", 1)
    owner_q = quote(owner, safe="")
    repo_q = quote(repo, safe="")

    repo_url = f"{GITHUB_API}/repos/{owner_q}/{repo_q}"
    issue_url = f"{repo_url}/issues/{issue_number}"
    comment_url = f"{repo_url}/issues/comments/{comment_id}"

    repository = fetch_json(repo_url)
    issue = fetch_json(issue_url)
    comment = fetch_json(comment_url)

    if not isinstance(repository, dict):
        errors.append("github repository response: object required")
        repository = {}
    if not isinstance(issue, dict):
        errors.append("github issue response: object required")
        issue = {}
    if not isinstance(comment, dict):
        errors.append("github comment response: object required")
        comment = {}

    repo_owner = repository.get("owner")
    canonical_owner = repo_owner.get("login") if isinstance(repo_owner, dict) else None
    if canonical_owner != owner:
        errors.append("github repository owner does not match requested owner")

    if issue.get("number") != issue_number:
        errors.append("github issue number mismatch")
    if issue.get("repository_url") != repo_url:
        errors.append("github issue repository binding mismatch")
    if issue.get("state") != "open":
        errors.append("github issue must be open for rollout approval")

    expected_issue_url = issue_url
    if comment.get("issue_url") != expected_issue_url:
        errors.append("github comment issue binding mismatch")

    user = comment.get("user")
    login = user.get("login") if isinstance(user, dict) else None
    user_type = user.get("type") if isinstance(user, dict) else None
    if login != canonical_owner:
        errors.append("github comment must be authored by repository owner")
    if user_type != "User":
        errors.append("github comment author must be a human User account")
    if comment.get("author_association") != "OWNER":
        errors.append("github comment author_association OWNER required")
    if comment.get("performed_via_github_app") is not None:
        errors.append("github app-authored comments cannot grant Human rollout authority")

    created = _parse_github_time(comment.get("created_at"), "comment.created_at", errors)
    updated = _parse_github_time(comment.get("updated_at"), "comment.updated_at", errors)
    if created is not None and updated is not None and created != updated:
        errors.append("github approval comment must not be edited")

    body = comment.get("body")
    if not isinstance(body, str):
        errors.append("github comment body: string required")
        body = ""
    match = APPROVAL_RE.fullmatch(body)
    if not match:
        errors.append("github comment body does not match exact R1 approval command")
    elif match.group(1) != request_hash:
        errors.append("github approval comment request_hash mismatch")

    if errors:
        raise ExternalTrustError(errors)

    return {
        "schema_version": "1",
        "domain": "plangate.runtime-human-rollout-verification/v1",
        "repo_full_name": repo_full_name,
        "issue_number": issue_number,
        "comment_id": comment_id,
        "request_hash": request_hash,
        "decision": "enable_r1_read_only_dispatch",
        "human_rollout_decision_verified": True,
        "verified_by": "live_github_issue_comment_metadata",
        "owner_login": canonical_owner,
        "comment_created_at": comment["created_at"],
        "comment_unedited": True,
        "performed_via_github_app": False,
        "authority": {
            "agent_invoke_allowed": False,
            "dispatch_allowed": False,
            "code_write_allowed": False,
            "issue_write_allowed": False,
            "approval_write_allowed": False,
            "merge_allowed": False,
            "deploy_allowed": False,
        },
    }


def assess_runtime_attestation_gap(*, request_hash: str, config_sha: str | None) -> dict[str, Any]:
    """Record why the current repository canary is not sufficient R1 attestation.

    Existing .github/workflows/claude-subscription-canary.yml demonstrates a strong
    read-only workflow pattern, but it has no request_hash/config_sha binding for this
    R1 request and therefore cannot establish runtime_role_registered or
    hard_read_only_enforced for a specific request.
    """
    if not REQUEST_HASH_RE.fullmatch(request_hash):
        raise ExternalTrustError(["request_hash: valid sha256 required"])
    if config_sha is not None and not REQUEST_HASH_RE.fullmatch(config_sha):
        raise ExternalTrustError(["config_sha: valid sha256 required"])

    return {
        "schema_version": "1",
        "domain": "plangate.runtime-attestation-gap/v1",
        "request_hash": request_hash,
        "config_sha": config_sha,
        "reusable_pattern": {
            "workflow_ref": ".github/workflows/claude-subscription-canary.yml",
            "main_only": True,
            "repository_owner_dispatch": True,
            "github_hosted_runner": True,
            "read_only_tool_surface": True,
            "post_run_mutation_check": True,
        },
        "request_bound_runtime_attestation_available": False,
        "runtime_probe_attestation_verified": False,
        "missing_bindings": [
            "request_hash",
            "Explorer config_sha",
            "R1 runtime role registration",
            "R1 provider connector registration",
            "R1 hard read-only enforcement for this request",
        ],
        "dispatch_ready": False,
        "dispatch_allowed": False,
        "authority": {
            "agent_invoke_allowed": False,
            "dispatch_allowed": False,
        },
    }


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    human = sub.add_parser("verify-human-comment")
    human.add_argument("--repo", required=True)
    human.add_argument("--issue-number", type=int, required=True)
    human.add_argument("--comment-id", type=int, required=True)
    human.add_argument("--request-hash", required=True)

    gap = sub.add_parser("attestation-gap")
    gap.add_argument("--request-hash", required=True)
    gap.add_argument("--config-sha")

    args = parser.parse_args(argv)

    try:
        if args.command == "verify-human-comment":
            result = verify_human_rollout_comment(
                repo_full_name=args.repo,
                issue_number=args.issue_number,
                comment_id=args.comment_id,
                request_hash=args.request_hash,
            )
        else:
            result = assess_runtime_attestation_gap(
                request_hash=args.request_hash,
                config_sha=args.config_sha,
            )
    except ExternalTrustError as exc:
        for error in exc.errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 2

    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
