# TASK-0021 品質・Rule 遵守レビュー報告

> レビュー実施日: 2026-04-19
> レビュー対象: Workflow 5 phase / Skill 10 個 / Agent 5 体 / Rule 統合 / Template
> 親 PBI: `docs/working/TASK-0021/pbi-input.md`

## 総合判定

**CONDITIONAL**

Rule 1〜5 の骨格設計は高品質で整合性が取れている。ただし以下 2 系統の課題がマージ前対応推奨。

1. **鮮度ズレ（major 相当）**: 複数 Agent / 挿入マップで「TASK-0026 / 0027 / 0028 で作成予定」と記載されているが、対象ファイル（`design.md` / `handoff.md` テンプレート、`plangate-v7-hybrid.md`）はすでに同 TASK 内で作成済。読者に未完了と誤解させる。
2. **存在しない参照（major 相当）**: `docs/workflows/README.md` の対応表で `release-manager` Agent が V-4 主担当として引用されているが、`.claude/agents/` に当該 Agent は存在しない。同じく `docs/plangate-v7-hybrid.md:175` の「既存 14 体」は実測 17 体と不一致。

## Rule 遵守スコア

| Rule | スコア | 備考 |
|------|--------|------|
| Rule 1（Workflow = 順序と完了条件のみ） | 5/5 | 5 phase 全て state 形式で記述。コードブロック / How to / 具体手順の混入なし（Grep 確認済）。 |
| Rule 2（Skill = 再利用単位） | 10/10 | 新設 10 個は特定技術スタック・TASK 番号への言及なし（既存 Skill の言及は対象外）。 |
| Rule 3（Agent = 責務のみ） | 4/5 | 責務・委譲・allowed-tools は明確。ただし「TASK-XXXX で作成予定」の鮮度ズレ記述が 5 件残存。`git 操作` などは抽象記述なので問題なし。 |
| Rule 4（案件固有情報 = CLAUDE.md） | 10/10 | 新設 Agent / Skill に Laravel / PostgreSQL / 特定スタック名の混入なし。境界ルールが `hybrid-architecture.md` に明記。 |
| Rule 5（最終成果物 = handoff） | 5/5 | `05_verify_and_handoff.md` で全 PBI 必須化 + `working-context.md` の handoff 節 + handoff.md テンプレートで整合。light モード以下でも「該当なし」と明記する運用を明示。 |

**合計**: 34/35

## 観点別詳細

### 観点 A: Rule 1 遵守（Workflow）

- 全 5 phase 定義（`01_context_bootstrap.md` 〜 `05_verify_and_handoff.md`）で完了条件が「〜が明文化されている」「〜が決定されている」の state 形式で統一されており、動作形式（「〜する」）への混入なし。
- `grep -l` で検出対象となるコードブロック（```typescript / ```python / ```bash 等）は 0 件。
- Skill / Agent 名の引用は存在するが、実装に踏み込んだ記述はない。
- 補助 3 ファイル（`README.md` / `execution-sequence.md` / `plangate-insertion-map.md` / `skill-mapping.md`）には手順が含まれるが、これは phase 定義本体ではなくナビゲーション層であり Rule 1 対象外。

### 観点 B: Rule 2 遵守（Skill）

- 新設 10 個（context-load / requirement-gap-scan / nonfunctional-check / edgecase-enumeration / risk-assessment / acceptance-criteria-build / architecture-sketch / feature-implement / acceptance-review / known-issues-log）全てに特定技術名（Laravel / PostgreSQL 等）の混入なし。
- TASK 番号への言及も 0 件。
- frontmatter（name, description + Use when 句）構造が全 Skill で統一されており、複数プロジェクトで再利用可能な粒度。
- 検出された既存 Skill（codex-multi-agent, self-review 等）への「プロジェクト固有」記述は本 TASK 対象外。

### 観点 C: Rule 3 遵守（Agent）

- 新設 5 Agent（orchestrator / requirements-analyst / solution-architect / implementation-agent / qa-reviewer）全てに責務 / 委譲関係 / allowed-tools が明記されている。
- 案件固有技術スタック名の混入なし。
- **課題**: 「TASK-0026 / 0027 / 0028 で作成予定」の記述が 5 箇所残存しており、実態（既に作成済）と齟齬。

### 観点 D: Rule 4 遵守（境界ルール）

- CLAUDE.md（プロジェクトルール）/ Skill（再利用）/ Hook（強制）の 3 層境界が `hybrid-architecture.md` と `plangate-v7-hybrid.md` で整合して記述。
- 新設 Skill / Agent に案件固有情報の漏れなし。

### 観点 E: Rule 5 遵守（Handoff 標準化）

- `05_verify_and_handoff.md` で「全 PBI（mode 問わず）で handoff.md を必須出力」を明記。
- `docs/working/templates/handoff.md` に必須 6 要素（要件適合 / 既知課題 / V2 候補 / 妥協点 / 引き継ぎ文書 / テスト結果サマリ）完備。
- `.claude/rules/working-context.md` の L81-98 および L244-278 に handoff 節があり、テンプレート・責任・例外（critical 緊急時の事後追補）が整合。
- light モード以下でも「該当なし」と明記する運用を明示しており Rule 5 と整合。

### 観点 F: ドキュメント品質

- 構造は概ね良好（目次あり、セクション長さ適正）。
- 重複記述は「Rule 1〜5 表」「境界ルール表」が `plangate-v7-hybrid.md` と `hybrid-architecture.md` の双方にある。`hybrid-architecture.md` が正本、`plangate-v7-hybrid.md` が解説と役割分担しているため許容範囲（DRY よりも自己完結性を優先する設計）。
- 数値不整合: `plangate-v7-hybrid.md:175` 「既存 14 体」は実測 17 体と不一致。

## Severity 付き指摘一覧

| ID | Severity | 箇所 | 指摘 | 推奨対応 |
|----|----------|------|------|---------|
| I-01 | major | `.claude/agents/qa-reviewer.md:42` | `handoff package 要素（TASK-0027 で仕様確定）` — テンプレートは `docs/working/templates/handoff.md` に既に存在 | `docs/working/templates/handoff.md` への参照に修正 |
| I-02 | major | `.claude/agents/qa-reviewer.md:60` | `handoff.md テンプレート: docs/working/templates/handoff.md（TASK-0027 で作成予定）` — 既に作成済 | 「作成予定」を削除 |
| I-03 | major | `.claude/agents/implementation-agent.md:52` | `design.md テンプレート: …（TASK-0026 で作成予定）` — 既に作成済 | 「作成予定」を削除 |
| I-04 | major | `.claude/agents/solution-architect.md:39` | `design 成果物（…、TASK-0026 で仕様確定）` — 既に確定済 | 「TASK-0026 で仕様確定」を削除 |
| I-05 | major | `.claude/agents/solution-architect.md:58` | `design.md テンプレート: …（TASK-0026 で作成予定）` — 既に作成済 | 「作成予定」を削除 |
| I-06 | major | `.claude/agents/requirements-analyst.md:60` | `Rule: docs/plangate-v7-hybrid.md（TASK-0028 で整備予定）` — 既に整備済 | 「整備予定」を削除 |
| I-07 | major | `docs/workflows/plangate-insertion-map.md:125` | `handoff.md テンプレート: …（TASK-0027 で作成予定）` — 既に作成済 | 「作成予定」を削除 |
| I-08 | major | `docs/workflows/README.md:61` | V-4 の主担当として `release-manager` を引用するが `.claude/agents/` に当該 Agent は存在しない | Agent 未実装なら引用を除去、または legacy / 将来追加と明記 |
| I-09 | major | `docs/plangate-v7-hybrid.md:175` | `.claude/agents/ — 責務ベース 5 体 + 既存 14 体` — 実測 17 体 | 数値を 17 に修正、または正確な数え方（除外対象を明記） |
| I-10 | minor | `docs/workflows/01_context_bootstrap.md:25` | `context-load（親 PBI 定義の Skill 10 個のうち Scan カテゴリ）` — 親 PBI への内部参照が Rule 1 の Skill 名引用を越えて補足を足している | 補足を削除、Skill 名のみ引用にするか、`docs/workflows/skill-mapping.md` への参照に変更 |
| I-11 | minor | `docs/workflows/README.md:31` | `WF-04 → WF-05: known-issues（+ コード差分）` — 02/03 の artifact クラス名と粒度が揃っているが、WF-04 の成果物は「コード差分 + known-issues メタ」で主従が逆の読み方もできる | 「code-diff + known-issues」等、主成果物を先頭に置く表記を検討 |
| I-12 | minor | `docs/plangate-v7-hybrid.md:20-22` | v5 / v6 / v7 表の行頭「v5」「v6」「**v7**」の強調方式が不統一（v7 のみ太字） | 強調の意図（本書対象を示す）を備考列で明示、または太字を v7 ラベルに集約 |
| I-13 | minor | `docs/workflows/skill-mapping.md:5` | `本表は .claude/skills/ 配下に配置された 10 個の再利用可能 Skill` — 実際は既存 Skill と混在配置（18 ディレクトリ） | 「本 TASK で新設した 10 個」と限定表記に |
| I-14 | info | `.claude/agents/orchestrator.md:24-31` | 委譲関係の code block がツリー表記。他 Agent は表形式。統一感の観点で表記が揃っていない | 表形式に統一（可読性向上、軽微） |
| I-15 | info | `docs/workflows/03_solution_design.md:38` | `テンプレート: docs/working/templates/design.md（7 要素構造）` — テンプレート実物は 7 要素だが本 phase 完了条件は 6 項目（モジュール構成〜技術的妥協点）で行数が違う | 「7 要素構造」の数え方（メタ情報+7 セクション か）を明示 |

## 品質課題（nit pick 以上）

### 鮮度管理の欠如（major）

TASK-0021 のサブ issue（#26, #27, #28）がすべて本 PBI 内で完了したにもかかわらず、「作成予定」「仕様確定予定」「整備予定」の記述が 5 ファイル 7 箇所に残存。導入時点で「将来作成するファイル」として書かれた記述が、完了後に更新されていない。

→ **推奨**: `grep -rn "作成予定\|仕様確定\|整備予定" .claude/agents/ docs/workflows/ docs/plangate-v7-hybrid.md` をマージ前チェックリストに入れる。

### 存在しない Agent の引用（major）

`release-manager` Agent は PlanGate v5/v6 でも `.claude/agents/` に実体なし。対応表で引用するなら「v5/v6 の将来実装候補」と注釈すべき。

### 数値誤り（minor）

`plangate-v7-hybrid.md:175` の「既存 14 体」は実測 17 体。過去 PBI で「14 体」と記載された時点の数値が更新されていない可能性。

### Rule 違反でないが改善余地（info）

- Agent 5 体の frontmatter に `tools` が列挙されているが、`allowed-tools` セクションと二重管理。`orchestrator.md` のみ `allowed-tools` セクションがあり他 Agent にはない → 統一推奨。
- `skill-mapping.md:44-51` の Agent × Skill 表で、`solution-architect` の `architecture-sketch` / `risk-assessment` は「呼び出し Skill」として妥当だが、`qa-reviewer` の `edgecase-enumeration` 呼び出しは WF-02 協働用途で、主担当とは別 context。表に注釈があれば誤解を防げる。

## 推奨対応優先度

1. **マージ前に修正（major）**: I-01 〜 I-09（7〜9 箇所のテキスト置換のみで完了）
2. **軽微（minor）**: I-10 〜 I-13（任意、別チケット化可）
3. **info**: I-14 〜 I-15（フォローアップ）
