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

import base64
import copy
import pathlib
import tempfile
import unittest
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import runtime_evidence_ingress as ingress  # noqa: E402
import runtime_evidence_request_bound_canary as canary  # noqa: E402


REQ = "sha256:" + "a" * 64
HEAD = "c" * 40
REPO = "s977043/PlanGate"
RUN_ID = 424242
PROVIDER = "cloudflare"


def _repo(root: pathlib.Path, *, platform="codex"):
    (root / "docs" / "working" / "_runtime-attestation").mkdir(parents=True)
    (root / "scripts").mkdir()

    if platform == "codex":
        path = root / ".codex" / "agents"
        path.mkdir(parents=True)
        config = (
            'name = "explorer_agent"\n'
            'sandbox_mode = "read-only"\n'
        )
        (path / "explorer_agent.toml").write_text(
            config, encoding="utf-8"
        )
        return ingress._sha256_text(config)

    path = root / ".claude" / "agents"
    path.mkdir(parents=True)
    config = (
        "---\n"
        "name: explorer-agent\n"
        "tools: Read, Grep, Glob, Bash\n"
        "---\n"
    )
    (path / "explorer-agent.md").write_text(
        config, encoding="utf-8"
    )
    return ingress._sha256_text(config)


def _proposal(root: pathlib.Path, content="trusted proposal\n"):
    path = root / canary.PROPOSAL_PATH
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return content.encode("utf-8")


def _fixture(*, request_hash=REQ, config_sha=None, proposal_bytes=b"trusted proposal\n"):
    if config_sha is None:
        config_sha = "sha256:" + "b" * 64

    repo_endpoint = "repos/s977043/PlanGate"
    repo_api = "https://api.github.com/" + repo_endpoint
    run_endpoint = f"{repo_endpoint}/actions/runs/{RUN_ID}"
    jobs_endpoint = f"{run_endpoint}/jobs"
    contents_endpoint = (
        f"{repo_endpoint}/contents/{canary.ACTIVE_WORKFLOW_PATH}?ref={HEAD}"
    )

    run = {
        "id": RUN_ID,
        "event": "workflow_dispatch",
        "path": canary.ACTIVE_WORKFLOW_PATH,
        "head_branch": "main",
        "head_sha": HEAD,
        "status": "completed",
        "conclusion": "failure",
        "run_attempt": 1,
        "name": "R1 Request-Bound Read-Only Attestation",
        "display_title": canary._expected_title(
            request_hash, config_sha, "codex", PROVIDER
        ),
        "actor": {"login": "s977043", "type": "User"},
        "triggering_actor": {"login": "s977043", "type": "User"},
        "repository": {"full_name": REPO},
    }

    steps = [
        {
            "name": name,
            "status": "completed",
            "conclusion": conclusion,
        }
        for name, conclusion in canary.REQUIRED_STEP_RESULTS.items()
    ]
    jobs = {
        "total_count": 1,
        "jobs": [
            {
                "name": canary.JOB_NAME,
                "status": "completed",
                "conclusion": "failure",
                "runner_group_name": "GitHub Actions",
                "steps": steps,
            }
        ],
    }

    return {
        repo_endpoint: {
            "full_name": REPO,
            "owner": {"login": "s977043", "type": "User"},
        },
        run_endpoint: run,
        jobs_endpoint: jobs,
        contents_endpoint: {
            "encoding": "base64",
            "content": base64.b64encode(proposal_bytes).decode("ascii"),
        },
    }


def _fetch(values):
    def fetch(url):
        return copy.deepcopy(values[url])
    return fetch


class PreflightTests(unittest.TestCase):
    def test_codex_exact_config_binding_passes_without_attestation(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            config_sha = _repo(root)
            result = canary.preflight(
                repo_root=root,
                request_hash=REQ,
                config_sha=config_sha,
                platform="codex",
                provider=PROVIDER,
            )

        self.assertTrue(result["static_sandbox_candidate"])
        self.assertFalse(result["hard_read_only_enforced"])
        self.assertFalse(result["runtime_role_registered"])
        self.assertFalse(result["runtime_probe_attestation_verified"])
        self.assertTrue(result["protected_environment_declared"])
        self.assertFalse(result["protected_environment_configuration_verified"])
        self.assertFalse(result["human_rollout_decision_verified"])
        self.assertFalse(result["verifier_execution_attested"])
        self.assertFalse(result["dispatch_ready"])
        self.assertFalse(result["dispatch_allowed"])

    def test_config_sha_mismatch_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            _repo(root)
            with self.assertRaises(canary.RequestBoundCanaryError) as ctx:
                canary.preflight(
                    repo_root=root,
                    request_hash=REQ,
                    config_sha="sha256:" + "f" * 64,
                    platform="codex",
                    provider=PROVIDER,
                )
        self.assertTrue(any("config_sha" in e for e in ctx.exception.errors))

    def test_claude_documented_role_is_not_static_hard_sandbox_candidate(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            config_sha = _repo(root, platform="claude-code")
            with self.assertRaises(canary.RequestBoundCanaryError) as ctx:
                canary.preflight(
                    repo_root=root,
                    request_hash=REQ,
                    config_sha=config_sha,
                    platform="claude-code",
                    provider=PROVIDER,
                )
        self.assertTrue(
            any("hard-sandbox candidate" in e for e in ctx.exception.errors)
        )

    def test_probe_is_deliberately_unavailable(self):
        result = canary.unavailable_probe(
            request_hash=REQ,
            config_sha="sha256:" + "b" * 64,
            platform="codex",
            provider=PROVIDER,
        )
        self.assertEqual(result["status"], "UNAVAILABLE")
        self.assertTrue(result["runtime_probe_reached"])
        self.assertFalse(result["runtime_role_registered"])
        self.assertFalse(result["hard_read_only_enforced"])
        self.assertFalse(result["runtime_probe_attestation_verified"])
        self.assertFalse(result["dispatch_allowed"])


class ActionsRunVerificationTests(unittest.TestCase):
    def _verify(self, root, values, config_sha):
        return canary.verify_expected_unavailable_run(
            repo_root=root,
            repo_full_name=REPO,
            run_id=RUN_ID,
            request_hash=REQ,
            config_sha=config_sha,
            platform="codex",
            provider=PROVIDER,
            fetch_json=_fetch(values),
        )

    def test_expected_failed_run_proves_binding_but_not_attestation(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            config_sha = _repo(root)
            proposal_bytes = _proposal(root)
            values = _fixture(
                config_sha=config_sha,
                proposal_bytes=proposal_bytes,
            )
            result = self._verify(root, values, config_sha)

        self.assertTrue(result["actions_run_provenance_verified"])
        self.assertTrue(result["request_binding_verified"])
        self.assertTrue(result["config_binding_verified"])
        self.assertTrue(result["trusted_workflow_bytes_verified"])
        self.assertTrue(result["runtime_probe_reached"])
        self.assertTrue(result["runtime_probe_expected_unavailable"])
        self.assertFalse(result["runtime_probe_attestation_verified"])
        self.assertTrue(result["protected_environment_declared"])
        self.assertFalse(result["protected_environment_configuration_verified"])
        self.assertFalse(result["human_rollout_decision_verified"])
        self.assertFalse(result["verifier_execution_attested"])
        self.assertIn("not independently attested", result["verification_limit"])
        self.assertFalse(result["dispatch_ready"])
        self.assertFalse(result["dispatch_allowed"])

    def test_unexpected_success_is_rejected_in_unavailable_contract(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            config_sha = _repo(root)
            proposal_bytes = _proposal(root)
            values = _fixture(
                config_sha=config_sha,
                proposal_bytes=proposal_bytes,
            )
            run_url = f"repos/s977043/PlanGate/actions/runs/{RUN_ID}"
            values[run_url]["conclusion"] = "success"
            with self.assertRaises(canary.RequestBoundCanaryError) as ctx:
                self._verify(root, values, config_sha)
        self.assertTrue(
            any("must conclude failure" in e for e in ctx.exception.errors)
        )

    def test_active_workflow_byte_mismatch_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            config_sha = _repo(root)
            proposal_bytes = _proposal(root)
            values = _fixture(
                config_sha=config_sha,
                proposal_bytes=b"mutated workflow\n",
            )
            with self.assertRaises(canary.RequestBoundCanaryError) as ctx:
                self._verify(root, values, config_sha)
        self.assertTrue(
            any("workflow bytes" in e for e in ctx.exception.errors)
        )

    def test_provider_binding_mismatch_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            config_sha = _repo(root)
            proposal_bytes = _proposal(root)
            values = _fixture(
                config_sha=config_sha,
                proposal_bytes=proposal_bytes,
            )
            run_url = f"repos/s977043/PlanGate/actions/runs/{RUN_ID}"
            values[run_url]["display_title"] = canary._expected_title(
                REQ, config_sha, "codex", "datadog"
            )
            with self.assertRaises(canary.RequestBoundCanaryError) as ctx:
                self._verify(root, values, config_sha)
        self.assertTrue(
            any("display_title binding mismatch" in e for e in ctx.exception.errors)
        )

    def test_non_owner_actor_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            config_sha = _repo(root)
            proposal_bytes = _proposal(root)
            values = _fixture(
                config_sha=config_sha,
                proposal_bytes=proposal_bytes,
            )
            run_url = f"repos/s977043/PlanGate/actions/runs/{RUN_ID}"
            values[run_url]["actor"] = {"login": "other", "type": "User"}
            with self.assertRaises(canary.RequestBoundCanaryError):
                self._verify(root, values, config_sha)

    def test_rerun_attempt_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            config_sha = _repo(root)
            proposal_bytes = _proposal(root)
            values = _fixture(
                config_sha=config_sha,
                proposal_bytes=proposal_bytes,
            )
            run_url = f"repos/s977043/PlanGate/actions/runs/{RUN_ID}"
            values[run_url]["run_attempt"] = 2
            with self.assertRaises(canary.RequestBoundCanaryError) as ctx:
                self._verify(root, values, config_sha)
        self.assertTrue(
            any("fresh run_attempt=1" in e for e in ctx.exception.errors)
        )

    def test_runtime_probe_step_must_fail_exactly(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            config_sha = _repo(root)
            proposal_bytes = _proposal(root)
            values = _fixture(
                config_sha=config_sha,
                proposal_bytes=proposal_bytes,
            )
            jobs_url = f"repos/s977043/PlanGate/actions/runs/{RUN_ID}/jobs"
            for step in values[jobs_url]["jobs"][0]["steps"]:
                if step["name"] == "Run R1 read-only runtime probe":
                    step["conclusion"] = "success"
            with self.assertRaises(canary.RequestBoundCanaryError) as ctx:
                self._verify(root, values, config_sha)
        self.assertTrue(
            any("conclusion mismatch" in e for e in ctx.exception.errors)
        )


if __name__ == "__main__":
    unittest.main()
