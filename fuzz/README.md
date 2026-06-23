# Fuzz Testing

PlanGate uses [atheris](https://github.com/google/atheris) for Python fuzzing.

## Targets

| File | Target | Description |
|------|--------|-------------|
| `fuzz_render_review.py` | `scripts/render_review.py` | HTML escaping / Markdown rendering |

## Running locally

```sh
pip install atheris
mkdir -p fuzz/corpus
python fuzz/fuzz_render_review.py fuzz/corpus/
```

## CI / OSS-Fuzz

The fuzz drivers follow the [atheris pattern](https://github.com/google/atheris)
and are compatible with OSS-Fuzz / CIFuzz integration.
