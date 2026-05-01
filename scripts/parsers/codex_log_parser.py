"""codex_log_parser.py — Codex CLI JSONL session log の解析

PlanGate Issue #168 / TASK-0054 — eval runner の latency / tokens 自動取得。

入力: ~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl 等の NDJSON
出力: dict（latency_seconds / completion_tokens / reasoning_tokens / 補助指標）

抽出ルール:
- latency_seconds: 全 event_msg/task_complete の duration_ms 合計 / 1000（複数ターン対応）
- time_to_first_token_seconds: 同 task_complete の time_to_first_token_ms 平均 / 1000
- completion_tokens / reasoning_tokens / input_tokens: 最後の event_msg/token_count(info あり) の total_token_usage
- turn_count: event_msg/task_complete の出現回数
- tool_call_count: 現状 0（v2 で response_item を解析）

ログ形式が壊れている / 想定外イベントが混じる場合は best-effort で値を埋め、
取得不可フィールドは None。
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def parse(log_path: Path | str) -> dict[str, Any]:
    log_path = Path(log_path)
    if not log_path.is_file():
        raise FileNotFoundError(f"codex log not found: {log_path}")

    duration_ms_total = 0
    ttft_values: list[int] = []
    turn_count = 0
    last_token_info: dict | None = None

    with log_path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue

            payload = rec.get("payload") or {}
            ptype = payload.get("type")

            if rec.get("type") == "event_msg" and ptype == "task_complete":
                duration_ms_total += int(payload.get("duration_ms") or 0)
                ttft = payload.get("time_to_first_token_ms")
                if ttft is not None:
                    ttft_values.append(int(ttft))
                turn_count += 1

            if rec.get("type") == "event_msg" and ptype == "token_count":
                info = payload.get("info")
                if info:
                    last_token_info = info

    usage = (last_token_info or {}).get("total_token_usage") or {}

    avg_ttft = (sum(ttft_values) / len(ttft_values) / 1000.0) if ttft_values else None

    return {
        "source": "codex",
        "log_path": str(log_path),
        "latency_seconds": duration_ms_total / 1000.0 if duration_ms_total > 0 else None,
        "time_to_first_token_seconds": avg_ttft,
        "turn_count": turn_count,
        "input_tokens": usage.get("input_tokens"),
        "cached_input_tokens": usage.get("cached_input_tokens"),
        "output_tokens": usage.get("output_tokens"),
        "completion_tokens": usage.get("output_tokens"),  # alias
        "reasoning_tokens": usage.get("reasoning_output_tokens"),
        "total_tokens": usage.get("total_tokens"),
        "model_context_window": (last_token_info or {}).get("model_context_window"),
        "tool_call_count": None,  # v2: response_item を解析して埋める
    }


if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        print("Usage: python3 codex_log_parser.py <path-to-jsonl>", file=sys.stderr)
        sys.exit(2)
    result = parse(sys.argv[1])
    print(json.dumps(result, indent=2, default=str))
