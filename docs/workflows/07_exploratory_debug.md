# WF-07 Exploratory Debug（opt-in フェーズ）

> PlanGate × Workflow/Skill/Agent ハイブリッドアーキテクチャ 実行層 / 探索フェーズ（opt-in）
> 起源: issue #493（Expo SDK 移行での 4 層入れ子障害を PlanGate で扱えなかった経験）

## 目的

「やってみて初めて問題が露呈する」探索的タスクに対し、**仮説→検証→学習→AC 更新**
のループを PlanGate の構造として扱えるようにする。

標準フロー（WF-01〜06）は「要件が固まってから計画・実装」を前提とするため、
探索的タスク・長時間外部検証を含むタスク・インシデント駆動の計画修正には本フェーズを opt-in する。

## opt-in 起動（既定 OFF）

本フェーズは **既定で発火しない**。

起動条件（いずれか）:

- C-3 承認済み pbi-input の `exploratory: true` を明示
- WF-00 Intent Intake で Mode が `exploratory` と判定される
- 探索的タスクであることを人間が明示（`/ai-dev-workflow TASK-XXXX explore`、将来 CLI）

未指定 run は WF-01〜06 の標準フローで処理される。

## 3 フェーズ定義

### Phase E-1: 探索ループ（仮説→検証→学習→AC 更新）

探索的タスクでは AC（受入基準）が固定されず、検証ごとに更新される。

**ループ構造**:

```text
仮説定義（Hypothesis）
    ↓
検証実行（Verify）
    ↓
学習（Learn）
    ↓
AC 更新（Update AC）← 前の仮説が解消されると次の層が露呈することがある
    ↓
次の仮説 or 完了
```

**運用ルール**:

- 各 `Hypothesis` は `status.md` の残タスクとして `仮説-N:` プレフィックスで記録する
- 検証結果は `evidence/exploratory/hypothesis-N-result.md` に記録する
- AC 更新時は `pbi-input.md` と `test-cases.md` に差分追記する（削除しない、append-only）
- 1 ループの完了条件は「仮説の解消または棄却が記録されたこと」

### Phase E-2: 長時間外部検証待機（waiting_external_verification）

CI / EAS ビルド / デプロイ等、20分以上かかる外部検証を含む場合のサブ状態。

**BLOCKED 状態との連携** (`working-context.md` §BLOCKED 状態 / #498 Deferred ゲート):

```text
status.md 残タスクの記録形式:
- [ ] BLOCKED: 検証タスク名
    blocker: <外部サービス名（例: EAS production build #5）>
    owner: 外部サービス / 時間経過
    unblock_condition: <完了条件（例: EAS ビルド成功 → 次仮説へ進む）>
    waiting_external_verification: true
```

**再開プロトコル**:

1. 外部検証完了後、結果を `evidence/exploratory/hypothesis-N-result.md` に記録
2. `status.md` の BLOCKED タスクを `[x]` に更新し、学習内容を記載
3. 次の仮説または完了に進む（Phase E-1 に戻る）

**上限**:

- 1 タスクあたりの外部検証待機は最大 5 回まで（5 回を超えたら根本設計を見直すゲート）

### Phase E-3: インシデント駆動の計画修正（AC 改訂フロー）

検証失敗時に spec/design を見直すフィードバックループ。

**発動条件**:

- Phase E-1 の検証が FAIL かつ「前提の誤り」が判明した場合
- 想定していなかった問題が露呈した場合（入れ子障害の発見等）

**AC 改訂フロー**:

```text
検証 FAIL
    ↓
根本原因の分類:
  (a) 実装ミス → Phase E-1 に戻って修正
  (b) 前提の誤り（設計 / 環境 / 依存関係）→ 以下の AC 改訂
  (c) 外部サービスの問題 → Phase E-2（待機）
    ↓
(b) の場合:
  1. decision-log.jsonl に前提誤りと根本原因を記録（append-only）
  2. pbi-input.md の Notes に「前提変更」として追記
  3. 影響 AC を特定して test-cases.md を更新
  4. 人間に変更範囲を確認（影響が Out of scope を超える場合は C-3 再承認）
    ↓
次の仮説へ
```

## 入力

- pbi-input.md（初期 AC、柔軟に更新可）
- WF-01 の context（前提制約）

## 完了条件

- 全仮説が「解消」または「棄却」として記録されている
- `evidence/exploratory/` に各仮説の結果が記録されている
- 最終 AC が test-cases.md と整合している
- 標準フロー（WF-05）への移行条件が満たされている（通常の V-1/handoff）

## 呼び出す Skill

- `hypothesis-logger`（仮説記録 / 将来実装）
- `acceptance-review`（WF-05 に委譲）

## 主担当 Agent

- `orchestrator`（フェーズ遷移管理）
- `qa-reviewer`（AC 整合確認・WF-05 移行判断）

## 既存 WF との接続

| 既存 WF | 接続点 |
|---------|--------|
| WF-00 Intent Intake | `Mode: exploratory` を出力すると本フェーズを推奨 |
| WF-01 Context Bootstrap | 前提制約を読み込む（変更なし）|
| WF-05 Verify & Handoff | 全仮説解消後に標準移行（変更なし）|
| working-context.md §BLOCKED | `waiting_external_verification: true` を BLOCKED の拡張フィールドとして使用 |

## 制約（Rule 1 準拠）

本フェーズ定義は順序と完了条件のみ。探索ループの具体的な観点・記録フォーマットは
Skill / Agent に委譲。全 run への強制適用は禁止（opt-in 原則）。
