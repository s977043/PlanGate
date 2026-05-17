---
task_id: TASK-0082
artifact_type: review-external
schema_version: 1
status: done
phase: V-3
---

# V-3/V-4 外部レビュー — TASK-0082（TASK-0071 S3）

critical。Codex 実行（Gemini ランタイムクラッシュ→Codex 主体・前例運用）。

## 判定: Codex=critical0/major4/minor2 → fix-loop（全反映）

| # | Sev | 指摘 | 対応 |
|---|-----|------|------|
| MJ-1 | major | `SKIP_REASON="   "` 空白のみ非空通過＝必須化を実質空で回避可 | strip し空白のみを実質空として拒否（exit2 検証済）|
| MJ-2 | major | no-task ブロック内 `[ -n "$task_id" ]`＝常に false＝todo.md 経路が死に分岐 | 死に分岐除去。no-task 経路の SKIP_REASON 源は env のみと明記 |
| MJ-3 | major | `granted_at` 未来でメンテ成立＝承認前メンテ可 | maintenance 検証に `granted_at <= now` 必須（承認前メンテ禁止・検証済）|
| MJ-4 | major | skip-ack が acknowledged_by のみ・at 欠落/null 通す | acknowledged_by/acknowledged_at **両方必須**（C-3確定どおり・検証済）|
| mn-1 | minor | schema runtime 未検証 | hook はセキュリティ主条件を個別検証。runtime jq 検証は V2 候補 |
| mn-2 | minor | required 化は ruleset 依存 | ci.yml に job 追加済・required 化は ruleset(Human-owned) |

Codex 確認: P4(d)/plan.md BLOCK は maintenance 判定より前で不変。固定パス
`docs/working/_maintenance/` も env 無効化観点で妥当。

## V-4 リリース前チェック（critical 必須）: 全 PASS
- MJ-1〜4 exit code 検証（空白拒否/未来granted_at無効/ack両方必須）
- hook 78/0・CLI 64/0・dash -n OK
- plan.md BLOCK(E1)/BYPASS>メンテ(E2)/fail-closed 不変

## 出典
- Codex: /tmp/t0082-codex-v3.md（critical0/major4/minor2）
- Gemini: /tmp/t0082-gemini-v3.md（ランタイムクラッシュ）
