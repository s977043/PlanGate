# Lightweight Plan Quality Checks（正本）

> 計画品質を実装前に軽量に構造化する **正本**。重い Gate / Agent
> orchestration / PR review / QA automation を導入せず、手動実行可能な
> 補助 Check として計画の不足・リスク・前提・完了条件・次アクションを
> 抽出する。
> 関連: [#213](https://github.com/s977043/plangate/issues/213)（PBI-PQ-001）/
> [#53](https://github.com/s977043/plangate/issues/53) / TASK-0091 /
> [`harness-improvement-roadmap.md`](./harness-improvement-roadmap.md) §10 /
> [`.claude/skills/plan-quality-check/SKILL.md`](../../.claude/skills/plan-quality-check/SKILL.md) /
> [`../../schemas/plan-quality-check.schema.json`](../../schemas/plan-quality-check.schema.json)

## 1. 目的と位置づけ

PlanGate の初期価値は重い自動実行基盤ではなく **計画品質を上げること**に
ある。`gstack` 的な AI 開発ワークフロー（slash command / agent
orchestration / PR review / QA automation / browser daemon）を直接移植
すると重くなる。本機能は **`gstack` を参考思想に留め直接移植しない**方針で、
軽量な Plan Quality Layer のみを定義する。

> 本 Check の判定は **助言（advisory）**であり、C-3/C-4 等の人間承認・
> ゲート判定を**代替しない**（[review-principles.md](../../.claude/rules/review-principles.md)
> の承認境界・[responsibility-classes.md](../../.claude/rules/responsibility-classes.md)
> の Human-owned 境界は不変）。

## 2. Check 種別と責務

| Check | 責務（何を確認するか） | 主出力フィールド |
|-------|----------------------|----------------|
| `plan_check` | 計画の **目的・対象・成功条件・スコープ** が明確か | `score` / `missing_items` / `summary` |
| `risk_check` | **失敗要因・依存関係・未決事項・暗黙の前提** が洗い出されているか | `risks` / `assumptions` / `next_actions` |
| `done_check` | **完了条件・検証方法・リリース後確認** が定義されているか | `done_criteria` / `validation_notes` |
| `combined` | 上記 3 種を統合した 1 結果 | 全フィールド |

各 Check は単独でも `combined` でも実行できる。

## 3. 出力構造

出力は [`schemas/plan-quality-check.schema.json`](../../schemas/plan-quality-check.schema.json)
準拠の JSON。自由文サマリ（`summary`）も持つが、機械処理対象は JSON とする
（AI 出力を自由文だけにしない＝ AC4）。

| フィールド | 内容 |
|-----------|------|
| `check_type` | plan_check / risk_check / done_check / combined |
| `score` | Plan Health Score（0-100、§4）|
| `decision` | ready / needs_clarification / insufficient（助言） |
| `summary` | 1 行サマリ |
| `score_breakdown` | Score 最小内訳（§4、任意） |
| `missing_items[]` | `field` / `severity`(critical/major/minor/info) / `message` |
| `risks[]` | `severity`(high/medium/low) / `title` / `recommendation` |
| `assumptions[]` | `title` / `confidence`(high/medium/low) / `validation_method` |
| `done_criteria[]` | 完了条件の配列 |
| `validation_notes` | 検証方法・リリース後確認のメモ |
| `next_actions[]` | `title` / `type`(clarify/investigate/decide/implement/verify) |

### 出力例

```json
{
  "check_type": "combined",
  "score": 76,
  "decision": "needs_clarification",
  "summary": "目的は明確だが、成功指標と完了条件が不足している。",
  "missing_items": [
    { "field": "success_metric", "severity": "major",
      "message": "成功指標が測定可能ではない。" }
  ],
  "risks": [
    { "severity": "high", "title": "通知対象条件が曖昧",
      "recommendation": "何日前から通知対象にするか定義する。" }
  ],
  "assumptions": [
    { "title": "契約更新日が既存DBに存在する", "confidence": "medium",
      "validation_method": "DBスキーマを確認する。" }
  ],
  "done_criteria": [
    "通知対象ユーザーに契約更新通知が届く",
    "通知対象が0件でもエラーにならない"
  ],
  "next_actions": [ { "title": "成功指標を定義する", "type": "clarify" } ]
}
```

## 4. Plan Health Score（最小内訳）

`score`（0-100）は以下の最小 5 軸の平均（各 0-100、等加重）。実装側で
重みを調整してよいが、軸は固定（二重定義防止）:

| 軸 | 評価対象 |
|----|---------|
| `goal_clarity` | 目的・狙いが一意に読めるか |
| `scope_defined` | In/Out スコープが切られているか |
| `success_metric` | 成功条件が測定可能か |
| `risks_identified` | リスク・依存・前提が洗い出されているか |
| `done_criteria_defined` | 完了条件・検証方法が定義されているか |

### decision 閾値（助言）

| score | decision | 意味 |
|-------|----------|------|
| 85-100 | `ready` | 計画品質は十分（人間最終判断は別） |
| 60-84 | `needs_clarification` | 重要な不足あり。`next_actions` を解消推奨 |
| 0-59 | `insufficient` | 計画として未成熟。再構造化推奨 |

> 判定不能 / 根拠不足のときは **安全側**（より低い score・
> `needs_clarification` 以下）に倒す。

## 5. 実行と保存

- **手動実行**: `bin/plangate plan-check <TASK-XXXX> --init` で
  `docs/working/TASK-XXXX/plan-quality-check.json` の雛形を生成し、
  AI / 人間が内容を埋める。`--validate` でスキーマ検証する。
  重い Gate / Agent を起動しない（AC: heavy 非依存・手動実行可能）。
- **Plan 状態としての保存**: 結果は
  `docs/working/TASK-XXXX/plan-quality-check.json` に保存し、計画の
  状態の一部として扱う（[working-context.md](../../.claude/rules/working-context.md)
  の TASK 作業コンテキストに同居）。`status.md` / `current-state.md`
  から参照してよい（任意）。
- 将来、Gate / Review / QA / Release 判定へ拡張する **土台**とする
  （本 PBI は定義と軽量実行まで。heavy 拡張は別 PBI・Non-goal）。

## 6. Non-goals（本 PBI で実装しない）

- `gstack` の slash command / workflow をそのまま取り込むこと
- browser daemon / ngrok / pair-agent / PR review automation /
  QA automation（Playwright）/ Release Gate / Security Gate の実装
- AI 判定を人間承認の代替にすること（承認境界不変）

## 7. 関連

- [`harness-improvement-roadmap.md`](./harness-improvement-roadmap.md) §10 — Lightweight Plan Quality Checks
- [`.claude/skills/plan-quality-check/SKILL.md`](../../.claude/skills/plan-quality-check/SKILL.md) — 再利用 Skill 定義
- [`schemas/plan-quality-check.schema.json`](../../schemas/plan-quality-check.schema.json) — 出力スキーマ
- [`.claude/rules/review-principles.md`](../../.claude/rules/review-principles.md) — 承認境界（不変）
- [`.claude/rules/responsibility-classes.md`](../../.claude/rules/responsibility-classes.md) — Human-owned 境界
