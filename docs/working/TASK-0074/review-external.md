---
task_id: TASK-0074
artifact_type: review-external
schema_version: 1
status: done
phase: V-3
---

# V-3 外部レビュー — TASK-0074（F3）

standard モード。Codex 実行。Gemini は skill 競合で実質出力なし→Codex 主体。

## 判定: Codex=CONDITIONAL（critical 0 / major 1 / minor 1）→ doc 明確化で反映

critical なし＝コード再作業不要。スコープ正直性の明記で対応。

| # | Sev | 指摘 | 対応 |
|---|-----|------|------|
| 1 | major | 自動ヒント警告を仕様化したが実装/チェックポイントが差分に無く、UI層変更でも is_ui_task:false で Addendum 削除可。ゲート回避防止が文書宣言依存 | spec に「実装は後続 TASK・本 PBI はテンプレ+spec まで」を明記、後続 AC 候補を記載。handoff 既知課題化。当面はソフト誘導（#236 の一律必須化回避と一貫） |
| 2 | minor | 「design.md に Addendum 4〜6」だが design.md テンプレは視覚証跡(7)まで含む | 「必須フィールド全体(1〜7)」へ修正 |

## 確認（Codex）
- heredoc 破壊リスク: 問題なし（bash -n 通過、init 生成物のバッククォート正常）
- 真実源分岐 / 踏襲元最優先: 妥当
- major 以外に大きな穴なし

## 出典
- Codex: /tmp/t0074-codex-v3.md（CONDITIONAL）
- Gemini: /tmp/t0074-gemini-v3.md（出力不全）
