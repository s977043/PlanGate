# H-02 承認記録 — HO 対象ファイル適用（TASK-0871）

- 対象: `.claude/commands/ai-loop-workflow.md`（Hardening Override 対象・AI 編集不可）
- patch: `docs/working/TASK-0871/evidence/ho-patch/ai-loop-workflow.md.patch`（2 hunk / 29 行）
- **承認**: 2026-07-19 Human（AskUserQuestion「H-02: patch 承認（適用は自分で実行）」を選択）
- **適用**: 2026-07-19 Human が worktree 内で `git apply` を対話実行（AI は未編集 — HO 常時 block 遵守）
- **検証**: `git apply --check --reverse <patch>` exit 0（適用結果が patch と完全一致することをオーガナイザーが機械確認）
- 関連: plan.md Stop Condition「HO 対象ファイルの diff が Human 未承認」の証跡ファイル（本記録の存在 = 承認済み）
- C-3 再承認: 同日 `bin/plangate approve TASK-0871` により c3.json 再発行済み（plan_hash `sha256:843d96180b9d2de7f0aea4a448d1198ab1c95e423bb76b17f0e21dcc08ac3dc7`）
