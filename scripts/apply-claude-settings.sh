#!/bin/sh
# apply-claude-settings.sh — settings wiring 契約 適用（TASK-0080 S1a / V-3 CR-1）
#
# `.claude/settings.json` を wiring 契約に整合させる。**ユーザーが実行**
# （AI は self-mod ガードで .claude/settings.json を編集不可）。
# `.claude/settings.example.json` の hooks ブロックを **冪等 merge** し、
# EH-3 の PLANGATE_HOOK_FILE 引数を保証する。
# 冪等・backup&restore・適用後に契約検証し未適用残があれば非0（誤認防止）。
#
# merge の性質（#928 AC-1 前提 / #914 doctor ブロッカー解消）:
#   - **不足のみ取り込む**: example にあって settings.json に無い hook を追加
#   - **削除しない**: settings.json 固有の hook（ローカル追加）は保持する
#     （mass-delete guard の思想と一貫）
#   - **同定キー**: (event, matcher, hook が起動するスクリプトパス)。
#     引数は同定に含めない（EH-3 の引数差分は二重追加でなく後段の引数付与で解消）
#   - **matcher 解釈は `scripts/check-settings-wiring.sh` の `has()` と一致
#     させること**。片方だけが `""` / `"*"` を全ツールとみなすと、apply は
#     「配線済み」と判断し検証は「不足」と言い続けて**永久に収束しない**
#     （#928 MJ-1）。両者を同時に変更する
#   - **全 hook event が対象**: settings.json 不在時に example を丸ごと cp する
#     既存分岐と対称にする（PreToolUse だけだと PostToolUse/Stop/SessionStart の
#     新規 hook が既存ユーザーにだけ配線されない非対称が残る）
#
# ⚠️ 適用範囲と副作用（敵対レビュー F3 / 契約範囲外の自動配線）:
#   本スクリプトは example の **全 hook event** を取り込む。一方
#   `check-settings-wiring.sh` が検証するのは **PreToolUse の 6 項目のみ**で
#   あり、それ以外（SessionStart / PostToolUse / Stop）は**契約外**である。
#   契約外 hook には副作用の大きいものが含まれうる（例: SessionStart の
#   `scripts/gh-pin-account.sh` は `gh auth switch` によりマシン全体の gh CLI
#   active account を書き換える）。また「削除しない」方針の裏返しとして、
#   **ユーザーが意図的に削除した hook は再実行のたびに復活する**（opt-out 手段は
#   現状なし。`--all-events` opt-in 化は follow-up）。
#
# ⚠️ 既知の制約:
#   - **matcher が example より狭い場合は重複ブロックが生じる**（F2(a)）。
#     例: settings.json 側 `"Edit"` / example 側 `"Edit|Write"` → 包含関係が
#     成立しないため example ブロックを追加し、Edit で同一 hook が 2 回発火する。
#     「不足ツールだけ既存ブロックへ足す」設計が要るため follow-up 扱い。
#   - **`.claude/settings.local.json` は参照しない**（F6）。そちらに EH-3 等を
#     配線している環境では本スクリプトが二重配線を検知できない（契約検証側も
#     settings.json のみを見るため同様）。
#
#   sh scripts/apply-claude-settings.sh [--dry-run]
set -eu
usage() {
  printf 'usage: sh scripts/apply-claude-settings.sh [--dry-run]\n'
}
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SJ="$ROOT/.claude/settings.json"
EX="$ROOT/.claude/settings.example.json"
# 未知引数を黙って本適用にしない（`--dryrun` / `-n` の打ち間違い対策 / F5）
DRY=0
case "${1:-}" in
  "") ;;
  --dry-run) DRY=1 ;;
  *) printf 'error: unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
esac
if [ "$#" -gt 1 ]; then
  printf 'error: too many arguments\n' >&2; usage >&2; exit 2
fi
[ -f "$EX" ] || { printf 'error: %s not found\n' "$EX" >&2; exit 2; }

BAK=""
if [ ! -f "$SJ" ]; then
  printf '[apply] .claude/settings.json 不在 → settings.example.json をコピー\n'
  [ "$DRY" -eq 1 ] || cp "$EX" "$SJ"
  [ "$DRY" -eq 1 ] && { printf '[apply] --dry-run: コピーせず\n'; exit 0; }
else
  [ "$DRY" -eq 1 ] && printf '[apply] --dry-run: 構造マージ内容のみ確認\n'
  # backup 名は mktemp で一意化する。`$(date +%s)` だと契約 FAIL → 即再実行
  # （最も自然な操作）で同一秒に同名 backup へ **適用後の内容** が cp され、
  # 適用前 pristine が失われて巻き戻せなくなる。
  if [ "$DRY" -eq 0 ]; then
    BAK=$(mktemp "$SJ.bak.XXXXXX")
    cp "$SJ" "$BAK"
  fi
  # rc は `|| rc=$?` で捕捉する。`if ! python3 ...; then rc=$?` は `!` 反転後の
  # 0 を拾ってしまい、無効 JSON 等の失敗時に exit 0（fail-open）になる。
  rc=0
  python3 - "$SJ" "$EX" "$DRY" <<'PY' || rc=$?
import copy, json, os, re, sys
SJ, EX, DRY = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
# symlink（dotfiles 管理）を実体へ解決してから書く。解決しないと os.replace が
# リンクを実ファイルへ置換し、リンク先は旧内容のまま取り残される。
SJ = os.path.realpath(SJ)
try:
    doc = json.load(open(SJ))
except Exception as e:
    print(f"[apply] FAIL: {SJ} 無効 JSON: {e}", file=sys.stderr); sys.exit(2)
try:
    ex = json.load(open(EX))
except Exception as e:
    print(f"[apply] FAIL: {EX} 無効 JSON: {e}", file=sys.stderr); sys.exit(2)
if not isinstance(doc, dict):
    print(f"[apply] FAIL: {SJ} の最上位が object でない", file=sys.stderr); sys.exit(2)
changed = []

# ── hook 同定キー ─────────────────────────────────────────────────
# command から「起動するスクリプトパス」を取り出す。引数はキーに含めない
# （EH-3 の `${PLANGATE_HOOK_FILE:-}` 有無で別 hook と誤判定し二重配線するのを
# 防ぐ。引数差分は後段 2) で解消する）。
#
# 正規化は「同じファイルを指すと断定できる表記ゆれ」だけに限定する:
#   - **二重引用符**の有無（`sh "${X}/a.sh"` と `sh ${X}/a.sh` は同じパス）
#   - `${VAR}` / `$VAR` の brace 有無（同一変数なので同じパス）
#   - 先頭の `./`
# **単一引用符は剥がさない**。`sh '${X}/a.sh'` はシェルが変数を展開せず
# literal パスを起動しようとして `No such file or directory` になる別物で、
# 同一視すると「配線済み」と誤判定したまま hook が起動しない状態を作る。
# **変数名も保持する**。`$SOMEVAR/scripts/hooks/x.sh` と
# `${CLAUDE_PROJECT_DIR}/scripts/hooks/x.sh` は別ファイルを指しうる。
# いずれも誤同一視すると必要な hook が入らないまま、契約検証は部分文字列
# grep なので PASS してしまう（Shadow Config）。
_BRACED_VAR = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}")
_SCRIPT = re.compile(r"\S+\.(?:sh|py)\b")


def _script_paths(cmd):
    out = []
    for tok in _SCRIPT.findall(cmd or ""):
        tok = tok.strip('"')
        tok = _BRACED_VAR.sub(r"$\1", tok)
        while tok.startswith("./"):
            tok = tok[2:]
        if tok:
            out.append(tok)
    return tuple(out)


def hook_key(h):
    if not isinstance(h, dict):
        return ("<invalid>", json.dumps(h, sort_keys=True))
    cmd = h.get("command", "") or ""
    scripts = _script_paths(cmd)
    # スクリプト起動でない hook（インラインコマンド等）は正規化した command で同定
    return (h.get("type"), scripts or re.sub(r"\s+", " ", cmd.strip()))


UNIVERSAL = "<all-tools>"


def matcher_tokens(m):
    """matcher をツール集合として解釈する。
    - `""`（matcher 省略）/ `"*"` は **全ツール**（UNIVERSAL）
    - `Edit|Write` のような単純な alternation は集合
    - それ以外（正規表現メタ文字を含む）は None ＝文字列一致でのみ同一視"""
    m = (m or "").strip()
    if m in ("", "*"):
        return UNIVERSAL
    parts = [p.strip() for p in m.split("|")]
    if parts and all(re.fullmatch(r"[A-Za-z0-9_]+", p) for p in parts):
        return frozenset(parts)
    return None


def matcher_covers(existing, wanted):
    """settings.json 側 matcher が example 側 matcher を包含するか。
    包含していれば example 側ブロックを追加しない（＝同じ hook が同じツールで
    2 回発火する二重配線を防ぐ）。
    - `Edit|Write|MultiEdit`（ローカル拡張）⊇ `Edit|Write`
    - `""` / `"*"`（全ツール）は任意の matcher を包含する"""
    if existing == wanted:
        return True
    et, wt = matcher_tokens(existing), matcher_tokens(wanted)
    if et is UNIVERSAL:
        return True
    if et is None or wt is None or wt is UNIVERSAL:
        return False
    return wt <= et


def hook_label(h):
    if not isinstance(h, dict):
        return "<invalid hook>"
    sp = _script_paths(h.get("command", "") or "")
    return sp[0].rsplit("/", 1)[-1] if sp else re.sub(
        r"\s+", " ", (h.get("command", "") or "").strip())[:60]


# 1) settings.example.json の hooks から「不足しているものだけ」を取り込む
hooks = doc.setdefault("hooks", {})
ex_hooks = ex.get("hooks", {}) or {}
if not isinstance(hooks, dict):
    print(f"[apply] FAIL: {SJ} の hooks が object でない", file=sys.stderr); sys.exit(2)
if not isinstance(ex_hooks, dict):
    print(f"[apply] FAIL: {EX} の hooks が object でない", file=sys.stderr); sys.exit(2)

for event, ex_blocks in ex_hooks.items():
    if not isinstance(ex_blocks, list):
        print(f"[apply] WARN: {EX} hooks.{event} が配列でない → skip", file=sys.stderr)
        continue
    cur = hooks.setdefault(event, [])
    if not isinstance(cur, list):
        print(f"[apply] WARN: {SJ} hooks.{event} が配列でない → skip", file=sys.stderr)
        continue
    seen = []
    for blk in cur:
        if not isinstance(blk, dict):
            continue
        m = blk.get("matcher") or ""
        for h in blk.get("hooks", []) or []:
            seen.append((m, hook_key(h)))

    def present(matcher, key):
        return any(k == key and matcher_covers(m, matcher) for m, k in seen)

    for blk in ex_blocks:
        if not isinstance(blk, dict):
            continue
        m = blk.get("matcher") or ""
        missing = [h for h in (blk.get("hooks", []) or [])
                   if not present(m, hook_key(h))]
        if not missing:
            continue
        newblk = {k: copy.deepcopy(v) for k, v in blk.items() if k != "hooks"}
        newblk["hooks"] = copy.deepcopy(missing)
        cur.append(newblk)
        for h in missing:
            seen.append((m, hook_key(h)))
            changed.append(f"{event}[{m or '*'}] {hook_label(h)}")

# 2) EH-3: check-plan-hash.sh の command に ${PLANGATE_HOOK_FILE:-} を付与
#    （1) で取り込んだブロックも含め、最終状態で必ず引数が載る）
for blk in hooks.get("PreToolUse", []) or []:
    if not isinstance(blk, dict):
        continue
    for h in blk.get("hooks", []) or []:
        if not isinstance(h, dict):
            continue
        c = h.get("command", "") or ""
        if "check-plan-hash.sh" not in c or "${PLANGATE_HOOK_FILE:-}" in c:
            continue
        if "${PLANGATE_HOOK_TASK:-}" in c:
            h["command"] = c.replace(
                "${PLANGATE_HOOK_TASK:-}",
                "${PLANGATE_HOOK_TASK:-} ${PLANGATE_HOOK_FILE:-}", 1)
        else:
            # 位置引数契約は $1=task_id / $2=target_file
            # （scripts/hooks/check-plan-hash.sh:
            #   task_id=${PLANGATE_HOOK_TASK:-${1:-}} /
            #   target_file=${PLANGATE_HOOK_FILE:-${2:-}}）。
            # example と同形になるよう TASK→FILE の順で 2 つ足す。
            #
            # 効果の範囲（誇張しないための注記 / 実測済み）:
            #   **空引数を保持する runner**（引用符付き展開・手動実行）でのみ
            #   位置が保たれる。FILE だけを足した形ではファイルパスが $1＝
            #   task_id 扱いになり `error: invalid task_id` → exit 2。
            #   一方 `sh -c` 経路では未引用 `${VAR:-}` の空展開が語ごと消える
            #   ため、**TASK 未設定 + FILE 設定**のケースは付与の有無に関わらず
            #   $1 に FILE が入り同じ結果になる（= example の配線自体が持つ
            #   性質）。emit の quote 化は settings.example.json（HO 対象）の
            #   同時変更を要するため follow-up（#975）。
            # なお契約検証は部分文字列 grep なのでこの破壊を検知できない。
            h["command"] = (c.rstrip()
                            + " ${PLANGATE_HOOK_TASK:-} ${PLANGATE_HOOK_FILE:-}")
        changed.append("EH-3 PLANGATE_HOOK_FILE")

if DRY:
    if changed:
        print(f"[apply] --dry-run 適用予定: {changed}")
    else:
        print("[apply] --dry-run 適用予定なし（settings.example.json 由来の"
              "取り込み差分なし）")
    sys.exit(0)
if changed:
    json.dumps(doc)  # 妥当性
    # 非原子的書き込みを避ける: truncate 直後に中断すると壊れた JSON が残り、
    # 次回実行が「無効 JSON」で止まる。tmp へ書いて os.replace で差し替える。
    tmp = SJ + ".tmp"
    with open(tmp, "w") as f:
        json.dump(doc, f, ensure_ascii=False, indent=2)
        f.write("\n")
    # mode を引き継ぐ（引き継がないと 0600 が umask 由来の 0644 へ拡大し、
    # settings.json が持ちうる秘匿値の可視範囲が広がる）
    os.chmod(tmp, os.stat(SJ).st_mode & 0o7777)
    os.replace(tmp, SJ)
    print(f"[apply] 適用: {changed}")
else:
    # 「変更なし」は「契約準拠」ではない（後段の wiring 検証が判定する）
    print("[apply] 変更なし（settings.example.json 由来の取り込み差分なし）")
sys.exit(0)
PY
  if [ "$rc" -ne 0 ]; then
    if [ "$DRY" -eq 0 ] && [ -f "$BAK" ]; then
      cp "$BAK" "$SJ"; printf '[apply] エラー→ %s から復元\n' "$BAK" >&2
    fi
    exit "$rc"
  fi
  # backup はここでは消さない。後段の契約検証が PASS するまで残す
  # （検証 FAIL で exit 1 する経路でも巻き戻せるようにする / F4）。
fi

[ "$DRY" -eq 1 ] && exit 0
# 適用後に契約検証（未適用残があれば非0＝「適用済み誤認」防止 / V-3 CR-1）
if sh "$ROOT/scripts/check-settings-wiring.sh" --target user >/dev/null 2>&1; then
  if [ -n "$BAK" ] && [ -f "$BAK" ]; then
    rm -f "$BAK"
  fi
  printf '[apply] done: settings wiring 契約準拠を確認\n'; exit 0
fi
printf '[apply] FAIL: 適用後も契約未準拠が残存（手動確認が必要）\n' >&2
if [ -n "$BAK" ] && [ -f "$BAK" ]; then
  printf '[apply] 適用前の backup を残しました: %s\n' "$BAK" >&2
fi
sh "$ROOT/scripts/check-settings-wiring.sh" --target user 2>&1 | sed 's/^/  /' >&2
exit 1
