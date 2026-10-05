#!/usr/bin/env python3
""":"
# --- PG-SH-GUARD (#1169): sh / bash 誤起動ガード ---
# sh はこのファイルの module docstring を二重引用符文字列として読むため、
# docstring 内のバッククォートがコマンド置換として評価され、repo を書き換える
# 副作用が起きる。python3 以外のインタプリタでは何も評価する前にここで止める。
echo "ERROR: $0 is a Python script; do not run it with sh/bash." >&2
echo "       Use: python3 $0 [args...]" >&2
exit 2
":"""

from __future__ import annotations

__doc__ = """runtime_evidence_request_bound_canary.py — request-bound R1 canary contract.

This module intentionally stops before live R1 Agent dispatch.

Current contract stage:
    r1-request-bound-v1-unavailable

The proposed workflow can prove:
- exact request_hash / Explorer config_sha binding;
- trusted main / owner-dispatch / GitHub-hosted execution boundary;
- repository postconditions remained read-only;
- the runtime-probe step was reached.

It cannot yet prove:
- actual Explorer runtime registration;
- actual Explorer invocation;
- hard read-only enforcement by the target platform;
- Human presence / identity / rollout authority.

Therefore runtime_probe_attestation_verified and dispatch_allowed remain false.
"""

import argparse
import base64
import hashlib
import json
import pathlib
import re
import sys
from typing import Any, Callable

HERE = pathlib.Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import gh_exec  # noqa: E402
import runtime_evidence_ingress as ingress  # noqa: E402
import runtime_evidence_investigation as investigation  # noqa: E402


GITHUB_API = "https://api.github.com"
CONTRACT_STAGE = "r1-request-bound-v1-unavailable"
ACTIVE_WORKFLOW_PATH = ".github/workflows/runtime-r1-request-bound-canary.yml"
PROPOSAL_PATH = (
    "docs/working/_runtime-attestation/"
    "runtime-r1-request-bound-canary.proposed.yml"
)
JOB_NAME = "R1 request-bound read-only attestation"

REQUIRED_STEP_RESULTS = {
    "Enforce request-bound execution boundary": "success",
    "Checkout trusted source SHA": "success",
    "Verify request and Explorer config binding": "success",
    "Run R1 read-only runtime probe": "failure",
    "Verify canary stayed read-only": "success",
}

HASH_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
HEAD_SHA_RE = re.compile(r"^[0-9a-f]{40}$")
REPO_RE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
PLATFORMS = {"codex", "claude-code"}


class RequestBoundCanaryError(ValueError):
    def __init__(self, errors: list[str]):
        self.errors = list(errors)
        super().__init__("; ".join(self.errors))


def _sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def _github_json(endpoint: str, *, repo_full_name: str) -> Any:
    """Fetch allowlisted GitHub JSON through gh_exec."""
    try:
        return gh_exec.get_api_json(endpoint, repo=repo_full_name)
    except gh_exec.Denied as exc:
        raise RequestBoundCanaryError([f"github: {exc}"]) from exc


def _expected_title(
    request_hash: str,
    config_sha: str,
    platform: str,
    provider: str,
) -> str:
    return (
        f"R1 attestation request={request_hash} "
        f"config={config_sha} platform={platform} provider={provider}"
    )


def _validate_common(
    *,
    request_hash: str,
    config_sha: str,
    platform: str,
    provider: str,
) -> list[str]:
    errors: list[str] = []
    if not isinstance(request_hash, str) or not HASH_RE.fullmatch(request_hash):
        errors.append("request_hash: sha256:<64 lowercase hex> required")
    if not isinstance(config_sha, str) or not HASH_RE.fullmatch(config_sha):
        errors.append("config_sha: sha256:<64 lowercase hex> required")
    if platform not in PLATFORMS:
        errors.append(f"platform: one of {sorted(PLATFORMS)} required")
    if not isinstance(provider, str) or not ingress.PROVIDER_RE.fullmatch(provider):
        errors.append("provider: provider-neutral identifier required")
    return errors


def preflight(
    *,
    repo_root: str | pathlib.Path,
    request_hash: str,
    config_sha: str,
    platform: str,
    provider: str,
) -> dict[str, Any]:
    errors = _validate_common(
        request_hash=request_hash,
        config_sha=config_sha,
        platform=platform,
        provider=provider,
    )
    root = pathlib.Path(repo_root).resolve()
    if not root.is_dir():
        errors.append("repo_root: existing directory required")
    if errors:
        raise RequestBoundCanaryError(errors)

    runtime = investigation.inspect_explorer_runtime(root, platform)
    if runtime.get("installed") is not True:
        errors.append("Explorer runtime config is not installed")
    if runtime.get("config_sha") != config_sha:
        errors.append("Explorer config_sha does not match exact canary input")

    # The first request-bound proposal is deliberately stricter than the R1
    # shadow request: only a static sandbox candidate may reach the runtime
    # probe. This currently makes Claude Explorer fail closed because its
    # documented role alone is not a hard-sandbox candidate.
    if runtime.get("static_sandbox_candidate") is not True:
        errors.append(
            "Explorer config is not a static hard-sandbox candidate"
        )

    if errors:
        raise RequestBoundCanaryError(errors)

    return {
        "schema_version": "1",
        "domain": "plangate.runtime-r1-canary-preflight/v1",
        "contract_stage": CONTRACT_STAGE,
        "request_hash": request_hash,
        "config_sha": config_sha,
        "platform": platform,
        "provider": provider,
        "runtime_role": runtime["role"],
        "config_ref": runtime["config_ref"],
        "static_sandbox_candidate": True,
        "hard_read_only_enforced": False,
        "runtime_role_registered": False,
        "runtime_probe_attestation_verified": False,
        "protected_environment_declared": True,
        "protected_environment_configuration_verified": False,
        "human_rollout_decision_verified": False,
        "verifier_execution_attested": False,
        "dispatch_ready": False,
        "dispatch_allowed": False,
        "authority": {
            "agent_invoke_allowed": False,
            "code_write_allowed": False,
            "merge_allowed": False,
            "deploy_allowed": False,
        },
    }


def unavailable_probe(
    *,
    request_hash: str,
    config_sha: str,
    platform: str,
    provider: str,
) -> dict[str, Any]:
    errors = _validate_common(
        request_hash=request_hash,
        config_sha=config_sha,
        platform=platform,
        provider=provider,
    )
    if errors:
        raise RequestBoundCanaryError(errors)

    return {
        "schema_version": "1",
        "domain": "plangate.runtime-r1-probe-unavailable/v1",
        "contract_stage": CONTRACT_STAGE,
        "request_hash": request_hash,
        "config_sha": config_sha,
        "platform": platform,
        "provider": provider,
        "status": "UNAVAILABLE",
        "reason": (
            "platform-specific Explorer registration/invocation attestation "
            "adapter is not implemented"
        ),
        "runtime_probe_reached": True,
        "runtime_role_registered": False,
        "hard_read_only_enforced": False,
        "runtime_probe_attestation_verified": False,
        "protected_environment_declared": True,
        "protected_environment_configuration_verified": False,
        "human_rollout_decision_verified": False,
        "verifier_execution_attested": False,
        "dispatch_ready": False,
        "dispatch_allowed": False,
        "authority": {
            "agent_invoke_allowed": False,
        },
    }


def _decode_contents_response(
    value: Any,
    *,
    field: str,
) -> bytes:
    if not isinstance(value, dict):
        raise RequestBoundCanaryError([f"{field}: object required"])
    if value.get("encoding") != "base64":
        raise RequestBoundCanaryError(
            [f"{field}: base64 GitHub contents response required"]
        )
    content = value.get("content")
    if not isinstance(content, str):
        raise RequestBoundCanaryError(
            [f"{field}.content: string required"]
        )
    try:
        return base64.b64decode(content, validate=False)
    except (ValueError, TypeError) as exc:
        raise RequestBoundCanaryError(
            [f"{field}.content: invalid base64"]
        ) from exc


def verify_expected_unavailable_run(
    *,
    repo_root: str | pathlib.Path,
    repo_full_name: str,
    run_id: int,
    request_hash: str,
    config_sha: str,
    platform: str,
    provider: str,
    fetch_json: Callable[[str], Any] | None = None,
) -> dict[str, Any]:
    """Verify the v1-unavailable request-bound canary against live Actions data.

    A valid result proves external run/request/config/workflow binding and that
    the workflow reached the deliberate UNAVAILABLE runtime-probe boundary.
    It does not prove runtime registration/enforcement and grants no dispatch.
    """
    errors = _validate_common(
        request_hash=request_hash,
        config_sha=config_sha,
        platform=platform,
        provider=provider,
    )
    if not REPO_RE.fullmatch(repo_full_name):
        errors.append("repo_full_name: owner/name required")
    if not isinstance(run_id, int) or isinstance(run_id, bool) or run_id < 1:
        errors.append("run_id: positive integer required")

    root = pathlib.Path(repo_root).resolve()
    proposal = root / PROPOSAL_PATH
    if not proposal.is_file() or proposal.is_symlink():
        errors.append("trusted canary proposal file is missing or unsafe")

    if errors:
        raise RequestBoundCanaryError(errors)

    owner, _repo = repo_full_name.split("/", 1)
    repo_endpoint = f"repos/{repo_full_name}"
    run_endpoint = f"{repo_endpoint}/actions/runs/{run_id}"
    jobs_endpoint = f"{run_endpoint}/jobs"
    repo_api = f"{GITHUB_API}/{repo_endpoint}"

    def get_json(endpoint: str) -> Any:
        if fetch_json is not None:
            return fetch_json(endpoint)
        return _github_json(endpoint, repo_full_name=repo_full_name)

    repository = get_json(repo_endpoint)
    run = get_json(run_endpoint)
    jobs_response = get_json(jobs_endpoint)

    if not isinstance(repository, dict):
        errors.append("github repository response: object required")
        repository = {}
    if not isinstance(run, dict):
        errors.append("github run response: object required")
        run = {}
    if not isinstance(jobs_response, dict):
        errors.append("github jobs response: object required")
        jobs_response = {}

    canonical_owner = (
        repository.get("owner", {}).get("login")
        if isinstance(repository.get("owner"), dict)
        else None
    )
    if canonical_owner != owner:
        errors.append("github repository owner mismatch")

    if run.get("id") != run_id:
        errors.append("github run id mismatch")
    if run.get("name") != "R1 Request-Bound Read-Only Attestation":
        errors.append("github run workflow name mismatch")
    if run.get("event") != "workflow_dispatch":
        errors.append("github run event must be workflow_dispatch")
    if run.get("path") != ACTIVE_WORKFLOW_PATH:
        errors.append("github run workflow path mismatch")
    if run.get("head_branch") != "main":
        errors.append("github run must execute from main")
    if run.get("status") != "completed":
        errors.append("github run must be completed")
    # v1-unavailable must fail specifically at the runtime probe.
    if run.get("conclusion") != "failure":
        errors.append(
            "v1-unavailable run must conclude failure at runtime probe"
        )
    if run.get("run_attempt") != 1:
        errors.append(
            "v1-unavailable attestation requires a fresh run_attempt=1"
        )
    if run.get("display_title") != _expected_title(
        request_hash, config_sha, platform, provider
    ):
        errors.append("github run display_title binding mismatch")

    head_sha = run.get("head_sha")
    if not isinstance(head_sha, str) or not HEAD_SHA_RE.fullmatch(head_sha):
        errors.append("github run head_sha: 40 lowercase hex required")
        head_sha = ""

    for field in ("actor", "triggering_actor"):
        actor = run.get(field)
        login = actor.get("login") if isinstance(actor, dict) else None
        if login != canonical_owner:
            errors.append(
                f"github run {field} must be repository owner"
            )

    run_repo = run.get("repository")
    if isinstance(run_repo, dict) and run_repo.get("full_name") != repo_full_name:
        errors.append("github run repository binding mismatch")

    # Bind the active HO workflow bytes at the run's trusted main SHA to the
    # reviewed proposal bytes in this repository version.
    if head_sha:
        contents_endpoint = (
            f"{repo_endpoint}/contents/{ACTIVE_WORKFLOW_PATH}"
            f"?ref={head_sha}"
        )
        active_workflow = _decode_contents_response(
            get_json(contents_endpoint),
            field="github workflow contents",
        )
        proposal_bytes = proposal.read_bytes()
        if active_workflow != proposal_bytes:
            errors.append(
                "active workflow bytes do not match reviewed proposal"
            )
    else:
        proposal_bytes = proposal.read_bytes()

    jobs = jobs_response.get("jobs")
    if not isinstance(jobs, list):
        errors.append("github jobs response: jobs array required")
        jobs = []

    matching = [job for job in jobs if job.get("name") == JOB_NAME]
    if len(matching) != 1:
        errors.append(
            "github run must contain exactly one request-bound attestation job"
        )
        job = {}
    else:
        job = matching[0]

    if job:
        if job.get("status") != "completed":
            errors.append("attestation job must be completed")
        if job.get("conclusion") != "failure":
            errors.append(
                "v1-unavailable attestation job must conclude failure"
            )

        runner_group = job.get("runner_group_name")
        if runner_group not in (None, "GitHub Actions"):
            errors.append(
                "attestation job must run in GitHub Actions runner group"
            )

        steps = job.get("steps")
        if not isinstance(steps, list):
            errors.append("attestation job steps array required")
            steps = []
        by_name = {
            step.get("name"): step
            for step in steps
            if isinstance(step, dict) and isinstance(step.get("name"), str)
        }
        for step_name, expected in REQUIRED_STEP_RESULTS.items():
            step = by_name.get(step_name)
            if not isinstance(step, dict):
                errors.append(f"required step missing: {step_name}")
                continue
            if step.get("status") != "completed":
                errors.append(
                    f"required step not completed: {step_name}"
                )
            if step.get("conclusion") != expected:
                errors.append(
                    f"required step conclusion mismatch: {step_name}"
                )

    if errors:
        raise RequestBoundCanaryError(errors)

    return {
        "schema_version": "1",
        "domain": "plangate.runtime-r1-actions-canary-verification/v1",
        "contract_stage": CONTRACT_STAGE,
        "repo_full_name": repo_full_name,
        "run_id": run_id,
        "head_sha": head_sha,
        "request_hash": request_hash,
        "config_sha": config_sha,
        "platform": platform,
        "provider": provider,
        "workflow_path": ACTIVE_WORKFLOW_PATH,
        "proposal_ref": PROPOSAL_PATH,
        "proposal_sha256": _sha256_bytes(proposal_bytes),
        "actions_run_provenance_verified": True,
        "request_binding_verified": True,
        "config_binding_verified": True,
        "trusted_workflow_bytes_verified": True,
        "runtime_probe_reached": True,
        "runtime_probe_expected_unavailable": True,
        "runtime_role_registered": False,
        "hard_read_only_enforced": False,
        "runtime_probe_attestation_verified": False,
        "protected_environment_declared": True,
        "protected_environment_configuration_verified": False,
        "human_rollout_decision_verified": False,
        "verifier_execution_attested": False,
        "verification_limit": (
            "workflow bytes and live run metadata are verified, but environment "
            "protection configuration and this verifier process provenance are "
            "not independently attested"
        ),
        "dispatch_ready": False,
        "dispatch_allowed": False,
        "authority": {
            "agent_invoke_allowed": False,
            "code_write_allowed": False,
            "approval_write_allowed": False,
            "merge_allowed": False,
            "deploy_allowed": False,
        },
    }


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    pre = sub.add_parser("preflight")
    pre.add_argument("--repo-root", required=True)
    pre.add_argument("--request-hash", required=True)
    pre.add_argument("--config-sha", required=True)
    pre.add_argument("--platform", required=True, choices=sorted(PLATFORMS))
    pre.add_argument("--provider", required=True)

    unavailable = sub.add_parser("probe-unavailable")
    unavailable.add_argument("--request-hash", required=True)
    unavailable.add_argument("--config-sha", required=True)
    unavailable.add_argument(
        "--platform", required=True, choices=sorted(PLATFORMS)
    )
    unavailable.add_argument("--provider", required=True)

    verify = sub.add_parser("verify-unavailable-run")
    verify.add_argument("--repo-root", required=True)
    verify.add_argument("--repo", required=True)
    verify.add_argument("--run-id", required=True, type=int)
    verify.add_argument("--request-hash", required=True)
    verify.add_argument("--config-sha", required=True)
    verify.add_argument(
        "--platform", required=True, choices=sorted(PLATFORMS)
    )
    verify.add_argument("--provider", required=True)

    args = parser.parse_args(argv)

    try:
        if args.command == "preflight":
            result = preflight(
                repo_root=args.repo_root,
                request_hash=args.request_hash,
                config_sha=args.config_sha,
                platform=args.platform,
                provider=args.provider,
            )
            rc = 0
        elif args.command == "probe-unavailable":
            result = unavailable_probe(
                request_hash=args.request_hash,
                config_sha=args.config_sha,
                platform=args.platform,
                provider=args.provider,
            )
            rc = 2
        else:
            result = verify_expected_unavailable_run(
                repo_root=args.repo_root,
                repo_full_name=args.repo,
                run_id=args.run_id,
                request_hash=args.request_hash,
                config_sha=args.config_sha,
                platform=args.platform,
                provider=args.provider,
            )
            rc = 0
    except RequestBoundCanaryError as exc:
        for error in exc.errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 2

    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
