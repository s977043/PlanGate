# PlanGate フロー接続 — サブエージェント委譲プロトコル

> **Status**: Specification（v1）
> 親: [#710](https://github.com/s977043/plangate/issues/710) サブエージェント委譲プロトコルをPlanGate運用に組み込む
> 対応子 Issue: [#715](https://github.com/s977043/plangate/issues/715) PlanGateフローへサブエージェント委譲プロトコルを接続する
> 関連（同ディレクトリ）: [README.md](./README.md)（正本入口・全体像、#711）/ [outcome-contract.md](./outcome-contract.md)（OUTCOME 契約、#712）/ [dispatch-template.md](./dispatch-template.md)（派遣プロンプト必須8要素、#713）/ [behavior-norms.md](./behavior-norms.md)（行動規範、#714）/ [examples.md](./examples.md)（サンプル、#716）

## 0. 位置づけ（一行の棲み分け）

本ファイルは **「PlanGate の Plan → Review → Approval → Execution の、どのタイミングでサブエージェントへ委譲するか」** を定義する接続層である。派遣プロンプトの中身は [`dispatch-template.md`](./dispatch-template.md)、報告契約は [`outcome-contract.md`](./outcome-contract.md)、行動規範は [`behavior-norms.md`](./behavior-norms.md) が正本を持つ（本ファイルで二重定義しない）。**承認境界（C-3 / C-4 ゲート、親子 PBI Gate の AS-1〜5 / `ChildExecAllowed` / `ParentDone`）は本ファイルが変更・緩和する対象ではなく**、[`.claude/rules/orchestrator-mode.md`](../../../.claude/rules/orchestrator-mode.md) の正本にすべて従う。本プロトコルは既存フローへの **拡張** であり、置換ではない（#710 方針 / #711 決定と一致）。

## 1. 対象フロー × PlanGate 既存フェーズ 対応表

[`docs/workflows/README.md`](../../workflows/README.md) の WF-00〜WF-07 と PlanGate の ABCD 呼称（[`docs/pages/reference/glossary.md`](../../pages/reference/glossary.md) が対応表の正本）を用いて、#715 が挙げる 5 つの対象フローを既存フェーズへ接続する。

| #   | 対象フロー（#715）              | 接続先フェーズ                                                           | 委譲時に使うテンプレート                                                                                      | 併用する既存 Skill                                                                              |
| --- | ------------------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| 1   | Plan 作成時の追加調査           | **WF-01 Context Bootstrap → WF-02 Requirement Expansion**（ABCD: A → B） | [4-A 調査エージェント向け](./dispatch-template.md#4-a-調査エージェント向け)                                   | `requirement-gap-scan` / `context-load`                                                         |
| 2   | Plan レビュー時の別視点レビュー | **C-1 セルフレビュー / C-2 外部AIレビュー**（計画品質ゲート、WF 外）     | [dispatch-template.md](./dispatch-template.md) 4-C「レビュー/監査/真因調査エージェント向け」（`review=true`） | `plan-quality-check` / `plan-quality-reviewer` / `acceptance-criteria-build`                    |
| 3   | Approval 前のリスク監査         | **C-3 直前**（人間レビュー前、計画承認ゲート）                           | 4-C（`review=true`）                                                                                          | `risk-assessment`                                                                               |
| 4   | Execution 中の限定実装          | **D: Agent 実行（TDD）/ WF-04 Build & Refine**                           | [4-B 実装エージェント向け](./dispatch-template.md#4-b-実装エージェント向け)                                   | `plugin/plangate/skills/subagent-dispatch`（`dispatch/task-NNN-brief.md` とファイル授受を併用） |
| 5   | Failure / partial 時の追指示    | 上記 1〜4 の**どのフェーズでも発生しうる**（フェーズ非依存）             | [dispatch-template.md](./dispatch-template.md) 4-D「同一サブエージェントへの追指示」                          | —                                                                                               |

> 表の「接続先フェーズ」はあくまで**委譲の契機**であり、C-1〜C-4 の判定主体・判定基準そのものは変更しない。例えば #2/#3 でサブエージェントが `review=true` で指摘を返しても、C-3 の APPROVE / CONDITIONAL / REJECT を決めるのは人間である（[`working-context.md`](../../../.claude/rules/working-context.md) C-3 ゲート正本のまま）。

## 2. 委譲判断基準

### 2.1 Iron Law（`codex-multi-agent` からの継承）

> `今すぐ主担当（オーケストレータ）が自分でやるべき作業は委譲しない`（[`.claude/skills/codex-multi-agent`](../../../.claude/skills/codex-multi-agent/SKILL.md) Iron Law）

委譲は目的ではなく手段である。独立して進められる具体的なタスクがない限り分割しない。

### 2.2 委譲する / しないケース（#715 委譲判断基準案の転記）

| 委譲する               | 委譲しない                             |
| ---------------------- | -------------------------------------- |
| 真因調査               | 単純な文言修正                         |
| 設計レビュー           | 明確な1ファイル変更                    |
| リスク列挙             | 既に判断済みの軽微な作業               |
| 複数観点レビュー       | オーケストレータが即答できる小さな確認 |
| 長文 SSOT の照合       |                                        |
| 既存調査結果の独立確認 |                                        |
| 実装前の影響範囲確認   |                                        |

**安全側の判定**: 該当が曖昧な場合は「委譲しない」側に倒す（委譲そのものを目的化しない。#715 注意点）。委譲により品質向上・観点分離・並列調査の効果が見込める場合に限定する。

### 2.3 Agent 単発 vs Workflow 化（#710 方針 5）

Agent 単発ではハードなコスト上限を強制できない（ソフト上限のみ）前提で使い分ける。

| 状況                                                           | 選択                                                                                                                 |
| -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| 小〜中規模タスク（表 1 の #1〜#3、単発の調査・レビュー・監査） | **Agent 単発 + ソフト上限**（[`dispatch-template.md`](./dispatch-template.md) 要素6 の「ソフト上限」欄）             |
| 長期調査・多段処理（複数フェーズにまたがる継続タスク）         | **Workflow 化**（`docs/workflows/0N_*.md` として phase 定義。単発 Agent への丸投げにしない）                         |
| ハード予算（トークン上限・ステップ上限を機構として強制したい） | `budget.remaining()` 相当の仕組みを持つ **Workflow 側**に載せる（Agent 単発では実現しない。将来拡張、本 PBI 範囲外） |

## 3. オーケストレータの責務（実作業をなぞらない）

オーケストレータの責務定義・完全な受け入れ確認チェックリストは [`README.md`](./README.md) §3 と [`outcome-contract.md`](./outcome-contract.md) §6 が正本（本ファイルで二重定義しない）。要旨のみ再掲する。

- オーケストレータは **派遣プロンプトの作成 / Agent 起動 / 完了結果の受領 / 最低限の受け入れ確認 / P0-P1-P2 順のユーザー確認 / 同一サブエージェントへの `SendMessage` 追指示** に責務を限定し、実作業（調査・実装・レビュー本体）を自分でなぞらない
- サブエージェントの報告は **丸呑みしない**。受け入れ確認 5 項目（[`outcome-contract.md`](./outcome-contract.md) §6）のいずれか FAIL で `SendMessage` 是正要求、P0 が含まれる場合はユーザーへ即時エスカレーション

## 4. `SendMessage` 追指示 vs 新規 spawn の使い分け

issue #715 のやること「`SendMessage` で同一サブエージェントへ追指示する条件」「新規 spawn すべき条件」を以下で定義する。

### 4.1 `SendMessage` 追指示を選ぶ条件（同一サブエージェント継続）

- 直前の報告が `OUTCOME: partial` で、**不足分がスコープ変更を伴わず明確**（例: テストの一部が未実行だっただけ）
- 受け入れ確認（[`outcome-contract.md`](./outcome-contract.md) §6）で FAIL した項目が **契約違反の是正**（`OUTCOME` 表記ゆれ、P0/P1/P2 未分類等）であり、タスク内容自体は変わらない
- 会話コンテキストの継続に価値がある（同一調査の深掘り、同一実装への修正依頼で、前提の再説明コストの方が高い）
- 前回の制約（read-only / write 対象 worktree 等）を変更しない

→ [`dispatch-template.md`](./dispatch-template.md) の 4-D テンプレートを用い、**前回の完了状態の要約を省略しない**（暗黙の継続を前提にしない）。

### 4.2 新規 spawn を選ぶ条件（別セッションで再委譲）

- `OUTCOME: failure` で、原因が **前提・環境・スコープの誤り**であり、渡すべき「既知の事実」（必須8要素の要素4）自体を作り直す必要がある
- 委譲するロール・観点が変わる（例: 調査 → 実装、implementer → reviewer）
- 会話が長くなり、誤った仮説の蓄積・スコープ逸脱等の **コンテキスト汚染リスク**が高まっている
- `review=true` の独立検証で「固定化されていない別の目」が必要な場合（同一エージェントに続けさせると視点が固定化し、二重チェックの意味が薄れる）
- P0 の要判断事項がユーザー判断で解消され、**別の制約・別のスコープ**でタスクを再開する場合

### 4.3 判定に迷った場合

新規 spawn 側に倒す（コンテキスト汚染や視点固定化のリスクを、追指示の効率より優先する）。

## 5. 既存承認ゲート・既存フローとの整合（矛盾しない確認 / #710・#715 受け入れ条件）

- **C-3 / C-4 ゲート**: 変更しない。サブエージェントが `review=true` でリスク監査（表 1 の #2/#3）を返しても、APPROVE / CONDITIONAL / REJECT（C-3）や APPROVE / REQUEST CHANGES / REJECT（C-4）の**判定主体は人間のまま**（[`working-context.md`](../../../.claude/rules/working-context.md)）
- **AS-1〜5 / `ChildExecAllowed` / `ParentDone`**（[`.claude/rules/orchestrator-mode.md`](../../../.claude/rules/orchestrator-mode.md)）: 変更しない。親子 PBI の Gate 通過判定に本プロトコルは関与しない。子 PBI exec 中に発生する「Execution 中の限定実装」委譲（表 1 の #4）は、`ChildExecAllowed` が既に成立している前提でのみ行う
- **`lite_eligible` / C-3 条件付き降格**（[`mode-classification.md`](../../../.claude/rules/mode-classification.md)）: 本プロトコルは lite 判定基準を変更しない。Hardening Override 対象パス（`.claude/rules/*.md` 等 9 カテゴリ）への実装委譲は、[`dispatch-template.md` 4-B](./dispatch-template.md#4-b-実装エージェント向け) の制約欄で **Write/Edit 禁止**を明記する（HO は常時 AI 直接編集不可。[`ho-change-workflow.md`](../ho-change-workflow.md)）
- **`subagent-dispatch`（並列 dispatch）との関係**: 高 mode（high-risk/critical）でのロール別並列実行・`dispatch/` ファイル授受は [`plugin/plangate/skills/subagent-dispatch`](../../../plugin/plangate/skills/subagent-dispatch/SKILL.md) の責務のまま。本プロトコルは個々の派遣プロンプトの自己完結性契約を提供するのみで、並列化の判断・分配構造を代替しない（[`README.md`](./README.md) §2.5 参照）

## 6. HO への接続（本ファイルは非HO）

本ファイル自体は `docs/` 配下の非 Hardening Override（HO）ファイルであり、直接作成・編集できる。一方、`.claude/rules/orchestrator-mode.md` / `.claude/rules/responsibility-classes.md` / `CLAUDE.md` / `AGENTS.md` への **本プロトコルへの参照導線追加**は HO パスへの変更に該当するため、AI が直接編集せず [`scripts/apply-subagent-delegation-wiring.sh`](../../../scripts/apply-subagent-delegation-wiring.sh)（非HO・`--dry-run` 既定の apply スクリプト）に隔離し、Human が確認・適用する（[`ho-change-workflow.md`](../ho-change-workflow.md) 標準フロー準拠）。

## 7. 参照

- [README.md](./README.md) — 配置 ADR・オーケストレータ責務・全体索引（#711）
- [outcome-contract.md](./outcome-contract.md) — OUTCOME / P0-P1-P2 / 検証状態・受け入れ確認チェックリスト正本（#712）
- [dispatch-template.md](./dispatch-template.md) — 派遣プロンプト必須8要素・バリアント別テンプレート（#713）
- [behavior-norms.md](./behavior-norms.md) — 行動規範 軽量版・フル版（#714）
- [examples.md](./examples.md) — サンプル派遣プロンプト・OUTCOME 出力例・検証手順（#716）
- [`docs/workflows/README.md`](../../workflows/README.md) — WF-00〜WF-07 の目的・完了条件
- [`.claude/rules/orchestrator-mode.md`](../../../.claude/rules/orchestrator-mode.md) / [`docs/orchestrator-mode.md`](../../orchestrator-mode.md)
- [`.claude/rules/working-context.md`](../../../.claude/rules/working-context.md) — C-3 / C-4 ゲート正本
- [`.claude/rules/mode-classification.md`](../../../.claude/rules/mode-classification.md) — lite_eligible / Hardening Override 対象パス
- [`.claude/skills/codex-multi-agent`](../../../.claude/skills/codex-multi-agent/SKILL.md) — 委譲判断基準の Iron Law
- [`plugin/plangate/skills/subagent-dispatch`](../../../plugin/plangate/skills/subagent-dispatch/SKILL.md) — 並列 dispatch・ファイル授受
