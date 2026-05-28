# TASK-0115 handoff

> WF-05 Verify & Handoff 完了パッケージ (Rule 5)
> INC-2026-05-26-001 Prevention P-3 実装

## 概要

INC-2026-05-26-001 (empty commit 49448c5 main 直接 push 事故) の構造原因を AI 行動規範として明文化。Bash 連結コマンド時の error guard セクションを `.claude/rules/responsibility-classes.md` に追加。Defense in Depth の規範層完成。

## 1. 要件適合確認結果 (AC-1..AC-5)

| AC | 結果 | 検証 |
|----|------|------|
| AC-1: `.claude/rules/` に新 rule 追加 | ✅ PASS | L65 に「Bash 連結コマンド時の error guard」セクション挿入 |
| AC-2: 4 項目含む (`&&` 連結 / branch verify / protected 2 段階 / INC 参照) | ✅ PASS | `awk '/Bash 連結コマンド/,/^## /' .claude/rules/responsibility-classes.md | grep -cE 'main.*禁止|protected.*明示確認'` ≥ 2 |
| AC-3: AI 運用 4 原則 階層関係 | ✅ PASS | 第 1 原則の運用解釈、第 4 原則 (解釈変更禁止) 引用 |
| AC-4: TASK-0112 と重複定義なし | ✅ PASS | 相互参照のみ、本 PBI は AI 行動規範、TASK-0112 は mode 自動補正 |
| AC-5: markdownlint + リンク健全性 | PR CI で確認 | `docs/working/incidents/2026-05-26-empty-commit-direct-push.md` への相対 link 健全性確認 (TC-05 R-007) |

## 2. 既知課題一覧

| ID | 内容 | 重要度 |
|----|------|--------|
| K-1 | 本 rule は LLM 解釈依存のソフトルール (Hook 強制ではない) | info |
| K-2 | TASK-0112 (mode 例外ルール) は plan merged だが exec 未完了 → 安全側 (lite_eligible=false 明示扱い) で進む (R-006) | info |
| K-3 | TASK-0116 (release tag Iron Law) も同 file 編集予定 → 本 PBI 配置の「既存ルール対応」直前への挿入で衝突回避済 | info |

## 3. V2 候補

- V2-A: PreToolUse hook (Bash matcher) で `git push` 前 branch verify を技術強制 (本 rule は規範のみ)
- V2-B: コマンド連結時の `&&` / `set -e` 強制チェック (lint 統合)
- V2-C: EH-10 (AI 自己設置 Gate Hook、RFC merged) と統合

## 4. 妥協点

- Hook 強制化は scope 外 (本 PBI は文言追記のみ)
- TASK-0112 未 exec の現状を安全側で扱う (R-006)
- LLM 解釈依存 (現状 PlanGate 全体の rule もソフト中心)

## 5. 引き継ぎ文書 (5 分把握サマリ)

1. **追加 section**: 「Bash 連結コマンド時の error guard (INC-2026-05-26-001 P-3 / TASK-0115)」
2. **配置**: `.claude/rules/responsibility-classes.md` の「既存ルール対応」セクション**直前** (R-008 反映)
3. **4 項目明文化**:
   - `&&` 連結 or `set -e` 必須
   - `git push` 前 current branch verify
   - **`main` は直接 commit/push 禁止** (project-rules.md と一致)
   - 他 protected は明示確認必須
4. **AI 運用 4 原則 階層**: 第 1 原則の運用解釈、第 4 原則で緩和不可
5. **Defense in Depth 3 層完成**: 規範層 (本 PBI) + 技術層 (TASK-0114 merged) + repo-wide (P-2 Human-owned)

## 6. テスト結果サマリ

| カテゴリ | 結果 |
|---------|------|
| 機械検証 (grep) | ✅ Bash 連結 section 存在、main 禁止 / protected 明示確認 ≥ 2 |
| markdownlint | PR CI で確認 |
| リンク健全性 | `docs/working/incidents/2026-05-26-empty-commit-direct-push.md` 存在確認 |
| 既存テスト regression | PR CI で確認 |
| 規模メトリクス (#351 自己適用) | plan 1 file vs 実 1 file = 1.0 倍 → light 維持 |

## 7. Refs

- INC: [INC-2026-05-26-001](../incidents/2026-05-26-empty-commit-direct-push.md) Prevention P-3
- C-3 APPROVED: PR #392 merged 2026-05-28
- C-2 individual: PR #380 (Codex CONDITIONAL major 2 → 反映後 APPROVE / Gemini 概ね APPROVE)
- 並列構造: [TASK-0114 (#360)](../TASK-0114/handoff.md) (pre-push 物理 block / INC P-1)
- 関連 RFC: [ai-self-set-gate-hook-enforcement.md](../../rfc/ai-self-set-gate-hook-enforcement.md) (EH-10 V2)
- 関連 PBI: TASK-0112 (mode 例外ルール、相互参照のみ) / TASK-0116 (release tag Iron Law、同 file 編集)
