# EXECUTION TODO: TASK-0047 / Issue #158

> Mode: **high-risk**

## Tasks

### 準備

- [x] PBI INPUT 作成
- [x] plan + test-cases 作成

### 実装

- [x] `scripts/validate-schemas.py` 実装
- [x] `bin/plangate validate-schemas` サブコマンド追加（cmd_validate には触れない）
- [x] `.github/workflows/schema-validate.yml` 作成
- [x] `tests/fixtures/schema-validate/{valid,invalid}/c3.json`
- [x] `tests/run-tests.sh` に TA-05 統合
- [x] `docs/ai/contracts/plan.md` 編集
- [x] `docs/ai/contracts/review.md` 編集
- [x] `docs/ai/contracts/verify.md` 編集
- [x] `docs/ai/contracts/handoff.md` 編集
- [x] `docs/ai/contracts/classify.md` 編集
- [x] `docs/ai/structured-outputs.md` § 8 追記
- [x] `docs/ai/eval-cases/format-adherence.md` Detection 整合

### 検証

- [x] `sh tests/run-tests.sh` 全 PASS（13 件）
- [x] `sh bin/plangate validate-schemas` 単体動作確認（valid PASS / invalid FAIL）
- [x] handoff.md 作成

### 完了

- [x] commit + push + PR 作成
- [ ] CI 緑確認 → C-4 ゲート
