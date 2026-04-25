# Design Gate ルール（正本）

> 正本。Design Gate の定義・適用条件はこのファイルのみで管理する。
> 参照元: `design-gate` Skill、`/pg-think` コマンド、`completion-gate.md`

## 目的

high-risk 以上のモードで「設計なしに実装へ進む」ことを防ぐ。
設計の意思決定を明文化し、実装着手前に関係者が合意した状態を作る。

## Design Artifact 必須 8 項目

high-risk / critical モードで実装開始前に揃っていなければならない。

| 番号 | 項目 | 内容 |
|------|------|------|
| 1 | **問題定義** | 何が問題か（現状・課題・背景） |
| 2 | **目的** | なぜ解決するか（ゴール・期待効果） |
| 3 | **非目的** | スコープ外の明示（今回対応しないこと） |
| 4 | **仕様** | 何を作るか（具体的な機能要件・動作仕様） |
| 5 | **代替案** | 検討した他のアプローチ（最低 2 案） |
| 6 | **採用案** | 選んだアプローチと選択理由 |
| 7 | **リスク** | 実装・運用上のリスク（影響度・対策付き） |
| 8 | **テスト方針** | どう検証するか（テスト種別・カバー範囲） |

## 適用条件（Mode 別）

| Mode | Design Artifact | 人間承認 |
|------|----------------|---------|
| `ultra-light` | 省略可 | 不要 |
| `light` | 省略可 | 不要 |
| `standard` | 省略可 | 不要 |
| `high-risk` | **必須**（8 項目全て） | 推奨 |
| `critical` | **必須**（8 項目全て） | **必須**（explicit） |

> Mode 定義は `plugin/plangate/rules/mode-classification.md` を参照。

## ブロック条件

以下のいずれかに該当する場合、`/pg-verify` および Completion Gate への移行を **ブロック** する:

1. Mode が `high-risk` 以上で `docs/working/TASK-XXXX/design.md` が存在しない
2. `design.md` が存在するが 8 項目のいずれかが未記入（空・プレースホルダーのまま）
3. Mode が `critical` で人間の明示的承認が記録されていない

## /pg-think との連携

`/pg-think` の出力（Problem Restatement / Assumptions / Options / Recommended Approach / Risks）を
Design Artifact のドラフトとして使用できる。

実行フロー:
1. `/pg-think` を実行して論点を整理する
2. `/pg-think` の出力を `design-gate` Skill の 8 項目にマッピングする
3. `docs/working/TASK-XXXX/design.md` に保存する

## 保存先

```text
docs/working/TASK-XXXX/design.md
```

テンプレート: `docs/working/templates/design.md`（存在する場合は参照して形式を合わせる）

## 関連

- Rule: `plugin/plangate/rules/mode-classification.md`（Mode 定義・GatePolicy）
- Rule: `completion-gate.md`（Completion Gate との連携・ブロック条件の発動）
- Skill: `plugin/plangate/skills/design-gate/SKILL.md`（Design Artifact 生成手順）
- Skill: `plugin/plangate/skills/skill-policy-router/SKILL.md`（requiresUserApproval との連携）
- Command: `plugin/plangate/commands/pg-think.md`（論点整理の初段）
- Template: `docs/working/templates/design.md`（Design Artifact の保存形式）
