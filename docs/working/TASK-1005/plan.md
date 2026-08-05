---
task_id: TASK-1005
artifact_type: plan
schema_version: 1
status: draft
mode: high-risk
related_issue: https://github.com/s977043/PlanGate/issues/1005
created_by: orchestrator
---

# TASK-1005 Implementation Plan

## Goal

PlanGate の finding 記録能力を維持したまま Human-owned admission control と WIP 制限を導入し、信用可能な Minimum Trust Kernel を作ったうえで #978 を完全な縦切りとして流せる実行契約を確立する。

## Context

- 関連Issue: [#1005](https://github.com/s977043/PlanGate/issues/1005)
- 関連artifact:
  - [`pbi-input.md`](./pbi-input.md)
  - [`todo.md`](./todo.md)
  - [`test-cases.md`](./test-cases.md)
  - [`decision-log.jsonl`](./decision-log.jsonl)
- 実測:
  - open 48 / plan 到達 2 / pbi-input のみ 19 / workdir なし 27
  - 46/48（95.8%）が plan 未到達
  - 33/48（68.8%）が起票後未更新
  - 8 月 1〜4 日の純増 +13（+2.9 件/日）
- 中核制約:
  - C-3 / C-4 / merge は Human-only
  - rules / settings / hooks / CI 等は HO として Human apply
  - development flow 自体が成果物であり、検査の誤成功は product failure と同義

## Scope

### In Scope

- backlog admission control の正本ドキュメント
- lifecycle state と promotion contract
- WIP limit と stop rule
- Reliability Recovery 1 の sequence / entry / exit contract
- Issue / PR Discovery Log と follow-up split contract
- Issue writeback DoD
- flow metrics の定義
- #921 / #997 / #994 / #942 / #978 への execution writeback
- Human が既存 milestone commitment を 6〜8 件へ裁定するための候補表

### Out of Scope

- C-3 前の test / hook / CLI / CI 実装
- label の破壊的一括変更
- 48 Issue の自動再分類
- GitHub ruleset / branch protection の変更
- #906 / #916 の実装
- 大型構想 9 件の採否決定

## Global Constraints

- `NO MERGE BY AI`、C-3、C-4を変更しない
- lifecycle は GitHub の `open/closed` と独立した意味を持つ
- priority と commitment を同一視しない
- Issue を close するために未充足 AC を無条件で follow-up へ移さない
- negative control は「テストコードが存在する」ではなく「修正前実装または意図的変異を実際に落とした証拠」を要求する
- HO path は AI が直接適用しない。patch、影響、rollback、確認手順を成果物として Human に渡す
- 新規 dependency を追加しない
- 変更対象外ファイルが必要になった場合は exec を止めて replan する

## 前提の実測検証

| 前提 | 検証方法 | 実測結果 | 判定 |
|---|---|---|---|
| backlog の主滞留は implementation より前 | 48 Issue の artifact 状態棚卸し | plan 2 / pbi-input 19 / no workdir 27 | ✅ |
| 7 月は処理能力低下だけでは説明できない | 月次 opened / closed 比較 | close 52→85、open 51→120 | ✅ |
| #921 は後続 negative control の load-bearing dependency | Issue 本文と再現ログ | 7 FAIL でも exit 0 の実測あり | ✅ |
| #997 は対象 operation ではなく absolute dirty state を見ている | test body / reproduction | unrelated untracked file で唯一 FAIL | ✅ |
| #978 は downstream HO 未定義を fail-closed にできていない | Issue reproduction | bundled template 21 patterns で downstream path が clean | ✅ |
| C-3 前の implementation は禁止 | CONTRIBUTING workflow | plan→Human C-3→exec の順序 | ✅ |

## Questions / Unknowns

- lifecycle state の実装を既存 label の組み合わせで表現するか、新規 `state:*` label を作るか。Human が C-3 で決定する
- milestone 9 から外す対象。Issue の重要度ではなく「このサイクルで commitment するか」の Human 判断が必要
- #978 の downstream context 判定に利用可能な既存 repository marker。exec 前に `arbiter.py` と run contract を実測し、なければ explicit execution context を plan 差分として C-3 再確認する
- metrics の取得元。既存 GitHub metadata と events で足りないものは、まず手動台帳で2サイクル測定し、自動化は別 PBI とする

## Approach Comparison

| 案 | 内容 | メリット | デメリット | 判定 |
|---|---|---|---|---|
| A | issue 作成を凍結 | 即時に open 純増を止める | finding を失い品質低下、実走改善ループを壊す | 不採用 |
| B | open issue を全て同一 backlog のまま優先順位だけ付ける | 変更コストが小さい | maturity と commitment が混在し、現状を再生産 | 不採用 |
| C | Discovery / Qualified / Committed に分離し promotion と WIP を Human-owned にする | 発見を保存しながら実行キューを制御、ボトルネック可視化 | triage と状態更新の運用コスト | 採用 |
| D | test foundation 8件を全完了してから本線 | baseline を広く修復 | 整備だけで停止、実走 feedback が遅い | 不採用 |
| E | #921 + negative control 2種を minimum entry とし #978 を縦切り | 信頼性と価値実走を早期に両立 | 一部 foundation は後続に残る | 採用 |

### Recommended Approach

案 C + E を採用する。

Admission Control は finding generation と implementation commitment を分離し、AI 並列度ではなく Human decision throughput に合わせる。Reliability Recovery は一括基盤刷新ではなく、#921 で failure propagation を回復し、異なる欠陥クラスの negative control を2つ成立させた時点で #978 を流す。これにより「整えるだけで完了」が構造上できない。

## Lifecycle State Machine

```text
Finding
  │ record
  ▼
Discovery
  │ Human triage: evidence / invariant / delta / independent AC
  ├── reject / park / merge into parent
  ▼
Qualified
  │ Human commitment: artifacts / dependencies / capacity / milestone
  ▼
Committed
  │ plan → C-1/C-2 → Human C-3
  ▼
In Progress
  │ verify → PR → Human C-4
  ▼
Delivered
  │ Issue writeback transaction
  ▼
Fully Satisfied / Partial / RFC / Not Planned
```

### Promotion Rules

#### Discovery → Qualified

全項目必須:

1. Current / Expected / Delta
2. reproduction or primary evidence
3. affected invariant / operational outcome
4. existing implementation / related Issue / PR check
5. independent Issue rationale
6. verifiable AC
7. negative control design for guard/test changes
8. cost of not doing

#### Qualified → Committed

全項目必須:

1. pbi-input / plan / todo / test-cases
2. dependency and file-conflict map
3. completion boundary
4. HO classification
5. C-1/C-2 readiness
6. milestone capacity within limit
7. Human explicit commitment

### WIP Stop Rule

いずれかの上限到達時、新規 promotion / start を止める。既存 WIP の unblock、review、writeback を優先する。

| Queue | Limit |
|---|---:|
| Plan authoring | 2 |
| C-3 waiting | 2 |
| Implementation | 2 |
| C-4 waiting | 2 |
| Milestone committed | 8 maximum; target 6 |

緊急割込みは Human が既存 item を decommit して slot を空ける。上限を単に +1 しない。

## Reliability Recovery 1 Design

### Work Package RR1-A: Failure Signal Integrity — #921

**Invariant**: standalone test が内部 failure を観測した場合、process exit status は非ゼロでなければならない。source された test は runner を exit してはならない。

**Design constraints**:

- file count hardcoding 禁止
- standalone detection は既存 canonical contract を利用
- common footer/helper の導入は source safety と shell portability を証明できる場合のみ
- representative-only test を採用する場合も、全対象 file が契約実装済みである静的/動的 inventory check を併用

**Negative controls**:

- fixture / env を意図的に壊して `[FAIL]` を発生させ、standalone rc != 0
- 同じ file を harness source し、runner が途中 exit せず failure count を集計
- footer を1本から除去する mutation が inventory test で FAIL

### Work Package RR1-B: Observation Fidelity — #997 / #947 / #994

**Invariant**: test は operation が生んだ変化と、実行前から存在する状態を区別し、題目に対応する構造だけを観測する。

#997 推奨設計:

- `_classify()` 前に対象 existing record の `{relative_path: sha256(content)}` snapshot
- `_classify()` 後に同じ対象集合を snapshot
- mapping equality を assert
- pre-existing untracked run file は対象既存 record でなければ許容
- mutation helper で record 1 byte rewrite を注入し FAIL を実証

#947 分割:

- ta-54 absolute dirty check は #997 と同じ before/after invariant
- SKIP accounting は pass と分離し summary / exit contract をテスト
- interruption residue は cleanup trap と next-run isolation を独立検証
- root cause が異なるため、同一 Issue 内でも commit / test evidence を分離

#994 推奨設計:

- source file 全体の token existence を判定しない
- target `if` condition を line continuation 込みで正規化して parse/check
- `PG_HARNESS_SOURCED && FIXTURES_DIR` の conjunction を要求
- unset line に token が残っても condition mutation を検出

### Work Package RR1-C: Guard/Action Set Symmetry — #991 / #970

**Invariant**: guard が評価する集合と action が変更・削除する集合は同じ canonical enumerator から得る。

- canonical side ごとに existence / expected count / stale count を評価
- aggregate relative threshold だけで片側全損を許可しない
- symlink exclusion、file extension、expected manifest を action loop と共有
- mutations: one-side empty、symlink-only destination、1 valid stale、override on/off

### Work Package RR1-D: CI Reachability — #942

**Invariant**: local test の存在ではなく、PR CI が必要な base/history を取得し対象違反で赤になる。

AI deliverable:

- workflow patch proposal
- event別 SHA resolution table
- permissions / fetch depth impact
- rollback patch
- negative PR scenario

Human deliverable:

- HO apply
- protected path intentional change の test PR
- expected check failure を evidence 保存
- patch restore / valid PR green の確認

### Work Package RR1-E: Vertical Slice — #978

**Start gate**:

- #921 AC-1〜AC-4 相当が完了
- #997/#994/#991 のうち異なる2クラスで mutation evidence が成立
- committed WIP < 2
- Human C-3

**Initial design boundary**:

```python
class HoPathsSourceKind(str, Enum):
    EXPLICIT = "explicit"
    DOWNSTREAM = "downstream"
    BUNDLED_TEMPLATE = "bundled_template"

@dataclass(frozen=True)
class ResolvedHoPaths:
    path: Path
    source_kind: HoPathsSourceKind
    patterns: tuple[str, ...]
```

- resolver は path だけでなく provenance を返す
- downstream execution で `BUNDLED_TEMPLATE` のみの場合は patterns 非空でも fail-closed
- outcome は `HUMAN_ESCALATED` と理由コード `HO_BOUNDARY_UNDEFINED` を持つ
- record に source path / source kind / execution context / decision reason を保存
- PlanGate self-run は bundled template を正当 source として回帰維持
- repository identity の暗黙推測を追加しない。既存 explicit context がなければ plan を差分改訂して Human 判断

**Excluded**:

- domain-gate §2 evaluator (#906)
- common escalate path engine (#916)
- ho-paths format migration

## Files / Interfaces

TASK-1005 自体の plan 実装で変更候補となるファイル:

| ファイル | 操作 | 目的 |
|---|---|---|
| `docs/pages/guides/governance/backlog-admission-control.md` | create | lifecycle / promotion / WIP / follow-up / writeback 正本 |
| `docs/pages/guides/governance/issue-governance.md` または現行正本 | modify | 新正本への導線。実在パスを exec 前に確定 |
| `.github/ISSUE_TEMPLATE/*` | Human apply candidate | Discovery / qualification fields。HO 判定後に別 Task 化可 |
| `docs/working/TASK-1005/status.md` | create | 2 cycle metrics と execution status |
| 対象 Issue comments | writeback | execution order / gate / evidence contract |

個別修復 Issue の実装ファイルは各 Issue の独立 plan で確定し、TASK-1005 から直接変更しない。

## Work Breakdown

### Task 1: Governance 正本を作る

**Purpose**: lifecycle、promotion、WIP、stop rule、follow-up、writeback を単一正本にする。

**Steps**:

- [ ] 現行 issue governance 文書と label 規約の実在パスを検索
- [ ] 重複正本を作らず、既存正本の拡張または明示的 successor を選ぶ
- [ ] state machine と promotion checklist を記述
- [ ] WIP exceed / emergency interrupt / decommit を記述
- [ ] Discovery Log template と scope split record を記述
- [ ] completion class と Issue writeback template を記述

**Completion Criteria**:

- [ ] AC-01 / AC-02 / AC-07 / AC-08 / AC-09 を満たす
- [ ] priority / milestone / lifecycle の意味が混同されない
- [ ] Human-owned decisions が明記される

**Rollback**: new doc と導線 commit を revert。既存 label / milestone data は変更しない。

### Task 2: Reliability Recovery 1 の execution contract を固定する

**Purpose**: 6〜8 件以内の候補、開始 gate、Exit Criteria、negative control を固定する。

**Steps**:

- [ ] #921、#947、#997、#994、#991、#970、#942、#978 の file/dependency map を各 plan 作成時に再実測
- [ ] Milestone 9 の current committed list を Human review 用に表にする
- [ ] #921 を最初の plan slot に置く
- [ ] #997/#994/#991 から異なる2クラスを negative-control slot に選ぶ
- [ ] #978 の start gate と non-goals を固定
- [ ] #942 の AI/Human handoff package を定義

**Completion Criteria**:

- [ ] AC-03〜AC-06 を満たす
- [ ] foundation 全完了待ちになっていない
- [ ] 6〜8 の上限を超えない

**Rollback**: sequence comment / doc を revert。各 Issue の実装は未開始のためコード rollback 不要。

### Task 3: Issue writeback

**Purpose**: 次の agent が依存と検証契約を再調査しない状態にする。

**Targets**:

- #921: RR1 first / failure signal dependency
- #997: content hash before/after + mutation
- #994: target condition parsing + mutation
- #942: HO handoff + real CI negative PR
- #978: vertical slice gate / source provenance boundary

**Completion Criteria**:

- [ ] AC-11 を満たす
- [ ] 各 comment に #1005 link、entry condition、out-of-scope、required evidence がある

**Rollback**: 誤りがあれば comment 追記で supersede。履歴を削除しない。

### Task 4: 2-cycle measurement

**Purpose**: WIP limit を推測ではなく実測で再設定する。

**Steps**:

- [ ] status.md に cycle start/end と queue timestamps を記録
- [ ] fully satisfied と partial を分ける
- [ ] follow-up origin を記録
- [ ] Human wait time と active work time を分ける
- [ ] 2 cycle 後に limit keep / decrease / increase を Human が判断

**Completion Criteria**:

- [ ] AC-10 を満たす
- [ ] limit 変更理由が metric と結びつく

## Verification Plan

| 種別 | 確認方法 | 期待結果 | Evidence |
|---|---|---|---|
| Doc structure | markdown lint / link check | 0 errors | `evidence/verification/` |
| Contract review | Given/When/Then cases in test-cases.md | 全ケースで一意な判定 | `test-cases.md` |
| Issue writeback | 5 target Issue comments | required fields present | GitHub comments |
| WIP simulation | queue examples 6 cases | limit / interrupt / decommit が曖昧でない | `evidence/manual/` |
| Negative control design | each RR item checklist | mutation target / expected fail / restore が明記 | Issue plan/evidence |
| Human boundary | source scan / review | AI approval/merge path なし | C-2 review |

## レビューレーン計画

| 成果物 | レーン | unavailable 時の代替 |
|---|---|---|
| admission control doc | agile flow / governance reviewer + maintainer usability reviewer | independent LLM reviewer + Human |
| RR1 sequence | test architecture reviewer + security/approval-boundary reviewer | River Review gates + Human |
| #978 boundary | fail-closed security reviewer + implementation maintainer | Codex/Claude independent review + Human |

## Plan Review Readiness

### Success Criteria

- AC mapping: `test-cases.md` TC-01〜TC-16
- Completion boundary: governance contract とIssue writebackが完了し、C-3 後に各個別 Issue plan を順次実行可能。個別 code fix の完了は TASK-1005 自体には含めない

### Review Criteria

- Design alignment: Human gate / auditability / fail-closed / dogfooding と整合
- Test expectations: negative control が修正前を落とすこと
- Security: approval boundary を弱めない、HO apply をAI化しない
- Maintainability: state、priority、milestone、completion class の責務を分離
- Backward compatibility: 既存 open Issue を自動 close / reclassify しない
- Operational risk: governance overhead が throughput を上回らないよう2-cycle review

### Required Context

- Issues: #921 #947 #997 #994 #991 #970 #942 #978 #1005
- Docs: README、CONTRIBUTING、working-context、review principles、現行 issue governance 正本
- Constraints: HO paths、C-3/C-4、NO MERGE BY AI、milestone 9

### Non-goals and Scope Boundary

- Change-prohibited zones: `.github/workflows/**`, `.claude/rules/**`, settings, hooks は本 TASK の自動 apply 対象外
- Forbidden new dependencies: 全て

## Replan Triggers

- 現行 issue governance 正本が本 plan と矛盾する
- lifecycle labels が既に別の意味で運用されている
- #921 が単独修復できず runner architecture の変更を要求する
- #978 の context 判定に新 public contract / schema が必要
- committed list を6〜8へ絞ると release blocker が外れる
- plan外の HO file apply が必要
- negative control が修正前実装で再現しない

## Stop Condition

- C-3 前に governance implementation または個別 fix を開始する必要がある
- Human-only decision を AI が代替する必要がある
- destructive bulk update / close / label replacement が必要
- rollback不能な ruleset / permission change が必要
- AC と現行正本が両立しない

## Human Approval Boundary

- lifecycle label の新設・正式名称
- milestone 9 の Committed 6〜8 件
- C-3 / C-4 / merge
- HO patch apply
- scope reduction / not planned / RFC migration
- WIP limit の2-cycle後の変更

## C-1 Self Review Checklist

- [x] AC と Work Breakdown を対応付けた
- [x] foundation 全完了待ちを避ける #978 start gate を定義した
- [x] negative control を検出力証拠として定義した
- [x] Human-only boundary を維持した
- [x] destructive bulk action を除外した
- [x] rollback と replan / stop condition を記述した
- [ ] 現行 governance 正本の実在パスを exec 前に確認する
- [ ] C-2 独立レビューを実施する
- [ ] Human C-3 を得る
