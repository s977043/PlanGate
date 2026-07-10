# ai-loop-workflow 概念ドキュメント

> 適用ドメイン（Phase 1）: ①plangate 本体 = docs/workflows/ai-loop/ 配下のみ（dogfooding 域・本番フロー WF-00〜07 非適用）
> ②導入先リポジトリ = ho-paths 確定 + LoopSpec scope.allowed_paths 宣言を前提に適用可

---

## Phase 1: 導入先適用

> Human 決定（2026-07-10・verbatim）:
> 「ai-loopのPoCとして、実際に開発中のリポジトリでの動作を検証していきたい。このフェーズに入ったと考えており、制限を調整したい」
> （issue [#807](https://github.com/s977043/plangate/issues/807)）

ai-loop-workflow は Phase 0（本リポジトリの `docs/workflows/ai-loop/` 配下限定の
隔離 PoC）から **Phase 1（導入先実リポジトリでの検証）** へ移行した
（Run-001〜021 の dogfooding + issue #782 の導入先実走 1 件の完了を根拠とする）。

### 前提（導入先で適用可能とする 2 条件）

1. **ho-paths の導入先確定**: 導入先プロジェクトが自身の HO（Hardening
   Override）境界を [`ho-paths.md`](./ho-paths.md) 相当の形で
   確定していること。未確定の場合、全件が human escalate になる
   （arbiter の安全側デフォルト）
2. **LoopSpec `scope.allowed_paths` の宣言**: [`loopspec.md`](./loopspec.md)
   の既存必須フィールドで、run ごとの変更可能範囲を宣言していること

### auto-approve 方針（Phase 1 更新）

導入先での auto-approve 適用範囲は、**lite 4 軸（[`lite-criteria.md`](./lite-criteria.md)
§2）を申告制・AND・判定不能→false（AC-8 安全側）で満たせば、実機能も
`AUTO_APPROVED` 対象に含めてよい**（Human 決定・2026-07-10）。Phase 0 時点の
「事実上 docs 級のみ」（issue #782 実測）から拡張する。`lite.size_ok` は
当面**申告制のまま**とし、git 由来の機械算出 blast-radius boolean への置換
（#780 slice C）が、申告制に伴う保証強化の unlock として残る。

### plangate 本体の扱い（据え置き）

plangate 本体（本リポジトリ）における ai-loop-workflow の適用ドメインは
**据え置き**であり、`docs/workflows/ai-loop/` 配下限定・PlanGate 本番フロー
（WF-00〜07）非適用のまま変更しない。

### 不変条件（安全側 — 承認境界は不動。Phase 1 でも緩和しない）

- HO 接触 = 無条件 escalate（fail-closed。ho-paths 不在も fail-closed）
- **NO MERGE BY AI** / escalate の自己解決禁止 / 対応ラウンド上限 3
- W チェック独立 2 体（Model A/B、必要なら C/D）
- lite 4 軸の AC-8 安全側（判定不能→false・虚偽宣言禁止）
- `allowed_paths` に HO パスを書いても escalate は免れない
  （LoopSpec 既存規定・design-philosophy.md I-1）

### Phase 0 → Phase 1 移行履歴

Phase 0（隔離 PoC・本リポジトリ限定）→ Phase 1（導入先実リポジトリでの検証・
lite 全域 auto-approve 可）。移行判断は issue #807（Human 決定 verbatim 上記）。

---

## 1. 位置づけ

ai-loop-workflow は PlanGate（WF-00〜WF-07）と**並立する独立 PoC**。
PlanGate を置き換えず、競合しない。

```text
PlanGate（WF-00〜WF-07）   → in-the-loop 本番統制（並走期は継続稼働）
ai-loop-workflow            → on-the-loop PoC（低リスク帯の flow → detect → escalate）
```

Arbiter が存在証明を超えるまで PlanGate が本番統制を担う。

---

## 2. WF-00〜07 との並立関係

| 観点 | PlanGate（WF-00〜07） | ai-loop-workflow |
| ------ | ---------------------- | ----------------- |
| ループモデル | in-the-loop（実行前承認） | on-the-loop（逸脱時昇格） |
| 適用対象 | 全変更 | low-risk 変更のみ（boundary=clean, lite=true） |
| 実行ブロック | 承認前にブロック | 事前ブロックしない（flow） |
| 競合 | なし | なし |
| カバーする工程 | 開発プロセス全体（intent→要件→設計→実装→検証→handoff） | **intent 受付から merge-ready（CI 全 job green + AI レビュー指摘対応完了）まで一気通貫**。工程の実体（WF-00〜03・C-1・C-2・exec・V 系）は PlanGate と共通利用するが、**C-3（人間の計画承認）のみを AI 裁定ゲート（C-3'）に置換**し、成果の担保責任は ai-loop が持つ |
| 変更の生成 | 責務内（WF-02〜04 で要件・設計・実装を導く） | **責務内（ai-dev-workflow より広い）**。生成から「CI 通過 + AI レビュー指摘対応完了」まで一気通貫で責務を持つ。工程の実体（生成・計画そのもの）は PlanGate 資産を共通利用するが、**成果の担保**（merge-ready 到達）は ai-loop 固有の責務 |

両者は競合しない。並走期において:

- PlanGate が本番統制を担当する
- Arbiter は PoC 領域（docs/ai/ai-loop/ と docs/workflows/ai-loop/）で実験的に稼働する

Arbiter は plan 生成・要件展開・設計（WF-01〜03）の**工程の実体**を再実装せず、
PlanGate 既存フローをそのまま利用する。置き換えの対象は **C-3 のみ**であり、
C-2（2 レーン契約、`review-principles.md`
§7-bis）は不変のまま踏襲する。判断実行は L1 = RiverReview 委譲、C-4・merge
は引き続き Human-owned 固定（詳細は次節）。ただし ai-loop-workflow は
**ai-dev-workflow（AI 工程は PR 作成まで、C-4 は人間）より広い責務**を持ち、
PR 作成後の CI・AI レビュー指摘対応が完了し merge-ready に到達するまでを
自らの DoD とする（詳細は §3.3）。

---

## 3. PlanGate フロー共通化と C-3 置換（C-3'）

### 3.1 ユーザー設計判断（verbatim・2026-07-02）

> 「ai-loopでもPlanGateのフローを踏襲し、計画・設計の品質を保つ価値があると考えており、C-2までのフローは共通化したい。C-3を人ではなく、AIレビューを強化した仕組みに置き換える方式を考えていた。」
>
> 「『ai-loop は生成に責務を持たない』は間違え。ai-loopは成果物がCI通過し、CI時のAIレビューの指摘事項の対応の完了までを責務として『ai-dev』よりも広い責務を担保する」
>
> 「そのために、PR作成前のセルフレビューの強化も整える」

追加判断（AskUserQuestion）: 既存 C-2（2 レーン・`review-principles.md`
§7-bis）は**不変**のまま、**後段に W チェック（C-3'）を追加**する方式を選択。

### 3.2 確定パイプライン

```text
WF-00〜03 / plan・todo・test-cases 生成   ← PlanGate と共通
C-1 セルフレビュー                         ← 共通
C-2 外部 AI レビュー（2 レーン・不変）      ← 共通（ここまで完全踏襲）
C-3'（置換点）: AI 裁定ゲート = Arbiter
  boundary / lite / class 前提チェック
  → W チェック（Model A 順方向 / Model B adversarial）
  → severity 分類 → C/D 裁定 → decision table
  ├─ AUTO_APPROVED + provenance 刻印 → exec へ
  └─ HUMAN_ESCALATED → 従来の人間 C-3 へ降格
exec / L-0 / V 系                          ← 共通
宣言↔実差分の整合検証 + 強化セルフレビュー（PR 作成前・必須）← ai-loop 固有（§3.4）
PR 作成
CI + AI レビュー指摘対応ループ（merge-ready まで）← ai-loop 固有（§3.3）
C-4・merge                                 ← Human-owned 固定（不変）
```

### 3.3 責務範囲（ai-dev-workflow との比較）

ai-loop-workflow の責務範囲は **intent 受付から「成果物が CI を通過し、
CI/PR 時の AI レビュー指摘への対応が完了する（= merge-ready 状態）」まで**
であり、ai-dev-workflow（AI 工程は PR 作成まで、C-4 は人間）より**広い責務**
を担保する。

| 項目 | ai-dev-workflow | ai-loop-workflow |
|------|------------------|-------------------|
| AI 責務の終点 | PR 作成まで | **merge-ready**（CI green + AI レビュー指摘対応完了）まで |
| PR 後の CI 失敗対応 | 人間主導（都度） | AI が対応ループを回す（review-feedback-loop.md §2 と接続） |
| PR 後の AI レビュー指摘対応 | 人間主導（都度） | AI が採用/理由付き不採用を記録し対応完了まで担保 |
| 人間の関与 | C-3（計画承認）+ C-4（merge） | **escalate 時の判断のみ + C-4（merge）** |

**DoD（merge-ready 到達条件）**: CI 全 job green **かつ** AI レビュー指摘が
ゼロ、または全件対応完了（採用 / 理由付き不採用の記録）。これを満たして
初めて C-4 待ちに到達する。

PR 後の CI・AI レビュー指摘対応ループは
[`review-feedback-loop.md`](./review-feedback-loop.md) §2 の L4 学習閉ループ
と接続する（指摘 → 対応 → 観点への還元 → 次回セルフレビューでの事前捕捉）。

**detect の二段構成**: C-3' の W チェックは plan（宣言）に対する第 1 段の
detect である。CI/PR 時の AI レビュー（ボットレビュー）を**実差分に対する
第 2 段の detect** として位置づける。これにより「plan は妥当だが実装が逸脱」
のケースを、セルフレビュー（自己判定）だけに依存せず独立判定で捕捉する。

**収束ルール（指摘対応ループの打ち切り基準）**: 対応ラウンド（push →
新規指摘確認）の上限は **3 ラウンド**とし、超過した場合は human escalate
とする（escalate 予算 =
[`arbiter-policy.md`](./arbiter-policy.md) §7 と接続）。
また新規指摘が minor / info のみとなった時点で、採用 / 理由付き不採用の
記録を条件に merge-ready 判定へ進んでよい（収束保証）。

### 3.4 強化セルフレビュー（PR 作成前・必須ステップ）

merge-ready 責務を担保するため、exec / V 系完了後・PR 作成前に**強化セルフ
レビュー**を必須ステップとして組み込む:

- **前段（宣言↔実差分の整合検証）**: plan の Files to Touch（宣言）と
  実差分（`git diff --name-only <base>...HEAD`）を突合し、宣言外の変更がゼロで
  あることを機械確認する。C-3' の裁定は宣言に対する判定（第 1 段 detect）のため、
  実装が宣言から逸脱していないことをここで検証する（PlanGate の EH-3
  = plan 乖離検知と同型の防御。機械化は Phase 3 で `arbiter.py --verify-diff`
  として実装予定）。宣言外の変更を検出した場合は exec へ差し戻すか、
  再裁定（C-3' 再実行）を行う
- **内容**: diff-audit スキル（旧 self-review、Phase 1〜13 全観点）+
  `plan-review-readiness-gate.md`
  §7/§8 観点 + review-feedback-loop（L4）で還元済みの観点を必ず通す
- **狙い**: PR 作成後の CI 失敗・AI レビュー指摘を事前に潰し、「PR 作成後に
  指摘を受けない状態」に近づける。指摘が出た場合は L4 ループ
  （[`review-feedback-loop.md`](./review-feedback-loop.md) §2）で観点へ
  還元し、次回はセルフレビューで事前に捕捉される（閉ループ）
- 手順の詳細は [`execution-runbook.md`](./execution-runbook.md) を参照

### 3.5 位置づけの整理

本節は PlanGate 既存の C-3 Autonomous APPROVE
（`working-context.md` #353）・
C-3 条件付き降格（F5-AD）の判定を decision table + provenance で完全機械化
した位置づけである。escalate は従来の人間 C-3 への降格であり、**承認境界の
撤廃ではない**。touches-HO は W チェック結果にかかわらず常に人間へ固定
（[`concept.md`](./concept.md) §5「不変の原則」参照）。

---

## 4. 6 層自己改善ループとの関係

ai-loop-workflow は、低リスク帯かつ承認境界に触れない範囲で、
[`adaptive-production-loop.md`](./adaptive-production-loop.md) に定義する
6 層自己改善ループを回す。

```text
Generate → Evaluate → Remember → Schedule → Optimize → Recurse
```

このモデルは `/goal` や `/loop` など特定ツールのコマンド仕様ではなく、
ai-loop-workflow の上位運用 contract である。

特に、`/loop` 型の schedule と、`/goal` 型の Goal / Exit Criteria を混同しない。
PlanGate では **closed/open の違いを interval の有無で判断しない**。
closed loop と呼べる条件は、以下が明示されていること:

- Goal / Exit Criteria
- Evaluate point
- Stop / Escalation / Block の terminal state
- Remember の保存先
- Schedule の次アクション選択規則
- Optimize の反映先
- Human-owned 境界

`/loop` の interval 省略は、PlanGate 上では Schedule の動的化にすぎない。
Goal / Evaluate / Stop / Memory / Escalation Contract が明示されていなければ、
closed loop とは扱わない。

| 6 層 | 本ドキュメント上の対応 |
| --- | --- |
| Generate | WF-00〜03 / plan・todo・test-cases 生成、exec、PR 作成 |
| Evaluate | C-1 / C-2 / C-3' / CI / AI review / DoD 判定 |
| Remember | decision record、review-feedback-loop、suppression、provenance |
| Schedule | CI fix、review comment handling、retry、stop、block、human escalate |
| Optimize | diff-audit / gate / suppression / scheduling policy の更新 |
| Recurse | 1 サイクルの出力を次サイクルの pre-check へ戻す |

policy / HO / C-4 merge は Human-owned 固定であり、AI は自己改善ループを通じて
承認境界そのものを自己変更しない。

---

## 5. autonomous-degraded-gates-spec.md との関係

Phase 0（#655）の結論を参照:
`docs/working/TASK-0655/TASK-0655-c3-review.html`

| 区分 | 内容 |
| ------ | ------ |
| 拡張 | Arbiter は `docs/ai/autonomous-degraded-gates-spec.md` の degraded-gates 概念を**拡張する** |
| 非代替 | `docs/ai/autonomous-degraded-gates-spec.md` を置き換えない。PlanGate 本番の degraded-gates はそのまま |
| 参照元 | `NoHardeningOverridePath` 条件を `docs/ai/ai-loop/ho-paths.md` の起点として参照 |

---

## 6. 共通スキル参照方法

intent-classifier 等の PlanGate 共通スキルは shared として参照するが、
Arbiter 側のコードから直接変更しない（参照のみ）。

asset-inventory.md の uses/not-uses 分類に従う:
`docs/ai/ai-loop/asset-inventory.md`

---

## 7. 関連ドキュメント

- `docs/ai/ai-loop/arbiter-policy.md` — Arbiter L0 policy
- `docs/ai/ai-loop/ho-paths.md` — HO パス集約（touches-HO 判定の正本）
- `docs/ai/ai-loop/asset-inventory.md` — 共通資産 uses/not-uses 分類
- `docs/ai/ai-loop/concept.md` — Arbiter の基本概念（Phase 0）
- `docs/ai/ai-loop/related-specs.md` — 既存仕様との関係（Phase 0）
- `docs/ai/autonomous-degraded-gates-spec.md` — 参照元（変更禁止）
- [`docs/workflows/ai-loop/adaptive-production-loop.md`](./adaptive-production-loop.md) — 6 層自己改善ループと `/goal` / `/loop` 責務分離の正本
- [`docs/workflows/ai-loop/flow-detect.md`](./flow-detect.md) — C-3' の flow→detect→escalate 動作フロー
- [`docs/workflows/ai-loop/execution-runbook.md`](./execution-runbook.md) — PR 前セルフレビュー・PR 後指摘対応ループの実行手順
- [`docs/workflows/ai-loop/review-feedback-loop.md`](./review-feedback-loop.md) — CI/AI レビュー指摘対応を L4 学習へ還元する閉ループ
- `plan-review-readiness-gate.md` — 強化セルフレビュー §7/§8 観点の参照元
- `review-principles.md` §7-bis — C-2 の 2 レーン契約（不変）
- `working-context.md` — C-3 Autonomous APPROVE（#353）・C-3 条件付き降格（F5-AD）の正本
