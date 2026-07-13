# External Review -- TASK-0842

> Phase: c2
> Reviewer: codex
> Generated: 2026-07-13T01:51:34Z

## Findings

1. **[重大] 「既存 CI に一本化」は #843 の同期元をカバーしていません。**  
   [plan.md:45](/Users/user/Documents/GitHub/plangate/docs/working/TASK-0842/plan.md:45) と [plan.md:87](/Users/user/Documents/GitHub/plangate/docs/working/TASK-0842/plan.md:87) は CI drift ゲートが `plugin/plangate/**` 全体を担保する前提ですが、workflow の push 対象は `.claude/**`、`.agents/skills/**`、`CHANGELOG.md` のみです。[sync-plugin-plangate.yml:7](/Users/user/Documents/GitHub/plangate/.github/workflows/sync-plugin-plangate.yml:7)  
   一方、同期スクリプトは `docs/ai/ai-loop/**` と `scripts/ai-loop/**` を plugin の bundled resources にコピーします。[sync-plugin-plangate.sh:134](/Users/user/Documents/GitHub/plangate/scripts/sync-plugin-plangate.sh:134) [sync-plugin-plangate.sh:286](/Users/user/Documents/GitHub/plangate/scripts/sync-plugin-plangate.sh:286)  
   したがって #840 / #843 のような変更は main に入っても CI 同期 PR を起動せず、まさにこの計画が解消対象とする未同期を再発させます。B案を採るなら、CI の trigger を同期元全体に拡張するか、「CI-owned」という記録を撤回して明示的な同期責務・検証を定義してください。

2. **[重大] Human による `ho-paths.md` の適用から PR / C-4 までの経路がありません。**  
   [plan.md:100](/Users/user/Documents/GitHub/plangate/docs/working/TASK-0842/plan.md:100) と [todo.md:52](/Users/user/Documents/GitHub/plangate/docs/working/TASK-0842/todo.md:52) は Human が commit するところで止まっています。しかしプロジェクトルールは main への直接 commit を禁止し、PR 経由の merge を要求します。  
   C-4 として定義されているのは #843 の「同期 PR」だけです。[plan.md:102](/Users/user/Documents/GitHub/plangate/docs/working/TASK-0842/plan.md:102)  
   HO-contract の実変更を含む PR の作成者、PR の単位、C-4 承認対象を明記してください。同期結果を同一 PR に含めるのか、HO-contract 用 PR と同期用 PR を分けるのかも決める必要があります。

3. **[中] AC-3 の検証コマンドは「このタスクで変更されていない」ことを証明できません。**  
   [plan.md:121](/Users/user/Documents/GitHub/plangate/docs/working/TASK-0842/plan.md:121) の `git diff --stat -- <paths>` は未コミット差分だけを確認します。すでに commit 済みの変更は見逃すため、証跡ログの「base origin/main」という主張とも一致しません。[eh3-no-change.log:1](/Users/user/Documents/GitHub/plangate/docs/working/TASK-0842/evidence/verification/eh3-no-change.log:1)  
   タスクブランチの全差分を確認する `git diff --stat origin/main...HEAD -- <paths>` と、未コミット差分の確認を分けて記録すべきです。

4. **[中] Human 適用用の「unified diff」は `git apply` 可能な形式ではありません。**  
   [plan.md:71](/Users/user/Documents/GitHub/plangate/docs/working/TASK-0842/plan.md:71) の hunk header は `@@ HO パス一覧` のような説明形式で、unified diff の `@@ -old,count +new,count @@` 構文ではありません。H-2 はこの差分を適用することを要求しているため、適用漏れリスクを下げるという目的とも矛盾します。実際に適用可能な patch にするか、「手動編集用の変更指示」と明記してください。

**総合判定: 要修正。**  
特に 1 を解消しない限り、「plugin 同期の担保を既存 CI に一本化」という B案の根拠が成立しません。

---

## R-NNN 監査表（追記専用 / TASK-0076 F5-C）

| R-NNN | severity | 内容（要約） | 検証（オーガナイザー実測） | status | reflected_in(commit) | notes |
|-------|----------|------------|--------------------------|--------|---------------------|-------|
| R-001 | major | CI trigger（.claude/** / .agents/skills/** / CHANGELOG.md）が同期元 docs/ai/ai-loop/** / scripts/ai-loop/** を未カバー → ai-loop 変更は同期 PR を起動しない | CONFIRMED（yml paths 実測 + sync-plugin-plangate.sh L151-152 実測） | accepted | (確定反映コミットで記入) | 対応: workflow trigger paths 拡張を Human 適用差分として plan に追加（.github/workflows/*.yml は HO-ci のため AI 編集不可）。AC-4 の「CI-owned 一本化」は trigger 拡張適用後に成立と明記 |
| R-002 | major | ho-paths.md の Human 適用 commit から PR / C-4 への経路が未定義（main 直接 commit は禁止） | CONFIRMED（project-rules C 実測） | accepted | (同上) | 対応: PR 単位を確定 — PR-1（本タスクブランチ: plan 成果物 + asset-inventory + Human が HO 差分 2 件を同ブランチに commit → C-4）/ PR-2（#843 同期 PR → C-4） |
| R-003 | medium | AC-3 検証 `git diff --stat -- <paths>` は未コミット差分のみで「本タスクで未変更」を証明しない | CONFIRMED | accepted | (同上) | 対応: `git diff --stat origin/main...HEAD -- <paths>`（ブランチ全差分）+ 未コミット差分の 2 段確認に修正、evidence 再取得 |
| R-004 | medium | 提案差分の hunk header が git apply 不能な説明形式 | CONFIRMED（@@ 構文不一致） | accepted | (同上) | 対応: 「手動編集用の変更指示（git apply 非対応）」と明記し、対象行番号を付記 |

指摘なし項目: なし（4 件すべて指摘あり）。
