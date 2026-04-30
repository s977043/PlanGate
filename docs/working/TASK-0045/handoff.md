---
task_id: TASK-0045
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-05-01
author: qa-reviewer
v1_release: ""
related_issue: 159
---

# Handoff: TASK-0045 / Issue #159 — PR close キーワード自動検証 CI

## メタ情報

```yaml
task: TASK-0045
related_issue: https://github.com/s977043/plangate/issues/159
author: qa-reviewer
issued_at: 2026-05-01
v1_release: <PR マージ後に SHA を記入>
```

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 |
|---------|------|------|
| AC-1: workflow が PR で trigger される | PASS | `.github/workflows/check-pr-issue-link.yml` の `on: pull_request` に [opened, edited, synchronize, labeled, unlabeled, reopened] を設定 |
| AC-2: closing keyword なしで warning | PASS | fixture `warn/` で `WARN: no closing keyword found` を確認、workflow が `gh pr comment` で通知 |
| AC-3: 子 PBI YAML の `related_issue:` ↔ closing keyword 整合 | PASS | スクリプト 95 行目以降の `expected_issue` 抽出 + 照合ロジック、schema に optional `related_issue:` を追記 |
| AC-4: chore / documentation label で SKIP | PASS | fixture `skip-label/` で `SKIP: label "documentation"` を確認 |
| AC-5: PR テンプレと整合 | PASS | 既存テンプレ（PR #154）の Linked Issue セクション構造を変更せず、closing keyword 行を直接 grep |
| AC-6: fixture pass / warn / skip 各 1 件以上 | PASS | `tests/fixtures/check-pr-issue-link/` 配下 4 fixture（pass / warn / skip-label / skip-marker）、`tests/run-tests.sh` で 4 件 PASS |

**総合**: **6 / 6 基準 PASS**
**FAIL / WARN の扱い**: なし

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| 既存 PBI-116 配下の子 YAML に `related_issue:` 未記入 | minor | accepted | Yes（後続タスクで遡及記入推奨）|
| closing keyword の grep がコードブロック内も検出する | info | accepted | No（false-positive のリスクは低く、warning 止まり）|

**Critical 課題**: なし

## 3. V2 候補

| V2 候補 | 理由 | 優先度 | 関連 Issue |
|--------|------|--------|---------|
| 既存子 PBI YAML への `related_issue:` 遡及記入 | 本 PBI 範囲外（schema 拡張のみで完結）| Low | — |
| Markdown コードブロック除外パーサ | false-positive 抑制（実害低い）| Low | — |
| 強制 block 化（warning → error） | 運用知見蓄積後に検討 | Low | — |
| `.claude/worktrees/` を `.gitignore` に追加 | retrospective P-3 未対応、本 PBI scope 外 | Medium | — |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| POSIX sh + GitHub Actions の最小構成 | TypeScript / GitHub Action 化 | light モードで scope を維持、既存 `scripts/` パターンに整合 |
| 子 PBI YAML から `related_issue:` を抽出（optional）| YAML 必須化 | 前方互換維持、既存 PBI-116 配下に遡及不要 |
| warning のみ（block しない）| CI を fail させる | 運用初期の誤検出耐性、issue 本文「過剰検出時は false-positive 抑制」と整合 |
| `<!-- skip-issue-link-check -->` マーカー対応 | label のみ skip | 細粒度 escape hatch、運用柔軟性 |

## 5. 引き継ぎ文書

### 概要

PR 本文に GitHub closing keyword（`closes #N` / `fixes #N` / `resolves #N`）が含まれているかを CI で検証するワークフローを新設した。子 PBI auto-close 漏れ（PBI-116 で 5 件発生）の再発防止が目的。検証ロジックは `scripts/check-pr-issue-link.sh` に分離してテスト容易性を確保し、`tests/run-tests.sh` から 4 fixture（pass / warn / skip-label / skip-marker）を回している。

### 触れないでほしいファイル

- `tests/fixtures/check-pr-issue-link/*/expected.txt`: テスト判定の期待値、変更すると挙動と乖離する
- `scripts/check-pr-issue-link.sh` の closing keyword 正規表現（`keyword_re` 変数）: GitHub 公式仕様に合わせており、勝手に拡張すると false-positive が増える

### 次に手を入れるなら

- 既存 PBI-116 配下の子 YAML に `related_issue:` を遡及追加（任意、warning 抑制と precision 向上）
- 運用で誤検出が頻発する場合は `scripts/check-pr-issue-link.sh` の skip 条件を追加（`bot[user]:` author 等）
- アンチパターン: warning を error に格上げする変更は別 PBI として PR 化（影響範囲が広い）

### 参照リンク

- Issue: https://github.com/s977043/plangate/issues/159
- 親 retrospective: `docs/working/retrospective-2026-04-30.md` § Try T-6
- plan: `docs/working/TASK-0045/plan.md`
- スクリプト: `scripts/check-pr-issue-link.sh`
- ワークフロー: `.github/workflows/check-pr-issue-link.yml`

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| Unit (fixture) | 4 | 4 | 0 / 0 | pass / warn / skip-label / skip-marker |
| Integration (run-tests.sh 全体) | 14 | 14 | 0 / 0 | 既存 10 + 新規 4 |
| E2E | 0 | — | — | 本 PR 自身が `closes #159` を含むため CI 起動時に self-test 兼ねる |

**FAIL / SKIP の詳細**: なし

実行コマンド: `sh tests/run-tests.sh`
実行結果: `Results: 14 passed, 0 failed`
