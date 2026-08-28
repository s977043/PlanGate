# Evidence: name 多重定義 46 件の全件分類（TASK-1087 / AC-1）

> 測定日: 2026-08-18 / base: `origin/main` = `387ea21`
> 生成方法: `scripts/check-skill-name-collisions.py` の収集・分類関数を直接呼び出し全件列挙

## 結論

**真の衝突は 0 件**。46 件すべてが repo-local と plugin export のミラー対だった。

| クラス | 件数 |
|-------|------|
| 正常なミラー（repo-local ⇄ 単一 plugin / root 内相対パス一致 / 定義数 2） | **46** |
| 定義数 3 以上（repo-local + 複数 plugin。#692 の動機ケース） | 0 |
| plugin 同士の同名（repo-local 無し） | 0 |
| 非ミラー位置での同名 | 0 |
| 同一 root 内の重複 | 0 |

うち **3 件（#25 / #29 / #30）は description に差分がある**が、いずれも
export 時の意図的な適応であり「名前の取り合い」ではない（末尾の注記）。

## 全件表

| # | kind | name | 判定 | 根拠 |
|---|------|------|------|------|
| 1 | agent | `acceptance-tester` | 正常なミラー | 定義数=2 / repo-local+plugin:plangate / root 内相対パス一致 |
| 2 | agent | `code-optimizer` | 正常なミラー | 同上 |
| 3 | agent | `documentation-writer` | 正常なミラー | 同上 |
| 4 | agent | `explorer-agent` | 正常なミラー | 同上 |
| 5 | agent | `implementation-agent` | 正常なミラー | 同上 |
| 6 | agent | `implementer` | 正常なミラー | 同上 |
| 7 | agent | `linter-fixer` | 正常なミラー | 同上 |
| 8 | agent | `orchestrator` | 正常なミラー | 同上 |
| 9 | agent | `project-planner` | 正常なミラー | 同上 |
| 10 | agent | `qa-reviewer` | 正常なミラー | 同上 |
| 11 | agent | `requirements-analyst` | 正常なミラー | 同上 |
| 12 | agent | `retrospective-analyst` | 正常なミラー | 同上 |
| 13 | agent | `setup-coordinator` | 正常なミラー | 同上 |
| 14 | agent | `skill-designer` | 正常なミラー | 同上 |
| 15 | agent | `solution-architect` | 正常なミラー | 同上 |
| 16 | agent | `spec-writer` | 正常なミラー | 同上 |
| 17 | agent | `workflow-conductor` | 正常なミラー | 同上 |
| 18 | command | `ai-dev-workflow` | 正常なミラー | 同上 |
| 19 | command | `ai-loop-workflow` | 正常なミラー | 同上 |
| 20 | command | `codex-mvp-split` | 正常なミラー | 同上 |
| 21 | command | `plangate-setup` | 正常なミラー | 同上 |
| 22 | command | `working-context` | 正常なミラー | 同上 |
| 23 | skill | `acceptance-criteria-build` | 正常なミラー | 同上 |
| 24 | skill | `acceptance-review` | 正常なミラー | 同上 |
| **25** | skill | `ai-loop-cycle` | 正常なミラー | 同上 + **description 差分あり**（注記 A） |
| 26 | skill | `architecture-sketch` | 正常なミラー | 同上 |
| 27 | skill | `brainstorming` | 正常なミラー | 同上 |
| 28 | skill | `breakdown-gate` | 正常なミラー | 同上 |
| **29** | skill | `codex-multi-agent` | 正常なミラー | 同上 + **description 差分あり**（注記 B） |
| **30** | skill | `context-load` | 正常なミラー | 同上 + **description 差分あり**（注記 C） |
| 31 | skill | `diff-audit` | 正常なミラー | 同上 |
| 32 | skill | `edgecase-enumeration` | 正常なミラー | 同上 |
| 33 | skill | `feature-implement` | 正常なミラー | 同上 |
| 34 | skill | `intent-classifier` | 正常なミラー | 同上 |
| 35 | skill | `known-issues-log` | 正常なミラー | 同上 |
| 36 | skill | `nonfunctional-check` | 正常なミラー | 同上 |
| 37 | skill | `plangate-setup` | 正常なミラー | 同上 |
| 38 | skill | `ref-integrity-scan` | 正常なミラー | 同上 |
| 39 | skill | `requirement-gap-scan` | 正常なミラー | 同上 |
| 40 | skill | `risk-assessment` | 正常なミラー | 同上 |
| 41 | skill | `skill-creator` | 正常なミラー | 同上 |
| 42 | skill | `skill-policy-router` | 正常なミラー | 同上 |
| 43 | skill | `subagent-delegation-brief` | 正常なミラー | 同上 |
| 44 | skill | `subagent-driven-development` | 正常なミラー | 同上 |
| 45 | skill | `subagent-team-design` | 正常なミラー | 同上 |
| 46 | skill | `systematic-debugging` | 正常なミラー | 同上 |

## description 差分 3 件の内訳（実測 diff）

いずれも **配布先で正しく機能させるための export 適応**であり、
`hybrid-architecture.md`「他リポジトリへ export する場合は `plugin/plangate/`
配下の export 版で固有名を抽象化する」に沿う。

### 注記 A — `ai-loop-cycle`: リポジトリ内パス → 同梱 references

```
repo-local: 正本 = docs/workflows/ai-loop/00_concept.md、… = docs/workflows/ai-loop/rollout-policy.md。
plugin    : 正本 = 同梱 references/00_concept.md、… = 同梱 references/rollout-policy.md（導入先が独自正本を保持する場合はそちらを優先）。
```

export は自己完結している必要があるため、リポジトリ内パスを同梱 `references/` へ
書き換えている。これは差分が**あるべき**箇所。

### 注記 B — `codex-multi-agent`: 語順のみ

```
repo-local: Codex / Claude Code のどちらでも使える…
plugin    : Claude Code / Codex のどちらでも使える…
```

意味は同一。表記ゆれ。

### 注記 C — `context-load`: CLAUDE.md → AGENTS.md

```
repo-local: CLAUDE.md と依頼文から案件の前提・制約・品質基準を抽出し…
plugin    : AGENTS.md と依頼文から案件の前提・制約・品質基準を抽出し…
```

配布先ツールに合わせた正本ファイル名の抽象化（Rule 4 の export 適応）。

## 補足: 衝突ではないが観測された事象

**plugin にしか存在しない name が 15 件**ある（`ai-dev-plan` / `ai-dev-exec` /
`review-gate` / `subagent-dispatch` 等）。これらは **定義が 1 つしかない**ため
多重定義ではなく、本検査の対象外。ただし
「repo-local に対応物が無い skill が配布されている」という**配布レーンの非対称**
であり、#1144（enforcement 層の配布）と同じ領域の観測事実として handoff に記載する。
