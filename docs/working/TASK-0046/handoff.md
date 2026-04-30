---
task_id: TASK-0046
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-05-01
author: qa-reviewer
v1_release: ""
related_issue: 155
---

# Handoff: TASK-0046 / Issue #155 — v8.3 Baseline 測定

## メタ情報

```yaml
task: TASK-0046
related_issue: https://github.com/s977043/plangate/issues/155
author: qa-reviewer
issued_at: 2026-05-01
v1_release: <PR マージ後に SHA を記入>
```

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 |
|---------|------|------|
| AC-1: `eval-comparison-template.md` に v8.3 baseline 行が記入されている | PASS | `grep -E '^\| v8\.3' docs/ai/eval-comparison-template.md` で 1 件ヒット |
| AC-2: 8 観点すべての測定値が記入されている | PASS | accuracy / latency / tool calls / format adherence / scope discipline / verification honesty + 補足観点（approval / stop / tool overuse）= 9 列、空セルなし（latency / tool calls は `n/a` を明示）|
| AC-3: 測定根拠が記録されている | PASS | `docs/working/TASK-0046/evidence/baseline-data.md` に 5 PBI × 8 観点の生データ |
| AC-4: 集計手順が `docs/ai/eval-baseline-procedure.md` に明文化されている | PASS | 新規作成、Step 1〜10 の 7 セクション構成 |
| AC-5: schema 準拠率 ≥ 95% | PASS | 5 / 5 = **100%**（handoff 必須 6 要素全 PBI で揃う、release blocker 該当外）|

**総合**: **5 / 5 基準 PASS**
**FAIL / WARN の扱い**: なし

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| latency / tool calls が n/a（session log 未保存）| minor | accepted | Yes（#156 で自動取得）|
| baseline は 1 EPIC（PBI-116）のみで、複数 EPIC 横断比較は未実施 | info | accepted | No（最初の baseline として十分）|
| eval-cases/*.md の Detection 手順と本 procedure の同期が手動 | minor | accepted | Yes（#156 / #158 で機械化）|

**Critical 課題**: なし

## 3. V2 候補

| V2 候補 | 理由 | 優先度 | 関連 Issue |
|--------|------|--------|---------|
| #156 eval runner 実装後の latency / tool calls 再取得 | session log 自動集計が前提 | High | #156 |
| 全 PBI（PBI-116 配下以外）への baseline 拡張 | 統計的有意性向上 | Medium | — |
| baseline の継続更新基盤（モデル変更ごとに自動更新）| #156 + #158 完了後 | Medium | #156 / #158 |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| 5 PBI 手動集計 | 全 PBI（17 PR 分）網羅 | 手動コストと有意性のトレードオフ、5 件で Phase 1〜4 を網羅できる |
| latency / tool calls を `n/a` 記載 | 推定値で埋める | verification honesty 観点で誤った数値より honest な n/a を採用 |
| baseline は EPIC 単位（PBI-116）| 全 working PBI 平均 | EPIC 内 4 phase で実測の幅を持たせ、後続の比較対象として明確 |
| procedure を別ファイル化 | template に直接記述 | 再利用性確保、template は記入結果に専念 |

## 5. 引き継ぎ文書

### 概要

PlanGate v8.3 の eval framework に対し、PBI-116 EPIC 完了済 5 子 PBI から **初回 baseline** を取得した。`eval-comparison-template.md` に v8.3 baseline 行を 1 行追記し、集計手順を `eval-baseline-procedure.md` に Step 1〜10 で文書化。`docs/working/TASK-0046/evidence/baseline-data.md` に 5 PBI × 8 観点の生データを保存。

主な数値:
- AC coverage: **35/35 = 100%**
- Approval discipline: 5/5 PASS
- Format adherence: **5/5 = 100%**（release blocker 該当外、≥ 95%）
- Scope / Verification honesty / Stop / Tool overuse: 全て PASS
- Latency / Cost: n/a（#156 eval runner 実装後に再取得）

### 触れないでほしいファイル

- `docs/working/TASK-0046/evidence/baseline-data.md`: baseline の正本データ、後続の比較対象。書き換える場合は新 baseline として別行追加（上書き禁止）
- `docs/ai/eval-comparison-template.md` の v8.3 baseline 行: モデル変更時の比較基準

### 次に手を入れるなら

- #156 eval runner 完成後、latency / tool calls の実測値で baseline を補強（n/a → 数値に置換）
- 新 EPIC 完了時、本手順で次の比較行を追加
- アンチパターン: baseline 行を上書き編集（履歴喪失）

### 参照リンク

- Issue: https://github.com/s977043/plangate/issues/155
- 親 retrospective: `docs/working/retrospective-2026-04-30.md` § Try T-1
- plan: `docs/working/TASK-0046/plan.md`
- 集計手順: `docs/ai/eval-baseline-procedure.md`
- 生データ: `docs/working/TASK-0046/evidence/baseline-data.md`
- baseline 行: `docs/ai/eval-comparison-template.md`

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| Doc verification | 5 | 5 | 0 / 0 | TC-1〜TC-5 |
| Schema 準拠率（baseline） | 5 | 5 | 0 / 0 | handoff × 5 PBI |

検証コマンド:

```sh
# TC-1: baseline 行の存在
grep -E '^\| v8\.3' docs/ai/eval-comparison-template.md

# TC-3: evidence
test -f docs/working/TASK-0046/evidence/baseline-data.md

# TC-4: procedure file + sections
test -f docs/ai/eval-baseline-procedure.md
grep -cE '^## ' docs/ai/eval-baseline-procedure.md  # ≥ 5 期待

# TC-5: schema 準拠率
for t in TASK-0039 TASK-0040 TASK-0041 TASK-0042 TASK-0044; do
  grep -cE "^## [1-6]\." "docs/working/$t/handoff.md"
done  # 全 5 件で "6" → 100% PASS
```

実行結果: **全 TC PASS**

## todo.md

実行中に [`todo.md`](./todo.md) は更新せずこの handoff に統合した（standard mode 簡略化）。
