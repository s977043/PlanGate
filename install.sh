#!/bin/sh
# install.sh — PlanGate を Claude Code / Codex にインストール
#
# Usage:
#   sh install.sh                   # 自動検出してインストール
#   sh install.sh --claude          # Claude Code のみ
#   sh install.sh --codex           # Codex のみ
#   sh install.sh --target DIR      # インストール先を指定
#   sh install.sh --force           # 既存ファイルを強制上書き
#   sh install.sh --uninstall       # アンインストール（manifest から）
#   sh install.sh --version         # インストール済みバージョン表示
#   sh install.sh --dry-run         # 変更内容を確認（実行しない）

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PLUGIN_DIR="$REPO_ROOT/plugin/plangate"
PLUGIN_VERSION="$(command -v python3 >/dev/null 2>&1 && python3 - "$PLUGIN_DIR/.claude-plugin/plugin.json" << 'PYEOF' || echo "unknown"
import json, sys
try:
    with open(sys.argv[1], encoding='utf-8') as f:
        print(json.load(f)['version'])
except Exception:
    print('unknown')
PYEOF
)"
DRY_RUN=0
MODE="auto"
FORCE=0
SHOW_VERSION=0
UNINSTALL=0
TARGET_DIR=""
MANIFEST_NAME="plangate-manifest.json"
# --target が指定された場合は auto モードでも Claude Code のみ対象

_log()  { printf '\033[1;32m[plangate]\033[0m %s\n' "$1"; }
_warn() { printf '\033[1;33m[plangate]\033[0m %s\n' "$1"; }
_skip() { printf '\033[0;90m[plangate]\033[0m skip (exists): %s\n' "$1"; }
_dry()  { printf '\033[1;36m[dry-run] \033[0m %s\n' "$1"; }

# python3 が必要な操作（manifest 生成・読み込み・アンインストール）の前に呼ぶ
_require_python3() {
  command -v python3 >/dev/null 2>&1 || {
    printf '\033[1;31m[plangate]\033[0m Error: python3 is required for this operation\n' >&2
    exit 1
  }
}

while [ $# -gt 0 ]; do
  case "$1" in
    --claude)     MODE="claude"; shift ;;
    --codex)      MODE="codex"; shift ;;
    --target)
      if [ $# -lt 2 ] || [ -z "${2:-}" ]; then
        printf "Error: --target requires a directory argument\n" >&2; exit 1
      fi
      TARGET_DIR="$2"; shift 2 ;;
    --force)      FORCE=1; shift ;;
    --uninstall)  UNINSTALL=1; shift ;;
    --version)    SHOW_VERSION=1; shift ;;
    --dry-run)    DRY_RUN=1; shift ;;
    --help|-h)
      printf 'Usage: sh install.sh [OPTIONS]\n\n'
      printf '  --claude        Claude Code のみインストール\n'
      printf '  --codex         Codex のみインストール\n'
      printf '  --target DIR    インストール先を指定\n'
      printf '  --force         既存ファイルを強制上書き\n'
      printf '  --uninstall     アンインストール\n'
      printf '  --version       インストール済みバージョン表示\n'
      printf '  --dry-run       変更内容を確認（実行しない）\n'
      exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 1 ;;
  esac
done

# バージョン表示
if [ "$SHOW_VERSION" = "1" ]; then
  printf 'PlanGate v%s\n' "$PLUGIN_VERSION"
  DEST="${TARGET_DIR:-$(pwd)/.claude}"
  MANIFEST="$DEST/$MANIFEST_NAME"
  if [ -f "$MANIFEST" ]; then
    _require_python3
    installed=$(python3 - "$MANIFEST" << 'PYEOF'
import json, sys
try:
    with open(sys.argv[1], encoding='utf-8') as f:
        print(json.load(f).get('version', 'unknown'))
except Exception:
    print('unknown')
PYEOF
)
    printf 'Installed: v%s  (manifest: %s)\n' "$installed" "$MANIFEST"
  else
    printf 'Not installed (no manifest found at %s)\n' "$DEST/$MANIFEST_NAME"
  fi
  exit 0
fi

# ===== Claude Code インストール =====
install_claude() {
  DEST="${TARGET_DIR:-$(pwd)/.claude}"
  _log "Claude Code: $PLUGIN_DIR → $DEST (v$PLUGIN_VERSION)"

  installed=0; skipped=0
  for dir in agents skills commands rules; do
    src="$PLUGIN_DIR/$dir"
    dst="$DEST/$dir"
    [ -d "$src" ] || continue
    [ "$DRY_RUN" = "1" ] || mkdir -p "$dst"
    for f in "$src"/*; do
      [ -e "$f" ] || continue
      base="$(basename "$f")"
      if [ "$FORCE" = "0" ] && [ -e "$dst/$base" ]; then
        _skip "$dir/$base"
        skipped=$((skipped + 1))
        continue
      fi
      if [ -L "$f" ]; then
        _warn "SKIP symlink: $dir/$base (symlinks are skipped for security)"
        skipped=$((skipped + 1))
        continue
      fi
      if [ "$DRY_RUN" = "1" ]; then
        _dry "WOULD COPY: $dir/$base"
      else
        cp -r "$f" "$dst/$base"
        installed=$((installed + 1))
      fi
    done
  done

  if [ "$DRY_RUN" = "0" ]; then
    _write_manifest "$DEST"
    _log "完了: installed=$installed, skipped=$skipped (--force で上書き可)"
    _print_caveats "$DEST"
  else
    _log "dry-run 完了（実際の変更なし）"
  fi
}

# アンインストール
uninstall_claude() {
  DEST="${TARGET_DIR:-$(pwd)/.claude}"
  MANIFEST="$DEST/$MANIFEST_NAME"
  if [ ! -f "$MANIFEST" ]; then
    _warn "manifest が見つかりません: $MANIFEST"
    _warn "手動で $DEST/agents/ $DEST/skills/ $DEST/commands/ $DEST/rules/ を確認してください"
    exit 1
  fi
  _require_python3
  python3 - "$MANIFEST" "$DRY_RUN" << 'PYEOF'
import json, os, sys, shutil
manifest_path, dry = sys.argv[1], sys.argv[2] == '1'
with open(manifest_path, encoding='utf-8') as fh:
    d = json.load(fh)
for f in d.get('files', []):
    if os.path.lexists(f):
        if dry:
            print(f'[dry-run]  WOULD DELETE: {f}')
        else:
            if os.path.isdir(f) and not os.path.islink(f):
                shutil.rmtree(f)
            else:
                os.remove(f)
            print(f'[plangate] deleted: {f}')
if not dry:
    os.remove(manifest_path)
    print(f'[plangate] removed manifest: {manifest_path}')
    # 空になった agents/skills/commands/rules ディレクトリを best-effort で除去
    import os.path as _p
    base = _p.dirname(manifest_path)
    for _sub in ('agents', 'skills', 'commands', 'rules'):
        _d = _p.join(base, _sub)
        if os.path.isdir(_d) and not os.listdir(_d):
            try:
                os.rmdir(_d)
                print(f'[plangate] removed empty dir: {_d}')
            except OSError:
                pass
PYEOF
}

# manifest 生成
_write_manifest() {
  dest="$1"
  manifest="$dest/$MANIFEST_NAME"
  _require_python3
  python3 - "$dest" "$PLUGIN_DIR" "$PLUGIN_VERSION" "$manifest" << 'PYEOF'
import json, os, sys
from datetime import datetime, timezone
dest, plugin_dir, version, manifest_path = sys.argv[1:5]
files = []
for d in ['agents', 'skills', 'commands', 'rules']:
    src = os.path.join(plugin_dir, d)
    if not os.path.isdir(src): continue
    for f in os.listdir(src):
        dst_f = os.path.join(dest, d, f)
        if os.path.exists(dst_f):
            files.append(dst_f)
data = {
    'version': version,
    'installed_at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'files': sorted(files),
}
with open(manifest_path, 'w', encoding='utf-8') as fh:
    json.dump(data, fh, indent=2, ensure_ascii=False)
    fh.write('\n')
print(f'[plangate] manifest: {manifest_path} ({len(files)} files)')
PYEOF
}

# インストール後案内（caveats）
_print_caveats() {
  dest="$1"
  [ "${PLANGATE_SETUP_HINT:-1}" = "0" ] && return 0
  printf '\n\033[1;34m━━━ PlanGate v%s インストール完了 ━━━\033[0m\n' "$PLUGIN_VERSION"
  printf '\n\033[1mStep 1\033[0m: Claude Code セッションで確認\n'
  printf '  /subagent-team-design\n'
  printf '\n\033[1mStep 2\033[0m: プラグインパスを settings.json に追加（任意）\n'
  printf '  .claude/settings.json の "plugins" に以下を追記:\n'
  printf '  "%s"\n' "$REPO_ROOT/plugin/plangate"
  printf '\n\033[1mアップデート\033[0m:\n'
  printf '  cd %s && git pull && sh install.sh --force\n' "$REPO_ROOT"
  printf '\n\033[1mアンインストール\033[0m:\n'
  printf '  sh %s/install.sh --uninstall\n' "$REPO_ROOT"
  printf '\033[1;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n\n'
}

# ===== Codex インストール =====
install_codex() {
  CODEX_DIR="${TARGET_DIR:-$(pwd)/.codex/skills}"
  _log "Codex: skills → $CODEX_DIR (v$PLUGIN_VERSION)"
  _codex_force=""
  [ "$FORCE" = "1" ] && _codex_force="--force"
  if [ "$DRY_RUN" = "1" ]; then
    _dry "WOULD RUN: sh $PLUGIN_DIR/scripts/install-plangate-skills.sh --target $CODEX_DIR $_codex_force"
  else
    sh "$PLUGIN_DIR/scripts/install-plangate-skills.sh" --target "$CODEX_DIR" $_codex_force
    _log "Codex インストール完了"
    printf '\n\033[1m確認\033[0m: Codex セッションで $plangate-setup を実行してください\n\n'
  fi
}

# ===== メイン =====
if [ "$UNINSTALL" = "1" ]; then
  uninstall_claude; exit 0
fi

case "$MODE" in
  auto)
    # --target 指定時は Claude Code のみ（Codex の --target は --codex と組み合わせる）
    if [ -n "$TARGET_DIR" ]; then install_claude; exit 0; fi
    HAS_CLAUDE=0; HAS_CODEX=0
    [ -d "$(pwd)/.claude" ] && HAS_CLAUDE=1
    [ -d "$(pwd)/.codex" ]  && HAS_CODEX=1
    if [ "$HAS_CLAUDE" = "0" ] && [ "$HAS_CODEX" = "0" ]; then
      _warn ".claude/ / .codex/ が見つかりません"
      printf '  sh install.sh --claude   # Claude Code\n'
      printf '  sh install.sh --codex    # Codex\n'
      exit 1
    fi
    [ "$HAS_CLAUDE" = "1" ] && install_claude
    [ "$HAS_CODEX"  = "1" ] && install_codex
    ;;
  claude) install_claude ;;
  codex)  install_codex ;;
esac
