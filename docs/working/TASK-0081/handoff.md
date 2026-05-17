---
task_id: TASK-0081
artifact_type: handoff
schema_version: 1
status: done
---

# HANDOFF — TASK-0081 (責務4分類 rules 正本化 / TASK-0071 S4)

## 1. 要件適合確認結果

| AC | 判定 | 根拠 |
|----|------|------|
| AC-1 4分類正本 | PASS | `.claude/rules/responsibility-classes.md`（AI/Human/CI/Workflow-owned 表+境界）|
| AC-2 具体例 | PASS | settings適用=Human / settings-drift=CI / handoff=Workflow / 実装=AI 等 |
| AC-3 既存ルール対応表 | PASS | hybrid Rule1-5 / orchestrator AS / working-context タスクロック / mode-classification / settings-wiring-contract / TASK-0077 AC-4 の対応表 |
| AC-4 hybrid 参照 | PASS | hybrid-architecture.md に参照追加（additive・重複定義なし）|
| AC-5 整合 | PASS | merge=Human-owned 固定 / 検証三者分担 が settings-wiring-contract・TASK-0077 AC-4 と矛盾なし |
| AC-6 既存本文不変 | PASS | hybrid 削除行0（参照4行追加のみ）・他 rules 変更なし・hook 78/0 |

## 1-bis. V-3 対応（Codex major1 fix-loop / Gemini クラッシュ）

Codex=critical0/major1/minor2。critical なし。fix-loop: MJ-1=orchestrator-mode
AS-3(ParentDone)は人間 or policy 許容 → AS-1/2/4/5 と AS-3 分割+階層例外明記。
minor=Human-owned self-mod を self-mod guard 対象に限定。再 V-1 PASS、
hook 78/0、hybrid additive。

## 2. 既知課題一覧

- なし（additive な rules 正本新設・強制機構変更なし）
- `.claude/rules/` は CI markdownlint スコープ外（structure はローカル維持）

## 3. V2 候補

- TASK-0071 S3（EH-3 メンテモード/SKIP_REASON・S3a の C-3 3点確定が前提）
- 責務4分類の機械検出（PBI 設計時に AI-owned 誤帰属を grep/lint で警告）

## 4. 妥協点

- 上位集約正本 + 既存ルールは参照のみ（本文 additive）。個別の具体適用は
  既存ルールに残し、矛盾でなく階層関係とした

## 5. 引き継ぎ文書（5分サマリ）

direction-codex-gemini.md C4 / TASK-0071 S4 の責務4分類
（AI/Human/CI/Workflow-owned）を `.claude/rules/responsibility-classes.md`
単一正本に集約。merge=Human 固定・検証三者分担（CI=reference/AI=doctor実体/
Workflow=完了ロック）を明文化。hybrid-architecture から参照（additive）。
既存本文不変・hook 78/0。これで TASK-0071 D-1 の S4 完了。残: S3 のみ。

## 6. テスト結果サマリ

- AC-1〜6 grep/diff 検証: 全 PASS
- additive 確認: hybrid 削除行0・他 rules 無変更
- hook 回帰: 78 passed / 0 failed
- 変更スコープ: hybrid-architecture.md（参照1ブロック）+ 新規 responsibility-classes.md + TASK-0081 docs
