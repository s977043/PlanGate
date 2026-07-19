---
task_id: TASK-0871
artifact_type: review-self
schema_version: 1
status: draft
verdict: WARN
created_by: c1-review-worker（起草者とは別コンテキスト）
---

# TASK-0871 セルフレビュー結果（C-1）

> レビュー日: 2026-07-19
> 判定: **WARN** — critical=0, major=1, minor=4, info=1
> 対象: `docs/working/TASK-0871/{pbi-input,plan,todo,test-cases}.md`
> レビュー方式: 17 項目チェック（plan-quality-check Skill + review-self テンプレート準拠）。
> 実在確認・数値主張は本 worktree で実測（コマンドと結果を各項に記載）。

## サマリー

| result | 件数 |
|--------|------|
| PASS | 19 |
| WARN | 4 |
| FAIL | 0 |
| N/A | 2 |

### 実測による裏取り（量化子・実在主張の全数照合）

| plan の主張 | 実測 | 結果 |
|------------|------|------|
| `rg -l "C-3'" docs/workflows/ai-loop/*.md` → 9 ファイル | 9 ファイル（flow-detect / adaptive / loopspec / six-stage / execution-runbook / decision-table / unknown-discovery / 00_concept / stop-rollback） | ✅ 一致 |
| MERGE_READY/merge-ready → 6 ファイル | 6 ファイル（00_concept / adaptive / six-stage / execution-runbook / loopspec / `.agents/skills/ai-loop-cycle/SKILL.md`） | ✅ 一致 |
| `scripts/sync-plugin-plangate.sh` 実在 | 実在 | ✅ |
| AC-10 名指し 6 ファイル + 周辺 docs の実在 | command / SKILL / 00_concept / six-stage / adaptive / core-contract / flow-detect / stop-rollback / loopspec / execution-runbook すべて実在 | ✅ |
| `.claude/commands/ai-loop-workflow.md` は HO 対象 | `scripts/hooks/check-plan-hash.sh` case 文に `.claude/commands/*.md` あり（HO 9 カテゴリ該当）。`.agents/skills/` と `docs/ai/*.md` は HO パターン外（plan の「HO 隣接（CLAUDE.md 参照系）」表現と整合） | ✅ 正確 |
| issue #871 AC 10 項目の写像 | `gh issue view 871` 本文と突合。AC-1〜10 すべて pbi-input へ転記済み。ただし AC-9 は plan 側で対象限定が付加（後述 F-3） | ✅（10/10、注記あり） |
| `docs/workflows/ai-loop/rollout-policy.md` 未存在（新設が成立） | 未存在 | ✅ |
| design-philosophy.md の所在 | `docs/workflows/ai-loop/` に**無し**。実在は `docs/ai/ai-loop/design-philosophy.md` | ⚠️ F-2 参照 |

## 指摘一覧（severity 付き）

| ID | severity | 内容 | 対応 check |
|----|----------|------|-----------|
| F-1 | **major** | plan に明示の **Stop Condition / Replan Triggers（機械値）欄が未記入**（`rg -n "Stop Condition\|停止条件\|Replan" plan.md` → 0 件）。S9 の「矛盾 >0 なら差し戻し」、R-2 の「編集 12 ファイル超過で分割」など機械値を伴う等価トリガは散在するが、C1-LOOP-01/02（#544 Phase1）が求める明示欄がない。high-risk のため C-3 前に欄として明記すべき | C1-PLAN-08/09-AEE |
| F-2 | minor | D-6 / EC-5 が参照する `design-philosophy.md` の実在パスは `docs/ai/ai-loop/design-philosophy.md` だが、plan の Files / Components to Touch に**未列挙**。EC-5「どちらを実定義とするか確定し他方を参照化」の解消先が touch 対象外ファイルになり得る（スコープ表と検証計画の不整合） | C1-PLAN-05（注記） |
| F-3 | minor | AC-9 の対象限定（#866 除外・ai-dev/ai-loop アーキ文書に限定）は理由付きで妥当だが、issue #871 本文の AC-9 は**無限定**（実測 verbatim「正本一覧に同じ責務の複数正本が残っていない」）。限定の正当性は C-3 で Human 確定 + issue コメントで scope 注記を残す手当が todo に無い | C1-PLAN-03（注記） |
| F-4 | minor | todo T-08 の depends_on が `T-05, T-07` で、plan の依存 `(S4 ∥ S5 ∥ S6) → S7` にある **S5（=T-06 core-contract）が欠落**。core-contract は plugin references 非同梱（plan B案比較表の記載）なので実害は限定的だが、plan と todo で依存グラフが不一致 | C1-PLAN-06 |
| F-5 | minor | T-04（00_concept 正本化再構成）が 8 要素を 1 タスクに内包し粒度大。単一 commit + TC-01〜08 で検証可能ではあるが、差し戻し時（T-12 🚩）の切り分け単位として粗い | C1-TODO-08 |
| F-6 | info | mode-classification の critical 対象例に「ワークフロー定義変更」があり、ai-loop workflow 文書群の再構成は critical 引き上げ余地がある。high-risk でも C-3 同期 Human 必須は同一のため実運用差は V-4 / 複数レビュアー推奨のみ。C-3 で判断を明記されたい | Mode 判定（注記） |

## Plan チェック（7項目 + AEE 2項目）

### C1-PLAN-01: 受入基準網羅性
- **result**: PASS
- **category**: plan
- **finding**: AC-1〜10（issue #871 実測本文と全数照合）はすべて Work Breakdown に写像される。AC-1/2/3/4/6/7/8→S3、AC-5→S2+S3、AC-9→S4〜S6+S9、AC-10→S5〜S7。水増しなし・穴なし。DoD の「link check / sync dry-run / 独立 review evidence」も S7/S8/S9 でカバー
- **evidence_ref**: 本ファイル「実測による裏取り」表
- **impacted_files**: []

### C1-PLAN-02: Unknowns処理
- **result**: PASS
- **category**: plan
- **finding**: Q1〜Q3 が「C-3 で確定」と解決手段明記。pbi-input の Unknowns（core-contract 追記量）と plan Q2 が対応
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-03: スコープ制御
- **result**: PASS
- **category**: plan
- **finding**: Non-goals は issue #871 の 4 項目 + #866 別トラック宣言で明確。#866 除外は AC-9 の判定対象限定として一貫して記述され矛盾はない（pbi-input / plan / TC-09 の 3 箇所で同一限定）。ただし issue 本文 AC-9 は無限定のため F-3（minor）: C-3 確定と issue への scope 注記を推奨
- **evidence_ref**: `gh issue view 871` 実測（AC-9 verbatim）
- **impacted_files**: []

### C1-PLAN-04: テスト戦略
- **result**: PASS
- **category**: plan
- **finding**: doc タスクとして markdownlint / link check / rg 用語監査（付録 B に実コマンド）/ sync dry-run / 独立レビューが具体。AC→TC は test-cases.md に委譲され接続明記
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-05: Work Breakdown Output
- **result**: PASS
- **category**: plan
- **finding**: S1〜S9 全行に Output / Owner / Risk / 🚩 / rollback 列あり（high-risk 要件充足）。注記 F-2（minor）: EC-5 の解消先になり得る `docs/ai/ai-loop/design-philosophy.md` が Files to Touch に未列挙
- **evidence_ref**: `find . -name "design-philosophy*"` 実測（本ファイル冒頭表）
- **impacted_files**: ["docs/working/TASK-0871/plan.md"]

### C1-PLAN-06: 依存関係
- **result**: WARN
- **category**: plan
- **finding**: plan の S1→S2→S3→(S4∥S5∥S6)→S7→S8→S9 は無矛盾。ただし todo T-08 depends_on に T-06（=S5）が欠落し plan と不一致（F-4）。core-contract 非同梱のため実害は小
- **evidence_ref**: plan.md L104 / todo.md T-08 行の突合
- **impacted_files**: ["docs/working/TASK-0871/todo.md"]
- **suggested_action**: T-08 depends_on に T-06 を追加（または plan 側依存を S4∥S6→S7 に修正し理由を明記）
- **owner**: agent
- **resolved**: false

### C1-PLAN-07: 動作検証自動化
- **result**: PASS
- **category**: plan
- **finding**: 付録 B に実行可能な rg コマンド 6 種、sync dry-run、link check が列挙され、TC-10〜12 に接続。付録 A（D-1〜D-12 矛盾一覧）は S1 / T-01 で evidence 化（`evidence/verification/terminology-audit.md`）に接続済み
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-08-AEE: Stop Condition 記入（#544 Phase1）
- **result**: WARN
- **category**: plan
- **finding**: 明示の Stop Condition 欄が未記入（rg 実測 0 件）。S9 差し戻し条件・EC-1 の V-1 block 等の等価停止条件は存在するが欄として未集約。high-risk のため C-1 反映時に明記を強く推奨（skill C1-LOOP-01 は high-risk で FAIL 側解釈もあり得る。F-1 major）
- **evidence_ref**: 本ファイル F-1（rg コマンドと結果を記載）
- **impacted_files**: ["docs/working/TASK-0871/plan.md"]
- **suggested_action**: plan に「Stop Condition: 矛盾指摘 >0（TC-13）で停止・差し戻し / HO diff Human 未承認で T-07 停止」等の欄を追加
- **owner**: agent
- **resolved**: false

### C1-PLAN-09-AEE: Replan Triggers 機械値（#544 Phase1）
- **result**: WARN
- **category**: plan
- **finding**: 明示の Replan Triggers 欄が未記入。機械値を伴う等価トリガは R-2（編集ファイル数 > 12 で follow-up 分割）と S9（矛盾 >0 で S3〜S6 差し戻し）に散在。欄として集約されておらず C1-LOOP-02 の形式要件未充足（F-1 major に包含）
- **evidence_ref**: 本ファイル F-1
- **impacted_files**: ["docs/working/TASK-0871/plan.md"]
- **suggested_action**: 「Replan Triggers: 編集ファイル実数 > 12 / 独立レビュー矛盾 > 0 / sync dry-run 差分が正本外に波及」を機械値付きで欄化
- **owner**: agent
- **resolved**: false

## Plan 品質追加チェック（Superpowers 由来 / #581）

### C1-SUP-PLAN-01: No Placeholders Rule
- **result**: PASS
- **category**: plan
- **finding**: `rg -P "TBD|TODO|後で実装|必要に応じて|適切に|いい感じ"` の該当は todo.md タイトル「EXECUTION TODO」の 1 件のみ（placeholder ではない）。S4「差分が出るもののみ」は開放的だが Metrics Evidence の上限（追従 ≤6 ファイル）で有界。Q1〜Q3 は C-3 確定事項として明示済み
- **evidence_ref**: rg 実測（本レビュー実行ログ）
- **impacted_files**: []

### C1-SUP-PLAN-02: Task Sizing Rules
- **result**: PASS
- **category**: plan
- **finding**: 各タスクに変更対象ファイル・検証手段（TC 接続）・依存が明記され、タスク単位で approve/reject 可能。T-04 の粒度は F-5（minor）参照
- **evidence_ref**: —
- **impacted_files**: []

## ToDo チェック（6項目）

### C1-TODO-08: タスク粒度
- **result**: WARN
- **category**: todo
- **finding**: T-04 が正本宣言 / 5 責務表 / terminal state / C-3 経路 / 状態語彙区別 / 内外 Loop / harness 禁止 / Phase 1 置換の 8 要素を 1 タスクに内包（F-5）。TC-01〜08 で要素別検証は可能だが、差し戻し単位として粗い
- **evidence_ref**: todo.md T-04 行
- **impacted_files**: ["docs/working/TASK-0871/todo.md"]
- **suggested_action**: T-04 を「責務表+terminal state」「C-3/C-3' 経路+語彙区別」「rollout 参照置換」程度に分割検討（C-3 で判断可）
- **owner**: agent
- **resolved**: false

### C1-TODO-09: depends_on設定
- **result**: PASS
- **category**: todo
- **finding**: 全タスクに depends_on あり。T-08 の T-06 欠落は C1-PLAN-06 / F-4 で指摘済（重複計上しない）
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-10: チェックポイント設定
- **result**: PASS
- **category**: todo
- **finding**: 🚩 が T-04（diff 提示）/ T-06（CLAUDE.md 参照系）/ T-07（HO 接触）/ T-12（差し戻し条件）に設定され、plan の 🚩（S3/S5/S6/S9）と一致
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-11: Iron Law遵守
- **result**: PASS
- **category**: todo
- **finding**: 「T-03〜T-08 は H-01（C-3 APPROVED）まで着手不可」を明記。HO 対象 T-07 は「AI は diff 提示まで・Human 承認前に commit しない」で HO 常時 block 運用と整合。C-3 は同期・Human 必須（autonomous APPROVE 不可）で判定マトリクス（high-risk かつ HO パス含み → ❌）と一致
- **evidence_ref**: check-plan-hash.sh HO case 文の実測（本ファイル冒頭表）
- **impacted_files**: []

### C1-TODO-12: 完了条件
- **result**: PASS
- **category**: todo
- **finding**: 各タスクに files / 期待成果が記述され、合否基準は TC-01〜13 の期待出力へ接続。T-13 で AC 突合表の evidence 化まで明示
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-RB: rollback（戻し手順）
- **result**: PASS
- **category**: todo
- **finding**: high-risk 実装タスク T-03〜T-08 全件に `rollback:` 記述あり（git revert 単位 + T-07 は Human 手適用分の逆適用まで明記）。検証/読取タスクは「不要」と明記。欠落 0 件
- **evidence_ref**: —
- **impacted_files**: []

## テストケースチェック（3項目）

### C1-TEST-13: 受入基準→テストケース網羅性
- **result**: PASS
- **category**: test
- **finding**: AC-1〜10 の 10/10 に TC が対応（AC-4→TC-04+13、AC-10→TC-10/11/12 の多重化を含む）。TC-01〜13 に AC 対応のない水増し TC なし。Verification 4 項目（link check / 用語監査 / sync dry-run / 独立レビュー）も TC-10/12/11/13 に写像
- **evidence_ref**: 本ファイル冒頭表（issue 本文との全数照合）
- **impacted_files**: []

### C1-TEST-14: テストケースの具体性
- **result**: PASS
- **category**: test
- **finding**: 機械系 TC は実行コマンド（rg / ls / sync dry-run）と期待出力を値レベルで記述。目視系 TC も突合対象文書を名指し
- **evidence_ref**: —
- **impacted_files**: []

### C1-TEST-15: エッジケースの考慮
- **result**: PASS
- **category**: test
- **finding**: EC-1（HO 未承認残）/ EC-2（sync 漏れ）/ EC-3（verbatim 残置）/ EC-4（安全側不変条件の欠落 = plan R-4 対応）/ EC-5（語彙集二重化）/ EC-6（外部レビュー不可 = review-principles §7-ter 準拠）と境界・異常系を網羅。EC-5 の解消先パスは F-2 参照
- **evidence_ref**: —
- **impacted_files**: []

## B-1/B-2チェック（2項目）

### C1-B1B2-16: B-1確認質問
- **result**: PASS
- **category**: plan
- **finding**: pbi-input は issue #871 本文（一次ソース・取得日明記）から構造化され、曖昧点は Q1〜Q3 として C-3 確定に振られている。issue にない付加解釈（AC-9 限定）は理由付きで明示（F-3 で Human 確定を推奨）
- **evidence_ref**: —
- **impacted_files**: []

### C1-B1B2-17: B-2アプローチ比較
- **result**: PASS
- **category**: plan
- **finding**: A/B/C 3 案を AC-5/AC-9/参照影響/plugin sync/HO 接触量/コストの 6 観点で比較し、B 案採用理由（参照先パス不変・Non-goals 整合・最小変更）を明記。Metrics Evidence（B-1→B-2 gate）も実測値付きで記載され ratio < 3 を確認
- **evidence_ref**: —
- **impacted_files**: []

### C1-SEC-01: 秘密情報 非接触（#578）
- **result**: N/A
- **category**: plan
- **finding**: 文書再構成のみで `.env` / API キー / トークン / 個人パスに非接触。秘密情報を扱わない変更のため N/A
- **evidence_ref**: —
- **impacted_files**: []

### C1-SCOPE-DISC-01: 発見事項の予防的分離（#578）
- **result**: PASS
- **category**: plan
- **finding**: #866 の別トラック分離、R-2 の follow-up PR 分割、EC-3 の残置 + 採否理由 evidence 化など、スコープ外発見をその場で直さず分離する方針が一貫
- **evidence_ref**: —
- **impacted_files**: []

### C1-UI-01: UI デザインシステム準拠（#579）
- **result**: N/A
- **category**: plan
- **finding**: non-UI タスクのため N/A
- **evidence_ref**: —
- **impacted_files**: []

## Mode 判定の妥当性（追加観点）

- high-risk 判定は妥当: 定量（8〜12 ファイル / AC 10 / タスク 13）と例外ルール
  「承認境界周辺の変更 → 最低 high」（`.claude/commands/ai-loop-workflow.md` が
  HO 9 カテゴリの `.claude/commands/*.md` に実測該当）が一致。
- `lite_eligible=false` 強制・C-3 同期 Human 必須・autonomous APPROVE 不可・
  doc-light 不適用（承認境界周辺 `.md` 除外条件）は各正本ルールと整合。
- F-6（info）: critical 引き上げ余地（「ワークフロー定義変更」該当性）は C-3 で
  Human 判断を明記されたい。

## 自動修正ログ

| check_id | 修正内容 | 修正先ファイル |
|----------|---------|--------------|
| —（本レビューは新規作成のみ。レビュー対象への自動修正は行っていない） | — | — |
