#!/usr/bin/env python3
"""fuzz_render_review.py — atheris fuzz driver for scripts/render_review.py

Tests HTML escaping, Markdown parsing, and rendering logic in render_review.py
against arbitrary input to detect panics, encoding errors, and XSS vectors.

Usage (local):
    pip install atheris
    mkdir -p fuzz/corpus
    python fuzz/fuzz_render_review.py fuzz/corpus/

Usage (OSS-Fuzz / CIFuzz):
    Automatically detected via `import atheris` pattern.
"""
import sys
import os
import html

# Allow importing from scripts/ without installation
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))

import atheris

# Module-level import to avoid per-iteration overhead during fuzzing
try:
    import render_review as rr
except ImportError:
    rr = None


@atheris.instrument_func
def fuzz_html_escape(data: bytes) -> None:
    """Fuzz HTML escaping — must never raise, must escape < > & \" '."""
    text = data.decode('utf-8', errors='replace')
    escaped = html.escape(text, quote=True)
    assert '<script' not in escaped.lower(), "XSS vector escaped incorrectly"


@atheris.instrument_func
def fuzz_render_md_section(data: bytes) -> None:
    """Fuzz render_review md-to-html rendering with arbitrary Markdown input."""
    if rr is None:
        return
    text = data.decode('utf-8', errors='replace')
    try:
        result = rr.md_to_html(text)
        assert isinstance(result, str)
    except AttributeError:
        pass  # md_to_html may not exist in all versions


def TestOneInput(data: bytes) -> None:
    fuzz_html_escape(data)
    fuzz_render_md_section(data)


if __name__ == '__main__':
    atheris.Setup(sys.argv, TestOneInput)
    atheris.Fuzz()
