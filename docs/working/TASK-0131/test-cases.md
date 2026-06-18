# TEST CASES — TASK-0131 (#565)

## AC → テストケース マッピング

### AC-01: todo.md 各タスクに rollback を記す規約が正本に明文化
- **TC-01**: `grep -n "rollback" .claude/rules/working-context.md` で rollback 規約節がヒットする（H2 適用後）。前提: working-context 更新適用済み。期待: 規約文がある。種別: 機械
- **TC-02**: `grep -n "rollback" .agents/skills/ai-dev-plan/SKILL.md` で `rollback:` キー規約がヒットする。種別: 機械

### AC-02: mode 別の必須/任意ルールが矛盾なく記載（Refs: R-002）
- **TC-03**: working-context **と** ai-dev-plan SKILL の**双方**に「high-risk/critical で rollback 必須・standard 以下任意」が記載され、mode-classification.md の定性基準と矛盾せず、正本(責務宣言)と生成規約の責務差分が整合する。種別: レビュー
- **TC-04**: standard 以下で `rollback:不要` 明記が許容される旨が記載。種別: レビュー

### AC-03: 記入サンプルが1件存在
- **TC-05**: `docs/working/TASK-0131/todo.md` の各 Agent タスクに `rollback:` が存在する。種別: 機械（`grep '^- \[ \] T' docs/working/TASK-0131/todo.md | grep -vc 'rollback:'` が 0）

### AC-04: 正本+ミラー整合
- **TC-06**: `.agents/` `.codex/` `plugin/plangate/` の ai-dev-plan SKILL の rollback 規約文が一致（diff 差分なし）。種別: 機械

### AC-05: C-1 が rollback 欠落を検出（Refs: R-001）
- **TC-07**: `plan-quality-check` SKILL と `docs/working/templates/review-self.md` に「high-risk/critical の実装タスクで rollback 欠落 → FAIL」検出項目が存在する。high-risk plan で rollback 欠落タスクを与えると C-1 が FAIL 判定する。種別: レビュー + 機械（grep で検出項目の存在確認）

## Edge cases
- EC-01: 検証/読取のみタスク → `rollback:不要` を許容（誤って必須化しない）
- EC-02: 長手順 rollback → 直下補助ブロック記法が壊れずレンダリングされる
- EC-03: worktree 残骸ミラー（`.claude/worktrees/...`）は同期対象外として TC-06 から除外
