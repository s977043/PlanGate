# EXECUTION PLAN — TASK-0142

## Goal

issue #493 PBI-493-02。探索的デバッグ対応の docs 先行定義。
WF-07（探索ループ・長時間外部検証待機・インシデント駆動 AC 更新）を新設し、
既存 WF と連携できる状態にする。

## Constraints / Non-goals

- docs（`docs/workflows/`）のみ変更、HO パス非対象
- acceptance-tester / workflow-conductor.md の改修は別 PBI
- bin/plangate への待機コマンド追加は別 PBI（PBI-493-01）

## Approach Overview

doc-light モードで WF-07 を新設し、README.md と execution-sequence.md に参照を追加する。
WF-07 は WF-01〜06 と同列の opt-in ワークフローとして位置づける。

## Work Breakdown

### Step 1: WF-07 ドキュメント新設

Output: `docs/workflows/07_exploratory_debug.md`

内容:
- 目的（探索的タスクへの対応）
- 3 フェーズ定義:
  - 探索ループ（仮説→検証→学習→AC 更新）
  - 長時間外部検証待機（`waiting_external_verification` / BLOCKED 連携）
  - インシデント駆動の計画修正（検証失敗→AC 改訂フロー）
- 既存 WF との接続（WF-00 Intent Intake から分岐する条件）
- 完了条件
- 呼び出す Skill（既存 acceptance-review / doc 追加のみ）

Owner: AI

### Step 2: README.md 更新

Output: `docs/workflows/README.md`（既存に WF-07 行を追加）

Owner: AI

### Step 3: execution-sequence.md 更新

Output: `docs/workflows/execution-sequence.md`（探索モード分岐を追記）

Owner: AI

### Step 4: L-0 リンター

sh scripts/lint.sh または markdownlint

Owner: AI

## Files / Components to Touch

- `docs/workflows/07_exploratory_debug.md`  (新規)
- `docs/workflows/README.md`                (追記)
- `docs/workflows/execution-sequence.md`    (追記)

## Testing Strategy

- L-0: markdownlint PASS（AC-4）
- V-1: ファイル存在 + 内容確認（3要件が定義されているか）
- E2E: 不要（docs のみ）

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| markdownlint 違反 | 書き方を既存 WF-06 に合わせる |
| リンク切れ | 相互参照は相対パスで記述、L-0 で確認 |

## Mode 判定

**モード**: light
**変更種別**: doc
**doc-light**: ✅（docs/workflows/ のみ、HO 非対象）
**lite_eligible**: true（既存構造の枠内、新規設計ゼロ・doc 追加のみ）

**判定根拠**:
- 変更ファイル数: 3 → light
- 受入基準数: 4 → light
- 変更種別: doc → doc-light
- リスク: 低（HO なし）
- **最終判定**: light / doc-light
