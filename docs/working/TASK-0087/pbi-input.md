# PBI INPUT PACKAGE — TASK-0087 / #225 バージョニング安定性ポリシー明文化

## Context / Why
PlanGate は高頻度リリース（8 日で v8.1.0→v8.6.0）。20 Schema / 11 Hook / 5 mode
が相互依存し波及が広いが、何が breaking change かの定義がなく、導入側が
バージョンアップの安全性を CHANGELOG だけで判断できない。

## What (Scope)
- In scope: `docs/ai/versioning-stability-policy.md`（正本・新規）+ `oss-governance.md` から参照リンク
- Out of scope: release-please 設定変更 / CHANGELOG 既存エントリの遡及タグ付け / LTS ブランチの実切り出し / CI 強制（後続）

## 受入基準
- AC1: Schema / Hook / Workflow / CLI 別の Breaking Change 定義（major/minor/patch）が表で示される
- AC2: コンポーネント別 Stable / Beta / Experimental 宣言がある
- AC3: CHANGELOG 影響度タグ（[BREAKING]/[MIGRATION REQUIRED]/[STABILITY]/[SAFE UPDATE]/[INTERNAL]）と記載例がある
- AC4: 安定版（LTS）運用方針が明記される（当面 LTS なし + トリガ）
- AC5: oss-governance.md から本ポリシーへ到達できる

## Notes from Refinement
- #225 提案の severity 表を踏襲。判定不明時は安全側（高 severity）固定。
- #224（release archive 方式）と LTS 判断を将来連携。

## Estimation Evidence
- Risks: 既存運用との齟齬（緩和: 既存 mode-classification 固定条項を参照） / Unknowns: なし / Assumptions: docs のみで CI 強制は後続 PBI
