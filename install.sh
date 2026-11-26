#!/bin/sh
# install.sh — PlanGate を Claude Code / Codex にインストール
#
# Usage:
#   sh install.sh                   # 自動検出してインストール
#   sh install.sh --claude          # Claude Code のみ
#   sh install.sh --codex           # Codex のみ
#   sh install.sh --target DIR      # インストール先を指定
#   sh install.sh --force           # 管理済み・未編集ファイルを更新
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
      printf '  --force         管理済み・未編集ファイルを更新\n'
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
  MANIFEST="$DEST/plangate-owned-v2.json"
  [ -f "$MANIFEST" ] || MANIFEST="$DEST/$MANIFEST_NAME"
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

# Claude direct-install ownership is tracked per regular file. Legacy manifests
# cannot prove ownership and are deliberately left untouched.
_claude_files() {
  _require_python3
  python3 - "$1" "${TARGET_DIR:-$(pwd)/.claude}" "$PLUGIN_DIR" "$PLUGIN_VERSION" "$DRY_RUN" "$FORCE" <<'PYEOF'
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import stat
import sys
import tempfile
from datetime import datetime, timezone

operation, target, source, version, dry, force = sys.argv[1:]
dry, force = dry == '1', force == '1'
root = Path(os.path.abspath(target))
src = Path(source)
manifest = root / 'plangate-owned-v2.json'
legacy = root / 'plangate-manifest.json'
allowed = {'agents', 'skills', 'commands', 'rules'}

def fail(message):
    print('[plangate] ERROR: ' + message, file=sys.stderr)
    sys.exit(1)

def safe_rel(value):
    if not isinstance(value, str) or not value or '\\' in value:
        return False
    p = PurePosixPath(value)
    return (not p.is_absolute() and len(p.parts) >= 2 and p.parts[0] in allowed
            and all(x not in ('', '.', '..') for x in value.split('/')))

def no_symlinks(path, include_leaf=True):
    # Also inspect ancestors of the target itself, without resolving symlinks.
    parts = path.parts if include_leaf else path.parts[:-1]
    p = Path(parts[0])
    for part in parts[1:]:
        p = p / part
        if p.is_symlink():
            return False
    return True

def digest(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()

def receipt(path):
    st = os.lstat(path)
    if not stat.S_ISREG(st.st_mode):
        raise ValueError('not a regular file')
    return {'sha256': digest(path), 'dev': st.st_dev, 'ino': st.st_ino,
            'ctime_ns': st.st_ctime_ns, 'mode': stat.S_IMODE(st.st_mode)}

def matches(path, expected):
    try:
        return no_symlinks(path) and receipt(path) == expected
    except (OSError, ValueError):
        return False

def read_records():
    if not no_symlinks(manifest):
        fail('symlink in manifest path')
    if not manifest.exists():
        return {}
    try:
        data = json.loads(manifest.read_text(encoding='utf-8'))
        if not isinstance(data, dict) or data.get('format') != 2 or not isinstance(data.get('files'), dict):
            raise ValueError('unsupported manifest format')
        files = data['files']
        for name, checksum in files.items():
            if (not safe_rel(name) or not isinstance(checksum, dict) or set(checksum) != {'sha256', 'dev', 'ino', 'ctime_ns', 'mode'} or not isinstance(checksum['sha256'], str) or len(checksum['sha256']) != 64 or any(c not in '0123456789abcdef' for c in checksum['sha256']) or any(type(checksum[k]) is not int or checksum[k] < 0 for k in ('dev', 'ino', 'ctime_ns', 'mode'))):
                raise ValueError('invalid manifest entry')
        return files
    except (OSError, ValueError, TypeError) as exc:
        fail('invalid ownership manifest: ' + str(exc))

def save(files):
    data = {'format': 2, 'version': version,
            'updated_at': datetime.now(timezone.utc).isoformat(), 'files': files}
    fd, tmp = tempfile.mkstemp(prefix='.plangate-owned-', dir=root)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as out:
            json.dump(data, out, ensure_ascii=False, indent=2, sort_keys=True)
            out.write('\n')
        os.replace(tmp, manifest)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)

if not no_symlinks(root):
    fail('symlink in target path')
records = read_records()
if legacy.exists() or legacy.is_symlink():
    print('[plangate] legacy manifest retained; do not use an older installer to uninstall')

if operation == 'install':
    # A missing file loses ownership as soon as its absence is observed.
    for rel in list(records):
        dest = root / rel
        if no_symlinks(dest) and not os.path.lexists(dest):
            if not dry:
                del records[rel]
                save(records)
    # No destination writes occur in dry-run, including directory creation.
    for category in sorted(allowed):
        base = src / category
        if base.is_symlink() or not base.is_dir():
            continue
        for folder, dirs, files in os.walk(base, followlinks=False):
            dirs[:] = sorted(d for d in dirs if not (Path(folder) / d).is_symlink())
            for name in sorted(files):
                origin = Path(folder) / name
                if origin.is_symlink() or not origin.is_file():
                    continue
                rel = origin.relative_to(src).as_posix()
                dest = root / rel
                if not no_symlinks(dest):
                    print('[plangate] protected symlink: ' + rel)
                    continue
                present = os.path.lexists(dest)
                if present:
                    if not (force and rel in records and matches(dest, records[rel])):
                        print('[plangate] protected existing: ' + rel)
                        continue
                    # Avoid overwriting anything changed by the user.
                    print(('[dry-run] WOULD UPDATE: ' if dry else '[plangate] update: ') + rel)
                    if not dry:
                        fd, tmp = tempfile.mkstemp(prefix='.plangate-copy-', dir=dest.parent)
                        try:
                            with open(origin, 'rb') as inp, os.fdopen(fd, 'wb') as out:
                                shutil.copyfileobj(inp, out)
                            shutil.copymode(origin, tmp)
                            if not matches(dest, records[rel]):
                                fail('file changed during update: ' + rel)
                            # A failure before saving the new receipt leaves it unowned.
                            os.replace(tmp, dest)
                            records[rel] = receipt(dest)
                            save(records)
                        finally:
                            if os.path.exists(tmp):
                                os.unlink(tmp)
                    continue
                print(('[dry-run] WOULD COPY: ' if dry else '[plangate] copy: ') + rel)
                if not dry:
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    # Exclusive creation prevents claiming an existing file.
                    with open(origin, 'rb') as inp, open(dest, 'xb') as out:
                        shutil.copyfileobj(inp, out)
                    shutil.copymode(origin, dest)
                    records[rel] = receipt(dest)
                    save(records)
elif operation == 'uninstall':
    if not manifest.exists():
        print('[plangate] no verified ownership manifest; all files retained')
        sys.exit(0)
    for rel, expected in sorted(records.items()):
        dest = root / rel
        if no_symlinks(dest) and not os.path.lexists(dest):
            print('[plangate] missing; ownership expired: ' + rel)
            if not dry:
                del records[rel]
                save(records)
            continue
        if not matches(dest, expected):
            print('[plangate] retained (modified or unsafe): ' + rel)
            continue
        print(('[dry-run] WOULD DELETE: ' if dry else '[plangate] deleted: ') + rel)
        if not dry:
            # Forget ownership before unlinking; a failure leaves an unowned file.
            del records[rel]
            save(records)
            os.unlink(dest)
    # Retain the manifest and directories, including records for modified files.
else:
    fail('unknown operation')
PYEOF
}

install_claude() {
  _log "Claude Code: $PLUGIN_DIR → ${TARGET_DIR:-$(pwd)/.claude} (v$PLUGIN_VERSION)"
  _claude_files install
}

uninstall_claude() {
  _claude_files uninstall
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
