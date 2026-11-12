# TASK-1550 — Test Cases

> Status: **Not run**（TC-01 の baseline 測定のみ実施済み）。fixture の配置先は T-01 で `tests/run-tests.sh` の構成に合わせて決める。

## AC → TC

| AC | TC |
|----|----|
| AC-01 経路と baseline | TC-01, TC-10 |
| AC-02 主経路での提示 | TC-02, TC-03, TC-08 |
| AC-03 正本の単一性 | TC-04, TC-07 |
| AC-04 境界を緩めない | TC-06, TC-09 |
| AC-05 Evidence | TC-03, TC-05, TC-08 |
| AC-06 設計 / 反映 / 実利用 | TC-08 |

## ケース

### TC-01 — baseline の再現性（実測）

- 前提: なし
- 入力: `gh pr list --repo s977043/plangate --state merged --limit 30 --json number,body,mergedAt,author`
- 判定式: `## Rollback / Detection` 見出し（`(?m)^## Rollback / Detection`）/ 見出しに Rollback か Detection（`(?m)^#+ .*(Rollback|Detection)`）/ 3 行が TODO 以外
- 期待: 測定日時・HEAD・範囲とともに 3 値を記録できる
- 種別: 実測。2026-11-02 12:06 測定値 3/30・5/30・2/30（origin/main `0d8d9468`）

### TC-02 — Skill がテンプレートを参照する（positive）

- 入力: `.agents/skills/pr-decision/SKILL.md`
- 期待: `.github/PULL_REQUEST_TEMPLATE.md` へのパスと、`Kill-switch` / `Detection signal` / `Observation window` の 3 語を含む
- 種別: fixture（自動）

### TC-03 — Rollback Plan → 3 行の対応（positive）

- 入力: 同上
- 期待: 判定レポートの `Rollback Plan` を `## Rollback / Detection` に写す指示がある
- 種別: fixture（自動）

### TC-04 — 例文を複製しない（negative）

- 入力: 同上
- 期待: テンプレートのコメント中の例文（`PG_T61_PARALLEL=1` / `no runtime behavior change`）を含まない。含めば FAIL
- 種別: fixture（自動）

### TC-05 — 変異注入で検出力を確認

- 入力: TC-02〜TC-04 の検査に対し、(a) 参照パスを消した Skill、(b) 例文を貼った Skill
- 期待: (a) で TC-02 が、(b) で TC-04 が FAIL する
- 種別: fixture（自動）

### TC-06 — closing keyword と承認語を壊さない（compatibility）

- 入力: 追加節
- 期待: `Closes` / `Refs` の扱いを変えない記述があり、`approve` / `merge` を AI に指示する文が無い
- 種別: fixture（自動）+ 目視

### TC-07 — ミラー一致

- 入力: `scripts/sync-plugin-plangate.sh` と `scripts/install-plangate-skills-to-codex.sh --force` 実行後
- 期待: `.codex/skills/pr-decision/` / `plugin/plangate/skills/pr-decision/` が正本と一致。既存 drift 検査が緑
- 種別: integration（自動）

### TC-08 — 実利用（post-adoption）

- 入力: merge 後に AI が作成した PR
- 期待: 3 行が当該変更に合う内容で記入されている。merge 後 30 件で TC-01 を再測定し前後を並べる。観測できなければ `NOT VERIFIED`
- 種別: 実測（手動）

### TC-09 — 承認境界（negative）

- 入力: 実装 PR の diff
- 期待: HO 12 カテゴリへの AI 編集 0 件、`.github/workflows/` への追加 0 件、`approvals/` の AI 作成 0 件
- 種別: `git diff origin/main --name-only` で確認

### TC-10 — 経路一覧の網羅（regression）

- 入力: exec 着手時の origin/main で `git grep -n -E 'gh pr create|PULL_REQUEST_TEMPLATE'`
- 期待: plan §1.1 の R-1〜R-10 以外のヒットが無い。あれば Replan
- 種別: 実測（自動）

## エッジケース

- docs-only PR: テンプレートの `N/A (reason)` で足りる（Skill 側で再定義しない — TC-04）
- Agent の挙動を変える docs: テンプレートの記述に従い signal を書く（同上）
- bot の同期 PR（R-6 / R-7）: 今回の対象外。TC-01 の母集団には含まれる（2/30）ので比較時に分けて数える
