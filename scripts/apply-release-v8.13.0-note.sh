#!/bin/sh
# apply-release-v8.13.0-note.sh — CLAUDE.md の最新リリース節を v8.13.0 へ（Human 実行）
set -eu
MODE="${1:---dry-run}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
F="$ROOT/CLAUDE.md"
OLD_H='## v8.12.0 並列レビューア実行・Plugin sync 品質ガード（最新リリース機能）'
NEW_H='## v8.13.0 全体健全化・エージェント model tier（最新リリース機能）'
OLD_N='> 最新リリース: **v8.12.0**（2026-06-07）並列レビューア実行・Plugin sync 品質ガード・導入促進（Why PlanGate）/運用ガード整備。v8.11.0 で Claude Code / Codex Plugin 正式配布、v8.10.0 で Codex CLI parity 完成・Hook/Guard 拡充・Skill 整備。'
NEW_N='> 最新リリース: **v8.13.0**（2026-06-11）全体監査駆動の健全化（docs 鮮度・テスト隔離・スリム化）+ エージェント model tier（docs/ai/model-profiles.md §11）+ Hook enforcement 実態整合 + doc-light モード。v8.12.0 で並列レビューア実行・Plugin sync 品質ガード、v8.11.0 で Plugin 正式配布、v8.10.0 で Codex CLI parity 完成。'

if grep -qF -- "$NEW_H" "$F"; then echo "OK (already)"; exit 0; fi
grep -qF -- "$OLD_H" "$F" || { echo "ERROR: アンカー不在（見出し）" >&2; exit 1; }
grep -qF -- "$OLD_N" "$F" || { echo "ERROR: アンカー不在（注記）" >&2; exit 1; }
if [ "$MODE" = "--dry-run" ]; then
  echo "[dry-run] CLAUDE.md: 見出しと最新リリース注記を v8.13.0 に更新"
elif [ "$MODE" = "--apply" ]; then
  python3 - "$F" "$OLD_H" "$NEW_H" "$OLD_N" "$NEW_N" <<'PY'
import sys
f = sys.argv[1]
with open(f, encoding="utf-8") as fp: s = fp.read()
for old, new in [(sys.argv[2], sys.argv[3]), (sys.argv[4], sys.argv[5])]:
    assert s.count(old) == 1
    s = s.replace(old, new)
with open(f, "w", encoding="utf-8") as fp: fp.write(s)
PY
  echo "APPLIED: CLAUDE.md"
else
  echo "usage: $0 [--dry-run|--apply]"; exit 1
fi
