# tests/fixtures/pg-fold-path.sh
# TASK-1101 / #1101 — HO 判定用パス正規化関数の**正本ソース**。
#
# 本ファイルの `>>> PG-FOLD-PATH BEGIN` 〜 `<<< PG-FOLD-PATH END` の間は
# scripts/hooks/check-plan-hash.sh へ **byte 一致で inline される**
# （check-plan-hash.sh は Hardening Override 対象パスであり AI が直接編集
#  できないため、単体ファイルを正本にして patch 経由で適用する）。
# 一致は ta-65 の parity TC が機械照合する。
#
# 使い方（単体評価）:
#   . tests/fixtures/pg-fold-path.sh
#   _pg_fold_path 'bin/../bin/plangate' "$PWD" 1
#   printf '%s rc=%s\n' "$_PG_FOLD_OUT" "$_PG_FOLD_RC"

# >>> PG-FOLD-PATH BEGIN (#1101)
# _pg_fold_path — HO 判定専用のパス正規化（字句のみ / FS に触れない）
#
#   In : $1 = 対象パス / $2 = repo root（空可）/ $3 = 1 なら小文字化
#   Out: _PG_FOLD_OUT    正規化結果
#        _PG_FOLD_RC     0=正常 / 1=fail-closed（呼び出し側が block する）
#        _PG_FOLD_REASON fail-closed の理由（rc=1 のときのみ意味を持つ）
#
# 適用順（#1101 / RiverReview critical）:
#   (1) 末尾空白の除去
#   (2) // の畳み込み / . セグメント除去 / .. の字句的畳み込み  ← **最初に**
#   (3) 先頭 ./ の除去（(2) のセグメント走査に含まれる）
#   (4) repo root の除去
#   (5) 小文字化（_ho_key のみ / $3=1）
#   ※ (2) を (3) より後ろに置くと `.//CLAUDE.md` が素通りする。
#
# 制約:
#   - 単語分割に依存しない（zsh で no-op になるため / R-002）
#   - 外部コマンドを呼ばない（fork 増加ゼロ / AC-11）。呼び出し側も
#     コマンド置換を使わず、結果はグローバル変数で受け取ること
#   - 先頭 `/` は除去しない（絶対パスを block しない / N-1・TC-11b）
#   - 末尾 `/` は保持する（`CLAUDE.md/` は FS 到達不能なので skip 側のまま）
#   - シンボリックリンクは解決しない（Non-goal）
_PG_FOLD_MAXSEG=256

_pg_fold_tolower() {
  _pl_in=$1
  case "$_pl_in" in
    *[ABCDEFGHIJKLMNOPQRSTUVWXYZ]*) ;;
    *) _PG_FOLD_LOWER=$_pl_in; return 0 ;;
  esac
  _pl_out=''
  while [ -n "$_pl_in" ]; do
    _pl_rest=${_pl_in#?}
    _pl_c=${_pl_in%"$_pl_rest"}
    _pl_in=$_pl_rest
    case "$_pl_c" in
      A) _pl_c=a ;; B) _pl_c=b ;; C) _pl_c=c ;; D) _pl_c=d ;;
      E) _pl_c=e ;; F) _pl_c=f ;; G) _pl_c=g ;; H) _pl_c=h ;;
      I) _pl_c=i ;; J) _pl_c=j ;; K) _pl_c=k ;; L) _pl_c=l ;;
      M) _pl_c=m ;; N) _pl_c=n ;; O) _pl_c=o ;; P) _pl_c=p ;;
      Q) _pl_c=q ;; R) _pl_c=r ;; S) _pl_c=s ;; T) _pl_c=t ;;
      U) _pl_c=u ;; V) _pl_c=v ;; W) _pl_c=w ;; X) _pl_c=x ;;
      Y) _pl_c=y ;; Z) _pl_c=z ;;
    esac
    _pl_out=$_pl_out$_pl_c
  done
  _PG_FOLD_LOWER=$_pl_out
}

_pg_fold_path() {
  _pf_in=${1:-}
  _pf_root=${2:-}
  _pf_lower=${3:-0}
  _PG_FOLD_OUT=''
  _PG_FOLD_RC=0
  _PG_FOLD_REASON=''

  # (1) 末尾空白（space / tab 等）の除去
  while [ -n "$_pf_in" ]; do
    case "$_pf_in" in
      *[[:space:]]) _pf_in=${_pf_in%?} ;;
      *) break ;;
    esac
  done

  # (2)(3) セグメント走査による畳み込み
  _pf_abs=0
  case "$_pf_in" in /*) _pf_abs=1 ;; esac
  _pf_trail=0
  case "$_pf_in" in */) _pf_trail=1 ;; esac
  _pf_rest=$_pf_in
  _pf_out=''
  _pf_n=0
  while [ -n "$_pf_rest" ]; do
    _pf_n=$((_pf_n + 1))
    if [ "$_pf_n" -gt "$_PG_FOLD_MAXSEG" ]; then
      _PG_FOLD_RC=1
      _PG_FOLD_REASON="segment limit exceeded (>$_PG_FOLD_MAXSEG)"
      _PG_FOLD_OUT=$_pf_in
      return 0
    fi
    case "$_pf_rest" in
      */*) _pf_seg=${_pf_rest%%/*}; _pf_rest=${_pf_rest#*/} ;;
      *) _pf_seg=$_pf_rest; _pf_rest='' ;;
    esac
    case "$_pf_seg" in
      '')
        # 連続スラッシュ / 先頭スラッシュ由来の空セグメント
        continue
        ;;
      .)
        # 先頭 ./ と 中間 /./ の双方
        continue
        ;;
      ..)
        if [ "$_pf_abs" = 1 ] && [ -z "$_pf_out" ]; then
          # 絶対パスの root を越える .. は root に固定する
          continue
        fi
        case "$_pf_out" in
          '') _pf_out='..' ;;
          '..') _pf_out='../..' ;;
          *'/..') _pf_out="$_pf_out/.." ;;
          */*) _pf_out=${_pf_out%/*} ;;
          *) _pf_out='' ;;
        esac
        ;;
      *)
        if [ -z "$_pf_out" ]; then
          _pf_out=$_pf_seg
        else
          _pf_out="$_pf_out/$_pf_seg"
        fi
        ;;
    esac
  done

  # fail-closed (a): 畳み込み**後**に先頭 .. が残る（相対パスのみ）
  if [ "$_pf_abs" = 0 ]; then
    case "$_pf_out" in
      '..'|'../'*)
        _PG_FOLD_RC=1
        _PG_FOLD_REASON="leading .. after folding"
        _PG_FOLD_OUT=$_pf_out
        return 0
        ;;
    esac
  fi

  if [ "$_pf_abs" = 1 ]; then
    _pf_final="/$_pf_out"
  else
    _pf_final=$_pf_out
  fi
  if [ "$_pf_trail" = 1 ] && [ -n "$_pf_out" ]; then
    _pf_final="$_pf_final/"
  fi

  # (4) repo root の除去
  if [ -n "$_pf_root" ]; then
    case "$_pf_final" in
      "$_pf_root"/*) _pf_final=${_pf_final#"$_pf_root"/} ;;
    esac
  fi

  # (5) 小文字化（_ho_key のみ）
  if [ "$_pf_lower" = 1 ]; then
    _pg_fold_tolower "$_pf_final"
    _pf_final=$_PG_FOLD_LOWER
  fi

  _PG_FOLD_OUT=$_pf_final
  return 0
}
# <<< PG-FOLD-PATH END (#1101)
