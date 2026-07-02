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
| レビューコメント | `gh pr view <PR番号> --json comments,reviews` の ID 差分 | §3 レビューコメント対応 |
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

while true; do
  state=$(gh pr view "${PR_NUMBER}" --json state --jq .state)
  if [ "${state}" = "MERGED" ] || [ "${state}" = "CLOSED" ]; then
    echo "PR #${PR_NUMBER} is ${state}. Stop watching."
    exit 0
  fi

  # (1) コンフリクト検知
  mergeable=$(gh pr view "${PR_NUMBER}" --json mergeable --jq .mergeable)
  if [ "${mergeable}" = "CONFLICTING" ]; then
    echo "CONFLICTING detected on PR #${PR_NUMBER}"
  fi

  # (2) CI FAIL検知
  if gh pr checks "${PR_NUMBER}" 2>/dev/null | grep -qi "fail"; then
    echo "CI FAIL detected on PR #${PR_NUMBER}"
  fi

  # (3) 新規レビューコメント検知
  gh pr view "${PR_NUMBER}" --json comments --jq '.comments[].id' \
    > /tmp/pr-watch-${PR_NUMBER}-current.txt
  new_ids=$(comm -13 <(sort "${SEEN_FILE}") <(sort /tmp/pr-watch-${PR_NUMBER}-current.txt))
  if [ -n "${new_ids}" ]; then
    echo "New review comments: ${new_ids}"
  fi
  cp /tmp/pr-watch-${PR_NUMBER}-current.txt "${SEEN_FILE}"

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

## 4. gh mutation の前置（アカウントドリフト対策）

コメント返信・push 等の mutation を伴う `gh` 操作は、`gh auth switch` +
viewer 検証 + mutation を**同一 Bash 呼び出し**で実行する（単発 switch は
次コマンドで既定アカウントに戻るため）。

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

## 関連ドキュメント

- [`docs/workflows/ai-loop/review-feedback-loop.md`](../../../docs/workflows/ai-loop/review-feedback-loop.md) — suppression 表・L4 学習閉ループの正本
- [`docs/workflows/ai-loop/execution-runbook.md`](../../../docs/workflows/ai-loop/execution-runbook.md) §2(7) — コンフリクト対応手順の正本
- [`.claude/rules/responsibility-classes.md`](../../rules/responsibility-classes.md) — Bash 連結コマンド error guard・三点照合
