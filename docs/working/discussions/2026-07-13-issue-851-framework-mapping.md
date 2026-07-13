# 2026-07-13: issue #851 対応表 — Pocock × Superpowers × g-stack の計画スタック取り込み検討

> 対象: [#851](https://github.com/s977043/plangate/issues/851)（Design）
> status: **一次分析（判断材料）。採用/見送りの最終確定は Human**
> 本ファイルの役割: #851 の検討項目 A（Alignment Gate）/ B（Task Contract v2）/
> C（Reviewer Lens Registry）の各要素を、PlanGate 既存機構へ実ファイルパス付きで
> 対応付け、gap 一次判定を提供する。#851 完了条件そのもの（8 項目のチェック確定）
> はここでは満たさない — Human が本ファイルを読んで判断する入力に限定する。

## 0. 実測範囲・前提

実測した資料:

- `gh issue view 851`（全文）
- `gh issue view 810`（Unknown Discovery Gate 拡張・TASK-0810 pbi-input.md）
- `gh issue view 786`（Fable 実働パターン還元・F-1〜F-5・実装状況コメント含む）
- `gh issue view 729`（CLOSED。Unknown Discovery Gate 導入検討の起点。#810 の前身）
- `.claude/rules/review-principles.md` §7-bis（C-2 2 レーン契約）
- `docs/ai/external-reviewer-interface.md`（§9 専門 Reviewer Skill 一覧・§9.1
  plan-quality-reviewer・§10 unavailable 記録規約）
- `.claude/skills/breakdown-gate/SKILL.md`（intake ゲート・growth-core 由来）
- `docs/ai/subagent-delegation/README.md`（配置 ADR・§2.5 棲み分け表冒頭）
- `docs/working/templates/plan.md`（全見出し一覧・F-1/F-2/F-4 実装済み節）
- `docs/workflows/ai-loop/unknown-discovery.md`（4 分類・3 ゲート構造）
- `docs/working/discussions/` 既存ファイル一覧（形式参考、内容は個別に未読）
- CLAUDE.md / .claude/rules/working-context.md（todo.md 記述ルール・rollback 既定 — セッションコンテキストとして実測）

未確認（Human 確認が必要、または本分析のスコープ外として未実施）:

- 外部フレームワーク本体（Matt Pocock skills / Superpowers / g-stack）のソース・
  最新版・ライセンス — 元ポスト URL（X/Twitter）のみで一次資料未取得。#851 完了
  条件「外部実装を参照する場合のライセンス確認」は**本分析では未着手**
- `docs/ai/subagent-delegation/` 配下の `outcome-contract.md` / `behavior-norms.md`
  / `dispatch-template.md` / `examples.md` / `plangate-flow-integration.md` の全文
  （README の索引部のみ実測。B 項目の詳細対応にはこれらの全文確認を推奨）
- `docs/workflows/ai-loop/` 配下の `loopspec.md` / `review-feedback-loop.md` /
  `decision-table.md` 等の全文（E 項目「ai-loop / Trust Ledger 接続」の詳細判定に
  必要だが、本分析では unknown-discovery.md のみ実測）
- `.claude/commands/ai-dev-workflow.md` L194-232（C-1 17 項目正本）の全文（#786
  コメントで HO 指定と判明したが本文は未読）
- TASK-0810 の C-3 承認状況・#786 slice 3（F-1 C-1 追加・F-5）の PR マージ有無

---

## 1. 対応表（検討項目 A / B / C）

判定は 4 値: **既存で充足** / **既存拡張で対応可** / **新規要** / **対応不要**。

### A. Alignment Gate（Pocock型 `grill-me` / `grill-with-docs`）

| # | #851 の要素 | 対応する既存機構 | 判定 | 根拠 |
|---|---|---|---|---|
| A-1 | 対話型 Alignment Loop（未解決判断ゼロを終了条件） | `docs/workflows/ai-loop/unknown-discovery.md` §2（4 分類）+ TASK-0810 pbi-input.md（Plan 作成・PR 前セルフレビューへの統合設計） | **既存拡張で対応可** | unknown-discovery.md は Known/Unknown Knowns/Unknowns の 4 分類と「Plan 前→Plan 中→実装中」の 3 ゲート構造を既に定義。ただし現状は ai-loop（PoC）側の正本であり、PlanGate 本体 plan.md への統合は TASK-0810 が担当中（未完了・pbi-input.md 段階） |
| A-2 | `unresolved_blocking_decisions: 0` を完了条件とする YAML 終了条件 | plan.md `## Questions / Unknowns（#786）` 節（L58）+ TASK-0810 の `Blocking Unknowns` / `Readiness: ready/needs_clarification/blocked` 候補 | **既存拡張で対応可** | plan.md には Questions/Unknowns 節が既にあるが、`blocking` フラグや `Readiness` 状態の構造化 YAML はまだ入っていない（TASK-0810 未実装） |
| A-3 | `grill-with-docs` 相当（コードベース/ドキュメント参照必須） | TASK-0810「Repository-Resolvable Questions」候補（コードベースや履歴から AI 自身が調査すべき事項を人間へ質問する前に区別） | **既存拡張で対応可** | 概念は TASK-0810 pbi-input.md に明記済みだが実装前 |
| A-4 | #729 / #810 との重複回避 | #729（CLOSED・#810 の前身）→ #810（Unknown Discovery を Plan 作成 + PR 前セルフレビューへ統合する現行進行中 issue） | **対応不要（要重複回避）** | #851 の Alignment Gate は #810 と**同一領域**。#851 は「対話ループとしての強化」を追加検討事項に挙げるが、#810 は既に Plan/PR前セルフレビューへの統合を設計済み。**A は新規 Gate を作らず #810 の実装完了を待つのが妥当**（詳細は §2 重複マトリクス） |
| A-5 | light 以下での質問数上限 | 未確認（#851 独自提案。#810 側に該当節なし） | **新規要（軽量）** | #810 の想定フローに Mode 別上限の記載は無い。#851 の D 節（Mode別適用表）に「light: 最大3問」の暫定案あり。既存 mode-classification.md フェーズ適用マトリクスへの 1 行追加で対応可能な粒度 |

### B. Task Contract v2（Superpowers型）

| # | #851 の要素 | 対応する既存機構 | 判定 | 根拠 |
|---|---|---|---|---|
| B-1 | target_files（modify/create）+ dependencies | plan.md `## Files / Interfaces`（L73）+ `## Work Breakdown`（L80、Task 単位） | **既存で充足** | 既存 plan.md は Files/Interfaces と Work Breakdown で対象ファイルと依存を既に構造化 |
| B-2 | implementation.strategy=test-first / steps | `.claude/skills/tdd-workflow` 相当 + Work Breakdown の Task 見出し | **既存で充足** | TDD 前提は既存ワークフロー（WF-04）に組み込み済み。plan への完成コード全文記載は #851 自身が非採用方針を明示 |
| B-3 | verification.commands / expected | plan.md `## Verification Plan`（L157）+ test-cases.md | **既存で充足** | 既存の test-cases.md マッピングと Verification Plan で担保 |
| B-4 | rollback | working-context.md todo.md 記述ルール「各タスクに `rollback:` を記載（必須=high-risk/critical）」 | **既存で充足** | working-context.md に既定あり（本分析冒頭の CLAUDE.md コンテキストに実測済み） |
| B-5 | completion（完了条件） | test-cases.md 受入基準マッピング + status.md 残タスクチェックリスト | **既存で充足** | 既存構成でカバー |
| B-6 | delegation:（allowed/forbidden/report_must_include/verify_cmd） | #786 F-3 提案（**未実装**）+ `docs/ai/subagent-delegation/` 一式（outcome-contract.md 等・全文未読） | **新規要** | #786 コメント実測により、**`docs/working/templates/todo.md` は現状ファイルが存在しない**（INDEX.md が言及するのみ）。F-3 の `delegation:` ブロックは todo.md テンプレート新設の判断待ちで未実装。#851 の B 項目はこの F-3 gap と**同一の未充足領域** |
| B-7 | breakdown-gate との責務分担 | `.claude/skills/breakdown-gate/SKILL.md`（起動前 intake、mode-classification 非代替、plan-quality-check とはタイミングで分離） | **既存で充足** | breakdown-gate は既に「起動前」「起動後」「plan 生成後」の 3 段階責務分界表を持つ。Task Contract v2 は「plan 生成後〜実行時」のレイヤーであり breakdown-gate の責務と衝突しない |
| B-8 | サブエージェント委譲プロトコルとの接続 | `docs/ai/subagent-delegation/README.md`（正本）+ CLAUDE.md 参照済み | **既存拡張で対応可** | 委譲プロトコル自体は #710/#715 系で正本化済み。B-6（delegation: ブロック）との統合実装が #786 の未実装項目として明記されている＝#851 の B はこれと重複（§2 参照） |
| B-9 | C-1/C-2/rubric grader/code-run rubric の評価対象化 | `docs/ai/external-reviewer-interface.md` §9（専門 Reviewer Skill 段階導入）+ ai-loop rubric grader（CLAUDE.md 言及のみ、詳細未読） | **既存拡張で対応可** | 評価接続の枠組み（Reviewer Skill 段階導入表）は既にあるが、Task Contract v2 固有のフィールドを rubric に紐付ける実装は無し |

### C. Reviewer Lens Registry（g-stack型）

| # | #851 の要素 | 対応する既存機構 | 判定 | 根拠 |
|---|---|---|---|---|
| C-1 | 目的別 Reviewer Lens（product/engineering/design/security/devex/qa/release） | `docs/ai/external-reviewer-interface.md` §9 専門 Reviewer Skill 一覧表（lane: design-validity / security / test-strategy / code-quality / release / docs） | **既存拡張で対応可** | 既存表は 6 lane を定義済みで、`plan-quality-reviewer`（design-validity）のみ導入済み（TASK-0126）。security-risk / test-strategy / implementation-quality / release-readiness / docs-handoff は「🔜 予定」段階。#851 の C はこの**既定路線の実装完了**そのものに相当し、新規設計は不要 |
| C-2 | 条件付きルーティング（`when: [touches_auth, ...]`） | 同上表の「Mode 閾値」列（light+ / standard+ / high-risk+）+ v2.0 Mode スケール表（§8） | **既存拡張で対応可** | Mode 閾値によるスケール表は既にあるが、`touches_auth` 等の**変更内容ベースの条件付き発火**（属性トリガー）は未実装。Mode 閾値のみでは #851 の条件例（design 変更時のみ design lens）を表現できない部分がある |
| C-3 | 共通 Review Contract への正規化 | external-reviewer-interface.md §3（出力フォーマット変換）+ §3.2 Severity マッピング + §3.3 events 最小フィールド | **既存で充足** | `R-NNN / lane / severity / status` の正規化フォーマットは既に正本化済み（`review-external.md` 追記互換） |
| C-4 | findings のトレース可能性（AC/task/evidence） | review-principles.md §7-bis「コード起因の AC/スコープ欠落の捕捉責任」+ external-reviewer-interface §3.3 | **既存拡張で対応可** | トレース方針の記述はあるが、Lens 別（product/design/devex 等）に拡張した際のトレース経路は 2 レーン（design-validity / codebase-pattern）を前提にした現行設計のままで、g-stack 型の 5〜7 lens 化時の再検証が必要 |
| C-5 | Lens 自身が Gate 判定を持たず PlanGate Gate へ集約 | review-principles.md §4 判定基準（Auto-approve/Human review required 等）が唯一の Gate | **既存で充足** | 既存判定基準は severity 集約による単一 Gate。Lens 追加でも判定ロジック自体の変更は不要（設計原則と整合） |
| C-6 | 23+ Skill を増やさない最小構成 | external-reviewer-interface §9 の段階導入順（① plan-quality → ② security-risk → ③ test-strategy → ④ 残 4 本は high-risk+ 限定） | **既存で充足（方針一致）** | 既存ロードマップ自体が「最小構成・段階導入・high-risk+限定」という #851 の設計原則と一致済み |

**サマリ**:
- A（Alignment Gate）: 5 項目中 既存拡張 3 / 対応不要（重複回避対象）1 / 新規要（軽量）1
- B（Task Contract v2）: 9 項目中 既存で充足 5 / 既存拡張 2 / 新規要 1（delegation: ブロック）/ 既存で充足（責務分離）1
- C（Reviewer Lens Registry）: 6 項目中 既存で充足 3 / 既存拡張 3 / 新規要 0

**全体傾向（一次判定・前提条件つき）**: #851 が新規に持ち込む要素のうち、現時点の
実測範囲で「新規」と判定できたのは **B-6（delegation: ブロック）と A-5（Mode 別
質問数上限）** に限られる。A・C の大半は既存機構（#810・
external-reviewer-interface §9 ロードマップ）の**実装完了待ち**である。
ただしこれは §0 の未確認事項 — 特に**外部 3 フレームワーク本体（ソース・終了
条件・成果物形式・ライセンス）が未読** — を前提とした一次判定であり、本体確認
（#851 完了条件の調査項目）で本表の判定が覆る可能性がある。「新設不要」の断定は
本体確認の完了までしない。

---

## 1-bis. 直列スタックとしての接続点

> #851 の核心は「3 フレームワークは代替案でなく直列レイヤー
> （Pocock=Alignment → Superpowers=Planning → g-stack=Review Lens →
> PlanGate=Control Plane/Gate）」という解釈である。本節は、A→B→C を直列接続した
> 場合に PlanGate 側でどの成果物・ゲートが接続点になるかを §1 の対応表と整合する
> 形で明示する。

| レイヤー | 外部フレームワーク | PlanGate 側の接続点（成果物） | 通過するゲート | §1 対応 |
|---|---|---|---|---|
| Alignment（未知解消） | Pocock `grill-me` / `grill-with-docs` | plan.md `## Questions / Unknowns` 節 + TASK-0810 の `Blocking Unknowns` / `Readiness` 出力（Plan 前〜Plan 中） | **C-3**（Readiness=blocked なら Plan 確定不可 — #810 設計方針「Blocking Unknown が残る場合は Plan 確定を止める」） | A-1〜A-3 |
| Planning（契約化された分解） | Superpowers spec lock → task breakdown → subagents | Work Breakdown（plan.md L80）+ todo.md（新設判断待ち）の `delegation:` ブロック + `docs/ai/subagent-delegation/` 派遣プロンプト契約 | **C-3 承認済み plan → exec**（`bin/plangate exec` は APPROVED c3.json のみ受理）+ breakdown-gate（起動前 intake） | B-1〜B-8 |
| Review Lens（目的別レビュー） | g-stack CEO/eng/design/DevEx review → QA | external-reviewer-interface.md §9 の lane 別 Reviewer Skill → `review-external.md` の `R-NNN / lane / severity / status` 正規化出力 | **C-2**（plan ゲート）/ **V-3**（実装後）— Lens は判定を持たず severity 集約が review-principles.md §4 の単一判定へ流れる | C-1〜C-5 |
| Control Plane（最終判定・証跡） | （PlanGate 自身） | status.md / decision-log.jsonl / handoff.md / evidence/ | **C-3 / C-4**（Human-owned・不変） | — |

**直列接続の含意**:

- 各レイヤーの出力が次レイヤーの入力になる連鎖は、**既存成果物のリレー**で表現
  できる: Alignment の未解決事項（Unknowns 節）が解消されない限り C-3 を通らず、
  C-3 承認済み plan の Work Breakdown（+ `delegation:` ブロック）が exec の契約に
  なり、その成果物を lane 別レビューが R-NNN として C-2/V-3 に集約し、最終判定は
  C-3/C-4（Human-owned）に留まる。
- **再点検の結論: 直列接続しても新設 Gate は不要（一次判定・§1 の判定と一致）**。
  レイヤー間の受け渡しはすべて既存ゲート（C-3 / exec 前提条件 / C-2 / V-3 / C-4）
  で表現でき、追加が必要なのは「ゲート」ではなく**接続点となる成果物フィールド**
  （TASK-0810 の Readiness 構造化、#786 F-3 の `delegation:` ブロック）である。
  §1 の判定（A: #810 統合、B: B-6 のみ新規、C: §9 ロードマップ実行）は変わらない。
- ただしこの結論は §0 の未確認事項（外部フレームワーク本体の終了条件・成果物
  形式・ライセンスの一次資料未読）を前提とした**一次判定**であり、本体確認
  （#851 完了条件の調査項目）の結果次第で覆りうる（§3 末尾の留保に従う）。

---

## 2. 重複マトリクス

| #851 項目 | 重複先 | 重複の性質 | 分界案 |
|---|---|---|---|
| **A × #810** | #810「feat: Plan作成とPR前セルフレビューにUnknown Discoveryを取り込む」（TASK-0810・OPEN・pbi-input.md 段階） | **A-1〜A-4 は重複、A-5 のみ新規**。#810 は #729（CLOSED）の後継で、Plan 作成プロトコル + PR 前セルフレビューへの Unknown-aware 拡張を既に設計中（Known Facts/Assumptions/Known Unknowns/Possible Unknown Unknowns/Repository-Resolvable Questions/Human Decisions Required/Blocking Unknowns/Readiness の出力候補まで具体化済み）。一方 **A-5（light 以下の質問数上限）は #810 に存在しない #851 独自要素** | **#851 の A-1〜A-4 は独立実装せず、#810 の完了を前提条件とする**。#851 が追加で持ち込む価値は ①「対話ループとして質問数ではなく blocking decision 解消を終了条件にする」運用ポリシー（#810 の `Readiness: needs_clarification` に 1 行の完了条件を足せば済む差分）と ② **A-5 の Mode 別質問数上限**（mode-classification.md への追記候補・§1 で新規要（軽量）判定）の 2 点。**新規 Gate は作らない** |
| **B × #786 F-3** | #786「Fable セッションの実働パターンを Plan テンプレートへ還元する」F-3（委託契約フィールド） | 完全重複。#786 のコメントで **delegation: ブロックが `todo.md` テンプレート不在のため未実装**と明記済み。#851 の B-6 が求める内容と #786 F-3 の文案は同一（allowed/forbidden/report_must_include/verify_cmd） | **#851 の B は独自設計をせず、#786 F-3 の未完了タスク（todo.md テンプレート新設判断）を先に解消する**。#786 に 2026-07-10 の実害エビデンス（worktree isolation 汚染）追記済みで優先度は既に高い。#851 側で B を別建てにすると同じ議論を二重に行うことになる |
| **B × 委譲プロトコル（#710/#715）** | `docs/ai/subagent-delegation/` 正本一式 | 部分重複。プロトコル自体（OUTCOME 契約・行動規範・派遣プロンプト8要素）は既に正本化済みだが、**plan.md/todo.md への機械的フィールド落とし込みは未接続** | 分界: 委譲プロトコル＝「派遣時の規範・契約」（docs/ai/subagent-delegation/ が正本）、Task Contract v2 の delegation: ブロック＝「plan/todo 内でのフィールド表現」。**#851 は後者（表現層）のみを扱い、規範層は変更しない** |
| **C × C-2 2レーン設計** | review-principles.md §7-bis（設計妥当性レーン / コードベース整合レーン） | 部分重複。2 レーンは「読む対象」で分けた設計、g-stack Lens は「評価目的」で分ける設計 — 軸が異なるため完全重複ではないが、**実装済みの `plan-quality-reviewer` は 2 レーン設計の設計妥当性レーンそのもの** | 分界: 既存 2 レーン契約（§7-bis）は「C-2 の読解責務分離」の正本として不変。Reviewer Lens Registry は**その上位の「lane 一覧・Mode 閾値・条件付きルーティング」を管理する台帳**として external-reviewer-interface.md §9 に既に存在。**#851 の C は §9 表の未導入 5 lane（security-risk/test-strategy/implementation-quality/release-readiness/docs-handoff）の実装促進に読み替える** |
| **C × external-reviewer-interface.md** | 同上 §9 全体 | ほぼ完全重複 | **#851 の C は新規正本を作らず、§9 表のロードマップ実行状況の追跡先として同ファイルを使い続ける** |

---

## 3. 推奨（一次案・Human 判断材料）

> #851 の設計原則「外部フレームワークの巨大な Skill 群を丸ごとコピーしない」
> 「既存 `plan.md`/`todo.md`/`test-cases.md`/`status.md`/decision record への統合を
> 優先する」に沿い、**新規の Gate/Contract/Registry の新設は最小限に留める**方針で
> 一次案を出す。
>
> **前提条件（結論の留保）**: 以下の一次案はすべて、外部 3 フレームワーク本体
> （ソース・終了条件・成果物形式・ライセンス）が**未読**であること（§0）を前提と
> する。本体確認は #851 の完了条件に含まれる調査項目であり、その結果によって
> 「既存で充足 / 新設不要」の判定・推奨は覆りうる。

| 項目 | 一次案 | 理由 |
|---|---|---|
| **A. Alignment Gate** | **見送り（#810 に統合）**。#851 として独立実装しない。#810 の完了条件に「Readiness=blocked の終了条件を明示（未解決 blocking decision ゼロ）」を 1 項目追加する程度に留める | A の実質は #810 の再発明。新規実装コストを払う理由がない |
| **B. Task Contract v2** | **部分採用**（B-6 のみ）。B-1〜B-5/B-7〜B-9 は既存で充足のため無対応。B-6（delegation: ブロック）は #786 F-3 の未完了タスクとして先に着手し、`docs/working/templates/todo.md` の新設可否を判断する | 新規に持ち込む価値がある要素は delegation: ブロックのみ。それも #786 側の issue として既に切られている |
| **C. Reviewer Lens Registry** | **既定ロードマップの実行加速として採用**。新規正本は作らず、external-reviewer-interface.md §9 の「🔜 予定」5 lane（security-risk / test-strategy / implementation-quality / release-readiness / docs-handoff）の導入を優先タスク化する。C-2（条件付きルーティング `when: [...]`）のみ、Mode 閾値表に「変更内容トリガー」列を追加する小さな拡張として新規検討に値する | 既存ロードマップと #851 の C はほぼ同一物。属性ベースのルーティングだけが未充足の新規要素 |
| **D. Mode別適用** | 既存 mode-classification.md のフェーズ適用マトリクスへの軽微な追記で対応可（A-5 の light 質問数上限など）。**新しい Mode 別適用表を #851 独自に作らない** | 二重の正本化を避ける |
| **E. ai-loop / Trust Ledger 接続** | **未確認のため判断保留**。`docs/workflows/ai-loop/loopspec.md` 等の全文を読まないと接続方針を決められない。Human が優先順位を判断した上で別途調査が必要 | 実測範囲外（§0 未確認事項） |

### 後続 Issue 分割案（一次）

1. **#810 の完了を最優先**（A の実質的な受け皿。すでに OPEN・pbi-input.md 段階）
2. **#786 slice 2（F-3 delegation ブロック + todo.md テンプレート新設）を次点**（B の唯一の新規要素）
3. external-reviewer-interface.md §9 の残 5 lane 導入を通常の段階導入ロードマップ通り進める（C。新規 issue 化は不要、既存表のまま）
4. C-2 の条件付きルーティング（`when: [touches_auth, ...]`）は小粒の新規 issue 候補（優先度低・P2 相当）
5. #851 自体は「独立実装 issue」ではなく「調査完了 → 各既存 issue への誘導」で完結させ、CLOSE を推奨（Human 判断）

---

## 4. Human Decisions Required

- [ ] #851 を「独立実装」ではなく「#810・#786・external-reviewer-interface §9 への誘導のみで CLOSE」する方針でよいか
- [ ] A-5（light モードの質問数上限）を mode-classification.md への追記として着手してよいか、独立 issue にするか
- [ ] C-2（条件付きルーティング `when:` 属性トリガー）を新規 issue として切るか、§9 表の将来課題欄に留めるか
- [ ] E（ai-loop / Trust Ledger 接続）の調査に着手するか、#851 の非目標「PlanGate標準WorkflowとPoCを無理に統合しない」に従い明示的に「非接続」と結論付けるか
- [ ] 外部 3 フレームワーク（Pocock skills / Superpowers / g-stack）のライセンス確認は本分析未着手 — #851 完了条件の該当項目をどう扱うか（省略可能かどうかを含め判断が必要）
- [ ] `docs/ai/subagent-delegation/` 配下の未読ファイル（outcome-contract.md 等）を読んだ上で B-6 の delegation: ブロック文案を最終化する作業を誰が担当するか
