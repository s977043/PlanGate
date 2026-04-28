# Self-Review (C-1) — TASK-0038

> 対象: `pbi-input.md` / `plan.md` / `todo.md` / `test-cases.md`
> モード: high-risk
> 17 項目チェック

## Plan チェック（7 項目）

### C1-PLAN-01: 受入基準網羅性

**判定**: PASS

plan.md の Step 1 〜 9 が AC-1 〜 AC-9 にすべて対応。各 Step の「カバー AC」欄で明示。

| AC | 対応 Step |
|----|----------|
| AC-1 | Step 1 |
| AC-2 | Step 2 |
| AC-3 | Step 7 |
| AC-4 | Step 5 |
| AC-5 | Step 7, 8 |
| AC-6 | Step 5 |
| AC-7 | Step 1, 3 |
| AC-8 | Step 1, 4 |
| AC-9 | Step 1, 3, 4, 6 |

漏れなし。

### C1-PLAN-02: Unknowns 処理

**判定**: PASS

plan.md「Questions / Unknowns」セクションで U1 / U2 / U3 を明示し、各 Unknown に対する **本 PBI での対応方針**（保留 / 仮置き / 2 案併記）を記述している。

### C1-PLAN-03: スコープ制御

**判定**: PASS

- pbi-input.md「Out of scope」で実装系・統合系・自動化系を明示
- plan.md「Non-goals」で CLI 実装・Agent 実装・Hook 実装・並行ランタイム・既存 DSL 破壊を明示
- 触らない範囲（既存 workflows / agents / skills / bin / tests）を plan.md「触らない」に明記

### C1-PLAN-04: テスト戦略

**判定**: PASS

- Unit / Integration / Acceptance / Verification Automation の 4 層を定義
- 実装テストではなく **ドキュメント整合性検証** に限定する旨を明記
- `test-cases.md` の TC-01 〜 TC-20 + EC-01 〜 EC-05 で具体化

### C1-PLAN-05: Work Breakdown Output

**判定**: PASS

各 Step に Output / Owner / Risk / 🚩 / カバー AC が表で記載されている（Step 1 〜 9 すべて）。

### C1-PLAN-06: 依存関係

**判定**: PASS

- todo.md「依存関係」セクションで Step 間の前後関係を明示
- 並列実行可能な箇所（B-3/B-4, B-5 内部 4 ファイル）も明示
- depends_on の起点（C-3 APPROVE）も明記

### C1-PLAN-07: 動作検証自動化

**判定**: PASS

`scripts/check-orchestrator-docs.sh`（B-10 で作成）が TC-01 〜 TC-20 を自動実行する設計。手動検証は EC-03 / EC-04 のみ（人間レビュー併用）。

## ToDo チェック（5 項目）

### C1-TODO-01: タスク粒度

**判定**: PASS

各タスクが「ファイル 1 つ作成」「セクション 1 つ追加」「検証 1 種実行」レベルに分解されている。Phase B は 10 サブフェーズ（B-1 〜 B-10）で構成。

### C1-TODO-02: depends_on 設定

**判定**: PASS

todo.md「依存関係」で B-1 → B-2 〜 B-9 の順序、B-3/B-4 並列、B-5 内部並列、B-10 は B-9 後を明示。

### C1-TODO-03: チェックポイント設定

**判定**: PASS

Phase A 末尾（C-3 ゲート）、各 B-N 末尾（🚩 必須確認）、Phase D 末尾（C-4 ゲート）に明示的なゲートあり。

### C1-TODO-04: Iron Law 遵守

**判定**: PASS

todo.md「Iron Law」セクションで Phase A 〜 D 各 phase の不可侵ルールを明記:

- A: `NO EXECUTION WITHOUT REVIEWED PLAN FIRST`
- B: `NO SCOPE CHANGE WITHOUT USER APPROVAL`
- C: `NO MERGE WITHOUT VERIFICATION PASSED`
- D: `NO HANDOFF WITHOUT KNOWN-ISSUES LOGGED`

### C1-TODO-05: 完了条件

**判定**: PASS

todo.md「完了条件」で 4 条件（AC 全 PASS / スクリプト全 PASS / handoff 6 要素充足 / C-4 APPROVE）を明示。

## TestCases チェック（3 項目）

### C1-TC-01: 受入基準との紐付き

**判定**: PASS

test-cases.md「受入基準 → テストケース マッピング」表で AC-1 〜 AC-9 のすべてが少なくとも 1 つの TC に紐付く。整合性チェック（TC-18 〜 TC-20）も追加。

### C1-TC-02: Edge case 網羅

**判定**: PASS

EC-01（文字コード）/ EC-02（リンク実在）/ EC-03（用語不一致）/ EC-04（Status 誤記）/ EC-05（forbidden_files 実害）の 5 種を定義。

### C1-TC-03: 自動化可否

**判定**: PASS

TC-01 〜 TC-20 はすべて shell + grep で自動化可能、EC-01 〜 EC-05 のうち EC-03 / EC-04 のみ半自動（人間レビュー併用）と明示。

## 総合判定

**全 17 項目 PASS**

WARN / FAIL なし。C-3 ゲート提出可。

## 指摘事項（次フェーズで留意すべき点）

| ID | 種別 | 内容 |
|----|------|------|
| N-1 | Note | 既存 v7 hybrid 5 Agent との責務境界（Step 1 / TC-02）が exec phase 最大の難所。本 PBI 範囲では「責務境界表」を作成するが、実装での agent 重複は別 PBI で再評価が必要 |
| N-2 | Note | Issue #109 受入基準の「`plangate decompose` が仕様化されている」の `<引数>` 部分が原文で省略されており、RFC で `plangate decompose <PBI-id>` として推測 |
| N-3 | Note | TC-19 の用語統一チェックは grep ベースのため、構造的逸脱（例: 同義語使用）は検出できない。EC-03 で人間レビュー併用 |
| N-4 | Risk | RFC を Draft で確定すると、後続実装 PBI で仕様が変わる可能性あり。本 PBI handoff.md の「V2 候補」で明記する |

## C-3 ゲート判定材料サマリ

人間レビュアー向けの判断ポイント:

1. **スコープが純粋に仕様策定のみで実装を含まないか** → ✅ Out of scope に実装系すべて記載
2. **既存 v7 hybrid を破壊しないか** → ✅ Constraints で「置換せず内側で拡張」を明示
3. **AC 9 項目すべてに対応文書が割り当てられているか** → ✅ C1-PLAN-01 マッピング表参照
4. **テストが妥当か（実装テストではなくドキュメント整合性で OK か）** → ✅ TC 設計の意図を Testing Strategy で明示
5. **モード判定（high-risk）は妥当か** → ✅ 変更ファイル数 13 + アーキ仕様策定で high-risk 適合（実装なしのため検証コストは軽め）

C-3 三値判断の推奨:

- **APPROVE**: 上記 5 点に異論なしの場合 → exec へ進む
- **CONDITIONAL**: スコープ縮小（例: RFC を別 PBI に切り出す）等の修正指示あり → plan.md 修正後 C-1 簡易再実行
- **REJECT**: 仕様策定アプローチ自体の変更要求あり → pbi-input.md 再設計
