#!/bin/sh
# release-prep.sh — リリース準備の機械化 + readiness 検査（v8.13.0 の準備漏れ実害から / 2026-06-11）
#
# v8.13.0 リリースで「CLAUDE.md apply 漏れ」「README 数値更新漏れ」が発生したため、
# 機械化できる準備と検査を 1 コマンドに集約する。tag push / Release 作成は本スクリプトの
# 範囲外（docs/release-process.md の Iron Law フローに従い、Human または明示承認済み AI）。
#
# 使い方:
#   sh scripts/release-prep.sh --check     # readiness 検査のみ（変更なし）
#   sh scripts/release-prep.sh vX.Y.Z      # 準備実行（CHANGELOG 確定 / version bump / 同期 + 検査）
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-}"

fail=0
note() { printf '%s\n' "$1"; }
ng() { printf 'NG: %s\n' "$1"; fail=1; }
ok() { printf 'OK: %s\n' "$1"; }

# version 宣言箇所の同値検査（#1257）。
# 旧実装はここで plugin.json と marketplace.json を直接読み比べていたが、
# **宣言箇所が増えたときに追随しない**（実際 `.codex-plugin/plugin.json` は
# 見ていなかった）。宣言箇所の正本は scripts/version_sites.py の DECLARED_SITES に
# 一本化し、本関数はそこへ委譲する。宣言テーブルと実 manifest 走査の同値照合も
# 同じコマンドが行うため、新しい manifest を足して宣言し忘れた場合も落ちる。
check_versions() {
  out="$(sh "$ROOT/scripts/check-version-bump.sh" --parity --root "$ROOT" 2>&1)" && rc=0 || rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "version 宣言箇所が全て同値 ($(printf '%s' "$out" | sed -n 's/.*VERSION_PARITY_OK //p'))"
  else
    ng "version 宣言箇所の不一致 or 宣言漏れ (rc=$rc): $(printf '%s' "$out" | tr '\n' ' ')"
  fi
}

# 最新 tag 以降に配布物差分があるのに version が据え置きなら NOT READY にする（#1257）。
# ゲートの位置は A-2'（2026-09-07 Human 決定）: PR CI ではなく**リリース時**に置く。
# rc=3 は「検査していない」であり成功ではないので NG にする（shallow clone 等）。
check_version_bump() {
  out="$(sh "$ROOT/scripts/check-version-bump.sh" --bump --since-latest-tag --root "$ROOT" 2>&1)" && rc=0 || rc=$?
  case "$rc" in
    0) ok "配布物 version bump 契約 ($(printf '%s' "$out" | grep -o 'VERSION_[A-Z_]*' | tail -1))" ;;
    3) ng "version bump 未検査 (rc=3 / 完全な履歴が要る): $(printf '%s' "$out" | tr '\n' ' ')" ;;
    *) ng "$(printf '%s' "$out" | grep 'VERSION_BUMP_MISSING\|VERSION_BUMP_DOWNGRADE\|VERSION_TAG_PAYLOAD_CONFLICT' | head -1)
     → 詳細: sh scripts/check-version-bump.sh --bump --since-latest-tag" ;;
  esac
}

# #1085: 2 マニフェスト（.claude-plugin / .codex-plugin）の整合。
# check_versions は .claude-plugin 側しか読まないため、Codex 用マニフェストだけ
# 古い状態でも「plugin version 一致」で緑になる（片側の事実だけ見て緑を出す構造）。
# ここを readiness 検査に配線し、release 経路でも AC-4 の機械検出を成立させる。
check_manifest_parity() {
  out="$(sh "$ROOT/scripts/check-plugin-manifest-parity.sh" 2>&1)" && rc=0 || rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "plugin マニフェスト整合（.claude-plugin / .codex-plugin）"
  else
    ng "plugin マニフェスト不整合 (rc=$rc): $(printf '%s' "$out" | tr '\n' ' ')"
  fi
}

check_pending_applies() {
  pending=""
  for f in "$ROOT"/scripts/apply-*.sh; do
    [ -f "$f" ] || continue
    out="$(sh "$f" --dry-run 2>/dev/null || true)"
    case "$out" in
      *"[dry-run]"*) pending="$pending $(basename "$f")" ;;
    esac
  done
  if [ -z "$pending" ]; then ok "適用待ち apply スクリプトなし"; else ng "適用待ち apply あり（Human 実行が必要）:$pending"; fi
}

check_changelog_sync() {
  if sh "$ROOT/scripts/sync-release-docs.sh" | grep -q "no-op"; then
    ok "docs/changelog.md 同期済み"
  else
    ng "docs/changelog.md が未同期だったため今同期した（コミットに含めること）"
  fi
}

check_plugin_cache_sync() {
  out="$(sh "$ROOT/scripts/sync-plugin-installed.sh" --dry-run 2>/dev/null || true)"
  if printf '%s' "$out" | grep -q "no-op"; then
    ok "plugin インストール済みキャッシュ同期済み（Claude Code + Codex）"
  else
    ng "plugin キャッシュ未同期 — 実行: sh scripts/sync-plugin-installed.sh"
  fi
}

run_checks() {
  note "=== release readiness 検査 ==="
  check_versions
  check_version_bump
  check_manifest_parity
  check_pending_applies
  check_changelog_sync
  check_plugin_cache_sync
  note "=== 手動確認 TODO（機械化対象外） ==="
  note "- README / README_en の最新リリース行（散文）が対象 version か"
  note "- CLAUDE.md の最新リリース節（HO — apply スクリプトで Human 適用）"
  note "- テスト実行: sh tests/run-tests.sh && sh tests/hooks/run-tests.sh"
  if [ "$fail" -eq 0 ]; then note "READY"; else note "NOT READY"; fi
  return "$fail"
}

case "$MODE" in
  --check)
    run_checks
    ;;
  v[0-9]*)
    V="${MODE#v}"
    DATE="$(date -u +%Y-%m-%d)"
    note "=== v$V 準備実行 ($DATE) ==="
    python3 - "$ROOT" "$V" "$DATE" <<'PY'
import json, re, sys
root, v, date = sys.argv[1], sys.argv[2], sys.argv[3]
p = f"{root}/CHANGELOG.md"
s = open(p, encoding="utf-8").read()
m = re.search(r"## Unreleased\n(.+?)\n## v", s, re.S)
assert m and m.group(1).strip(), "Unreleased が空（リリース対象なし）"
s = s.replace("## Unreleased\n", f"## Unreleased\n\n## v{v} - {date}\n", 1)
open(p, "w", encoding="utf-8").write(s)
print(f"OK CHANGELOG: v{v} セクション化（サマリ文は手動で追記）")
# .codex-plugin/plugin.json も同時に bump する（#1085）。片方だけ上がると
# scripts/check-plugin-manifest-parity.sh が version 乖離として FAIL する。
for f in [f"{root}/plugin/plangate/.claude-plugin/plugin.json",
          f"{root}/plugin/plangate/.codex-plugin/plugin.json",
          f"{root}/.claude-plugin/marketplace.json"]:
    s2 = open(f, encoding="utf-8").read()
    s3 = re.sub(r'"version":\s*"[0-9.]+"', f'"version": "{v}"', s2)
    open(f, "w", encoding="utf-8").write(s3)
    print(f"OK version bump: {f.split('/')[-1]}")
PY
    sh "$ROOT/scripts/sync-release-docs.sh" >/dev/null || true
    note "=== 続けて readiness 検査 ==="
    run_checks || true
    note "次: README 散文 / CLAUDE.md apply（Human）/ テスト → PR → merge → tag push → check-tag-main-parity.sh → gh release create"
    ;;
  *)
    note "usage: $0 [--check | vX.Y.Z]"; exit 1
    ;;
esac
