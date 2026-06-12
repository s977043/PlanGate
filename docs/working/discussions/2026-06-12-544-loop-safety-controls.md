# #544 Loop 安全制御要素の PlanGate 取り込み — 討議メモ

> **Status**: 討議メモ（2026-06-12, rev.2）。4 視点レビュー（qa-reviewer / explorer / solution-architect / Codex）反映済。
> **対象 issue**: [#544](https://github.com/s977043/plangate/issues/544)
> **関連 issue**: [#543](https://github.com/s977043/plangate/issues/543)（外部レビュー結果の判定連携）/
> [#487](https://github.com/s977043/plangate/issues/487)（Phase R / trusted-autonomous / Risk Budget）/
> [#493](https://github.com/s977043/plangate/issues/493)（計画修正・長時間検証対応）/
> [#528](https://github.com/s977043/plangate/issues/528)（EH-3 doc-light）
> **スコープ**: PlanGate 本体の機能強化。別プロジェクト構想は本メモの対象外。

---

## 1. 結論

PlanGate に取り込むべきは「Loop を全部自動で回す機能」ではなく、
**Loop を安全に止める・戻す・検証するための制御点**である。

PlanGate の強みは「Plan を作って承認してから実行する」こと。ここに

- **Verification**（検証コマンドの明示。※既存 Testing Strategy > Verification Automation の具体化として）
- **Stop Condition**（完了条件の明示）
- **Replan Rule**（前提崩壊時の差し戻しルール）

を足すと、Plan が「実行可能で・止め方と戻し方が定義された」状態に近づく。
ただし plan に書くだけでは **ソフト強制（LLM が参照すれば従う）にとどまる**。
「契約」化（記入を承認条件にする）には C-1 拡張（同一ブランチ）+ Gate 化（#543）が要る（§4 参照）。

Risk / Review Checklist / Loop Log は次段で追加する。
完全自動リトライ・無制限の自己修正・自動マージは**初期段階では入れない**。

---

## 2. #544 提案 6 要素 × 既存資産マップ

> rev.2 注: 下表は実機確認に基づき修正済。plan.md の必須セクション正本は
> **`docs/working/templates/` には存在せず**（plan 雛形ファイルは無い）、
> `docs/ai-driven-development.md` の Prompt 1（L291-）+ `.claude/rules/working-context.md` L179-188 が正本。
> `.agents/skills/ai-dev-plan/SKILL.md` L31-33 も「skill は順序のみ、必須セクション正本は ai-driven-development.md / mode-classification」と明記。

| 提案要素 | 既存の対応物（実機確認） | 判定 |
|---------|------------------------|------|
| **Verification** | **既に `Testing Strategy > Verification Automation` が存在**（ai-driven-development.md L335 / working-context L188）。ただし任意記述で stop_condition と未連動 | **既存セクションの具体化**（新規 top-level `## Verification` は作らず、Verification Automation を強化）|
| **Stop Condition** | mode 別フェーズ完了条件 / handoff 6 要素 / DoD。plan 本体への明示は薄い | **新規価値あり**（plan に完了条件を明示）|
| **Replan Rule** | 第 2 原則（迂回禁止）/ working-context の Replan・Deferred(BLOCKED) ゲート / ai-dev-plan SKILL「人間ゲートの明示」「リスク3点セット」。概念はあるが plan 静的記述として無い | **明文化価値あり**（plan に差し戻し条件を明示。自己設置 Gate 非緩和原則と接続）|
| **Risk** | `Risks & Mitigations`（ai-driven-development.md L337）が既存 / mode-classification の Risk 軸 | **既存セクションへ吸収**（新設しない）|
| **Review Checklist** | C-1 セルフレビュー（Plan 7 + ToDo 5 + TestCases 3 = **15 項目**。「17項目」は v3 改善コメント由来の通称）/ review-self.md / plan-quality-check SKILL | **C-1 と概念重複だが完全一致ではない**（後述）|
| **Loop Log** | `decision-log.jsonl`（append-only・schema 制約あり）/ WF-06 retro。※`status.md` に Attempt 欄は**現存しない** | **新設提案**（既存資産ではない。接続先は status.md Attempt 欄新設 vs decision-log のいずれか）|

### Review Checklist の扱い（rev.2 修正）

「C-1 と重複だから新設見送り」は結論として妥当だが、#544 の Review Checklist 7 観点のうち
**「Verification は実行可能か」「Replan Rule は明確か」は現 C-1 の Plan 7 項目に存在しない**。
よって正しくは「**新設はせず、C-1 Plan チェック項目を拡張して吸収する**」（plan-quality-check / review-self.md の Plan 観点に 2 項目追加）。

### 取り込み優先度

| 優先 | 要素 | 理由 |
|------|------|------|
| 高 | Verification（既存 Verification Automation 強化） | Plan が検証可能になる |
| 高 | Stop Condition | AI の完了判定を明確化 |
| 高 | Replan Rule | 勝手な方針変更を防ぐ |
| 中 | Risk | 既存 Risks & Mitigations へ吸収 |
| 中 | Loop Log | 試行錯誤を資産化（接続先要決定・新設） |
| 中 | C-1 拡張 | Stop Condition / Replan 記入チェックを C-1 に 2 項目追加（ソフト強制を一段上げる）|

---

## 3. 関連 issue との責務分担（rev.2 修正）

本テーマは既存 issue と重なる。レビューで #543 委譲がスコープ超過と判明したため二段分離する。

| 領域 | 担当 | 補足 |
|------|------|------|
| **plan 正本への 3 要素追加**（Verification Automation 強化 / Stop Condition / Replan Rule） | **#544（本 issue）** | 編集対象は §4 で確定 |
| **plan フィールド充足チェック**（記入有無を C-1 で検出） | **#544（C-1 拡張・同一ブランチ）** | plan-quality-check / review-self.md の Plan 観点に追加。**#543 ではない** |
| **進行可否の Gate 化**（未記入で承認不可・strict） | **#543** | #543 は「**外部レビュー結果**（Decision/Risk/Stop-Work 等）の判定連携」。Gate 判定の器を #543 が持ち、#544 の充足結果を入力にできる |
| **Risk Budget / trusted-autonomous / Phase R** | **#487** | #544 の Risk は「明示」まで。自律予算は #487 |
| **計画修正・長時間外部検証への対応** | **#493** | #544 で定義する Replan Rule のトリガ条件が #493 のフィードバックゲートの入力になる（依存方向: #544 → #493）|

> rev.2 の要点: 「充足チェック」と「Gate 化（承認不可）」は別レイヤー。
> 充足チェックは C-1 拡張（#544 内で完結）、承認不可化の強制は #543。
> 単純に「Phase 2 を #543 へ」と委譲すると、#543 のスコープ（外部レビュー結果連携）外で宙づりになる。

---

## 4. 段階導入案（PlanGate 既存フェーズへのマッピング）

| Phase | 内容 | 担当 | 既存フェーズ |
|-------|------|------|------------|
| **Phase 1** | plan 正本に Stop Condition / Replan Rule 追加 + Verification Automation 強化 + C-1 に記入チェック 2 項目追加 | #544 | B（plan 生成）/ C-1 |
| **Phase 2** | 未記入で承認不可（strict Gate 化） | **#543** | C-3 ゲート |
| **Phase 3** | Loop Log の接続先決定・新設（status.md Attempt 欄 vs decision-log 拡張） | 別 issue 化候補 | D（exec）/ status.md |
| **Phase 4** | Risk Budget・自律度制御 | **#487** | mode-classification |

### Phase 1 の編集対象（rev.2 で確定）

plan 雛形ファイルは存在しないため、**正本ドキュメントへの追記**になる:

1. **`docs/ai-driven-development.md`** Prompt 1（L291-337 付近）— Stop Condition / Replan Rule セクション追記、Verification Automation 強化
2. **`.claude/rules/working-context.md`** L179-188「plan.md（EXECUTION PLAN）」必須要素リストに追記
3. **`.agents/skills/ai-dev-plan/SKILL.md`** — 1・2 を正本参照しているため原則追従のみ（必須セクションを再定義しない＝Rule 1）
4. **C-1 側**（`plan-quality-check` SKILL / `review-self.md` テンプレ）— Plan チェックに「Stop Condition 記入済か」「Replan Rule 記入済か」を追加

#### 追記する 3 セクション雛形（Verification は Testing Strategy 配下に統合）

```md
## Testing Strategy
（既存。Unit / Integration / E2E に加え）
### Verification Automation
実装後に実行する検証コマンド（プロジェクト固有値は各リポジトリの CLAUDE.md が注入 / Rule 4）。
- <test コマンド>
- <lint コマンド>
- <typecheck コマンド>

## Stop Condition
以下を満たしたら完了とする。
- 変更が Scope 内に収まっている
- Verification Automation が成功している
- 必要なテストが追加/更新されている
- 既存仕様を壊していない
- 残課題が明示されている

## Replan Rule
以下の場合は実装を止めて Plan を更新する（第 2 原則: 迂回禁止 / 自己設置 Gate 非緩和原則と整合。
本ルールは /goal・autonomy 包括承認では自動解除されない）。
- Plan と既存設計が矛盾した
- 変更範囲が想定より広がった
- DB / API / 認証認可 / セキュリティに影響が出た
- 新しい依存追加が必要になった
- Verification の失敗原因が Plan の前提と異なった
```

> Verification はプロジェクト非依存のためテンプレ側はプレースホルダ + 例示に徹し、
> 実コマンド注入は各リポジトリの CLAUDE.md が担う（Rule 4）。特定言語コマンドをテンプレに埋めない（Rule 2 違反回避）。

### mode 判定（rev.2 で対象パス別に書き分け）

| 編集対象 | HO 9 カテゴリ該当 | mode 判定 |
|---------|------------------|----------|
| `.claude/rules/working-context.md` | **該当**（`.claude/rules/*.md`）| **lite_eligible=false + Standard 同期 C-3 固定**（mode-classification「承認境界周辺の変更 → 最低 high」/ autonomous APPROVE 不可）|
| `docs/ai-driven-development.md` | 非該当（HO 9 カテゴリ外）| ただし plan 生成挙動の正本変更のため定性「ワークフロー定義変更」に近い → **最低 high・C-3 推奨** |
| `.agents/skills/ai-dev-plan/SKILL.md` | 非該当（`.claude/skills/` のみ override 外と明記、`.agents/skills/` は除外列挙に**無い**）| 配布正本の挙動変更 → 定性 critical 該当の可能性。**安全側で high・C-3** |
| `plan-quality-check` / `review-self.md` | 非該当 | 標準モード判定 |

→ 編集セットに `.claude/rules/working-context.md` を含む時点で **本 PBI 全体が lite_eligible=false + Standard 同期 C-3 固定**（安全側集約）。

---

## 5. 未決事項（rev.2 更新）

- [ ] Verification Automation の「強化」の具体（stop_condition との連動・プレースホルダ必須化の有無）
- [ ] Loop Log の接続先（status.md に Attempt 欄を新設 vs decision-log.jsonl 拡張。後者は append-only schema 制約あり）
- [ ] Phase 3（Loop Log）を #544 で扱うか別 issue 化するか（#544 のクローズ条件を Phase 1 完了に絞れるか）
- [ ] C-1 拡張 2 項目（Stop Condition / Replan 記入チェック）を plan-quality-check と review-self.md の双方に入れるか

---

## 6. 一行サマリ

> #544 は PlanGate の plan に Stop Condition / Replan Rule を追加し Verification Automation を強化する。
> Verification は既存 Testing Strategy 配下に統合、Risk は既存 Risks へ吸収、Review Checklist は C-1 拡張で吸収。
> 充足チェックは C-1（#544 内）、承認不可化は #543、自律予算は #487、計画修正運用は #493 に分離する。
> 編集対象は plan 正本（ai-driven-development.md + working-context.md）で、後者が HO のため全体 Standard 同期 C-3 固定。
