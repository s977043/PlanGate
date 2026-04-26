# RFC: Gemini CLI Provider Support

**Status**: Draft
**Created**: 2026-04-27
**Issue**: [#82](https://github.com/s977043/plangate/issues/82)

## Motivation

PlanGate's external review step (C-2 / V-3) currently uses Codex CLI as the default reviewer.
Gemini CLI provides an alternative LLM perspective that can catch blind spots Codex might miss.
Adding Gemini CLI as an optional provider would:

- Enable multi-model review for high-risk and critical workflows
- Reduce dependency on a single AI vendor for external review
- Give teams already using Google AI a natural integration point

## Proposed Configuration

In a project's `plangate.yaml` (or equivalent config):

```yaml
providers:
  external_reviewer:
    type: gemini-cli
    model: gemini-2.5-pro
    args: ["--yolo"]
```

The `plangate` harness would dispatch to `gemini` CLI using the same prompt template
currently sent to `codex review`.

## Implementation Plan

1. Abstract the external reviewer invocation in `bin/plangate` into a `call_external_reviewer` function.
2. Add a `PLANGATE_EXTERNAL_REVIEWER` environment variable (default: `codex`).
3. Add a `gemini` branch: invoke `gemini --yolo -p "<prompt>"` and capture stdout.
4. Validate that the output contains a structured review block before writing to `review-external.md`.
5. Update `workflows/high-risk.yaml` and `workflows/critical.yaml` to reference `provider: gemini-cli`.
6. Document the configuration in `README.md` under `## Provider Support`.

## Open Questions

- **Authentication**: Gemini CLI requires `GOOGLE_API_KEY` or `gcloud auth`. Harness should detect and warn if unset.
- **Model specification**: Which Gemini model versions should be pinned? Flash vs. Pro trade-offs for speed vs. quality.
- **Prompt compatibility**: Codex review uses a diff-based prompt. Gemini requires the full file context for best results — prompt template may need adjustment.
- **Rate limits**: Gemini CLI has different rate limits per tier; timeout handling in the harness may need tuning.
