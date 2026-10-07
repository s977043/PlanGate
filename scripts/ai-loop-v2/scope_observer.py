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

import fnmatch
import pathlib
import posixpath
import re
import subprocess


class ScopeObservationError(ValueError):
    """The deterministic scope observer cannot prove the requested fact."""


class ManifestObservationError(ScopeObservationError):
    """HarnessManifest content is insufficient to derive component delta."""


class NonCanonicalPath(ScopeObservationError):
    """A changed path is not canonical, so scope cannot be proven."""


_COMMIT_RE = re.compile(r"(?:[0-9a-f]{40}|[0-9a-f]{64})\Z")


def canonical_path(path):
    """Return a canonical relative path or URI-like repository path.

    fnmatch lets "*" cross "/", so paths must be canonical before scope
    matching. Empty, absolute, "."/"..", duplicate-separator, and malformed
    scheme paths fail closed.
    """
    if not isinstance(path, str) or not path:
        raise NonCanonicalPath("changed_paths: empty path")
    scheme, sep, rest = path.partition("://")
    if not sep:
        scheme, rest = "", path
    if scheme and ("/" in scheme or not scheme.replace("-", "").isalnum()):
        raise NonCanonicalPath("changed_paths: invalid scheme: " + path)
    if not rest or rest.startswith("/"):
        raise NonCanonicalPath(
            "changed_paths: absolute or empty path: " + path
        )
    if posixpath.normpath(rest) != rest or ".." in rest.split("/"):
        raise NonCanonicalPath("changed_paths: non-canonical path: " + path)
    return path


def changed_paths_within_scope(changed_paths, allowed_scope):
    if not isinstance(changed_paths, list) or not changed_paths:
        raise ScopeObservationError("changed_paths")
    paths = [canonical_path(path) for path in changed_paths]
    if not isinstance(allowed_scope, list) or not allowed_scope:
        raise ScopeObservationError("allowed_scope")
    return all(
        any(fnmatch.fnmatch(path, pattern) for pattern in allowed_scope)
        for path in paths
    )


def paths_intersect(paths, protected):
    return any(
        any(fnmatch.fnmatch(path, pattern) for pattern in protected)
        for path in paths
    )


def scope_patterns_intersect(declared, protected):
    def prefix(pattern):
        indexes = [
            index
            for token in ("*", "?", "[")
            if (index := pattern.find(token)) >= 0
        ]
        return pattern[: min(indexes)] if indexes else pattern

    for left in declared:
        for right in protected:
            if fnmatch.fnmatch(left, right) or fnmatch.fnmatch(right, left):
                return True
            left_prefix = prefix(left)
            right_prefix = prefix(right)
            if (
                left_prefix.startswith(right_prefix)
                or right_prefix.startswith(left_prefix)
            ):
                return True
    return False


def _index_components(manifest):
    components = manifest.get("components")
    if not isinstance(components, list):
        raise ManifestObservationError("MANIFEST_COMPONENT_IDENTITY")
    index = {}
    for item in components:
        component_id = item.get("component_id") if isinstance(item, dict) else None
        if (
            not isinstance(component_id, str)
            or not component_id
            or component_id in index
        ):
            raise ManifestObservationError("MANIFEST_COMPONENT_IDENTITY")
        index[component_id] = item
    return index


def _component_paths(component):
    paths = component.get("paths")
    if not isinstance(paths, list) or not paths:
        raise ManifestObservationError("COMPONENT_PATHS_MISSING")
    return paths


def observe_manifest_delta(baseline, candidate):
    """Derive changed Harness components and their declared paths.

    This is an identity/manifest observation. Repository-backed evaluation
    must additionally observe the actual changed repository paths and compare
    them with this result.
    """
    before = _index_components(baseline)
    after = _index_components(candidate)
    deltas = []
    changed_paths = set()
    for component_id in sorted(set(before) | set(after)):
        left = before.get(component_id)
        right = after.get(component_id)
        if left == right:
            continue
        deltas.append(
            {
                "component_id": component_id,
                "before_content_sha": left.get("content_sha") if left else None,
                "after_content_sha": right.get("content_sha") if right else None,
            }
        )
        for side in (left, right):
            if side is None:
                continue
            for path in _component_paths(side):
                changed_paths.add(canonical_path(path))
    return deltas, sorted(changed_paths)


def _require_commit_ref(value):
    if not isinstance(value, str) or not _COMMIT_RE.fullmatch(value):
        raise ScopeObservationError("REPOSITORY_COMMIT_REF")
    return value


def _git(root, args):
    try:
        completed = subprocess.run(
            ["git", "-C", str(root), *args],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except OSError as exc:
        raise ScopeObservationError("REPOSITORY_OBSERVER_UNAVAILABLE") from exc
    if completed.returncode != 0:
        raise ScopeObservationError("REPOSITORY_OBSERVER_UNAVAILABLE")
    return completed.stdout


def observe_repository_delta(repo_root, baseline_commit, candidate_commit):
    """Observe actual changed paths from an exact repository commit pair.

    The observer accepts only full lowercase commit object IDs and invokes git
    without a shell. It does not consume Candidate-declared changed paths.
    """
    baseline = _require_commit_ref(baseline_commit)
    candidate = _require_commit_ref(candidate_commit)

    root = pathlib.Path(repo_root).resolve()
    if not root.is_dir():
        raise ScopeObservationError("REPOSITORY_OBSERVER_UNAVAILABLE")

    top = _git(root, ["rev-parse", "--show-toplevel"])
    try:
        observed_root = pathlib.Path(top.decode("utf-8").strip()).resolve()
    except UnicodeDecodeError as exc:
        raise ScopeObservationError("REPOSITORY_OBSERVER_UNAVAILABLE") from exc
    if observed_root != root:
        raise ScopeObservationError("REPOSITORY_ROOT_MISMATCH")

    _git(root, ["cat-file", "-e", baseline + "^{commit}"])
    _git(root, ["cat-file", "-e", candidate + "^{commit}"])

    raw = _git(
        root,
        [
            "diff",
            "--name-only",
            "-z",
            "--no-renames",
            baseline,
            candidate,
            "--",
        ],
    )
    changed = []
    for encoded in raw.split(b"\0"):
        if not encoded:
            continue
        try:
            path = encoded.decode("utf-8")
        except UnicodeDecodeError as exc:
            raise ScopeObservationError("REPOSITORY_PATH_ENCODING") from exc
        changed.append(canonical_path(path))

    if not changed:
        raise ScopeObservationError("REPOSITORY_DELTA_EMPTY")
    return {
        "baseline_commit": baseline,
        "candidate_commit": candidate,
        "changed_paths": sorted(set(changed)),
    }
