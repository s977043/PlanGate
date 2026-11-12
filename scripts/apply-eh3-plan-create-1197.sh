#!/bin/sh
# apply-eh3-plan-create-1197.sh — #1197 案 B の HO 適用スクリプト（本スクリプト自体は非 HO）
#
# 対象: scripts/hooks/check-plan-hash.sh（Hardening Override。**適用は Human-owned**）
# patch: docs/working/_reports/1197-eh3-plan-create-patch.md の PG-PATCH block
# 型: .claude/skills/ho-apply-script/SKILL.md
#
# Usage:
#   sh scripts/apply-eh3-plan-create-1197.sh              # dry-run（既定。書き込みなし）
#   sh scripts/apply-eh3-plan-create-1197.sh --apply      # hook へ適用し pending flag を削除 → 検証
#   sh scripts/apply-eh3-plan-create-1197.sh --verify     # 適用後の述語だけを測る
#   sh scripts/apply-eh3-plan-create-1197.sh --rollback   # hook を戻し pending flag を復元
#
#   PLANGATE_APPLY_REPO=<path>  対象 repo を差し替える（使い捨て clone での検証用）
#
# commit も push もしない。--apply / --verify が通ったら、feature ブランチで
# hook と flag 削除を commit して PR にする（他の apply スクリプトと連結実行しない）。
# --verify は hook の挙動を **実 repo で** 測る（ho-apply-script 落とし穴 7）。
#
# Exit: 0 = 成功 / 1 = ABORT（理由を stderr に出す）

set -eu

REPO="${PLANGATE_APPLY_REPO:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
DOC="docs/working/_reports/1197-eh3-plan-create-patch.md"
TARGET="scripts/hooks/check-plan-hash.sh"
FLAG="tests/fixtures/eh3-plan-create-pending-1197.flag"
MARKER="PLAN_CREATE_ALLOW"
MODE=dry-run
case "${1:-}" in
  "" | --dry-run) MODE=dry-run ;;
  --apply) MODE=apply ;;
  --verify) MODE=verify ;;
  --rollback) MODE=rollback ;;
  *) printf 'ABORT: unknown argument: %s\n' "${1}" >&2; exit 1 ;;
esac

T="$(mktemp -d)"
trap 'rm -rf "${T}"' EXIT
die() { printf 'ABORT: %s\n' "$*" >&2; exit 1; }
ok() { printf '  ok  %s\n' "$1"; }

cd "${REPO}" || die "repo に入れない: ${REPO}"

# ── 前提 ──────────────────────────────────────────────────────────
br=$(git rev-parse --abbrev-ref HEAD)
case "${br}" in
  HEAD | main | master | release/*) die "feature ブランチで実行すること（現在: ${br}）" ;;
esac
git fetch -q origin || die "origin の fetch に失敗"
git merge-base --is-ancestor origin/main HEAD || die "origin/main から分岐していない（現在: ${br}）"
dirty=$(git status --porcelain \
  | grep -vF -- 'docs/working/_audit/skip-decision-log.jsonl' \
  | grep -vF -- "${TARGET}" \
  | grep -vF -- "${FLAG}" || true)
[ -z "${dirty}" ] || { printf '%s\n' "${dirty}" >&2; die "未コミットの変更がある"; }
[ -f "${DOC}" ] || die "patch 文書が無い: ${DOC}"
[ -f "${TARGET}" ] || die "対象が無い: ${TARGET}"

# ── 抽出（awk）────────────────────────────────────────────────────
awk 'BEGIN{q=sprintf("%c",96)}
     /^<!-- PG-PATCH-BEGIN -->$/{b=1;next}
     /^<!-- PG-PATCH-END -->$/{exit}
     b && substr($0,1,1)==q{f=!f;next}
     f' "${DOC}" >"${T}/p.patch"
[ -s "${T}/p.patch" ] || die "patch 抽出が空: ${DOC}"
head -1 "${T}/p.patch" | grep -qF -- 'diff --git a/scripts/hooks/check-plan-hash.sh ' \
  || die "抽出結果が対象 hook の unified diff で始まっていない"

state=none
if git apply --check "${T}/p.patch" 2>/dev/null; then
  state=unapplied
elif git apply --check -R "${T}/p.patch" 2>/dev/null; then
  state=applied
fi

# ── 述語（--apply の後と --verify で共通）──────────────────────────
verify() {
  grep -qF -- "${MARKER}" "${TARGET}" || die "marker が無い（未適用）: ${MARKER}"
  [ ! -e "${FLAG}" ] || die "pending flag が残っている: ${FLAG}（--apply で削除される）"
  sh -n "${TARGET}" || die "hook が構文エラー"
  # 前提 assert: 実 repo で HO block が効いていること（効いていなければ検証環境の問題）
  _in='{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"bin/plangate"}}'
  _rc=0
  printf '%s' "${_in}" | env -u PLANGATE_HOOK_TASK -u PLANGATE_HOOK_FILE -u PLANGATE_BYPASS_HOOK -u PLANGATE_HOOK_STRICT \
    PLANGATE_SKIP_REASON=apply-1197-verify sh "${TARGET}" >"${T}/ho.out" 2>&1 || _rc=$?
  if [ "${_rc}" != "2" ]; then
    printf 'probe stdin: %s\n' "${_in}" >&2
    printf 'probe rc=%s out: %s\n' "${_rc}" "$(head -2 "${T}/ho.out" | tr '\n' ' ')" >&2
    printf "再現: printf '%%s' '%s' | PLANGATE_SKIP_REASON=x sh %s; echo \$?\n" "${_in}" "${TARGET}" >&2
    die "実 repo の HO probe が rc=2 にならない（patch ではなく検証環境の問題の可能性）"
  fi
  ok "HO probe rc=2"
  for _t in ta-119-eh3-plan-create ta-79-eh3-bash-lane ta-80 ta-65 ta-39; do
    _f=$(ls tests/extras/"${_t}"*.sh 2>/dev/null | head -1 || true)
    [ -n "${_f}" ] || die "テストが見つからない: ${_t}"
    _rc=0
    sh "${_f}" >"${T}/t.out" 2>&1 || _rc=$?
    if [ "${_rc}" != "0" ] || grep -qF -- '[FAIL]' "${T}/t.out"; then
      grep -F -- '[FAIL]' "${T}/t.out" | head -10 >&2 || true
      printf '再現: sh %s\n' "${_f}" >&2
      die "${_f} に FAIL（rc=${_rc}）"
    fi
    ok "${_f} (rc=0, FAIL なし)"
  done
}

case "${MODE}" in
  dry-run)
    printf 'mode=dry-run state=%s branch=%s\n' "${state}" "${br}"
    [ "${state}" != none ] || die "fwd も rev も当たらない（patch が stale か、対象が既に変更されている）"
    if [ "${state}" = unapplied ]; then
      git apply -v --check "${T}/p.patch" 2>&1 | grep -F -- 'offset' && die "offset が出る（別位置に当たる恐れ）" || true
      ok "patch は offset なしで適用可能（書き込みなし）"
    else
      ok "既に適用済み"
    fi
    ;;
  apply)
    case "${state}" in
      unapplied)
        git apply -v --check "${T}/p.patch" 2>&1 | grep -F -- 'offset' && die "offset が出る（別位置に当たる恐れ）" || true
        git apply "${T}/p.patch" || die "適用に失敗"
        ok "patch を適用"
        ;;
      applied) printf '既に適用済みです。検証だけ行います。\n' ;;
      *) die "fwd も rev も当たらない（patch が stale か、対象が既に変更されている）" ;;
    esac
    if [ -e "${FLAG}" ]; then
      rm -f -- "${FLAG}"
      ok "pending flag を削除: ${FLAG}"
    fi
    verify
    printf '完了。feature ブランチで %s と %s の削除を commit してください（push / merge はしない）。\n' "${TARGET}" "${FLAG}"
    ;;
  verify)
    [ "${state}" = applied ] || die "patch が適用状態ではない（state=${state}）"
    verify
    ;;
  rollback)
    if [ "${state}" = applied ]; then
      git apply -R "${T}/p.patch" || die "reverse-apply に失敗"
      ok "patch を取り消し"
    elif [ "${state}" = unapplied ]; then
      printf '未適用です。hook は変更しません。\n'
    else
      die "rev も当たらない（対象が手編集されている）"
    fi
    if [ ! -e "${FLAG}" ] && git cat-file -e "HEAD:${FLAG}" 2>/dev/null; then
      git show "HEAD:${FLAG}" >"${FLAG}"
      ok "pending flag を HEAD から復元: ${FLAG}"
    fi
    _left=$(git status --porcelain -- "${TARGET}" "${FLAG}")
    [ -z "${_left}" ] || { printf '%s\n' "${_left}" >&2; die "rollback 後に差分が残る"; }
    ok "対象と flag の差分 0 行"
    ;;
esac
