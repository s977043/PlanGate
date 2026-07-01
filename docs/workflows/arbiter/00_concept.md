# Arbiter-workflow 概念ドキュメント

> 適用ドメイン: Arbiter-workflow（docs/workflows/arbiter/ 配下）のみ
> 非適用: PlanGate 本番フロー（WF-00〜WF-07）

---

## 1. 位置づけ

Arbiter-workflow は PlanGate（WF-00〜WF-07）と**並立する独立 PoC**。
PlanGate を置き換えず、競合しない。

```text
PlanGate（WF-00〜WF-07）   → in-the-loop 本番統制（並走期は継続稼働）
Arbiter-workflow            → on-the-loop PoC（低リスク帯の flow → detect → escalate）
```

Arbiter が存在証明を超えるまで PlanGate が本番統制を担う。

---

## 2. WF-00〜07 との並立関係

| 観点 | PlanGate（WF-00〜07） | Arbiter-workflow |
| ------ | ---------------------- | ----------------- |
| ループモデル | in-the-loop（実行前承認） | on-the-loop（逸脱時昇格） |
| 適用対象 | 全変更 | low-risk 変更のみ（boundary=clean, lite=true） |
| 実行ブロック | 承認前にブロック | 事前ブロックしない（flow） |
| 競合 | なし | なし |

両者は競合しない。並走期において:

- PlanGate が本番統制を担当する
- Arbiter は PoC 領域（docs/ai/arbiter/ と docs/workflows/arbiter/）で実験的に稼働する

---

## 3. autonomous-degraded-gates-spec.md との関係

Phase 0（#655）の結論を参照:
`docs/working/TASK-0655/TASK-0655-c3-review.html`

| 区分 | 内容 |
| ------ | ------ |
| 拡張 | Arbiter は `autonomous-degraded-gates-spec.md` の degraded-gates 概念を**拡張する** |
| 非代替 | `autonomous-degraded-gates-spec.md` を置き換えない。PlanGate 本番の degraded-gates はそのまま |
| 参照元 | `NoHardeningOverridePath` 条件を `ho-paths.md` の起点として参照 |

---

## 4. 共通スキル参照方法

intent-classifier 等の PlanGate 共通スキルは shared として参照するが、
Arbiter 側のコードから直接変更しない（参照のみ）。

asset-inventory.md の uses/not-uses 分類に従う:
`docs/ai/arbiter/asset-inventory.md`

---

## 5. 関連ドキュメント

- `docs/ai/arbiter/arbiter-policy.md` — Arbiter L0 policy
- `docs/ai/arbiter/ho-paths.md` — HO パス集約（touches-HO 判定の正本）
- `docs/ai/arbiter/asset-inventory.md` — 共通資産 uses/not-uses 分類
- `docs/ai/arbiter/concept.md` — Arbiter の基本概念（Phase 0）
- `docs/ai/arbiter/related-specs.md` — 既存仕様との関係（Phase 0）
- `docs/ai/autonomous-degraded-gates-spec.md` — 参照元（変更禁止）
