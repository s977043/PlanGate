---
task_id: TASK-0075
artifact_type: review-external
schema_version: 1
status: done
phase: V-3
---

# V-3 外部レビュー — TASK-0075（F4）

high-risk。Codex + Gemini 実行（両者出力あり）。

## 判定: Codex=CONDITIONAL APPROVE(critical0/major2/minor2) / Gemini=PASS(条件付承認・major0)

Codex major をブロッカー採用し doc 明確化で反映（critical なし＝コード再作業不要）。

| # | Sev | 指摘(Codex) | 対応 |
|---|-----|------------|------|
| MJ-1 | major | `/ai-dev-workflow ... retro` を opt-in 正本に宣言したが scripts/ai-dev-workflow に retro 経路なし＝実行不能の抜け穴 | 明示コマンドを「将来 CLI（未実装）」と明記し正本起動方式から除外。CLI 実装は後続 PBI |
| MJ-2 | major | `retro_enabled` の承認境界未定義（AI が plan 中に自己付与しうる） | 正本 opt-in source を **C-3 承認済み pbi-input の retro_enabled のみ**に固定。plan_hash/EH-3 が改変検出 |
| mn-1 | minor | README 実行シーケンスで WF-06 が標準の一部に見える | 「標準は 1〜7 で完結・WF-06 は opt-in append」明記 |
| mn-2 | minor | seeds パス表記揺れ（full vs basename） | 正本/artifact 参照を docs/working/improvement-seeds.md フルパスに統一 |

## Gemini（PASS）
- 純追加性 / #228・#231・#200 責務分離 / 承認境界 / Rule 1 すべて PASS
- minor 助言: seeds 肥大時 #200 archive/rotate、skip 理由 1 行（任意・V2）→ 反映済

## 確認
- 再 V-1: AC-1〜8 + MJ/minor 全 PASS、hook 48/0、lint 0

## 出典
- Codex: /tmp/t0075-codex-v3.md（CONDITIONAL APPROVE）
- Gemini: /tmp/t0075-gemini-v3.md（PASS 条件付承認）
