# TASK-0021 一貫性レビュー報告（ドキュメント相互参照・一貫性）

> 対象: TASK-0021（PlanGate × Workflow/Skill/Agent ハイブリッドアーキテクチャ）全成果物
> 実施日: 2026-04-19
> レビュアー: explorer-agent（読み取り専用・コード変更なし）

## 総合判定

**WARN**

critical 級不整合は無し。major 級 3 件 / minor 級 4 件を検出。いずれも追補で解消可能。親 PBI 受入基準 9 件のうち 8 件は充足、1 件（v5/v6 ドキュメントとの整合）は TASK-0028 の実装未完により部分充足。

---

## 観点別結果

### 1. Skill / Agent / Workflow 相互参照

**不整合: 2 件（major 1 / minor 1）**

| 項目 | 検出内容 |
| --- | --- |
| `implementation-agent` の呼び出し Skill に `self-review` が含まれる | 親 PBI 定義の 10 Skill に `self-review` は含まれていない。`self-review` は既存 `.claude/skills/self-review/` に存在する PlanGate v5 系 Skill であり、v7 新設 10 Skill の一覧（skill-mapping.md / WF-04 定義 / pbi-input.md）にも載っていない。WF-04 定義では `feature-implement` のみを呼び出し Skill と規定。 |
| `docs/workflows/README.md` の PlanGate 対応表で V-4 主担当を `release-manager` と記載 | `release-manager` agent は `.claude/agents/` に存在しない（`docs/plangate-plugin-migration.md:97` で不在が明記、`docs/working/TASK-0019/plan.md:13` でも除外対象）。critical モード限定とはいえ、存在しない agent を対応表に置くのは孤立参照。 |

**整合している部分**:
- WF-01〜WF-05 の「呼び出す Skill」と Skill 側の「想定 Phase」は `context-load` / `requirement-gap-scan` / `nonfunctional-check` / `edgecase-enumeration` / `risk-assessment`（WF-02/03 両記載）/ `acceptance-criteria-build` / `architecture-sketch` / `feature-implement` / `acceptance-review` / `known-issues-log` の 10 個すべて双方向一致。
- skill-mapping.md / execution-sequence.md と WF-0N ファイルの phase × 主担当 agent は一致。

### 2. artifact クラス一貫性

**不整合: 0 件**

- 5 クラス（**context** / **requirements** / **design** / **known-issues** / **handoff**）の命名が WF-01〜WF-05、Skill 10 個、Agent 5 体、hybrid-architecture.md、plangate-v7-hybrid.md、templates/design.md、templates/handoff.md 全てで一致。
- `design.md` の 7 要素（モジュール構成 / データフロー / 状態管理 / 失敗時扱い / テスト観点 / 依存制約 / 技術的妥協点）が WF-03 定義、architecture-sketch Skill、solution-architect Agent、templates/design.md で一致。
- `handoff.md` の 6 要素（要件適合 / 既知課題 / V2 候補 / 妥協点 / 引き継ぎ文書 / テスト結果）が WF-05 定義、acceptance-review + known-issues-log Skill、qa-reviewer Agent、templates/handoff.md、working-context.md、hybrid-architecture.md で一致。

### 3. Rule 1〜5 適用

**不整合: 0 件（ただし minor 級の網羅性指摘 1 件）**

- Rule 1〜5 の定義が `hybrid-architecture.md` と `plangate-v7-hybrid.md` で完全一致（Workflow は順序と完了条件 / Skill は再利用単位 / Agent は責務 / CLAUDE.md に案件固有情報 / handoff 集約）。
- Rule 4 の境界表（CLAUDE.md / Skill / Hook）が両ドキュメントに同内容で記載。
- 各 WF / Skill / Agent / Template の末尾に該当する Rule 番号が明示（WF-01〜05 は Rule 1 と Rule 5、Skill は Rule 2、Agent は Rule 3、handoff は Rule 5）。
- **minor**: requirements-analyst.md:60 / solution-architect.md:58 / implementation-agent.md:52 / qa-reviewer.md:60 が `TASK-0026 / TASK-0027 / TASK-0028 で作成予定` と書いているが、当該 TASK は既に完了し template / 正本ドキュメントが存在する。Agent 側の参照表現を現在形（"存在する"）に更新すべき。

### 4. 命名規約統一

**不整合: 0 件**

- Skill 名: すべてハイフン区切り小文字で統一（`context-load` / `requirement-gap-scan` / `acceptance-criteria-build` 等）。10 個すべて SKILL.md frontmatter の `name:` と、skill-mapping.md、WF 各 phase、Agent の「呼び出し Skill」節で完全一致。
- Agent 名: 5 体すべてハイフン区切りで統一（`orchestrator` / `requirements-analyst` / `solution-architect` / `implementation-agent` / `qa-reviewer`）。
- Phase 名: `WF-01`〜`WF-05` でハイフン区切り大文字の 2 桁形式に統一（`WF-1` 等の揺れは検出されず）。

### 5. 孤立参照

**不整合: 2 件（minor 2）**

| 項目 | 検出内容 |
| --- | --- |
| `docs/workflows/plangate-insertion-map.md:125` に `handoff.md テンプレート: ...（TASK-0027 で作成予定）` | 実際には `docs/working/templates/handoff.md` は既に存在。`予定` 表記を現在形に更新すべき。 |
| `requirements-analyst.md:60` に `docs/plangate-v7-hybrid.md（TASK-0028 で整備予定）` | 実際には同ファイルは既に存在。現在形に更新すべき。 |

**存在確認した参照**:
- `docs/ai-driven-development.md`（working-context.md から参照）— 存在
- `docs/ai/project-rules.md`（CLAUDE.md から参照）— 存在
- `docs/working/templates/design.md` / `handoff.md` — 存在
- Issue #22 / pbi-input.md — 存在

### 6. v5 / v6 / v7 位置関係

**不整合: 1 件（major 1）**

| 項目 | 検出内容 |
| --- | --- |
| `docs/plangate-v6-roadmap.md` に v7 への導線・位置付け記述がゼロ | `plangate.md:9` には `> v7 ハイブリッドアーキテクチャ: 本書の統制層を維持しつつ...詳細は docs/plangate-v7-hybrid.md 参照` が追加済みだが、`plangate-v6-roadmap.md` には v7 言及が 0 件（`grep -i 'v7\|hybrid\|ハイブリッド' → 0 match`）。TASK-0028 の plan.md / todo.md に「v6 roadmap に v7 導線 note 追加」タスク（T-6）が残っており、実装未完。親 PBI 受入基準『既存 PlanGate v5/v6 ドキュメントとの整合』は v5 のみ充足、v6 は未充足。 |

**整合している部分**:
- `plangate-v7-hybrid.md:18-34` に v5 / v6 / v7 の比較表と差分が明記。
- `plangate-v7-hybrid.md:148-166` に Phase 1 opt-in → Phase 2 default → Phase 3 full v7 の移行パスが記載され、`plangate-insertion-map.md:102-117` と一致。
- `plangate.md:9` に v7 への導線 note 追加済み。
- `README.md:146` で v6 roadmap へのリンクが維持され、廃止扱いではない（v7 と並立）。

---

## Severity 付き指摘一覧

| ID | Severity | 箇所 | 指摘 | 推奨対応 |
| --- | --- | --- | --- | --- |
| H-01 | major | `.claude/agents/implementation-agent.md:24` | 呼び出し Skill に `self-review` を含むが、TASK-0021 で整備された 10 Skill に未包含。`self-review` は PlanGate v5 系で WF-04 とは別系統。Rule 3（Agent 責務のみ）と skill-mapping.md の「Agent との関係」表（`implementation-agent → feature-implement`）とも不整合。 | 選択肢 A: WF-04 で `self-review` も併用する正式方針とし、skill-mapping.md の Agent 対応表に `self-review` を追記し、WF-04 呼び出し Skill にも明記。選択肢 B: `self-review` 参照を削除し、`feature-implement` 内の自己レビュー記述に一本化。いずれか決定。 |
| H-02 | major | `docs/workflows/README.md:61` | V-4 主担当を存在しない `release-manager` と記載。 | 脚注で「release-manager は `.claude/agents/` に未配置（critical モード時に新規作成予定）」と明記、または TASK-0025 スコープへ吸収。 |
| H-03 | major | `docs/plangate-v6-roadmap.md` 全体 | v7 への導線 note が未追加。TASK-0028 T-6 が未完了で、親 PBI 受入基準『v5/v6 との整合』が部分充足にとどまる。 | `plangate-v6-roadmap.md` 冒頭に `plangate.md:9` 同等の導線 note を追加（TASK-0028 T-6 を完了する）。 |
| H-04 | minor | `docs/workflows/plangate-insertion-map.md:125` | `handoff.md テンプレート ...（TASK-0027 で作成予定）` が現実と不一致（既に存在）。 | `docs/working/templates/handoff.md` への直リンクに置換、`予定` を削除。 |
| H-05 | minor | `.claude/agents/requirements-analyst.md:60` | `docs/plangate-v7-hybrid.md（TASK-0028 で整備予定）` の `予定` が不整合。 | 現在形に修正。 |
| H-06 | minor | `.claude/agents/solution-architect.md:58`, `implementation-agent.md:52` | `design.md テンプレート（TASK-0026 で作成予定）` が不整合（存在済み）。 | 現在形に修正。 |
| H-07 | minor | `.claude/agents/qa-reviewer.md:42,60` | `handoff package 要素（TASK-0027 で仕様確定）` / `handoff.md テンプレート（TASK-0027 で作成予定）` が不整合（確定済み）。 | 現在形に修正し、templates/handoff.md へ直リンク。 |
| H-08 | info | `docs/workflows/execution-sequence.md:35` | シーケンス図内 `I->>I: feature-implement + self-review` は H-01 と同じ問題の派生。H-01 の決着に合わせて揃える。 | H-01 の方針に追従。 |

---

## 補足: PBI 受入基準の充足確認

| # | 受入基準 | 判定 | 根拠 |
| --- | --- | --- | --- |
| 1 | Workflow 5 phase 定義（目的/入力/完了条件/Skill/Agent） | PASS | WF-01〜WF-05 全て 5 要素揃う |
| 2 | Skill 10 個配置（入出力定義） | PASS | `.claude/skills/` 配下 10 個すべて frontmatter + 入力 + 出力セクションあり |
| 3 | Agent 5 体配置（責務/委譲/allowed-tools） | PASS | 5 体すべて tools 宣言、責務、委譲関係セクションあり |
| 4 | WF-03 独立 + design artifact 出力 | PASS | templates/design.md 7 要素、plan.md との役割分担明記 |
| 5 | WF-05 で handoff を毎回必須出力 | PASS | working-context.md / hybrid-architecture.md / WF-05 / templates/handoff.md で必須化を宣言 |
| 6 | Rule 1〜5 明文化 | PASS | hybrid-architecture.md 正本 + plangate-v7-hybrid.md で展開 |
| 7 | CLAUDE.md / Skill / Hook 境界ルール明文化 | PASS | hybrid-architecture.md:52-68 / plangate-v7-hybrid.md:99-113 |
| 8 | 既存 v5/v6 ドキュメントとの整合 | **WARN** | v5（plangate.md）は PASS、v6（plangate-v6-roadmap.md）は v7 言及ゼロ（H-03） |
| 9 | 実行シーケンス（orchestrator → … → orchestrator）がドキュメント化 | PASS | execution-sequence.md mermaid 図 + plangate-v7-hybrid.md:134-146 |

**充足: 8/9（89%）**。H-03 の対応（TASK-0028 T-6 完了）で 9/9 に到達見込み。

---

## 関連

- 親 PBI: `docs/working/TASK-0021/pbi-input.md`
- Rule 正本: `.claude/rules/hybrid-architecture.md`
- 統合ドキュメント: `docs/plangate-v7-hybrid.md`
- 本レビュー実施方針: AI運用4原則 第3原則（読み取り専用探索、決定はユーザー）
