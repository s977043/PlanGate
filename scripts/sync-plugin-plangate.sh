#!/bin/sh
# sync-plugin-plangate.sh — .claude/ を plugin/plangate/ に同期
# TASK-0124: push to main で CI が呼び出し、差分あり時に PR を自動作成
# ローカル実行: sh scripts/sync-plugin-plangate.sh [--dry-run]

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
fi

_log()    { printf '[sync-plugin] %s\n' "$1"; }
_drylog() { printf '[sync-plugin][dry-run] %s\n' "$1"; }
# safety guard の通知は stderr へ出す（#877 AC-9）。CI drift-check job は
# `sh scripts/sync-plugin-plangate.sh` を run ブロックの 1 行目で実行するため、
# 非ゼロ終了すると後続の `::error::` 説明行に到達しない。「何が起きたか / どう
# 解除するか」は本スクリプトの出力だけが伝達手段になる。
_warn()   { printf '[sync-plugin] %s\n' "$1" >&2; }

PLUGIN_DIR="$REPO_ROOT/plugin/plangate"
CLAUDE_DIR="$REPO_ROOT/.claude"
SKILLS_DIR="$REPO_ROOT/.agents/skills"

changed=0
# #861 safety guard の発火フラグ（#877 F1）。sync_dir はサブシェルを介さず
# 呼ばれるため（下の for ループ 1 箇所のみ）、POSIX sh に local が無くても
# global への集約が成立する。終端で 1 回だけ判定して exit 3 する。
guard_fired=0

# agents の model frontmatter は本リポジトリ運用向けの tier 指定（docs/ai/model-profiles.md
# §Claude Code エージェントの model tier）。配布版 plugin は利用者環境のモデル可用性に
# 依存しないよう `inherit` へ正規化する（hybrid-architecture.md「export 時の抽象化」準拠）。
_normalize_model() {
  # $1=src file → stdout に frontmatter の model: 行を inherit 化した内容を出力
  # （docs/ai/model-profiles.md §11。本文中の model: 行は対象外）
  sed '1,/^---$/{s/^model: .*/model: inherit/;}' "$1"
}
_tmp_norm=""
_ai_loop_map_file=""
# per-file 一時ファイルも trap 対象にして中断時 leak を塞ぐ（gemini MEDIUM）。
# POSIX sh に local は無く関数内代入も global なので、最後に割り当てた値を trap が掃除する。
_tmp_rewritten=""
_tmp_ho=""
trap 'rm -f "${_tmp_norm:-}" "${_ai_loop_map_file:-}" "${_tmp_rewritten:-}" "${_tmp_ho:-}"' EXIT INT TERM

# mass-delete safety guard の共通判定（#861 / #877 / #914）。
# 判定 + 警告 + guard_fired フラグ立てのみを担う（呼び出し元の制御脱出は含めない
# — sync_dir は関数 return / 経路1 はループ内 skip / 経路2 はトップレベル if と
# 制御構造が異なるため、脱出は各呼び出し側が行う）。
# $1=label $2=base 件数（src 側の残存数）$3=stale 件数（dst 側の削除候補数）
# 戻り値: 0 = 削除を保留せよ（blocked） / 1 = 削除を続行してよい
# 注意: guard_fired の global 集約は「サブシェルを介さない呼び出し」に依存する
# （上の L27-29 コメントと同じ制約）。本関数の呼び出しを $(...) 内へ置かないこと。
_mass_delete_blocked() {
  [ "$3" -gt "$2" ] || return 1
  if [ "${PLANGATE_ALLOW_MASS_DELETE:-0}" = "1" ]; then
    # override は Human-owned のローカル操作限定（CI workflow の env: には
    # 置かない）。解除したことを必ず記録に残す（#877 AC-2）。
    _warn "WARN: mass-delete guard を PLANGATE_ALLOW_MASS_DELETE=1 で解除しました — $1 (base=$2 / stale=$3) の削除を続行します"
    return 1
  fi
  _warn "WARN: DELETE skipped for $1 — base=$2 / stale=$3 (削除候補が src 残存数を上回るため削除を保留 / #861 safety guard)。意図した一括削除であれば PLANGATE_ALLOW_MASS_DELETE=1 を付けて再実行してください"
  guard_fired=1
  return 0
}

sync_dir() {
  _src="$1"; _dst="$2"; _label="$3"
  [ -d "$_src" ] || { _log "SKIP (src not found): $_label"; return 0; }
  mkdir -p "$_dst"
  for _f in "$_src"/*.md "$_src"/*.yaml "$_src"/*.yml "$_src"/*.json; do
    [ -f "$_f" ] || continue
    _base="$(basename "$_f")"
    _dfile="$_dst/$_base"
    if [ "$_label" = "agents" ] && [ "${_base##*.}" = "md" ]; then
      _tmp_norm="$(mktemp)"
      _normalize_model "$_f" > "$_tmp_norm"
      if [ ! -f "$_dfile" ] || ! cmp -s "$_tmp_norm" "$_dfile"; then
        if [ "$DRY_RUN" = "1" ]; then _drylog "WOULD COPY (model normalized): $_label/$_base"
        else cp "$_tmp_norm" "$_dfile"; _log "COPY (model normalized): $_label/$_base"; fi
        changed=1
      fi
      rm -f "$_tmp_norm"
      continue
    fi
    if [ ! -f "$_dfile" ] || ! cmp -s "$_f" "$_dfile"; then
      if [ "$DRY_RUN" = "1" ]; then _drylog "WOULD COPY: $_label/$_base"
      else cp "$_f" "$_dfile"; _log "COPY: $_label/$_base"; fi
      changed=1
    fi
  done
  # safety guard (#861 / #877): dst 側の削除候補（stale = dst にあって src に
  # 無いファイル）が src 側の残存件数を上回るときは、src が一時的に欠損している
  # 可能性が高いため削除ループのみスキップする（コピーは阻害しない）。
  # .claude/agents/ 欠損状態で sync が走って plugin 側を大量削除する事故
  # （issue #861）を構造的に防ぐ。
  #
  # #877 F2: 判定を dst 総数ベース（src*2 < dst）から stale 件数ベースへ変更する。
  # 旧式の _dst_count はコピーループ通過後に数えるため、dry-run（コピーしない）と
  # 実行（コピー済み）で同じ入力から異なる値になり判定が食い違った
  # （実測: src=3 / stale=4 で dry-run 非発火・実行発火）。stale と src は
  # コピー動作の影響を受けないため両モードで一致する。README.md は src/dst とも
  # 除外して対称に数える（旧式は src 側のみ含む非対称だった）。
  _src_count=0
  for _f in "$_src"/*.md "$_src"/*.yaml "$_src"/*.yml "$_src"/*.json; do
    [ -f "$_f" ] || continue
    [ "$(basename "$_f")" = "README.md" ] && continue
    _src_count=$((_src_count + 1))
  done
  # 注意: ここの「stale の定義」（README.md 除外 + src 側に同名が無い）は、
  # 下の削除ループの条件と**必ず一致させること**。片方だけ変えると「N 件と
  # 数えて guard を通したのに実際は M 件消す」形で guard が無効化される（#861 再発型）。
  _stale_count=0
  for _f in "$_dst"/*.md "$_dst"/*.yaml "$_dst"/*.yml "$_dst"/*.json; do
    [ -f "$_f" ] || continue
    _base="$(basename "$_f")"
    [ "$_base" = "README.md" ] && continue
    if [ ! -f "$_src/$_base" ]; then
      _stale_count=$((_stale_count + 1))
    fi
  done
  # 判定 + 警告 + guard_fired は共通関数へ集約（#914）。blocked のときのみ
  # sync_dir から脱出して削除ループをスキップする（コピーは阻害しない。
  # 呼び出し元 for の継続 = 従来挙動を維持）。
  if _mass_delete_blocked "$_label" "$_src_count" "$_stale_count"; then
    return 0
  fi
  # 削除条件は上の _stale_count 集計と同一（README.md 除外 + src に同名が無い）。
  # 変更する場合は必ず両方を同時に更新する。
  for _f in "$_dst"/*.md "$_dst"/*.yaml "$_dst"/*.yml "$_dst"/*.json; do
    [ -f "$_f" ] || continue
    _base="$(basename "$_f")"
    [ "$_base" = "README.md" ] && continue
    if [ ! -f "$_src/$_base" ]; then
      if [ "$DRY_RUN" = "1" ]; then _drylog "WOULD DELETE: $_label/$_base"
      else rm "$_f"; _log "DELETE: $_label/$_base"; fi
      changed=1
    fi
  done
}

for _dir in agents rules commands; do
  sync_dir "$CLAUDE_DIR/$_dir" "$PLUGIN_DIR/$_dir" "$_dir"
done

# スキルはサブディレクトリ構造を持つため再帰コピーで同期する
# 各スキルの SKILL.md を plugin/plangate/skills/<name>/SKILL.md にコピー
_plugin_skills="$PLUGIN_DIR/skills"
mkdir -p "$_plugin_skills"
for _skill_dir in "$SKILLS_DIR"/*/; do
  [ -d "$_skill_dir" ] || continue
  _skill_name="$(basename "$_skill_dir")"
  _src_md="$_skill_dir/SKILL.md"
  [ -f "$_src_md" ] || continue
  _dst_dir="$_plugin_skills/$_skill_name"
  _dst_md="$_dst_dir/SKILL.md"
  mkdir -p "$_dst_dir"
  if [ ! -f "$_dst_md" ] || ! cmp -s "$_src_md" "$_dst_md"; then
    if [ "$DRY_RUN" = "1" ]; then _drylog "WOULD COPY: skills/$_skill_name/SKILL.md"
    else cp "$_src_md" "$_dst_md"; _log "COPY: skills/$_skill_name/SKILL.md"; fi
    changed=1
  fi
  # bundled references/*.md を同期（Agent Skills bundled resources / #797）。
  # ai-loop-cycle は除外: その references/ は正本 docs からリンク変換つきで
  # 生成する専用セクション（issue #771/#790）が管理しており、.agents/ 側に
  # references/ が無いため、この汎用同期（特に削除ループ）を通すと専用
  # セクションの成果物を消してしまう。
    # source に references が無いスキルは本同期の管理外として dest に触らない
    # （汎用セマンティクス。ai-loop-cycle は専用セクションが生成するため従来は
    #   名指しガードだったが、src 存在ガードに一般化 — gemini #805 対応）
    _src_refs="$_skill_dir/references"
    _dst_refs="$_dst_dir/references"
    if [ -d "$_src_refs" ]; then
      mkdir -p "$_dst_refs"
      for _rf in "$_src_refs"/*.md; do
        [ -f "$_rf" ] || continue
        [ -L "$_rf" ] && continue
        _rb="${_rf##*/}"
        _rdst="$_dst_refs/$_rb"
        if [ ! -f "$_rdst" ] || ! cmp -s "$_rf" "$_rdst"; then
          if [ "$DRY_RUN" = "1" ]; then _drylog "WOULD COPY: skills/$_skill_name/references/$_rb"
          else cp "$_rf" "$_rdst"; _log "COPY: skills/$_skill_name/references/$_rb"; fi
          changed=1
        fi
      done
    fi
    if [ -d "$_src_refs" ] && [ -d "$_dst_refs" ]; then
      # mass-delete safety guard（#914 経路1）: src 側 references/ の空化・欠損で
      # 当該 skill の dst references/ を一括削除する事故を防ぐ。削除実行前に
      # base（src 側 *.md 残存数）と stale（dst にあって src に同名が無い *.md 数）
      # を集計し、blocked なら**当該 skill の references 削除のみ** skip する
      # （他 skill の処理・コピーは継続）。
      # dst 側 stale 集計は**削除ループと同一条件**で数える（[ -L ] 除外は入れない
      # / #970）。集計が削除より狭い（集計 ⊊ 削除）と「N 件と数えて M 件消す」
      # ことになり guard が無効化されるため、集計の正は常に削除ループ側に置く。
      # src 側 base 集計はコピーループ（[ -L ] 除外あり）と対を成すため除外を維持する
      # （ただし stale 判定の [ ! -f "$_src_refs/$_rb" ] は symlink を辿るため、base の
      #  集合とは一致しない。安全側＝過剰 block に倒れるため許容 / #970 Non-goal）。
      _refs_base_count=0
      for _rf in "$_src_refs"/*.md; do
        [ -f "$_rf" ] || continue
        [ -L "$_rf" ] && continue
        _refs_base_count=$((_refs_base_count + 1))
      done
      _refs_stale_count=0
      for _rf in "$_dst_refs"/*.md; do
        [ -f "$_rf" ] || continue
        _rb="${_rf##*/}"
        if [ ! -f "$_src_refs/$_rb" ]; then
          _refs_stale_count=$((_refs_stale_count + 1))
        fi
      done
      # 呼び出しを $(...) 内へ置かないこと（guard_fired の global 伝播条件）。
      # blocked 時は break を使わず if で当該 skill の削除だけを避ける
      # （break だと後続 skill の同期が落ちる）。
      if ! _mass_delete_blocked "skills/$_skill_name/references" "$_refs_base_count" "$_refs_stale_count"; then
        # 削除条件は上の _refs_stale_count 集計と同一（[ -L ] 除外を足さない +
        # src に同名が無い）。変更する場合は必ず両方を同時に更新する。
        for _rf in "$_dst_refs"/*.md; do
          [ -f "$_rf" ] || continue
          _rb="${_rf##*/}"
          if [ ! -f "$_src_refs/$_rb" ]; then
            if [ "$DRY_RUN" = "1" ]; then _drylog "WOULD DELETE: skills/$_skill_name/references/$_rb"
            else rm "$_rf"; _log "DELETE: skills/$_skill_name/references/$_rb"; fi
            changed=1
          fi
        done
      fi
    fi
done

# ai-loop-workflow の docs / scripts を plugin へ同期（issue #771 rework）
# Plugin は docs/ を配布対象として認識しない（公式仕様: プラグインが読み込むのは
# agents/commands/skills 等の定義ディレクトリのみ）ため、Agent Skills の
# bundled resources 方式（skill ディレクトリ内 references/ + scripts/ に自己完結
# 同梱）へ再設計。同期先は plugin/plangate/skills/ai-loop-cycle/ 配下のみ:
# - docs/workflows/ai-loop/*.md（正本 10 本）→ .../ai-loop-cycle/references/（フラット配置）
# - docs/ai/ai-loop/ の思想・仕様層抜粋（run 由来レポート・asset-inventory 等の
#   内部管理系は対象外）→ 同上 references/（ho-paths.md のみ雛形注記ヘッダを前置）
# - scripts/ai-loop/{arbiter,test_arbiter}.py → .../ai-loop-cycle/scripts/
# 旧同期先（plugin/plangate/docs/ 全体・plugin/plangate/scripts/ai-loop/）は廃止。
#
# issue #790: references/ へ書き込む内容は正本 verbatim ではなく、
# scripts/_ai_loop_link_rewrite.py で markdown リンクを自己完結化してから
# 書き込む（正本側の `../`/`../../`/`../../../` 相対リンクは plugin 導入先で
# リンク切れになるため）。変換は plugin コピーにのみ適用し、正本
# docs/workflows/ai-loop/*.md・docs/ai/ai-loop/*.md 自体は変更しない。
AI_LOOP_WORKFLOWS_DIR="$REPO_ROOT/docs/workflows/ai-loop"
AI_LOOP_SPEC_DIR="$REPO_ROOT/docs/ai/ai-loop"
AI_LOOP_SCRIPTS_DIR="$REPO_ROOT/scripts/ai-loop"
PLUGIN_AI_LOOP_SKILL_NAME="ai-loop-cycle"
PLUGIN_AI_LOOP_SKILL_DIR="$PLUGIN_DIR/skills/$PLUGIN_AI_LOOP_SKILL_NAME"
PLUGIN_AI_LOOP_REFS="$PLUGIN_AI_LOOP_SKILL_DIR/references"
PLUGIN_AI_LOOP_SCRIPTS="$PLUGIN_AI_LOOP_SKILL_DIR/scripts"
AI_LOOP_LINK_REWRITER="$REPO_ROOT/scripts/_ai_loop_link_rewrite.py"

# docs/ai/ai-loop から同梱する思想・仕様層ファイル名（内部管理系除外の選定結果）
_ai_loop_spec_files="design-philosophy.md arbiter-policy.md concept.md README.md hotl-merge-entry-criteria.md related-specs.md"

_sync_ai_loop_file() {
  # $1=src file, $2=dst dir, $3=label（ログ用）— リンク変換なしの単純コピー
  # （scripts/*.py 等、markdown リンクを含まない同期対象向け。references/ の
  #  markdown は _sync_ai_loop_ref_content を使う）
  _f="$1"; _dst_dir="$2"; _label="$3"
  mkdir -p "$_dst_dir"
  _base="$(basename "$_f")"
  _dfile="$_dst_dir/$_base"
  if [ ! -f "$_dfile" ] || ! cmp -s "$_f" "$_dfile"; then
    if [ "$DRY_RUN" = "1" ]; then _drylog "WOULD COPY: $_label/$_base"
    else cp "$_f" "$_dfile"; _log "COPY: $_label/$_base"; fi
    changed=1
  fi
}

# references/ はフラット配置（workflows 10 本 + spec 6 本 + ho-paths.md = 17 本、
# ファイル名衝突なしを確認済み）。SKILL.md は本ループの対象外（親ディレクトリに
# 配置されるため references/*.md の glob には含まれず、削除ループの対象にもならない）
#
# bundle 集合（_ai_loop_expected_refs）はリンク変換（issue #790）の判定にも使う
# ため、コピーより前に全件を確定させる（二段構成: (1) 期待 basename 一覧を確定
# → (2) 内容を変換しつつ書き込み。先にコピーしながら集合を積み上げると、後半で
# 追加される bundle ファイルへの内部リンクを前半ファイルの変換時点でまだ判定
# できない）。
#
# issue #790 MAJOR 是正: リンク変換は basename 単独では別実体へ誤ポイントし得る
# （例 docs/ai/subagent-delegation/README.md が ai-loop の README.md と basename
# 衝突）。同一実体判定のため basename → **バンドル元ソース実パス** の写像も
# ここで確定し TSV でリライタへ渡す（key 集合がバンドル集合を成す）。
_ai_loop_expected_refs=""
_ai_loop_map_file="$(mktemp)"
: > "$_ai_loop_map_file"
if [ -d "$AI_LOOP_WORKFLOWS_DIR" ]; then
  for _f in "$AI_LOOP_WORKFLOWS_DIR"/*.md; do
    [ -f "$_f" ] || continue
    _b="$(basename "$_f")"
    _ai_loop_expected_refs="$_ai_loop_expected_refs $_b"
    printf '%s\t%s\n' "$_b" "$_f" >> "$_ai_loop_map_file"
  done
fi
if [ -d "$AI_LOOP_SPEC_DIR" ]; then
  for _name in $_ai_loop_spec_files; do
    [ -f "$AI_LOOP_SPEC_DIR/$_name" ] || continue
    _ai_loop_expected_refs="$_ai_loop_expected_refs $_name"
    printf '%s\t%s\n' "$_name" "$AI_LOOP_SPEC_DIR/$_name" >> "$_ai_loop_map_file"
  done
  if [ -f "$AI_LOOP_SPEC_DIR/ho-paths.md" ]; then
    _ai_loop_expected_refs="$_ai_loop_expected_refs ho-paths.md"
    printf '%s\t%s\n' "ho-paths.md" "$AI_LOOP_SPEC_DIR/ho-paths.md" >> "$_ai_loop_map_file"
  fi
fi

_sync_ai_loop_ref_content() {
  # $1=content src file（変換前の内容。ho-paths.md はヘッダ前置後の tmp file）
  # $2=source path（相対リンク解決の基準となる論理ソースパス。ho-paths.md は
  #    ヘッダ前置前の元パス）、$3=dst basename（例: 00_concept.md）、$4=label
  # references/ へ書き込む直前に markdown リンクを自己完結化する（issue #790）:
  #   同一実体のバンドル内部参照 → ./name.md、本スキル自身の SKILL.md →
  #   ../SKILL.md、それ以外（外部正本・別実体）→ リンク解除しインラインコード化
  _content_src="$1"; _source_path="$2"; _base="$3"; _label="$4"
  mkdir -p "$PLUGIN_AI_LOOP_REFS"
  _dfile="$PLUGIN_AI_LOOP_REFS/$_base"
  _tmp_rewritten="$(mktemp)"
  python3 "$AI_LOOP_LINK_REWRITER" "$_content_src" "$_source_path" \
    "$PLUGIN_AI_LOOP_SKILL_NAME" "$_ai_loop_map_file" > "$_tmp_rewritten"
  if [ ! -f "$_dfile" ] || ! cmp -s "$_tmp_rewritten" "$_dfile"; then
    if [ "$DRY_RUN" = "1" ]; then _drylog "WOULD COPY (links self-contained): $_label/$_base"
    else cp "$_tmp_rewritten" "$_dfile"; _log "COPY (links self-contained): $_label/$_base"; fi
    changed=1
  fi
  rm -f "$_tmp_rewritten"
}

if [ -d "$AI_LOOP_WORKFLOWS_DIR" ]; then
  for _f in "$AI_LOOP_WORKFLOWS_DIR"/*.md; do
    [ -f "$_f" ] || continue
    _sync_ai_loop_ref_content "$_f" "$_f" "$(basename "$_f")" "skills/ai-loop-cycle/references"
  done
fi
if [ -d "$AI_LOOP_SPEC_DIR" ]; then
  for _name in $_ai_loop_spec_files; do
    _f="$AI_LOOP_SPEC_DIR/$_name"
    [ -f "$_f" ] || continue
    _sync_ai_loop_ref_content "$_f" "$_f" "$_name" "skills/ai-loop-cycle/references"
  done

  # ho-paths.md はプロジェクト固有のため、雛形注記ヘッダを前置してからリンク変換する
  _ho_src="$AI_LOOP_SPEC_DIR/ho-paths.md"
  if [ -f "$_ho_src" ]; then
    _tmp_ho="$(mktemp)"
    {
      printf '%s\n' '> **雛形注記**: 本ファイルは PlanGate リポジトリでの運用実績を示す配布時の参考例です。'
      printf '%s\n' '> HO（Hardening Override）パス一覧はプロジェクト固有につき、**導入先で確定**してください。'
      printf '%s\n' '> 未確定のパスに触れる変更は、arbiter が安全側 escalate（human escalate）する原則を守ってください。'
      printf '\n'
      cat "$_ho_src"
    } > "$_tmp_ho"
    _sync_ai_loop_ref_content "$_tmp_ho" "$_ho_src" "ho-paths.md" "skills/ai-loop-cycle/references"
    rm -f "$_tmp_ho"
  fi
fi
# plugin 側の skills/ai-loop-cycle/references/ から、正本側に存在しなくなったファイルを削除する
# mass-delete safety guard（#914 経路2）: 削除実行前に base（期待集合
# _ai_loop_expected_refs の要素数）と stale（dst にあって期待集合に無い *.md 数）を
# 集計し、blocked なら削除ループ全体を skip する（コピー処理は上で完了済み・阻害しない）。
#
# 保証範囲（plan 論点 C-2 で Human 承認済みの設計選択）:
#   base は正本 2 ディレクトリ（docs/workflows/ai-loop / docs/ai/ai-loop）の
#   **合算**である。したがって本 guard が捕捉するのは「合算 base に対して stale が
#   上回る」規模の異常（両正本の同時欠損・空化、多数側ディレクトリの消失など）に
#   限られる。**少数側ディレクトリ（docs/ai/ai-loop）を丸ごと欠損させても
#   stale <= base のままとなり、WARN なし・exit 0 で削除が通る**（検出しない）。
#   ディレクトリ単位の完全欠損を個別に検出したい場合は正本ごとに base を
#   分離する必要があるが、本 PBI では合算方式を採用した。
if [ -d "$PLUGIN_AI_LOOP_REFS" ]; then
  # 要素数の算出は意図的な未 quote 展開（スペース区切りのワード分割）。後段に
  # 位置パラメータの使用（$@ / shift / set --）が無いことは確認済み（U-2。
  # $1 の --dry-run 判定は冒頭で消費済み）。
  set -- $_ai_loop_expected_refs
  _ai_loop_ref_base_count=$#
  # stale の定義（*.md 実ファイル + 期待集合に無い）は下の削除ループの条件と
  # **必ず一致させること**。片方だけ変えると「N 件と数えて M 件消す」形で
  # guard が無効化される（#861 再発型）。
  _ai_loop_ref_stale_count=0
  for _f in "$PLUGIN_AI_LOOP_REFS"/*.md; do
    [ -f "$_f" ] || continue
    _base="$(basename "$_f")"
    case " $_ai_loop_expected_refs " in
      *" $_base "*) : ;;
      *) _ai_loop_ref_stale_count=$((_ai_loop_ref_stale_count + 1)) ;;
    esac
  done
  # 呼び出しを $(...) 内へ置かないこと（guard_fired の global 伝播条件）
  if ! _mass_delete_blocked "skills/ai-loop-cycle/references" "$_ai_loop_ref_base_count" "$_ai_loop_ref_stale_count"; then
    for _f in "$PLUGIN_AI_LOOP_REFS"/*.md; do
      [ -f "$_f" ] || continue
      _base="$(basename "$_f")"
      case " $_ai_loop_expected_refs " in
        *" $_base "*) : ;;
        *)
          if [ "$DRY_RUN" = "1" ]; then _drylog "WOULD DELETE: skills/ai-loop-cycle/references/$_base"
          else rm "$_f"; _log "DELETE: skills/ai-loop-cycle/references/$_base"; fi
          changed=1
          ;;
      esac
    done
  fi
fi

# arbiter 裁定エンジン + テスト + metrics（#780 Slice D 後半: test_arbiter.py の
# ArbiterMetricsIntegrationTests が同ディレクトリの metrics モジュールを import
# するため、bundled 配置でも自立実行できるよう metrics.py も同梱する）+
# test_metrics.py（#780 follow-up / #815: metrics.py 単独の bundled 自立テスト
# 完全性のため metrics.py と対で同梱する）を同期
# （__pycache__ は対象外。markdown リンクを含まないためリンク変換は不要、
# 単純コピーの _sync_ai_loop_file を使う）
if [ -d "$AI_LOOP_SCRIPTS_DIR" ]; then
  # plan_package.py + test_plan_package.py（TASK-0872 / R-008: Plan-first 束縛層。
  # 明示列挙に無いと plugin 配布物からサイレント欠落するため必ず対で列挙する）
  # c3_contract.py + test_c3_contract.py（TASK-0896: arbiter/plan_package/
  # c3prime_verify が import する共通契約層。列挙漏れは bundled 側 import エラー）
  # delivery.py + test_delivery.py（TASK-0873: MERGE_READY 状態機械。
  # c3prime_verify/c3_contract を import するため対で列挙する）
  # gh_exec / check_exec_boundary / collector / ci_taxonomy / executor / reconciler
  # （TASK-0917 / R-011: 実 PR 収束レーン。本 for ループと下の case 許可判定は
  # **同一集合**でなければならない（片方漏れ = sync drift。T-39 で機械照合する））
  for _f in "$AI_LOOP_SCRIPTS_DIR/arbiter.py" "$AI_LOOP_SCRIPTS_DIR/test_arbiter.py" "$AI_LOOP_SCRIPTS_DIR/metrics.py" "$AI_LOOP_SCRIPTS_DIR/test_metrics.py" "$AI_LOOP_SCRIPTS_DIR/plan_package.py" "$AI_LOOP_SCRIPTS_DIR/test_plan_package.py" "$AI_LOOP_SCRIPTS_DIR/c3prime_verify.py" "$AI_LOOP_SCRIPTS_DIR/test_c3prime_verify.py" "$AI_LOOP_SCRIPTS_DIR/c3_contract.py" "$AI_LOOP_SCRIPTS_DIR/test_c3_contract.py" "$AI_LOOP_SCRIPTS_DIR/delivery.py" "$AI_LOOP_SCRIPTS_DIR/test_delivery.py" "$AI_LOOP_SCRIPTS_DIR/gh_exec.py" "$AI_LOOP_SCRIPTS_DIR/test_gh_exec.py" "$AI_LOOP_SCRIPTS_DIR/check_exec_boundary.py" "$AI_LOOP_SCRIPTS_DIR/test_check_exec_boundary.py" "$AI_LOOP_SCRIPTS_DIR/collector.py" "$AI_LOOP_SCRIPTS_DIR/test_collector.py" "$AI_LOOP_SCRIPTS_DIR/ci_taxonomy.py" "$AI_LOOP_SCRIPTS_DIR/test_ci_taxonomy.py" "$AI_LOOP_SCRIPTS_DIR/executor.py" "$AI_LOOP_SCRIPTS_DIR/test_executor.py" "$AI_LOOP_SCRIPTS_DIR/reconciler.py" "$AI_LOOP_SCRIPTS_DIR/test_reconciler.py" "$AI_LOOP_SCRIPTS_DIR/run_evidence.py" "$AI_LOOP_SCRIPTS_DIR/test_run_evidence.py" "$AI_LOOP_SCRIPTS_DIR/run_evidence_verify.py" "$AI_LOOP_SCRIPTS_DIR/test_run_evidence_verify.py"; do
    [ -f "$_f" ] || continue
    _sync_ai_loop_file "$_f" "$PLUGIN_AI_LOOP_SCRIPTS" "skills/ai-loop-cycle/scripts"
  done
fi
if [ -d "$PLUGIN_AI_LOOP_SCRIPTS" ]; then
  for _f in "$PLUGIN_AI_LOOP_SCRIPTS"/*.py; do
    [ -f "$_f" ] || continue
    _base="$(basename "$_f")"
    case "$_base" in
      # 上の for ループ（コピー元列挙）と **同一集合** に保つこと。片方漏れは
      # sync drift（TASK-0917 / R-011）。T-39 の機械照合で差分 0 を確認する。
      arbiter.py|test_arbiter.py|metrics.py|test_metrics.py|plan_package.py|test_plan_package.py|c3prime_verify.py|test_c3prime_verify.py|c3_contract.py|test_c3_contract.py|delivery.py|test_delivery.py|gh_exec.py|test_gh_exec.py|check_exec_boundary.py|test_check_exec_boundary.py|collector.py|test_collector.py|ci_taxonomy.py|test_ci_taxonomy.py|executor.py|test_executor.py|reconciler.py|test_reconciler.py|run_evidence.py|test_run_evidence.py|run_evidence_verify.py|test_run_evidence_verify.py) : ;;
      *)
        if [ "$DRY_RUN" = "1" ]; then _drylog "WOULD DELETE: skills/ai-loop-cycle/scripts/$_base"
        else rm "$_f"; _log "DELETE: skills/ai-loop-cycle/scripts/$_base"; fi
        changed=1
        ;;
    esac
  done
fi

# bundled schema（TASK-0874 / R1 M-4）: run_evidence_verify.py は schema を
# 「唯一の正」として読むが、plugin 導入先には REPO_ROOT/docs/schemas/ が存在せず
# 受理器が**常に起動不能**になっていた（実測 exit 1）。skill 直下の schemas/ へ
# 同梱し、受理器側の SCHEMA_CANDIDATES 2 本目がここを解決する。
#
# ⚠️ 上の scripts/*.py 同期ループ（と対の case 文）には **足さないこと**。
# tests/extras/ta-60-run-evidence.sh の drift 検査は for ループから `.py` だけを
# 抽出して case 文と集合比較するため、片方に `.json` が混ざると誤検知する。
PLUGIN_AI_LOOP_SCHEMAS="$PLUGIN_AI_LOOP_SKILL_DIR/schemas"
_ai_loop_schema_files="run-evidence.schema.json"
if [ -d "$REPO_ROOT/docs/schemas" ]; then
  for _name in $_ai_loop_schema_files; do
    [ -f "$REPO_ROOT/docs/schemas/$_name" ] || continue
    _sync_ai_loop_file "$REPO_ROOT/docs/schemas/$_name" "$PLUGIN_AI_LOOP_SCHEMAS" \
      "skills/ai-loop-cycle/schemas"
  done
fi
if [ -d "$PLUGIN_AI_LOOP_SCHEMAS" ]; then
  for _f in "$PLUGIN_AI_LOOP_SCHEMAS"/*.json; do
    [ -f "$_f" ] || continue
    _base="$(basename "$_f")"
    case " $_ai_loop_schema_files " in
      *" $_base "*) : ;;
      *)
        if [ "$DRY_RUN" = "1" ]; then _drylog "WOULD DELETE: skills/ai-loop-cycle/schemas/$_base"
        else rm "$_f"; _log "DELETE: skills/ai-loop-cycle/schemas/$_base"; fi
        changed=1
        ;;
    esac
  done
fi

# バージョン番号を CHANGELOG から取得（README.md / plugin.json 共用）
_ver=""
if [ -f "$REPO_ROOT/CHANGELOG.md" ]; then
  _ver=$(grep '^## v[0-9]' "$REPO_ROOT/CHANGELOG.md" | head -1 | sed 's/## \(v[^ ]*\).*/\1/')
fi
# semver 形式を検証（CHANGELOG フォーマット変更時の誤 version 注入を防ぐ）。
# 非 semver なら _ver を空にし、後続の version 書き込みを全てスキップする。
if [ -n "$_ver" ]; then
  # X.Y.Z（任意で -prerelease）を厳格検証。case の glob は緩く 8.11.0.1 等を
  # 通してしまうため grep -E の正規表現で判定する。
  if ! printf '%s' "${_ver#v}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'; then
    _log "WARN: CHANGELOG の version '$_ver' が semver 形式でないため version 同期をスキップ"
    _ver=""
  fi
fi

# README.md の Version 行を更新
PLUGIN_README="$PLUGIN_DIR/README.md"
if [ -n "$_ver" ] && [ -f "$PLUGIN_README" ]; then
  _cur=$(grep '^\- \*\*Version\*\*:' "$PLUGIN_README" | sed 's/.*: //' || true)
  if [ "$_cur" != "$_ver" ]; then
    if [ "$DRY_RUN" = "1" ]; then _drylog "WOULD UPDATE README version: $_cur -> $_ver"
    else
      _tmp=$(mktemp)
      sed "s/^\(- \*\*Version\*\*:\).*/\1 $_ver/" "$PLUGIN_README" > "$_tmp" && mv "$_tmp" "$PLUGIN_README"
      _log "UPDATE README version: $_cur -> $_ver"
    fi
    changed=1
  fi
fi

# plugin.json の version フィールドを更新
PLUGIN_JSON="$PLUGIN_DIR/.claude-plugin/plugin.json"
if [ -n "$_ver" ] && [ -f "$PLUGIN_JSON" ] && command -v python3 >/dev/null 2>&1; then
  _pcur=$(python3 - "$PLUGIN_JSON" << 'PYJSON' 2>/dev/null || true
import json, sys
try:
    with open(sys.argv[1], encoding='utf-8') as f:
        print(json.load(f).get('version', ''))
except Exception:
    print('')
PYJSON
)
  _ver_noprefix="${_ver#v}"
  if [ "$_pcur" != "$_ver_noprefix" ]; then
    if [ "$DRY_RUN" = "1" ]; then _drylog "WOULD UPDATE plugin.json version: $_pcur -> $_ver_noprefix"
    else
      python3 - "$PLUGIN_JSON" "$_ver" << 'PYEOF'
import json, sys
path, ver = sys.argv[1], sys.argv[2]
with open(path, encoding='utf-8') as f:
    d = json.load(f)
d['version'] = ver.lstrip('v')
with open(path, 'w', encoding='utf-8') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write('\n')
PYEOF
      _log "UPDATE plugin.json version: $_pcur -> $_ver_noprefix"
    fi
    changed=1
  fi
fi

# marketplace.json の plugins[].version を更新（plugin.json と同期 / #456）
MARKETPLACE_JSON="$REPO_ROOT/.claude-plugin/marketplace.json"
if [ -n "$_ver" ] && [ -f "$MARKETPLACE_JSON" ] && command -v python3 >/dev/null 2>&1; then
  _ver_noprefix="${_ver#v}"
  _mp_changed=$(python3 - "$MARKETPLACE_JSON" "$_ver_noprefix" "$DRY_RUN" << 'PYJSON'
import json, sys
path, ver, dry = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(path, encoding='utf-8') as f:
        d = json.load(f)
except Exception as e:
    sys.stderr.write('marketplace.json read/parse error: %s\n' % e)
    sys.exit(1)
target = [p for p in d.get('plugins', []) if p.get('name') == 'plangate']
if not target:
    sys.stderr.write('marketplace.json に plangate plugin 定義がありません\n')
    sys.exit(1)
changed = []
for plug in target:
    if plug.get('version') != ver:
        changed.append('%s -> %s' % (plug.get('version'), ver))
        if dry != '1':
            plug['version'] = ver
# marketplace 自体の metadata.version も同期（plugins[].version との二重管理防止）
md = d.get('metadata')
if isinstance(md, dict) and md.get('version') not in (None, ver):
    changed.append('metadata %s -> %s' % (md.get('version'), ver))
    if dry != '1':
        md['version'] = ver
if changed and dry != '1':
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(d, f, indent=2, ensure_ascii=False)
        f.write('\n')
print(';'.join(changed))
PYJSON
) || { _log "ERROR: marketplace.json 同期に失敗（parse 失敗 / plangate 未定義）"; exit 1; }
  if [ -n "$_mp_changed" ]; then
    if [ "$DRY_RUN" = "1" ]; then _drylog "WOULD UPDATE marketplace.json version: $_mp_changed"
    else _log "UPDATE marketplace.json version: $_mp_changed"; fi
    changed=1
  fi
fi

if [ "$changed" = "1" ]; then
  _log "Sync complete — changes detected"
else
  _log "Sync complete — no changes"
fi

# #877 F1: mass-delete safety guard が発火した run は非ゼロ（exit 3）で終了する。
# 従来は WARN を出して exit 0 のまま終わっていたため、CI の sync job が「削除が
# 永久に保留されたまま毎 run 発火し続ける」恒久 drift を検知できなかった。
# dry-run は副作用が無く予告のみのため exit 0 を維持する（CI の 2 job はいずれも
# --dry-run を使わない生実行であり、exit 3 だけで job は自動 fail する）。
# exit code の優先順位: 先行 fatal（marketplace.json 同期失敗の exit 1）> guard（exit 3）。
if [ "$guard_fired" = "1" ] && [ "$DRY_RUN" != "1" ]; then
  _warn "ERROR: mass-delete safety guard が発火したため削除を保留しました (#861 / #877)。正本側の欠損を確認するか、意図した一括削除であれば PLANGATE_ALLOW_MASS_DELETE=1 を付けて再実行してください"
  exit 3
fi
