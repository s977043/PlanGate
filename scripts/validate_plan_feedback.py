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


"""Strict, read-only validator for untrusted plan-review-feedback JSON.

Checks source freshness, not signer identity or C-3 approval.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import hmac
import json
import os
import re
import sys

from review_questions import _questions, _read, _strict_object

MAX_FEEDBACK_BYTES = 512 * 1024
TASK_RE = re.compile(r"^TASK-[0-9]{4}$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
STATES = ("answered", "deferred", "unanswered")


def _exact_mapping(obj, fields, name):
    if not isinstance(obj, dict) or set(obj) != set(fields):
        raise ValueError("invalid %s structure" % name)
    return obj


def _source_digest(payload, label, filename, path):
    obj = _exact_mapping(payload, ("path", "sha256"), "source " + label)
    if obj["path"] != filename:
        raise ValueError("invalid source path for " + label)
    expected = obj["sha256"]
    if not isinstance(expected, str) or not SHA256_RE.fullmatch(expected):
        raise ValueError("invalid source SHA-256 for " + label)
    actual = hashlib.sha256(_read(path)).hexdigest()
    if not hmac.compare_digest(expected, actual):
        raise ValueError("stale source SHA-256: " + label)


def _feedback_payload(raw):
    try:
        result = json.loads(raw.decode("utf-8"), object_pairs_hook=_strict_object)
    except (UnicodeError, ValueError) as exc:
        raise ValueError("invalid feedback JSON") from exc
    return _exact_mapping(
        result,
        ("schemaVersion", "kind", "taskId", "source", "feedback_only",
         "approval_granted", "generatedAt", "answers"),
        "feedback",
    )


def validate_feedback(work_dir, task_id, feedback_file):
    """Validate a review-only sidecar without modifying the repository.

    A successful result is not authentication, a reviewer verdict, or approval.
    """
    if not isinstance(task_id, str) or not TASK_RE.fullmatch(task_id):
        raise ValueError("invalid TASK identifier")

    payload = _feedback_payload(_read(feedback_file, MAX_FEEDBACK_BYTES))
    if type(payload["schemaVersion"]) is not int or payload["schemaVersion"] != 1:
        raise ValueError("unsupported feedback version")
    if payload["kind"] != "plan-review-feedback" or payload["taskId"] != task_id:
        raise ValueError("feedback kind or task mismatch")
    if payload["feedback_only"] is not True or payload["approval_granted"] is not False:
        raise ValueError("feedback is not explicitly non-authoritative")

    timestamp = payload["generatedAt"]
    if not isinstance(timestamp, str) or not timestamp.endswith("Z"):
        raise ValueError("invalid generatedAt timestamp")
    try:
        parsed = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ValueError("invalid generatedAt timestamp") from exc
    if parsed.tzinfo is None or parsed.utcoffset() != timezone.utc.utcoffset(parsed):
        raise ValueError("timestamp must be UTC")

    src = _exact_mapping(payload["source"], ("plan", "questions"), "source")
    _source_digest(src["plan"], "plan", "plan.md", os.path.join(work_dir, "plan.md"))
    questions_path = os.path.join(work_dir, "review-questions.json")
    # Validate the same raw questions file for both integrity and schema.
    qbytes = _read(questions_path, 131072)
    _source_digest(src["questions"], "questions", "review-questions.json", questions_path)
    questions = _questions(qbytes)
    definitions = {q["id"]: q for q in questions}

    answers = payload["answers"]
    if not isinstance(answers, list) or len(answers) != len(questions):
        raise ValueError("answer count does not match questions")
    seen = set()
    counts = {key: 0 for key in STATES}
    for answer in answers:
        _exact_mapping(answer, ("questionId", "status", "response", "note"), "answer")
        qid = answer["questionId"]
        if not isinstance(qid, str) or qid not in definitions or qid in seen:
            raise ValueError("unknown or duplicate answer question ID")
        seen.add(qid)
        status, response, note = answer["status"], answer["response"], answer["note"]
        if status not in STATES:
            raise ValueError("invalid answer status")
        if not isinstance(response, str) or len(response) > 4000:
            raise ValueError("invalid response")
        if not isinstance(note, str) or len(note) > 4000:
            raise ValueError("invalid note")
        if status == "answered":
            if not response.strip():
                raise ValueError("answered question must include response")
            choices = definitions[qid].get("choices", [])
            if choices and response not in choices:
                raise ValueError("answer does not match allowed choices")
        elif status == "deferred":
            if response or not note.strip():
                raise ValueError("deferred question must have only a reason note")
        elif response or note:
            raise ValueError("unanswered question must be empty")
        counts[status] += 1

    return {
        "status": "VALID_REVIEW_FEEDBACK",
        "taskId": task_id,
        "feedback_only": True,
        "approval_granted": False,
        "counts": counts,
    }


def main():
    parser = argparse.ArgumentParser(
        description="Validate plan review feedback (never grants approval)."
    )
    parser.add_argument("--task", required=True, help="TASK-XXXX")
    parser.add_argument("--feedback", required=True, help="JSON exported by plan viewer")
    parser.add_argument("--work-dir", default=None, help="Folder containing plan.md")
    args = parser.parse_args()
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    work_dir = args.work_dir or os.path.join(repo, "docs", "working", args.task)
    try:
        report = validate_feedback(work_dir, args.task, args.feedback)
    except (OSError, ValueError) as exc:
        print("error: review feedback invalid: %s" % exc, file=sys.stderr)
        return 2
    print(json.dumps(report, sort_keys=True, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
