#!/bin/sh
# scripts/add-slsa-attestation.sh — SLSA provenance workflow を追加（OpenSSF Scorecard 対応）
#
# .github/workflows/ は Hardening Override 対象のため AI が本スクリプトを生成し、
# --apply は Human が実行する（docs/ai/responsibility-classes.md AI/Human 分界）。
#
# 使い方:
#   sh scripts/add-slsa-attestation.sh --dry-run   # 差分確認（変更なし）
#   sh scripts/add-slsa-attestation.sh --apply     # 適用（冪等）
set -eu
MODE="${1:---dry-run}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="$ROOT/.github/workflows/slsa-attestation.yml"

# 冪等性チェック
if [ -f "$TARGET" ]; then
  printf 'SKIP (already applied): %s は既に存在します\n' "$TARGET"
  exit 0
fi

CONTENT='name: SLSA Provenance

# リリース公開時に SLSA build provenance を生成し release asset に添付する。
# Scorecard CII-Best-Practices / SLSA チェック対応。
on:
  release:
    types: [published]

permissions: {}

jobs:
  provenance:
    permissions:
      id-token: write      # SLSA signing (OIDC token)
      contents: write      # release asset upload
      attestations: write  # GitHub Attestations API
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0 # v7
        with:
          ref: ${{ github.event.release.tag_name }}

      - name: Create release archive
        run: |
          tag="${{ github.event.release.tag_name }}"
          git archive --format=tar.gz \
            --prefix="plangate-${tag}/" \
            HEAD \
            -o "plangate-${tag}.tar.gz"
          echo "ARCHIVE=plangate-${tag}.tar.gz" >> "$GITHUB_ENV"

      - name: Generate SLSA provenance attestation
        uses: actions/attest-build-provenance@e8d4baa0b41c87f71bb46de40f28fe2e2aaee96f # v2.4.0
        with:
          subject-path: ${{ env.ARCHIVE }}

      - name: Upload archive to release
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release upload "${{ github.event.release.tag_name }}" \
            "${{ env.ARCHIVE }}" --clobber
'

if [ "$MODE" = "--dry-run" ]; then
  printf '[dry-run] 以下のファイルを新規作成します:\n  %s\n\n' "$TARGET"
  printf '%s\n' "$CONTENT"
  exit 0
elif [ "$MODE" = "--apply" ]; then
  printf '%s' "$CONTENT" > "$TARGET"
  printf 'APPLIED: %s を作成しました\n' "$TARGET"
  printf '次のステップ:\n'
  printf '  git add .github/workflows/slsa-attestation.yml\n'
  printf '  git commit -m "feat(security): SLSA provenance attestation workflow 追加"\n'
else
  printf 'usage: %s [--dry-run|--apply]\n' "$0" >&2
  exit 1
fi
