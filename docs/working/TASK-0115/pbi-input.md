# TASK-0115 PBI INPUT PACKAGE

> 出自: [INC-2026-05-26-001](../incidents/2026-05-26-empty-commit-direct-push.md) Prevention P-3
> 関連: PR #359, INC 寄与要因 C-1

## Context / Why

INC-2026-05-26-001 で AI が `git checkout` 失敗を見落として後続 `git commit` / `git push` を中断しなかった (寄与要因 C-1: 複数コマンド連結時のエラー伝播弱)。

Prevention P-3 として `.claude/rules/` に **コマンド連結時の error guard rule** を追記し、AI が次回以降同じパターンを踏まない構造化を行う。`.claude/rules/` は Hardening Override 対象のため C-3 APPROVED + maintenance window 経由で適用。

TASK-0112 (mode-classification 例外ルール、merged) と同じ操作パターン。

## What (Scope)

### In scope

- `.claude/rules/responsibility-classes.md` または `.claude/rules/` 配下に「Bash 連結コマンド時の error guard」セクション追加 (R-008 反映: 「既存ルール対応」セクション直前に配置で論理構造維持)
  - `&&` 連結 or `set -e` 必須
  - `git push` 前の `git rev-parse --abbrev-ref HEAD` で current branch verify
  - **`main` は直接 commit / push 禁止** (project-rules.md L66 と一致 / R-001 反映)
  - **その他 protected branch (`master`, `release/*`) への commit/push は事前明示確認**
- 追記場所の選択: 既存 [`responsibility-classes.md`](../../../../.claude/rules/responsibility-classes.md) §「対外公開アーティファクト publish 責務分界」と類似性が高いため同 file 内に追記、または新規 `.claude/rules/bash-command-chain-guard.md` を分離
- INC-2026-05-26-001 を出典として明記

### Out of scope

- AI 側の自動チェック実装 (本 PBI は文言ルールのみ、実装側強制は TASK-0114 P-1 hook 等)
- `bin/plangate` ラッパーで AI コマンドを intercept する仕組み

## 受入基準

- AC-1: `.claude/rules/` に「Bash 連結コマンド時の error guard」rule が追加されている
- AC-2: 以下 4 項目が含まれる: (i) `&&` 連結 or `set -e`、(ii) `git push` 前 branch verify、(iii) protected branch への commit/push 事前確認、(iv) INC-2026-05-26-001 への参照
- AC-3 (R-001 反映): AI 運用 4 原則 (CLAUDE.md `<law>`) との階層関係明示 (本 rule は第 1 原則の運用解釈)、**`main` は禁止 / 他 protected は明示確認** という 2 段階構造を明示
- AC-4: TASK-0112 (mode-classification 例外ルール) との重複定義なし、相互参照のみ
- AC-5 (R-007 反映): markdownlint pass + **`docs/working/incidents/2026-05-26-empty-commit-direct-push.md` への相対 link 健全性確認** (TC-05) + リンク健全性 CI pass

## Notes from Refinement

- `.claude/rules/` は Hardening Override 対象 → C-3 APPROVED + maintenance window 経由
- TASK-0112 と同じ操作手順を踏襲
- 追記場所: `.claude/rules/responsibility-classes.md` 内が文脈整合性高い (既に「自己設置 Gate 非緩和原則」「対外公開 publish 責務分界」など運用解釈ルールがある)

## Estimation

### Risks
- AI 自己解釈で rule を緩和 (本 PBI 自体が AI 運用 4 原則第 4 原則違反を防ぐ rule) → mitigation: 文言を明確 + INC 参照で実例固定
- TASK-0114 (P-1 hook) との重複感 → mitigation: P-1 は physical block (技術)、P-3 は AI 行動規範 (運用解釈) で層分離明示

### Unknowns
- 追記場所 (responsibility-classes.md 内 vs 新規 file) → plan で確定

### Assumptions
- `.claude/rules/` 構造は不変
- AI 運用 4 原則は CLAUDE.md `<law>` で固定
