# Hook Enforcement — runtime で強制すべき不変条件

> **Status**: v3（**Implementation: 5/10 hooks Done** — #157 で EH-2 / EHS-2 / EHS-3、#169 セッション A で EH-1 / EH-3 を追加。3 mode 設計）
> 関連: [`responsibility-boundary.md`](./responsibility-boundary.md) / [`tool-policy.md`](./tool-policy.md) / [`model-profiles.md`](./model-profiles.md)
> 実装: [`scripts/hooks/check-plan-exists.sh`](../../scripts/hooks/check-plan-exists.sh) / [`check-c3-approval.sh`](../../scripts/hooks/check-c3-approval.sh) / [`check-plan-hash.sh`](../../scripts/hooks/check-plan-hash.sh) / [`check-handoff-elements.sh`](../../scripts/hooks/check-handoff-elements.sh) / [`check-fix-loop.sh`](../../scripts/hooks/check-fix-loop.sh)
> 設定例: [`.claude/settings.example.json`](../../.claude/settings.example.json) / 単体テスト: [`tests/hooks/run-tests.sh`](../../tests/hooks/run-tests.sh)

## 1. 目的

PlanGate の **Iron Law 7 項目相当の不変条件** を、プロンプトに頼らず **runtime で決定論的にブロック** する。プロンプト薄型化（PBI-116-01 で達成）と両立して、強制力を維持する。

## 2. 強制すべき不変条件（一覧）

[`responsibility-boundary.md`](./responsibility-boundary.md) § 5 と整合。最低 6 件:

### EH-1: plan.md なし production code 編集ブロック

- **トリガー**: `docs/working/TASK-XXXX/plan.md` が存在しない状態で、production code（CLAUDE.md / AGENTS.md / `docs/ai/` / `.claude/` / `bin/` / `schemas/` / `plugin/` 等）を編集しようとした
- **対応**: Hook が即 block。「plan.md を作成してください」とユーザーに通知
- **基盤**: Iron Law #1（C-3 承認前 production 編集禁止）+ #5（承認済 plan との整合性）

### EH-2: C-3 承認なし exec ブロック

- **トリガー**: `approvals/c3.json` の `c3_status: APPROVED` がない、または存在しない状態で `exec` フェーズに進もうとした
- **対応**: Hook が即 block。Child C-3 ゲートを促す
- **基盤**: Iron Law #1（C-3 承認前 production 編集禁止）

### EH-3: plan_hash 改竄検知

- **トリガー**: `approvals/c3.json` 発行後、`plan.md` が変更されたが `c3.json` の `plan_hash` が更新されていない
- **対応**: Hook が次の operation を block。再承認を要求
- **基盤**: Iron Law #5（承認済 plan と実装差分の整合性）

### EH-4: test-cases.md なし V-1 ブロック

- **トリガー**: V-1（受入検査）を試みたが `test-cases.md` が存在しない
- **対応**: Hook が即 block
- **基盤**: Iron Law #3（検証証拠なし完了禁止）

### EH-5: 検証ログなし PR 作成ブロック

- **トリガー**: `evidence/verification.md` または同等のログがないまま子 PR を作成しようとした
- **対応**: Hook が PR 作成を block
- **基盤**: Iron Law #3（検証証拠なし完了禁止）

### EH-6: scope 外ファイル編集検知

- **トリガー**: 子 PBI YAML の `forbidden_files` に該当するファイルを編集
- **対応**: Hook が即停止
- **基盤**: Iron Law #2（PBI 外 scope 追加禁止）

### EH-7: 2 段階レビューなしマージブロック（推奨）

- **トリガー**: C-3 + C-4 のいずれかが APPROVED でない状態で main へマージ試行
- **対応**: GitHub branch protection / Hook で block
- **基盤**: Iron Law #7（2 段階レビューなしマージ禁止）

## 3. validation_bias: strict 時の追加条件

Model Profile の `validation_bias: strict` プロファイル（gpt-5_5_pro）では、上記 EH-1〜EH-7 に加えて以下 3 件以上を追加で強制:

### EHS-1: V-3 外部レビュー必須化

- **トリガー**: standard 以上の mode で V-3 外部 AI レビューなしに PR 作成
- **対応**: Hook が PR 作成 block

### EHS-2: handoff.md 必須 6 要素チェック

- **トリガー**: `handoff.md` が必須 6 要素（要件適合 / 既知課題 / V2 候補 / 妥協点 / 引き継ぎ文書 / テスト結果）を欠く
- **対応**: Hook が WF-05 完了を block

### EHS-3: V-1 fix loop 上限超過 escalation

- **トリガー**: V-1 FAIL → fix → V-1 のループが 5 回を超過
- **対応**: Hook が ABORT、ユーザー判断にエスカレーション

## 4. 実装（#157 で 3 hook、#169 セッション A で +2 hook、計 5 hook）

| Hook | 種別 | 実装 | 由来 |
|------|------|------|------|
| **EH-1**（plan.md なし production code 編集 block）| PreToolUse hook | [`scripts/hooks/check-plan-exists.sh`](../../scripts/hooks/check-plan-exists.sh) | #169 / TASK-0056 |
| EH-2（C-3 未承認 exec block）| PreToolUse hook | [`scripts/hooks/check-c3-approval.sh`](../../scripts/hooks/check-c3-approval.sh) | #157 / TASK-0048 |
| **EH-3**（plan_hash 改竄検知）| PreToolUse hook + CLI | [`scripts/hooks/check-plan-hash.sh`](../../scripts/hooks/check-plan-hash.sh) | #169 / TASK-0056 |
| EHS-2（handoff 必須 6 要素）| CLI（手動 / WF-05 で呼び出し）| [`scripts/hooks/check-handoff-elements.sh`](../../scripts/hooks/check-handoff-elements.sh) | #157 / TASK-0048 |
| EHS-3（fix loop 上限超過）| CLI（V-1 fix loop 内で increment / check）| [`scripts/hooks/check-fix-loop.sh`](../../scripts/hooks/check-fix-loop.sh) | #157 / TASK-0048 |

**残未実装**: EH-4 / EH-5 / EH-6（次セッション B）/ EH-7 / EHS-1（次セッション C）

### 4.1 3 モード設計

| モード | 環境変数 | 挙動 |
|-------|---------|------|
| **default**（推奨初期値）| なし | 違反検出時は warning のみ、continue:true（block しない）。誤検出時の作業妨害を最小化 |
| **strict** | `PLANGATE_HOOK_STRICT=1` | 違反検出時に block / exit 1。本番運用 / CI 等で有効化 |
| **bypass** | `PLANGATE_BYPASS_HOOK=1` | 常時 pass。緊急対応 / 既知の例外時のみ使用、監査 log に必ず記録 |

### 4.2 監査ログ

すべての判定は `docs/working/_audit/hook-events.log` に append-only で記録される（タブ区切り）:

```text
<ISO8601 UTC>\t<level>\t<hook-name>\t<task-id>\t<message>
```

`level`: `PASS` / `VIOLATION` / `BYPASS` / `SKIP` / `INCREMENT`

### 4.3 設定方法（opt-in）

[`.claude/settings.example.json`](../../.claude/settings.example.json) を `.claude/settings.json` にコピーすると PreToolUse hook（**EH-1 + EH-2 + EH-3**）+ SessionStart（gh-pin-account）が有効化される。EHS-2 / EHS-3 は CLI ツールとして workflow 内で呼び出す。

### 4.4 テスト

- 単体: `sh tests/hooks/run-tests.sh` → **21 件 PASS**（#157 で 12 + #169 セッション A で 9 件追加）
- 統合: `sh tests/run-tests.sh` の TA-06 で hook 子テストを呼び出し

### 4.5 EH-4 / EH-5 / EH-6 / EH-7 / EHS-1 の status

#157 で 3 hook + #169 セッション A で 2 hook = 計 **5 hook 実装済**。残 5 hook（EH-4 / EH-5 / EH-6 / EH-7 / EHS-1）は **未実装（Spec のみ）**、Issue #169 のセッション B / C で順次対応。

## 5. 既存 `.claude/settings.json` hooks との関係

本ファイルが定義する不変条件は、既存 hooks（もしあれば）と:

- **重複なし**: 既存 hooks は本ファイルの実装で参照すべき入口
- **追加**: EH-1〜EH-7 + EHS-1〜EHS-3 を新規実装
- **既存 v8.1 ガードレール（`plugin/plangate/rules/*-gate.md`）との関係**: Plugin 配布版の追加ガードレールとして共存（[`responsibility-boundary.md`](./responsibility-boundary.md) § 6 参照）

## 6. 「block 通知」の文言ガイド

Hook が block する際の通知文言:

```text
[Hook EH-1] plan.md がないため production code を編集できません。
docs/working/TASK-XXXX/plan.md を作成してください。
```

形式:
- `[Hook EH-N]` プレフィックスで該当条件を識別
- 1 行サマリ + 解消手順 1 行
- 詳細は本ファイルへリンク

## 関連

- 親計画: [`docs/working/PBI-116/parent-plan.md`](../working/PBI-116/parent-plan.md)
- 責務境界: [`responsibility-boundary.md`](./responsibility-boundary.md)
- Tool Policy: [`tool-policy.md`](./tool-policy.md)
- Model Profile: [`model-profiles.md`](./model-profiles.md)
- Iron Law 7 項目: [`core-contract.md`](./core-contract.md) § 4
- Phase 1 成果: [`core-contract.md`](./core-contract.md)
