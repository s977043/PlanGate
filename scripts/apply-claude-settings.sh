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
#   - **全 hook event が対象**: settings.json 不在時に example を丸ごと cp する
#     既存分岐と対称にする（PreToolUse だけだと PostToolUse/Stop/SessionStart の
#     新規 hook が既存ユーザーにだけ配線されない非対称が残る）
#
#   sh scripts/apply-claude-settings.sh [--dry-run]
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SJ="$ROOT/.claude/settings.json"
EX="$ROOT/.claude/settings.example.json"
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
[ -f "$EX" ] || { printf 'error: %s not found\n' "$EX" >&2; exit 2; }

if [ ! -f "$SJ" ]; then
  printf '[apply] .claude/settings.json 不在 → settings.example.json をコピー\n'
  [ "$DRY" -eq 1 ] || cp "$EX" "$SJ"
  [ "$DRY" -eq 1 ] && { printf '[apply] --dry-run: コピーせず\n'; exit 0; }
else
  [ "$DRY" -eq 1 ] && printf '[apply] --dry-run: 構造マージ内容のみ確認\n'
  BAK="$SJ.bak.$(date +%s)"
  [ "$DRY" -eq 1 ] || cp "$SJ" "$BAK"
  # rc は `|| rc=$?` で捕捉する。`if ! python3 ...; then rc=$?` は `!` 反転後の
  # 0 を拾ってしまい、無効 JSON 等の失敗時に exit 0（fail-open）になる。
  rc=0
  python3 - "$SJ" "$EX" "$DRY" <<'PY' || rc=$?
import copy, json, re, sys
SJ, EX, DRY = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
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
# command から「起動するスクリプトパス」を取り出す。`${CLAUDE_PROJECT_DIR}`
# 等の変数展開を除去して比較するため、変数名の差異では二重追加されない。
# 引数はキーに含めない（EH-3 の `${PLANGATE_HOOK_FILE:-}` 有無で別 hook と
# 誤判定し二重配線するのを防ぐ。引数差分は後段 2) で解消する）。
_VAR = re.compile(r"\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*")
_SCRIPT = re.compile(r"\S+\.(?:sh|py)\b")


def _script_paths(cmd):
    out = []
    for tok in _SCRIPT.findall(cmd or ""):
        tok = _VAR.sub("", tok).lstrip("/")
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


def matcher_tokens(m):
    """`Edit|Write` のような単純な alternation を集合に分解する。
    正規表現メタ文字を含む matcher は None（＝文字列一致でのみ同一視）。"""
    parts = [p.strip() for p in (m or "").split("|")]
    if all(re.fullmatch(r"[A-Za-z0-9_]*", p) for p in parts):
        return frozenset(parts)
    return None


def matcher_covers(existing, wanted):
    """settings.json 側 matcher が example 側 matcher を包含するか。
    `Edit|Write|MultiEdit`（ローカルで拡張）が `Edit|Write` を包含するケースで
    二重配線（同じ hook が同じツールで 2 回発火）するのを防ぐ。"""
    if existing == wanted:
        return True
    et, wt = matcher_tokens(existing), matcher_tokens(wanted)
    return et is not None and wt is not None and wt <= et


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
            h["command"] = c.rstrip() + " ${PLANGATE_HOOK_FILE:-}"
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
    with open(SJ, "w") as f:
        json.dump(doc, f, ensure_ascii=False, indent=2)
        f.write("\n")
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
  [ "$DRY" -eq 0 ] && [ -f "$BAK" ] && rm -f "$BAK"
fi

[ "$DRY" -eq 1 ] && exit 0
# 適用後に契約検証（未適用残があれば非0＝「適用済み誤認」防止 / V-3 CR-1）
if sh "$ROOT/scripts/check-settings-wiring.sh" --target user >/dev/null 2>&1; then
  printf '[apply] done: settings wiring 契約準拠を確認\n'; exit 0
fi
printf '[apply] FAIL: 適用後も契約未準拠が残存（手動確認が必要）\n' >&2
sh "$ROOT/scripts/check-settings-wiring.sh" --target user 2>&1 | sed 's/^/  /' >&2
exit 1
