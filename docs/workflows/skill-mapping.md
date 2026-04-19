# Skill × Phase マッピング表

> PlanGate × Workflow / Skill / Agent ハイブリッドアーキテクチャ
>
> 本表は `.claude/skills/` 配下に配置された 10 個の再利用可能 Skill と、`docs/workflows/` で定義された 5 phase（WF-01〜WF-05）の対応を示す。

## カテゴリ別 Skill 一覧

| Skill | カテゴリ | 主な Phase | 役割 | 出力 artifact |
| --- | --- | --- | --- | --- |
| `context-load` | Scan | WF-01 | CLAUDE.md と依頼文から前提を抽出 | 前提サマリ |
| `requirement-gap-scan` | Scan | WF-02 | 要件の抜け漏れ検出 | 追加要件候補 |
| `nonfunctional-check` | Check | WF-02 | 性能・保守性・安全性の確認 | 非機能要件 |
| `edgecase-enumeration` | Check | WF-02 | 境界条件・例外条件の列挙 | エッジケース一覧 |
| `risk-assessment` | Check | WF-02 / WF-03 | 制約・未確定要素の洗い出し | リスク一覧 |
| `acceptance-criteria-build` | Design | WF-02 | 受け入れ条件の明文化 | AC 一覧 |
| `architecture-sketch` | Design | WF-03 | 構成案の叩き台作成 | 構成案 |
| `feature-implement` | Build | WF-04 | 個別機能の実装 | コード差分 |
| `acceptance-review` | Review | WF-05 | 要件適合レビュー | 適合/不足一覧 |
| `known-issues-log` | Review | WF-05 | 妥協点・既知不具合の文書化 | 既知課題表 |

## Phase × Skill 対応（逆引き）

| Phase | 呼び出す Skill |
| --- | --- |
| **WF-01** Context Bootstrap | `context-load` |
| **WF-02** Requirement Expansion | `requirement-gap-scan` / `nonfunctional-check` / `edgecase-enumeration` / `risk-assessment` / `acceptance-criteria-build` |
| **WF-03** Solution Design | `architecture-sketch` / `risk-assessment` |
| **WF-04** Build & Refine | `feature-implement` |
| **WF-05** Verify & Handoff | `acceptance-review` / `known-issues-log` |

## 全 Phase カバレッジ確認

- WF-01: ✅ 1 Skill
- WF-02: ✅ 5 Skill
- WF-03: ✅ 2 Skill（うち risk-assessment は WF-02 と共有）
- WF-04: ✅ 1 Skill
- WF-05: ✅ 2 Skill

**結果**: 全 5 phase が 1 個以上の Skill でカバーされている。

## Agent との関係

| Agent | 主に呼び出す Skill |
| --- | --- |
| `orchestrator` | （phase 遷移制御のため、直接的な Skill 呼び出しは少ない） |
| `requirements-analyst` | `context-load` / `requirement-gap-scan` |
| `qa-reviewer` | `nonfunctional-check` / `edgecase-enumeration` / `acceptance-criteria-build` / `acceptance-review` / `known-issues-log` |
| `solution-architect` | `architecture-sketch` / `risk-assessment` |
| `implementation-agent` | `feature-implement` |

詳細な Agent 定義は TASK-0025（Issue #25）で扱う。

## 設計原則の遵守

- **Rule 2**: 各 Skill は再利用単位に限定されており、案件固有情報を含まない
- **Rule 4**: 案件固有情報は CLAUDE.md に寄せ、Skill では抽象化された手順のみ扱う

## 関連

- 各 Skill の詳細: `.claude/skills/<skill-name>/SKILL.md`
- Workflow 定義: `docs/workflows/0*_*.md`
- 親 PBI: `docs/working/TASK-0021/pbi-input.md`
