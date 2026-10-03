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

__doc__ = """test_runtime_evidence_dispatch_readiness.py — #1448 pre-run readiness."""

import copy
import json
import pathlib
import tempfile
import unittest
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import runtime_evidence_dispatch_readiness as readiness  # noqa: E402
import runtime_evidence_ingress as ingress  # noqa: E402
import runtime_evidence_investigation as investigation  # noqa: E402


def _repo(root: pathlib.Path):
    (root / "docs" / "working").mkdir(parents=True)
    (root / "scripts").mkdir()
    (root / ".codex" / "agents").mkdir(parents=True)
    (root / ".codex" / "agents" / "explorer_agent.toml").write_text(
        'name = "explorer_agent"\n'
        'sandbox_mode = "read-only"\n',
        encoding="utf-8",
    )


def _r0(root: pathlib.Path):
    payload = {
        "event_id": "ready-001",
        "captured_at": "2026-10-03T08:00:00Z",
        "environment": "production",
        "issue_fingerprint": "TypeError:ready:42",
        "deployment_ref": "worker-ready",
        "occurrence_count": 2,
        "recurrence": True,
        "error_type": "TypeError",
        "statement": "Cloudflare reported repeated worker failures.",
        "trace_refs": ["cf-trace:ready"],
        "log_refs": ["cf-log:ready"],
        "status": "active",
        "candidate_problem": "A production worker failure is recurring.",
    }
    envelope = {
        "authenticated": True,
        "replayed": False,
        "redaction_applied": True,
        "secret_scan": "pass",
    }
    mapped = ingress.map_cloudflare_issue(payload, envelope)
    ingress.persist_source_snapshot(root, mapped)
    return mapped


def _request(root: pathlib.Path):
    mapped = _r0(root)
    request = investigation.build_r1_investigation_request(
        repo_root=root,
        source_ref=mapped["source_ref"],
        platform="codex",
    )
    return mapped, request


def _evidence(root: pathlib.Path, name: str, body: str):
    path = root / "docs" / "working" / "_runtime-activation" / f"{name}.txt"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body, encoding="utf-8")
    ref = path.relative_to(root).as_posix()
    sha = readiness._sha256_bytes(path.read_bytes())
    return ref, sha


def _observations(root: pathlib.Path, request):
    role = request["role"]["runtime_role"]
    config_sha = request["role"]["config_sha"]
    provider = request["source"]["provider"]
    source_ref = request["source"]["source_ref"]
    request_hash = request["request_hash"]

    rows = []
    specs = [
        (
            "runtime_role_registered",
            "runtime_probe",
            {"role": role, "config_sha": config_sha},
        ),
        (
            "provider_connector_registered",
            "runtime_probe",
            {"provider": provider},
        ),
        (
            "hard_read_only_enforced",
            "runtime_probe",
            {"role": role, "config_sha": config_sha},
        ),
        (
            "admission_binding_verified",
            "repository_evidence",
            {"source_ref": source_ref},
        ),
    ]
    for idx, (kind, source_kind, extra) in enumerate(specs):
        ref, sha = _evidence(root, f"{idx}-{kind}", f"{kind}: pass\n")
        row = {
            "schema_version": "1",
            "domain": readiness.OBS_DOMAIN,
            "kind": kind,
            "request_hash": request_hash,
            "platform": "codex",
            "observed_at": f"2026-10-03T08:0{idx}:00Z",
            "source_kind": source_kind,
            "verdict": "pass",
            "evidence_ref": ref,
            "evidence_sha": sha,
        }
        row.update(extra)
        rows.append(row)
    return rows


class DispatchReadinessTests(unittest.TestCase):
    def test_complete_machine_candidates_still_cannot_self_authorize_dispatch(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            _repo(root)
            _mapped, request = _request(root)
            result = readiness.evaluate_dispatch_readiness(
                repo_root=root,
                request=request,
                observations=_observations(root, request),
            )

        self.assertFalse(result["dispatch_ready"])
        self.assertFalse(result["dispatch_allowed"])
        self.assertTrue(result["requirements"]["machine_candidate_evidence_complete"])
        self.assertFalse(result["requirements"]["runtime_probe_attestation_verified"])
        self.assertFalse(result["requirements"]["human_rollout_decision_verified"])
        self.assertFalse(result["authority"]["agent_invoke_allowed"])
        self.assertFalse(result["v2_run_activation"]["applicable"])
        self.assertNotIn("selected", result)
        self.assertNotIn("fired", result)

    def test_missing_one_machine_candidate_is_not_complete(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            _repo(root)
            _mapped, request = _request(root)
            observations = _observations(root, request)[:-1]
            result = readiness.evaluate_dispatch_readiness(
                repo_root=root,
                request=request,
                observations=observations,
            )
        self.assertFalse(result["dispatch_ready"])
        self.assertFalse(result["requirements"]["machine_candidate_evidence_complete"])

    def test_static_config_alone_is_not_ready(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            _repo(root)
            _mapped, request = _request(root)
            result = readiness.evaluate_dispatch_readiness(
                repo_root=root,
                request=request,
                observations=[],
            )
        self.assertTrue(result["requirements"]["static_read_only_candidate"])
        self.assertFalse(result["dispatch_ready"])

    def test_stale_request_hash_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            _repo(root)
            _mapped, request = _request(root)
            observations = _observations(root, request)
            observations[0]["request_hash"] = "sha256:" + "0" * 64
            with self.assertRaises(readiness.DispatchReadinessError) as ctx:
                readiness.evaluate_dispatch_readiness(
                    repo_root=root,
                    request=request,
                    observations=observations,
                )
        self.assertTrue(any("exact R1 request" in e for e in ctx.exception.errors))

    def test_config_sha_mismatch_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            _repo(root)
            _mapped, request = _request(root)
            observations = _observations(root, request)
            observations[0]["config_sha"] = "sha256:" + "f" * 64
            with self.assertRaises(readiness.DispatchReadinessError) as ctx:
                readiness.evaluate_dispatch_readiness(
                    repo_root=root,
                    request=request,
                    observations=observations,
                )
        self.assertTrue(any("exact Explorer config" in e for e in ctx.exception.errors))

    def test_evidence_ref_outside_docs_working_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            _repo(root)
            _mapped, request = _request(root)
            observations = _observations(root, request)
            outside = root / "README.md"
            outside.write_text("not activation evidence\n", encoding="utf-8")
            observations[0]["evidence_ref"] = "README.md"
            observations[0]["evidence_sha"] = readiness._sha256_bytes(
                outside.read_bytes()
            )
            with self.assertRaises(readiness.DispatchReadinessError) as ctx:
                readiness.evaluate_dispatch_readiness(
                    repo_root=root,
                    request=request,
                    observations=observations,
                )
        self.assertTrue(any("docs/working" in e for e in ctx.exception.errors))

    def test_evidence_hash_mismatch_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            _repo(root)
            _mapped, request = _request(root)
            observations = _observations(root, request)
            observations[0]["evidence_sha"] = "sha256:" + "f" * 64
            with self.assertRaises(readiness.DispatchReadinessError) as ctx:
                readiness.evaluate_dispatch_readiness(
                    repo_root=root,
                    request=request,
                    observations=observations,
                )
        self.assertTrue(any("content hash mismatch" in e for e in ctx.exception.errors))

    def test_self_declared_human_rollout_observation_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            _repo(root)
            _mapped, request = _request(root)
            observations = _observations(root, request)
            ref, sha = _evidence(root, "fake-human", "enable r1\n")
            observations.append({
                "schema_version": "1",
                "domain": readiness.OBS_DOMAIN,
                "kind": "rollout_decision_recorded",
                "request_hash": request["request_hash"],
                "platform": "codex",
                "observed_at": "2026-10-03T08:09:00Z",
                "source_kind": "human_decision",
                "verdict": "pass",
                "evidence_ref": ref,
                "evidence_sha": sha,
                "decision": "enable_r1_read_only_dispatch",
            })
            with self.assertRaises(readiness.DispatchReadinessError) as ctx:
                readiness.evaluate_dispatch_readiness(
                    repo_root=root,
                    request=request,
                    observations=observations,
                )
        self.assertTrue(any(".kind:" in e for e in ctx.exception.errors))

    def test_conflicting_observations_fail_readiness(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            _repo(root)
            _mapped, request = _request(root)
            observations = _observations(root, request)
            conflict = copy.deepcopy(observations[0])
            ref, sha = _evidence(root, "conflict", "registration: fail\n")
            conflict["evidence_ref"] = ref
            conflict["evidence_sha"] = sha
            conflict["verdict"] = "fail"
            observations.append(conflict)
            result = readiness.evaluate_dispatch_readiness(
                repo_root=root,
                request=request,
                observations=observations,
            )
        self.assertFalse(result["dispatch_ready"])
        self.assertIn("runtime_role_registered", result["conflicts"])

    def test_request_tamper_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            _repo(root)
            _mapped, request = _request(root)
            observations = _observations(root, request)
            request["authority"]["agent_invoke_allowed"] = True
            with self.assertRaises(readiness.DispatchReadinessError) as ctx:
                readiness.evaluate_dispatch_readiness(
                    repo_root=root,
                    request=request,
                    observations=observations,
                )
        self.assertTrue(any("canonical request hash mismatch" in e for e in ctx.exception.errors))

    def test_raw_runtime_output_field_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            _repo(root)
            _mapped, request = _request(root)
            observations = _observations(root, request)
            observations[0]["command_output"] = "agent registered"
            with self.assertRaises(readiness.DispatchReadinessError) as ctx:
                readiness.evaluate_dispatch_readiness(
                    repo_root=root,
                    request=request,
                    observations=observations,
                )
        self.assertTrue(any("command_output" in e for e in ctx.exception.errors))


if __name__ == "__main__":
    unittest.main()
