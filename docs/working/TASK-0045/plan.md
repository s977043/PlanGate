# EXECUTION PLAN: TASK-0045 / Issue #159

> Mode: **light**（簡易 plan: Goal + Approach + 確認方法）

## Goal

PR 本文に GitHub closing keyword（`closes #N` / `fixes #N` / `resolves #N`）が含まれているかを CI で機械検証し、子 PBI auto-close 漏れを再発防止する。

## Approach

1. **検証ロジック**: `scripts/check-pr-issue-link.sh`（POSIX sh）に分離し、入力（PR body / labels / changed files）から **PASS / WARN / SKIP** を stdout に出力
2. **CI 起動**: `.github/workflows/check-pr-issue-link.yml` を `pull_request` イベント（opened / edited / synchronize / labeled）で起動し、上記スクリプトを呼び出して `gh pr comment` / label 付与で warning 通知
3. **schema 拡張**: `docs/schemas/child-pbi.yaml` に optional `related_issue: <int>` を追加（既存 YAML との前方互換）
4. **テスト**: `tests/fixtures/check-pr-issue-link/` に pass / warn / skip-label / skip-marker の 4 fixture + `tests/run-tests.sh` から呼び出し

## 変更ファイル

| ファイル | 種別 |
|---------|------|
| `scripts/check-pr-issue-link.sh` | 新規 |
| `.github/workflows/check-pr-issue-link.yml` | 新規 |
| `tests/fixtures/check-pr-issue-link/{pass,warn,skip-label,skip-marker}/*` | 新規 |
| `tests/run-tests.sh` | 編集（フィクスチャ呼び出し追加）|
| `docs/schemas/child-pbi.yaml` | 編集（`related_issue:` 追記）|
| `docs/working/TASK-0045/*` | 新規（plan / handoff 等）|

## Mode判定

**モード**: light

**判定根拠**:
- 変更ファイル数: 6 → light
- 受入基準数: 6 → standard
- 変更種別: CI 1 ワークフロー追加 + 軽量スクリプト → light
- リスク: warning のみで強制 block なし → 低
- **最終判定**: light（CI 追加だが既存挙動に副作用なし、誤検出時も推奨運用に留まる）

## Risks & Mitigations

| Risk | Mitigation |
|------|----------|
| GitHub closing keyword の判定 regex が false-positive を出す | 公式 keyword（close/closes/closed/fix/fixes/fixed/resolve/resolves/resolved）を case-insensitive で照合、コードブロック内は対象外（簡易: 全文 grep でも実害低い）|
| 既存 PR / chore PR で warning が出続ける | label skip + marker skip を提供、warning 止まりで block しない |
| PBI YAML の `related_issue:` 未設定で誤判定 | フィールド未存在時は厳密 issue 一致をスキップ、closing keyword 1 件以上で PASS |

## 確認方法

- `sh tests/run-tests.sh` で全 fixture が PASS
- 本 PR 自身が `closes #159` を含むため CI で PASS する（self-test）
