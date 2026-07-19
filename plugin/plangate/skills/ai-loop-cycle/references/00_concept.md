# ai-loop-workflow 概念ドキュメント（正本）

> **正本宣言**: 本ドキュメントは ai-dev / ai-loop の**アーキテクチャ・責務定義の
> 単一正本**である（5 責務・terminal state・C-3'/Human C-3 経路・内側 Delivery
> Loop / 外側 Evolution Loop の区別・active run の harness 自己変更禁止）。
> 他文書（command / skill / 周辺 workflow docs / 実行契約）の同種記述は本正本への
> 参照とし、重複定義しない。**Phase 1 の適用制限（rollout eligibility）は本書では
> 定めず、[`rollout-policy.md`](./rollout-policy.md) を正本とする。**

---

## Phase 1: 導入先適用

適用制限（適用ドメイン・前提 2 条件・auto-approve 方針・escalate 条件）の正本は
[`rollout-policy.md`](./rollout-policy.md) を参照。

安全側不変条件の要約（承認境界は不動。rollout 段階によらず緩和しない — 詳細は
rollout-policy §5）:

| 不変条件 | 内容 |
|---------|------|
| HO 接触 = 無条件 escalate | touches-HO は W チェック結果にかかわらず常に人間へ（fail-closed。ho-paths 未解決時も全件 escalate） |
| **NO MERGE BY AI** | C-4 / merge は Human-owned 固定。escalate の自己解決禁止・対応ラウンド上限 3 |
| lite AC-8 安全側 | lite 4 軸は申告制・AND・**判定不能→false**（虚偽宣言禁止） |
| allowed_paths で HO は免れない | `allowed_paths` に HO パスを書いても escalate は免れない |

---

## 1. 位置づけ

ai-loop-workflow は、PlanGate Core（artifact / gate / validation / evidence /
stop rule）を共通の開発統制基盤とし、**ai-dev（Plan / exec / verify / PR 作成）を
内包して自律制御する実行プロファイル**である。ai-dev の工程を再実装せず共通
利用し、C-3'・CI・レビュー・修正反復によって PR を `MERGE_READY` へ収束させる。

```text
PlanGate（WF-00〜WF-07） → in-the-loop 本番統制（C-3 = Human・pre-exec。不変）
ai-loop-workflow          → on-the-loop 実行プロファイル（eligible run 限定の
                            flow → detect → escalate。適用範囲は rollout-policy）
```

PlanGate 本番フロー（WF-00〜07）を置き換えず、競合しない。どの変更・どの
リポジトリに ai-loop を適用してよいか（現在は Phase 1）は
[`rollout-policy.md`](./rollout-policy.md) が定める。

短縮表現（EPIC [#870](https://github.com/s977043/plangate/issues/870) 統合定義）:

> ai-dev は PR を作る。ai-loop は PR を完成させ、次の開発をより良くする。

---

## 2. 責務境界（5 責務・terminal state）と WF-00〜07 との関係

### 2.1 5 責務表（正本）

| レイヤー | 責務 | AI 責務の終点 |
|---|---|---|
| PlanGate Core | artifact / gate / validation / evidence / stop rule | 実行プロファイルへ提供 |
| ai-dev | PBI → Plan → C-1/C-2/C-3 → exec / verify → PR | `PR_CREATED` |
| ai-loop Delivery | C-3' → CI / review / repair | `MERGE_READY` |
| ai-loop Evolution | completed runs → candidate → experiment → improvement PR | 改善 PR の `MERGE_READY` |
| Human | 例外 C-3、HO / policy / first principles、C-4 / merge | `MERGED` |

### 2.2 terminal state 定義（Delivery 状態）

| state | 意味 | 判定主体 |
|-------|------|---------|
| `PR_CREATED` | ai-dev の AI 責務終点（PR 作成完了） | ai-dev |
| `MERGE_READY` | ai-loop Delivery の DoD 状態。**CI 全 job green かつ AI レビュー指摘全件対応完了の AND**（詳細 = §3.3 DoD） | ai-loop の DoD 判定 |
| `MERGED` | merge 完了。**Human C-4 のみが到達させる**（NO MERGE BY AI） | Human |

表記は **`MERGE_READY` に正規化**する（旧表記 merge-ready は同一概念。
本文中の「merge-ready」残置は歴史的 verbatim 引用に限る）。

### 2.3 裁定状態と Delivery 状態の語彙群区別

以下の 2 つの語彙群は**別物**であり、同列の terminal state として列挙しない:

| 語彙群 | 値 | 意味 |
|--------|----|------|
| 裁定状態（arbiter 3 値） | `AUTO_APPROVED` / `HUMAN_ESCALATED` / `BLOCKED` | C-3' 裁定（1 回の gate 判定）の終端。正本 = [`decision-table.md`](./decision-table.md) |
| Delivery 状態 | `PR_CREATED` / `MERGE_READY` / `MERGED` | run の進行段階（§2.2）。裁定ではない |

なお round limit exceeded は `HUMAN_ESCALATED` への遷移理由であり独立の
state ではない。

### 2.4 WF-00〜07 との関係

| 観点 | PlanGate（WF-00〜07） | ai-loop-workflow |
| ------ | ---------------------- | ----------------- |
| ループモデル | in-the-loop（実行前承認） | on-the-loop（逸脱時昇格） |
| 適用対象 | 全変更 | eligible run のみ（boundary=clean, lite=true — [`rollout-policy.md`](./rollout-policy.md) §4） |
| 実行ブロック | 承認前にブロック | 事前ブロックしない（flow） |
| 競合 | なし | なし |
| カバーする工程 | 開発プロセス全体（intent→要件→設計→実装→検証→handoff） | **intent 受付から `MERGE_READY`（CI 全 job green + AI レビュー指摘対応完了）まで一気通貫**。工程の実体（WF-00〜03・C-1・C-2・exec・V 系）は PlanGate と共通利用するが、**C-3（人間の計画承認）のみを AI 裁定ゲート（C-3'）に置換**し、成果の担保責任は ai-loop が持つ |
| 変更の生成 | 責務内（WF-02〜04 で要件・設計・実装を導く） | **責務内（ai-dev-workflow より広い）**。生成から「CI 通過 + AI レビュー指摘対応完了」まで一気通貫で責務を持つ。工程の実体（生成・計画そのもの）は PlanGate 資産を共通利用するが、**成果の担保**（`MERGE_READY` 到達）は ai-loop 固有の責務 |

両者は競合しない。並走期において PlanGate が本番統制を担当する
（実験稼働の範囲は [`rollout-policy.md`](./rollout-policy.md)）。

Arbiter は plan 生成・要件展開・設計（WF-01〜03）の**工程の実体**を再実装せず、
PlanGate 既存フローをそのまま利用する（EPIC #870 Non-goals: ai-loop 用に
Plan / exec / verify を別実装しない）。置き換えの対象は **C-3 のみ**であり、
C-2（2 レーン契約、`review-principles.md`
§7-bis）は不変のまま踏襲する。判断実行は L1 = RiverReview 委譲、C-4・merge
は引き続き Human-owned 固定（詳細は次節）。ただし ai-loop-workflow は
**ai-dev-workflow（AI 工程は PR 作成 = `PR_CREATED` まで、C-4 は人間）より広い
責務**を持ち、PR 作成後の CI・AI レビュー指摘対応が完了し `MERGE_READY` に
到達するまでを自らの DoD とする（詳細は §3.3）。

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
PR 作成（= PR_CREATED）
CI + AI レビュー指摘対応ループ（MERGE_READY まで）← ai-loop 固有（§3.3）
C-4・merge（= MERGED）                     ← Human-owned 固定（不変）
```

**経路の定義**: **C-3' は eligible run（lite / clean / no-merge / gates 充足）の
標準自動経路**であり、判定主体は arbiter（[`decision-table.md`](./decision-table.md)
priority 0〜6）。**Human C-3 は escalate 経路**であり、touches-HO / lite=false /
判定不能 / W チェック不一致重大時に降格する（判定主体 = Human）。

### 3.3 責務範囲（ai-dev-workflow との比較）

ai-loop-workflow の責務範囲は **intent 受付から「成果物が CI を通過し、
CI/PR 時の AI レビュー指摘への対応が完了する（= `MERGE_READY` 状態）」まで**
であり、ai-dev-workflow（AI 工程は PR 作成まで、C-4 は人間）より**広い責務**
を担保する。

| 項目 | ai-dev-workflow | ai-loop-workflow |
|------|------------------|-------------------|
| AI 責務の終点 | PR 作成（`PR_CREATED`）まで | **`MERGE_READY`**（CI green + AI レビュー指摘対応完了）まで |
| PR 後の CI 失敗対応 | 人間主導（都度） | AI が対応ループを回す（review-feedback-loop.md §2 と接続） |
| PR 後の AI レビュー指摘対応 | 人間主導（都度） | AI が採用/理由付き不採用を記録し対応完了まで担保 |
| 人間の関与 | C-3（計画承認）+ C-4（merge） | **escalate 時の判断のみ + C-4（merge）** |

**DoD（`MERGE_READY` 到達条件）**: CI 全 job green **かつ** AI レビュー指摘が
ゼロ、または全件対応完了（採用 / 理由付き不採用の記録）。これを満たして
初めて C-4 待ちに到達する。判定主体は ai-loop の DoD 判定（§2.2）。

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
記録を条件に `MERGE_READY` 判定へ進んでよい（収束保証）。

### 3.4 強化セルフレビュー（PR 作成前・必須ステップ）

`MERGE_READY` 責務を担保するため、exec / V 系完了後・PR 作成前に**強化セルフ
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

### 3.5 位置づけの整理（C-3 系正本の役割分界）

C-3 系の経路定義は以下のとおり役割分界する（二重定義ではなく階層）:

- **PlanGate 本番フロー（WF-00〜07）の C-3 系**（C-3 Autonomous APPROVE
  [#353] / C-3 条件付き降格 [F5-AD]）の正本は
  `working-context.md`
- **ai-loop 経路（C-3'）の正本は本文書**。C-3' は上記 Autonomous APPROVE /
  条件付き降格の判定を decision table + provenance で完全機械化した、
  ai-loop Delivery 限定の別経路である

escalate は従来の人間 C-3 への降格であり、**承認境界の撤廃ではない**。
touches-HO は W チェック結果にかかわらず常に人間へ固定
（[`concept.md`](./concept.md) §5「不変の原則」参照）。

### 3.6 C-3' と WF-00〜07 不変の両立規定

以下の 2 点は恒久 invariant である:

1. **PlanGate 本番フロー（WF-00〜07）の C-3 は常に Human・pre-exec のまま不変**。
   `core-contract.md` §3
   （approve-wait = c3.json APPROVED）を含む実行契約は C-3' の導入によって
   変更されない
2. **C-3' は ai-loop Delivery（eligible run）に限る別経路**であり、
   PlanGate C-3 を置換しない

両経路の入口分岐から terminal state までの順序:

```text
                      変更 Request（intent 受付）
                               │
              ┌── 入口分岐: eligible run か？ ──┐
              │  （rollout-policy.md §4:        │
              │   boundary=clean AND lite=true） │
        No（本番フロー /               Yes（ai-loop Delivery）
        escalate / 判定不能）                    │
              │                                  │
     PlanGate WF-00〜07                WF-00〜03 / C-1 / C-2（共通）
     C-3 = Human・pre-exec ◄──────┐              │
     （常に不変）                 │      C-3'（arbiter 裁定）
              │                   │       ├─ AUTO_APPROVED ──► exec
              │                   └────── HUMAN_ESCALATED（降格）
              │                           （BLOCKED は run 停止）
              ▼                                  ▼
            exec                        exec / V 系 / PR 作成
              │                                  │  = PR_CREATED
              ▼                                  ▼
        PR 作成 = PR_CREATED           CI + AI レビュー対応ループ
              │                                  │  = MERGE_READY
              └──────────► C-4 / merge ◄─────────┘
                     （Human-owned 固定 = MERGED）
```

---

## 4. 内側 Delivery Loop / 外側 Evolution Loop と 6 層自己改善ループ

### 4.1 内側 / 外側の区別

| Loop | 範囲 | 責務レイヤー（§2.1） |
|------|------|---------------------|
| **内側 Delivery Loop** | 1 run: Request → Plan → C-3' → exec → PR → CI/レビュー対応 → `MERGE_READY` | ai-loop Delivery |
| **外側 Evolution Loop** | completed runs → candidate → experiment → improvement PR（改善 PR の `MERGE_READY`） | ai-loop Evolution |

**active run の harness 自己変更禁止**: active run は開始時の harness
（実行規則・gate・policy・`harness_version`）を最後まで保持し、run の途中で
自己変更しない。改善は外側 Evolution Loop で**別 TASK / Plan / PR** として
行い、改善 PR も C-4（Human merge）を経て次回以降の run にのみ反映される。

### 4.2 6 層自己改善ループとの関係

ai-loop-workflow は、eligible run の範囲で（適用制限 =
[`rollout-policy.md`](./rollout-policy.md)）、
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
承認境界そのものを自己変更しない（§4.1 の harness 自己変更禁止と一体）。

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

- [`docs/workflows/ai-loop/rollout-policy.md`](./rollout-policy.md) — **Phase 1 適用制限（rollout eligibility）の正本**
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
- `working-context.md` — C-3 Autonomous APPROVE（#353）・C-3 条件付き降格（F5-AD）の正本（PlanGate 本番フロー側 — §3.5 の役割分界参照）
