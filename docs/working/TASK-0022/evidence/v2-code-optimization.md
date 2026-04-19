# V-2 コード最適化（docs 対象）

> 実施日: 2026-04-20
> モード: full（V-2 必須）
> 対象: `docs/workflows/` 配下 6 ファイル

## V-2 の位置づけ

本 TASK は docs のみのため、「コード最適化」は実質的に **ドキュメントの構造・表記・整合性の最適化**として実施する。具体的な対象は以下。

1. 各 phase ファイル間の構造統一
2. Skill / Agent 名の親 PBI との整合
3. 対応表の粒度確認
4. README と phase ファイルの冗長除去

## 1. 各 phase ファイル間の構造統一

全 5 phase ファイルが同一構造（6 必須セクション + 冒頭の位置づけ注記）で記述されていることを確認。

| ファイル | セクション | 行数 | 判定 |
|---|---|---|---|
| 01_context_bootstrap.md | 6 | 38 | ✅ |
| 02_requirement_expansion.md | 6 | 39 | ✅ |
| 03_solution_design.md | 6 | 40 | ✅ |
| 04_build_and_refine.md | 6 | 36 | ✅ |
| 05_verify_and_handoff.md | 6 | 38 | ✅ |

**結果**: ✅ 全ファイルが同一構造、行数も 36〜40 の範囲で揃っている（TC-E4「30〜120行」ガードレール内）。

## 2. Skill / Agent 名の親 PBI との整合（TC-E1）

親 PBI（`docs/working/TASK-0021/pbi-input.md`）の Skill 10 個・Agent 5 体と、本 TASK の phase 定義で引用された名前の突合。

### Skill 名の整合

| 親 PBI 定義 | phase での出現 | 整合 |
|---|---|---|
| context-load | WF-01 | ✅ |
| requirement-gap-scan | WF-02 | ✅ |
| nonfunctional-check | WF-02 | ✅ |
| edgecase-enumeration | WF-02 | ✅ |
| risk-assessment | WF-03 | ✅ |
| acceptance-criteria-build | WF-02 | ✅ |
| architecture-sketch | WF-03 | ✅ |
| feature-implement | WF-04 | ✅ |
| acceptance-review | WF-05 | ✅ |
| known-issues-log | WF-05 | ✅ |

**追加で引用した Skill**（親 PBI に明記なし、本 TASK で補足）:

- `constraint-extract` (WF-01), `definition-of-done` (WF-01): WF-01 の完了条件をカバーする観点として追加
- `domain-modeling` (WF-03), `implementation-plan` (WF-03): WF-03 の完了条件をカバーする観点として追加
- `scaffold-generate` (WF-04), `local-review` (WF-04), `refactor-pass` (WF-04): WF-04 の実装作業をカバーする観点として追加
- `test-matrix-check` (WF-05), `handoff-package` (WF-05): WF-05 の完了条件をカバーする観点として追加

これら追加 Skill は **#24（Skill 整備）で正式化**する位置付け。本 TASK では名前の列挙のみで、実装は Out of scope。

### Agent 名の整合

| 親 PBI 定義 | phase での出現 | 整合 |
|---|---|---|
| orchestrator | WF-01, WF-03, WF-05 | ✅ |
| requirements-analyst | WF-01, WF-02 | ✅ |
| solution-architect | WF-03 | ✅ |
| implementation-agent | WF-04 | ✅ |
| qa-reviewer | WF-02, WF-05 | ✅ |

**結果**: ✅ Agent 5 体は親 PBI と完全整合。

## 3. 対応表の粒度確認

README の PlanGate 既存フェーズ対応表には、Codex Q2 見解に従って A/B/C-1/C-2/C-3/D/L-0/V-1/V-2/V-3/V-4/PR作成/C-4 の **13 項目**を全て記載済み。省略なし。

## 4. README と phase ファイルの冗長除去

### 重複チェック

| 項目 | README 記述 | phase ファイル記述 | 判定 |
|---|---|---|---|
| 目次（phase 一覧） | ○ | - | OK（README のみ） |
| artifact クラス一覧 | ○（全体表） | ○（各 phase の「次 phase 引き継ぎ」） | OK（README=全体、phase=個別） |
| 実行シーケンス | ○ | - | OK（README のみ） |
| 対応表 | ○ | - | OK（README のみ） |
| Rule 1 の適用 | ○ | - | OK（README のみ） |

各 phase ファイルには phase 固有の情報のみを記述し、全体像は README に集約されている。**冗長なし**。

## 総合判定

| 観点 | 結果 |
|---|---|
| 構造統一 | ✅ PASS |
| Skill / Agent 整合 | ✅ PASS（Agent 完全整合、Skill は #24 での正式化を予定） |
| 対応表粒度 | ✅ PASS（全 13 項目記載） |
| 冗長除去 | ✅ PASS |

**V-2 判定**: ✅ **PASS**（docs として最適化完了）
