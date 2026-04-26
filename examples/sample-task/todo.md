---
task_id: sample-task
artifact_type: todo
schema_version: 1
---

# EXECUTION TODO — Add User Registration Endpoint

## 🤖 Agentタスク

### 準備フェーズ

- [ ] T-01: scope確認・plan.md読み込み (agent)
- [ ] T-02: `src/app.js` と既存authミドルウェアを探索し、POST /api/users が遮断されないか確認 (agent)
- [ ] T-03: usersテーブルスキーマ確認（カラム名・制約・型） (agent) 🚩

### 実装フェーズ

- [ ] T-04: `src/validators/user.js` 実装（`isValidEmail`, `isValidPassword`） (agent) 🚩
  - depends_on: T-03
- [ ] T-05: `src/services/userService.js` 実装（`hashPassword`, `createUser`, DB INSERT, 409検出） (agent) 🚩
  - depends_on: T-04
- [ ] T-06: `src/routes/users.js` 実装（POST /api/users ハンドラ、バリデーション呼び出し、サービス呼び出し） (agent) 🚩
  - depends_on: T-05
- [ ] T-07: `src/app.js` にusersルーターをmount (agent)
  - depends_on: T-06
- [ ] T-08: セルフレビュー① — 実装の妥当性・bcryptのasync/await使用・エラーレスポンス形式を確認 (agent) 🚩
  - depends_on: T-07

### テストフェーズ

- [ ] T-09: `tests/unit/validators/user.test.js` 実装（isValidEmail: 正常・異常・境界値、isValidPassword: 正常・短い・空文字） (agent)
  - depends_on: T-04
- [ ] T-10: `tests/integration/routes/users.test.js` 実装（TC-01〜TC-08 + TC-E1〜TC-E5） (agent)
  - depends_on: T-07
- [ ] T-11: セルフレビュー② — テスト網羅性・AC→TCマッピング・エッジケース確認 (agent) 🚩
  - depends_on: T-09, T-10

### 検証フェーズ

- [ ] T-12: `npm run lint` 実行・エラー修正 (agent)
  - depends_on: T-11
- [ ] T-13: `npm test` 実行・全件PASS確認 (agent) 🚩
  - depends_on: T-12
- [ ] T-14: AC-1〜AC-7 を test-cases.md と突合し、全件PASS確認 (agent)
  - depends_on: T-13
- [ ] T-15: `handoff.md` 生成 (agent)
  - depends_on: T-14

## 👤 Humanタスク

- [ ] H-01: **C-3ゲート** — `examples/sample-task/plan.md` を読み、APPROVE / CONDITIONAL / REJECT を判断（exec開始前に必須）(human)
  - depends_on: plan.md, todo.md, test-cases.md, review-self.md 生成完了
- [ ] H-02: **C-4ゲート** — GitHub PR をレビュー・マージ（完了後）(human)
  - depends_on: PR作成完了

## ⚠️ 依存関係

```
T-01 → T-02 → T-03
T-03 → T-04 → T-05 → T-06 → T-07 → T-08
T-04 → T-09
T-07 → T-10
T-08, T-09, T-10 → T-11 → T-12 → T-13 → T-14 → T-15
H-01 must complete before exec starts
T-15 must complete before PR is created
H-02 must complete before Done
```
