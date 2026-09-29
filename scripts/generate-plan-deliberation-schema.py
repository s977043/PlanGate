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

__doc__ = """Generate the Plan Deliberation v1 JSON Schema deterministically.

TASK-1353 / #1353. This file is AI-owned. The generated target
schemas/plan-deliberation.schema.json is Hardening Override and must be applied
by a Human through scripts/apply-task-1353-plan-deliberation-schema.sh.
"""

import json
import sys


SHA256 = r"^sha256:[0-9a-f]{64}$"
GIT_SHA = r"^[0-9a-f]{7,40}$"


def string_array(*, min_items: int = 0) -> dict:
    out = {"type": "array", "items": {"type": "string"}}
    if min_items:
        out["minItems"] = min_items
    return out


def build_schema() -> dict:
    position_base = {
        "type": "object",
        "required": [
            "position_id",
            "participant_ref",
            "stance",
            "claim",
            "rationale_summary",
            "evidence_refs",
            "assumptions",
        ],
        "properties": {
            "position_id": {"type": "string", "minLength": 1},
            "participant_ref": {"type": "string", "minLength": 1},
            "source_finding_ref": {"type": "string", "minLength": 1},
            "stance": {
                "type": "string",
                "enum": ["support", "oppose", "conditional", "unknown"],
            },
            "claim": {"type": "string", "minLength": 1},
            "rationale_summary": {"type": "string", "minLength": 1},
            "evidence_refs": string_array(),
            "assumptions": string_array(),
        },
        "additionalProperties": False,
    }

    final_position = {
        "type": "object",
        "required": [
            *position_base["required"],
            "changed",
            "change_reason",
        ],
        "properties": {
            **position_base["properties"],
            "changed": {"type": "boolean"},
            "change_reason": {
                "type": "string",
                "enum": [
                    "factual_error",
                    "stronger_evidence",
                    "wrong_assumption",
                    "missing_constraint",
                    "unchanged",
                ],
            },
        },
        "additionalProperties": False,
        "allOf": [
            {
                "if": {
                    "properties": {"changed": {"const": False}},
                    "required": ["changed"],
                },
                "then": {
                    "properties": {"change_reason": {"const": "unchanged"}},
                },
                "else": {
                    "properties": {
                        "change_reason": {
                            "enum": [
                                "factual_error",
                                "stronger_evidence",
                                "wrong_assumption",
                                "missing_constraint",
                            ]
                        }
                    }
                },
            }
        ],
    }

    schema = {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": (
            "https://github.com/s977043/plangate/"
            "schemas/plan-deliberation.schema.json"
        ),
        "title": "PlanGate Plan Deliberation Artifact v1",
        "description": (
            "Experimental Plan Deliberation feature artifact. The schema file "
            "itself follows the repository Stable JSON Schema compatibility "
            "policy. Deliberation clarifies disagreement; it is not an approval "
            "or gate decision."
        ),
        "type": "object",
        "required": [
            "schema_version",
            "artifact_type",
            "stability",
            "task_id",
            "plan_ref",
            "source_reviews",
            "execution",
            "trigger",
            "participants",
            "problem_frames",
            "positions",
            "outcome",
        ],
        "properties": {
            "schema_version": {"type": "integer", "const": 1},
            "artifact_type": {"type": "string", "const": "plan-deliberation"},
            "stability": {"type": "string", "enum": ["experimental"]},
            "task_id": {"type": "string", "pattern": r"^TASK-[0-9]{4}$"},
            "plan_ref": {
                "type": "object",
                "required": ["plan_hash", "source_sha"],
                "properties": {
                    "plan_hash": {"type": "string", "pattern": SHA256},
                    "source_sha": {"type": "string", "pattern": GIT_SHA},
                    "plan_package_hash": {"type": "string", "pattern": SHA256},
                },
                "additionalProperties": False,
            },
            "source_reviews": {
                "type": "array",
                "minItems": 1,
                "items": {
                    "type": "object",
                    "required": [
                        "review_ref",
                        "reviewer_id",
                        "lane",
                        "execution_status",
                    ],
                    "properties": {
                        "review_ref": {"type": "string", "minLength": 1},
                        "reviewer_id": {"type": "string", "minLength": 1},
                        "lane": {"type": "string", "minLength": 1},
                        "execution_status": {
                            "type": "string",
                            "enum": ["executed", "unavailable"],
                        },
                    },
                    "additionalProperties": False,
                },
            },
            "execution": {
                "type": "object",
                "required": ["status", "limitations"],
                "properties": {
                    "status": {
                        "type": "string",
                        "enum": ["completed", "partial", "unavailable", "not_run"],
                    },
                    "limitations": string_array(),
                },
                "additionalProperties": False,
            },
            "trigger": {
                "type": "object",
                "required": ["reason_codes"],
                "properties": {
                    "reason_codes": {
                        "type": "array",
                        "minItems": 1,
                        "uniqueItems": True,
                        "items": {
                            "type": "string",
                            "enum": [
                                "reviewer_conflict",
                                "evidence_conflict",
                                "assumption_conflict",
                                "approach_conflict",
                                "major_singleton",
                                "human_decision_required",
                            ],
                        },
                    },
                    "detail": {"type": "string"},
                },
                "additionalProperties": False,
            },
            "participants": {
                "type": "array",
                "items": {
                    "type": "object",
                    "required": ["participant_id", "reviewer_id", "lane"],
                    "properties": {
                        "participant_id": {"type": "string", "minLength": 1},
                        "reviewer_id": {"type": "string", "minLength": 1},
                        "lane": {"type": "string", "minLength": 1},
                    },
                    "additionalProperties": False,
                },
            },
            "problem_frames": {
                "type": "array",
                "items": {
                    "type": "object",
                    "required": [
                        "participant_ref",
                        "objective",
                        "constraints",
                        "non_goals",
                        "assumptions",
                        "unknowns",
                    ],
                    "properties": {
                        "participant_ref": {"type": "string", "minLength": 1},
                        "objective": {"type": "string", "minLength": 1},
                        "constraints": string_array(),
                        "non_goals": string_array(),
                        "assumptions": string_array(),
                        "unknowns": string_array(),
                    },
                    "additionalProperties": False,
                },
            },
            "positions": {
                "type": "object",
                "required": ["initial", "challenges", "final"],
                "properties": {
                    "initial": {
                        "type": "array",
                        "items": {"$ref": "#/$defs/position"},
                    },
                    "challenges": {
                        "type": "array",
                        "items": {"$ref": "#/$defs/challenge"},
                    },
                    "final": {
                        "type": "array",
                        "items": {"$ref": "#/$defs/finalPosition"},
                    },
                },
                "additionalProperties": False,
            },
            "outcome": {
                "type": "object",
                "required": [
                    "status",
                    "agreements",
                    "unresolved",
                    "evidence_needed",
                    "replan_trigger_proposals",
                    "human_decisions",
                    "requires_c2_rereview",
                    "rereview_reasons",
                ],
                "properties": {
                    "status": {
                        "type": "string",
                        "enum": [
                            "converged",
                            "split",
                            "insufficient_evidence",
                        ],
                    },
                    "agreements": string_array(),
                    "unresolved": string_array(),
                    "evidence_needed": string_array(),
                    "replan_trigger_proposals": string_array(),
                    "human_decisions": string_array(),
                    "requires_c2_rereview": {"type": "boolean"},
                    "rereview_reasons": string_array(),
                },
                "additionalProperties": False,
            },
        },
        "additionalProperties": False,
        "allOf": [
            {
                "if": {
                    "properties": {
                        "source_reviews": {
                            "contains": {
                                "type": "object",
                                "properties": {
                                    "execution_status": {"const": "unavailable"}
                                },
                                "required": ["execution_status"],
                            }
                        }
                    },
                    "required": ["source_reviews"],
                },
                "then": {
                    "properties": {
                        "execution": {
                            "properties": {
                                "status": {
                                    "enum": ["partial", "unavailable", "not_run"]
                                }
                            }
                        }
                    }
                },
            },
            {
                "if": {
                    "properties": {
                        "execution": {
                            "properties": {"status": {"const": "completed"}},
                            "required": ["status"],
                        }
                    },
                    "required": ["execution"],
                },
                "then": {
                    "properties": {
                        "participants": {"minItems": 1},
                        "problem_frames": {"minItems": 1},
                        "positions": {
                            "properties": {
                                "initial": {"minItems": 1},
                                "final": {"minItems": 1},
                            }
                        },
                    }
                },
            },
            {
                "if": {
                    "properties": {
                        "execution": {
                            "properties": {"status": {"const": "partial"}},
                            "required": ["status"],
                        }
                    },
                    "required": ["execution"],
                },
                "then": {
                    "properties": {
                        "outcome": {
                            "properties": {
                                "status": {
                                    "enum": ["split", "insufficient_evidence"]
                                }
                            }
                        }
                    }
                },
            },
            {
                "if": {
                    "properties": {
                        "execution": {
                            "properties": {
                                "status": {
                                    "enum": ["unavailable", "not_run"]
                                }
                            },
                            "required": ["status"],
                        }
                    },
                    "required": ["execution"],
                },
                "then": {
                    "properties": {
                        "outcome": {
                            "properties": {
                                "status": {"const": "insufficient_evidence"}
                            }
                        }
                    }
                },
            },
            {
                "if": {
                    "properties": {
                        "outcome": {
                            "properties": {"status": {"const": "split"}},
                            "required": ["status"],
                        }
                    },
                    "required": ["outcome"],
                },
                "then": {
                    "properties": {
                        "outcome": {
                            "properties": {"unresolved": {"minItems": 1}}
                        }
                    }
                },
            },
            {
                "if": {
                    "properties": {
                        "outcome": {
                            "properties": {
                                "requires_c2_rereview": {"const": True}
                            },
                            "required": ["requires_c2_rereview"],
                        }
                    },
                    "required": ["outcome"],
                },
                "then": {
                    "properties": {
                        "outcome": {
                            "properties": {
                                "status": {
                                    "enum": ["split", "insufficient_evidence"]
                                },
                                "rereview_reasons": {"minItems": 1},
                            }
                        }
                    }
                },
                "else": {
                    "properties": {
                        "outcome": {
                            "properties": {
                                "rereview_reasons": {"maxItems": 0}
                            }
                        }
                    }
                },
            },
        ],
        "$defs": {
            "position": position_base,
            "finalPosition": final_position,
            "challenge": {
                "type": "object",
                "required": [
                    "challenge_id",
                    "from_position_ref",
                    "target_position_ref",
                    "statement",
                    "evidence_refs",
                ],
                "properties": {
                    "challenge_id": {"type": "string", "minLength": 1},
                    "from_position_ref": {"type": "string", "minLength": 1},
                    "target_position_ref": {"type": "string", "minLength": 1},
                    "statement": {"type": "string", "minLength": 1},
                    "evidence_refs": string_array(),
                },
                "additionalProperties": False,
            },
        },
    }
    return schema


def main() -> int:
    schema = build_schema()
    try:
        from jsonschema import Draft202012Validator
    except ImportError:
        pass
    else:
        Draft202012Validator.check_schema(schema)
    sys.stdout.write(json.dumps(schema, ensure_ascii=False, indent=2, sort_keys=True))
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
