# tests/extras/ta-68-skill-spec-presence.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# #1109: scripts/check-codex-skill-spec.sh の「見ていないのに緑」を潰す回帰テスト。
#
# 背景: 旧実装は agents/openai.yaml が無い skill を silently skip していたため、
#   配布物 plugin/plangate/skills の欠落 4 件が「Checked 35 / PASS」に化けていた。
#   さらに冒頭コメントは「--warn-only 時は常に 0」と宣言していたが、target 不在では
#   FileNotFoundError の traceback とともに rc=1 になり契約違反だった。
#   TC-01: スクリプトの syntax
#   TC-02: 実リポジトリの既定 2 root が rc=0
#   TC-03: 負側 — SKILL.md はあるが openai.yaml が無い skill を violation にする
#   TC-04: 負側 — openai.yaml はあるが SKILL.md が無いディレクトリを violation にする
#   TC-05: --warn-only は violation があっても rc=0
#   TC-06: --warn-only は target 不在でも rc=0（契約）
#   TC-07: 非 --warn-only の target 不在は rc=1（fail-closed / 緑にしない）
#   TC-08: target 不在で python traceback を出さない
#   TC-09: 既定 target に配布物 plugin/plangate/skills を含む
#   TC-10: 検査対象外にしたエントリを理由つきで出力し、件数が同値である
#          （**絶対件数を契約値にしない** / R-002）
#   TC-11: 既存 field 検査（short_description 上限）が退行していない
#   TC-12: 配布物 root で SKILL.md 集合と openai.yaml 集合が一致する（同値照合）
#   ── V-3 REJECT 反映（R-001 / R-002 / R-003 / R-004）で追加 ──
#   TC-13: 既定経路（引数なし・explicit=False）が fixture repo で rc=0（正側）
#   TC-14: 負側 — 既定経路でも openai.yaml 欠落を検出する（変異 M-B を kill）
#   TC-15: 負側 — 宣言した既定 root の不在を violation にする（変異 M-A を kill）
#   TC-16: 既定出力に宣言 2 root が両方現れる（root 名で照合・件数は使わない）
#   TC-17: 同名 basename の 2 root でも violation 行が区別できる（R-004）

if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ] && [ -n "${EXTRAS_DIR:-}" ]; then
  _pg_extra_mode=harness
  _pg_extra_dir="$EXTRAS_DIR"
else
  _pg_extra_mode=standalone
  _pg_extra_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
fi
_pg_extra_helper="$_pg_extra_dir/_extra-contract.sh"
if [ ! -r "$_pg_extra_helper" ]; then
  printf '  [FAIL] helper unresolved: %s\n' "$_pg_extra_helper" >&2
  if [ "$_pg_extra_mode" = harness ]; then
    fail=$((fail + 1))
    return 0
  fi
  exit 1
fi
. "$_pg_extra_helper"
pg_extra_contract_init ta-68-skill-spec-presence standalone-capable

# ta-26 TC-33（静的検査 / README 規約 8）準拠
if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

printf '\n=== TA-68: skill spec presence check (#1109) ===\n'

t68_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t68_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

_T68_ROOT="$(CDPATH= cd -- "$_pg_extra_dir/../.." && pwd)"
_T68_SPEC="$_T68_ROOT/scripts/check-codex-skill-spec.sh"
_T68_DIST="$_T68_ROOT/plugin/plangate/skills"

if ! command -v python3 >/dev/null 2>&1; then
  pg_extra_contract_skip "python3 未導入のため TA-68 を skip"
fi

# === TC-01 syntax ===
if [ -f "$_T68_SPEC" ] && sh -n "$_T68_SPEC" 2>/dev/null; then
  t68_pass "TC-01 check-codex-skill-spec.sh の syntax OK"
else
  t68_fail "TC-01 不在 or syntax error: $_T68_SPEC"
fi

# === 共通 fixture（正常な skill 1 件を作る）===
_T68_TMP="$(mktemp -d)"
register_cleanup "$_T68_TMP"

_t68_make_skill() {
  # $1 = root / $2 = skill 名 / $3 = short_description
  mkdir -p "$1/$2/agents"
  printf -- '---\nname: %s\ndescription: fixture\n---\n\nbody\n' "$2" > "$1/$2/SKILL.md"
  {
    printf 'interface:\n'
    printf '  display_name: "%s"\n' "$2"
    printf '  short_description: "%s"\n' "$3"
    printf '  icon_small: "./assets/plangate-small.svg"\n'
    printf '  icon_large: "./assets/plangate-small.svg"\n'
    printf '  default_prompt: "Use $%s to assist with this project."\n' "$2"
    printf '  brand_color: "#1A56DB"\n'
  } > "$1/$2/agents/openai.yaml"
}

# === TC-02 実リポジトリの既定 2 root が rc=0 ===
_t68_rc2=0
_t68_out2=$(sh "$_T68_SPEC" 2>&1) || _t68_rc2=$?
if [ "$_t68_rc2" -eq 0 ]; then
  t68_pass "TC-02 既定 2 root が rc=0"
else
  t68_fail "TC-02 既定 target で violation (rc=$_t68_rc2): $(printf '%s' "$_t68_out2" | tr '\n' ';')"
fi

# === TC-03 負側: openai.yaml 欠落を violation にする（silent skip の再発検出）===
_T68_MISS="$_T68_TMP/missing-yaml"
_t68_make_skill "$_T68_MISS" ok-skill "A perfectly valid fixture skill description"
mkdir -p "$_T68_MISS/no-yaml-skill"
printf -- '---\nname: no-yaml-skill\n---\n' > "$_T68_MISS/no-yaml-skill/SKILL.md"
_t68_rc3=0
_t68_out3=$(sh "$_T68_SPEC" --target "$_T68_MISS" 2>&1) || _t68_rc3=$?
if [ "$_t68_rc3" -eq 1 ] && printf '%s' "$_t68_out3" | grep -q 'no-yaml-skill: agents/openai.yaml missing'; then
  t68_pass "TC-03 負側: openai.yaml 欠落を rc=1 + 名指しで検出"
else
  t68_fail "TC-03 欠落を検出できず (rc=$_t68_rc3, 期待 1): $(printf '%s' "$_t68_out3" | tr '\n' ';')"
fi

# === TC-04 負側: SKILL.md の無い openai.yaml（orphan）も violation ===
_T68_ORPHAN="$_T68_TMP/orphan-yaml"
_t68_make_skill "$_T68_ORPHAN" ok-skill "A perfectly valid fixture skill description"
_t68_make_skill "$_T68_ORPHAN" orphan-skill "A perfectly valid fixture skill description"
rm -f "$_T68_ORPHAN/orphan-skill/SKILL.md"
_t68_rc4=0
_t68_out4=$(sh "$_T68_SPEC" --target "$_T68_ORPHAN" 2>&1) || _t68_rc4=$?
if [ "$_t68_rc4" -eq 1 ] && printf '%s' "$_t68_out4" | grep -q 'orphan-skill: agents/openai.yaml exists but SKILL.md missing'; then
  t68_pass "TC-04 負側: orphan openai.yaml を rc=1 で検出"
else
  t68_fail "TC-04 orphan を検出できず (rc=$_t68_rc4, 期待 1): $(printf '%s' "$_t68_out4" | tr '\n' ';')"
fi

# === TC-05 --warn-only は violation があっても rc=0 ===
_t68_rc5=0
sh "$_T68_SPEC" --warn-only --target "$_T68_MISS" >/dev/null 2>&1 || _t68_rc5=$?
if [ "$_t68_rc5" -eq 0 ]; then
  t68_pass "TC-05 --warn-only は violation ありでも rc=0"
else
  t68_fail "TC-05 --warn-only が violation ありで非 0 (rc=$_t68_rc5, 期待 0)"
fi

# === TC-06 --warn-only は target 不在でも rc=0（契約）===
_T68_ABSENT="$_T68_TMP/never-created"
_t68_rc6=0
_t68_out6=$(sh "$_T68_SPEC" --warn-only --target "$_T68_ABSENT" 2>&1) || _t68_rc6=$?
if [ "$_t68_rc6" -eq 0 ]; then
  t68_pass "TC-06 --warn-only は target 不在でも rc=0"
else
  t68_fail "TC-06 target 不在で非 0 (rc=$_t68_rc6, 期待 0): $(printf '%s' "$_t68_out6" | tr '\n' ';')"
fi

# === TC-07 非 --warn-only の target 不在は rc=1（fail-closed）===
_t68_rc7=0
_t68_out7=$(sh "$_T68_SPEC" --target "$_T68_ABSENT" 2>&1) || _t68_rc7=$?
if [ "$_t68_rc7" -eq 1 ] && printf '%s' "$_t68_out7" | grep -q 'target directory not found'; then
  t68_pass "TC-07 target 不在は rc=1（緑にしない）"
else
  t68_fail "TC-07 target 不在の扱いが不正 (rc=$_t68_rc7, 期待 1): $(printf '%s' "$_t68_out7" | tr '\n' ';')"
fi

# === TC-08 target 不在で traceback を出さない ===
if printf '%s' "$_t68_out7" | grep -q 'Traceback'; then
  t68_fail "TC-08 target 不在で python traceback が出ている"
else
  t68_pass "TC-08 target 不在で traceback を出さない"
fi

# === TC-09 既定 target に配布物 plugin/plangate/skills を含む ===
if printf '%s' "$_t68_out2" | grep -q 'plugin/plangate/skills'; then
  t68_pass "TC-09 既定 target に配布物 plugin/plangate/skills を含む"
else
  t68_fail "TC-09 配布物が既定 target に入っていない: $(printf '%s' "$_t68_out2" | tr '\n' ';')"
fi

# === TC-10 検査対象外エントリを件数と理由つきで出力する ===
# **絶対件数（ignored=1）を契約値にしない**（#1109 R-002）。skills root に
# 非ディレクトリが 1 枚増えただけの無関係 PR を落とさないため、
#   (a) reason 付きの ignored 行が出ること
#   (b) summary の ignored=<N> と ignored: 行の実数が **同値** であること
# の 2 点だけを見る。
_t68_ign_sum=$(printf '%s\n' "$_t68_out2" | awk 'match($0, /ignored=[0-9]+/) { s += substr($0, RSTART + 8, RLENGTH - 8) } END { print s + 0 }')
_t68_ign_rows=$(printf '%s\n' "$_t68_out2" | awk '/ignored: .* — reason: / { n++ } END { print n + 0 }')
if printf '%s' "$_t68_out2" | grep -q 'ignored: README.md — reason:' \
  && [ -n "$_t68_ign_sum" ] && [ "$_t68_ign_sum" = "$_t68_ign_rows" ]; then
  t68_pass "TC-10 skip を理由つきで出力し件数が同値 (summary=$_t68_ign_sum rows=$_t68_ign_rows)"
else
  t68_fail "TC-10 skip の理由出力 or 件数同値が崩れている (summary=$_t68_ign_sum rows=$_t68_ign_rows): $(printf '%s' "$_t68_out2" | tr '\n' ';')"
fi

# === TC-11 既存 field 検査（short_description 上限）が退行していない ===
_T68_LONG="$_T68_TMP/long-desc"
_t68_make_skill "$_T68_LONG" long-skill "$(printf 'x%.0s' $(seq 1 70))"
_t68_rc11=0
_t68_out11=$(sh "$_T68_SPEC" --target "$_T68_LONG" 2>&1) || _t68_rc11=$?
if [ "$_t68_rc11" -eq 1 ] && printf '%s' "$_t68_out11" | grep -q 'short_description too long'; then
  t68_pass "TC-11 short_description 上限検査が退行していない"
else
  t68_fail "TC-11 field 検査が退行 (rc=$_t68_rc11, 期待 1): $(printf '%s' "$_t68_out11" | tr '\n' ';')"
fi

# === TC-12 配布物 root の SKILL.md 集合 == openai.yaml 集合（同値照合）===
# 絶対件数を契約値にしない（skill は運用で増える）。集合差が空であることだけを見る。
_t68_diff=$(python3 - "$_T68_DIST" << 'PYEOF'
import os, sys
root = sys.argv[1]
skills, yamls = set(), set()
if os.path.isdir(root):
    for name in os.listdir(root):
        d = os.path.join(root, name)
        if name.startswith('.') or not os.path.isdir(d):
            continue
        if os.path.isfile(os.path.join(d, 'SKILL.md')):
            skills.add(name)
        if os.path.isfile(os.path.join(d, 'agents', 'openai.yaml')):
            yamls.add(name)
print(','.join(sorted(skills ^ yamls)))
PYEOF
)
if [ -z "$_t68_diff" ]; then
  t68_pass "TC-12 配布物 root の SKILL.md 集合と openai.yaml 集合が一致"
else
  t68_fail "TC-12 配布物 root で集合が不一致: $_t68_diff"
fi

# ── 既定経路（explicit=False）の検出力 / #1109 R-001 R-003 ───────────────────
# CI が実際に通るのは `--target` 無しの既定経路だが、TC-03/04/07/11 はすべて
# `--target` 経由（explicit=True）であり、既定経路の検出ロジックだけを壊す変異が
# 生き残っていた（レビューア変異 M-A / M-B が 12/12 PASS で生存）。
#
# テスト専用 env などの新しい seam は増やさない。スクリプトは `REPO_ROOT` を
# **自分の置かれた場所**（`dirname $0/..`）から求めるため、fixture repo へ
# スクリプトを複製するだけで既定経路をそのまま実行できる。
_t68_make_fixture_repo() {
  # $1 = fixture repo のパス。`scripts/` と既定 2 root を持つ最小 repo を作る
  _fr="$1"
  mkdir -p "$_fr/scripts"
  cp "$_T68_SPEC" "$_fr/scripts/check-codex-skill-spec.sh"
  mkdir -p "$_fr/.codex/skills" "$_fr/plugin/plangate/skills"
  _t68_make_skill "$_fr/.codex/skills" alpha-skill "A perfectly valid fixture skill description"
  _t68_make_skill "$_fr/plugin/plangate/skills" alpha-skill "A perfectly valid fixture skill description"
}

# === TC-13 正側: 既定経路（引数なし）が fixture repo で rc=0 ===
_T68_FR_OK="$_T68_TMP/repo-ok"
_t68_make_fixture_repo "$_T68_FR_OK"
_t68_rc13=0
_t68_out13=$(sh "$_T68_FR_OK/scripts/check-codex-skill-spec.sh" 2>&1) || _t68_rc13=$?
if [ "$_t68_rc13" -eq 0 ] && printf '%s' "$_t68_out13" | grep -q 'across 2 target(s)'; then
  t68_pass "TC-13 既定経路が fixture repo の 2 root を検査して rc=0"
else
  t68_fail "TC-13 既定経路の正側が壊れている (rc=$_t68_rc13): $(printf '%s' "$_t68_out13" | tr '\n' ';')"
fi

# === TC-14 負側: 既定経路で openai.yaml 欠落を検出する（M-B 相当を kill）===
_T68_FR_MISS="$_T68_TMP/repo-missing"
_t68_make_fixture_repo "$_T68_FR_MISS"
mkdir -p "$_T68_FR_MISS/plugin/plangate/skills/beta-skill"
printf -- '---\nname: beta-skill\n---\n' > "$_T68_FR_MISS/plugin/plangate/skills/beta-skill/SKILL.md"
_t68_rc14=0
_t68_out14=$(sh "$_T68_FR_MISS/scripts/check-codex-skill-spec.sh" 2>&1) || _t68_rc14=$?
if [ "$_t68_rc14" -eq 1 ] && printf '%s' "$_t68_out14" | grep -q 'beta-skill: agents/openai.yaml missing'; then
  t68_pass "TC-14 負側: 既定経路でも openai.yaml 欠落を rc=1 で検出"
else
  t68_fail "TC-14 既定経路の presence 検査が効いていない (rc=$_t68_rc14, 期待 1): $(printf '%s' "$_t68_out14" | tr '\n' ';')"
fi

# === TC-15 負側: 宣言した既定 root の不在は violation（M-A 相当を kill）===
# #1086 で `.codex/skills` を untrack しても「検査母数が黙って半減する」ことを許さない。
# root を減らすときは DEFAULT_TARGETS の宣言を編集する＝意識的なコード変更を強制する。
_T68_FR_ABSENT="$_T68_TMP/repo-absent-root"
_t68_make_fixture_repo "$_T68_FR_ABSENT"
rm -rf "$_T68_FR_ABSENT/.codex"
_t68_rc15=0
_t68_out15=$(sh "$_T68_FR_ABSENT/scripts/check-codex-skill-spec.sh" 2>&1) || _t68_rc15=$?
if [ "$_t68_rc15" -eq 1 ] \
  && printf '%s' "$_t68_out15" | grep -q 'target directory not found (declared default target)' \
  && printf '%s' "$_t68_out15" | grep -q '\.codex/skills'; then
  t68_pass "TC-15 負側: 宣言した既定 root の不在を rc=1 + root 名で検出"
else
  t68_fail "TC-15 既定 root 消失が緑のまま通る (rc=$_t68_rc15, 期待 1): $(printf '%s' "$_t68_out15" | tr '\n' ';')"
fi

# === TC-16 既定出力に宣言 2 root が **両方** 現れる（root 名で照合・件数は使わない）===
if printf '%s' "$_t68_out2" | grep -q '\.codex/skills:' \
  && printf '%s' "$_t68_out2" | grep -q 'plugin/plangate/skills:'; then
  t68_pass "TC-16 既定出力に .codex/skills と plugin/plangate/skills が両方現れる"
else
  t68_fail "TC-16 既定 root のいずれかが出力に現れない: $(printf '%s' "$_t68_out2" | tr '\n' ';')"
fi

# === TC-17 violation 行が root を区別できる（basename 衝突の解消 / R-004）===
_T68_DUP="$_T68_TMP/dup"
mkdir -p "$_T68_DUP/a/skills/foo" "$_T68_DUP/b/skills/foo"
printf -- '---\nname: foo\n---\n' > "$_T68_DUP/a/skills/foo/SKILL.md"
printf -- '---\nname: foo\n---\n' > "$_T68_DUP/b/skills/foo/SKILL.md"
_t68_rc17=0
_t68_out17=$(sh "$_T68_SPEC" --target "$_T68_DUP/a/skills" --target "$_T68_DUP/b/skills" 2>&1) || _t68_rc17=$?
_t68_uniq=$(printf '%s\n' "$_t68_out17" | awk '/agents\/openai.yaml missing/ { print }' | sort -u | awk 'END { print NR + 0 }')
if [ "$_t68_rc17" -eq 1 ] && [ "$_t68_uniq" -eq 2 ]; then
  t68_pass "TC-17 同名 basename の 2 root でも violation 行が区別できる"
else
  t68_fail "TC-17 violation 行が root を区別できない (rc=$_t68_rc17, uniq=$_t68_uniq, 期待 2): $(printf '%s' "$_t68_out17" | tr '\n' ';')"
fi

rm -rf "$_T68_TMP"

pg_extra_contract_finalize
