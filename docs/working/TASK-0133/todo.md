# EXECUTION TODO — TASK-0133 (#567)

## 🤖 Agent タスク
### 準備
- [ ] T1 decision-log-schema.md 既存フィールド + brainstorming skill 現状を精読 (owner:agent, rollback:不要・読取のみ)
### 実装
- [ ] T2 [S1] decision-log-schema.md に alternatives_rejected:[{option,rationale}] additive 追加 + サンプル + 後方互換注記 (owner:agent, files:docs/working/templates/decision-log-schema.md, depends_on:T1, rollback:該当追記を git checkout で復元)
- [ ] T3 [S2] brainstorming skill に不採用理由 記録規約を追記（必須=high-risk/critical/human）。正本 .agents/skills → .claude/.codex/plugin ミラー同期 (owner:agent, files:.agents/skills/brainstorming/SKILL.md;.claude/skills/brainstorming/SKILL.md;.codex/skills/brainstorming/SKILL.md;plugin/plangate/skills/brainstorming/SKILL.md, depends_on:T1, rollback:4ファイルを git checkout で復元)
- [ ] T4 [S3] pbi-input Notes の decision-log 参照縮退を規約化（pbi-input.md 不在時は working-context.md の該当箇所へ fallback・T1 で対象確定） (owner:agent, files:docs/working/templates/pbi-input.md, depends_on:T2, rollback:追記を git checkout で復元)
### 検証
- [ ] T5 alternatives_rejected grep / 既存フィールド全残 grep / サンプル jq parse / markdownlint (owner:agent, depends_on:T2,T3,T4, rollback:不要・検証のみ)
### 完了
- [ ] T6 handoff.md 作成(6要素) (owner:agent, rollback:不要)

## 👤 Human タスク
- [ ] H1 C-3 承認（standard・スキーマ変更のため autonomous 不可・同期） (owner:human 🚩)
- [ ] H2 C-4 PR レビュー (owner:human)

## ⚠️ 依存
- T1 → T2/T3 → T4 → T5
- exec 開始は H1(C-3) 必須。HO 対象ファイルを触らない（templates/ + .claude/skills/）ため HO apply 不要。

## 📌 rollback 記法サンプル（#565 規約適用）
standard だが #565 ドッグフーディングとして各タスクに rollback: を記載。
