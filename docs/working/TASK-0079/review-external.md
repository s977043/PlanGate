---
task_id: TASK-0079
artifact_type: review-external
schema_version: 1
status: done
phase: V-3
---

# V-3/V-4 外部レビュー — TASK-0079（F5-AD 実装）

critical。Codex 実行（Gemini 出力不全→Codex 主体・前例運用）。

## V-3 判定: Codex=承認可（critical 0 / major 0 / minor 1）

| # | Sev | 指摘 | 対応 |
|---|-----|------|------|
| mn-1 | minor | critical Lite 例外と非同期 C-3 降格の関係が読解負荷（穴ではない） | mode-classification AC-11 に「事前 C-3 明示承認の無い critical は lite_eligible=false＝Lite/非同期降格の対象外」を一文追記 |

Codex 確認: opt-in 既定OFF/AC-8安全側/Hardening Override最上位/reject巻戻し
（ブランチ/PR/invalidation/監査/派生）に**抜けなし**、lite_eligible は内包派生
で二重分類リスク抑制。

## V-4 リリース前チェック（critical 必須）: 全 PASS

- hook 回帰 78/0 / scripts・bin diff ゼロ
- 全 AC（lite_eligible/Lite構成/C-3降格/reject巻戻し/Override/監査）存在
- 既存非破壊: 5段階 mode 定義・C-3 三値本文 保持（完全 additive・削除行0）
- 承認境界非撤廃 明記 / handoff 6 要素 / 変更スコープ = rules 2ファイル＋TASK-0079

## 結論
Codex 承認可（critical/major 0）+ minor 反映 + V-4 全 PASS。マージ可。

## 出典
- Codex: /tmp/t0079-codex-v3.md（承認可）
- Gemini: /tmp/t0079-gemini-v3.md（出力不全）
