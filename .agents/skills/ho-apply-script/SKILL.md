---
name: ho-apply-script
description: "Hardening Override 対象パスへの patch を Human が安全に適用するための、検証つきスクリプトを組み立てる。Use when: .github/workflows/** / scripts/hooks/** / .claude/settings*.json など AI が編集できないパスの変更を Human に渡す時、apply-*.sh を新規に書く時。"
---

# HO Apply Script

Hardening Override（HO）対象パスは **AI が編集できない**。AI は patch と「検証つき適用
スクリプト」までを用意し、**実行は Human** が行う（責務 4 分類の Human-owned）。

本 skill は**そのスクリプトの型**を定める。毎回ゼロから書くと同じバグを踏むため。

## When to use

- HO 対象パス（正本: [`mode-classification.md`](../../../.claude/rules/mode-classification.md) の
  「承認境界周辺の変更」の 12 カテゴリ）を変更する patch を Human に渡すとき
- `scripts/apply-*.sh` を新規に書くとき

## When not to use

- 非 HO パスの変更（AI が直接編集して PR にすればよい）
- patch を作ること自体（それは patch 文書側の仕事。本 skill は**適用の型**）

## Inputs

| 入力 | 例 |
| --- | --- |
| patch 文書のパス | `docs/working/_reports/1288-ci-layer2-and-push-lane-patch.md` |
| marker 名 | `PG-PATCH-BEGIN` / `PG-PATCH-END` |
| 対象ファイル | `.github/workflows/sync-plugin-plangate.yml` |
| 適用後に成立すべき述語 | 「層 2 の検査が清浄なツリーで空」「`ta-71` が 27/0」 |

## Outputs

`apply`（既定）/ `--verify` / `--rollback` の 3 モードを持つ POSIX sh スクリプト 1 本。
**commit も push もしない。**

## Procedure

### 1. 骨格

```sh
#!/bin/sh
set -eu
REPO="${PLANGATE_APPLY_REPO:-/absolute/path/to/repo}"   # 検証用に上書き可能にする
DOC="docs/working/_reports/<name>.md"
TARGET=".github/workflows/<name>.yml"
MODE="${1:-apply}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
die() { printf 'ABORT: %s\n' "$*" >&2; exit 1; }
ok()  { printf '  ok  %s\n' "$1"; }
cd "$REPO" || die "repo に入れない: $REPO"
```

### 2. 前提の確認

```sh
br=$(git rev-parse --abbrev-ref HEAD)
[ "$br" = "main" ] || die "branch が main でない（現在: $br）"

# 未コミット変更。**対象ファイル自身は除外する**（下記の落とし穴 2）
dirty=$(git status --porcelain \
  | grep -v 'docs/working/_audit/skip-decision-log.jsonl' \
  | grep -vF -- "$TARGET" || true)
[ -z "$dirty" ] || { printf '%s\n' "$dirty" >&2; die "未コミットの変更がある"; }

[ -f "$DOC" ] || die "patch 文書が無い: $DOC（PR が未マージの可能性）"
```

### 3. 抽出（**awk 方式**。落とし穴 3）

```sh
awk 'BEGIN{q=sprintf("%c",96)}
     /^<!-- PG-PATCH-BEGIN -->$/{b=1;next}
     /^<!-- PG-PATCH-END -->$/{exit}
     b && substr($0,1,1)==q{f=!f;next}
     f' "$DOC" > "$T/p.patch"
[ -s "$T/p.patch" ] || die "patch 抽出が空: $DOC"
head -1 "$T/p.patch" | grep -q '^diff --git ' \
  || die "抽出結果が unified diff で始まっていない"
```

### 4. 適用（**fwd と rev の両方**を見る。落とし穴 5）

```sh
if git apply --check "$T/p.patch" 2>/dev/null; then
  git apply "$T/p.patch" || die "適用に失敗"
elif git apply --check -R "$T/p.patch" 2>/dev/null; then
  printf '既に適用済みです。検証だけ行います。\n'
else
  die "fwd も rev も当たらない（patch が stale か、対象が既に変更されている）"
fi
```

### 5. 検証

**marker の存在確認だけで終えない。** 「適用後に成立すべき述語」を実際に測る。

```sh
grep -qF -- "$MARKER" "$TARGET" || die "marker が無い: $MARKER"   # -- 必須（落とし穴 1）
python3 -c "import yaml,sys; yaml.safe_load(open('$TARGET'))" || die "YAML として読めない"
_out=$(sh tests/extras/ta-NN.sh 2>&1 || true)
printf '%s\n' "$_out" | grep -q '\[FAIL\]' && { printf '%s\n' "$_out" | tail -20 >&2; die "ta-NN に FAIL"; }
```

### 6. rollback

```sh
git apply --check -R "$T/p.patch" 2>/dev/null || die "reverse-apply できない"
git apply -R "$T/p.patch" || die "reverse-apply に失敗"
```

## 落とし穴（すべて実際に踏んだもの）

| # | 落とし穴 | 症状 | 対処 |
| --- | --- | --- | --- |
| 1 | `grep -qF "- '...'"` | BSD grep が `- '...'` を**オプションと解釈**し `usage:` を吐いて検証が落ちる | **`grep -qF -- "$pat"`** |
| 2 | dirty ガードで対象ファイルを除外していない | 適用後は対象が必ず `M` になるので、**再実行と `--rollback` が自分のガードで止まる** | `grep -vF -- "$TARGET"` で除外。想定外の手編集は `--check` が fwd/rev とも通らないことで捕まる |
| 3 | marker 抽出が `sed -e '1d' -e '$d'` の 2 回がけ | markdown formatter が**fence 長を正規化し marker 前後に空行を入れる**ため 2 行余る | fence 長・空行に依存しない **awk** |
| 4 | `grep -c ... \|\| printf '0'` | 0 件のとき `0\n0` の**二重出力** → `[: integer expression expected` | `\|\| true` で受ける |
| 5 | `git apply --check` を fwd だけ見る | **rc=0 でも適用可能とは限らない**。同じ形の並びが複数あると `offset` で別位置に当たり、配線が 2 重になる（実例あり） | fwd / rev の**両方**を測り、`git apply -v` で `offset` を確認する |

## Checklist

適用スクリプトを Human に渡す前に:

- [ ] **複製環境で 4 モードすべてを実走**（`apply` / 再実行（冪等）/ `--verify` / `--rollback`）
- [ ] `--rollback` 後に `git status --porcelain -- <target>` が **0 行**
- [ ] `grep` に `--` が付いている
- [ ] dirty ガードが対象ファイル自身を除外している
- [ ] 検証が marker の存在だけでなく**述語**（テスト・パース・実挙動）を測っている
- [ ] **commit も push もしない**
- [ ] `PLANGATE_APPLY_REPO` 等で repo パスを上書きでき、複製で dry-run できる

## Quality bar

**「`--check` が rc=0 だった」は検証ではない。** 複製環境で実際に適用し、適用後の述語が
成立することと、`--rollback` で差分 0 に戻ることを実測してから渡す。

## Example prompt

> `docs/working/_reports/1288-ci-layer2-and-push-lane-patch.md` の `PG-PATCH` を
> `.github/workflows/sync-plugin-plangate.yml` へ適用するスクリプトを、
> `ho-apply-script` の型で作って。検証は「層 2 の述語が清浄なツリーで空」と
> 「`ta-71` が 27/0」。複製で 4 モード実走してから渡すこと。
