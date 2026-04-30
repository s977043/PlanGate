# PBI INPUT PACKAGE: TASK-0047 / Issue #158

> Source: [#158 [EPIC] Structured Outputs 実 LLM 適用 + schema validate CI 統合](https://github.com/s977043/plangate/issues/158)
> Mode: **high-risk**

## Context / Why

v8.3.0 で `docs/ai/structured-outputs.md` + 4 schemas（review-result / acceptance-result / mode-classification / handoff-summary）を整備したが、**実 LLM プロンプトへの組み込みは未実施**。schema 化された JSON 出力を強制すれば、format adherence（release blocker 観点）の機械検証が可能になる。

## What

### In scope

- `docs/ai/contracts/{plan,review,verify,handoff,classify}.md` に schema reference + CI 連携明記を追加
- `.github/workflows/schema-validate.yml` 新設、PR の `docs/working/**/*.json` を validate
- `scripts/validate-schemas.py` 新設（Python + jsonschema、basename → schema 自動マッピング）
- `bin/plangate validate-schemas` サブコマンド追加（既存 `validate` には触れない、後方互換維持）
- `docs/ai/structured-outputs.md` § 8 にマイグレーションガイド追記
- `docs/ai/eval-cases/format-adherence.md` の Detection 手順を新 CI に整合
- `tests/fixtures/schema-validate/{valid,invalid}/c3.json` + `tests/run-tests.sh` 統合

### Out of scope

- 全 phase の Markdown 廃止（共存維持）
- 自動 PR 修正（違反検出のみ、修正は人間 / AI 担当）
- 第三者 schema registry への公開
- 既存 PBI への JSON 遡及追加（後方互換のため新規 / 編集のみ対象）

## Acceptance Criteria

- AC-1: `docs/ai/contracts/{plan,review,verify,handoff,classify}.md` に schema reference が追加されている
- AC-2: `.github/workflows/schema-validate.yml` が PR の JSON artifact を validate する
- AC-3: schema 違反時に CI FAIL になる
- AC-4: `bin/plangate validate-schemas` が schema validate を実行する
- AC-5: format-adherence eval case の Detection 手順が CI 実装と一致する
- AC-6: 既存 PBI（PBI-116 配下）が新 CI を pass する（対象 JSON 不在で skip）
- AC-7: マイグレーションガイドが `structured-outputs.md` に追記されている

## Notes

- 推奨 mode: **high-risk**（CI / 既存 artifact 両方に影響、前方互換維持必要）
- 依存: なし（v8.3.0 schema は単独実装可）
- format adherence release blocker 観点（v8.3 eval framework）の **機械化** を担う
- `bin/plangate validate` への組込みは **新サブコマンド `validate-schemas`** に分離して達成（既存挙動を変えない）
