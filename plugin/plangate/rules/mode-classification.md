# モード分類基準（5段階）

> 正本。判定基準の調整はこのファイルのみで行う。
> 参照元: `ai-dev-workflow.md`（plan サブコマンド）、`workflow-conductor.md`（役割7）
> 関連 Skill: `intent-classifier`（依頼文 → Intent 判定）、`skill-policy-router`（Intent + Mode → GatePolicy）

## 5段階モード定義

| モード | ラベル | 対象例 |
|--------|-------|-------|
| **超低** | `ultra-light` | typo修正、設定値変更、コメント修正、README更新 |
| **低** | `light` | バグ修正、1ファイルの小修正、設定追加 |
| **中** | `standard` | 小規模機能追加、数ファイルの変更、テンプレート追加 |
| **高** | `high-risk` | 機能追加、複数ファイル・複数レイヤーの変更 |
| **超高** | `critical` | アーキテクチャ変更、横断的リファクタリング、ワークフロー定義変更 |

## 判定基準

### 定量基準

| 判定軸 | 超低 | 低 | 中 | 高 | 超高 |
|--------|------|---|---|---|------|
| 変更ファイル数 | 1 | 1-2 | 3-5 | 6-15 | 16+ |
| 受入基準数 | 0-1 | 1-2 | 3-5 | 6-10 | 11+ |
| タスク数（見込み） | 1-2 | 2-4 | 5-10 | 11-20 | 21+ |

### 定性基準

| 判定軸 | 超低 | 低 | 中 | 高 | 超高 |
|--------|------|---|---|---|------|
| 変更種別 | typo/設定/コメント | バグ修正/設定追加 | 小機能追加 | 機能追加/リファクタ | アーキ変更/横断 |
| リスク | なし | 低 | 中 | 高 | 極高 |
| 影響範囲 | 当該ファイルのみ | 当該機能のみ | 関連機能に波及 | 複数レイヤーに波及 | システム全体 |
| ロールバック | 不要 | 容易 | 可能 | 計画的に必要 | 段階的ロールバック必須 |

> **注**: 「高」のラベルは `high-risk`（旧: `full`）。`full` は非推奨となり `high-risk` を使用すること。

### 判定ロジック

```text
1. 定量基準の各軸でモードを判定（最大値を採用）
2. 定性基準の各軸でモードを判定（最大値を採用）
3. 定量と定性の高い方を最終モードとする
4. ユーザーがオーバーライドした場合はそちらを優先
```

**例外ルール**:
- セキュリティ関連の変更 → 最低でも「中」
- データベーススキーマ変更 → 最低でも「高」
- 公開 API の破壊的変更 → 最低でも「超高」

## フェーズ適用マトリクス

各モードで実行するフェーズを定義する。○ = 実行、△ = 簡易版、- = スキップ。

| フェーズ | 超低 | 低 | 中 | 高 | 超高 |
|---------|------|---|---|---|------|
| **brainstorm** | - | - | △（任意） | ○ | ○ |
| **plan 生成** | - | △（簡易plan） | ○ | ○ | ○（詳細plan） |
| **C-1 セルフレビュー** | - | △（Plan 7項目のみ） | ○（17項目） | ○（17項目） | ○（17項目） |
| **C-2 外部AIレビュー** | - | - | - | ○ | ○（複数観点） |
| **C-3 人間レビュー** | - | △（差分確認） | ○ | ○ | ○（詳細レビュー） |
| **exec (TDD)** | 直接実装 | TDD | TDD | TDD + 並列 | TDD + 並列 + 段階的 |
| **L-0 リンター** | ○ | ○ | ○ | ○ | ○ |
| **V-1 受け入れ検査** | △（簡易確認） | ○ | ○ | ○ | ○ |
| **V-2 コード最適化** | - | - | - | ○ | ○ |
| **V-3 外部レビュー** | - | - | ○ | ○ | ○ |
| **V-4 リリース前チェック** | - | - | - | - | ○ |
| **PR 作成** | ○ | ○ | ○ | ○ | ○ |
| **C-4 PRレビュー** | ○ | ○ | ○ | ○ | ○（複数レビュアー推奨） |

> 列ヘッダー（超低〜超高）は左から `ultra-light` / `light` / `standard` / `high-risk` / `critical` に対応する。

### 簡易版の定義

| フェーズ | 通常版 | 簡易版 |
|---------|--------|--------|
| plan 生成 | Goal + Constraints + Work Breakdown + Testing Strategy + Risks | Goal + 変更内容 + 確認方法 |
| C-1 | 17項目チェック | Plan 7項目（C1-PLAN-01〜07）のみ |
| C-3 | 全ドキュメントレビュー | 差分のみ確認（plan 不要なため） |
| V-1 | test-cases.md 全件突合 | 変更箇所の動作確認のみ |

## plan.md での記載方法

```markdown
## Mode判定

**モード**: {ultra-light | light | standard | high-risk | critical}

**判定根拠**:
- 変更ファイル数: {N} → {モード}
- 受入基準数: {N} → {モード}
- 変更種別: {種別} → {モード}
- リスク: {レベル} → {モード}
- **最終判定**: {モード}（{オーバーライドの場合はその理由}）
```

## Gate 適用マトリクス

各モードで適用する Gate を定義する。○ = 必須、△ = 推奨/任意、- = スキップ。

| Gate | ultra-light | light | standard | high-risk | critical |
|------|------------|-------|----------|-----------|----------|
| **Design Gate** | - | - | - | ○ | ○ |
| **TDD Gate** | - | - | △ | ○ | ○ |
| **Review Gate** | - | - | △（/pg-check 推奨） | ○ | ○ |
| **Completion Gate** | - | △ | ○ | ○ | ○ |

### Gate 詳細

| Gate | ルール正本 | Skill | コマンド |
|------|-----------|-------|---------|
| Design Gate | `plugin/plangate/rules/design-gate.md` | `design-gate` | `/pg-think`（初段） |
| TDD Gate | `plugin/plangate/commands/pg-tdd.md` | — | `/pg-tdd` |
| Review Gate | `plugin/plangate/rules/review-gate.md` | `review-gate` | `/pg-check` |
| Completion Gate | `plugin/plangate/rules/completion-gate.md` | — | `/pg-verify` |

> 各 Gate の詳細条件は各ルールファイルを参照。Completion Gate が全 Gate の通過を一元管理する。

## 調整ガイド

このファイルの判定基準を調整する際のルール:

1. **定量基準の閾値変更**: 各軸の数値を変更可能。運用実績に基づき調整
2. **例外ルールの追加/変更**: プロジェクト固有のリスクに応じて追加可能
3. **フェーズ適用の変更**: ○/△/- の割当を変更可能。ただし以下は固定:
   - L-0（リンター）は全モードで必須
   - PR作成・C-4 は全モードで必須
4. **新モードの追加**: 5段階で不足する場合は中間モードを定義可能（非推奨）

## GatePolicy 定義

Mode ごとに必要な Skill とゲート要件（GatePolicy）を定義する。
`skill-policy-router` Skill がこの定義に基づいて GatePolicy を返す。

### GatePolicy フィールド

| フィールド | 型 | 説明 |
|-----------|---|------|
| `requiredSkills` | string[] | 必須実行 Skill の識別子リスト |
| `optionalSkills` | string[] | 推奨 Skill の識別子リスト |
| `requiresUserApproval` | boolean | 人間の明示的承認が必要か |
| `requiresEvidence` | boolean | 実行根拠（evidence）の保存が必要か |
| `requiresFailingTestFirst` | boolean | failing test を先に書く TDD が必要か |
| `requiresWorktree` | boolean | 独立ブランチ（worktree）での作業が必要か |

### Skill 識別子

| 識別子 | 対応する行動 |
|--------|------------|
| `think` | 設計・計画の立案（plan.md 生成） |
| `hunt` | コードベース調査（Grep / Glob 探索） |
| `check` | セルフレビュー（self-review Skill） |
| `tdd` | テスト駆動開発（failing test first） |
| `verify` | 受け入れ検査（test-cases.md 突合） |
| `worktree` | 独立ブランチでの作業 |
| `review` | 外部レビュー（human / external AI） |
| `approval` | 人間の明示的承認取得 |

### Mode 別 GatePolicy 一覧

| Mode | requiredSkills | optionalSkills | approval | evidence | TDD | worktree |
|------|---------------|----------------|---------|---------|-----|---------|
| `ultra-light` | verify | check | false | false | false | false |
| `light` | check, verify | think, hunt | false | false | false | false |
| `standard` | think, check, verify | hunt, tdd | recommended | true | conditional | false |
| `high-risk` | think, approval, worktree, tdd, check, review, verify | — | **true** | true | **true** | **true** |
| `critical` | think, approval, worktree, tdd, review, verify | — | **true** | true | **true** | **true** |

**`critical` の追加要件**:

- ロールバック計画の策定
- セキュリティレビューを含む多角的レビュー
- 段階的デプロイ計画の策定

### 参照

- Skill: `plugin/plangate/skills/intent-classifier/SKILL.md`
- Skill: `plugin/plangate/skills/skill-policy-router/SKILL.md`
