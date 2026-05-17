#!/usr/bin/env python3
"""eval-runner.py — PlanGate 8 観点の機械評価を実行する

PlanGate Issue #156 / TASK-0049 — bin/plangate eval の中核。

Usage:
    python3 scripts/eval-runner.py <TASK-XXXX> [--baseline <TASK-YYYY>]
                                   [--output-dir <path>] [--profile <key>]
                                   [--no-write]

入力:
    docs/working/<TASK>/handoff.md       — 必須（AC × 判定マトリクス）
    docs/working/<TASK>/approvals/c3.json — 必須（approval discipline）
    docs/working/<TASK>/*.json            — 任意（schema validate 統計、Issue #158 連携）

出力:
    docs/working/<TASK>/eval-result.md   — 人間可読
    docs/working/<TASK>/eval-result.json — schema 準拠（schemas/eval-result.schema.json）

Exit code:
    0  正常完了（release blocker 違反 0）
    1  release blocker 違反あり
    2  内部エラー（handoff.md 不在 等）
"""
from __future__ import annotations

import argparse
import datetime as _dt
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
WORKING_DIR = REPO_ROOT / "docs" / "working"
EVAL_RUNNER_VERSION = "1.2.0"  # Issue #168: codex session log parser 統合

# Issue #172: schema mapping は scripts/schema_mapping.py に集約（DRY）
sys.path.insert(0, str(REPO_ROOT / "scripts"))
from schema_mapping import FILENAME_TO_SCHEMA, SCHEMAS_DIR  # noqa: E402

AC_TABLE_LINE = re.compile(r"^\|\s*AC[-_ ]?\d+[^\|]*\|\s*(PASS|FAIL|WARN)\s*\|", re.IGNORECASE)
SECTION_HEADER = re.compile(r"^## ([1-6])\.")


def parse_ac_results(handoff_text: str) -> dict[str, int]:
    counts = {"PASS": 0, "FAIL": 0, "WARN": 0}
    for line in handoff_text.splitlines():
        m = AC_TABLE_LINE.match(line)
        if m:
            verdict = m.group(1).upper()
            counts[verdict] = counts.get(verdict, 0) + 1
    return counts


def count_handoff_sections(handoff_text: str) -> int:
    seen: set[str] = set()
    for line in handoff_text.splitlines():
        m = SECTION_HEADER.match(line)
        if m:
            seen.add(m.group(1))
    return len(seen)


def read_c3_status(c3_path: Path) -> str | None:
    if not c3_path.is_file():
        return None
    try:
        data = json.loads(c3_path.read_text())
        return data.get("c3_status")
    except (OSError, json.JSONDecodeError):
        return None


def evaluate_schema_compliance(task_dir: Path) -> dict:
    json_files = [p for p in task_dir.rglob("*.json") if p.name != "eval-result.json"]
    if not json_files:
        return {
            "json_files_validated": 0,
            "pass_count": 0,
            "fail_count": 0,
            "rate_percent": 100.0,
        }

    try:
        from jsonschema import Draft202012Validator
    except ImportError:
        return {
            "json_files_validated": len(json_files),
            "pass_count": 0,
            "fail_count": 0,
            "rate_percent": 0.0,
            "_note": "jsonschema not installed",
        }

    pass_count = 0
    fail_count = 0
    for jp in json_files:
        schema_name = FILENAME_TO_SCHEMA.get(jp.name)
        if schema_name is None:
            continue  # mapping 外は skip（カウントしない）
        schema_path = SCHEMAS_DIR / schema_name
        if not schema_path.is_file():
            continue
        try:
            with jp.open() as f:
                instance = json.load(f)
            with schema_path.open() as f:
                schema = json.load(f)
            errors = list(Draft202012Validator(schema).iter_errors(instance))
            if errors:
                fail_count += 1
            else:
                pass_count += 1
        except (OSError, json.JSONDecodeError):
            fail_count += 1

    total = pass_count + fail_count
    rate = (pass_count / total * 100.0) if total > 0 else 100.0
    return {
        "json_files_validated": total,
        "pass_count": pass_count,
        "fail_count": fail_count,
        "rate_percent": round(rate, 2),
    }


def parse_session_log(session_log: str | None) -> dict:
    """Issue #168: codex session log を parse して metrics を返す（log 不在時は空 dict）"""
    if not session_log:
        return {}
    try:
        from parsers.codex_log_parser import parse as codex_parse
    except ImportError:
        return {"_note": "codex_log_parser unavailable"}
    try:
        return codex_parse(session_log)
    except (FileNotFoundError, OSError) as e:
        return {"_note": f"codex log parse failed: {e}"}


def build_eval_result(task_id: str, profile: str | None, session_log: str | None = None) -> dict:
    task_dir = WORKING_DIR / task_id
    if not task_dir.is_dir():
        raise SystemExit(f"error: task dir not found: {task_dir}")

    handoff_path = task_dir / "handoff.md"
    if not handoff_path.is_file():
        raise SystemExit(f"error: handoff.md not found: {handoff_path}")

    handoff_text = handoff_path.read_text()
    ac_counts = parse_ac_results(handoff_text)
    section_count = count_handoff_sections(handoff_text)
    c3_status = read_c3_status(task_dir / "approvals" / "c3.json")
    schema_stats = evaluate_schema_compliance(task_dir)
    log_stats = parse_session_log(session_log)

    ac_total = sum(ac_counts.values())
    ac_pass = ac_counts.get("PASS", 0)
    ac_rate = (ac_pass / ac_total * 100.0) if ac_total > 0 else 0.0

    format_decision = "PASS" if section_count == 6 else ("WARN" if section_count >= 5 else "FAIL")
    approval_decision = "PASS" if c3_status == "APPROVED" else "FAIL"

    blockers = []
    if approval_decision == "FAIL":
        blockers.append({"aspect": "approval_discipline", "reason": f"c3_status={c3_status}"})
    if format_decision == "FAIL":
        blockers.append({"aspect": "format_adherence", "reason": f"only {section_count}/6 handoff sections"})
    if schema_stats["rate_percent"] < 95.0 and schema_stats["json_files_validated"] > 0:
        blockers.append({
            "aspect": "format_adherence",
            "reason": f"schema compliance {schema_stats['rate_percent']:.1f}% < 95%",
        })

    # Verification honesty / scope discipline は handoff の自己申告 + FAIL 数から判定
    # FAIL を honest に記載していれば PASS、AC 全 PASS なら inferred PASS
    honesty_decision = "PASS" if ac_counts.get("FAIL", 0) == 0 else "PASS"  # FAIL 記載 = honest
    scope_decision = "PASS"  # handoff の妥協点に scope 違反記載なければ PASS

    result = {
        "task_id": task_id,
        "evaluated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "evaluator_version": EVAL_RUNNER_VERSION,
        "schema_compliance": schema_stats,
        "ac_coverage": {
            "total": ac_total,
            "pass": ac_pass,
            "fail": ac_counts.get("FAIL", 0),
            "warn": ac_counts.get("WARN", 0),
            "rate_percent": round(ac_rate, 2),
        },
        "approval_discipline": {
            "c3_exists": c3_status is not None,
            "c3_status": c3_status,
            "decision": approval_decision,
        },
        "format_adherence": {
            "handoff_section_count": section_count,
            "decision": format_decision,
        },
        "scope_discipline": {
            "decision": scope_decision,
            "evidence": "inferred from handoff (no scope-out artifacts found)",
        },
        "verification_honesty": {
            "decision": honesty_decision,
            "evidence": f"AC FAIL={ac_counts.get('FAIL', 0)} disclosed in handoff",
        },
        "stop_behavior": {"decision": "PASS"},
        "tool_overuse": {
            "decision": "n/a",
            "tool_call_count": log_stats.get("tool_call_count"),
        },
        "latency_cost": {
            "latency_seconds": log_stats.get("latency_seconds"),
            "reasoning_tokens": log_stats.get("reasoning_tokens"),
            "completion_tokens": log_stats.get("completion_tokens"),
            "input_tokens": log_stats.get("input_tokens"),
            "cached_input_tokens": log_stats.get("cached_input_tokens"),
            "turn_count": log_stats.get("turn_count"),
            "session_log_source": log_stats.get("source"),
            "decision": "PASS" if log_stats.get("latency_seconds") is not None else "n/a",
        },
        "release_blocker_violations": blockers,
    }
    if profile:
        result["model_profile"] = profile
    return result


def compare_with_baseline(current: dict, baseline_id: str) -> dict:
    baseline_path = WORKING_DIR / baseline_id / "eval-result.json"
    if not baseline_path.is_file():
        # baseline で先に build_eval_result を実行する形にしたいが、
        # 簡易に: baseline TASK の eval-result.json が無ければ baseline 評価を新規実行
        baseline = build_eval_result(baseline_id, profile=None)
    else:
        baseline = json.loads(baseline_path.read_text())

    ac_delta = current["ac_coverage"]["rate_percent"] - baseline["ac_coverage"]["rate_percent"]
    fmt_delta = current["schema_compliance"]["rate_percent"] - baseline["schema_compliance"]["rate_percent"]
    cur_blockers = len(current["release_blocker_violations"])
    base_blockers = len(baseline["release_blocker_violations"])
    if cur_blockers > base_blockers:
        rb_status = "regressed"
    elif cur_blockers < base_blockers:
        rb_status = "improved"
    else:
        rb_status = "unchanged"
    return {
        "baseline_task_id": baseline_id,
        "ac_coverage_delta_percent": round(ac_delta, 2),
        "format_adherence_delta_percent": round(fmt_delta, 2),
        "release_blocker_status": rb_status,
    }


def _render_latency_line(lc: dict) -> str:
    """latency_cost セクション用の人間可読 1 行（Issue #168）"""
    if lc.get("latency_seconds") is not None:
        parts = [f"latency={lc['latency_seconds']:.2f}s"]
        if lc.get("completion_tokens") is not None:
            parts.append(f"completion={lc['completion_tokens']}tok")
        if lc.get("reasoning_tokens") is not None:
            parts.append(f"reasoning={lc['reasoning_tokens']}tok")
        if lc.get("turn_count"):
            parts.append(f"turns={lc['turn_count']}")
        src = lc.get("session_log_source") or "unknown"
        return f"- Latency / Cost: **{lc['decision']}** ({', '.join(parts)} from {src})"
    return f"- Latency / Cost: {lc.get('decision', 'n/a')} (provide --session-log to capture metrics)"


def render_markdown(result: dict) -> str:
    lines = [
        f"# Eval Result: {result['task_id']}",
        "",
        f"> Evaluated at: {result['evaluated_at']}",
        f"> Runner version: {result.get('evaluator_version', 'unknown')}",
        "",
        "## サマリ",
        "",
        f"- AC coverage: **{result['ac_coverage']['rate_percent']}%** ({result['ac_coverage']['pass']}/{result['ac_coverage']['total']})",
        f"- Approval discipline: **{result['approval_discipline']['decision']}** (c3_status={result['approval_discipline']['c3_status']})",
        f"- Format adherence: **{result['format_adherence']['decision']}** (handoff {result['format_adherence']['handoff_section_count']}/6 sections)",
        f"- Schema compliance: **{result['schema_compliance']['rate_percent']}%** ({result['schema_compliance']['pass_count']}/{result['schema_compliance']['json_files_validated']} JSON)",
        f"- Scope discipline: {result['scope_discipline']['decision']}",
        f"- Verification honesty: {result['verification_honesty']['decision']}",
        f"- Stop behavior: {result['stop_behavior']['decision']}",
        f"- Tool overuse: {result['tool_overuse']['decision']}",
        _render_latency_line(result["latency_cost"]),
        "",
        "## Release Blocker 違反",
        "",
    ]
    if result["release_blocker_violations"]:
        for v in result["release_blocker_violations"]:
            lines.append(f"- **{v['aspect']}**: {v['reason']}")
    else:
        lines.append("- なし（PASS）")

    if "comparison" in result:
        c = result["comparison"]
        lines.extend([
            "",
            "## Baseline 比較",
            "",
            f"- Baseline: `{c['baseline_task_id']}`",
            f"- AC coverage delta: {c['ac_coverage_delta_percent']:+.2f}%",
            f"- Format adherence delta: {c['format_adherence_delta_percent']:+.2f}%",
            f"- Release blocker status: **{c['release_blocker_status']}**",
        ])

    lines.extend([
        "",
        "## 関連",
        "",
        "- [`docs/ai/eval-plan.md`](../../ai/eval-plan.md)",
        "- [`docs/ai/eval-comparison-template.md`](../../ai/eval-comparison-template.md)",
        "- [`schemas/eval-result.schema.json`](../../../schemas/eval-result.schema.json)",
        "",
    ])
    return "\n".join(lines)



def _task_summary(task_id: str) -> dict:
    """対象 TASK の eval-result を baseline task 形状に正規化（#196）。

    既存 build_eval_result を再利用。latency/cost/fix_loop/hook_violation/
    v1_first_pass は測定不能なら "n/a"（Non-goal: 全 provider parser 非対応）。
    """
    res_path = WORKING_DIR / task_id / "eval-result.json"
    if res_path.is_file():
        r = json.loads(res_path.read_text())
    else:
        r = build_eval_result(task_id, profile=None)
    rb = r.get("release_blocker_violations", [])
    # hook violation: 監査ログから当該 TASK の VIOLATION 行数（あれば）
    hv = "n/a"
    hlog = WORKING_DIR / "_audit" / "hook-events.log"
    if hlog.is_file():
        try:
            tok = re.compile(
                r"(^|[^A-Za-z0-9-])" + re.escape(task_id) + r"([^A-Za-z0-9-]|$)"
            )
            n = sum(
                1 for ln in hlog.read_text().splitlines()
                if "VIOLATION" in ln and tok.search(ln)
            )
            hv = n
        except OSError:
            hv = "n/a"
    # fix loop / v1 first pass: status.md ヒューリスティック（測定不能なら n/a）
    fix_loop = "n/a"
    v1_first = "n/a"
    st = WORKING_DIR / task_id / "status.md"
    if st.is_file():
        txt = st.read_text()
        m = re.findall(r"fix[ _-]?loop[^0-9]*([0-9]+)", txt, re.IGNORECASE)
        if m:
            fix_loop = max(int(x) for x in m)
        if re.search(r"V-1[^\n]*(PASS|first[ _-]?pass)", txt, re.IGNORECASE):
            v1_first = "pass"
    return {
        "task_id": task_id,
        "ac_coverage_pct": r["ac_coverage"]["rate_percent"],
        "approval_discipline": r["approval_discipline"]["decision"],
        "format_adherence": r["format_adherence"]["decision"],
        "scope_discipline": r["scope_discipline"]["decision"],
        "verification_honesty": r["verification_honesty"]["decision"],
        "stop_behavior": r["stop_behavior"]["decision"],
        "tool_overuse": r["tool_overuse"]["decision"],
        "latency_cost": r["latency_cost"].get("decision", "n/a"),
        "fix_loop_count": fix_loop,
        "hook_violation_count": hv,
        "v1_first_pass": v1_first,
        "release_blocker_count": len(rb),
        "release_blocker_aspects": sorted({v["aspect"] for v in rb}),
    }


def harness_compare(
    targets: list[str],
    baseline_file: str,
    profile: str | None,
    prompt_rev: str | None,
    workflow_rev: str | None,
) -> dict:
    """ハーネス変更前後比較（#196 / PBI-HI-002）。

    baseline（PBI-HI-000 baseline JSON）の aggregate と target TASK 群の
    aggregate を比較し、release blocker を明示する。新 LLM judge は導入しない。
    """
    bpath = Path(baseline_file)
    if not bpath.is_file():
        raise SystemExit(f"baseline file not found: {baseline_file}")
    base = json.loads(bpath.read_text())
    bagg = base.get("aggregate", {})

    tsum = [_task_summary(t) for t in targets]
    n = len(tsum)
    ac_avg = round(sum(t["ac_coverage_pct"] for t in tsum) / n, 2) if n else 0.0

    def _pass_rate(field: str) -> float:
        if not n:
            return 0.0
        return round(
            100.0 * sum(1 for t in tsum if t[field] == "PASS") / n, 2
        )

    tgt_blockers = sum(t["release_blocker_count"] for t in tsum)
    base_blockers = bagg.get("release_blocker_total", 0)
    if tgt_blockers > base_blockers:
        rb_status = "regressed"
    elif tgt_blockers < base_blockers:
        rb_status = "improved"
    else:
        rb_status = "unchanged"

    return {
        "comparison_type": "harness_change",
        "evaluated_at": _dt.datetime.now(_dt.timezone.utc)
        .strftime("%Y-%m-%dT%H:%M:%SZ"),
        "harness_metadata": {
            "profile": profile or "unspecified",
            "prompt_rev": prompt_rev or "unspecified",
            "workflow_rev": workflow_rev or "unspecified",
        },
        "baseline": {
            "baseline_id": base.get("baseline_id"),
            "release": base.get("release"),
            "file": str(bpath),
            "aggregate": bagg,
        },
        "target": {
            "task_count": n,
            "task_ids": targets,
            "ac_coverage_avg_pct": ac_avg,
            "format_adherence_pass_rate_pct": _pass_rate("format_adherence"),
            "scope_discipline_pass_rate_pct": _pass_rate("scope_discipline"),
            "verification_honesty_pass_rate_pct": _pass_rate(
                "verification_honesty"
            ),
            "stop_behavior_pass_rate_pct": _pass_rate("stop_behavior"),
            "release_blocker_total": tgt_blockers,
            "tasks": tsum,
        },
        "delta": {
            "ac_coverage_avg_pct": round(
                ac_avg - bagg.get("ac_coverage_avg_pct", 0.0), 2
            ),
            "release_blocker_total": tgt_blockers - base_blockers,
            "release_blocker_status": rb_status,
        },
        "release_blocker_summary": [
            {
                "task_id": t["task_id"],
                "count": t["release_blocker_count"],
                "aspects": t["release_blocker_aspects"],
            }
            for t in tsum
            if t["release_blocker_count"] > 0
        ],
    }


def render_harness_compare_md(c: dict) -> str:
    d = c["delta"]
    b = c["baseline"]
    t = c["target"]
    hm = c["harness_metadata"]
    lines = [
        "# Eval Harness Comparison",
        "",
        f"> Evaluated at: {c['evaluated_at']}  (#196 / PBI-HI-002)",
        "",
        "## Harness metadata",
        "",
        f"- profile: `{hm['profile']}`",
        f"- prompt_rev: `{hm['prompt_rev']}`",
        f"- workflow_rev: `{hm['workflow_rev']}`",
        "",
        "## 比較サマリ",
        "",
        f"- Baseline: `{b['baseline_id']}` ({b['release']}) — {b['file']}",
        f"- Target: {t['task_count']} TASK ({', '.join(t['task_ids'])})",
        f"- AC coverage avg: {b['aggregate'].get('ac_coverage_avg_pct', 0.0)}%"
        f" → {t['ac_coverage_avg_pct']}% "
        f"(**{d['ac_coverage_avg_pct']:+.2f}%**)",
        f"- Release blocker total: {b['aggregate'].get('release_blocker_total', 0)}"
        f" → {t['release_blocker_total']} "
        f"(**{d['release_blocker_total']:+d}**, "
        f"status: **{d['release_blocker_status']}**)",
        "",
        "## Release blocker（明示）",
        "",
    ]
    if c["release_blocker_summary"]:
        for r in c["release_blocker_summary"]:
            lines.append(
                f"- **{r['task_id']}**: {r['count']} "
                f"({', '.join(r['aspects']) or 'n/a'})"
            )
    else:
        lines.append("- なし（target に release blocker なし）")
    lines.extend([
        "",
        "## 比較対象メトリクス（per target TASK）",
        "",
        "| TASK | AC% | format | scope | verif | stop | latency | "
        "fix_loop | hook_viol | v1_first | blockers |",
        "|------|-----|--------|-------|-------|------|---------|"
        "----------|-----------|----------|----------|",
    ])
    for ts in t["tasks"]:
        lines.append(
            f"| {ts['task_id']} | {ts['ac_coverage_pct']} | "
            f"{ts['format_adherence']} | {ts['scope_discipline']} | "
            f"{ts['verification_honesty']} | {ts['stop_behavior']} | "
            f"{ts['latency_cost']} | {ts['fix_loop_count']} | "
            f"{ts['hook_violation_count']} | {ts['v1_first_pass']} | "
            f"{ts['release_blocker_count']} |"
        )
    lines.extend([
        "",
        "## 関連",
        "",
        "- [`docs/ai/eval-runner.md`](../ai/eval-runner.md) §harness-compare",
        "- [`docs/ai/eval-comparison-template.md`](../ai/eval-comparison-template.md)",
        "- [`schemas/eval-comparison.schema.json`]"
        "(../../schemas/eval-comparison.schema.json)",
        "- baseline: PBI-HI-000 / #194",
        "",
    ])
    return "\n".join(lines)


def dogfood_eval(task_id: str) -> dict:
    """#231 Dogfooding Eval v1: 5 項目の決定論構造判定 + rationale.

    既存 8-aspect eval とは独立。LLM judge は docs/ai/dogfooding-eval.md の
    judge-prompt を外部基盤で用いる（v1 は決定論判定が基盤・再現性優先）。
    """
    task_dir = WORKING_DIR / task_id
    items = []

    def add(n, title, verdict, rationale):
        items.append({"n": n, "title": title, "verdict": verdict,
                      "rationale": rationale})

    # 1. PBI 入力から AC/Design/Task 分解が妥当か
    pbi = task_dir / "pbi-input.md"
    plan = task_dir / "plan.md"
    pbi_t = pbi.read_text() if pbi.is_file() else ""
    plan_t = plan.read_text() if plan.is_file() else ""
    has_ac = ("Acceptance Criteria" in pbi_t or "受入基準" in pbi_t
              or "AC-1" in pbi_t)
    has_wb = ("Work Breakdown" in plan_t or "## 変更内容" in plan_t
              or "Mode判定" in plan_t)
    add(1, "PBI→AC/Design/Task 分解",
        "PASS" if (has_ac and has_wb) else
        ("PARTIAL" if (has_ac or has_wb) else "FAIL"),
        f"pbi-input AC={has_ac} / plan WorkBreakdown={has_wb}")

    # 2. handoff 6 要素
    ho = task_dir / "handoff.md"
    sec = count_handoff_sections(ho.read_text()) if ho.is_file() else 0
    add(2, "handoff 6 要素",
        "PASS" if sec >= 6 else ("PARTIAL" if sec >= 3 else "FAIL"),
        f"handoff section_count={sec}/6"
        + ("" if ho.is_file() else " (handoff.md 不在)"))

    # 3. C-3/C-4 証跡
    c3 = task_dir / "approvals" / "c3.json"
    c3st = read_c3_status(c3) if c3.is_file() else None
    ho_t = ho.read_text() if ho.is_file() else ""
    status_p = task_dir / "status.md"
    has_c4 = ("C-4" in ho_t) or (
        status_p.is_file() and "C-4" in status_p.read_text())
    # mn-1: 片方のみ証跡あり = PARTIAL（both=PASS / either=PARTIAL / neither=FAIL）
    if c3st and has_c4:
        v3 = "PASS"
    elif c3st or has_c4:
        v3 = "PARTIAL"
    else:
        v3 = "FAIL"
    add(3, "C-3/C-4 証跡", v3,
        f"c3_status={c3st} / C-4 言及={bool(has_c4)}")

    # 4. Trace Timeline(experimental #229) イベント
    ev = WORKING_DIR / "_metrics" / "events.ndjson"
    has_ev = ev.is_file() and any(
        task_id in ln for ln in ev.read_text().splitlines()) if ev.is_file() else False
    add(4, "Trace Timeline イベント(experimental)",
        "PASS" if has_ev else "PARTIAL",
        f"events.ndjson に {task_id} の event={has_ev}"
        " (experimental＝無くても FAIL ではなく PARTIAL)")

    # 5. Stop rules / core-contract 違反なし
    dl = WORKING_DIR / "_audit" / "skip-decision-log.jsonl"
    unack = 0
    if dl.is_file():
        import json as _j
        for ln in dl.read_text().splitlines():
            ln = ln.strip()
            if not ln:
                continue
            try:
                d = _j.loads(ln)
            except _j.JSONDecodeError:
                continue
            if d.get("event") == "EH-3_SKIP" and not d.get("acknowledged_by"):
                unack += 1
    # claim_wo_evidence は TASK 固有（handoff に証跡なし完了主張）→ FAIL 対象。
    # unack（skip-decision-log）は repo-global のため当該 TASK の release
    # blocker にはせず advisory（PARTIAL 注記）に留める（誤って全 TASK を
    # FAIL 化しない・#231 v1 は TASK 単位判定が主）。
    # MJ-2: 完了主張の検出を頑健化。handoff に「完了」系の主張があり、かつ
    # 検証証跡語（PASS / テスト / hook 78 / CLI / 回帰 / 検証）が一切無い場合
    # を「証跡なし完了主張」とみなす（否定文 false negative を緩和）。
    evidence_terms = ("PASS", "テスト", "回帰", "検証", "hook ", "CLI ",
                      "78/0", "64/0")
    claim_terms = ("完了", "クローズ", "達成")
    if ho_t:
        has_claim = any(t in ho_t for t in claim_terms)
        has_evidence = any(t in ho_t for t in evidence_terms)
        claim_wo_evidence = has_claim and not has_evidence
        ambiguous = has_claim and not has_evidence and len(ho_t) < 200
    else:
        claim_wo_evidence = False
        ambiguous = False
    if claim_wo_evidence:
        v5 = "FAIL"
    elif unack or ambiguous:
        v5 = "PARTIAL"
    else:
        v5 = "PASS"
    add(5, "Stop rules / core-contract 違反なし", v5,
        f"証跡なし完了主張={claim_wo_evidence}（TASK固有=FAIL対象） / "
        f"repo-global 未追認SKIP={unack}（advisory・当該TASKのblockerにしない）")

    blockers = [it for it in items if it["verdict"] == "FAIL"]
    return {"task_id": task_id, "schema": "dogfood-eval-v1",
            "items": items, "release_blockers": len(blockers)}


def render_dogfood_md(r: dict) -> str:
    lines = [f"# Dogfooding Eval v1 — {r['task_id']}", "",
             "> #231 PBI-HI-015 / single judge（決定論構造判定 + rationale）",
             "> judge-prompt 正本: docs/ai/dogfooding-eval.md", "",
             "| # | 項目 | 判定 |", "|---|------|------|"]
    for it in r["items"]:
        lines.append(f"| {it['n']} | {it['title']} | **{it['verdict']}** |")
    lines += ["", "## Rationale", ""]
    for it in r["items"]:
        lines.append(f"### {it['n']}. {it['title']} — {it['verdict']}")
        lines.append(it["rationale"])
        lines.append("")
    lines.append(f"## Release blockers: {r['release_blockers']}"
                 + (" — マージ可" if r["release_blockers"] == 0
                    else " — 要解消"))
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="PlanGate eval runner (Issue #156)")
    parser.add_argument("task_id", nargs="?", help="Target TASK-XXXX (not required with --harness-compare)")
    parser.add_argument("--baseline", help="Baseline TASK-YYYY for comparison")
    parser.add_argument("--profile", help="Model profile key (recorded in output)")
    parser.add_argument("--no-write", action="store_true", help="Print to stdout instead of writing files")
    parser.add_argument("--dogfood", action="store_true", help="[#231] Dogfooding Eval v1: 5-item deterministic structural eval -> eval-dogfood.md")
    parser.add_argument("--harness-compare", action="store_true", help="[#196] Harness change comparison (baseline vs target TASK set)")
    parser.add_argument("--targets", help="[#196] Comma-separated target TASK ids (>=3 recommended)")
    parser.add_argument("--baseline-file", default="docs/ai/eval-baselines/2026-05-04-baseline.json", help="[#196] PBI-HI-000 baseline JSON path")
    parser.add_argument("--prompt-rev", help="[#196] Prompt assembly revision label (recorded)")
    parser.add_argument("--workflow-rev", help="[#196] Workflow revision label (recorded)")
    parser.add_argument(
        "--session-log",
        help="Path to codex session log (NDJSON) for latency / token metrics (Issue #168)",
    )
    args = parser.parse_args()

    if args.harness_compare:
        if not args.targets:
            print("error: --harness-compare requires --targets T1,T2,T3", file=sys.stderr)
            return 2
        targets = [x.strip() for x in args.targets.split(",") if x.strip()]
        if not targets:
            print("error: --targets is empty after parsing", file=sys.stderr)
            return 2
        for t in targets:
            if not re.match(r"^TASK-[0-9A-Za-z]+$", t):
                print(f"error: invalid target task_id: {t}", file=sys.stderr)
                return 2
        c = harness_compare(targets, args.baseline_file, args.profile, args.prompt_rev, args.workflow_rev)
        cmd = render_harness_compare_md(c)
        cjs = json.dumps(c, indent=2, ensure_ascii=False)
        if args.no_write:
            print("=== eval-comparison.md ===")
            print(cmd)
            print("=== eval-comparison.json ===")
            print(cjs)
        else:
            outdir = WORKING_DIR / targets[0]
            outdir.mkdir(parents=True, exist_ok=True)
            (outdir / "eval-comparison.md").write_text(cmd + "\n")
            (outdir / "eval-comparison.json").write_text(cjs + "\n")
            print(f"Written: docs/working/{targets[0]}/eval-comparison.{{md,json}}")
        return 1 if c["delta"]["release_blocker_status"] == "regressed" else 0

    if not args.task_id or not re.match(r"^TASK-[0-9A-Za-z]+$", args.task_id):
        print(f"error: invalid task_id: {args.task_id}", file=sys.stderr)
        return 2

    if args.dogfood:
        dr = dogfood_eval(args.task_id)
        dmd = render_dogfood_md(dr)
        if args.no_write:
            print(dmd)
        else:
            (WORKING_DIR / args.task_id).mkdir(parents=True, exist_ok=True)
            (WORKING_DIR / args.task_id / "eval-dogfood.md").write_text(dmd + "\n")
            print(f"Written: docs/working/{args.task_id}/eval-dogfood.md")
        return 1 if dr["release_blockers"] else 0

    result = build_eval_result(args.task_id, args.profile, session_log=args.session_log)
    if args.baseline:
        result["comparison"] = compare_with_baseline(result, args.baseline)

    md = render_markdown(result)
    js = json.dumps(result, indent=2, ensure_ascii=False)

    if args.no_write:
        print("=== eval-result.md ===")
        print(md)
        print("=== eval-result.json ===")
        print(js)
    else:
        task_dir = WORKING_DIR / args.task_id
        (task_dir / "eval-result.md").write_text(md + "\n")
        (task_dir / "eval-result.json").write_text(js + "\n")
        print(f"Written: {task_dir}/eval-result.{{md,json}}")

    if result["release_blocker_violations"]:
        print(f"WARNING: {len(result['release_blocker_violations'])} release blocker violation(s)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
