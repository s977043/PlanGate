# PBI INPUT PACKAGE: {タイトル}

> フェーズ A（PBI INPUT）で作成する。**Human / AI のどちらが作成してもよい**。AI は user feedback / Issue / RunEvidence / FailureRecord / operational observation 等から生成・更新できる。正本: `working-context.md` の「pbi-input.md」節。

## Context / Why

{なぜやるか。ユーザーの課題・目的。「便利だから」ではなく課題ベースで書く}

### Bounded Discovery

> Discovery depth は変更量ではなく uncertainty / impact / irreversibility / evidence quality で調整する。
> **minimal** では既存の Context / Why・Scope・AC・Unknowns だけでよく、下表を無理に埋めない。
> **expanded discovery で Requirement の出所が material な場合**だけ Trace を使う。
> AI は candidate / question / evidence gap の提案だけでなく本 artifact を作成・更新してよい。author identity を authority の根拠にせず、Evidence / provenance / uncertainty / policy で判断する。未確認事項を黙って Requirement に昇格させない。

- Discovery depth: minimal / expanded
- Actor / Job（material な場合）: {誰の、どの状況・仕事か}
- PBI author: human / ai / mixed
- Application timing: follow_up / replan_current
- Target layer: delivery / harness
- Source run / failure refs（ある場合）: {run_id / FailureRecord / RunEvidence refs}
- HarnessImprovementCandidate ref（Target layer = harness の場合。draft 時は pending 可、Plan / implementation readiness 前に必須）: {candidate ref / pending}
- Problem evidence refs（material な場合）: {問題設定を支持する evidence ref}

#### Source / Feedback Provenance（material な場合）

| Source Ref | Source Kind | Claim Class | Supports |
| --- | --- | --- | --- |
| {ref} | human_feedback / issue / run_evidence / failure_record / measurement / existing_behavior / external_source / policy | observed / reported / inferred | Goal / Problem / REQ-001 / AC-01 |

> `observed` = artifact / measurement / verifier で直接確認、`reported` = Human / external source の報告、`inferred` = source から導出した仮説・解釈。
> `follow_up` は current Run を変更しない。`replan_current` は delivery の Replan / Plan Verification / Plan Gate を通す。`Target layer = harness` は必ず `follow_up` とし、`replan_current + harness` は禁止。Harness PBI は draft 時点では Candidate ref が pending でもよいが、Plan / implementation readiness 前に HarnessImprovementCandidate を upstream authority として確定し、本 PBI で evaluation contract を置き換えない。
> 要約・再生成・別 Agent の同意は source independence を増やさない。PBI 自身や downstream の Plan / Review を、この PBI の upstream Goal / Problem の独立 Evidence に循環利用しない。

#### Existing Work Check（AI-generated / expanded discovery で material な場合）

- Checked refs / queries: {既存 Issue / PBI の検索条件・確認した refs}
- Materialization decision: update_existing / link_only / create_new
- Related PBI / Issue refs: {refs}
- Decision reason: {同じ Problem / outcome か、Scope / Requirement / AC が material に違うか}

> 類似判定だけで既存 Issue / PBI を自動 close / merge しない。既存 PBI が Plan / approval と binding 済みで semantic change が必要な場合は、重複解消として書き換えず Replan / policy boundary に戻す。

#### Requirement Discovery Trace（material な場合）

| Requirement ID | Goal / Problem | Evidence / Source | Acceptance Basis | Related AC |
| --- | --- | --- | --- | --- |
| REQ-001 | {何を解くための要求か} | {ref / provenance} | evidence / explicit_decision / policy_rule | AC-01 |

> この表には policy 上 accepted と扱える Requirement だけを置く。candidate / unresolved は下の Unknowns に残し、Plan 側で補完・創作しない。`inferred` claim だけを根拠に事実認定したように書かない。

## What（Scope）

### In scope

{やること。具体的な機能・振る舞い}

### Out of scope

{やらないこと。明示的な除外範囲}

## 受入基準

- [ ] AC-01: {検証可能な粒度で書く}
- [ ] AC-02:

## Notes from Refinement

> 議論で決まったことの**要約**を記す。判断の正本は `decision-log.jsonl`（スキーマ: `decision-log-schema.md`）。
> **不採用にした案とその理由は decision-log の `alternatives_rejected`（`[{"option": "...", "rationale": "..."}]`）に構造化記録**し、ここはその参照・要約に留める（二重管理しない）。high-risk / critical / human decision では `alternatives_rejected` の記録が必須。

## Estimation Evidence

### Risks

{リスク}

### Unknowns

{不明点}

### Assumptions

{前提条件}
