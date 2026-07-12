---
task_id: TASK-0810
artifact_type: pbi-input
schema_version: 1
status: draft
related_issue: https://github.com/s977043/plangate/issues/810, https://github.com/s977043/plangate/issues/786
created_by: orchestrator
---

# TASK-0810 PBI INPUT PACKAGE

> #810（Unknown Discovery を Plan / PR 前セルフレビューへ取り込む）と #786 残タスク
> （F-3 delegation ブロック / F-5 不採用根拠必須化）を **1 PBI に統合**して実施する。
> 統合は 2026-07-12 の Human 明示決定（起草時の 2 分割案は不採用）。

## Context / Why

- #786 は Fable 実セッションの実働パターン（前提実測検証・Stop/Replan・委託契約・
  レビューレーン計画・不採用根拠の実測必須化）を plan.md テンプレート等へ還元する
  issue。F-1/F-2/F-4 は既に `docs/working/templates/plan.md` へ実装済み（commit 63f2ca6
  以降・issue コメントで実測確認済み）。**F-3（delegation ブロック）と F-5（不採用根拠
  必須化）が未実装**で残っている。
- #810 は AI coding agent の失敗要因が「実装力」から「Unknown（要件・制約・暗黙知・
  影響範囲の未解決）」へ移っているという問題意識から、Plan 作成プロトコルと PR 作成前
  セルフレビューを Unknown-aware に拡張する提案。
- 両 issue は「plan.md / C-1 / review-external.md といった同一アーティファクト群への
  追加観点」という共通の性質を持ち、テンプレート差分が競合しうるため、**単一 PBI で
  1 回のテンプレート改訂として統合実施**することが 2026-07-12 に Human 決定された
  （分割すると同一ファイルへの 2 回の非同期改訂となり、C-1/C-3 の整合コストが増える
  ため）。

## What（Scope）

### In Scope

1. **#810 Unknown Discovery の Plan/PR-前セルフレビューへの統合**
   - `docs/working/templates/plan.md` の `## Questions / Unknowns（#786）` 節を拡張し、
     #810 の出力候補（Known Facts / Assumptions / Known Unknowns / Possible Unknown
     Unknowns / Repository-Resolvable Questions / Human Decisions Required /
     Blocking Unknowns / Readiness）を構造化して持たせる
   - **Blocking Unknown 判定を C-1 セルフレビュー（17 項目チェック）の必須項目として
     追加する**（Human 決定 2: readiness ≠ ready を C-1 の gate 相当項目にする。
     `plan-quality-check` skill は advisory のまま変更しない）
   - PR 作成前セルフレビュー（`review-self.md` の C-1 相当運用）に Unknown 再検査観点
     を追加する
2. **#786 F-3: Work Breakdown への delegation ブロック**
   - `docs/working/templates/todo.md` を新規作成する（現状テンプレート未存在。
     INDEX.md は言及するが実体なし）
   - 委託タスクに `delegation:`（allowed / forbidden / report_must_include /
     verify_cmd）ブロックを持たせる。standard 以上で必須、light 以下は任意
   - #800/#797 実害（worktree isolation 下での main チェックアウトパスへの誤操作）を
     踏まえ、`verify_cmd` に「作業開始前に `pwd` が worktree 配下であることを検証し、
     以後の git・ファイル操作は worktree プレフィックスの絶対パスのみ使用」を必須項目
     として含める
3. **#786 F-5: 不採用根拠の実測必須化**
   - `review-external.md` の監査表規約に「不採用（status=不採用）は仕様引用または
     実測コマンド+結果を notes に必須とする（推測のみでの棄却は不可）」を追記する
4. **HO 対象への差分提案（AI は提案まで・適用は Human）**
   - `.claude/commands/ai-dev-workflow.md`（C-1 17 項目の正本）に、F-1（前提の実測
     検証）と Blocking Unknown gate の C-1 項目を追加する差分案
   - `.claude/rules/review-principles.md` に F-5 の運用注記（不採用根拠の実測必須化）
     と、**「AI は差分提案まで・適用は Human ワンアクション」の 1 行注記**を追加する
     差分案（Human 決定 3）
   - 上記 2 点は `.claude/rules/*.md` / `.claude/commands/*.md` = Hardening Override
     対象パスのため、本 PBI では **AI が差分（パッチ相当のテキスト）を plan.md /
     handoff.md に明示するのみ**とし、実ファイルへの適用は行わない
5. C-1 チェックリストへの Blocking Unknown gate 項目の追加（`docs/working/templates/plan.md`
   の `## C-1 Self Review Checklist` を拡張）
6. 軽量サンプル PBI での分量検証（#810 の「質問数増加の目的化防止」受入基準に対応。
   実運用サンプルで Unknown 節が過剰に膨張しないことを確認する）

### Out of Scope

- `.claude/rules/*.md` / `.claude/commands/*.md`（HO 対象）への**実適用**（Human が
  別途ワンアクションで適用）
- `plan-quality-check` skill 本体の改修（advisory のまま。gate 化しない）
- #780（6段階ループ設計）本体の実装
- #710/#715（委譲プロトコル）本体との統合実装（`delegation:` ブロックの文案は
  #710/#715 の入力になるが、本 PBI では todo.md テンプレートへの追加までとする）
- ai-loop-workflow（旧 Arbiter）への適用（本番 PlanGate WF-00〜07 のみが対象）

## 受入基準

1. `docs/working/templates/plan.md` の `## Questions / Unknowns（#786）` 節が #810 の
   8 分類（Known Facts 〜 Readiness）を持つ構造に拡張されている
2. `## C-1 Self Review Checklist` に Blocking Unknown gate 項目（readiness=ready
   でなければ C-1 は PASS にならない旨）が追加されている
3. `docs/working/templates/todo.md` が新規作成され、`delegation:`（allowed /
   forbidden / report_must_include / verify_cmd）ブロックの記法例を持つ
4. `delegation.verify_cmd` の記法例に worktree pwd 検証（#800/#797 実害由来）が
   含まれる
5. `docs/working/templates/review-external.md` の監査表規約に不採用根拠の実測必須化
   （仕様引用 or 実測コマンド+結果）が追記されている（review-external.md テンプレート
   が存在しない場合は新規作成し、既存 review-external.md 実例の規約と整合させる）
6. `.claude/commands/ai-dev-workflow.md` への C-1 項目追加差分（F-1 前提実測検証 +
   Blocking Unknown gate）が plan.md 内に明示され、Human 適用手順が示されている
7. `.claude/rules/review-principles.md` への F-5 運用注記 + 「AI は差分提案まで・
   適用は Human ワンアクション」1 行注記の差分が plan.md 内に明示され、Human 適用
   手順が示されている
8. C-1 セルフレビュー（17 項目）が実施され `review-self.md` に PASS/WARN/FAIL 判定
   が記録されている
9. Mode 判定が high-risk であり、その根拠（ゲート機構新設 + HO 接触）が明記されて
   いる
10. 軽量サンプル（ultra-light/light 相当の架空 PBI）で Unknown 節を埋めた場合の
    分量が「過剰質問化していない」と判定できる評価結果が plan.md または
    evidence に記録されている
11. #786 F-3/F-5 と #810 の対応関係（どの受入基準がどの issue のどの提案に対応する
    か）が pbi-input.md または plan.md にトレーサブルに記載されている

## Notes from Refinement（2026-07-12 決定事項）

- **1 PBI 統合**: 起草時点では #810（TASK-0810）と #786 残タスクを 2 分割する案が
  あったが、Human が明示指定で不採用とし、単一 PBI 統合を確定した
- **Blocking Unknown 判定 = C-1 checklist（gate 相当）**: readiness ≠ ready を
  C-1 セルフレビューの必須項目として扱う。`plan-quality-check` skill は
  advisory のまま変更しない（二重ゲート化を避ける）
- **review-principles.md（HO）への注記 1 行**: 「AI は差分提案まで・適用は Human
  ワンアクション」を明記し、責務 4 分類（AI-owned は提案まで・Human-owned は
  self-mod ガード対象の適用）と整合させる

## Estimation Evidence

### Risks

- テンプレート改訂が既存進行中 PBI の plan.md 生成手順と非互換にならないか
  （追加節は既存必須節を変更しないため互換性は保たれる想定だが要確認）
- Blocking Unknown gate を C-1 必須項目に追加すると、既存の C-1 17 項目カウントが
  変わる（項目追加によりチェックリスト数が変動。既存 review-self.md 実例との
  整合を要検証）
- HO 対象ファイルへの適用漏れ（AI が提案しても Human が適用し忘れる）は Shadow
  Config 相当のリスク。todo.md に Human タスクとして明示し、handoff にも残す

### Unknowns

- `.claude/commands/ai-dev-workflow.md` の C-1 17 項目の現行リスト全文（本 PBI の
  plan 作成時に読み込み、追加箇所を特定する必要がある）
- `review-external.md` テンプレートが `docs/working/templates/` に実在するかどうか
  （実在確認は plan 作成時の Repository-Resolvable Question とする）

### Assumptions

- `docs/working/templates/plan.md` の F-1/F-2/F-4 実装（#786 issue コメント記載）が
  最新 main に反映済みであること（本エージェントの読み取りで実測確認済み: 2026-07-12
  時点で該当節を確認）
