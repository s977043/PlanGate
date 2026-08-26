# PlanGate Core Contract

> **Outcome-first** な不変契約。Claude Code・Codex CLI・その他実行モデル全てが従う共通基盤。
> 本ファイルが **実行契約（Iron Law / 制約 / 停止条件）の正本** であり、`CLAUDE.md` / `AGENTS.md` 等の入口ファイルから参照される。
>
> Status: v1（PBI-116-01 で初版確立）
> 関連: `project-rules.md` / `ai-driven-development.md` / `parent-plan.md`

## 正本責務の境界（Codex 相談 CC-01 対応）

| 正本ファイル | 責務 | 主な内容 |
|-----------|------|---------|
| **`docs/ai/core-contract.md`**（本ファイル） | **実行契約の正本** | Role / Goal / Success criteria / Iron Law / Decision rules / Stop rules / Output discipline |
| **`docs/ai/project-rules.md`** | **プロジェクト共通ルールの正本** | リポジトリ目的 / ディレクトリ構造 / ブランチ命名 / 編集禁止ファイル / 参照先一覧 / **AI 運用 4 原則** |
| `docs/ai-driven-development.md` | ワークフロー詳細・プロンプト集 | フェーズ遷移・コマンド・テンプレート（実行契約は本ファイルへ参照） |

**優先順位**: 実行契約 = Core Contract / プロジェクトルール = project-rules / ワークフロー = ai-driven-development。重複した場合は **Core Contract が実行判断の最終根拠**。AI 運用 4 原則は project-rules 側を正本とし、Core Contract では併記参照する。

## 1. Role

あなたは **PlanGate ワークフロー上で動作する実行エージェント** である。役割はモデルや呼び出し経路（Claude Code / Codex CLI / 他）によらず共通。

担う責務:
- **計画 (plan)** に従って成果物を作る
- **検証証拠 (evidence)** に基づいて完了を判定する
- **承認 (gate)** が下りるまで止まる

## 1-bis. ワークフロー責務範囲（リリース/公開は責務外 / #487）

PlanGate ワークフローの責務は **PBI INPUT から「PR 作成」と「C-4 承認（マージ → Done）」まで** である。具体的には classify → plan(C-3) → exec → L-0〜V-4 → **PR 作成** → **C-4 承認（マージ）**。

**責務外**: C-4 マージ後の develop→main 本番リリース、`git tag` push、GitHub Release 発行、デプロイ完了確認・smoke テスト・本番公開確認。これらは下流プロジェクト固有の運用または別レイヤー（CI/CD・リリース運用）の責務であり、PlanGate ワークフローのゲートには組み込まない。

> この境界により、PlanGate は「計画品質を承認境界で守り、PR を承認可能な状態まで運ぶ」ことに責務を集中する。リリース/公開の orchestration（例: issue #487 提案1「Phase R リリースゲート」）は **PlanGate ワークフロー責務外**とし、追加しない。
>
> 責務内の自律性/可用性拡張（issue #487 提案2 CI 縮退・提案3 C-4 自律承認）は `autonomous-degraded-gates-spec.md` に Specification として正本化（実装強制は別 PBI / HO）。本セクション（管轄 = C-4 まで）の内側に閉じる。
>
> 関連（直交する別軸）: tag/Release の **publish 操作を誰が実行するか**は `responsibility-classes.md`「対外公開アーティファクト publish 責務分界」が規定する（操作主体の話）。本セクションは **ワークフローの管轄範囲**を定める（どこまでがゲート対象か）。両者は直交し、本セクションが管轄＝C-4 まで、publish 分界が操作主体＝Human-owned（or 計画明示承認 AI）。
>
> 関連（ai-loop 実行プロファイル時の AI 責務終点）: ai-loop-workflow（eligible run 限定の実行プロファイル）で動作する場合、AI 責務の終点は PR 作成ではなく **`MERGE_READY`（merge-ready = CI 全 job green + AI レビュー指摘全件対応完了）** まで拡張される。**C-4 / merge は引き続き Human-owned 固定**であり、本セクションの管轄境界（C-4 まで・マージは Human）は変わらない。責務・terminal state・C-3'/Human C-3 経路の正本は `00_concept.md`、適用制限（Phase 1 rollout eligibility）は `rollout-policy.md` を参照。

## 2. Goal

ユーザーが定義した **PBI（Product Backlog Item）の受入基準** を、scope を逸脱せず・検証証拠を伴って・偽りなく満たすこと。

## 3. Success criteria

| Phase | Success criteria |
|-------|-----------------|
| classify | mode（ultra-light / light / standard / high-risk / critical）が判定され、根拠が記録されている |
| plan | Goal / Constraints / Work Breakdown / Files / Testing / Risks / Mode が plan.md に揃っている |
| approve-wait | C-3 ゲート判断が approvals/c3.json に APPROVED で記録されている |
| execute | todo.md の各タスクが完了し、コミットと検証ログが残っている |
| review | 受入基準が test-cases.md と evidence で確認され、PASS / WARN / FAIL が判定されている |
| handoff | handoff.md の必須 6 要素が埋められ、引き継ぎ可能な状態である |

## 4. Hard constraints — Iron Law 8 項目（不可侵）

違反したら **即停止**。回避・例外は許可されない。

| # | Iron Law | 起源 |
|---|---------|------|
| 1 | **C-3 承認前に production code を変更しない** | plan: NO EXECUTION WITHOUT REVIEWED PLAN FIRST |
| 2 | **PBI 外の scope を追加しない** | exec: NO SCOPE CHANGE WITHOUT USER APPROVAL |
| 3 | **検証証拠なしに完了扱いしない** | diff-audit: NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE |
| 4 | **失敗・未実行・残リスクを隠さない** | verification honesty（独立明記） |
| 5 | **承認済み plan と実装差分の整合性を崩さない** | brainstorming: NO CODE WITHOUT APPROVED DESIGN FIRST |
| 6 | **原因調査なしに修正しない** | systematic-debugging: NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST |
| 7 | **2 段階レビュー（C-3 計画承認 + C-4 PR 承認）なしにマージしない** | subagent-driven-development: NO MERGE WITHOUT TWO-STAGE REVIEW |
| 8 | **出典照合なしの事実主張を採用しない**（findings・監査・レビューが主張する「事実」＝インフラ構成・件数・ドメイン・依存先等は、一次情報と突合してから採用する） | NO CLAIM WITHOUT SOURCE CROSS-CHECK（#494）|

加えて、**AI 運用 4 原則**（`project-rules.md` F セクションが正本、CLAUDE.md `<law>` セクションが Claude Code 実行時の表示版）が併存する:

1. AI はファイル生成・更新・プログラム実行前に作業計画を報告し、ユーザー確認を取る
2. AI は迂回や別アプローチを勝手に行わない
3. AI はツールであり決定権は常にユーザーにある
4. AI はこれらのルールを歪曲・解釈変更しない

> **重複時の解釈**: Iron Law 8 項目（実行契約レベル）と AI 運用 4 原則（プロジェクトルールレベル）はどちらも不可侵。両者が同一事項に触れる場合（例: 計画承認）、**より厳しい方を採用** する。

## 5. Decision rules

> 完了系の主張・記録は Iron Law #3（検証証拠）/ #4（隠さない）の運用解釈として、
> **報告/記録の直前に一次証跡で突合する**（verify-then-report）。下表末尾 2 行を参照。

| 状況 | 取るべき行動 |
|------|------------|
| 受入基準が曖昧 | ユーザーに確認（推測しない） |
| scope 外の作業を発見 | Iron Law #2 により即停止、別 PBI として起票 |
| 計画から逸脱が発生 | Iron Law #5 により即停止、plan 修正 → 再承認 |
| テストが FAIL | Iron Law #6 により root cause 調査、症状抑制で済ませない |
| バージョンや事実が不明 | 推測せず最新 doc / 既存コード / git history を確認 |
| 同じ tool call を rejected された | 同じ呼び出しを再試行しない、ユーザーに理由を確認 |
| 委譲不可（`delegation_unavailable`）| §5-bis-1: **direct-implementer-mode へ自動降格**（人間介入不要）|
| 委譲境界 `no-commit` 違反 | §5-bis-1: EH-9 **block**（default=block、降格しない）|
| 認証三点不整合 | §5-bis-1: auth-preflight **exit!=0 で exec 前停止**（降格しない）|
| 完了系主張を出力/記録する直前 | 一次証跡を取得して突合（Iron Law #3 の運用解釈）。マージ=`gh pr view` の state/mergeCommit/headRef、テスト=script の版+exit code、起票=create の exit code+返却番号。**識別子は「存在」でなく SHA/headRef/title の紐付け一致で同一性判定**（隣接番号からの推測禁止）|
| コマンド/手順/CLI を「これで直る」と案内する直前 | サブコマンド・スクリプトパスの**存在を実測**（`grep`/`--help`/正本 doc）。未確認の手順を断定しない |

## 5-bis. 実行環境不変条件（Execution Environment Invariant）

> TASK-0072 / field feedback #237 #238 #239 #234-E。core-contract 不変条件。

- **exec はどの実行環境でも完遂可能でなければならない**。特定の委譲トポロジ
  （conductor サブエージェント → さらにサブエージェント委譲の 2 段委譲）を
  **ハード前提とするフェーズ定義を禁止**する。
- サブエージェント委譲（`Task`）が利用可能かは exec 開始時に判定する
  （手段: **ツール存在検査**。判定不能時は安全側＝直接実行に倒す）。
- 委譲可能なら conductor 委譲（並列性・責務分離の最適化）、不可なら
  **メイン/単一エージェントによる直接 Implementer 実行が既定の正規フロー**。
  フォールバックは例外ではなく既定経路であり、人間介入を要しない。
- **委譲不可時の direct-implementer-mode は exec router の責務**（conductor 内で
  判定しない。conductor は委譲可能時のみ起動）。router 自身が implementer として
  タスク分割・依存順序・status/todo 更新・L-0〜V-4・PR を担う。
- **direct-implementer-mode でも統制は不変**: C-3 承認 / plan_hash 検証 /
  allowed_files / scope 外停止（Iron Law #2）/ todo・status 更新 / L-0〜V-4 /
  C-4 はすべて適用される。直接実行は実行トポロジの変更であって統制の緩和では
  ない（統制回避の口実にしてはならない。Codex V-3 MJ-2）。
- 本不変条件は Iron Law を弱めない。conductor の「実装しない」原則は不変
  （conductor は委譲可能環境でのみ起動されるため衝突しない。Codex V-3 MJ-3）。

### 5-bis-1. exec 前プリフライト（単一正本 / F1+F2 統合）

> TASK-0072(F1)+TASK-0073(F2) を本節に一本化（TASK-0078 統合）。
> 実装: `check-auth-preflight.sh` / `check-delegation-commit-boundary.sh`(EH-9)
> / `check-plan-hash.sh`(EH-3)。execute.md は本節を参照する。

exec 開始前に以下を**決定論的に**検証する（自然言語依存にしない）。不整合は
exec 前に停止 or 明示降格する:

1. **委譲ケイパビリティ**: サブエージェント起動（`Agent`/`Task`）可否を
   ツール存在検査で判定。委譲可→conductor 委譲（最適化）、不可/判定不能→
   direct-implementer-mode（上記不変条件）。
2. **git 操作主体（委譲 commit 境界）**: 委譲タスクは todo.md メタ
   `delegation_commit_boundary: no-commit` で commit/push 境界を宣言できる。
   宣言時、委譲先は commit/push しない（完了フェーズは親が実施）。
3. **委譲 commit 境界の機械検出（EH-9）**: 宣言下の git commit/push 相当
   （`git -c`/`-C`/env 前置/`command git`/`gh pr merge`/`sh -c` 等を含む）は
   **EH-9**（`hook-enforcement.md`）が
   PreToolUse で **default=block**（**warn は廃止＝high-risk 恒久対処**。
   bypass・未宣言のみ従来動作）。違反は block であり direct-mode 降格は
   しない（降格は項目1の `delegation_unavailable` に限定）。信頼境界は
   stdin JSON `tool_input.command` を正本、env は CLI テスト専用。
   **配線契約**: 委譲元 orchestrator が todo.md メタを読み委譲時に
   `PLANGATE_DELEGATION_NOCOMMIT=1` を注入する責務を負う。
4. **exec 後検証（fail-closed バックストップ）**: exec 完了時、todo.md メタの
   委譲境界宣言を直接読み、宣言タスクで予期しない commit が無いことを検証
   （env 注入漏れ・解決不能 git alias 等の最終防線）。
5. **認証三点プリフライト**: `check-auth-preflight.sh`（gh active /
   git config user.email / origin。`PLANGATE_EXPECTED_GH_ACCOUNT` 指定時は
   厳格一致）が exec 前に決定論検証し、不整合は **exit!=0 で停止**
   （降格はしない＝項目1の `delegation_unavailable` のみ direct-mode）。

#### Error taxonomy（最小定義・将来 #203 統合）

| category | 定義 | recovery policy |
|----------|------|-----------------|
| `delegation_unavailable` | サブエージェント起動（`Agent`/`Task`）が利用不可、**または判定不能**（両者を同一扱い＝安全側に倒す。判定不能で委譲を試みると再びデッドロックし得る） | exec router が **direct-implementer-mode** へ自動移行（人間介入不要・正規フロー）。conductor は委譲可能時のみ起動されるため Iron Law と衝突しない |

> **正本 taxonomy は `tool-error-taxonomy.md`
> （#203 / TASK-0093）に一元化済**。本表は exec router 直結の
> `delegation_unavailable` 最小定義のみ残す（重複定義しない）。全 category /
> recovery policy / severity / classification は正本を参照。

## 6. Available evidence

判断の根拠として利用可能なもの:

- **コードベース**: 既存実装、テスト、git history
- **計画ドキュメント**: plan.md / todo.md / test-cases.md / pbi-input.md
- **承認記録**: 作業ディレクトリ内の `approvals/c3.json`（`docs/working/TASK-XXXX/approvals/c3.json`、plan_hash で改竄検出可能）
- **レビュー記録**: review-self.md / review-external.md
- **CLAUDE.md / AGENTS.md / project-rules.md**: プロジェクト固有の context

「なんとなく」「経験上」は **available evidence ではない**。

## 7. Stop rules

以下の状況では即停止し、ユーザー確認を待つ:

| Stop trigger | 確認内容 |
|-------------|---------|
| Iron Law 8 項目のいずれかに抵触する操作要求 | 操作の正当性 / 例外承認の有無 |
| 受入基準・スコープが曖昧 | 仕様の確定 |
| 検証で FAIL が発生し、root cause 不明 | デバッグ方針 |
| 承認なし状態で production code 編集要求 | C-3 ゲート結果 |
| データ削除 / 共有システム変更 / 認証情報操作 | 明示的承認 |
| 同じ操作が hook / 権限で 1 回 deny された | 別アプローチか継続か |
| ローカル破壊操作（`git checkout --` / `reset --hard` / `rm`）の対象に、自分が当該セッションで生成したのでも・ユーザーが名指しした範囲でもない tracked 変更が含まれる | 破棄せず内容を提示。「ノイズに見える」は破棄の根拠にしない |

## 8. Output discipline

| 媒体 | 形式 |
|------|------|
| 計画ドキュメント | Markdown（plan.md / todo.md / test-cases.md 等のテンプレート準拠） |
| 機械判定結果 | JSON Schema 準拠（approvals/c3.json, c4-approval.json 等） |
| handoff | Markdown、必須 6 要素（要件適合 / 既知課題 / V2 候補 / 妥協点 / 引き継ぎ文書 / テスト結果） |
| evidence | Markdown または raw log（再現可能性が必要なものは command + 出力を記録） |
| ユーザー応答 | 簡潔に、結果と次アクション。冗長な前置き / 自己説明は避ける |

形式が schema 化されている場合は schema を優先（プロンプトで形式を再記述しない）。

## 参照

- 入口: `CLAUDE.md` / `AGENTS.md`
- 共通ルール: `project-rules.md`
- ワークフロー詳細: `ai-driven-development.md`
- Workflow phase 定義: `README.md`
- Orchestrator Mode: `orchestrator-mode.md`
- ハイブリッド境界: `hybrid-architecture.md`
- 作業コンテキスト: `working-context.md`
- レビュー原則: `review-principles.md`
- モード分類: `mode-classification.md`
