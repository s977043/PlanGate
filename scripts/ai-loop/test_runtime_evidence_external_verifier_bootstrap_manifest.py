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

import pathlib
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
import sys

sys.path.insert(0, str(HERE))

import runtime_evidence_external_verifier_bootstrap_manifest as manifest  # noqa: E402


class ExternalVerifierBootstrapManifestTest(unittest.TestCase):
    def _package(self, root: pathlib.Path) -> pathlib.Path:
        package = root / manifest.PACKAGE_RELATIVE_DIR
        package.mkdir(parents=True)
        for index, name in enumerate(manifest.REQUIRED_FILES, start=1):
            (package / name).write_bytes(f"fixture-{index}\n".encode("utf-8"))
        return package

    def test_build_manifest_is_stable_and_fail_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp).resolve()
            package = self._package(root)
            commit = "1" * 40

            first = manifest.build_manifest(
                repo_root=root,
                bootstrap_dir=package,
                declared_source_commit=commit,
            )
            second = manifest.build_manifest(
                repo_root=root,
                bootstrap_dir=package,
                declared_source_commit=commit,
            )

            self.assertEqual(first, second)
            self.assertEqual(first["package_file_count"], 4)
            self.assertTrue(first["exact_required_file_set_verified"])
            self.assertTrue(first["package_bytes_content_addressed_candidate"])
            self.assertTrue(first["declared_source_commit_bound_candidate"])
            self.assertFalse(first["bootstrap_contract_semantics_revalidated"])
            self.assertFalse(first["source_commit_repository_membership_verified"])
            self.assertFalse(first["external_operator_received_package_verified"])
            self.assertFalse(first["external_operator_accepted_package_verified"])
            self.assertFalse(first["independent_admin_boundary_verified"])
            self.assertFalse(first["runtime_probe_attestation_verified"])
            self.assertFalse(first["human_rollout_decision_verified"])
            self.assertFalse(first["dispatch_ready"])
            self.assertFalse(first["dispatch_allowed"])
            self.assertTrue(all(v is False for v in first["authority"].values()))

    def test_byte_change_changes_package_hash(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp).resolve()
            package = self._package(root)
            commit = "2" * 40

            before = manifest.build_manifest(
                repo_root=root,
                bootstrap_dir=package,
                declared_source_commit=commit,
            )
            target = package / manifest.REQUIRED_FILES[0]
            target.write_bytes(target.read_bytes() + b"changed\n")
            after = manifest.build_manifest(
                repo_root=root,
                bootstrap_dir=package,
                declared_source_commit=commit,
            )

            self.assertNotEqual(
                before["package_content_hash"],
                after["package_content_hash"],
            )
            self.assertNotEqual(before["result_hash"], after["result_hash"])

    def test_declared_commit_change_changes_package_hash(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp).resolve()
            package = self._package(root)

            first = manifest.build_manifest(
                repo_root=root,
                bootstrap_dir=package,
                declared_source_commit="3" * 40,
            )
            second = manifest.build_manifest(
                repo_root=root,
                bootstrap_dir=package,
                declared_source_commit="4" * 40,
            )

            self.assertNotEqual(
                first["package_content_hash"],
                second["package_content_hash"],
            )

    def test_missing_file_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp).resolve()
            package = self._package(root)
            (package / manifest.REQUIRED_FILES[-1]).unlink()

            with self.assertRaises(
                manifest.ExternalVerifierBootstrapManifestError
            ):
                manifest.build_manifest(
                    repo_root=root,
                    bootstrap_dir=package,
                    declared_source_commit="5" * 40,
                )

    def test_unexpected_file_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp).resolve()
            package = self._package(root)
            (package / "extra-instructions.txt").write_text(
                "unexpected\n",
                encoding="utf-8",
            )

            with self.assertRaises(
                manifest.ExternalVerifierBootstrapManifestError
            ):
                manifest.build_manifest(
                    repo_root=root,
                    bootstrap_dir=package,
                    declared_source_commit="5" * 40,
                )

    def test_symlink_file_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp).resolve()
            package = self._package(root)
            target = package / manifest.REQUIRED_FILES[0]
            backing = root / "backing.txt"
            backing.write_text("backing\n", encoding="utf-8")
            target.unlink()
            try:
                target.symlink_to(backing)
            except OSError as exc:
                self.skipTest(f"symlink unavailable: {exc}")

            with self.assertRaises(
                manifest.ExternalVerifierBootstrapManifestError
            ):
                manifest.build_manifest(
                    repo_root=root,
                    bootstrap_dir=package,
                    declared_source_commit="6" * 40,
                )

    def test_wrong_package_path_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp).resolve()
            package = root / "other"
            package.mkdir()
            for index, name in enumerate(manifest.REQUIRED_FILES, start=1):
                (package / name).write_bytes(f"fixture-{index}\n".encode("utf-8"))

            with self.assertRaises(
                manifest.ExternalVerifierBootstrapManifestError
            ):
                manifest.build_manifest(
                    repo_root=root,
                    bootstrap_dir=package,
                    declared_source_commit="7" * 40,
                )

    def test_invalid_commit_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp).resolve()
            package = self._package(root)

            with self.assertRaises(
                manifest.ExternalVerifierBootstrapManifestError
            ):
                manifest.build_manifest(
                    repo_root=root,
                    bootstrap_dir=package,
                    declared_source_commit="main",
                )


if __name__ == "__main__":
    unittest.main()
