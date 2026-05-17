# バージョニング安定性ポリシー（正本）

> PlanGate のバージョニングと互換性の **正本**。導入側が「このバージョンに
> 上げて安全か」を CHANGELOG だけで判断できることを目的とする。
> 関連: [#225](https://github.com/s977043/plangate/issues/225) / TASK-0087 /
> [`oss-governance.md`](../oss-governance.md) / [`CHANGELOG.md`](../../CHANGELOG.md)

## 1. 目的と背景

PlanGate は高頻度リリース（v8.1.0 -> v8.6.0 を 8 日間で 5 メジャー）を行う。
20 個の JSON Schema・11 の enforcement hook・5 つの workflow mode が相互依存
するため、1 変更の波及範囲が広い。本ポリシーは **何が breaking change か** を
定義し、**コンポーネント別の安定性レベル** を宣言し、**CHANGELOG 影響度タグ**
を標準化し、**安定版運用方針** を定める。

SemVer（`MAJOR.MINOR.PATCH`）を採用する。release-please の conventional
commits 自動採番を維持しつつ、本ポリシーで **消費側互換性の判定軸** を補う。

## 2. Breaking Change 定義

「導入側の既存運用が、無変更では壊れる変更」を **major** とする。以下は
コンポーネント別の正規化された判定表。**判定に迷う場合は安全側（より高い
severity）に倒す**。

### 2.1 JSON Schema（`schemas/*.json`）

| 変更 | severity | 理由 |
|------|----------|------|
| 必須フィールドの追加 | **major** | 既存データが invalid 化 |
| フィールド型の変更 / 制約強化（pattern, enum 削減, maxLength 短縮） | **major** | 既存データが invalid 化 |
| オプショナルフィールドの追加 | minor | 既存データは valid のまま |
| enum 値の追加（`additionalProperties:false` を維持） | minor | 既存データは valid のまま |
| フィールド削除 | **major** | 参照側が壊れる |
| description / title のみ変更 | patch | 振る舞い不変 |

> `additionalProperties:false` の Schema に enum 追加するのは minor だが、
> **その値を必須化・既定化する変更は major**（消費側が新値を扱えない）。

### 2.2 Enforcement Hook（`scripts/hooks/*` / EH-x）

| 変更 | severity | 理由 |
|------|----------|------|
| 既定挙動の変更（warning -> block、SKIP -> BLOCK 等） | **major** | 既存フローが停止し得る |
| 新規 hook の追加（既定 OFF / opt-in） | minor | 明示有効化まで影響なし |
| 新規 hook の追加（既定 ON / 強制） | **major** | 既存フローが停止し得る |
| block 条件の緩和（block -> warning） | minor | 既存フローは止まらなくなる |
| 監査ログ形式の変更（消費側パーサあり） | **major** | ログ解析が壊れる |
| メッセージ文言のみ変更 | patch | 振る舞い不変 |

### 2.3 Workflow / Mode（`docs/workflows/*` / mode 定義）

| 変更 | severity | 理由 |
|------|----------|------|
| 必須フェーズの追加 / 削除 | **major** | 完了条件が変わる |
| ゲート（C-3/C-4/V-1）の必須化 | **major** | 通過条件が変わる |
| オプショナルフェーズの追加 / 削除 | minor | 既定フローは不変 |
| mode 判定閾値の変更（同 mode に収まる範囲） | minor | 大半の PBI は不変 |
| mode 判定閾値の変更（既存 PBI の mode が上がる） | **major** | 適用フェーズが増える |
| `lite_eligible` 安全側不変条件の緩和 | **major** | ゲート強度低下（緩和不可・[`mode-classification.md`](../../.claude/rules/mode-classification.md) 調整ガイド3 で固定） |

### 2.4 CLI（`bin/plangate`）

| 変更 | severity | 理由 |
|------|----------|------|
| サブコマンドの削除 / リネーム | **major** | 既存スクリプトが壊れる |
| 引数・フラグの削除 / 意味変更 | **major** | 既存呼び出しが壊れる |
| 必須引数の追加 | **major** | 既存呼び出しが壊れる |
| 新規サブコマンド / オプショナルフラグの追加 | minor | 既存呼び出しは不変 |
| 出力フォーマット変更（消費側パーサあり: `--json` 等） | **major** | パイプライン破壊 |
| 人間向け出力文言のみ変更 | patch | 機械可読部不変 |

## 3. 安定性レベル

各コンポーネントは以下 3 段階のいずれかを宣言する。レベルは
**API 契約の強度** であり、品質・テスト網羅度とは独立。

| レベル | 契約 | 変更時の扱い |
|--------|------|-------------|
| **Stable** | breaking change は major のみ・移行ガイド必須 | 2 章を厳格適用 |
| **Beta** | breaking change を minor で許容（CHANGELOG 明記必須） | 影響度タグで通知 |
| **Experimental** | 予告なく変更可・本番依存非推奨 | 互換保証なし |

### 3.1 コンポーネント別宣言

| コンポーネント | レベル | 備考 |
|---------------|--------|------|
| JSON Schema（`schemas/*.json`） | **Stable** | 消費側がデータ検証に使用 |
| Hook enforcement model（EH-x / EHS-x の契約） | **Stable** | フロー停止に直結 |
| CLI core subcommands（`init` / `doctor` / `version` / `metrics`） | **Stable** | スクリプト依存対象 |
| Workflow / Gate モデル（C-3/C-4/V-1、5 mode） | **Stable** | 運用契約の中核 |
| Plugin mode（`plugin/plangate/`） | **Beta** | #224 で成熟化進行中 |
| Metrics v1（events / collector / reporter） | **Beta** | schema_version で additive 進化 |
| Eval framework（eval-runner / dogfooding eval） | **Beta** | 観点・項目は追加進化 |
| Dynamic Context Engine（#199） | **Experimental** | 未確定 |
| Model Profile v2（#197） | **Experimental** | 未確定 |

> レベル変更（例: Beta -> Stable 昇格）は **CHANGELOG に `[STABILITY]`
> として明記**し、昇格後は 2 章を厳格適用する。降格（Stable -> Beta）は
> 原則行わない（行う場合は major + 移行ガイド必須）。

## 4. CHANGELOG 影響度タグ

CHANGELOG.md の各エントリ先頭に、導入側影響度を表すタグを付与する。
**1 エントリに最も重いタグ 1 つ**を付ける（複数該当時は上から優先）。

| タグ | 意味 | 導入側のアクション |
|------|------|------------------|
| `[BREAKING]` | 2 章の major に該当 | 移行作業が必須。移行ガイドへのリンクを併記 |
| `[MIGRATION REQUIRED]` | 互換だが設定・データ移行が必要 | 指示に従い移行（無変更だと degrade） |
| `[STABILITY]` | 安定性レベルの変更（3.1） | 依存方針の再確認 |
| `[SAFE UPDATE]` | 後方互換・無変更で安全 | そのまま更新可 |
| `[INTERNAL]` | 消費側に影響しない内部変更 | アクション不要 |

記載例:

```markdown
### Changed
- `[BREAKING]` `schemas/plangate-event.schema.json`: `gate_id` を必須化
  （移行: [versioning-stability-policy.md](docs/ai/versioning-stability-policy.md#5-移行ガイド)）
- `[SAFE UPDATE]` `schemas/plangate-event.schema.json`: `parent_event_id`
  をオプショナル追加（既存 events は無変更で valid）
```

> release-please は conventional commits からバージョンを採番する。
> `feat!:` / `BREAKING CHANGE:` フッタを付けた commit が major を駆動する。
> 本タグは **CHANGELOG 上の人間可読な影響度通知** であり、採番ロジックとは
> 独立に常に付与する（採番が minor でも `[MIGRATION REQUIRED]` はあり得る）。

## 5. 移行ガイド

`[BREAKING]` / `[MIGRATION REQUIRED]` を含むリリースは、CHANGELOG の
当該エントリから移行手順へのリンクを必須とする。移行手順は最低限:

1. **何が変わったか**（before -> after の具体例）
2. **影響を受ける条件**（どの利用形態が壊れるか）
3. **移行手順**（コマンド / 設定変更 / データ変換）
4. **移行しない場合の挙動**（degrade or 停止）

配置: 大規模移行は `docs/migration/<version>.md`、小規模は CHANGELOG
エントリ内に直接記載してよい。

## 6. 安定版（LTS）運用方針

高頻度リリースと並行し、以下を提供する:

- **最新安定版ポインタ**: `main` の最新タグを常に「推奨導入版」とする。
  Plugin 消費側は 3.1 Stable コンポーネントについて、同一 major 内で
  互換が保たれることを期待してよい。
- **LTS ブランチ**: 当面は **採用なし**（単一 active line を維持）。
  外部採用が増え、複数 major の並行保守需要が顕在化した時点で
  `release/vN.x` ブランチを切る。判断トリガと運用は #224 Plugin 成熟化の
  バージョン同期機構（release archive 方式）と合わせて再評価する。
- **非互換の予告**: Stable コンポーネントの major 変更は、可能な限り
  1 リリース前に CHANGELOG の `### Deprecated` で予告する。

## 7. 適用と検証

- 本ポリシーは **リリース PR 作成時**（release-manager / V-4）に適用する。
- CHANGELOG 影響度タグの付与漏れは C-4 レビュー観点に含める。
- 2 章の severity 判定が分かれる場合、**安全側（高い severity）を採用**し、
  判断を CHANGELOG エントリまたは PR に明記する（トレーサビリティ）。

## 8. 関連

- [`oss-governance.md`](../oss-governance.md) — OSS 運用ガバナンス全体
- [`CHANGELOG.md`](../../CHANGELOG.md) — リリース履歴（本ポリシーのタグ適用先）
- [`issue-governance.md`](./issue-governance.md) — Issue / Label / Milestone
- [`.claude/rules/mode-classification.md`](../../.claude/rules/mode-classification.md) — 5 mode / lite_eligible
- [#224](https://github.com/s977043/plangate/issues/224) — Plugin 成熟化（バージョン同期機構）
- [#226](https://github.com/s977043/plangate/issues/226) — 段階的導入ガイド
