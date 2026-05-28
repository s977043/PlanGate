# /codex-mvp-split

規模 L 以上の機能を着手する前段で、**最小 MVP (Phase 1) を Codex に選定相談**する。属人化された Phase 分割質問を標準化 (TASK-0118 / #352)。

> 正本: [`docs/ai/codex-mvp-split.md`](../../docs/ai/codex-mvp-split.md)
> 前段連携: [`docs/ai/plan-metrics-verification.md`](../../docs/ai/plan-metrics-verification.md) (#351 / TASK-0117) で「規模 L 以上」判定された場合に本コマンド起動を推奨

## 引数

`<topic>` — MVP 分割を検討する機能・トピック名。

## いつ使うか

- A フェーズ (PBI INPUT PACKAGE 作成) **前段**
- TASK-0117 事前メトリクス検証で **実数 / 見積もり ≥ 3 倍** (規模 L 相当) と判定された場合
- 1 セッションで全部実装すると完結しない規模の機能

## 質問テンプレ (Codex へ)

```text
<project> の「<topic>」の最小 MVP 設計について Codex に相談します。

# 背景
<関連既存機能 + ギャップ + 直近文脈>

# 質問
**質問**: 「<topic>」の Phase 1 最小 MVP は次のどれが妥当か?
(A) 新ページ独立案
(B) 既存拡張案
(C) 最小新規導線案
(D) Codex 独自案

工数感 (S/M/L) と推奨理由を 400 字程度で。判断材料となる
「ユーザ価値」「実装の独立性」「次フェーズへの拡張性」を含めてください。
```

## 採用後

PBI INPUT PACKAGE に **Phase 分割表** を必ず含める:

| Phase | 内容 | 工数 | 状態 |
|---|---|---|---|
| 1 | <採用案> | M | 着手 |
| 2 | <次の拡張> | S | 繰延 |
| 3 | <最終形> | M | 繰延 |

Phase 1 を本セッションの PBI scope とし、Phase 2 以降は繰延 (別 PBI)。

## 出力

- Codex 回答 (4 選択肢から 1 つ + 工数 + 3 軸の判断材料)
- PBI INPUT PACKAGE への Phase 分割表

## 関連

- 正本: [`docs/ai/codex-mvp-split.md`](../../docs/ai/codex-mvp-split.md)
- skill: [`.agents/skills/codex-mvp-split/SKILL.md`](../../.agents/skills/codex-mvp-split/SKILL.md)
- 前段: TASK-0117 (#351) 事前メトリクス検証
