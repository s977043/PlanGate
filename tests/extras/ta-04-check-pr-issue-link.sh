# tests/extras/ta-04-check-pr-issue-link.sh
# Sourced by tests/run-tests.sh — relies on $pass / $fail / $PLANGATE_BIN / $FIXTURES_DIR
# Issue #170 で run-tests.sh から分離
#
# 判定は fixture の expected.txt の **全文一致**（#159 敵対レビュー major-2/3）。
# 旧実装は `case "$out" in "$expected"*)` の prefix 4 文字（PASS/WARN/SKIP）しか
# 見ておらず、以下の変異が実測で生存していた:
#   - 出力分岐削除（`PASS: non-closing link(s)  found` で issue 番号が消える）
#   - expected_issue 不一致を WARN→PASS
#   - expected_issue 抽出ブロックごと削除
#   - non-closing の区切り `[[:space:]:]+` → `*`（`refs#1` が WARN→PASS）
#   - PASS メッセージ文言の改変
# expected.txt はそれまで harness から読まれていない飾りだったので、それを
# 全文期待値の正本に格上げする。
#
# fixture の任意ディレクトリ `sandbox/` があれば mktemp へ複製し、そこを cwd に
# してスクリプトを起動する。`--changed-files` の child PBI YAML 解決は
# `[ -f "$yaml" ]`（cwd 相対）で行われるため、本番の docs/working/ に依存せず
# expected_issue 経路を検証できる（origin/main には related_issue を持つ子 PBI
# YAML が 0 件）。

printf '\n=== TA-04: check-pr-issue-link.sh ===\n'

# repo root は FIXTURES_DIR から解決する（`$0` は source 元の runner を指すため、
# 別ディレクトリの harness から source されると壊れる / ta-59 と同じ流儀）。
PR_LINK_SCRIPT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)/scripts/check-pr-issue-link.sh"
PR_LINK_FIXTURES="$FIXTURES_DIR/check-pr-issue-link"

run_pr_link_fixture() {
  fixture_dir=$1
  label=$2
  if [ ! -f "$fixture_dir/expected.txt" ]; then
    printf '[FAIL] %s — fixture has no expected.txt: %s\n' "$label" "$fixture_dir"
    fail=$((fail + 1))
    return 0
  fi
  ta04_expected=$(cat "$fixture_dir/expected.txt")
  ta04_sbx=""
  ta04_cwd="$PWD"
  if [ -d "$fixture_dir/sandbox" ]; then
    ta04_sbx=$(mktemp -d)
    register_cleanup "$ta04_sbx"
    cp -R "$fixture_dir/sandbox/." "$ta04_sbx/"
    ta04_cwd="$ta04_sbx"
  fi
  out=$(cd "$ta04_cwd" && sh "$PR_LINK_SCRIPT" \
    --body-file "$fixture_dir/body.txt" \
    --labels-file "$fixture_dir/labels.txt" \
    --changed-files "$fixture_dir/changed-files.txt" 2>&1) || {
    printf '[FAIL] %s — script exited non-zero: %s\n' "$label" "$out"
    fail=$((fail + 1))
    if [ -n "$ta04_sbx" ]; then
      rm -rf "$ta04_sbx"
    fi
    return 0
  }
  # set -e 安全（README 規約 4）: `[ ... ] && rm` の AND-list は条件が偽のとき
  # 関数の戻り値を 1 にし、set -eu のハーネスを途中終了させる。if で書く。
  if [ -n "$ta04_sbx" ]; then
    rm -rf "$ta04_sbx"
  fi
  if [ "$out" = "$ta04_expected" ]; then
    printf '[PASS] %s\n' "$label"
    pass=$((pass + 1))
  else
    printf '[FAIL] %s\n  expected: %s\n  got     : %s\n' "$label" "$ta04_expected" "$out"
    fail=$((fail + 1))
  fi
}

run_pr_link_fixture "$PR_LINK_FIXTURES/pass" "pass: closes #N present"
run_pr_link_fixture "$PR_LINK_FIXTURES/warn" "warn: no closing keyword"
run_pr_link_fixture "$PR_LINK_FIXTURES/skip-label" "skip-label: documentation label"
run_pr_link_fixture "$PR_LINK_FIXTURES/skip-marker" "skip-marker: HTML comment marker"
run_pr_link_fixture "$PR_LINK_FIXTURES/pass-refs" "pass-refs: non-closing link 'Refs: #N' accepted"
run_pr_link_fixture "$PR_LINK_FIXTURES/pass-part-of" "pass-part-of: non-closing link 'Part of #N' accepted"
run_pr_link_fixture "$PR_LINK_FIXTURES/warn-bare-hash" "warn-bare-hash: bare #N without keyword stays WARN"
# --- #159 敵対レビュー是正で追加した TC ---
run_pr_link_fixture "$PR_LINK_FIXTURES/pass-expected-issue" \
  "pass-expected-issue: child PBI YAML の related_issue と一致 → PASS（番号まで全文一致）"
run_pr_link_fixture "$PR_LINK_FIXTURES/warn-expected-issue-mismatch" \
  "warn-expected-issue-mismatch: related_issue と不一致 → WARN"
run_pr_link_fixture "$PR_LINK_FIXTURES/warn-refs-no-separator" \
  "warn-refs-no-separator: 区切り無しの 'refs#1' は linkage 宣言でない → WARN"
run_pr_link_fixture "$PR_LINK_FIXTURES/warn-closing-word-boundary" \
  "warn-closing-word-boundary: hotfix/prefix/suffixes の語末一致で PASS しない → WARN"
