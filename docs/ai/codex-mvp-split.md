# Codex MVP Split (#352 / TASK-0118)

> **正本**: 本 doc。`.claude/commands/codex-mvp-split.md` / `.agents/skills/codex-mvp-split/SKILL.md` は本 doc を参照。
>
> 前段連携: [`plan-metrics-verification.md`](./plan-metrics-verification.md) (#351 / TASK-0117)

## 目的

規模 L 以上の機能を着手前に **最小 MVP (Phase 1) → Phase 2 → ...** に分割し、Codex に Phase 1 を選定相談する。属人化された質問テンプレを標準化、1 セッション完遂可能な scope に絞る。

## 背景

規模 L をいきなり全部実装すると 1 セッションで完結せず、リリースが滞る。

PocketEitan で 2 例実証:
- **例文音読カード** (規模 L、4 Phase に分割) → Phase 1 を v0.16.0 で完遂
- **TASK-srs-unification** (規模 standard〜full、2 Phase) → Phase 1 を v0.15.0 で完遂

毎回手書きで質問テンプレを作るのは非効率 + 属人化。本 skill で標準化。

## 起動タイミング (TASK-0117 連携)

```text
A フェーズ着手前
  ↓
TASK-0117 事前メトリクス検証 (#351)
  → 実数 / 見積もり ≥ 3 倍 = 規模 L 相当
  ↓
codex-mvp-split (本 skill) 起動  ← ここ
  ↓
Phase 1 確定 → PBI INPUT PACKAGE に Phase 分割表
  ↓
ai-dev-plan skill で plan 生成
```

TASK-0117 (#351) と **AND 関係**:
- TASK-0117 = 規模判定 (実数取得)
- 本 PBI (#352) = 規模 L 判定後の Phase 分割

相互参照のみ、重複定義なし。

## 質問テンプレ

```text
<project> の「<topic>」の最小 MVP 設計について Codex に相談します。

# 背景
<関連既存機能 + ギャップ + 直近文脈>

# 質問
**質問**: 「<topic>」の Phase 1 最小 MVP は次のどれが妥当か?
(A) 新ページ独立案 — 独立した新機能として実装
(B) 既存拡張案 — 既存機能を拡張
(C) 最小新規導線案 — 最小限の新規導線のみ追加
(D) Codex 独自案 — Codex が上記以外を提案

工数感 (S/M/L) と推奨理由を 400 字程度で。判断材料となる
「ユーザ価値」「実装の独立性」「次フェーズへの拡張性」を含めてください。
```

### 判断材料 3 軸

| 軸 | 観点 |
|----|------|
| **ユーザ価値** | Phase 1 単体でユーザに価値を提供できるか |
| **実装の独立性** | 他機能への依存が少なく単独実装可能か |
| **次フェーズへの拡張性** | Phase 2 以降への発展余地があるか |

## 採用後: Phase 分割表

PBI INPUT PACKAGE に必ず含める:

| Phase | 内容 | 工数 | 状態 |
|---|---|---|---|
| 1 | <採用案> | M | 着手 |
| 2 | <次の拡張> | S | 繰延 |
| 3 | <最終形> | M | 繰延 |

- **Phase 1 のみ本セッションの PBI scope**
- Phase 2 以降は **別 PBI に繰延** (繰延理由を明記)

## 既存実例 (PocketEitan)

### 1. 例文音読カード (規模 L → 4 Phase)

- 質問: 例文音読カードの Phase 1 最小 MVP は?
- Codex 回答: (C) 最小新規導線案 (既存カード画面に音読ボタン追加)
- 工数: M / 判断: ユーザ価値高 (即体験可) + 独立性高 + Phase 2 (録音比較) へ拡張可
- 結果: Phase 1 を v0.16.0 (PR #368) で完遂、4 Phase 全体を 1 セッション詰まりなく分割

### 2. TASK-srs-unification (規模 standard〜full → 2 Phase)

- 質問: SRS 統合の Phase 1 最小 MVP は?
- Codex 回答: (B) 既存拡張案 (既存 SRS ロジックに統合 API 層追加)
- 工数: M / 判断: 既存資産活用 + 段階移行可能
- 結果: Phase 1 を v0.15.0 (PR #365) で完遂

## CLI 化 (V2 候補)

現状は質問テンプレ提供 + Human/Codex CLI で相談。`bin/plangate mvp-split <topic>` 等の CLI 自動 dispatch は V2 候補 (本 PBI scope 外)。

## 関連

- Issue: [#352](https://github.com/s977043/plangate/issues/352)
- command: [`.claude/commands/codex-mvp-split.md`](../../.claude/commands/codex-mvp-split.md)
- skill: [`.agents/skills/codex-mvp-split/SKILL.md`](../../.agents/skills/codex-mvp-split/SKILL.md)
- 前段: [`plan-metrics-verification.md`](./plan-metrics-verification.md) (#351 / TASK-0117)
- 参考実装: PocketEitan PR #371 (`.claude/commands/codex-mvp-split.md`)
