#!/bin/sh
# check-plan-hash.sh — Hook EH-3: plan_hash 改竄検知
#
# approvals/c3.json の plan_hash と現 plan.md の SHA-256 を突合。
# 不一致なら C-3 承認後に plan が改変されたことを示す → 違反。
#
# Usage:
#   sh scripts/hooks/check-plan-hash.sh <TASK-XXXX>
#   PLANGATE_HOOK_TASK=TASK-XXXX sh scripts/hooks/check-plan-hash.sh
#
# Modes:
#   default                       warning（exit 0）
#   PLANGATE_HOOK_STRICT=1        違反時 exit 1（block）
#   PLANGATE_BYPASS_HOOK=1        常時 exit 0
#
# 監査: docs/working/_audit/hook-events.log
#
# Issue #169 / TASK-0056

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
WORKING_DIR="$REPO_ROOT/docs/working"
AUDIT_LOG="$WORKING_DIR/_audit/hook-events.log"

log_event() {
  level=$1
  msg=$2
  mkdir -p "$(dirname "$AUDIT_LOG")"
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  printf '%s\t%s\tcheck-plan-hash\t%s\t%s\n' "$ts" "$level" "${task_id:-${PLANGATE_HOOK_TASK:--}}" "$msg" >>"$AUDIT_LOG"
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

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
#   (4) 小文字化（_ho_key のみ / $3=1）
#   (5) repo root の除去（小文字化済み同士で比較 = 大小文字非依存）
#   ※ (2) を (3) より後ろに置くと `.//CLAUDE.md` が素通りする。
#   ※ (5) を (4) より前に置くと **root 前置部だけ大文字にした絶対パス**
#     （`/USERS/.../CLAUDE.md`）が素通りする。macOS の case-insensitive FS では
#     同一実体に到達し**書き込みが成立する**（PR 前レビューで検出）。
#
# 制約:
#   - 単語分割に依存しない（zsh で no-op になるため / R-002）
#   - 外部コマンドを呼ばない（fork 増加ゼロ / AC-11）。呼び出し側も
#     コマンド置換を使わず、結果はグローバル変数で受け取ること
#   - 先頭 `/` は除去しない（絶対パスを block しない / N-1・TC-11b）
#   - 末尾 `/` は保持する（`CLAUDE.md/` は FS 到達不能なので skip 側のまま）
#   - シンボリックリンクは解決しない（Non-goal）
#   - fail-closed は 4 条件: (a) 畳み込み後に先頭 .. が残る / (b) セグメント数
#     > 256 / (c) 全体長 > 4096 (PATH_MAX 上限) / (d) セグメント長 > 255
#     (NAME_MAX)。(c)(d) は #1101 Step 7 の実測（長い大文字パスで小文字化が
#     非線形に悪化し、timeout の無い EH-3 がハングする）を受けた追加であり、
#     plan v4 の 2 条件からの**逸脱**（status.md 計画からの変更点 #9 に記録）。
_PG_FOLD_MAXSEG=256
# NAME_MAX（macOS / Linux とも 255）。これを超えるセグメントは FS 上の
# ファイル名になりえないため、block しても正当な書き込みを妨げない。
_PG_FOLD_MAXNAME=255
# PATH_MAX の上限（Linux 4096 / macOS 1024）。同上。
_PG_FOLD_MAXLEN=4096

_pg_fold_tolower() {
  _pl_all=$1
  case "$_pl_all" in
    *[ABCDEFGHIJKLMNOPQRSTUVWXYZ]*) ;;
    *) _PG_FOLD_LOWER=$_pl_all; return 0 ;;
  esac
  # 1 文字ループは入力長 n に対して O(n^2)（`${v#?}` と `${v%"$rest"}` が毎回
  # 全長を走査する）。パス全体を一度に回すと長い大文字パスで実行時間が跳ね上がる
  # ため、**`/` セグメント単位に分割して回す**（出力は分割しない場合と byte 一致）。
  # 上限そのものは _PG_FOLD_MAXNAME / _PG_FOLD_MAXLEN が fail-closed で切る。
  # 背景: #1101 Step 7（EH-3 に timeout が無いため暴走は block ではなくハングになる）。
  _pl_acc=''
  while : ; do
    case "$_pl_all" in
      */*) _pl_in=${_pl_all%%/*}; _pl_all=${_pl_all#*/}; _pl_sep='/' ;;
      *) _pl_in=$_pl_all; _pl_all=''; _pl_sep='' ;;
    esac
    case "$_pl_in" in
      *[ABCDEFGHIJKLMNOPQRSTUVWXYZ]*)
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
        ;;
      *) _pl_out=$_pl_in ;;
    esac
    _pl_acc=$_pl_acc$_pl_out$_pl_sep
    if [ -z "$_pl_sep" ]; then
      break
    fi
  done
  _PG_FOLD_LOWER=$_pl_acc
}

_pg_fold_path() {
  _pf_in=${1:-}
  _pf_root=${2:-}
  _pf_lower=${3:-0}
  _PG_FOLD_OUT=''
  _PG_FOLD_RC=0
  _PG_FOLD_REASON=''

  # fail-closed (c): 入力長が上限（PATH_MAX 上限）を超える（#1101 Step 7）。
  # 上限判定を「セグメント数」だけに置くと `1 セグメント x 20,000 文字` が
  # 素通りし、小文字化ループだけが非線形に回る。EH-3 に timeout は無いので
  # これは block ではなく**ハング**になる＝可用性の穴。長さでも切る。
  if [ ${#_pf_in} -gt "$_PG_FOLD_MAXLEN" ]; then
    _PG_FOLD_RC=1
    _PG_FOLD_REASON="path length exceeded (>$_PG_FOLD_MAXLEN)"
    _PG_FOLD_OUT=$_pf_in
    return 0
  fi

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
    # fail-closed (d): セグメント長が NAME_MAX を超える（#1101 Step 7）。
    # 小文字化のコストはセグメント長の 2 乗で効くため、ここで切らないと
    # 全体長の上限 (c) だけでは worst case が数十秒に達する。
    if [ ${#_pf_seg} -gt "$_PG_FOLD_MAXNAME" ]; then
      _PG_FOLD_RC=1
      _PG_FOLD_REASON="segment length exceeded (>$_PG_FOLD_MAXNAME)"
      _PG_FOLD_OUT=$_pf_in
      return 0
    fi
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

  # (4) 小文字化（_ho_key のみ）— **repo root 除去より先**に行う。
  #     root 前置部だけ大文字にした絶対パス（macOS の case-insensitive FS では
  #     同一実体に到達し書き込みが成立する）で (5) をすり抜けられるため。
  #     root 側も同じ写像を通してから比較する＝ root 除去が大小文字非依存になる。
  if [ "$_pf_lower" = 1 ]; then
    _pg_fold_tolower "$_pf_final"
    _pf_final=$_PG_FOLD_LOWER
    if [ -n "$_pf_root" ]; then
      _pg_fold_tolower "$_pf_root"
      _pf_root=$_PG_FOLD_LOWER
    fi
  fi

  # (5) repo root の除去（$3=1 のときは小文字化済み同士の比較）
  if [ -n "$_pf_root" ]; then
    case "$_pf_final" in
      "$_pf_root"/*) _pf_final=${_pf_final#"$_pf_root"/} ;;
    esac
  fi

  _PG_FOLD_OUT=$_pf_final
  return 0
}
# <<< PG-FOLD-PATH END (#1101)

# bypass
if [ "${PLANGATE_BYPASS_HOOK:-0}" = "1" ]; then
  log_event "BYPASS" "PLANGATE_BYPASS_HOOK=1 set"
  printf '[Hook EH-3] BYPASS\n'
  exit 0
fi

# TASK / 対象ファイル resolution
# codebase 慣行（check-forbidden-files.sh）に合わせ env → 位置引数の順。
task_id=${PLANGATE_HOOK_TASK:-${1:-}}
target_file=${PLANGATE_HOOK_FILE:-${2:-}}

# PreToolUse hook では Claude Code が stdin に JSON（tool_input.file_path）を
# 渡す。env / 引数で未指定なら stdin JSON から対象パスを補完する（最終手段）。
if [ -z "$target_file" ] && [ ! -t 0 ]; then
  _stdin=$(cat 2>/dev/null || true)
  if [ -n "$_stdin" ]; then
    # V-3/Gemini 指摘: sed の貪欲マッチは「最後の "file_path"」を拾い、
    # 偽プロパティ注入で plan.md 判定を回避され得る。jq で正規パス
    # (.tool_input.file_path) を優先抽出し、無ければ「最初に出現する」
    # file_path を grep -o（非貪欲・出現順）で取得する。
    if command -v jq >/dev/null 2>&1; then
      target_file=$(printf '%s' "$_stdin" \
        | jq -r '.tool_input.file_path // .file_path // empty' 2>/dev/null \
        | head -1)
    fi
    if [ -z "$target_file" ]; then
      target_file=$(printf '%s' "$_stdin" \
        | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
        | head -1 \
        | sed 's/.*"\([^"]*\)"$/\1/')
    fi
  fi
fi

# ===== EH-3b: Bash レーンの明示 no-op（#1104 / PR #1267 の実測是正）=====
# `.claude/settings.example.json` は PreToolUse matcher "Bash" にも本 hook を
# 配線しているが、Bash の PreToolUse payload が持つのは tool_input.command で
# あり tool_input.file_path ではない。したがって上の抽出は必ず空になり、
# 以降は「対象パス不明」のまま進むため、実測では次の 3 点だけが起きる:
#   - HO 判定は 1 度も一致しない（#1104 が塞ごうとした穴は塞がっていない）
#   - no-task セッションでは SKIP_REASON 未設定として **全 Bash が exit 2**
#   - SKIP_REASON を設定すると Bash 1 回ごとに skip-decision-log へ未追認
#     エントリが増え check-skip-acknowledged.sh が FAIL する
# 「防御を足さずに摩擦だけ足す」状態を避けるため、Bash レーンで対象パスが
# 与えられていない場合は **明示的に何もしない**。
# Bash コマンド文字列からの書き込み先抽出（= #1104 本来の意図）は未実装で
# あり、**#1104 は open のまま**（既知の残存ギャップ）。詳細と残存脅威モデル:
#   docs/working/_reports/1104-bash-lane-noop-patch-applicable.md
# 適用範囲は **「対象パス未指定」かつ「TASK 文脈なし」の Bash payload のみ**:
#   - PLANGATE_HOOK_FILE / $2 で対象が明示されていれば従来どおり HO / plan.md 判定
#   - PLANGATE_HOOK_TASK が設定されていれば従来どおり plan_hash 突合を行う
#     （plan_hash 検証は target_file を必要としないため、Bash レーンでも有効）
# jq 不在時は本分岐を発火させない（誤って判定を緩めないための安全側）。
if [ -z "$target_file" ] && [ -z "$task_id" ] && [ -n "${_stdin:-}" ] && command -v jq >/dev/null 2>&1; then
  _tool_name=$(printf '%s' "$_stdin" | jq -r '.tool_name // empty' 2>/dev/null || true)
  if [ "${_tool_name:-}" = "Bash" ]; then
    reason="Bash lane without target path: EH-3 does not parse Bash commands (#1104 open)"
    log_event "BASH_LANE_NOOP" "$reason"
    printf '[Hook EH-3 BASH_LANE_NOOP] %s\n' "$reason"
    exit 0
  fi
fi

# ===== Hardening Override 判定（#1089 / TASK-1089）=====
# TASK 文脈（PLANGATE_HOOK_TASK / $1）の有無に依存せず評価する。TASK-0106 では
# 本判定が no-task 分岐の内側にあったため、TASK 設定時は plan_hash 検証パスへ
# 抜けて 9 カテゴリすべてが一度も評価されなかった（#1089）。
# 判定内容・9 カテゴリ・「maintenance 窓内でも常時 block」は不変（R-003/R-015）。
# 優先順は BYPASS > Override > (no-task: maintenance/doc-light/SKIP_REASON,
# task: plan_hash 検証)。
# (i) target_file 正規化（R-028）
_norm_target="${target_file:-}"
case "$_norm_target" in
  ./*) _norm_target="${_norm_target#./}" ;;
esac
case "$_norm_target" in
  "$REPO_ROOT"/*) _norm_target="${_norm_target#$REPO_ROOT/}" ;;
esac

# (i-b) HO 判定専用キー _ho_key の導出（#1101 / TASK-1101）
# 表記揺れ（./ 前置 / // / /./ / .. 往復 / repo root 跨ぎ / 大小文字 / 末尾空白
# とその複合）で HO を迂回できないようにする。**_norm_target は書き換えない**
# ＝下流 3 経路（maintenance allowed_paths の fnmatchcase / c3.json conversation
# 判定 / doc-light 拡張子）が大小文字に感応して共有しているため（R-001）。
_pg_fold_path "${target_file:-}" "$REPO_ROOT" 1
_ho_key=$_PG_FOLD_OUT
if [ "$_PG_FOLD_RC" != "0" ]; then
  # fail-closed: (a) 畳み込み後に先頭 .. が残る / (b) セグメント数 > 256 /
  # (c) 全体長 > 4096 (PATH_MAX 上限) / (d) セグメント長 > 255 (NAME_MAX)。
  # (a) は cwd 次第で repo 内 HO に到達しうる。(b)(c)(d) は EH-3 に timeout が
  # 無く暴走が block ではなく**ハング**になるため上限で切って block へ倒す。
  # AC-8 は (a)(b) の 2 条件のみを規定しており、(c)(d) は #1101 Step 7 の実測
  # （長い大文字パスで小文字化が非線形に悪化）を受けた**逸脱**。ただし (c)(d)
  # に該当するパスは PATH_MAX / NAME_MAX を超えており FS 上のファイルを
  # 指しえないため、正当な書き込みを止めることはない。
  reason="HARDENING_OVERRIDE: ${target_file:-} は正規化できない (fail-closed: ${_PG_FOLD_REASON})"
  log_event "HARDENING_OVERRIDE" "$reason"
  printf '[Hook EH-3] %s\n' "$reason" >&2
  exit 2
fi

# (ii) Hardening Override 物理先頭判定（R-003/R-015、maintenance より上）
# 判定対象は _ho_key（小文字化済み）。したがって case は**小文字側で受ける**。
# ラベル 9 行 / パターン 15 個。9 カテゴリの正本は
# .claude/rules/mode-classification.md の Hardening Override 節（内容は不変）。
_override=0
case "$_ho_key" in
  .claude/rules/*.md) _override=1 ;;
  .claude/settings.json|.claude/settings.local.json|.claude/settings.example.json) _override=1 ;;
  .claude/commands/*.md|.claude/commands/*/*.md) _override=1 ;;
  .claude/agents/*.md|.claude/agents/*/*.md) _override=1 ;;
  scripts/hooks/*.sh) _override=1 ;;
  bin/plangate) _override=1 ;;
  schemas/*.schema.json) _override=1 ;;
  .github/workflows/*.yml|.github/workflows/*.yaml) _override=1 ;;
  agents.md|claude.md) _override=1 ;;
esac
if [ "$_override" = "1" ]; then
  # AC-9: 監査ログと reason には**生の要求パス**を残す（正規化後の値ではない）。
  reason="HARDENING_OVERRIDE: ${target_file:-} は maintenance 窓内でも常時 block (R-003/R-015)"
  log_event "HARDENING_OVERRIDE" "$reason"
  printf '[Hook EH-3] %s\n' "$reason" >&2
  exit 2
fi

# P4(d) ファイルパス感応型ガード（TASK-0070 / C-3 F1-b 採用 / Gemini レビュー）:
#   - TASK 文脈なし & 対象が plan.md → BLOCK（C-3 承認後の plan 改変を
#     TASK 文脈を消して通す攻撃を阻止。Gemini 相談 Case 1）
#   - TASK 文脈なし & plan.md 以外 → SKIP（汎用 Edit/Write を許可。
#     check-forbidden-files.sh と同じ「no task→skip」慣行。Case 2）
#   - PLANGATE_HOOK_STRICT=1 は従来どおり no-task を一律 block（後方互換）
if [ -z "$task_id" ]; then
  # 正規化（V-3/Gemini 指摘）: 末尾空白除去 + 小文字化で plan.md 判定回避を防ぐ
  #   - macOS は既定で大文字小文字非区別 → PLAN.md で OS 上は plan.md 改変可能
  #   - "plan.md "（末尾空白）等の表記揺れも plan.md として扱う
  _tf_lc=$(printf '%s' "$target_file" | sed 's/[[:space:]]*$//' | tr 'A-Z' 'a-z')
  case "$_tf_lc" in
    */plan.md|plan.md)
      reason="plan.md edited without TASK context (EH-3 bypass guard): $target_file"
      log_event "VIOLATION" "$reason"
      printf '[Hook EH-3] BLOCK: plan.md edited without TASK context.\n' >&2
      printf '  target: %s\n' "$target_file" >&2
      printf '  Set PLANGATE_HOOK_TASK=TASK-XXXX to allow plan.md edits.\n' >&2
      exit 2
      ;;
  esac
  if [ "${PLANGATE_HOOK_STRICT:-0}" = "1" ]; then
    printf 'Usage: %s <TASK-XXXX>  (or set PLANGATE_HOOK_TASK)\n' "$0" >&2
    exit 2
  fi

  # ===== TASK-0106: メンテモード v2（承認ファイル方式 + 多層 + Override 物理先頭）=====
  # 判定順序 (R-020):
  #   (i)   target_file 正規化（./ 除去等・R-028）        ← #1089 で task_id 分岐の前へ移動
  #   (ii)  Hardening Override 物理先頭判定（R-003/R-015） ← #1089 で task_id 分岐の前へ移動
  #   (iii) maintenance ファイル valid 判定（v1=30分窓、v2=allowed_paths/one_shot/consumed_at）
  #   (iv)  allowed_paths スコープ判定（指定なし=Override 対象以外を許可、後方互換）
  #   (v)   flock(LOCK_EX|LOCK_NB) → 再 open(path) で inode 比較 → consumed_at 未消費なら os.replace（R-002/R-017/R-027/R-031）
  # 優先順 BYPASS(上記) > Override(block) > maintenance(SKIP) > 通常(SKIP_REASON)。
  # env では maintenance 有効化しない（承認ファイルのみ=AI自己付与不可・R-011）。
  # (i)(ii) は本分岐に入る前に評価済み（#1089）。_norm_target はそこで確定する。

  # [TASK-0144] C-3 conversation mode: c3.json auto-generate path
  # approvals/c3.json + conversation mode -> SKIP (通す。中身検証は EH-2 と AI 生成コードに委ねる)
  case "$_norm_target" in
    docs/working/TASK-*/approvals/c3.json)
      _cfg_yml="$REPO_ROOT/.plangate.yml"
      _c3mode="cli"
      if [ -f "$_cfg_yml" ]; then
        _c3mode=$(python3 - "$_cfg_yml" 2>/dev/null <<'PYC3'
import sys
cfg_path = sys.argv[1]
try:
    import yaml
    with open(cfg_path, "r", encoding="utf-8") as f:
        d = yaml.safe_load(f)
    if not isinstance(d, dict):
        print("cli"); sys.exit(0)
    m = (d.get("c3_approval") or {}).get("mode", "cli")
    print(m if m in ("cli", "conversation") else "cli")
except Exception:
    print("cli")
PYC3
) || _c3mode="cli"
      fi
      if [ "$_c3mode" = "conversation" ]; then
        _dlog_c3="$WORKING_DIR/_audit/skip-decision-log.jsonl"
        mkdir -p "$(dirname "$_dlog_c3")"
        _ts_c3=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
        _esc_c3=$(printf '%s' "${_norm_target:-unknown}" | tr -d $'\n\r\t')
        printf '{"ts":"%s","event":"EH-3_C3_CONVERSATION_SKIP","target":"%s","acknowledged_by":null,"acknowledged_at":null}\n' "$_ts_c3" "$_esc_c3" >>"$_dlog_c3"
        reason="C3_CONVERSATION_SKIP: c3.json target (${_norm_target:-unknown}) -- conversation mode, auto-allowed"
        log_event "C3_CONVERSATION_SKIP" "$reason"
        printf '[Hook EH-3 C3_CONVERSATION_SKIP] %s\n' "$reason"
        exit 0
      fi
      ;;
  esac

  # (iii)-(v) maintenance valid + scope + one-shot atomic consume
  _maint="$REPO_ROOT/docs/working/_maintenance/maintenance.json"
  # [TASK-0138] doc-light path: auto-SKIP for non-HO .md files
  # maintenance ファイルが存在する場合は token ライフサイクル（one-shot 消費等）を優先し
  # doc-light は発火させない。no-maint 時のみ非 HO .md を記録付き自動 SKIP。
  if [ ! -f "$_maint" ]; then
    _dl_ext=$(printf '%s' "$_norm_target" | sed 's/.*\.//; y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/')
    if [ "$_dl_ext" = "md" ]; then
      _dlog_dl="$WORKING_DIR/_audit/skip-decision-log.jsonl"
      mkdir -p "$(dirname "$_dlog_dl")"
      _ts_dl=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
      _esc_dl=$(printf '%s' "${_norm_target:-unknown}" | tr -d '\n\r\t')
      printf '{"ts":"%s","event":"EH-3_DOC_LIGHT_SKIP","target":"%s","acknowledged_by":null,"acknowledged_at":null}\n' "$_ts_dl" "$_esc_dl" >>"$_dlog_dl"
      reason="DOC_LIGHT_SKIP: non-HO .md target (${_norm_target:-unknown}) -- auto-skipped"
      log_event "DOC_LIGHT_SKIP" "$reason"
      printf '[Hook EH-3 DOC_LIGHT_SKIP] %s\n' "$reason"
      exit 0
    fi
  fi
  if [ -f "$_maint" ]; then
    _mresult=$(MAINT_FILE="$_maint" NORM_TARGET="$_norm_target" python3 - <<'PYM' 2>/dev/null || true
import json, os, sys, time, fnmatch
import fcntl
maint_path = os.environ["MAINT_FILE"]
norm_target = os.environ["NORM_TARGET"]
try:
    with open(maint_path, "r") as f:
        d = json.load(f)
    ga = int(d["until"]); gat = int(d["granted_at"]); now = int(time.time())
    base_ok = (str(d.get("approved_by","")).strip()!="" and
               str(d.get("reason","")).strip()!="" and
               gat<=now and ga>now and 0<ga-gat<=1800)
    if not base_ok:
        print("INVALID|base validation failed"); sys.exit(0)
    allowed = d.get("allowed_paths")
    if allowed is not None:
        if not isinstance(allowed, list):
            print("INVALID|allowed_paths not array"); sys.exit(0)
        matched = any(fnmatch.fnmatchcase(norm_target, pat) for pat in allowed)
        if not matched:
            print(f"OUT_OF_SCOPE|target={norm_target} not in allowed_paths={allowed}")
            sys.exit(0)
    one_shot = bool(d.get("one_shot", False))
    if not one_shot:
        print(f"VALID|legacy 30min window (one_shot=false), target={norm_target}")
        sys.exit(0)
    if d.get("consumed_at") is not None:
        print(f"CONSUMED|one_shot already consumed at {d.get('consumed_at')}")
        sys.exit(0)
    try:
        with open(maint_path, "r+") as lock_fp:
            try:
                fcntl.flock(lock_fp.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                print("RACE_LOCK|flock LOCK_NB failed (concurrent hook), fail-closed")
                sys.exit(0)
            try:
                lock_ino = os.fstat(lock_fp.fileno()).st_ino
                path_ino = os.stat(maint_path).st_ino
            except FileNotFoundError:
                print("RACE_DELETE|target removed during lock, fail-closed")
                sys.exit(0)
            if lock_ino != path_ino:
                print(f"RACE_INODE|fd ino={lock_ino} != path ino={path_ino}, fail-closed (R-031)")
                sys.exit(0)
            lock_fp.seek(0)
            d2 = json.load(lock_fp)
            if d2.get("consumed_at") is not None:
                print(f"RACE_CONSUMED|re-read after lock: already consumed by other")
                sys.exit(0)
            d2["consumed_at"] = now
            tmp = maint_path + ".tmp"
            with open(tmp, "w") as wf:
                json.dump(d2, wf, ensure_ascii=False, indent=2)
            os.replace(tmp, maint_path)
            print(f"VALID|one_shot consumed (consumed_at={now}), target={norm_target}")
            sys.exit(0)
    except Exception as e:
        print(f"ERROR|{e}")
        sys.exit(0)
except Exception as e:
    print(f"INVALID|{e}")
PYM
)
    case "$_mresult" in
      VALID*)
        reason="MAINTENANCE_SKIP: non-plan ${_norm_target:-unknown} ($_mresult)"
        log_event "MAINTENANCE_SKIP" "$reason"
        printf '[Hook EH-3 SKIP] %s\n' "$reason"
        exit 0
        ;;
      *)
        log_event "MAINTENANCE_BLOCK" "fail-closed: $_mresult"
        ;;
    esac
  fi

  # ===== SKIP_REASON 例外申請（空/空白のみなら SKIP せず停止）=====
  # 本ブロックは no-task 経路（task_id 空）。SKIP_REASON 源は env のみ
  # （todo.md は TASK 文脈前提＝ここでは解決不能。V-3 MJ-2: 死に分岐を除去）。
  # V-3 MJ-1: 前後空白を除去し「空白のみ」を実質空として拒否。
  _skipr=$(printf '%s' "${PLANGATE_SKIP_REASON:-}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  if [ -z "$_skipr" ]; then
    log_event "SKIP_BLOCKED" "no task_id non-plan SKIP but SKIP_REASON empty — refusing to skip (set PLANGATE_SKIP_REASON)"
    printf '[Hook EH-3] SKIP 拒否: SKIP_REASON 未設定。\n' >&2
    printf '  PLANGATE_SKIP_REASON=... を設定するか、メンテ承認ファイルを人間が発行してください。\n' >&2
    exit 2
  fi
  # decision-log.jsonl に reason を append（人間が後で acknowledged_by 追記→CI が未追記を fail）
  _dlog="$WORKING_DIR/_audit/skip-decision-log.jsonl"
  mkdir -p "$(dirname "$_dlog")"
  _ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  _esc_r=$(printf '%s' "$_skipr" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n\r\t')
  _esc_f=$(printf '%s' "${target_file:-unknown}" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n\r\t')
  printf '{"ts":"%s","event":"EH-3_SKIP","target":"%s","skip_reason":"%s","acknowledged_by":null,"acknowledged_at":null}\n' "$_ts" "$_esc_f" "$_esc_r" >>"$_dlog"
  reason="no task_id; non-plan target (${target_file:-unknown}) — skipped (SKIP_REASON 記録済・要人間追認)"
  log_event "SKIP" "$reason"
  printf '[Hook EH-3 SKIP] %s\n' "$reason"
  exit 0
fi

case "$task_id" in
  TASK-*) ;;
  *)
    printf 'error: invalid task_id: %s\n' "$task_id" >&2
    exit 2
    ;;
esac

plan_file="$WORKING_DIR/$task_id/plan.md"
c3_file="$WORKING_DIR/$task_id/approvals/c3.json"

if [ ! -f "$plan_file" ]; then
  reason="plan.md not found: $plan_file"
  log_event "SKIP" "$reason"
  printf '[Hook EH-3 SKIP] %s\n' "$reason"
  exit 0
fi

if [ ! -f "$c3_file" ]; then
  reason="c3.json not found: $c3_file (no approval to compare against)"
  log_event "SKIP" "$reason"
  printf '[Hook EH-3 SKIP] %s\n' "$reason"
  exit 0
fi

# c3.json から plan_hash を抽出（strict JSON / #282 TASK-0105）。
# 寛容 sed 抽出は不正 JSON の c3.json でも plan_hash を拾い承認判定の
# 入力健全性を損なうため、scripts/plan_hash_util.recorded_plan_hash と
# 意味一致の strict 解析へ。不正/欠落/非 object/prefix 不一致は空（=SKIP）。
# python3 は本フック :108 で既出依存（新規依存追加なし）。
recorded_hash=$(python3 - "$c3_file" <<'PHX' 2>/dev/null || echo ""
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print(""); raise SystemExit(0)
if not isinstance(d, dict):
    print(""); raise SystemExit(0)
v = d.get("plan_hash", "")
print(v[7:] if isinstance(v, str) and v.startswith("sha256:") else "")
PHX
)

if [ -z "$recorded_hash" ]; then
  reason="plan_hash not found in c3.json"
  log_event "SKIP" "$reason"
  printf '[Hook EH-3 SKIP] %s\n' "$reason"
  exit 0
fi

current_hash=$(sha256_of "$plan_file")

if [ "$recorded_hash" = "$current_hash" ]; then
  log_event "PASS" "plan_hash matches"
  printf '[Hook EH-3 PASS] plan_hash matches current plan.md\n'
  exit 0
fi

reason="plan_hash mismatch: recorded=$recorded_hash, current=$current_hash"
log_event "VIOLATION" "$reason"

if [ "${PLANGATE_HOOK_STRICT:-0}" = "1" ]; then
  printf '[Hook EH-3 BLOCK] plan.md was modified after C-3 approval.\n' >&2
  printf '  Recorded: sha256:%s\n' "$recorded_hash" >&2
  printf '  Current : sha256:%s\n' "$current_hash" >&2
  printf '  Action  : Re-approval required (update c3.json plan_hash) or revert plan.md.\n' >&2
  exit 1
fi

printf '[Hook EH-3 WARNING] plan_hash mismatch (plan.md modified post-C-3)\n' >&2
printf '  Recorded: sha256:%s\n' "$recorded_hash" >&2
printf '  Current : sha256:%s\n' "$current_hash" >&2
exit 0
