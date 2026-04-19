# TASK-0019 Plugin 内フロー完結検証

> 実施日: 2026-04-19

## 検証方針

### 静的フロー完結性

plugin 内 6 agents で PlanGate ワークフローが論理的に完結することを、各 agent の役割から確認:

| フェーズ | 担当 agent | plugin 内有無 |
|---------|----------|--------------|
| B: plan + todo + test-cases 生成 | spec-writer | ✅ |
| D: exec (TDD) | implementer | ✅ |
| L-0: リンター自動修正 | linter-fixer | ✅ |
| V-1: 受入検査 | acceptance-tester | ✅ |
| V-2: コード最適化 | code-optimizer | ✅ |
| 全フェーズ制御 | workflow-conductor | ✅ |

### 未同梱 agents の影響

| 非同梱 agent | 担当フェーズ | 代替 |
|-------------|------------|------|
| test-engineer（存在せず） | テスト作成 | implementer が兼務 |
| release-manager（存在せず） | V-4 リリース前チェック | critical モード時のみ必要、plugin 初版では対応しない |
| claude-code-reviewer | C-2 外部レビュー | plugin 外（Codex や別途手配） |
| retrospective-analyst | 振り返り | オプション、本 plugin では未同梱 |

workflow-conductor が参照する judgment は `plugin/plangate/rules/mode-classification.md` に完結。**実装フロー（plan → C-1 → exec → L-0 → V-1 → PR）は plugin 単体で回せる構造**。

ただし、C-2 外部レビューと V-4 リリース前チェックは opt-in / 外部ツール依存のため、plugin 利用者は必要に応じ別途手配する（TASK-0020 の README で案内）。

## Runtime フロー検証（未実施）

統合 runtime 検証で以下を実施予定:

| Test | 手順 | 期待結果 |
|------|------|---------|
| FL-1 | 小規模テストチケット（typo 修正レベル）を plugin 内 agents のみで plan → exec → PR まで実行 | 全フェーズが plugin agents で完結 |
| FL-2 | light モード判定が workflow-conductor で正しく機能 | mode-classification.md のルールに従い判定 |
| FL-3 | acceptance-tester で V-1 が test-cases.md を参照して機能 | PASS/FAIL 判定が出力される |

## 判定

静的完結性: ✅ PASS

- 実装フロー（B→D→L-0→V-1→PR）に必要な agents は全て同梱
- rules 参照も plugin 内で解決可能
- 未同梱 agent（release-manager 等）の影響は critical モード使用時のみ、**light/standard/full モードでは plugin 単体で完結**
