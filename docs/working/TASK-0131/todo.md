# EXECUTION TODO — TASK-0131 (#565)

## 🤖 Agent タスク

### 準備
- [ ] T1 working-context.md / ai-dev-plan SKILL の todo.md 規約 現状箇所を特定 (owner:agent, files:.claude/rules/working-context.md, rollback:不要・読取のみ)

### 実装
- [ ] T2 [S2] ai-dev-plan SKILL「todo.md 規約」に rollback: キー + mode別必須 + 補助ブロック許可を追記 (owner:agent, files:.agents/skills/ai-dev-plan/SKILL.md, depends_on:T1, rollback:git checkout で該当SKILL.mdを元に戻す)
- [ ] T3 [S2] 上記を .codex/ と plugin/plangate/ のミラーへ同期 (owner:agent, files:.codex/skills/ai-dev-plan/SKILL.md;plugin/plangate/skills/ai-dev-plan/SKILL.md, depends_on:T2, rollback:2ミラーを git checkout で復元)
- [ ] T4 [S1] working-context.md 追記の apply-script + patch を生成（AI編集しない） (owner:agent, files:scripts/apply-task-0131-rollback.sh, depends_on:T1, rollback:生成スクリプトを削除, 🚩HO)
- [ ] T5 [S3] plan-quality-check SKILL + review-self.md に rollback 欠落検出を追加 (owner:agent, files:.claude/skills/plan-quality-check/SKILL.md;docs/working/templates/review-self.md, depends_on:T2, rollback:両ファイルを git checkout で復元)
- [ ] T6 [S4] 本 todo.md を rollback 記入サンプルとして整える (owner:agent, depends_on:T2, rollback:todo.md のサンプル追記差分を git checkout で復元)

### 検証
- [ ] T7 grep で3ミラー rollback 規約一致 + AC-05 検出項目確認 + markdownlint + doctor (owner:agent, depends_on:T3,T5, rollback:不要・検証のみ)

### 完了
- [ ] T8 handoff.md 作成(6要素) (owner:agent, rollback:不要)

## 👤 Human タスク
- [ ] H1 C-3 承認（high-risk / Standard 同期・exec 前ゲート） (owner:human 🚩)
- [ ] H2 working-context.md の apply-script 実行（HO 適用） (owner:human 🚩)
- [ ] H3 C-4 PR レビュー (owner:human)

## ⚠️ 依存
- T1 → T2 → T3 / T5 → T7
- exec 開始は H1(C-3) 必須 / S1 反映は H2(HO 適用) 必須
- AC-01 のうち working-context 正本反映の検証は H2(人間 apply) 後に実施

## 📌 rollback 記法サンプル（#565 ドッグフーディング）
各タスクの `rollback:` が本ファイルの記入例。検証/読取のみのタスクは `rollback:不要` と明記する（mode-classification の「不要明記可」に対応）。
