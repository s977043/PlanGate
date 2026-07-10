---
name: breakdown-gate
description: "PlanGate 起動前の intake 判定（mode-classification にかける前の分割要否）。実装着手前にタスク粒度を5要素で判定し、必要なら分割候補を提示する。Use when: PlanGate を起動すべきか迷う軽量タスクの判定時、PBI 化の前に分割要否を確かめたい時、「タスクを分割して」「粒度が大きすぎる」「1 PRに複数目的が入っている」。出典: growth-core task-breakdown-gate 由来（#799）。"
---

# Breakdown Gate

> **Provenance（出典・vendoring 規約）**: growth-core `task-breakdown-gate`
> （upstream: Growth-Teams-Agent@5219642 / 2026-07-03 時点）を PlanGate 向けに
> 汎用化して取り込み（#799）。上流への自動追従はしない — 上流更新の反映は
> **意図的に** diff をレビューして行う（provenance 追跡 + 意図的更新の vendoring 標準）。

実装着手**前**にタスクの粒度を判定し、粗すぎる場合は分割候補を提示する intake ゲート。growth-core `task-breakdown-gate` から蒸留。

## Iron Law

`ONE TASK = ONE PURPOSE, ONE PR-SIZED DIFF, ONE VERIFIABLE OUTCOME`

目的・差分・検証結果のどれか 1 つでも複数に見えたら分割を検討する。

## 役割分界（オーガナイザー設計 / issue #799）

| 段階 | 担当 | 本スキルとの関係 |
|---|---|---|
| 起動前 intake | **breakdown-gate（本スキル）** | 5 要素 + 粒度判定 → 分割候補提示 |
| 起動後の規模判定 | [`mode-classification.md`](../../../.claude/rules/mode-classification.md)（正本・不変） | 本スキルは **mode を決めない**（判定基準は参照のみ） |
| plan 生成後の粒度検査 | C-1 ToDo チェック「タスク粒度」（不変） | 本スキルは plan 生成**前** |
| 規模 L 以上の MVP scoping | `codex-mvp-split`（既存・`.agents/skills/codex-mvp-split/`） | 本スキルは**分割要否の判定**まで。規模 L 以上と判明したら codex-mvp-split で最小 MVP（Phase 1）分割へ |
| plan 生成後の品質スコア | `plan-quality-check`（既存・`.claude/skills/` 専用） | 5 要素は同系だがタイミングが異なる（本スキル=plan **前** / plan-quality-check=plan **後**）。チェックリストの正本は各自 — 変更時は相互参照 |

本スキルは PlanGate の Mode 判定・C-1 レビューを代替しない。あくまで「PlanGate を起動する前に、そもそも 1 タスクとして扱ってよい粒度か」を判定する前段ゲート。

## Common Rationalizations

| こう思ったら | 現実 |
|---|---|
| 「まとめて実装した方が速い」 | 大きいタスクほど迷走する |
| 「DB 変更と API 変更は一緒じゃないと意味がない」 | migration+API+test 同梱は最多の失敗パターン |
| 「テストは後で」 | 後でとは永遠のこと |
| 「Rollback は考えなくていい」 | 書けないなら設計が固まっていない証拠 |

## 手順

### Phase 1: タスク一覧の確認

判定対象のタスク一覧を取得する。`docs/working/TASK-XXXX/todo.md` が既に存在する場合はそれを読み、記載されたタスクを入力とする。存在しない場合はユーザーの依頼文から判定対象タスクを列挙する。

### Phase 2: 5 要素チェック

各タスクについて以下 5 要素を判定する。いずれかが「書けない」または「複数になる」場合は分割候補へ回す。

- □ **目的**（1 文・複数動詞なし）
- □ **変更対象**（file / module / API / DB を限定可）
- □ **完了条件**（観測可能・検証可能）
- □ **検証方法**（unit / integration / manual / lint+typecheck+build）
- □ **Rollback**（1 手順で書ける）

### Phase 3: 粒度サイズ判定

| 目安 | 判定 |
|---|---|
| 30 分〜2 時間 | 理想 |
| 半日〜1 日 | 許容 |
| 2 日以上 | 分割必須 |
| DB + API + UI + テスト同梱 | 分割必須 |
| 目的が複数（「〜して、さらに〜」） | 分割必須 |

### Phase 4: 分割候補の提示

分割が必要と判定したタスクについて、各分割候補が Iron Law（1 目的・1 PR 規模・1 検証）を満たす形で列挙し、依存順を明示する。分割後の各タスクは個別に PlanGate（[`mode-classification.md`](../../../.claude/rules/mode-classification.md)）の Mode 判定にかける導線を示す。

## 出力フォーマット

タスクごとに以下を出力する:

```markdown
### タスク: <タスク名>

| 要素 | 判定 |
|---|---|
| 目的 | OK / NG（理由） |
| 変更対象 | OK / NG（理由） |
| 完了条件 | OK / NG（理由） |
| 検証方法 | OK / NG（理由） |
| Rollback | OK / NG（理由） |

**粒度判定**: 理想 / 許容 / 分割必須

**分割要否**: 不要 / 必要

**分割候補**（分割必要の場合）:
1. <候補1>（依存: なし）
2. <候補2>（依存: 候補1完了後）
...
```

## 関連

- [`mode-classification.md`](../../../.claude/rules/mode-classification.md) — 規模判定の正本。本スキルは mode を決めない
- `codex-mvp-split`（`.agents/skills/codex-mvp-split/`） — 規模 L 以上の最小 MVP（Phase 1）選定。本スキルの分割要否判定の後段
- `plan-quality-check`（`.claude/skills/plan-quality-check/`） — plan 生成後の品質スコアリング（本スキルは plan 生成前。変更時は相互参照）
- [`subagent-driven-development`](../subagent-driven-development/SKILL.md) — 分割後の各タスクをサブエージェントへ委譲する際に使用
- [`brainstorming`](../brainstorming/SKILL.md) — 要件そのものが曖昧な場合はこちらを先に使う（本スキルは要件確定後の粒度判定）
