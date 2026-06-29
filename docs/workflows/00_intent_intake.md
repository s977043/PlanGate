# WF-00 Intent Intake（advisory・既定運用は補助）

> **advisory のみ**。本フローは強制ゲートではなく、依頼受領直後に Intent / Mode / GatePolicy を整理する入口。強制化（機械 gate）は別 PBI。既存 WF-01〜05 の手順・ゲートは変更しない（**Rule 1**: Workflow は順序と完了条件だけ）。

## 目的

ユーザー依頼を受け取った直後に、意図（Intent）と規模（Mode）と必要ゲート（GatePolicy）を構造化し、plan 着手（ai-dev-plan）前段の見通しを advisory に与える。

## 入力

- ユーザー依頼文（または直前会話コンテキスト）

## advisory フロー

```text
依頼文
  → intent-classifier        （Intent 7 分類）
  → Mode 判定                 （mode-classification.md 正本・lite_eligible 含む）
  → skill-policy-router       （確定 Mode/lite_eligible → GatePolicy 写像）
  → ai-dev-plan 前段          （plan.md 着手）
```

| ステップ | Skill / 正本 | 出力 |
|---------|-------------|------|
| 1. Intent 分類 | [`intent-classifier`](../../.claude/skills/intent-classifier/SKILL.md) | intent + confidence |
| 2. Mode 判定 | [`mode-classification.md`](../../.claude/rules/mode-classification.md)（**正本**）| mode + lite_eligible |
| 3. GatePolicy 写像 | [`skill-policy-router`](../../.claude/skills/skill-policy-router/SKILL.md) | requiredSkills / gate 要件 |
| 4. plan 着手 | ai-dev-plan | plan.md |

## 責務分界（重複定義しない）

- **Mode の判定基準・`lite_eligible`** は `mode-classification.md` が単一正本。intent-classifier も skill-policy-router も Mode 自体は判定しない。
- intent-classifier は Intent 分類のみ、skill-policy-router は確定 Mode → GatePolicy 写像のみ。

## 完了条件

advisory のため強制完了条件なし。Intent / Mode / GatePolicy の見通しが得られたら WF-01（Context Bootstrap）へ。

## exploratory 判定時の WF-07 推奨

intent-classifier が `exploratory` を返した場合、advisory として以下を提示する:

```
Intent: exploratory が検出されました。
→ WF-07 Exploratory Debug（opt-in）の使用を推奨します。
   docs/workflows/07_exploratory_debug.md を参照し、
   pbi-input.md に `exploratory: true` を追加してください。
   通常の WF-01〜05 に進む場合はそのまま続行できます。
```

WF-07 への移行は強制ではなく、人間が明示的に opt-in した場合のみ発動する（既定 OFF 原則不変）。

## 非強制

本フローは助言であり、既存 WF-01〜05 の phase・ゲート・承認境界を一切変更しない。強制化は将来 PBI で検討。
