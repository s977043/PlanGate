# RFC: OpenCode Provider Support

**Status**: Draft
**Created**: 2026-04-27
**Issue**: [#82](https://github.com/s977043/plangate/issues/82)

## Motivation

OpenCode is an open-source, terminal-native AI coding agent that supports multiple LLM backends
(OpenAI, Anthropic, local models via Ollama).
Adding OpenCode as a PlanGate provider would:

- Enable fully local / air-gapped workflows using Ollama models
- Support teams that prefer open-source tooling over proprietary CLIs
- Allow the implementation agent role to be filled by a non-Anthropic model

## Proposed Configuration

In a project's `plangate.yaml` (or equivalent config):

```yaml
providers:
  implementation_agent:
    type: opencode
    model: anthropic/claude-sonnet-4-5
```

Or for a local model:

```yaml
providers:
  implementation_agent:
    type: opencode
    model: ollama/qwen2.5-coder
```

## Implementation Plan

1. Define a `provider` field in `workflows/*.yaml` for `wf04_build_and_refine` agents.
2. Add an `opencode` dispatch path in the harness: invoke `opencode run "<prompt>"` and capture run.ndjson events.
3. Map OpenCode session events to PlanGate's `run-event.schema.json` format (session_started, task_completed, etc.).
4. Verify that gate enforcement (plan_hash_check, c3.json existence) runs before handing off to OpenCode.
5. Test with `ollama/qwen2.5-coder` for a `light` mode task to validate the event mapping.
6. Document the configuration in `README.md` under `## Provider Support`.

## Open Questions

- **Session isolation**: OpenCode manages its own session state. How does it interact with PlanGate's `docs/working/TASK-XXXX/` structure?
- **run.ndjson compatibility**: OpenCode may emit events in a different format. Does the harness normalize them, or does OpenCode need a PlanGate plugin?
- **Approval files**: Can OpenCode read and respect `approvals/c3.json` gate enforcement, or must the harness intercept before handing off?
- **Local model quality**: Smaller local models may not produce plan.md / handoff.md artifacts that pass `plangate validate`. Minimum model size guidance needed.
