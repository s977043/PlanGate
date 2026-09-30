---
name: pr-watch
description: "PR 作成後の監視と自動対応（CI エラー・レビューコメント・コンフリクトの 3 点セット）。Use when: 「PR を監視して」「レビュー対応を進めて」「PR 作成後」"
---

# PR Watch

PR 作成後、マージまたは close されるまで監視し、CI エラー・レビューコメント・
コンフリクトの 3 点セットに対応する再利用単位の定型。

## 1. 監視 3 点セット

| 観点 | 検知方法 | 対応 |
|------|---------|------|
| CI エラー | `gh pr checks <PR番号>` に `fail` | §3 CI FAIL 対応 |
| レビューコメント | `gh api repos/<owner>/<repo>/pulls/<PR番号>/comments` の ID 差分（inline review comments。`gh pr view --json comments` は issue コメントのみでボット指摘を取りこぼす） | §3 レビューコメント対応 |
| コンフリクト | `gh pr view <PR番号> --json mergeable` が `CONFLICTING` | §3 CONFLICTING 対応 |

3 点いずれも未検知かつ `state` が `MERGED` / `CLOSED` になった時点で監視終了。

## 2. Monitor スクリプト定型

`<PR番号>` は実行時に対象 PR 番号へ置換する。60 秒間隔でポーリングし、
コメントは `seen_file` に既知 ID を保存して差分検知する。

```bash
#!/usr/bin/env bash
set -euo pipefail

PR_NUMBER="<PR番号>"
SEEN_FILE="/tmp/pr-watch-${PR_NUMBER}-seen-comments.txt"
touch "${SEEN_FILE}"

CURRENT_FILE="/tmp/pr-watch-${PR_NUMBER}-current.txt"

while true; do
  # 一時的な gh 失敗（ネットワーク・レート制限）でクラッシュさせない
  state=$(gh pr view "${PR_NUMBER}" --json state --jq .state 2>/dev/null || echo "")
  if [ "${state}" = "MERGED" ] || [ "${state}" = "CLOSED" ]; then
    echo "PR #${PR_NUMBER} is ${state}. Stop watching."
    exit 0
  fi
  if [ -z "${state}" ]; then
    sleep 60
    continue
  fi

  # (1) コンフリクト検知
  mergeable=$(gh pr view "${PR_NUMBER}" --json mergeable --jq .mergeable 2>/dev/null || echo "")
  if [ "${mergeable}" = "CONFLICTING" ]; then
    echo "CONFLICTING detected on PR #${PR_NUMBER}"
  fi

  # (2) CI FAIL検知
  if gh pr checks "${PR_NUMBER}" 2>/dev/null | grep -qi "fail"; then
    echo "CI FAIL detected on PR #${PR_NUMBER}"
  fi

  # (3) 新規レビューコメント検知（inline review comments = ボット指摘を含む）
  # 取得成功時のみ SEEN_FILE を更新する（失敗時に空で上書きすると
  # 次回成功時に既読コメントを全件「新規」と誤検知するため）
  if gh api --paginate "repos/<owner>/<repo>/pulls/${PR_NUMBER}/comments" \
       --jq '.[].id' > "${CURRENT_FILE}" 2>/dev/null; then
    new_ids=$(comm -13 <(sort "${SEEN_FILE}") <(sort "${CURRENT_FILE}"))
    if [ -n "${new_ids}" ]; then
      echo "New review comments: ${new_ids}"
    fi
    cp "${CURRENT_FILE}" "${SEEN_FILE}"
  fi

  sleep 60
done
```

検知後は Monitor を止めずに §3 の対応定型へ分岐する（対応完了後にループへ戻る）。

## 3. 対応定型

### CI FAIL

1. `gh run view <run-id> --log-failed` でログを確認する
2. 原因を特定し、根拠のある修正を行う（症状抑制のみの修正は禁止）
3. 修正を commit・push する
4. `gh pr checks <PR番号> --watch` で再確認する

### レビューコメント

1. **必ず [`review-feedback-loop.md`](../../../docs/workflows/ai-loop/review-feedback-loop.md)
   §5 の登録済み suppression 表と突合する**。パターンが一致すれば、
   同表の機械反証を引用して**理由付きで不採用**とする
2. suppression に該当しない指摘は、事実主張（差分内容・件数・依存先等）を
   一次情報（実ファイル・実行結果）と照合してから採否判断する（Iron Law #8:
   NO CLAIM WITHOUT SOURCE CROSS-CHECK）
3. **採用**: 修正を実装し、`gh api repos/<owner>/<repo>/pulls/<PR番号>/comments/<comment-id>/replies -f body="<対応内容>"` でスレッド返信する
4. **不採用**: 理由（suppression 該当 or 一次確認の結果）を同スレッドに明記して返信する
5. 対応内容は `review-feedback-loop.md` §2 の L4 学習閉ループへ還元する

### CONFLICTING

1. 原因を特定する（`git log --oneline origin/main..<branch>` と
   `git log --oneline <branch>..origin/main` で分岐点を確認）
2. **スタック PR の前段 squash マージが原因の場合**は、固有コミットのみを
   載せ替える:

   ```bash
   git rebase --onto origin/main <旧base> <branch>
   ```

3. push 前に**三点照合**（[`responsibility-classes.md`](../../rules/responsibility-classes.md)
   「Bash 連結コマンド時の error guard」節が正本）: `git branch -vv` で
   ローカル名・upstream・HEAD の SHA を確認してから対象を同定する
4. `git push --force-with-lease` で push する
5. push 直後の `mergeable` は再計算中で stale な場合がある。**数十秒後に
   再確認**する（`gh pr view <PR番号> --json mergeable`）
6. **衝突中の PR は CI が 1 件も走っていないことがある**（base と merge できないと
   workflow が起動しない）。解消前に「CI green」と判定していても、それは
   **CI 未実行**である。push 後の `gh pr checks` の結果が出るまで品質判定を保留し、
   0 件を green と読まない

## 4. gh mutation の前置（アカウントドリフト対策）

コメント返信・push 等の mutation を伴う `gh` 操作は、`gh auth switch` +
viewer 検証 + mutation を**同一 Bash 呼び出し**で実行する。`gh auth switch`
自体は設定ファイルを書き換える永続操作だが、**他プロセスも switch を行う
環境では切替が競合（レースコンディション）し、mutation 実行の瞬間に別
アカウントへ戻っている実測が繰り返しある**ため、switch と mutation の間に
別呼び出しを挟まず、直前検証つきで atomic に行う。

```bash
gh auth switch --user <expected-user> \
  && [ "$(gh api user --jq .login)" = "<expected-user>" ] \
  && gh api repos/<owner>/<repo>/pulls/<PR番号>/comments/<comment-id>/replies -f body="<本文>"
```

## 5. 収束ルール

- 対応ラウンド上限は **3**。超過時は human escalate
  （[`execution-runbook.md`](../../../docs/workflows/ai-loop/execution-runbook.md)
  §2(7) の収束ルールと同一基準）
- 新規指摘が **minor / info のみ**になった時点で、対応記録を条件に
  merge-ready 判定へ進んでよい
- DoD: CI 全 job green **かつ** レビュー指摘ゼロ、または全件対応完了
  （採用/理由付き不採用の記録あり）。以降は C-4（人間の merge 承認、
  Human-owned 固定）待ちに遷移する
- **テスト ID の横断重複**: 連番 ID のテスト（`tests/extras/ta-NN-*.sh` 等）を追加・
  改番する PR は、merge-ready 判定の前に、open PR 全体と main の両方で同じ番号が
  別ファイルに使われていないかを確認する。ファイル名が違えば git の衝突にならず、
  CI でも検出されない

  下のコマンドはどれも、**ABORT が出ず、終了コードが 0 で、出力が空**のときだけ
  「重複なし」と読む。取得に失敗したときの空出力を「重複なし」と取り違えないため、
  取得失敗は必ず ABORT と非 0 で終わる

  取得の打ち切り確認（先に実行する）: `gh pr list` は `--limit` 件で、各 PR の
  `files` は 100 件で黙って打ち切られる。打ち切られると、下のコマンドは重複を
  見落としたまま空を返す

  ```bash
  if out=$(gh pr list --state open --limit 1000 --json number,files,changedFiles --jq '
      if length >= 1000 then "ABORT: open PR list may be truncated at 1000"
      else .[] | select(.changedFiles > ((.files // []) | length))
        | "ABORT: #\(.number) lists \((.files // []) | length) of \(.changedFiles) files; check it with gh pr diff \(.number) --name-only"
      end'); then
    [ -z "$out" ] || { printf '%s\n' "$out"; false; }
  else
    echo "ABORT: the open PR list is unavailable" >&2; false
  fi
  ```

  ABORT が出たら、下の open PR に関する結果は「重複なし」の根拠にならない
  （出た PR は `gh pr diff <n> --name-only` で個別に照合する）

  open PR 同士:

  ```bash
  gh pr list --state open --limit 1000 --json number,files --jq '
    [.[] | .number as $n | (.files // [])[].path
     | select(test("^tests/extras/ta-[0-9]+-"))
     | {id: (capture("ta-(?<i>[0-9]+)-").i | tonumber), pr: $n, path: .}]
    | group_by(.id) | map(select((map(.path) | unique | length) > 1))
    | .[] | "ta-\(.[0].id): " + (map("#\(.pr) \(.path)") | join(", "))' \
    || { echo "ABORT: the open PR list is unavailable" >&2; false; }
  ```

  出力が空（ABORT なし）なら重複なし。同じファイルを複数 PR が編集しているだけの
  場合は出ない。番号は数値として比べる（ta-7 と ta-07 は同じ番号）

  open PR と main: 上のコマンドは open PR 同士しか比べないので、先にマージされた
  PR が同じ番号を取った場合を検出できない（2026-09-25 に #1419 が main で ta-88 を
  使い、open の #1402 の ta-88 と衝突した）

  ```bash
  if git fetch -q origin main \
    && main_ids=$(git ls-tree --name-only origin/main tests/extras/ \
         | sed -nE 's#^tests/extras/ta-([0-9]+)-.*#\1#p' | awk '{ print $1 + 0 }' | sort -un) \
    && [ -n "$main_ids" ] \
    && prs=$(gh pr list --state open --limit 1000 --json number,files --jq '
         .[] | .number as $n | (.files // [])[].path
         | select(test("^tests/extras/ta-[0-9]+-")) | "\($n) \(.)"'); then
    printf '%s\n' "$prs" | while read -r n p; do
      [ -n "$p" ] || continue
      git cat-file -e "origin/main:$p" 2>/dev/null && continue
      id=$(printf '%s\n' "$p" | sed -nE 's#^tests/extras/ta-([0-9]+)-.*#\1#p' | awk '{ print $1 + 0 }')
      if printf '%s\n' "$main_ids" | grep -qx "$id"; then
        echo "ta-$id: #$n $p (main uses the same id)"
      fi
    done
  else
    echo "ABORT: origin/main or the open PR list is unavailable; empty output does not mean no collision" >&2
    false
  fi
  ```

  出力が空（ABORT なし）なら衝突なし。main にある同名ファイルを編集しているだけの
  PR は出ない。PR が main のファイルを同じ番号のまま rename した場合は、衝突として
  出る（誤検知。gh の `files` は変更後のパスしか返さない）

  main の中: 上の 2 つは「PR が持ち込む番号」しか見ないので、merge 後に main の中で
  同じ番号が 2 本になった場合は出ない（2026-09-29 に #1409 が改番前の
  `ta-88-ai-loop-v2-owner-backed-delivery.sh` を main に戻し、ta-88 が 2 本になった）。
  PR の merge 後にも実行する

  ```bash
  # 既知の重複は 2026-05 からある ta-14 の 2 本だけ。3 本目が入ったら出す。新しい番号を足さない
  if git fetch -q origin main \
    && ls=$(git ls-tree --name-only origin/main tests/extras/) && [ -n "$ls" ]; then
    printf '%s\n' "$ls" | sed -nE 's#^tests/extras/ta-([0-9]+)-.*#\1#p' \
      | awk '{ print $1 + 0 }' | sort -n | uniq -c \
      | awk '$1 > 1 && !($2 == 14 && $1 == 2) { print "duplicate on main: ta-" $2 " (" $1 " files)" }'
  else
    echo "ABORT: origin/main is unavailable" >&2; false
  fi
  ```

  出力が空（ABORT なし）なら、既知の ta-14 の 2 本を除いて main の中に重複なし。
  CI の `tests/extras/ta-61-extra-contract.sh` TC-20 は 2026-09-29 時点でファイル名の
  一意性しか見ておらず、番号の重複は検出しない（未是正）。CI に任せず、このコマンドを実行する

## 関連ドキュメント

- [`docs/workflows/ai-loop/review-feedback-loop.md`](../../../docs/workflows/ai-loop/review-feedback-loop.md) — suppression 表・L4 学習閉ループの正本
- [`docs/workflows/ai-loop/execution-runbook.md`](../../../docs/workflows/ai-loop/execution-runbook.md) §2(7) — コンフリクト対応手順の正本
- [`.claude/rules/responsibility-classes.md`](../../rules/responsibility-classes.md) — Bash 連結コマンド error guard・三点照合
