# Incident Report: AI direct push to main (empty commit 49448c5)

| 項目 | 値 |
|------|---|
| **Incident ID** | INC-2026-05-26-001 |
| **Severity** | Medium (governance violation, no functional impact) |
| **Date / Time** | 2026-05-26 07:47:43 +0900 |
| **Reporter** | Claude (self-report after detection) |
| **Status** | Documented, prevention pending Human-owned hardening |
| **Related Commit** | [`49448c5`](https://github.com/s977043/plangate/commit/49448c5864f286b4e4db17840e54ec8b208c54a9) |
| **Detected by** | Self-detection during session continuation |
| **Acknowledged by** | Human (本 incident report 作成承認) |

## 1. Summary

AI (Claude Code) が `git checkout` の失敗を見落とし、main branch 上で `git commit --allow-empty` + `git push` を実行した結果、**empty commit `49448c5` ("ci: retrigger plangate CLI tests (likely flaky TA-14)") が PR 経由せず直接 main に push された**。`.claude/rules/responsibility-classes.md` の Human-owned merge boundary に違反。

機能的影響は **皆無** (empty commit, `git show --stat 49448c5` で変更 file 0)。ガバナンス上の規範違反として記録する。

## 2. Timeline (UTC+9)

| Time | Event |
|------|-------|
| 07:47:00頃 | PR #340 (TASK-0110) の `plangate CLI tests` が CI 失敗していると認識 |
| 07:47:30頃 | Claude が CI 再 trigger のため `git checkout docs/task-0110-plan` を試行 |
| 07:47:35頃 | **checkout が AGENTS.md の uncommitted 変更で abort** (エラーメッセージ出力済) |
| 07:47:40頃 | **Claude が checkout 失敗を見落とし**、main 上で `git commit --allow-empty -m "ci: retrigger..."` 実行 |
| 07:47:43 | `git push` 実行 → main へ直接 push (commit 49448c5) |
| 07:47:50頃 | push 成功メッセージ ("main → main") から direct push を即時検知 |
| 07:48 頃 | self-report として ユーザーに transparent 報告 |
| 07:55 頃 | Codex 相談 → 「機能影響なしのため放置」推奨を採用 (初動) |
| 翌 review session | Codex/Gemini session-level review で「放置だけでは不足、incident 記録 + 再発防止必要」と再指摘 |
| 本日 | F-001 対応として本 incident report 作成 |

## 3. Root Cause Analysis

### 直接原因

`git checkout` 失敗のエラーメッセージ (`error: Your local changes to the following files would be overwritten by checkout: AGENTS.md`) を Claude が認識せず、後続の `git commit` / `git push` を中断しなかった。結果として現在 branch (main) 上で commit + push が成立。

### 寄与要因

| ID | 要因 | 説明 |
|----|------|------|
| C-1 | **複数コマンド連結時のエラー伝播弱** | `git checkout && git commit && git push` ではなく改行区切り bash で個別実行していたため、checkout の non-zero exit が後続を止めなかった |
| C-2 | **AGENTS.md uncommitted の常態化** | `<claude-mem-context>` 自動挿入 (issue #355) で AGENTS.md が頻繁に dirty 状態。checkout 失敗が日常的に起きうる状況だった (現に TASK-0113 #355 で構造的対策進行中) |
| C-3 | **direct push を block する Hook 不在** | リポジトリには pre-push hook が未配置で、AI からの main 直接 push が物理的に止まらない |
| C-4 | **CI 再 trigger 文化への依存** | 「Flaky テスト → empty commit で再 trigger」という pattern を CI 設計の代替として採用しがちで、ガバナンス側面が劣後 |

### 最大 risk (Codex 指摘)

> PlanGate が gate 駆動に見えて、実際には AI が gate 外で作業・push・PBI 量産できる **process drift** が成果物より先に進むリスク。

本 incident はこの process drift の具体例。

## 4. Impact Assessment

### 機能的影響

| 項目 | 評価 |
|------|------|
| Code 変更 | **なし** (`git show --stat 49448c5` で 0 file changed) |
| Test 結果への影響 | なし (empty commit のため新規 CI は走るが結果不変) |
| Production 影響 | なし (本 commit は production deploy 対象外) |
| 他 PR への影響 | なし (commit が空のため `git merge --ff-only` 等で透過) |

### ガバナンス影響

| 項目 | 評価 |
|------|------|
| Human-owned merge boundary 違反 | **Yes** (`.claude/rules/responsibility-classes.md` ) |
| sockpuppet 禁止 違反 | No (s977043 アカウントで push、別アカウントへの偽装なし) |
| AI 自己解釈による Gate 解除 | No (本件は意図的解除ではなく**コマンド連結エラーの見落とし**) |
| 監査ログ汚染 | Low (commit message が "ci: retrigger ..." で incident であることが推測可能) |

## 5. Decision: 放置 (revert なし) の妥当性

Codex 初動推奨「放置」を採用した根拠と、本 incident report 作成後の妥当性再評価。

### 放置の根拠
- empty commit のため `git revert 49448c5` も empty となり revert PR 自体に意味がない
- `git push --force-with-lease` での history 改変は revert 以上に大きな副作用 (他 PR の base shift, 監査ログ disrupt)
- 本 incident report により**透明性は担保**される (commit message + 本 doc + Codex 相談ログ)

### 放置で**不十分**な点 (Codex/Gemini 再 review 指摘)
- 「empty commit が出ても放置でいい」という前例化を防ぐ必要がある
- 再発防止 (C-3 / C-1 / C-2 への対応) が同時に必要

→ **Incident report (本 doc) + Prevention 提案 (§7) を実施することで「放置」を完結させる**。revert はしない。

## 6. Lessons Learned

| ID | 学び |
|----|------|
| L-1 | コマンド連結時は `set -e` 等の **explicit error propagation** か、`&&` 連結を徹底 |
| L-2 | `git push` 前に **必ず現在 branch を verify** (`git rev-parse --abbrev-ref HEAD` 等で main 不在確認) |
| L-3 | `git checkout` 失敗時は **後続コマンドを中断する明示的 guard** が必要 |
| L-4 | AGENTS.md 等 SSoT の自動挿入問題は incident の **増幅要因** になる (本セッションで TASK-0113 #355 で対策進行中) |
| L-5 | 「CI 再 trigger のための empty commit」は **PR ブランチでのみ実施**、main 上では絶対に行わない |

## 7. Prevention (再発防止策提案 — Human-owned 適用)

本 incident report は **提案のみ** に留め、実装・適用は Human-owned で別 PBI 化を推奨。

### 提案 P-1: pre-push hook で main への直接 push を block

```bash
# .git/hooks/pre-push or .husky/pre-push (template として scripts/templates/ に提供)
#!/usr/bin/env bash
protected_branches="main master release"
while read -r local_ref local_sha remote_ref remote_sha; do
  remote_branch=$(echo "$remote_ref" | sed 's@refs/heads/@@')
  for pb in $protected_branches; do
    if [ "$remote_branch" = "$pb" ]; then
      # GitHub default branch には PR 経由でのみ push
      echo "ERROR: Direct push to '$pb' is prohibited (Human-owned merge boundary)."
      echo "Create a PR instead. If this is a CI re-trigger, push to the PR branch."
      exit 1
    fi
  done
done
exit 0
```

- 配置: `scripts/templates/pre-push.sample` + `scripts/install-pre-push.sh`
- AI が自分で適用しても物理的に防止可能 (`.git/hooks/` は repo にコミット不可だが install script 経由で local 適用)
- ただし `.git/hooks/` ローカル設置のため repo-wide enforcement にはならない → 補完で P-2

### 提案 P-2: GitHub branch protection rule で main への direct push を block

- Repository Settings → Branches → main → "Restrict pushes" + "Require pull request before merging"
- **Human-owned 適用**: GitHub repo admin が設定 (AI 不可)
- 効果: physical / repo-wide enforcement

### 提案 P-3: コマンド連結時の AI 側 guard rule 強化

`.claude/rules/` に追記提案 (Human-owned 適用、AI が自己解釈で緩和しない構造):

```markdown
## Bash 連結コマンド時の error guard

AI が複数 git コマンドを連結実行する際は以下を遵守:
1. `&&` で連結する (改行区切りで個別実行しない)
2. または `set -e` を冒頭に書く
3. `git push` 前に `git rev-parse --abbrev-ref HEAD` で current branch verify
4. main / master / release ブランチへの commit / push は事前確認
```

### 提案 P-4: AGENTS.md 自動挿入対策の早期適用

TASK-0113 (#355 / PR #358 merged) で plan 完了済。Human が c3.json 発行 + maintenance window で適用すれば、本 incident の寄与要因 C-2 が解消する。

## 8. Status / Follow-up

- [x] Incident detected (self-report)
- [x] Codex 初動相談 (放置採用)
- [x] Codex/Gemini session review で再指摘
- [x] Human 指示で本 incident report 作成 (F-001)
- [ ] P-1 (pre-push hook template) PBI 化 — Human 判断待ち
- [ ] P-2 (GitHub branch protection) 適用 — Human-owned (GitHub admin 操作)
- [ ] P-3 (`.claude/rules/` 追記) PBI 化 — Human 判断待ち
- [ ] P-4 (TASK-0113 適用) — Human c3.json 発行待ち (本 incident と共通根)

## 9. References

- Codex/Gemini session review (2026-05-26): 本セッションログ後半
- `.claude/rules/responsibility-classes.md` (Human-owned merge boundary 正本)
- TASK-0113 / PR #358 (AGENTS.md 自動挿入対策、本 incident 寄与要因 C-2 への構造的対応)
- AI 運用 4 原則 第 1 (実行前 y/n) / 第 2 (迂回禁止) / 第 4 (解釈変更禁止) — `CLAUDE.md` <law>

## 10. Accountability

- **AI 責任**: コマンド連結エラーの見落とし、direct push の即時 abort 不在
- **Project 責任** (system 側): pre-push hook / branch protection の不在で物理的防止が効かなかった
- 両者の補完で再発防止を構造化する
