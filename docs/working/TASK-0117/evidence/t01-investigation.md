# TASK-0117 T-01 investigation (read-only)

> 実施: 2026-05-27 / Mode: read-only / C-3 前可
> 目的: `.agents/skills/ai-dev-plan/SKILL.md` 構造把握 + 追記方針確定 + 規模メトリクス検証

## 1. SKILL.md 構造 (`.agents/skills/ai-dev-plan/SKILL.md`、57 行)

```
L1-4    frontmatter (name / description)
L6      # AI-Driven Plan (PlanGate / Codex 共用)
L10-19  ## Read First (7 項目)
L21-27  ## Output (5 ファイル)
L29-48  ## Rules
         ├ ### フロー (B-1/B-2/B-3)
         ├ ### todo.md 規約
         ├ ### test-cases.md 規約
         └ ### 監査 (decision-log.jsonl)
L50-53  ## CLI 呼び出し
L55-57  ## 次フェーズへ
```

設計方針: **「読む順序と入出力規約のみを担う」** (skill 本文 L8)、実行ロジックは `scripts/ai-dev-workflow` / `bin/plangate` CLI 側に集約。

## 2. 既存 mode-classification 参照 (本 PBI との重複定義回避)

| Line | 内容 |
|------|------|
| L15 | Read First L4: `.claude/rules/mode-classification.md` (5 段階 mode + lite_eligible 派生属性の正本) |
| L33 | Rules フロー: 「Mode判定 / lite_eligible 等 は ... `.claude/rules/mode-classification.md` を **正本** とする。skill は順序のみを示す」 |
| L48 | 監査: 「mode が `critical` で `lite_eligible=true` の場合は人間の C-3 明示承認記録が前提 (AC-11)」 |

→ **本 PBI の「事前メトリクス検証」も同パターン**: skill には「step」と「コマンド例」「判定基準」を記載、詳細運用は `docs/ai/plan-metrics-verification.md` を正本として参照。

## 3. B-1/B-2/B-3 フロー (L34)

```
B-1 (最大 3 問の確認質問)
  ↓
B-2 (2〜3 案の trade-off 比較)
  ↓
B-3 (3 ファイル同時生成: plan / todo / test-cases)
```

→ **本 PBI の「事前メトリクス検証」は B-1 と B-2 の間に挿入**:
```
B-1 (確認質問)
  ↓
**事前メトリクス検証** (実数取得 + 判定) ← 新規 mandatory gate
  ↓
B-2 (trade-off 比較)
```

## 4. PocketEitan PR #371 参照確認

```bash
grep -rnE "PocketEitan|事前メトリクス" .agents/ docs/ai/
→ 0 件
```

PocketEitan PR #371 への参照は PlanGate repo 内に存在しない (外部リポジトリ実装)。本 PBI で初導入。実装はリポジトリ間横断のため、本 PBI doc 内に PocketEitan 実例 (1697 file / 17 group) を **literal text として記録** する形 (リンクではなく)。

## 5. 既存 docs/ai/ pattern (config 形式)

`docs/ai/` 配下に 20+ doc あり、いずれも:
- `# Title`
- `> 関連 link`
- 構造化セクション (`## 目的`, `## 規約`, `## 例` 等)
- 既存 file: `metrics.md`, `metrics-privacy.md`, `plan-quality-checks.md` 等が類似系

→ `docs/ai/plan-metrics-verification.md` も同 pattern で記述。

## 6. CLI 呼び出し (L51)

- `./scripts/ai-dev-workflow TASK-XXXX plan` — 実コマンド
- `bin/plangate validate TASK-XXXX` — plan_hash 整合機械検証

→ **「事前メトリクス検証」を CLI 化する場合**は別 PBI (本 PBI は skill / docs / test のみ、CLI 化は scope 外で V2 候補)。

## 7. 規模メトリクス検証 (#351 自己適用)

| 項目 | plan 見積もり | 実数 (T-01 確認) | 比率 |
|------|--------------|----------------|------|
| 変更ファイル数 | 4-5 | SKILL.md (追記) + plan-metrics-verification.md (新規) + ta-19 (新規) + handoff = **4 file** | **0.8〜1.0 倍** |
| 受入基準数 | 8 (AC-8 追加後) | 8 | 1.0 倍 |
| Mode | standard | standard 維持で妥当 (R-002 反映済) | — |

TASK-0117 判定基準「1〜3 倍」→ 採用、Mode 降格不要 (1.0 倍未満は降格候補だが standard 維持で問題なし)。**本 PBI を本 PBI の手法で自己評価 = 妥当な mode** であることを確認。

## 8. T-01 結論

### 確定事項

1. SKILL.md は「読む順序と入出力規約のみ」の薄い skill (57 行)
2. mode-classification.md は **正本参照のみ** で skill には mode 判定ロジックを書かない pattern
3. **本 PBI も同じ pattern**: skill には「事前メトリクス検証 step + 簡易説明」のみ、判定基準数値・コマンド例詳細・PocketEitan 実例は `docs/ai/plan-metrics-verification.md` を正本として参照
4. 「事前メトリクス検証」は **B-1 → B-2 の間の mandatory gate** に挿入
5. PocketEitan PR #371 は外部参照のため literal text で記録
6. CLI 化は scope 外 (V2 候補)

### T-02 追記方針 (skill 本体)

`.agents/skills/ai-dev-plan/SKILL.md` の `### フロー` セクション (L33-34) に以下を追加:

```markdown
- **事前メトリクス検証 (B-1 と B-2 の間の mandatory gate)**: 「全部 / 全件 / 残り N 件」系の対象は、`grep -rln <symbol> | wc -l` / `find . -name <pattern> | wc -l` 等で **実数を取得**。判定基準と PocketEitan 実例は [`docs/ai/plan-metrics-verification.md`](../../../docs/ai/plan-metrics-verification.md) を **正本** とする。判定:
  - 実数 / 見積もり ≥ 3 → スコープ縮小 or 別タスクへ切替
  - 1〜3 倍 → 採用、plan の Risks に記録
  - < 1 → 採用、Mode を 1 段下げる候補
- plan.md には **`## Metrics Evidence` 欄** を必須化 (実数 / 見積もり / ratio / 判定の出力契約 / AC-8 / R-003)
```

### T-03 doc (`docs/ai/plan-metrics-verification.md` 新規) 構成

- `# Plan Metrics Verification (#351 / TASK-0117)`
- `> 正本: 本 doc / skill は参照のみ`
- `## 目的`
- `## 判定基準` (3 倍 / 1〜3 倍 / < 1 倍)
- `## 検証コマンド例` (grep / wc / find / cloc 等)
- `## plan.md template (`## Metrics Evidence` 欄)`
- `## 既存実例` (PocketEitan 抽象語イラスト 17 グループ / 1697 file + 本セッション TASK-0111 14 file = 1.0-1.4 倍 で standard 維持の自己適用例)
- `## TASK-0112 との境界` (本 PBI = plan 前メトリクス検証 / TASK-0112 = mode 自動補正の例外ルール)

### 残作業 (c3.json APPROVED 後)

T-02 (SKILL.md 追記、`.agents/skills/` は Hardening Override 対象外、maintenance 不要) → T-03 (docs/ai/plan-metrics-verification.md) → T-04 (tests/extras/ta-19-plan-metrics-verification.sh) → T-05 (handoff + V-1)。

## 9. AC-1..AC-8 充足見込み (T-02 以降で確認)

| AC | 充足方法 | 確度 |
|----|---------|------|
| AC-1 skill にセクション追加 | T-02 で `### フロー` に挿入 | High |
| AC-2 検証コマンド例 | T-02 (skill) + T-03 (doc) で記述 | High |
| AC-3 判定基準数値 | T-02 + T-03 で明示 | High |
| AC-4 PocketEitan 実例 ≥ 1 | T-03 で literal 記載 | High |
| AC-5 TASK-0112 相互参照 | T-03 で境界明示 | High |
| AC-6 ta-19 機械検証 | T-04 で grep 実装 | High |
| AC-7 markdownlint + regression | T-04 + CI | High |
| AC-8 plan.md `## Metrics Evidence` 欄 | T-03 template に含める + ta-19 で検証 | High |
