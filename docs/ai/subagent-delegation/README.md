# サブエージェント委譲プロトコル — 正本 README

> **Status**: Specification（v1）
> 親: [#710](https://github.com/s977043/plangate/issues/710) サブエージェント委譲プロトコルをPlanGate運用に組み込む
> 本ファイルが対応する子 Issue: [#711](https://github.com/s977043/plangate/issues/711)（配置 ADR）
> 併設ファイルが対応する子 Issue: [#712](https://github.com/s977043/plangate/issues/712)〜[#716](https://github.com/s977043/plangate/issues/716)（§4 索引を参照）

## 0. このファイルの位置付け

PlanGate でオーケストレータがサブエージェント（会話履歴を持たない別セッションの
Agent）へ調査・レビュー・実装を委譲する際の**標準プロトコル**の入口。本ファイルは
①配置 ADR（なぜここに置くか）、②オーケストレータ責務の定義、③本ディレクトリ内
各ファイルへの索引の 3 点を担う。**個々の契約・テンプレート本体は各ファイルの正本
に譲る**（本 README で二重定義しない）。

## 1. 目的（#710 背景 / 目的の転記）

- PlanGate の Plan → Review → Approval → Execution に、サブエージェント委譲の標準
  プロトコルを追加する
- サブエージェントが会話履歴を持たない前提で、自己完結した派遣プロンプトを生成
  できるようにする
- 捏造進捗、二重調査、スコープ逸脱、要判断事項の見落としを防ぐ
- 実行ログ側で `OUTCOME` を安定判定できるようにする

対象の考え方は、メインセッションをオーケストレータに限定し、重い調査・レビュー・
実装は適切なモデルのサブエージェントへ委譲する運用である（Fable 的な振る舞い＝
結論先行・即行動・進捗の実証・スコープ規律・要判断事項の明示、を標準作法として
組み込む）。

## 2. 配置 ADR（#711 決定の転記）

### 2.1 決定

正本を **`docs/ai/subagent-delegation/`**（本ディレクトリ）に置く。子 Issue 1 件 =
1 ファイルの粒度で構成する。

### 2.2 採用理由

1. `docs/ai/` は [`project-rules.md`](../project-rules.md) B 節・G 節で「共通ルール・
   役割分担の正本置き場」と明記された確立済みの場所で、既に `adapters/` /
   `contracts/` というトピック別サブディレクトリ grouping の先例がある
   （`subagent-delegation/` を 1 トピック = 複数ファイルでまとめる体裁に前例あり）。
2. `docs/` 配下は [`ho-change-workflow.md`](../ho-change-workflow.md) で「原則 HO
   対象外」と明記され、AI が直接作成・iterate 可能。EPIC 全体（#712〜#716 の複数
   ファイル）を apply-script 経由にせず直接編集できる（`.claude/rules/*.md` 案では
   全ファイル追加が毎回 dry-run apply になり iteration コストが激増する）。
3. 委譲プロトコルは現段階で Hook 強制力を持たない「仕様・テンプレート・規範・
   契約」であり、`.claude/rules/`（＝強制対象 Gate の正本層。例: orchestrator-mode）
   や `.claude/skills/`（＝実行手順の呼出単位）ではなく `docs/ai/` の正本層が最も
   適合する。
4. 横展開（Codex / Gemini / Hermes / River Review）は「正本 1 つ + 各ツールが参照」
   の `docs/ai/` 方式が最も容易で、[`model-profiles.md`](../model-profiles.md)
   （モデル振り分けの既存正本）とも隣接して接続しやすい。
5. 導線は [`project-rules.md`](../project-rules.md) §G（非 HO・Claude / Codex 両
   entry point が継承する参照先 SSOT）に 1 行追加すれば両ツールから辿れ、
   `README.md` 主要ドキュメント表（非 HO）にも追記可能で reachability を満たす。

### 2.3 比較した配置候補

| 候補                                      | 内容                                                                                                                                                                                                                                                  | 採否                                                                                     |
| ----------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| **A. `docs/ai/subagent-delegation/`**     | 非 HO・既存サブディレクトリ grouping 先例あり・`project-rules.md` §G / README / model-profiles と接続容易・EPIC 全体を直接 iterate 可                                                                                                                 | **採用**                                                                                 |
| B. `.claude/skills/subagent-delegation/`  | 非 HO だが既存 `subagent-driven-development` / `subagent-dispatch` / `codex-multi-agent` と同層で密集し混乱を招く。`.agents/` / `.codex/` / `plugin/` へのミラー同期負担も発生。正本（OUTCOME 契約 / 行動規範）を手順層に置くのは正本責務境界と不整合 | 不採用（将来「派遣プロンプト生成の薄い実行入口 skill」を additive に追加する余地はあり） |
| C. `.claude/rules/subagent-delegation.md` | `.claude/rules/*.md` は HO パスで全ファイル追加が毎回 apply-script（dry-run）経由になり EPIC の iteration が事実上不能。現段階で Hook 強制力もない。既存 6 ルールに詳細仕様（8 要素 / サンプル / OUTCOME 契約）を入れると肥大化する                   | 不採用（参照導線 1 行のみ HO として張るのは妥当。正本本体は置かない）                    |

### 2.4 既存構成との衝突確認

同名・同一責務の直接衝突は **無し**（`docs/ai/subagent-delegation/` は新規、既存に
該当ファイルなし）。ただし整合（棲み分け明記）が必要な隣接資産が 4 つある。§2.5
で扱う。なお `docs/ai/subagent-delegation/` は
[`check-plan-hash.sh`](../../../scripts/hooks/check-plan-hash.sh) の 9 カテゴリ HO
パターンに非該当（`docs/` 配下）で承認境界にも抵触せず、mode 引き上げ対象外。

### 2.5 既存資産との棲み分け（demarcation）

3 層の役割を切り分ける。既存 Gate・手法・分配層は**変更・置換せず、拡張として
接続**する（#710 方針 / #711 注意点「既存フローを置き換えるのではなく、まず拡張
として扱う」と一致）。

| 資産                                                                                                                                            | 役割                                                                                                                                                                                                                                                                                                              |
| ----------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`docs/orchestrator-mode.md`](../../orchestrator-mode.md) + [`.claude/rules/orchestrator-mode.md`](../../../.claude/rules/orchestrator-mode.md) | 親子 PBI の **Gate 不変条件・状態遷移・AI 自己完結禁止**（AS-1〜5 / `ChildExecAllowed` / `ParentDone`）。「何を承認しないと次 phase に進めないか」の構造・承認境界                                                                                                                                                |
| `.claude/skills/subagent-driven-development`                                                                                                    | 実装タスクを Implementer → Spec Reviewer → Quality Reviewer の**2 段階レビューで回す開発手法**。「どう実装品質を担保するか」                                                                                                                                                                                      |
| `plugin/plangate/skills/subagent-dispatch`（+ `.codex/skills/subagent-dispatch`）                                                               | high / critical でのロール別依存グラフ生成・並列 dispatch・`dispatch/` ファイルベース受け渡し（TASK-0137 / #581 由来）。「どうタスクを分配・並列化するか」                                                                                                                                                        |
| **本プロトコル（`subagent-delegation/`）**                                                                                                      | 会話履歴を持たないサブエージェントに渡す**「1 回の派遣プロンプトの自己完結性（必須 8 要素）」**と**「返ってくる報告の契約（OUTCOME / P0-P1-P2 / 検証状態 / `review=true`）」**と**「行動規範（軽量版 / フル版）」**に特化した**委譲の契約・規範層**。既存が委譲の「構造・手法・分配層」なのに対し、直交・補完する |

**承認境界は本プロトコルで一切変更しない**。C-3 / C-4 ゲート、親子 PBI Gate は
すべて既存の正本（`.claude/rules/orchestrator-mode.md` 等）に従う。本プロトコルが
定義するのはあくまで「派遣プロンプトの中身」と「報告の受け取り方」であり、
承認が誰の手に渡るか（Human-owned / AI-owned）を変える権限は持たない。

さらに以下 2 点は既存正本を参照し、重複定義しない:

- モデル振り分け（「なぜこのモデルに格上げするか」の判断表）は
  [`model-profiles.md`](../model-profiles.md) / [`model-profiles.yaml`](../model-profiles.yaml)
  を正本とする。**モデル序列は公式の固定序列として扱わず、PlanGate 内の
  モデル振り分け表として定義する**（#710 注意点）。本プロトコル側で独自の
  モデル序列を新設しない。
- 「いつ委譲するか / どう分割するか / 並列化するか」の判断基準は
  `.claude/skills/codex-multi-agent` を参照する（[`plangate-flow-integration.md`](./plangate-flow-integration.md)
  から接続）。

### 2.6 HO wiring 対象（本プロトコルからの参照導線・非直接編集）

以下は Hardening Override（HO）対象パスであり、本プロトコルの正本ファイル自体は
これらを**直接編集しない**。参照導線の追加は
`scripts/apply-subagent-delegation-wiring.sh`（非 HO・dry-run 適用スクリプト）に
隔離し、[`ho-change-workflow.md`](../ho-change-workflow.md) の標準フロー
（仕様 docs + apply script を同一 PR に置き、HO 実ファイルは含めない → Human が
`--dry-run` 確認後に適用）に従う。

| 参照導線                 | 対象 HO ファイル                             | 内容                                                                                                                                                                               |
| ------------------------ | -------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ★非 HO・最優先           | [`project-rules.md`](../project-rules.md) §G | 委譲プロトコル正本への参照を 1 行追加（直接編集可、apply-script 不要）。CLAUDE.md / AGENTS.md はこの表を継承するため主導線になる                                                   |
| HO・apply-script 必須    | `.claude/rules/orchestrator-mode.md`         | 「既存ルールとの関係」表に demarcation 行を追加（親子 PBI Gate = 本ルール正本 / サブエージェント派遣プロンプト契約層 = `docs/ai/subagent-delegation/` と矛盾させない棲み分け明記） |
| HO・apply-script 推奨    | `.claude/rules/responsibility-classes.md`    | 「既存ルール対応」表に、オーケストレータの受け入れ確認・派遣プロンプト作成 = AI-owned／P0 要判断承認 = Human-owned の責務帰属行を追加                                              |
| HO・apply-script（任意） | `CLAUDE.md`                                  | 「Claude Code 固有参照」節に正本 1 行（discoverability 補強目的。`project-rules.md` §G 継承で足りるため省略可）                                                                    |
| HO・apply-script（任意） | `AGENTS.md`                                  | CLAUDE.md と対の 1 行（Codex parity。省略可）                                                                                                                                      |

非 HO の追加導線として `README.md` 主要ドキュメント一覧表・
[`docs/orchestrator-mode.md`](../../orchestrator-mode.md) の棲み分け節にも直接追記
できる（HO 9 カテゴリ非該当のため apply-script 不要）。

## 3. オーケストレータ責務（#710 方針 1 の転記）

オーケストレータは**実作業をなぞらない**。責務は以下に限定する。

- 派遣プロンプトの作成（→ [`dispatch-template.md`](./dispatch-template.md)）
- Agent 起動
- 完了結果の受領
- 最低限の受け入れ確認（下記チェックリスト）
- 要判断事項の P0 / P1 / P2 順のユーザー確認（→ [`outcome-contract.md`](./outcome-contract.md)）
- 同一サブエージェントへの `SendMessage` 追指示

ただし、**ユーザーへ返す前に**以下だけ確認する（丸呑み禁止 / #710 注意点）。

1. 要求された成果物があるか
2. 制約違反がないか
3. `OUTCOME` が最終行にあるか
4. 要判断事項が P0 / P1 / P2 で分類されているか
5. テスト・検証結果が「実行済み / 未実行 / 失敗 / 未検証」で明示されているか

このチェックリストの詳細判定基準（各項目の PASS / FAIL 例）は
[`outcome-contract.md`](./outcome-contract.md) §6 に定義する。

破壊的操作・データ削除・外部投稿・稼働プロセス停止は**禁止または明示的な承認制**
とする（#710 注意点）。委譲判断基準（Agent 単発 vs Workflow 化）は
[`plangate-flow-integration.md`](./plangate-flow-integration.md) を参照。

## 4. 本ディレクトリの構成（索引）

| ファイル                                                         | 対応子 Issue                                           | 内容                                                                          |
| ---------------------------------------------------------------- | ------------------------------------------------------ | ----------------------------------------------------------------------------- |
| **README.md**（本ファイル）                                      | [#711](https://github.com/s977043/plangate/issues/711) | 配置 ADR / オーケストレータ責務 / 索引                                        |
| [`outcome-contract.md`](./outcome-contract.md)                   | [#712](https://github.com/s977043/plangate/issues/712) | サブエージェント成果物契約（`OUTCOME` / P0-P1-P2 / 検証状態 / `review=true`） |
| [`dispatch-template.md`](./dispatch-template.md)   | [#713](https://github.com/s977043/plangate/issues/713) | 派遣プロンプト必須 8 要素テンプレート                                         |
| [`behavior-norms.md`](./behavior-norms.md)                         | [#714](https://github.com/s977043/plangate/issues/714) | サブエージェント行動規範（軽量版 / フル版）                                   |
| [`plangate-flow-integration.md`](./plangate-flow-integration.md) | [#715](https://github.com/s977043/plangate/issues/715) | Plan → Review → Approval → Execution への委譲プロトコル接続                   |
| [`examples.md`](./examples.md)                                   | [#716](https://github.com/s977043/plangate/issues/716) | サンプル派遣プロンプト・OUTCOME 出力例・検証手順                              |

> 各子 Issue は独立した並行タスクとして作業される想定のため、上記リンク先が
> 一時的に未作成の場合がある。最終的に全ファイルが揃った時点で本索引が完成する。

## 5. 非ゴール（既存運用との不変確認 / #710 受け入れ条件「既存 PlanGate 運用と矛盾しない」）

- C-3 / C-4 ゲート、親子 PBI の承認境界（AS-1〜5）を変更・緩和しない
- `.claude/rules/orchestrator-mode.md` の Gate 不変条件を上書きしない
- モデル振り分けの独自序列を新設しない（[`model-profiles.md`](../model-profiles.md) に委譲）
- HO パス（[`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md) 参照）への直接編集を行わない（apply-script 経由・Human 適用）

## 6. 参照

- 親 Issue: [#710](https://github.com/s977043/plangate/issues/710)
- [`docs/orchestrator-mode.md`](../../orchestrator-mode.md) / [`.claude/rules/orchestrator-mode.md`](../../../.claude/rules/orchestrator-mode.md)
- [`.claude/rules/responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md)
- [`.claude/rules/hybrid-architecture.md`](../../../.claude/rules/hybrid-architecture.md)
- [`.claude/skills/subagent-driven-development`](../../../.claude/skills/subagent-driven-development/SKILL.md)
- `plugin/plangate/skills/subagent-dispatch`（+ `.codex/skills/subagent-dispatch`）
- `.claude/skills/codex-multi-agent`
- [`docs/ai/model-profiles.md`](../model-profiles.md) / [`docs/ai/model-profiles.yaml`](../model-profiles.yaml)
- [`docs/ai/ho-change-workflow.md`](../ho-change-workflow.md)
- [`docs/ai/project-rules.md`](../project-rules.md) §G
