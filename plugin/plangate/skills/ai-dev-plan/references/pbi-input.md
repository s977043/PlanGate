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
- Source / feedback refs: {user feedback / Issue / RunEvidence / FailureRecord / measurement / existing behavior など。raw transcript は貼らない}
- Problem evidence refs（material な場合）: {問題設定を支持する evidence ref}

#### Requirement Discovery Trace（material な場合）

| Requirement ID | Goal / Problem | Evidence / Source | Related AC |
| --- | --- | --- | --- |
| REQ-001 | {何を解くための要求か} | {ref / provenance} | AC-01 |

> この表には policy 上 accepted と扱える Requirement だけを置く。candidate / unresolved は下の Unknowns に残し、Plan 側で補完・創作しない。

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
