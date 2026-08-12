# A-1: baseline 実測と横断調査（plan Step 1）

- 実行日: 2026-08-13
- 環境: macOS (darwin 25.6.0) / BSD `sed` / `/bin/sh`
- base: `origin/main` = `e9d384b77616314995c32d42a7f3d59f2dea32f6`
- ブランチ: `feat/1045-exec`（`git diff origin/main --stat` = 0 件で開始）

## 1. baseline（`sh tests/extras/ta-25-approval-token-guard.sh`）

```text
TA-25 standalone: 47 passed, 0 failed
EXIT=0
```

→ **0 failed。`SC-1 (a)` は発火せず。** 47 は測定環境・base とセットの参考値であり契約値にしない。

## 2. 誤検知の本 PBI 内再現（`PreToolUse` payload / 修正前 guard）

トークンパス literal を含むコマンドは probe スクリプト経由で組み立て、
literal とリダイレクトを同一 Bash コマンドに書かない（plan §記法規約）。

| # | コマンド（`<TOKEN>` = テスト専用架空パス） | 修正前 rc | 分類 |
|---|---|---:|---|
| FP-A | `grep -c '<TOKEN>' .gitignore 2>/dev/null` | 2 | 誤 block |
| FP-B | `cat <TOKEN> 2>&1` | 2 | 誤 block |
| FP-C | `cat <TOKEN> >&2` | 2 | 誤 block |
| FP-D | `cat <TOKEN> 3>&-` | 2 | 誤 block |
| FP-E | `python3 -c "print('<TOKEN> -> ok')"` | 2 | 誤 block（**GC-2 の取りこぼし。本 PBI では解消しない**） |
| FP-F | `git log --oneline -- <TOKEN> 2>/dev/null` | 2 | 誤 block |
| FP-G | `find docs/working -name c3.json 2>/dev/null` | 2 | 誤 block |
| FP-H | `jq -r .c3_status <TOKEN> 2>/dev/null` | 2 | 誤 block |
| FP-I | `cat <MAINT> 2>/dev/null` | 2 | 誤 block |
| FP-J | `ls <TOKEN> 1>/dev/null` | 2 | 誤 block |
| FP-K | `cat <TOKEN> 2>>/dev/null` | 2 | 誤 block |

退行防止側 18 ケース（`> <TOKEN>` / `>> <TOKEN>` / `1> <TOKEN>` / mixed / `/dev/stdout` /
`/dev/stderr` / `/dev/fd/3` / `/dev/nullX` / `/dev/null/../<TOKEN>` / `&>` / `&>>` /
`&> /dev/null` / `>& <file>` / 文字列リテラル `>` / `cp` / `tee` / `mv` /
`ls > /dev/null ; cp <TOKEN> …`）は **すべて rc=2**（修正前）。

## 3. U-6 横断調査（`scripts/` / `bin/` / `.codex/`）

```text
$ grep -rn "grep -q '>'" scripts/ bin/ .codex/
scripts/check-approval-token-write.sh:48:  printf '%s' "$_wc" | grep -q '>' && return 0
```

→ **粗い `>` 判定は本 guard の 1 箇所のみ**。他 3 本（`check-git-destructive.sh` /
`scripts/hooks/check-delegation-commit-boundary.sh` / `.codex/hooks/eh-bridge.sh`）に
`>` ベースの write-intent ヒューリスティクスは無い。**follow-up issue は不要**。

## 4. U-3 再確認

`grep -rn "writes token path" tests/` → **ヒット 0 件**（`docs/` と `scripts/` のみ）。
既存 TC は `BLOCK` / `target=` / `file_path=` / `parse-unknown` / `bypass` のみを assert。
→ **`RT-3` は発火せず**。detail 文字列への `rule=<id>` 追記は既存 TC を壊さない。

## 5. RT-2 (a)(b) の実測

- **(a)** 他の稼働ガードが本 guard を invoke / source している事実は **なし**
  （ヒットは `tests/` と `.claude/settings.example.json` の wiring、
  および `scripts/apply-task-0123-patches.sh` の複製導線のみ）
- **(b)** `scripts/hooks/check-approval-token-write.sh` は
  `git ls-tree -r origin/main` に **不在**、worktree / メイン checkout の両方にも **不在**

→ **`RT-2` は発火せず**。

## 6. 稼働 settings の実測（i-1 / U-5 の根拠）

メイン checkout `/Users/user/Documents/GitHub/plangate/.claude/settings.json`（gitignore 対象）:

```text
102:            "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/check-approval-token-write.sh"
111:            "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/check-approval-token-write.sh"
scripts/hooks/check-approval-token-write.sh: ABSENT
```

→ 稼働配線は **`scripts/` 直下を直接呼ぶ**。スクリプト本体の修正は **再適用なしで即時反映**
（U-5「再適用不要」を稼働側でも確認）。

## 7. R-008 / R-14 の複製導線

`scripts/apply-task-0123-patches.sh:67-88` は
`scripts/check-approval-token-write.sh` → `scripts/hooks/check-approval-token-write.sh` へ `cp` し、
**既存時は `_already` でスキップして更新しない**。
`origin/main` に当該ファイルは不在のため実害ゼロ。**`GC-7` を維持し本 PBI では触らない**。
handoff の既知課題へ記載。
