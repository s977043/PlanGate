---
task_id: TASK-0142
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-07-05
author: bookkeeping (事後発行)
v1_release: "079ea85 (PR#617) / v8.15.0"
---

> **本 handoff はマージ後の事後発行（bookkeeping）である。** TASK-0142 の実装
> （PR #617）は 2026-06-23 に main へマージ済みだが、WF-05 の必須成果物である
> handoff.md が未発行のまま current-state.md が stale（フェーズ: A — PBI INPUT
> 作成中）を表示し続けていた。本ファイルは pbi-input.md / plan.md /
> test-cases.md / todo.md / review-self.md とマージ済み PR #617 を一次証跡として
> 事後再構成したものであり、実装当時にリアルタイムで作成されたものではない。

# Handoff Package — TASK-0142

## メタ情報

```yaml
task: TASK-0142
related_issue: https://github.com/s977043/plangate/issues/493
follow_up_issue: https://github.com/s977043/plangate/issues/651
author: bookkeeping (事後発行 / 元セッションは orchestrator C-1 実施)
issued_at: 2026-07-05
v1_release: 079ea85 (PR#617 マージコミット / main ブランチ / v8.15.0 タグに包含)
```

## 1. 要件適合確認結果

| 受入基準                                                                                               | 判定 | 根拠 / コメント                                                                                                                                                                                                          |
| ------------------------------------------------------------------------------------------------------ | ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| AC-1: `docs/workflows/07_exploratory_debug.md` が存在し、探索ループ・待機・修正ゲートの3要件を定義する | PASS | ファイル実在確認済み（140 行、PR#617 diff）。Phase E-1（探索ループ）/ Phase E-2（`waiting_external_verification`）/ インシデント駆動の計画修正の3節を確認                                                                |
| AC-2: `docs/workflows/README.md` に WF-07 が追記される                                                 | PASS | `README.md` L22 に `**WF-07** Exploratory Debug（opt-in・既定OFF）` 行を確認                                                                                                                                             |
| AC-3: `docs/workflows/execution-sequence.md` に探索モード分岐が追記される                              | PASS | `execution-sequence.md` L88〜116 に「探索モード分岐（WF-07 opt-in）」節を確認                                                                                                                                            |
| AC-4: markdownlint PASS（L-0）                                                                         | PASS | PR#617 内 fix commit（"fix: markdownlint errors in WF-07 and execution-sequence" — MD032/MD031/MD040/MD012 解消）+ CI `Markdown lint` check = SUCCESS（`gh pr view 617` statusCheckRollup で確認、2026-06-23 completed） |

**総合**: 4/4 基準 PASS

**FAIL / WARN の扱い**: 全 AC PASS。C-1（review-self.md）の WARN-01（ToDo の完了判定基準がやや暗黙的）は minor・test-cases.md で補完済みとして exec 継続が承認されている。

## 2. 既知課題一覧

| 課題                                                                                                  | Severity | 状態                                     | V2 候補か                       |
| ----------------------------------------------------------------------------------------------------- | -------- | ---------------------------------------- | ------------------------------- |
| todo.md A-06〜A-08 の完了判定基準が test-cases.md 参照前提で暗黙的（review-self.md WARN-01）          | minor    | accepted（test-cases.md で実質補完済み） | No                              |
| WF-07 は opt-in 定義のみで、WF-00 Intent Intake からの自動判定・advisory 接続は本 PBI の Out of scope | info     | accepted                                 | Yes（後続 #651 で一部対応済み） |
| acceptance-tester / workflow-conductor.md への WF-07 組み込み（HO 対象）は未実施                      | minor    | open                                     | Yes                             |

**Critical 課題の対応**: Critical open 課題なし。

## 3. V2 候補

| V2 候補                                                    | 理由                                                           | 推定優先度 | 関連 Issue         |
| ---------------------------------------------------------- | -------------------------------------------------------------- | ---------- | ------------------ |
| acceptance-tester エージェントの WF-07 対応改修            | HO 対象（`.claude/agents/*.md`）のため本 PBI は Out of scope   | Medium     | #493               |
| workflow-conductor.md の WF-07 分岐組み込み                | HO 対象のため本 PBI は Out of scope                            | Medium     | #493               |
| PBI-493-01（長時間検証の bin/plangate コマンド化）         | bin/plangate は HO 対象、本 PBI は docs 先行定義のみ           | Medium     | #493               |
| PBI-493-03（検証失敗ゲートの機械的強制）                   | 機械強制は hook/CLI 実装が前提、本 PBI は docs 段階            | Low        | #493               |
| exploratory intent 8 分類化・hypothesis-logger・WF-07 接続 | 本 PBI の直接後続として **#651 で既に着手・現時点 Unreleased** | High       | #651（Unreleased） |

## 4. 妥協点

| 選択した実装                                                                              | 諦めた代替案                                    | 理由                                                                                                                                                                                |
| ----------------------------------------------------------------------------------------- | ----------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| doc-light / light モードで docs のみ先行定義                                              | 実装（hook/CLI/agent 改修）まで一括で行う       | HO 対象ファイル（agents/workflow-conductor.md/bin/plangate）への変更は別 PBI・別承認が必要なため、docs 先行定義で独立して価値を出す方針を選択（pbi-input.md Notes from Refinement） |
| WF-07 を WF-01〜06 と同列の opt-in ワークフローとして新設                                 | 既存 WF-00〜06 のいずれかに探索ループを埋め込む | 「要件が固まってから計画」前提の既存フローと「探索しながら学習」の性質が異なるため独立フェーズとして分離。既定 OFF（opt-in）とすることで既存 run の挙動を変えない                   |
| `waiting_external_verification` を working-context.md §BLOCKED の拡張フィールドとして設計 | 独自の新規状態機械を新設                        | 既存 BLOCKED 状態（#498 由来）との重複を避け、フィールド追加で連携させる方が保守性が高いため                                                                                        |

## 5. 引き継ぎ文書

### 概要

TASK-0142 は issue #493「探索的デバッグタスク対応強化」の PBI-493-02 として、
「仮説→検証→学習→AC 更新」の探索ループ・長時間外部検証待機・インシデント駆動の
計画修正の3要件を docs のみで先行定義した（WF-07 新設）。PR #617（コミット
079ea85）で main へマージ済み、v8.15.0 リリースタグに包含されている。

本 handoff は bookkeeping セッション（2026-07-05）による事後発行である。
current-state.md が「フェーズ: A — PBI INPUT 作成中」のまま stale 表示していたが、
実装は既に完了・main マージ・リリース済みであることを git 証跡（`merge-base
--is-ancestor 079ea85 main` / `v8.15.0` 両 PASS）と GitHub PR CI 結果
（`gh pr view 617` 全 check SUCCESS）で確認し、本ファイルと current-state.md を
是正した。

### 触れないでほしいファイル

- `docs/workflows/07_exploratory_debug.md`: WF-07 の正本。番号衝突（06 と 07）を
  避けるため既存 WF-06（`06_retro.md`）との整合を保つこと
- `docs/workflows/execution-sequence.md` L88〜116: 探索モード分岐節。他モード分岐
  と構造を揃えているため、変更時は既存フォーマットに従うこと

### 次に手を入れるなら

- 後続 issue #651（exploratory intent 8分類化 + hypothesis-logger スキル +
  WF-00 advisory 接続）が既に着手されている（現時点 Unreleased、CHANGELOG
  Unreleased セクション参照）。次の担当者はまず #651 の状態を確認すること
- acceptance-tester / workflow-conductor.md への WF-07 組み込みは HO 対象のため
  別 PBI として計画すること（apply-script パターンを踏む）
- PBI-493-01（長時間検証の bin/plangate コマンド）は bin/plangate が HO 対象の
  ため、TASK-0141/0143 で確立された apply-script + Human 適用パターンを踏襲する

### 参照リンク

- 親 issue: https://github.com/s977043/plangate/issues/493
- 後続 issue（Unreleased）: https://github.com/s977043/plangate/issues/651
- PR#617: https://github.com/s977043/plangate/pull/617
- pbi-input.md: `docs/working/TASK-0142/pbi-input.md`
- plan.md: `docs/working/TASK-0142/plan.md`
- review-self.md: `docs/working/TASK-0142/review-self.md`

## 6. テスト結果サマリ

> 本 PBI は docs のみの変更（doc-light）のため Unit/Integration/E2E のコード
> テストは対象外。V-1（ファイル存在 + 内容確認）と L-0（markdownlint）が
> テスト戦略の全てであり、**マージ済み PR #617 の CI PASS 実績を根拠に事後記載**
> する（実行ログの新規捏造ではなく `gh pr view 617` の statusCheckRollup を一次
> 証跡として引用）。

| チェック（CI）                   | 結果    | 完了時刻                         |
| -------------------------------- | ------- | -------------------------------- |
| Markdown lint（L-0 / AC-4）      | SUCCESS | 2026-06-23T08:34:08Z             |
| plangate CLI tests               | SUCCESS | 2026-06-23T08:34:35Z             |
| settings wiring drift            | SUCCESS | 2026-06-23T08:34:08Z             |
| SKIP_REASON 追認                 | SUCCESS | 2026-06-23T08:34:08Z             |
| CodeQL (Analyze python / CodeQL) | SUCCESS | 2026-06-23T08:34:56Z / 08:34:50Z |
| Check PR Issue Link              | SUCCESS | 2026-06-23T08:34:11Z             |

**V-1（手動 / grep 確認, TC-01〜05）**: 本 bookkeeping セッションで再実施し PASS
確認（AC-1〜3 のファイル内容・grep 結果は本 handoff §1 に記載のとおり）。

**FAIL / SKIP の詳細**: なし。

## 7. Metrics summary

該当なし（metrics --collect 未実施、doc-light PBI のため opt-out）
