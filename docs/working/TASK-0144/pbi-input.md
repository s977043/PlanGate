---
task_id: TASK-0144
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-0144

## Context / Why

現行の C-3 承認は `bin/plangate approve` CLI 実行（Human-owned）が必須。
個人・社内プロジェクトでは CLI の手間を省き、会話内の APPROVE で
exec に進みたい。一方で OSS・厳密な監査が必要なプロジェクトでは
CLI による provenance 記録を維持したい。

プロジェクト設定（`.plangate.yml`）で承認モードを切り替えられるようにすることで、
両方のニーズに対応する。関連: issue #626。

## What — Scope

### In scope

| # | 内容 | HO |
|---|------|-----|
| S1 | `.plangate.yml` に `c3_approval.mode: cli \| conversation` 設定を追加 | — |
| S2 | `schemas/plangate-config.schema.json`（または同等）にスキーマ定義を追加 | — |
| S3 | `bin/plangate` が `.plangate.yml` の `c3_approval.mode` を読み込み、exec / approve サブコマンドの動作を分岐 | ✅ |
| S4 | `conversation` モード時: AI が `approvals/c3.json` を Write 可能（EH-3 例外経路を明示・`source: conversation` フィールドで区別） | ✅ |
| S5 | `bin/plangate doctor` で現在の承認モードを表示 | ✅ |
| S6 | デフォルト `cli` で既存動作を完全後方互換に保つ | ✅ |
| S7 | c3.json スキーマに `source: cli \| conversation` フィールドを追加 | — |

### Out of scope

- `.plangate.yml` の他の設定項目（本 PBI は `c3_approval` のみ）
- EH-3 provenance 検証の完全実装（issue #420 — 後続 PBI）
- `conversation` モードの HMAC 署名・セッション検証（V2 候補）
- GUI / Web UI での承認フロー

## Acceptance Criteria

| AC | 内容 |
|----|------|
| AC-01 | `.plangate.yml` に `c3_approval: {mode: conversation}` を設定した状態で、会話内 APPROVE → AI が c3.json を生成 → `bin/plangate exec` が通る |
| AC-02 | `.plangate.yml` に `c3_approval: {mode: cli}` またはファイル未存在の場合、現行動作（`bin/plangate approve` 必須）が維持される |
| AC-03 | 生成された c3.json に `source: conversation` フィールドが含まれる |
| AC-04 | `bin/plangate doctor` が現在の承認モード（cli / conversation）を出力する |
| AC-05 | `schemas/plangate-config.schema.json` が `.plangate.yml` の `c3_approval.mode` を enum 検証する |
| AC-06 | 既存テスト（`sh tests/run-tests.sh`）が 0 FAIL で通過する |

## Notes from Refinement

- **デフォルトは `cli`**: 既存プロジェクトへの破壊的変更を避ける。`.plangate.yml` 未設定 = `cli` モード。
- **`source` フィールドで区別**: `conversation` モードで AI が生成した c3.json は `source: conversation` を持ち、CLI 発行（`source: cli`）と機械的に区別できる（issue #420 の暫定対応）。
- **EH-3 例外経路**: `conversation` モード時に AI が c3.json を Write しても EH-3 がブロックしない経路を明示的に設計する（暗黙の例外ではなく設計上の例外）。
- **`bin/plangate` は HO パス**: apply-script 経由で Human が適用する。

## Estimation Evidence

**Risks**:
- `bin/plangate` の設定読み込み追加は HO パス → apply-script が必要
- EH-3 hook の例外経路設計を誤ると conversation モードが常時 BLOCK になる可能性
- `.plangate.yml` のスキーマが CI drift check と整合しているか要確認

**Unknowns**:
- `.plangate.yml` が既に存在するか・既存スキーマとの衝突有無
- c3.json スキーマ（`schemas/c3-approval.schema.json`）の現行定義に `source` フィールドが追加可能か

**Assumptions**:
- `.plangate.yml` はプロジェクトルートに配置（gitignore 対象外）
- `conversation` モードで AI が生成する c3.json の中身は現行スキーマ準拠 + `source` フィールド追加
- 設定ファイル未存在時は `cli` にフォールバック（安全側）

## 関連

- issue: #626
- 関連 PBI: TASK-0143（EH-4/5/7 CLI 配線）
- 関連 issue: #420（EH-3 provenance 検証ギャップ）
- 設計正本: `docs/ai/settings-wiring-contract.md`
- c3.json スキーマ: `schemas/c3-approval.schema.json`（要確認）
