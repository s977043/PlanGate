# agentic-six-stage-loop — 6段階ループ対応表 + Trust Ledger 索引

> 適用ドメイン（Phase 1）: ①plangate 本体 = docs/workflows/ai-loop/ 配下のみ（dogfooding 域・本番フロー WF-00〜07 非適用）
> ②導入先リポジトリ = ho-paths 確定 + LoopSpec scope.allowed_paths 宣言を前提に適用可
> 対応 issue: [#780](https://github.com/s977043/plangate/issues/780)（ai-loop 6段階ループ適合性）
> 位置づけ: 汎用的なエージェント実行パイプラインの役割語彙
> （Triage / Conductor / Worker / Verifier / Gate / Trust Ledger）と、
> 現行 ai-loop の機能責務語彙（`Generate → Evaluate → Remember → Schedule → Optimize → Recurse`。
> 正本: [`adaptive-production-loop.md`](./adaptive-production-loop.md) §3）
> との**対応関係の正本**。新規機構を追加するものではなく、既存資産の
> 索引・命名対応を集約する。

---

## 1. 目的

\#780 は、外部で語られる 6 段階のエージェント実行パイプライン
（Triage → Conductor → Worker → Verifier → Gate → Trust Ledger、役割責務の語彙）
と、ai-loop-workflow が既に持つ機構・語彙（機能責務の語彙）との対応を問うた。

本書はその応答として、以下を 1 枚に集約する:

1. **6段階対応表**（§2）: 6 段階それぞれに対し、現行 ai-loop の対応資産
   （ファイル:節）・充足度・gap を明示する
2. **Trust Ledger 索引**（§3）: 「記録・学習」を担う既存 4 資産
   （decision record / provenance / 摩擦台帳 / review-feedback）が
   Trust Ledger 概念とどう対応するかを整理する索引正本
3. **6層×6段階の写像表**（§4）: 機能責務（6層）と役割責務（6段階）が
   直交する軸であることを 1 表で示す
4. **設計判断**（§5）: #780 の未決事項に対するオーガナイザー裁定

**本書が新設しない機構**: Triage の discovery 層、Conductor の着手前分解、
計画品質ゲートの hard gate 化、size_ok の機械算出は本書のスコープ外
（§5 で明記。それぞれ slice B/C や別 issue の Human 判断事項）。

---

## 2. 6段階対応表

現行 ai-loop は `Generate → Evaluate → Remember → Schedule → Optimize → Recurse`
（機能責務・[`adaptive-production-loop.md`](./adaptive-production-loop.md) §3）
を正本に持つ。今回の 6 段階（エージェント実行パイプラインの役割責務）との対応:

| 段階 | 現行 ai-loop の対応資産（ファイル:節 / 機構名） | 充足 | gap |
| --- | --- | :-: | --- |
| **Triage**（task 発見/受付/risk 分類） | `LoopSpec.trigger.type`（manual/issue_created/pr_opened/scheduled・[`loopspec.md`](./loopspec.md) §2）／[`loop-safety-gates.md`](./loop-safety-gates.md)（非停止プロンプト事前拒否・[`flow-detect.md`](./flow-detect.md) §2 事前ゲート）／boundary・lite・class 判定（[`flow-detect.md`](./flow-detect.md) §2）／[`lite-criteria.md`](./lite-criteria.md)／intent-classifier 共通 skill 参照（[`00_concept.md`](./00_concept.md) §6） | △ | **「タスク自体を発見・選別する層」が無い**。現状は「人が持ち込んだ 1 変更」を受ける intake のみ。issue/PR キューを走査して着手対象を選ぶ discovery が未定義（issue の判定と一致） |
| **Conductor**（分解/役割割当/進行制御） | Scheduling 判断表（[`execution-runbook.md`](./execution-runbook.md) §2-(7) / [`adaptive-production-loop.md`](./adaptive-production-loop.md) §5）／round 上限 3（[`execution-runbook.md`](./execution-runbook.md) §2-(7) が正本値）・escalate 予算（`arbiter-policy.md` §7）／retry/stop/block 選択／breakdown-gate スキルを Step 0 として接続し `gates.breakdown == "pass"`（split-suggested 等は escalate）を priority 1.7 の一部に組込み（[`decision-table.md`](./decision-table.md) §「priority 0/1.5/1.7/1.9」・#817） | △ | **着手前の粒度判定（intake）は breakdown-gate 接続で部分解消**（#817）。ただし**タスク分解（step 化）と役割割当そのものは依然未定義**。ai-loop は分解実体を PlanGate WF 側に委ねる設計（[`00_concept.md`](./00_concept.md) §2「工程の実体は共通利用」）のままで、conductor 責務は「PR 後 Scheduling + 着手前 breakdown gate 判定」に留まり、step 化・役割割当は空白のまま |
| **Worker**（生成/実装/PR 準備） | `LoopSpec.actors.maker`（[`loopspec.md`](./loopspec.md) §2）／exec（[`execution-runbook.md`](./execution-runbook.md) §2-(5) exit code 分岐後の実装〜(5b) grader）／ai-loop-cycle SKILL の maker 委託／PR 作成 | △ | **worker として独立の role 定義が無い**。maker は「checker と異なる主体」制約（I-2）で識別されるだけで、責務記述が薄い |
| **Verifier**（C-1/C-2/W/CI/grader） | C-1・C-2 共通踏襲（[`00_concept.md`](./00_concept.md) §3.2）／W チェック Model A/B/C/D（[`flow-detect.md`](./flow-detect.md) §3 / `arbiter-policy.md` §4）＝C-3'（[`00_concept.md`](./00_concept.md) §3「C-3'（置換点）: AI裁定ゲート = Arbiter」）／rubric grader Step 5.5（`.claude/skills/ai-loop-cycle/SKILL.md` Step 5.5）／CI・AI レビュー第2段 detect（[`00_concept.md`](./00_concept.md) §3.3）／plan 品質ゲート priority 1.7（`gates.c1 == "PASS"` を auto-approve の必要条件化・[`decision-table.md`](./decision-table.md) §「priority 0/1.5/1.7/1.9」・#817） | ○ | **C-1 相当の loop 内義務化は解消済み（#817）**: `gates.c1 == "PASS"` かつ `gates.breakdown == "pass"`（両方厳密一致）を満たさない場合は priority 1.7 で human escalate に倒れるため、C-1 は「loop の前提」から「auto-approve 経路の hard gate」へ格上げされた。ただし **C-2 の loop 内義務化は未対応**、**code-run 用 rubric variant（#782 P2）も未対応**のまま残る |
| **Gate**（判定/terminal state） | `arbiter.py` 3 値（AUTO_APPROVED/HUMAN_ESCALATED/BLOCKED・exit 0/2/3）／`MERGE_READY`（DoD 状態・[`00_concept.md`](./00_concept.md) §3.3）／C-4 wait（Human-owned 固定）／CB-1/2/3（[`decision-table.md`](./decision-table.md) §6）／fail-closed（ho-paths 未解決時の全件 escalate）+ allowed_paths 判定 + パス正規化を機械層に配線（[`decision-table.md`](./decision-table.md) §「priority 0/1.5/1.7/1.9」・#813） | ○ | ほぼ充足。terminal state と DoD 状態の区別は `design-philosophy.md` §5 語彙集で明示済み。**fail-closed 配線（#813）で priority 0 の安全側判定が機械層に落ち、充足度の裏付けがさらに強化**された。命名 alias を本表に載せるだけ |
| **Trust Ledger**（記録/学習） | decision record JSON（provenance・[`decision-table.md`](./decision-table.md) §5）／摩擦台帳 `run-001-frictions.md`（F-1〜F-41）／[`review-feedback-loop.md`](./review-feedback-loop.md)（R-NNN 還元・suppression S-1/S-2）／CB-1 事後 reject／decision record 集計 `metrics.py`（#812）／arbiter が record に run メタ（run_id/round_index/task_id/repair_action）を刻印（#815）／`gates`（c1/breakdown）を provenance に刻み plan-quality escalate を監査可能化（#819）／`size_ok` を changed_files 実数で機械検証（#820） | △ | **メトリクス統合基盤は前進（#812/#815/#819/#820）**: first-pass rate 等の成功/失敗シグナルを算出する集計ロジック（metrics.py）と、その入力となる run メタ・gates・size 検証結果の provenance 刻印が揃った。ただし**単一正本への完全統合・成功/失敗メトリクスの定常運用（レポート化）は未了**のため △ を維持 |

### 2.1 用語対応（alias）

上記表で「ほぼ充足」と判定した Verifier / Gate は、既存の terminal state
語彙をそのまま role 名の alias として扱ってよい。新しい状態や判定条件を
追加するものではない。

| 6段階の役割語 | 既存語彙（正本） |
| --- | --- |
| Verifier | C-1 / C-2 / W チェック（Model A/B/C/D）/ CI / AI レビュー / rubric grader |
| Gate | `arbiter.py` 3 値（`AUTO_APPROVED` / `HUMAN_ESCALATED` / `BLOCKED`）+ `MERGE_READY`（DoD 状態） |

---

## 3. Trust Ledger 索引

### 3.1 既存 4 資産との異同表

| 資産 | 実体 | 保存単位 | 正本性 | Trust Ledger との関係 |
| --- | --- | --- | --- | --- |
| decision record JSON | `arbiter.py` stdout（`docs/working/ai-loop-runs/*.json`） | 1 裁定 | AUTO_APPROVED のみ provenance 正本、他は audit record 暫定（[`execution-runbook.md`](./execution-runbook.md) §2-(4)） | **Ledger の「裁定イベント」行** |
| provenance | decision record 内の刻印（issued_by/policy_ref/target_sha/w_check） | 同上 | issued_by 真正性は未検証（`design-philosophy.md` I-3 honest 注記） | **Ledger の「承認根拠」列** |
| 摩擦台帳（F-NNN） | `run-001-frictions.md`（散文 + 状態表） | 1 摩擦観測 | 台帳が単一権威・追記専用（[`execution-runbook.md`](./execution-runbook.md) §2-(4)） | **Ledger の「失敗/成功学習」行**（種別に「成功シグナル」含む） |
| review-feedback（R-NNN / S-NNN） | [`review-feedback-loop.md`](./review-feedback-loop.md) §2-4・§5 suppression | 1 指摘 → 還元先 | AI-owned 編集可（policy 還元のみ Human-owned） | **Ledger の「指摘→反映トレース」行** |

**結論**: Trust Ledger は上記の**上位集約概念**であり、いずれとも同義ではない。
4 資産を「裁定イベント / 承認根拠 / 学習（失敗・成功）/ 指摘反映」の 4 系列として
束ねる**索引正本**が本節である（`design-philosophy.md` §7 文書地図の「記録」層に
本書への参照を additive 1 行追加する形。§6 参照）。**既存資産を移動・改名しない**
（一括再編回避の方針＝`design-philosophy.md` §7.1 と整合）。

### 3.2 保存対象・更新条件（現状の索引）

保存対象・更新条件は既に散在して実在する。Trust Ledger 索引の仕事は、
これらの保存先・更新条件・参照方法を 1 表に集約することであり、
**新規保存機構の追加ではない**。

| 保存対象 | 正本（ファイル:節） |
| --- | --- |
| decision record | [`decision-table.md`](./decision-table.md) §5 |
| CI failure / AI review 指摘 / 採用・理由付き不採用 | [`adaptive-production-loop.md`](./adaptive-production-loop.md) §6（Remember） |
| human reject / human override | [`decision-table.md`](./decision-table.md) §6（CB-1） |
| suppression | [`review-feedback-loop.md`](./review-feedback-loop.md) §5 |
| success pattern（成功シグナル） | `run-001-frictions.md` の「成功シグナル」種別 |

### 3.3 4 系列索引（Trust Ledger の構成要素）

| 系列 | 対応資産 | 何を記録するか |
| --- | --- | --- |
| 裁定イベント | decision record JSON | いつ・何が・どの terminal state に裁定されたか |
| 承認根拠 | provenance（decision record 内） | 誰が・何を根拠に・何を承認したか（issued_by 真正性は未検証） |
| 学習（失敗・成功） | 摩擦台帳（F-NNN） | 何が失敗したか・何が上手くいったか（成功シグナル含む） |
| 指摘反映トレース | review-feedback（R-NNN / S-NNN） | 指摘がどの観点にどう還元されたか |

---

## 4. 6層×6段階の写像表

機能責務（`Generate → Evaluate → Remember → Schedule → Optimize → Recurse`。
正本: [`adaptive-production-loop.md`](./adaptive-production-loop.md) §3）と
役割責務（Triage / Conductor / Worker / Verifier / Gate / Trust Ledger）は
**直交する 2 つの軸**である。同じ機構を「何をするか（機能）」と
「誰の役割か（role）」の両方から説明できることを、1 表で示す。

| 6層（機能責務） | 対応する 6段階（役割責務） | 備考 |
| --- | --- | --- |
| Generate | Worker | plan / todo / test-cases / diff / PR の生成主体 |
| Evaluate | Verifier + Gate | C-1/C-2/W チェック/CI/AI review = Verifier、`arbiter.py` 3 値裁定 = Gate |
| Remember | Trust Ledger | decision record・provenance・摩擦台帳・review-feedback の保存 |
| Schedule | Conductor（PR 後の範囲のみ） | retry/queue/CI fix/human escalate の次アクション選択。着手前分解は範囲外（§5 判断2） |
| Optimize | Trust Ledger の反映先 | skill / gate / suppression / scheduling policy の更新（Remember の記録を根拠にする） |
| Recurse | 全段階を横断 | 1 サイクルの出力を次サイクルの Triage/Worker/Verifier 入力へ戻す |

**表の読み方の注意**: Triage は現行 6 層のどこにも独立して存在しない
（§2 の gap）。Conductor は Schedule 層の一部（PR 後）にのみ対応し、
着手前分解は PlanGate WF 側の責務（§5 判断2）であるため、この写像表でも
「Schedule（PR 後の範囲のみ）」と限定して示す。

---

## 5. 設計判断

\#780 コメント欄の設計ドラフト末尾に列挙された未決事項に対する、
オーガナイザー裁定（本 slice A の scope 確定）。

### 判断1: Triage = intake + 分類まで（discovery は non-goal）

Triage の責務は「持ち込まれた 1 変更を受け、trigger 種別・boundary・lite・
class を判定する」intake + 分類までとする。issue/PR キューを走査して
**着手対象そのものを選ぶ discovery**（#782 の指摘した gap）は、本書・
現行 ai-loop のスコープに含めない。

- **V2 候補（1 行）**: issue/PR キュー走査による着手対象の自動選別（discovery
  層）は、Conductor の着手前分解と合わせて将来検討する V2 候補とし、
  本書では実装しない。

### 判断2: Conductor の分解責務は PlanGate WF 委譲のまま

Conductor の役割は「PR 後 Scheduling 判断表（[`execution-runbook.md`](./execution-runbook.md)
§2-(7) / [`adaptive-production-loop.md`](./adaptive-production-loop.md) §5）による
次アクション選択」に限定する。**着手前のタスク分解（step 化・役割割当）は
PlanGate WF 側（WF-01〜03）に委譲したまま**とし、ai-loop 側に新設しない。

この分担は `.claude/rules/hybrid-architecture.md`
Rule 1（Workflow は順序と完了条件だけを持つ。実装ノウハウは書かない）と
衝突しない: PlanGate WF が引き続き「分解の実体」を持ち、ai-loop-workflow
（本書含む）は「分解済みの成果物をどう Evaluate/Schedule するか」だけを扱う。
[`00_concept.md`](./00_concept.md) §2「工程の実体は共通利用」の設計と整合する。

### 判断3: 6層×6段階の写像は本書 1 表で完結

6層（機能責務）×6段階（役割責務）の写像は、**本書 §4 の 1 表のみ**で完結させる。
`design-philosophy.md` §7 文書地図には、本書への参照を **additive 1 行**
追加するのみとし、写像表そのものを複製・転記しない（§6 適用箇所参照）。

### 残る未決事項（本書のスコープ外・Human 判断事項）

以下は #780 ドラフトが挙げた未決事項のうち、本 slice A（正本化）では
判断せず、後続 slice（B/C）または別途の Human 判断に委ねる:

- **計画品質ゲートの hard gate 化度合い**（#782 P1-1 対応・slice B 相当）:
  **#817 で plan 品質ゲート（priority 1.7・`gates.c1 == "PASS"` かつ
  `gates.breakdown == "pass"` を auto-approve の必要条件）として一部
  hard gate 化を実装済み**（§2 Verifier 行と整合）。C-1 相当は「loop の
  前提」から auto-approve 経路の hard gate へ格上げされた。ただし
  **C-2 の loop 内義務化・code-run 用 rubric variant（#782 P2）は未決のまま
  残る**。残りの線引き（C-2 hard gate 化の是非等）は引き続き Human 確定事項
- **size_ok のしきい値**（#782 P1-2 対応・slice C 相当）: `size_ok` を
  git 由来の機械算出 blast-radius boolean へ置換する場合の具体しきい値は
  policy（Human-owned）であり、本書では定義しない
- **record スキーマ拡張の置き場**: decision record への `run_id` /
  `round_index` / `first_pass` 等の追加を PoC 中は `decision-table.md` 内定義
  （非 HO）とするか正式 schema 化（HO）とするかは未決のまま残す
- **摩擦台帳の構造化**: 機械可読化のコストと追記専用・散文運用の監査連続性の
  トレードオフは未決のまま残す

---

## 6. design-philosophy.md §7 への追記

`design-philosophy.md` §7 文書地図の「記録」層に、本書への additive 1 行を
追加する（本書は文書地図に新しい層を作らず、既存「記録」層の一資産として登録する）。
写像表・対応表そのものは本書に一本化し、`design-philosophy.md` 側に複製しない
（判断3）。

---

## 7. 関連ドキュメント

- [`00_concept.md`](./00_concept.md) — PlanGate フローとの接続（C-3'・merge-ready 責務）
- [`adaptive-production-loop.md`](./adaptive-production-loop.md) — 6 層自己改善ループ・1 サイクル contract 正本
- [`decision-table.md`](./decision-table.md) — Decision table・provenance schema・terminal state・CB
- [`execution-runbook.md`](./execution-runbook.md) — 1 サイクルの実行手順・Scheduling 判断表
- `docs/ai/ai-loop/design-philosophy.md` §7 — 文書地図（本書はここに additive 1 行で登録）
- `.claude/rules/hybrid-architecture.md` Rule 1 — Workflow は順序と完了条件だけを持つ（判断2 の整合根拠）
- issue [#780](https://github.com/s977043/plangate/issues/780) — 本書の起点（6段階ループ適合性の設計ドラフト）
- issue [#782](https://github.com/s977043/plangate/issues/782) — 実走レポート（P1-1/P1-2 の入力元。計画品質ゲート・size_ok は本書スコープ外・slice B/C）

---

## 8. HOTL境界（EPIC #822）

> 親: [#822](https://github.com/s977043/plangate/issues/822) EPIC（HITL→HOTL変革）。
> 本節は「何が非ブロック化（HOTL化＝人間の事前承認なしで進む）し、何が
> Human固定（HITL＝人間の事前承認必須）で残るか」を、直近セッションで実装
> した機構（#813/#815/#817/#819/#820/#824/#826）を根拠に対応表として
> 明文化する。**新しい判断基準を作るものではない**: §2 の充足度・§5 の
> 判断1〜3、および `.claude/rules/responsibility-classes.md` /
> `.claude/rules/orchestrator-mode.md` の既存正本をそのまま ai-loop 文脈へ
> 索引付けするだけである（重複定義しない・正本は変更しない）。

### 8.1 非ブロック化されている部分（HOTL・事前承認なしで自動進行）

直近セッションで実装した以下は、人間の**事前**承認なしに自動で進む
（§2 Verifier/Gate の充足度「○」/「△」の裏付けとなった実装）:

| 段階 | 機構 | 実装PR |
| --- | --- | --- |
| HO境界の実行時解決 | ho-paths 実行時 parse・解決不能時は fail-closed | [#813](https://github.com/s977043/plangate/issues/813) |
| plan品質チェック | priority 1.7（gates.c1/breakdown を auto-approve 必要条件に） | [#817](https://github.com/s977043/plangate/issues/817) |
| record への run メタ刻印 | run_id/round_index 等を provenance に刻印 | [#815](https://github.com/s977043/plangate/issues/815) |
| gates 生値の provenance 刻印 | plan-quality escalate の監査可能化 | [#819](https://github.com/s977043/plangate/issues/819) |
| size機械検証 | priority 1.9（size_ok 申告と実測 changed_files の突合） | [#820](https://github.com/s977043/plangate/issues/820) |
| W check（Model A/B 独立裁定） | §2 Verifier 対応資産（既存・[`flow-detect.md`](./flow-detect.md) §3） | 既存 |
| arbiter裁定 | AUTO_APPROVED/HUMAN_ESCALATED/BLOCKED（§2 Gate 対応資産） | 既存 |
| candidate提示（discovery） | D-2 read-only 候補提示 / D-3 recommended_next 構造化 | [#824](https://github.com/s977043/plangate/issues/824) / [#826](https://github.com/s977043/plangate/issues/826) |

**条件**: 上記いずれも lite 4 軸（[`lite-criteria.md`](./lite-criteria.md)）を
満たし・HO 非接触・plan 品質ゲート通過の場合のみ `AUTO_APPROVED` に到達し
うる。1 つでも欠ければ `HUMAN_ESCALATED` / `BLOCKED`（§2 Gate alias・
[`decision-table.md`](./decision-table.md) 参照）に落ちる。

### 8.2 Human固定（HITL・事前承認が必須のまま）で残る部分

以下は本セッションの変更で**一切緩和されていない**。判定主体・強制根拠は
既存正本のまま（本節は ai-loop 文脈での索引にとどめ、正本を再定義しない）:

| 項目 | 固定理由 | 正本 |
| --- | --- | --- |
| merge | AI は merge しない（sockpuppet 禁止と一貫。Human-owned 固定） | [`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md) |
| HO 接触 | touches-HO は無条件 escalate（priority 1・絶対条件） | [`ho-paths.md`](../../ai/ai-loop/ho-paths.md) |
| escalate の自己解決 | AI 自己完結禁止（人間しか担えない操作を AI-owned にしない） | [`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md) |
| 重大/critical リスク | AC-8 安全側で Human 確定（判定不能/未充足なら Standard・同期） | [`mode-classification.md`](../../../.claude/rules/mode-classification.md) |
| discovery の着手決定 | D-2/D-3 は candidate 提示のみ・exec は Human/orchestrator が起動 | 本書 §2 Triage gap・[`unknown-discovery.md`](./unknown-discovery.md) |
| C-3/C-4 ゲートの判定主体 | APPROVE/REQUEST CHANGES/REJECT の決定権は人間のまま | [`working-context.md`](../../../.claude/rules/working-context.md) |
| 親 PBI 分解確定・子 exec 開始・親完了宣言・スコープ拡大（AS-1〜AS-5） | AI 自己完結禁止条項（親子構造を伴う場合の Gate） | [`orchestrator-mode.md`](../../../.claude/rules/orchestrator-mode.md) |

### 8.3 事後監査による安全性担保（EPIC #822 リスク対応）

`AUTO_APPROVED` の経路はすべて以下で事後監査可能（record 保存・
§3 Trust Ledger 索引の「裁定イベント」「承認根拠」系列と対応）:

- run_id / round_index / task_id（[#815](https://github.com/s977043/plangate/issues/815)）
- gates.c1 / breakdown の生値（[#819](https://github.com/s977043/plangate/issues/819)）
- size_ok 申告 vs 実測 changed_files 突合（[#820](https://github.com/s977043/plangate/issues/820)）
- metrics.py での集計可能性（first-pass rate 等・[#812](https://github.com/s977043/plangate/issues/812)）

事後監査であって事前承認の代替ではない点に注意する: 8.1 の非ブロック化は
「実行後に検証可能」であることを条件に許容されており、8.2 の Human 固定
項目を事後監査で置き換えるものではない。

### 8.4 本節が主張しないこと

- 「完全自律」「HITL 全廃」ではない。8.2 の Human 固定項目は本セッションの
  範囲で一切変更されていない
- 本節はこのセッションで実装済みの機構の範囲の事実記述にとどまる。将来の
  拡張（discovery の着手決定自動化等）は明示的に対象外（§2 Triage gap /
  §5 判断1「V2 候補」参照）
