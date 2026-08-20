# Arbiter — 既存仕様との関係整理

> **Status**: Phase 0 ドキュメント（2026-07-01）。
> **目的**: ai-loop-workflow と PlanGate 既存仕様の関係を明確化し、混乱・二重定義を防ぐ。

---

## 参照解決順（`.claude/rules/*.md` / 導入先で必ずこの順に探す）

本ドキュメントは `.claude/rules/responsibility-classes.md` を参照する。
このパスは上流リポジトリ基準のため、導入先では **次の順で探索する**:

1. 導入先リポジトリの `.claude/rules/responsibility-classes.md`
2. 無ければ plugin root 配下 `<plugin_root>/rules/responsibility-classes.md`。
   `<plugin_root>` は **Bash で `ls "${CLAUDE_PLUGIN_ROOT}/rules/"` を実行して展開・確認した
   絶対パス**（Read ツールは絶対パスを要求し環境変数を展開しないため、`${CLAUDE_PLUGIN_ROOT}/...`
   という文字列をそのまま Read しない）。変数が空・未設定ならキャッシュを glob で推測せず 3 へ進む
3. どちらにも無い場合は **「正本 `responsibility-classes.md` を参照できなかった」と明示**し、
   推測で内容を補わない

---

## 参照解決順（`docs/**` / 導入先で必ずこの順に探す）

本ドキュメントが参照する `docs/**` は上流リポジトリ基準の相対パスであり、`install.sh --claude` / plugin（Claude marketplace）/ Codex の **3 経路とも配布対象外**（解決不可）。(1) 導入先リポジトリの同名パスを探す → (2) 見つからなければ **「正本 `<path>` を参照できなかった」と明示**し、本ドキュメント内の記述を代替正本として扱い、推測で内容を補わない。**plugin root 配下の探索は `docs/**` には適用しない**: plugin が配布するのは `agents` / `commands` / `skills` / `rules` 等の定義ディレクトリのみで `docs/` を配布対象として認識せず、plugin root 配下に相当する配布物が存在しないため、plugin root 段を置いても必ず空振りする（クラス A の rules 参照が plugin root 配下で解決できるのは `rules/` が実際に配布されるからであり、この非対称を `docs/**` に持ち込まない）。

---

## 関係の種類（3 択）

| 関係 | 意味 |
|------|------|
| **代替** | Arbiter が既存仕様を置き換える（既存仕様は非推奨化） |
| **拡張** | Arbiter が既存仕様の思想を継承し、より精密に実装する |
| **独立** | 異なる時点・目的で動作し、干渉しない |

---

## autonomous-degraded-gates-spec.md との関係

### 関係: 拡張

### autonomous-degraded-gates-spec.md の思想

`autonomous-degraded-gates-spec.md` は「証明可能なときだけ自律、それ以外は安全側（人間）」という
思想を持ち、`C4AutoApproveAllowed` 条件として `NoHardeningOverridePath`
（HO 対象パスを含まない）を定義している。

```text
C4AutoApproveAllowed =
  mode == ultra-light
  AND (C3AutonomousApproved OR C3Skipped)
  AND RiskTierIntegrityPassed
  AND CiAllGreen
  AND NoHardeningOverridePath       ← HO 対象パスを 1 つも含まない
  AND NoSchemaOrBreakingOrSecurity
```

### ai-loop-workflow との対応関係

| autonomous-degraded-gates-spec.md | ai-loop-workflow |
|-----------------------------------|-----------------|
| `NoHardeningOverridePath` | `boundary = clean`（HO に触れない限り自律継続） |
| C-4 自律承認（例外的な自律化） | flow（自律継続が既定動作） |
| in-the-loop 内の例外として設計 | on-the-loop が前提（極性が逆） |
| ultra-light mode 限定 | lite 条件で low-risk 帯を定義（Phase 1 以降） |
| CI green が必須条件 | W チェック 2 モデル合意が主軸（CI は補完） |

### 拡張の内容

- `autonomous-degraded-gates-spec.md` の "NoHardeningOverridePath" 条件は
  Arbiter の `boundary=clean` と同じ思想（HO に触れない限り自律継続）
- Arbiter は W チェック（2 モデル非対称）と provenance 刻印を追加することで、
  この思想をより精密に実装する
- ai-loop-workflow が成熟した段階で、`autonomous-degraded-gates-spec.md` の
  改版を検討する（**Phase 3 の判断対象**）

### 重要な違い

`autonomous-degraded-gates-spec.md` は in-the-loop の例外的自律化（承認前ゲートを1箇所狭める）。
Arbiter は on-the-loop を前提とした制御極性の反転（flow が既定動作）。
**思想は同じだが、実装の極性が逆**。Phase 0 では干渉しない（Arbiter は PoC 段階）。

---

## plan-review-readiness-gate.md との関係

### 関係: 独立

`plan-review-readiness-gate.md` は Arbiter の detect フェーズとは**異なる時点**で動作する
既存ゲート。C-1 前（plan 提出前）の readiness 検証を担う。

| 観点 | plan-review-readiness-gate.md | Arbiter detect フェーズ |
|------|-------------------------------|------------------------|
| 動作タイミング | C-1 前（plan 提出前） | 変更生成後（flow 中） |
| 目的 | plan が review に耐えられる状態か確認 | 変更が承認境界・逸脱条件に抵触するか判定 |
| 判定対象 | plan artifact | 変更ファイルセット |
| 位置づけ | in-the-loop の前処理ゲート | on-the-loop の逸脱検知エンジン |

### Arbiter での参照

ai-loop-workflow でも Plan Review Readiness Gate の**考え方**は参照できる。
特に「判定フレームを事前定義し、条件を機械的に評価する」設計思想は
Arbiter の boundary チェック・W チェックの設計に活用する。

---

## responsibility-classes.md との関係

### 関係: 上位制約（Arbiter は「追加」するが「変更」しない）

`responsibility-classes.md` は PlanGate の責務 4 分類（AI-owned / Human-owned /
CI-owned / Workflow-owned）の正本。in-the-loop 前提に最適化された分類。

### Arbiter での取り扱い

- `docs/ai/ai-loop/` 配下のドキュメントは `responsibility-classes.md` を変更しない
- Arbiter の L0 設計（Phase 1 以降）では、**Policy-owned**（事前定義された自律許可の裁定）と
  **Sensor-owned**（逸脱検知の責務）を**追加**する設計を想定
- Iron Law は Arbiter でも最上位制約として適用される

> **注意**: ここで定義する Policy-owned / Sensor-owned の追加責務、および
> Human-owned の役割変化は **Arbiter L0（docs/workflows/ai-loop/ 配下）内のみ**に適用される。
> PlanGate 本番フロー（WF-00〜WF-07）の C-3 / C-4 / merge 責務は変更しない。
> PlanGate 本番統制では `responsibility-classes.md` が引き続き優先する。

| 責務クラス | PlanGate 既存 | Arbiter 追加予定（Phase 1+） |
|-----------|--------------|----------------------------|
| AI-owned | 実装・テスト・PR 準備 等 | + 自律実行・auto-approve 発行 |
| Human-owned | 実行前承認・merge | → **policy 制定・例外裁定・事後監督**（実行前承認から退却） |
| CI-owned | drift 検出・必須検証 | + drift 検出・逸脱検知・サーキットブレーカー発火 |
| Workflow-owned | DoD・handoff 追跡 | + 学習ループ・昇格予算管理 |
| **Policy-owned** | - | 事前定義された自律許可の裁定（Human でも AI でもない第三主体） |
| **Sensor-owned** | - | 逸脱検知の責務 |

---

## hook-enforcement.md との関係

### 関係: 独立（HO パス定義を参照・継承）

`hook-enforcement.md` は PlanGate の HO パスと hook 実装の正本。
Arbiter は HO パスの定義を**参照**し、`docs/ai/ai-loop/ho-paths.md` に集約する。
`hook-enforcement.md` 自体は変更しない（`docs/ai/` 既存ファイルのため変更禁止）。

---

## core-contract.md（Iron Law）との関係

### 関係: 上位制約（Arbiter は Iron Law に従う）

Iron Law は Arbiter でも最上位制約として適用される。
ai-loop-workflow は Iron Law の下位に位置し、Iron Law を緩和・変更しない。

---

## 関連ドキュメント

- `docs/ai/ai-loop/concept.md` — Arbiter の基本概念・PlanGate との関係
- `docs/ai/ai-loop/asset-inventory.md` — 資産の uses/not-uses 分類
- `docs/ai/ai-loop/ho-paths.md` — touches-HO 判定基準リスト
- `docs/ai/autonomous-degraded-gates-spec.md` — `NoHardeningOverridePath` 定義元（読み取り専用）
- `docs/ai/core-contract.md` — Iron Law 正本（読み取り専用）
- `.claude/rules/responsibility-classes.md` — 責務 4 分類正本（読み取り専用）
