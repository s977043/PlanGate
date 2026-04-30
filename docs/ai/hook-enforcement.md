# Hook Enforcement — runtime で強制すべき不変条件

> **Status**: v1（PBI-116-06 で初版確立、Phase 2 / PBI-116、**境界定義のみ**）
> 関連: [`responsibility-boundary.md`](./responsibility-boundary.md) / [`tool-policy.md`](./tool-policy.md) / [`model-profiles.md`](./model-profiles.md)
> 実装方法: 本 PBI scope 外（別 PBI で `.claude/settings.json` の hooks 追加 / CLI 実装）

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

## 4. 実装方法（本 PBI scope 外）

実 Hook 実装は別 PBI で行う。候補:

- `.claude/settings.json` の `hooks` セクションで Bash / Python script を登録
- `bin/plangate validate` で事後検査
- GitHub Actions（branch protection ruleset と組み合わせ）

本 PBI は **「強制すべき不変条件の一覧」を定義** することに専念する。

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
