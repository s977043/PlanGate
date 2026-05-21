# TASK-0107 review-external.md — C-2 設計妥当性レーン外部レビュー集約

> **Phase**: C-2（PBI INPUT PACKAGE + plan 段階の事前レビュー）
> **Date**: 2026-05-21 ～ 2026-05-22
> **対象**: `brainstorm.md` / `pbi-input.md` / `plan.md` / `todo.md` / `test-cases.md`
> **レビュー観点**: C-2 設計妥当性レーン（5 観点・[`review-principles.md`](../../../.claude/rules/review-principles.md) §7-bis）
> **Rounds**:
> - **R1**: 第 1 ラウンド（pbi-input.md r0 対象、R-001〜R-005）
> - **R2**: 第 2 ラウンド（pbi-input.md r1 対象、R-006〜R-008）
> - **R3**: 第 3 ラウンド（plan.md / todo.md / test-cases.md 対象、R-009〜R-013）

---

## 1. 統合判定

### 第 1 ラウンド（pbi-input.md r0）
- Codex: CONDITIONAL（major × 2 / minor × 2）
- Gemini: APPROVE（info × 2）
- 統合: **CONDITIONAL** → R-001〜R-005 を 1 回確定反映済（pbi-input.md r1）

### 第 2 ラウンド（pbi-input.md r1）
- Codex: CONDITIONAL（R-001〜R-005 全 PASS、ただし監査表 pending 残存）
- Gemini: **APPROVE**（R-001〜R-005 全 PASS）
- 統合: **APPROVE for plan generation**
- R-006〜R-008 を 1 回確定反映済

### 第 3 ラウンド（plan.md / todo.md / test-cases.md）
- Codex: **REJECT**（major × 4 / minor × 1）— `working-context.md` Iron Law / mode-classification.md 機械的整合違反
- Gemini: **APPROVE**（info × 2）
- 統合: **CONDITIONAL** → R-009〜R-013 を 1 回確定反映

最終判定: **R-009〜R-013 反映後、C-1 簡易再実行 → C-3 ゲート（人間）に進行可**

---

## 2. 観点別評価サマリ

### R1（pbi-input.md r0）

| 観点 | Codex | Gemini |
|------|-------|--------|
| 1. 三層構成の設計妥当性 | PASS | PASS |
| 2. AC 10 件の網羅性 | **WARN** | PASS |
| 3. Out of scope の妥当性 | PASS | PASS |
| 4. Cowork 調査解釈 | PASS | PASS |
| 5. 責務 4 分類との整合 | **WARN** | PASS |
| 6. 見落としリスク | **WARN** | PASS |

### R2（pbi-input.md r1 反映評価）

| R | Codex | Gemini |
|---|-------|--------|
| R-001 [major] Workflow-owned 永続ロック | **PASS** | **PASS** |
| R-002 [major] Mode → high-risk | **PASS** | **PASS** |
| R-003 [minor] AC 検証可能性 | **PASS** | **PASS** |
| R-004 [minor] doctor --check-settings PASS AC | **PASS** | **PASS** |
| R-005 [info] 解消不能 FAIL 脱出経路 | **PASS** | **PASS** |

### R3（plan/todo/test-cases ファイル別評価）

| ファイル | Codex | Gemini |
|---------|-------|--------|
| plan.md | WARN（lite C-2 表記矛盾） | PASS |
| todo.md | **FAIL**（C-3 配置 / conductor 管轄混入） | PASS |
| test-cases.md | WARN（manual marker 欠落） | PASS |

---

## 3. 指摘リスト（R-NNN）

### 第 1 ラウンド指摘（R-001〜R-005）

#### R-001 [major] 責務 4 分類 — Workflow-owned 永続ロックの欠落
- **対象**: `pbi-input.md` r0 §1 責務4分類表 / `brainstorm.md` §4
- **改善案**: 新規 AC を追加 — 各 Step 完了ごとに `status.md` / `decision-log.jsonl` に manual action の pending/resolved を記録し、`doctor --check-settings PASS` まで V-1 / handoff 完了不可
- **出典**: Codex C-R-001 + Gemini G-R-001 統合
- **反映**: pbi-input.md r1 §1責務表 / §3 AC-11 / §4 設計原則

#### R-002 [major] モード判定 — standard 過小評価
- **対象**: pbi-input.md r0 §5 モード判定
- **改善案**: `high-risk` に修正 + Hardening Override 明記
- **出典**: Codex C-R-002
- **反映**: pbi-input.md r1 §5 モード判定

#### R-003 [minor] AC 網羅性 — 検証可能性の不足
- **対象**: pbi-input.md r0 §3 AC-2〜AC-5
- **改善案**: test-cases で検証可能な形に書き直し（`doctor --json` 利用、mock 検証）
- **出典**: Codex C-R-003
- **反映**: pbi-input.md r1 §3 AC-2〜AC-5

#### R-004 [minor] Shadow Config 防止 — `doctor --check-settings PASS` 条件の AC 化
- **対象**: pbi-input.md r0 §3 AC-10
- **改善案**: V-1/handoff 完了前に `bin/plangate doctor --check-settings PASS` を独立 AC 化
- **出典**: Codex C-R-004
- **反映**: pbi-input.md r1 §3 AC-12

#### R-005 [info] UX — 解消不能な FAIL の脱出経路
- **対象**: brainstorm.md §5 / pbi-input.md AC-4
- **改善案**: フォローアップ PBI 起票誘導 or 承知スキップの脱出経路を Agent 対話方針に
- **出典**: Gemini G-R-002
- **反映**: pbi-input.md r1 §2 Scope 7 / §3 AC-13 / §4 設計原則 / §5 R7

### 第 2 ラウンド指摘（R-006〜R-008）

#### R-006 [minor] 保守性 — 監査表 `pending` 残存
- **対象**: review-external.md §4 監査表
- **改善案**: pre-commit 段階では `reflected` に更新、commit SHA は後追記
- **出典**: Codex（R2）
- **反映**: 本表（§4）を `reflected` に更新済

#### R-007 [info] 保守性 — brainstorm.md に旧判断残存
- **対象**: brainstorm.md §4 / §7
- **改善案**: 「※ r1 で更新済、pbi-input.md r1 を正本」注記
- **出典**: Codex（R2）
- **反映**: brainstorm.md ヘッダーに r1 更新済注記追加済

#### R-008 [info] 拡張性 — 記録先ディレクトリの動的解決
- **対象**: pbi-input.md §3 AC-11 / §5 Unknowns U3
- **改善案**: plan 段階で実行コンテキストの解決（Task-local or Global）を定義
- **出典**: Gemini（R2）
- **反映**: pbi-input.md §5 Unknowns U7 追加済

### 第 3 ラウンド指摘（R-009〜R-013）

#### R-009 [major] Iron Law / ゲート順序 — C-3 が exec 後配置

- **対象**: `todo.md` r0 §「Phase 4: ゲート + リリース」（T-13 が handoff/V系後に配置）
- **指摘**: C-3 が T-13 として handoff/V系後に配置され、依存グラフでも T-03〜T-12 が C-3 承認なしに進める形になっている
- **理由**: [`working-context.md`](../../../.claude/rules/working-context.md) は C-3 を D: Agent 実行**前**の人間レビューと定義。todo 補足で「C-3 APPROVED が無い場合 exec 開始しない」と書いてあっても depends_on とグラフが逆向きでは構造として崩れる
- **改善案**: C-3 を Phase 1 直後（T-02 後）に移動。T-03〜T-08 の `depends_on` に C-3 (`G-C3`) を明示
- **出典**: Codex（R3）

#### R-010 [major] Iron Law / workflow-conductor 管轄混入

- **対象**: `todo.md` r0 T-08〜T-11（L-0 / V-1 / V-2 / V-3）/ T-14（PR 作成）
- **指摘**: L-0 / V-1 / V-2 / V-3 / PR 作成が通常 todo タスク化されている
- **理由**: working-context.md todo 定義は「L-0〜V-4, PR 作成は workflow-conductor が自動制御するため**含めない**」と明記。plan/todo 境界が崩れると conductor 自動制御と人手 todo が二重化する
- **改善案**: T-08〜T-11 / T-14 は「§ workflow-conductor 後続フェーズ」欄に分離し、本体 todo は T-01〜T-07 + C-3 (G-C3) + handoff 生成 (T-08) のみ
- **出典**: Codex（R3）

#### R-011 [major] mode / lite_eligible 整合 — `lite C-2` 表記矛盾

- **対象**: `plan.md` r0 §「フェーズ適用」C-2 行
- **指摘**: `lite_eligible=false` 明記と同時に「lite C-2: 1 本」で簡略可と記述（同一 plan 内で矛盾）
- **理由**: [`mode-classification.md`](../../../.claude/rules/mode-classification.md) の Lite は `lite_eligible=true` かつ opt-in 時の構成。本 PBI は Hardening Override 適用 `lite_eligible=false` のため Lite ゲートそのものが適用不可
- **改善案**: 「R1+R2+R3 実施」のように review round 数の積上で品質担保する旨に修正。Lite 用語は撤回
- **出典**: Codex（R3）

#### R-012 [major] test-cases 自動化可否 — manual marker 欠落

- **対象**: `test-cases.md` r0 TC-01 / TC-06 / TC-07 / TC-08 / TC-21 / TC-22 + §211 既知の自動化制約
- **指摘**: §211 で TC-01/06/07/08/21/22 は部分手動の可能性ありと明記しつつ、各 TC の **種別フィールド**には `integration` / `unit mock` のままで `manual` が反映されていない
- **理由**: C-1 TestCases 観点（review-principles.md §2-bis）は「各 TC の種別（unit/integration/grep/manual）が明示」。V-1 で自動実行対象と手動確認対象を分離できず、受け入れ検査の実行責務が曖昧になる
- **改善案**: 該当 TC の **種別フィールドを `unit mock + manual` 等に明示**。V-1 で人間確認が必要な期待出力を checklist 化
- **出典**: Codex（R3）

#### R-013 [minor] Edge case 検証責務 — EC-03 期待と検証範囲のズレ

- **対象**: `test-cases.md` r0 EC-03（同時起動）
- **指摘**: 「append-only のため衝突しない」と期待しつつ、同時 append の原子性 / ロック方式は plan で未定義、同時 append 検証を「Out of scope 候補」としている
- **理由**: 期待と検証範囲がずれている。Out of scope なら「衝突しない」ではなく「同時起動は検出して中断/注意喚起」などに落とす方が検証可能
- **改善案**: v1 では同時起動を unsupported とし、guard / 注意喚起の EC に変更。完全な同時書き込み耐性は v2 候補へ
- **出典**: Codex（R3）

---

## 4. 監査表（追記専用・squash/rebase 耐性）

| R-NNN | severity | round | status | reflected_in(commit) | notes |
|-------|----------|-------|--------|---------------------|-------|
| R-001 | major | R1 | reflected | f7ce0e7 | pbi-input.md r1 §1責務表 / §3 AC-11 / §4 設計原則。commit SHA は反映 commit 作成時追記 |
| R-002 | major | R1 | reflected | f7ce0e7 | pbi-input.md r1 §5 モード判定（high-risk + Hardening Override 明記）。commit SHA は反映 commit 作成時追記 |
| R-003 | minor | R1 | reflected | f7ce0e7 | pbi-input.md r1 §3 AC-2〜AC-5（test-case 検証可能化）。commit SHA は反映 commit 作成時追記 |
| R-004 | minor | R1 | reflected | f7ce0e7 | pbi-input.md r1 §3 AC-12（doctor --check-settings PASS）。commit SHA は反映 commit 作成時追記 |
| R-005 | info | R1 | reflected | f7ce0e7 | pbi-input.md r1 §2 Scope 7 / §3 AC-13 / §4 設計原則 / §5 R7。commit SHA は反映 commit 作成時追記 |
| R-006 | minor | R2 | reflected | f7ce0e7 | 本表（§4）を `reflected` に更新済。commit SHA は反映 commit 作成時追記 |
| R-007 | info | R2 | reflected | f7ce0e7 | brainstorm.md ヘッダーに「※ r1 で更新済」注記追加済。commit SHA は反映 commit 作成時追記 |
| R-008 | info | R2 | reflected | f7ce0e7 | pbi-input.md §5 Unknowns U7 追加済（実行時 TASK ID 動的解決）。commit SHA は反映 commit 作成時追記 |
| R-009 | major | R3 | reflected | f7ce0e7 | todo.md r1: C-3 を Phase 1 直後（G-C3）に移動、T-03〜T-08 の depends_on に G-C3 を明示。commit SHA は反映 commit 作成時追記 |
| R-010 | major | R3 | reflected | f7ce0e7 | todo.md r1: L-0/V-1/V-2/V-3/PR を §workflow-conductor 後続フェーズに分離。実装 todo は T-01〜T-08 に集約。commit SHA は反映 commit 作成時追記 |
| R-011 | major | R3 | reflected | f7ce0e7 | plan.md: 「lite C-2」表記を削除、「R1+R2+R3 実施」「review round 数の積上で品質担保」に修正。commit SHA は反映 commit 作成時追記 |
| R-012 | major | R3 | reflected | f7ce0e7 | test-cases.md: TC-01/06/07/08/21/22 の種別に `manual` を追加（unit mock + manual / integration + manual）。commit SHA は反映 commit 作成時追記 |
| R-013 | minor | R3 | reflected | f7ce0e7 | test-cases.md: EC-03 を「v1 unsupported（同時起動は検出して中断・v2 候補）」に変更。commit SHA は反映 commit 作成時追記 |

git commit 完了後、`reflected` を `reflected` に、`TBD` を実 commit SHA に追記する（追記専用）。

---

## 5. 元レビュー出力

### 第 1 ラウンド
- Codex: `/tmp/codex-review-output.txt`（48 行）
- Gemini: `/tmp/gemini-review-output.txt`（38 行）

### 第 2 ラウンド
- Codex: `/tmp/codex-review-r1-output.txt`（28 行）
- Gemini: `/tmp/gemini-review-r1-output.txt`（39 行）

### 第 3 ラウンド
- Codex: `/tmp/codex-c2-r3-output.txt`（66 行）
- Gemini: `/tmp/gemini-c2-r3-output.txt`（55 行）

### Plan 助言（参考）
- Codex: `/tmp/codex-plan-advisory-output.txt`（70 行）
- Gemini: `/tmp/gemini-plan-advisory-output.txt`（75 行）
