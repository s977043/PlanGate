# tests/extras/ta-82-sync-allowlist-pin.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
#
# #1263 R3: `scripts/sync-plugin-plangate.sh` の **ガバナンス 3 面（agents / rules /
# commands）の同期が no-op 化していないこと**を、サンドボックス実行による挙動 TC で
# 実測し、allowlist / 呼び出し行の字面ピンをその補助として置く。
#
# 背景（#1263 / 2026-09-06 の実測コメント）:
#   ガバナンス正本 30 件（`.claude/{rules,commands,agents}`）は Hardening Override
#   （HO）で守られているが、**導入先へ配布されるのは非 HO の `plugin/plangate/` 側**
#   である。既存の drift-check（`.github/workflows/sync-plugin-plangate.yml` が
#   `sh scripts/sync-plugin-plangate.sh` を走らせて `git diff` を見る形）は
#   「片側編集」「正本のみ編集」「agents の model 行改変」を FAIL 化できるが、
#   **同期スクリプトの allowlist を縮める改変は素通りする**:
#
#     for _dir in agents rules commands; do   →   for _dir in agents rules; do
#
#   この改変後も `plugin/plangate/commands/` の既存ファイルはそのまま残るため
#   `git diff` は空になり、drift-check は緑のままになる。以降 `.claude/commands/*.md`
#   （C-3 承認手順を含む）を編集しても配布側へ反映されず、しかも誰も気付かない。
#   本ファイルはその 1 点（#1263 受入基準 2 = AC-2）を塞ぐ。
#
# AC-2「同期スクリプト自体の改変が検出対象に含まれるか、含めない理由が明記される」に
# 対する本ファイルの立場（**射程の明示 / 実態どおりに書く**）:
#
#   - **主検査 = 挙動（TC-11〜TC-14）**: mktemp 配下のミニ repo（`scripts/` +
#     `.claude/{agents,rules,commands}` + `plugin/plangate/`）へ候補スクリプトを
#     置いて **実際に走らせ**、「正本にのみ在る新規ファイル（md / json）が
#     3 面とも配布側に現れる」「配布側にだけ在るファイルが削除される」ことを
#     実測する。**字面が 1 バイトも変わらない no-op 化**（`sync_dir` の再定義 /
#     ラベル分岐での早期 return / `PLUGIN_DIR` の付け替え）はここで落ちる。
#     #1263 R3 の本質は「同期が静かに no-op 化しても drift-check が緑のまま」で
#     あり、allowlist を縮める改変（L15）はその**最も狭い 1 事例**にすぎない。
#
#   - **補助検査 = 字面ピン（TC-01〜TC-05）**: `for _dir in ...` の allowlist と
#     ループ本体の `sync_dir` 呼び出し行を静的に見る。**構造解析ではなく
#     パターン照合**であり、次の誤爆／見逃しの性質を持つ（TC-16 が対照）:
#       * 誤爆しない: allowlist の**拡張**（`... commands output-styles`）/
#         `_gov_dirs="..."` への**変数化**（同ファイル内の単純代入なら解決する）/
#         呼び出し行の**インデント変更**と末尾 `|| exit N` の付加
#       * **誤爆する（既知・意図的）**: ループ変数そのもののリネーム
#         （`for _other in ...`）。TC-05 が「同期ループの消失」として固定して
#         いるため、この 1 クラスは字面ピンを維持する。挙動 TC 側は無関係に通る
#         ので、正当なリネームをしたい場合は TC-05 を同時に更新すること。
#       * **静的に読めない**: コマンド置換等で allowlist を動的生成する形は
#         `T82_LOOP_DYNAMIC` / `T82_LOOP_UNRESOLVED` として保守側（FAIL）に倒す。
#
#   - **含めない**: スクリプト全体の byte 固定。同スクリプトは skills / ai-loop /
#     ho-paths 等の同期も担い恒常的に成長するため、byte 固定は無関係な PR を落とす
#     時限爆弾になる（`tests/extras/README.md` P-6「絶対件数の契約値にしない」と同趣旨）。
#     ガバナンス 3 面**以外**の同期経路（skills / ai-loop / ho-paths / marketplace
#     version）は本ファイルの射程外で、`ta-26-plugin-sync.sh` の挙動 TC 群と
#     CI drift-check が受け持つ。
#
#   - **本ファイルでは塞げないもの**（#1263 の残り 2 点 = Human-owned）:
#     (1) **`.github/workflows/sync-plugin-plangate.yml` の drift-check job** が
#         `on.push.paths` / `on.pull_request.paths` の絞り込みで起動しない経路
#         （`tests/fixtures/sync-paths-known-gap-1249.flag` / patch は Human 適用待ち）。
#         **本ファイル自身の TC はこの穴の影響を受けない** — ta-82 は
#         `tests/run-tests.sh` 経由で `.github/workflows/test.yml` の
#         `on: pull_request`（**`paths:` 指定なし** / 2026-09-07 実測）で走るため、
#         どのパスを触る PR でも必ず実行される。影響を受けるのは
#         「sync 実行後の `git diff` を見る drift-check job」だけである。
#     (2) drift-check が required status check に未登録（ruleset 操作 = Human-owned）
#     いずれも `.github/workflows/**` / ruleset = HO・Human-owned のため本 TC は触れない。
#
#   - **同値照合（TC-06）の射程**: `sync_dir` のコピー／削除ループと同じ拡張子集合
#     （`*.md` / `*.yaml` / `*.yml` / `*.json`）を **双方向**で見る。src→dst は
#     配布漏れ・内容差分、dst→src は「正本に無いのに配布側に残る幽霊」（削除ループ /
#     mass-delete guard が壊れるクラス）。`README.md` だけは `sync_dir` が
#     stale 集計・削除ループの双方から除外するため、配布側単独の存在を許容する。
#
# 検出力の実証（README「PASS 判定の書き方」P-7）: TC-03 / TC-04 / TC-07 / TC-08 /
# TC-12 / TC-13 / TC-14 / TC-15 はサンドボックス複製へ変異を注入し、**変異が実際に
# 入ったこと**（`grep -c` / `cmp` / 存在確認）を先に確認してから、検査器が確かに
# FAIL することを実測する。変異は関数本体ではなく **call site / 分岐 / 配布先** を
# 壊す形を選ぶ。TC-09 / TC-16 は逆方向の対照（正当な model 正規化差分・挙動を
# 変えないリファクタを誤検出しない）を置く。
#
# 判定の書き方: 検査器は rc と **T82_ 接頭辞の一意 reason トークン**の対を返す
# （P-1 / P-3）。分岐ごとに固有トークンを持たせ、選言だけの述語は使わない（P-2）。
# 母数は floor で見る（P-6）— `.claude/{rules,commands,agents}` は今後も増えるため
# 絶対件数を契約値にしない。
#
# 隔離（README「隔離・後始末の規約」3 / 9）: 実 repo の tracked パスは読むだけで、
# 書き込みは `mktemp -d` 配下のみ。trap は張らない（規約 1・2）。挙動 TC は
# **サンドボックスへ複製したスクリプト**を、`REPO_ROOT` がサンドボックスへ解決される
# 位置（`<sbx>/scripts/`）から起動する。`sync-plugin-plangate.sh` は `REPO_ROOT` を
# `dirname $0/..` で導出するため、実 repo の `.claude/` / `plugin/` には一切触れない
# （後始末は `register_cleanup` + 終端の `rm -rf`）。

# ---- extras execution contract bootstrap (#921) ----------------------------
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
pg_extra_contract_init ta-82-sync-allowlist-pin standalone-capable

if pg_extra_contract_is_standalone; then
  # standalone: 外部 env 汚染を無害化（tests/extras/README.md「隔離・後始末の規約」8 /
  # ta-26 TC-33 が静的検査する集合と一致させる）
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

printf '\n=== TA-82: sync-plugin allowlist static pin (#1263 R3) ===\n'

_T82_ROOT="$(CDPATH= cd -- "$_pg_extra_dir/../.." && pwd)"
_T82_SCRIPT="$_T82_ROOT/scripts/sync-plugin-plangate.sh"
_T82_CLAUDE="$_T82_ROOT/.claude"
_T82_PLUGIN="$_T82_ROOT/plugin/plangate"
# ガバナンス 3 面（#1263 の実測表と同じ集合）。ここは「下限」であり、同期対象が
# 増えること自体は妨げない（TC-01 は包含で判定する）。
_T82_REQUIRED_DIRS='agents rules commands'
# sync_dir が同期対象にする拡張子（scripts/sync-plugin-plangate.sh の
# コピー / stale / 削除ループの glob と同一集合）。`*.md` だけを見ると
# yaml/yml/json の乖離が構造的な穴になる（#1263 R3 A-4）。
_T82_SYNC_EXTS='md yaml yml json'
# ループ本体の呼び出し行（**空白を正規化した**正典形。行頭インデントと
# 末尾の `|| exit N` は誤爆させない / #1263 R3 A-2）
_T82_CALLSITE='sync_dir "$CLAUDE_DIR/$_dir" "$PLUGIN_DIR/$_dir" "$_dir"'

t82_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t82_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

if [ ! -f "$_T82_SCRIPT" ] || [ ! -d "$_T82_CLAUDE" ] || [ ! -d "$_T82_PLUGIN" ]; then
  pg_extra_contract_skip "prerequisite absent: scripts/sync-plugin-plangate.sh / .claude / plugin/plangate"
  return 0 2>/dev/null || exit 3
fi

_T82_TMP="$(mktemp -d "${TMPDIR:-/tmp}/pg-ta82.XXXXXX")"
register_cleanup "$_T82_TMP"

# ── 検査器 1: 同期対象 allowlist ────────────────────────────────────
# $1 = 検査対象スクリプト。stdout に一意 reason トークン、rc 0 = 充足。
_t82_loop_check() {
  _t82_lc_f="$1"
  _t82_lc_n=$(grep -c 'for _dir in [^;]*; do' "$_t82_lc_f" 2>/dev/null || true)
  [ -n "$_t82_lc_n" ] || _t82_lc_n=0
  if [ "$_t82_lc_n" != "1" ]; then
    printf 'T82_LOOP_COUNT:%s\n' "$_t82_lc_n"
    return 1
  fi
  _t82_lc_rhs=$(sed -n 's/.*for _dir in \([^;]*\); do.*/\1/p' "$_t82_lc_f")
  # 誤爆を減らす（#1263 R3 A-2）: allowlist の **拡張**（`output-styles` の
  # ようなハイフン・数字入り）と、`_gov_dirs="..."` への **変数化** を落とさない。
  case "$_t82_lc_rhs" in
    *'$('* | *'`'*)
      # 動的生成は静的には解決できない。**保守側に倒して FAIL**（挙動 TC が
      # 主検査なので、ここは「静的には読めない」ことを可視化する役）。
      printf 'T82_LOOP_DYNAMIC:%s\n' "$_t82_lc_rhs"
      return 1
      ;;
    '$'*)
      _t82_lc_var="${_t82_lc_rhs#\$}"
      _t82_lc_var="${_t82_lc_var#\{}"
      _t82_lc_var="${_t82_lc_var%\}}"
      case "$_t82_lc_var" in
        '' | *[!A-Za-z0-9_]*)
          printf 'T82_LOOP_UNRESOLVED:%s\n' "$_t82_lc_rhs"
          return 1
          ;;
      esac
      # 同ファイル内の単純代入（`VAR="a b c"` / `VAR='a b c'` / `VAR=a`）から解決する。
      _t82_lc_toks=$(sed -n \
        "s/^[[:space:]]*${_t82_lc_var}=\"\([A-Za-z0-9_. -]*\)\"[[:space:]]*\$/\1/p; \
         s/^[[:space:]]*${_t82_lc_var}='\([A-Za-z0-9_. -]*\)'[[:space:]]*\$/\1/p; \
         s/^[[:space:]]*${_t82_lc_var}=\([A-Za-z0-9_.-]*\)[[:space:]]*\$/\1/p" \
        "$_t82_lc_f" | tail -n 1)
      if [ -z "$_t82_lc_toks" ]; then
        printf 'T82_LOOP_UNRESOLVED:%s\n' "$_t82_lc_rhs"
        return 1
      fi
      ;;
    *)
      _t82_lc_toks="$_t82_lc_rhs"
      ;;
  esac
  for _t82_lc_req in $_T82_REQUIRED_DIRS; do
    _t82_lc_hit=0
    for _t82_lc_t in $_t82_lc_toks; do
      if [ "$_t82_lc_t" = "$_t82_lc_req" ]; then
        _t82_lc_hit=1
      fi
    done
    if [ "$_t82_lc_hit" = "0" ]; then
      printf 'T82_DIR_MISSING:%s\n' "$_t82_lc_req"
      return 1
    fi
  done
  printf 'T82_LOOP_OK:%s\n' "$_t82_lc_toks"
  return 0
}

# ── 検査器 2: ループ本体の呼び出し行（allowlist を保ったまま無効化する経路）──
_t82_callsite_check() {
  _t82_cs_f="$1"
  # ループ本体の最初の「空行でもコメントでもない行」を取る（整形差分で誤爆しない）
  _t82_cs_next=$(awk '
    /for _dir in [^;]*; do/ { found = 1; next }
    found && $0 !~ /^[[:space:]]*$/ && $0 !~ /^[[:space:]]*#/ { print; exit }
  ' "$_t82_cs_f")
  if [ -z "$_t82_cs_next" ]; then
    printf 'T82_CALLSITE_ABSENT\n'
    return 1
  fi
  # 前後空白を落とし、末尾の `|| exit N` / `|| return N`（エラー伝播の強化）を
  # 許容してから正典形と比較する（#1263 R3 A-2）。
  _t82_cs_norm=$(printf '%s\n' "$_t82_cs_next" | sed -E \
    -e 's/^[[:space:]]+//' -e 's/[[:space:]]+$//' \
    -e 's/[[:space:]]*\|\|[[:space:]]*(exit|return)([[:space:]]+[0-9]+)?[[:space:]]*$//')
  if [ "$_t82_cs_norm" != "$_T82_CALLSITE" ]; then
    printf 'T82_CALLSITE_CHANGED:%s\n' "$_t82_cs_next"
    return 1
  fi
  printf 'T82_CALLSITE_OK\n'
  return 0
}

# ── 検査器 3: 正本 ↔ 配布ミラーの同値照合（byte 一致 / agents は model 正規化）──
# $1 = 正本ルート（.claude 相当）/ $2 = 配布ルート（plugin/plangate 相当）
# 絶対件数は書かない。母数は floor（`-ge`）で見る（P-6）。
_t82_parity_check() {
  _t82_pc_src_root="$1"
  _t82_pc_dst_root="$2"
  _t82_pc_total=0
  _t82_pc_viol=''
  for _t82_pc_d in $_T82_REQUIRED_DIRS; do
    _t82_pc_n=0
    # --- 方向 1: src → dst（配布漏れ / 内容差分）------------------------
    for _t82_pc_e in $_T82_SYNC_EXTS; do
      for _t82_pc_f in "$_t82_pc_src_root/$_t82_pc_d"/*."$_t82_pc_e"; do
        [ -f "$_t82_pc_f" ] || continue
        _t82_pc_n=$((_t82_pc_n + 1))
        _t82_pc_total=$((_t82_pc_total + 1))
        _t82_pc_b="$(basename "$_t82_pc_f")"
        _t82_pc_dst="$_t82_pc_dst_root/$_t82_pc_d/$_t82_pc_b"
        if [ ! -f "$_t82_pc_dst" ]; then
          _t82_pc_viol="$_t82_pc_viol $_t82_pc_d/$_t82_pc_b(missing)"
          continue
        fi
        if [ "$_t82_pc_d" = "agents" ] && [ "$_t82_pc_e" = "md" ]; then
          # 配布時の model frontmatter 正規化（sync-plugin-plangate.sh の
          # _normalize_model と同一規則。md のみが対象）を適用して byte 比較する。
          sed '1,/^---$/{s/^model: .*/model: inherit/;}' "$_t82_pc_f" > "$_T82_TMP/norm.md"
          cmp -s "$_T82_TMP/norm.md" "$_t82_pc_dst" \
            || _t82_pc_viol="$_t82_pc_viol $_t82_pc_d/$_t82_pc_b(diff)"
        else
          cmp -s "$_t82_pc_f" "$_t82_pc_dst" \
            || _t82_pc_viol="$_t82_pc_viol $_t82_pc_d/$_t82_pc_b(diff)"
        fi
      done
    done
    # --- 方向 2: dst → src（幽霊配布物）--------------------------------
    # src 側だけを走査すると「正本に無いのに配布側に残っているファイル」を
    # 検出できない（#1263 R3 A-3）。sync_dir の削除ループ / mass-delete guard が
    # 壊れるクラスが恒久的に素通りするため、逆方向も 1 周する。
    # README.md は sync_dir が stale 集計・削除ループの双方から除外するため、
    # 配布側に単独で存在してよい（同スクリプトのセマンティクスに合わせる）。
    for _t82_pc_e in $_T82_SYNC_EXTS; do
      for _t82_pc_g in "$_t82_pc_dst_root/$_t82_pc_d"/*."$_t82_pc_e"; do
        [ -f "$_t82_pc_g" ] || continue
        _t82_pc_b="$(basename "$_t82_pc_g")"
        [ "$_t82_pc_b" = "README.md" ] && continue
        if [ ! -f "$_t82_pc_src_root/$_t82_pc_d/$_t82_pc_b" ]; then
          _t82_pc_viol="$_t82_pc_viol $_t82_pc_d/$_t82_pc_b(ghost)"
        fi
      done
    done
    if [ "$_t82_pc_n" -lt 1 ]; then
      _t82_pc_viol="$_t82_pc_viol $_t82_pc_d(empty)"
    fi
  done
  if [ "$_t82_pc_total" -lt 3 ]; then
    printf 'T82_PARITY_FLOOR:%s\n' "$_t82_pc_total"
    return 1
  fi
  if [ -n "$_t82_pc_viol" ]; then
    printf 'T82_PARITY_DIFF:%s\n' "$_t82_pc_viol"
    return 1
  fi
  printf 'T82_PARITY_OK:%s\n' "$_t82_pc_total"
  return 0
}

# ── 検査器 4: 挙動（サンドボックスで同期スクリプトを実際に走らせる）──────
# #1263 R3 の本質は「同期が静かに no-op 化しても drift-check が緑のまま」で
# あり、字面ピン（検査器 1・2）はその**最も狭い 1 事例**しか見ていない。
# 本検査器は候補スクリプトを mktemp 配下のミニ repo（`scripts/` + `.claude/` +
# `plugin/plangate/`）へ置いて**実行**し、
#   (a) 正本にのみ在る新規ファイルがガバナンス 3 面とも配布側に現れるか
#       （md だけでなく json も置く = sync_dir の非 md 経路も通す）
#   (b) agents の model 正規化が効いているか
#   (c) 配布側にだけ在るファイル（幽霊）が削除されるか
# を実測する。関数の再定義・分岐の早期 return・PLUGIN_DIR の付け替えなど
# **字面が変わらない no-op 化**はここで落ちる。
# $1 = 検査対象スクリプト / $2 = サンドボックス識別子（TC ごとに一意）
_t82_behavior_check() {
  _t82_bc_script="$1"
  _t82_bc_root="$_T82_TMP/bx-$2"
  rm -rf "$_t82_bc_root"
  mkdir -p "$_t82_bc_root/scripts" || { printf 'T82_BEHAVIOR_SETUP\n'; return 1; }
  cp "$_t82_bc_script" "$_t82_bc_root/scripts/sync-plugin-plangate.sh" \
    || { printf 'T82_BEHAVIOR_SETUP\n'; return 1; }
  for _t82_bc_d in $_T82_REQUIRED_DIRS; do
    mkdir -p "$_t82_bc_root/.claude/$_t82_bc_d" "$_t82_bc_root/plugin/plangate/$_t82_bc_d"
    if [ "$_t82_bc_d" = "agents" ]; then
      printf -- '---\nname: ta82-probe\nmodel: opus\n---\nprobe %s\n' \
        "$_t82_bc_d" > "$_t82_bc_root/.claude/$_t82_bc_d/ta82-probe.md"
    else
      printf -- '# ta82 probe %s\n' "$_t82_bc_d" > "$_t82_bc_root/.claude/$_t82_bc_d/ta82-probe.md"
    fi
    printf '{"ta82":"%s"}\n' "$_t82_bc_d" > "$_t82_bc_root/.claude/$_t82_bc_d/ta82-probe.json"
    # 配布側にだけ置く「幽霊」。src 残存 2 件 > stale 1 件なので #861
    # mass-delete guard は発火せず、削除ループの健全性だけを見られる。
    printf 'ghost\n' > "$_t82_bc_root/plugin/plangate/$_t82_bc_d/ta82-ghost.md"
  done
  _t82_bc_rc=0
  ( cd "$_t82_bc_root" && sh "$_t82_bc_root/scripts/sync-plugin-plangate.sh" ) \
    > "$_t82_bc_root/run.log" 2>&1 || _t82_bc_rc=$?
  if [ "$_t82_bc_rc" != "0" ]; then
    printf 'T82_BEHAVIOR_RC:%s\n' "$_t82_bc_rc"
    return 1
  fi
  _t82_bc_viol=''
  for _t82_bc_d in $_T82_REQUIRED_DIRS; do
    _t82_bc_dstd="$_t82_bc_root/plugin/plangate/$_t82_bc_d"
    for _t82_bc_b in ta82-probe.md ta82-probe.json; do
      _t82_bc_src="$_t82_bc_root/.claude/$_t82_bc_d/$_t82_bc_b"
      if [ ! -f "$_t82_bc_dstd/$_t82_bc_b" ]; then
        _t82_bc_viol="$_t82_bc_viol $_t82_bc_d/$_t82_bc_b(undelivered)"
        continue
      fi
      if [ "$_t82_bc_d" = "agents" ] && [ "$_t82_bc_b" = "ta82-probe.md" ]; then
        sed '1,/^---$/{s/^model: .*/model: inherit/;}' "$_t82_bc_src" > "$_t82_bc_root/norm.md"
        cmp -s "$_t82_bc_root/norm.md" "$_t82_bc_dstd/$_t82_bc_b" \
          || _t82_bc_viol="$_t82_bc_viol $_t82_bc_d/$_t82_bc_b(content)"
      else
        cmp -s "$_t82_bc_src" "$_t82_bc_dstd/$_t82_bc_b" \
          || _t82_bc_viol="$_t82_bc_viol $_t82_bc_d/$_t82_bc_b(content)"
      fi
    done
    if [ -f "$_t82_bc_dstd/ta82-ghost.md" ]; then
      _t82_bc_viol="$_t82_bc_viol $_t82_bc_d/ta82-ghost.md(ghost-kept)"
    fi
  done
  if [ -n "$_t82_bc_viol" ]; then
    printf 'T82_BEHAVIOR_VIOL:%s\n' "$_t82_bc_viol"
    return 1
  fi
  printf 'T82_BEHAVIOR_OK\n'
  return 0
}

# ── TC-01: 実スクリプトの allowlist がガバナンス 3 面を包含する ───────
_t82_rc=0
_t82_out=$(_t82_loop_check "$_T82_SCRIPT") || _t82_rc=$?
if [ "$_t82_rc" = "0" ] && printf '%s' "$_t82_out" | grep -q '^T82_LOOP_OK:'; then
  t82_pass "TC-01 sync-plugin-plangate.sh の同期ループが agents/rules/commands を包含 ($_t82_out)"
else
  t82_fail "TC-01 同期 allowlist がガバナンス 3 面を包含しない (rc=$_t82_rc / $_t82_out)"
fi

# ── TC-02: ループ本体が両側パスを loop 変数から導出して sync_dir を呼ぶ ──
_t82_rc=0
_t82_out=$(_t82_callsite_check "$_T82_SCRIPT") || _t82_rc=$?
if [ "$_t82_rc" = "0" ] && [ "$_t82_out" = "T82_CALLSITE_OK" ]; then
  t82_pass "TC-02 ループ本体の sync_dir 呼び出し行が正典形と一致"
else
  t82_fail "TC-02 sync_dir 呼び出し行が変化している (rc=$_t82_rc / $_t82_out)"
fi

# ── TC-03: 変異注入 M1（allowlist から commands を落とす）→ TC-01 が FAIL ──
_t82_m1="$_T82_TMP/m1.sh"
sed 's/^for _dir in agents rules commands; do$/for _dir in agents rules; do/' "$_T82_SCRIPT" > "$_t82_m1"
_t82_m1_applied=$(grep -c '^for _dir in agents rules; do$' "$_t82_m1" 2>/dev/null || true)
_t82_rc=0
_t82_out=$(_t82_loop_check "$_t82_m1") || _t82_rc=$?
if [ "$_t82_m1_applied" != "1" ]; then
  t82_fail "TC-03 変異 M1 が空振りした（複製へ適用されていない: hits=${_t82_m1_applied}）"
elif [ "$_t82_rc" != "0" ] && [ "$_t82_out" = "T82_DIR_MISSING:commands" ]; then
  t82_pass "TC-03 変異 M1（commands を allowlist から除去）で TC-01 検査器が FAIL (rc=$_t82_rc / $_t82_out)"
else
  t82_fail "TC-03 変異 M1 を入れたのに検査器が通った＝TC-01 は空振り (rc=$_t82_rc / $_t82_out)"
fi

# ── TC-04: 変異注入 M2（sync_dir 呼び出しを無効化）→ TC-02 が FAIL ────
_t82_m2="$_T82_TMP/m2.sh"
sed 's|^  sync_dir "\$CLAUDE_DIR/\$_dir" "\$PLUGIN_DIR/\$_dir" "\$_dir"$|  : # disabled|' "$_T82_SCRIPT" > "$_t82_m2"
_t82_m2_applied=$(grep -c '^  : # disabled$' "$_t82_m2" 2>/dev/null || true)
_t82_rc=0
_t82_out=$(_t82_callsite_check "$_t82_m2") || _t82_rc=$?
if [ "$_t82_m2_applied" != "1" ]; then
  t82_fail "TC-04 変異 M2 が空振りした（複製へ適用されていない: hits=${_t82_m2_applied}）"
elif [ "$_t82_rc" != "0" ] && printf '%s' "$_t82_out" | grep -q '^T82_CALLSITE_CHANGED:'; then
  t82_pass "TC-04 変異 M2（sync_dir 呼び出しの無効化）で TC-02 検査器が FAIL (rc=$_t82_rc / $_t82_out)"
else
  t82_fail "TC-04 変異 M2 を入れたのに検査器が通った＝TC-02 は空振り (rc=$_t82_rc / $_t82_out)"
fi

# ── TC-05: 変異注入 M3（ループごと削除）→ allowlist 検査器が FAIL ────
_t82_m3="$_T82_TMP/m3.sh"
sed 's/^for _dir in agents rules commands; do$/for _other in agents rules commands; do/' "$_T82_SCRIPT" > "$_t82_m3"
_t82_m3_applied=$(grep -c '^for _other in agents rules commands; do$' "$_t82_m3" 2>/dev/null || true)
_t82_rc=0
_t82_out=$(_t82_loop_check "$_t82_m3") || _t82_rc=$?
if [ "$_t82_m3_applied" != "1" ]; then
  t82_fail "TC-05 変異 M3 が空振りした（複製へ適用されていない: hits=${_t82_m3_applied}）"
elif [ "$_t82_rc" != "0" ] && [ "$_t82_out" = "T82_LOOP_COUNT:0" ]; then
  t82_pass "TC-05 変異 M3（同期ループの消失）で検査器が FAIL (rc=$_t82_rc / $_t82_out)"
else
  t82_fail "TC-05 変異 M3 を入れたのに検査器が通った (rc=$_t82_rc / $_t82_out)"
fi

# ── TC-06: 実 repo の正本 ↔ 配布ミラーが同値（agents は model 正規化許容）──
_t82_rc=0
_t82_out=$(_t82_parity_check "$_T82_CLAUDE" "$_T82_PLUGIN") || _t82_rc=$?
if [ "$_t82_rc" = "0" ] && printf '%s' "$_t82_out" | grep -q '^T82_PARITY_OK:'; then
  t82_pass "TC-06 .claude/{agents,rules,commands}/*.md と plugin ミラーが同値 ($_t82_out)"
else
  t82_fail "TC-06 正本と配布ミラーが乖離 (rc=$_t82_rc / $_t82_out)"
fi

# ── サンドボックス複製（TC-07〜TC-09 の変異注入用）────────────────
_t82_sbx="$_T82_TMP/sbx"
mkdir -p "$_t82_sbx/src" "$_t82_sbx/dst"
for _t82_d in $_T82_REQUIRED_DIRS; do
  mkdir -p "$_t82_sbx/src/$_t82_d" "$_t82_sbx/dst/$_t82_d"
  cp "$_T82_CLAUDE/$_t82_d"/*.md "$_t82_sbx/src/$_t82_d/" 2>/dev/null || true
  cp "$_T82_PLUGIN/$_t82_d"/*.md "$_t82_sbx/dst/$_t82_d/" 2>/dev/null || true
done
# 複製自体が同値であることを先に確認する（以降の変異が「効いた」と言うための基準）
_t82_rc=0
_t82_base_out=$(_t82_parity_check "$_t82_sbx/src" "$_t82_sbx/dst") || _t82_rc=$?
if [ "$_t82_rc" != "0" ]; then
  t82_fail "TC-07..09 前提: サンドボックス複製が同値でない (rc=$_t82_rc / $_t82_base_out)"
fi

# ── TC-07: 1 バイト変異（rules 側ミラー）→ 同値照合が FAIL ─────────
_t82_victim="$_t82_sbx/dst/rules/mode-classification.md"
if [ -f "$_t82_victim" ]; then
  cp "$_t82_victim" "$_T82_TMP/rules-orig.md"
  printf 'X' >> "$_t82_victim"
  _t82_mut_ok=0
  cmp -s "$_T82_TMP/rules-orig.md" "$_t82_victim" || _t82_mut_ok=1
  _t82_rc=0
  _t82_out=$(_t82_parity_check "$_t82_sbx/src" "$_t82_sbx/dst") || _t82_rc=$?
  if [ "$_t82_mut_ok" != "1" ]; then
    t82_fail "TC-07 変異が空振り（1 バイト追記が反映されていない）"
  elif [ "$_t82_rc" != "0" ] && printf '%s' "$_t82_out" | grep -q 'rules/mode-classification.md(diff)'; then
    t82_pass "TC-07 配布ミラーの 1 バイト変異を同値照合が検出 (rc=$_t82_rc / $_t82_out)"
  else
    t82_fail "TC-07 1 バイト変異を入れたのに同値照合が通った＝TC-06 は空振り (rc=$_t82_rc / $_t82_out)"
  fi
  cp "$_T82_TMP/rules-orig.md" "$_t82_victim"
else
  t82_fail "TC-07 前提: サンドボックスに rules/mode-classification.md が無い"
fi

# ── TC-08: agents 本文の 1 バイト変異 → model 正規化の許容が本文差分を素通りしない ──
_t82_victim="$_t82_sbx/dst/agents/qa-reviewer.md"
if [ -f "$_t82_victim" ]; then
  cp "$_t82_victim" "$_T82_TMP/agents-orig.md"
  printf 'X' >> "$_t82_victim"
  _t82_mut_ok=0
  cmp -s "$_T82_TMP/agents-orig.md" "$_t82_victim" || _t82_mut_ok=1
  _t82_rc=0
  _t82_out=$(_t82_parity_check "$_t82_sbx/src" "$_t82_sbx/dst") || _t82_rc=$?
  if [ "$_t82_mut_ok" != "1" ]; then
    t82_fail "TC-08 変異が空振り（1 バイト追記が反映されていない）"
  elif [ "$_t82_rc" != "0" ] && printf '%s' "$_t82_out" | grep -q 'agents/qa-reviewer.md(diff)'; then
    t82_pass "TC-08 agents 本文の 1 バイト変異を検出（model 正規化の許容が広すぎない） (rc=$_t82_rc / $_t82_out)"
  else
    t82_fail "TC-08 agents 本文の 1 バイト変異を素通りした (rc=$_t82_rc / $_t82_out)"
  fi
  cp "$_T82_TMP/agents-orig.md" "$_t82_victim"
else
  t82_fail "TC-08 前提: サンドボックスに agents/qa-reviewer.md が無い"
fi

# ── TC-09: 対照 — 正当な model frontmatter 差分は誤検出しない（#1263 受入基準 4）──
# 正本側 agents の model: 行を別 tier へ書き換えても、配布側は inherit のままで
# 同値と判定されること（実 repo の「差異のある 6 件」がこの形）。
_t82_srcv="$_t82_sbx/src/agents/qa-reviewer.md"
if [ -f "$_t82_srcv" ]; then
  cp "$_t82_srcv" "$_T82_TMP/agents-src-orig.md"
  sed '1,/^---$/{s/^model: .*/model: opus/;}' "$_T82_TMP/agents-src-orig.md" > "$_t82_srcv"
  _t82_mut_ok=0
  cmp -s "$_T82_TMP/agents-src-orig.md" "$_t82_srcv" || _t82_mut_ok=1
  _t82_rc=0
  _t82_out=$(_t82_parity_check "$_t82_sbx/src" "$_t82_sbx/dst") || _t82_rc=$?
  if [ "$_t82_mut_ok" != "1" ]; then
    printf '  [SKIP] TC-09: 対象 agents に model frontmatter 行が無く対照を作れない\n'
  elif [ "$_t82_rc" = "0" ] && printf '%s' "$_t82_out" | grep -q '^T82_PARITY_OK:'; then
    t82_pass "TC-09 正当な model 正規化差分は誤検出しない (rc=$_t82_rc / $_t82_out)"
  else
    t82_fail "TC-09 model 行の tier 差分を誤検出した (rc=$_t82_rc / $_t82_out)"
  fi
  cp "$_T82_TMP/agents-src-orig.md" "$_t82_srcv"
else
  t82_fail "TC-09 前提: サンドボックスに src/agents/qa-reviewer.md が無い"
fi

# ── TC-11: 挙動 — 実スクリプトが 3 面を実際に配布する ────────────────
_t82_rc=0
_t82_out=$(_t82_behavior_check "$_T82_SCRIPT" base) || _t82_rc=$?
if [ "$_t82_rc" = "0" ] && [ "$_t82_out" = "T82_BEHAVIOR_OK" ]; then
  t82_pass "TC-11 サンドボックス実行で agents/rules/commands の新規ファイル（md/json）が 3 面とも配布され、幽霊は削除される"
else
  t82_fail "TC-11 実スクリプトの同期挙動が期待どおりでない (rc=$_t82_rc / $_t82_out)"
fi

# ── TC-12: 変異 B1（ループ直前で sync_dir を no-op に再定義）→ 挙動 TC が FAIL ──
# 字面（allowlist / callsite）は 1 バイトも変わらないため TC-01 / TC-02 は
# 素通りする。call site ではなく **呼ばれる関数の実体**を壊す変異。
_t82_b1="$_T82_TMP/b1.sh"
awk '/for _dir in [^;]*; do/ && !_x { print "sync_dir() { :; }"; _x = 1 } { print }' \
  "$_T82_SCRIPT" > "$_t82_b1"
_t82_b1_applied=$(grep -c '^sync_dir() { :; }$' "$_t82_b1" 2>/dev/null || true)
_t82_rc=0
_t82_out=$(_t82_behavior_check "$_t82_b1" b1) || _t82_rc=$?
_t82_b1_static=0
_t82_b1_s1=$(_t82_loop_check "$_t82_b1") || _t82_b1_static=1
_t82_b1_s2=$(_t82_callsite_check "$_t82_b1") || _t82_b1_static=1
if [ "$_t82_b1_applied" != "1" ]; then
  t82_fail "TC-12 変異 B1 が空振りした（複製へ適用されていない: hits=${_t82_b1_applied}）"
elif [ "$_t82_rc" != "0" ] && printf '%s' "$_t82_out" | grep -q '^T82_BEHAVIOR_VIOL:.*undelivered'; then
  t82_pass "TC-12 変異 B1（sync_dir の no-op 再定義）を挙動 TC が検出（字面検査は素通り: static_fail=${_t82_b1_static} / ${_t82_b1_s1} / ${_t82_b1_s2}） (rc=$_t82_rc / $_t82_out)"
else
  t82_fail "TC-12 変異 B1 を入れたのに挙動 TC が通った (rc=$_t82_rc / $_t82_out)"
fi

# ── TC-13: 変異 B3（sync_dir 冒頭で commands だけ早期 return）→ 挙動 TC が FAIL ──
# allowlist にも callsite にも触れず、**1 面だけ**を配布経路から外す変異。
_t82_b3="$_T82_TMP/b3.sh"
awk '{ print; if ($0 == "  _src=\"$1\"; _dst=\"$2\"; _label=\"$3\"" && !_y) { print "  if [ \"$_label\" = commands ]; then return 0; fi"; _y = 1 } }' \
  "$_T82_SCRIPT" > "$_t82_b3"
_t82_b3_applied=$(grep -c 'if \[ "\$_label" = commands \]; then return 0; fi' "$_t82_b3" 2>/dev/null || true)
_t82_rc=0
_t82_out=$(_t82_behavior_check "$_t82_b3" b3) || _t82_rc=$?
if [ "$_t82_b3_applied" != "1" ]; then
  t82_fail "TC-13 変異 B3 が空振りした（複製へ適用されていない: hits=${_t82_b3_applied}）"
elif [ "$_t82_rc" != "0" ] && printf '%s' "$_t82_out" | grep -q 'commands/ta82-probe.md(undelivered)'; then
  t82_pass "TC-13 変異 B3（commands のみ早期 return）を挙動 TC が検出 (rc=$_t82_rc / $_t82_out)"
else
  t82_fail "TC-13 変異 B3 を入れたのに commands の未配布を検出できなかった (rc=$_t82_rc / $_t82_out)"
fi

# ── TC-14: 変異 B2（PLUGIN_DIR を別パスへ付け替え）→ 挙動 TC が FAIL ──
# 同期は「走る」が配布先がずれるクラス。allowlist / callsite は無傷。
_t82_b2="$_T82_TMP/b2.sh"
sed 's|^PLUGIN_DIR="\$REPO_ROOT/plugin/plangate"$|PLUGIN_DIR="$REPO_ROOT/plugin/plangate-elsewhere"|' \
  "$_T82_SCRIPT" > "$_t82_b2"
_t82_b2_applied=$(grep -c '^PLUGIN_DIR="\$REPO_ROOT/plugin/plangate-elsewhere"$' "$_t82_b2" 2>/dev/null || true)
_t82_rc=0
_t82_out=$(_t82_behavior_check "$_t82_b2" b2) || _t82_rc=$?
if [ "$_t82_b2_applied" != "1" ]; then
  t82_fail "TC-14 変異 B2 が空振りした（複製へ適用されていない: hits=${_t82_b2_applied}）"
elif [ "$_t82_rc" != "0" ] && printf '%s' "$_t82_out" | grep -q '^T82_BEHAVIOR_VIOL:.*undelivered'; then
  t82_pass "TC-14 変異 B2（PLUGIN_DIR 付け替え）を挙動 TC が検出 (rc=$_t82_rc / $_t82_out)"
else
  t82_fail "TC-14 変異 B2 を入れたのに挙動 TC が通った (rc=$_t82_rc / $_t82_out)"
fi

# ── TC-15: 幽霊配布物（dst のみに在るファイル）を同値照合が検出する ──────
# A-3 の positive control。src 側走査だけでは violation ゼロになるクラス。
_t82_ghost_sbx="$_T82_TMP/ghost"
mkdir -p "$_t82_ghost_sbx/src" "$_t82_ghost_sbx/dst"
for _t82_d in $_T82_REQUIRED_DIRS; do
  mkdir -p "$_t82_ghost_sbx/src/$_t82_d" "$_t82_ghost_sbx/dst/$_t82_d"
  cp "$_t82_sbx/src/$_t82_d"/*.md "$_t82_ghost_sbx/src/$_t82_d/" 2>/dev/null || true
  cp "$_t82_sbx/dst/$_t82_d"/*.md "$_t82_ghost_sbx/dst/$_t82_d/" 2>/dev/null || true
done
_t82_rc=0
_t82_ghost_base=$(_t82_parity_check "$_t82_ghost_sbx/src" "$_t82_ghost_sbx/dst") || _t82_rc=$?
printf 'ghost\n' > "$_t82_ghost_sbx/dst/rules/ta82-ghost.md"
# 注意: `A && B && var=1` は条件不成立時に rc=1 を返し、harness の `set -e` 下で
# 実行全体を落とす。必ず if 文で書く（README「隔離・後始末の規約」と同趣旨）。
_t82_ghost_applied=0
if [ -f "$_t82_ghost_sbx/dst/rules/ta82-ghost.md" ] && [ ! -f "$_t82_ghost_sbx/src/rules/ta82-ghost.md" ]; then
  _t82_ghost_applied=1
fi
_t82_rc2=0
_t82_out=$(_t82_parity_check "$_t82_ghost_sbx/src" "$_t82_ghost_sbx/dst") || _t82_rc2=$?
if [ "$_t82_rc" != "0" ]; then
  t82_fail "TC-15 前提: 幽霊注入前の複製が同値でない (rc=$_t82_rc / $_t82_ghost_base)"
elif [ "$_t82_ghost_applied" != "1" ]; then
  t82_fail "TC-15 変異が空振り（dst 専用ファイルを作れていない）"
elif [ "$_t82_rc2" != "0" ] && printf '%s' "$_t82_out" | grep -q 'rules/ta82-ghost.md(ghost)'; then
  t82_pass "TC-15 正本に無い配布側ファイル（幽霊）を双方向照合が検出 (rc=$_t82_rc2 / $_t82_out)"
else
  t82_fail "TC-15 幽霊配布物を素通りした＝同値照合が片方向のまま (rc=$_t82_rc2 / $_t82_out)"
fi

# ── TC-16: 対照 — 挙動を変えないリファクタで字面検査を誤爆させない ──────
# A-2 の逆方向対照。以下はいずれも同期挙動を変えない（むしろ改善する）ため
# 検査器 1・2 は通さなければならない。
_t82_fp_fail=''
# (a) allowlist の拡張（ハイフン入りの新ディレクトリを足す）
_t82_fp_a="$_T82_TMP/fp-a.sh"
sed 's/^for _dir in agents rules commands; do$/for _dir in agents rules commands output-styles; do/' \
  "$_T82_SCRIPT" > "$_t82_fp_a"
[ "$(grep -c '^for _dir in agents rules commands output-styles; do$' "$_t82_fp_a")" = "1" ] \
  || _t82_fp_fail="$_t82_fp_fail a(not-applied)"
_t82_fp_out=$(_t82_loop_check "$_t82_fp_a") || _t82_fp_fail="$_t82_fp_fail a:$_t82_fp_out"
# (b) allowlist の変数化
_t82_fp_b="$_T82_TMP/fp-b.sh"
awk '{ if ($0 ~ /^for _dir in agents rules commands; do$/ && !_z) { print "_gov_dirs=\"agents rules commands\""; print "for _dir in $_gov_dirs; do"; _z = 1 } else { print } }' \
  "$_T82_SCRIPT" > "$_t82_fp_b"
[ "$(grep -c '^for _dir in \$_gov_dirs; do$' "$_t82_fp_b")" = "1" ] \
  || _t82_fp_fail="$_t82_fp_fail b(not-applied)"
_t82_fp_out=$(_t82_loop_check "$_t82_fp_b") || _t82_fp_fail="$_t82_fp_fail b:$_t82_fp_out"
# (c) 呼び出し行にエラー伝播を足す + インデント変更
_t82_fp_c="$_T82_TMP/fp-c.sh"
sed 's|^  sync_dir "\$CLAUDE_DIR/\$_dir" "\$PLUGIN_DIR/\$_dir" "\$_dir"$|    sync_dir "$CLAUDE_DIR/$_dir" "$PLUGIN_DIR/$_dir" "$_dir" \|\| exit 1|' \
  "$_T82_SCRIPT" > "$_t82_fp_c"
[ "$(grep -c 'sync_dir "\$CLAUDE_DIR/\$_dir" "\$PLUGIN_DIR/\$_dir" "\$_dir" || exit 1' "$_t82_fp_c")" = "1" ] \
  || _t82_fp_fail="$_t82_fp_fail c(not-applied)"
_t82_fp_out=$(_t82_callsite_check "$_t82_fp_c") || _t82_fp_fail="$_t82_fp_fail c:$_t82_fp_out"
if [ -z "$_t82_fp_fail" ]; then
  t82_pass "TC-16 挙動を変えないリファクタ 3 種（allowlist 拡張 / 変数化 / || exit 1 + インデント）で字面検査が誤爆しない"
else
  t82_fail "TC-16 挙動を変えないリファクタで字面検査が誤爆した:$_t82_fp_fail"
fi

# ── 後片付け（trap は使わない / README 規約 1・2）─────────────────
rm -rf "$_T82_TMP"
if [ -e "$_T82_TMP" ]; then
  t82_fail "TC-10 sandbox cleanup failed: $_T82_TMP"
else
  t82_pass "TC-10 sandbox removed (mktemp 配下のみ・実 repo は不変)"
fi

pg_extra_contract_finalize
