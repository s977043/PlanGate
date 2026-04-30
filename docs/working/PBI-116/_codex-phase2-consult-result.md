# Codex Phase 2 戦略相談結果

> 実施: 2026-04-30 / Codex CLI (`codex-cli 0.124.0`) / `codex exec` 経由
> 入力: [`_codex-phase2-consult.txt`](./_codex-phase2-consult.txt)
> 目的: Phase 1 (PBI-116-01) 完了後、Phase 2（PBI-116-02 / 04 / 06）の進め方をユーザー判断代行で Codex に決定依頼

## D1: 着手戦略

- **推奨: (a) 3 子 PBI を完全並行**
- 理由: 依存は PBI-116-01 のみで、`allowed_files` 重複なし
- ただし開始前に 02/06 の `tool_policy` 接続点だけ **interface preflight** を行う

## D2: 着手順序

- **推奨順: PBI-116-02 → PBI-116-06 → PBI-116-04**
- 理由: 02 は PBI-116-03 の前提で、06 の `tool_policy / validation_bias` 設計にも影響
- 04 は独立性が最も高く、並行枠で後追いしてもブロッカーになりにくい

## D3: 着手準備粒度

- **推奨: (a) 3 つすべてを preparatory で起票**
- 理由: pbi-input / INDEX / current-state まで揃えて並行実行可能性を確定
- plan/todo/test-cases は各子 PBI の Child C-3 単位で作り、承認境界を混ぜない

## D4: 想定リスクと対策

| Risk | Severity | Mitigation |
|------|---------|----------|
| 02/06 の Model Profile と Tool Policy 接続がずれる | Medium | preparatory で共有語彙を固定し、06 は 02 schema を参照前提にする |
| worktree / branch 競合 | Low | 3 worktree、3 branch、子 PBI ごとの `allowed_files` 厳守 |
| Structured Outputs が既存 `schemas/` と矛盾 | Medium | 04 の C-1/C-2 で既存 schema 棚卸し、既存 schema は変更しない |
| Plugin 配布版との同期漏れ | Medium | Phase 2 では原則 scope 外、必要差分は PBI-116-03/05 前に別途棚卸し |
| Eval 着手前のブロッカー残存 | Medium | 各子 PBI handoff に eval 観点と未決事項を明記 |

## D5: PR 戦略

- **推奨: 1 PR per 子 PBI、preparatory は各子 PBI の plan PR に含める**
- 理由: 親の標準運用と C-3/C-4 境界を維持できる
- マージ順は原則自由だが、実務上は 02 → 06 → 04 が後続 Phase 3 に最短でつながる

## 総合推奨（Codex 提案）

1. Phase 2 用に 3 worktree / 3 branch を作成
2. 3 子 PBI の preparatory context を起票
3. 最初に PBI-116-02 の pbi-input と interface preflight を固める
4. 続けて PBI-116-06、PBI-116-04 の Child C-3 用 plan/todo/test-cases を作成
5. ユーザー承認後、3 PR を並行実行

## 採用方針

ユーザー指示「ユーザーの代わりに Codex に確認を依頼」に基づき、上記 Codex 推奨を **包括採用**:

| 項目 | 採用結果 |
|------|---------|
| D1 着手戦略 | ✅ 完全並行 |
| D2 着手順序 | ✅ 02 → 06 → 04 |
| D3 準備粒度 | ✅ 3 つすべて preparatory（D5 と整合させる方法で） |
| D4 リスク対策 | ✅ 5 件すべて parent-plan.md / interface-preflight.md に反映 |
| D5 PR 戦略 | ✅ 1 PR per 子 PBI、preparatory + plan を統合 |

## 修正計画（D5 採用に伴う）

私の元案（preparatory 単独 PR）→ Codex 案（preparatory + plan を 1 PR）に変更:

| 項目 | 元案 | Codex 採用後 |
|------|------|-------------|
| 本 PR (`chore/PBI-116-phase-2-prep`) | 3 TASK preparatory | **Codex 戦略採用記録 + interface preflight 概念** のみ |
| 次セッション PR-1 | PBI-116-02 の plan/todo/test-cases | **PBI-116-02 の preparatory + plan/todo/test-cases**（統合）|
| 次々セッション PR-2 | PBI-116-06 の plan/todo/test-cases | **PBI-116-06 の preparatory + plan/todo/test-cases**（統合）|
| 並行 PR-3 | PBI-116-04 の plan/todo/test-cases | **PBI-116-04 の preparatory + plan/todo/test-cases**（統合）|

## 本 PR で実施すること

- ✅ `_codex-phase2-consult.txt` / `_codex-phase2-consult-result.md` 保存（再現性）
- ✅ `parent-plan.md` に Phase 2 戦略セクション追加（Codex 採用記録）
- ✅ `interface-preflight.md` 新規作成（02/06 接続点の事前合意ドキュメント）

## 次セッションで実施すること

- PBI-116-02 (#118) の TASK 番号採番（TASK-0040 想定）
- ブランチ `feat/PBI-116-02-...` で preparatory + plan/todo/test-cases を 1 PR
- C-1 セルフレビュー → C-2 Codex レビュー → Child C-3 ゲート
