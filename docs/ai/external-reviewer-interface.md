# 外部レビューア標準インターフェース（正本）

> PlanGate の C-2 / V-3 外部レビューア接続の **正本**。river-reviewer を
> 第一の参照実装とし、任意の外部レビューアを同一 IF で接続できる。
> 関連: [#227](https://github.com/s977043/plangate/issues/227) / TASK-0089 /
> [`.claude/rules/review-principles.md`](../../.claude/rules/review-principles.md) §7-bis /
> [`schemas/plangate-reviewers.schema.json`](../../schemas/plangate-reviewers.schema.json) /
> [`schemas/review-external.schema.json`](../../schemas/review-external.schema.json) /
> river-reviewer 側: [s977043/river-reviewer#802](https://github.com/s977043/river-reviewer/issues/802)

## 1. 目的

PlanGate の C-2（plan ゲート外部レビュー）/ V-3（実装後外部モデルレビュー）は
「外部レビューアを呼ぶ」設計（`PLANGATE_EXTERNAL_REVIEWER` 環境変数 +
`bin/plangate review <TASK> --phase c2|v3`）を持つ。本 IF は接続設定・データ
フロー・出力マッピング・責務分担を正規化し、導入側が **「PlanGate だけ」
「river-reviewer だけ」「両方」** の 3 パターンを迷わず選べるようにする。

> 本 IF は [review-principles.md §7-bis](../../.claude/rules/review-principles.md)
> の C-2 レビュア責務契約（2 レーン）を **変更しない**。5 レビュー観点・
> Severity・判定基準（§2〜4）も不変。本 IF は *接続の機械的規約* のみ。

## 2. レビューア設定ファイル `.plangate-reviewers.yaml`

リポジトリルートに任意配置（無ければ従来どおり `PLANGATE_EXTERNAL_REVIEWER`
の単一プロバイダ動作）。スキーマ: [`schemas/plangate-reviewers.schema.json`](../../schemas/plangate-reviewers.schema.json)。
最小構成例: [`.plangate-reviewers.example.yaml`](../../.plangate-reviewers.example.yaml)。

```yaml
version: "1.0"
reviewers:
  c2:
    provider: river-reviewer
    command: "river run . --phase upstream --output-format json"
    output_mapping:
      severity: finding.severity
      evidence: finding.evidence
      location: "finding.file + ':' + finding.line"
  v3:
    provider: river-reviewer
    command: "river run . --phase midstream --output-format json"
    output_mapping:
      severity: finding.severity
      evidence: finding.evidence
      location: "finding.file + ':' + finding.line"
```

- `version`: IF スキーマ版。additive 進化（[versioning-stability-policy.md](./versioning-stability-policy.md) §2.1）。
- `reviewers.c2` / `reviewers.v3`: フェーズ別レビューア。片方のみでも可。
- `provider`: レビューア識別子（例 `river-reviewer` / `gemini` / `codex`）。
- `command`: 実行コマンド。**JSON を stdout に出力**すること（後述 §3）。
- `output_mapping`: レビューア出力 → PlanGate フィールドの対応（§3）。
  **必須**（`severity` / `evidence` / `location` を含む。省略不可 —
  変換に必要なため schema で必須化）。

## 3. 出力フォーマット変換

外部レビューアは Finding 配列を JSON で出力する。PlanGate は
`output_mapping` に従い [`review-external.schema.json`](../../schemas/review-external.schema.json)
準拠の `review-external.md`（+ 任意 `review-result.json`）へ変換する。

### 3.1 river-reviewer Finding → PlanGate

river-reviewer の Finding は `Finding:Evidence:Impact:Fix:Severity:Confidence`
構造。対応:

| river-reviewer | PlanGate review-external | 備考 |
|----------------|--------------------------|------|
| `finding` | 指摘タイトル | 1 行要約 |
| `evidence` | 根拠（差分引用） | §6 具体性要件を満たす |
| `impact` | 影響（故障確率の説明） | §5 故障確率判断 |
| `fix` | 改善案 | §5 改善案提示 |
| `severity` | severity | §3.2 で 1:1 |
| `confidence` | （補助情報） | 低 confidence は info 降格可 |
| `file` + `line` | location | `file:line` 形式 |

### 3.2 Severity マッピング

river-reviewer と PlanGate の 4 段階は **現時点で語彙一致**。明示的に固定:

| river-reviewer | PlanGate ([review-principles §3](../../.claude/rules/review-principles.md)) | マージ影響 |
|----------------|------------------------------------------------------------------------------|-----------|
| `critical` | critical | ブロッカー |
| `major` | major | 修正推奨 |
| `minor` | minor | 任意 |
| `info` | info | 無視可 |

> 将来どちらかが語彙を変えた場合、本表が **唯一の正規変換点**。未知 severity
> は安全側で `major` に丸める（[versioning-stability-policy.md](./versioning-stability-policy.md)
> §2.1 制約強化 = major のため、追加時は本表更新を破壊的変更として扱う）。

### 3.3 events 最小フィールド（後続実装の解釈固定）

[review-principles §7-bis](../../.claude/rules/review-principles.md) の案を
本 IF で正規化する（#230 gate-event-normalization と整合）:

```
{ "review_id": "R-NNN", "lane": "design|codebase",
  "severity": "critical|major|minor|info",
  "reflected_in": "<artifact path>", "status": "open|reflected|deferred" }
```

events 化（[gate-event-normalization.md](./gate-event-normalization.md)）時は
この形を踏襲する。本 PBI は **参照定義まで**（events 発火実装は別 PBI）。

## 4. 責務分担

| フェーズ | PlanGate の責務 | 外部レビューア（river-reviewer）の責務 |
|----------|-----------------|----------------------------------------|
| C-1 | セルフレビュー（17 項目） | 不使用 |
| C-2 | レビュー結果の受け取り + ゲート判定（2 レーン責務契約 §7-bis 適用） | upstream スキルで plan 品質検証を実行 |
| V-1 | 受け入れ検査の判定（内部） | 不使用 |
| V-3 | 外部レビュー結果の受け取り + 判定 | midstream スキルで diff レビューを実行 |

- C-2 の 2 レーン（設計妥当性 / コードベース整合）は
  [review-principles §7-bis](../../.claude/rules/review-principles.md) が正本。
  外部レビューアは **コードベース整合レーンの探索を 1 エージェントに集約**
  する原則に従う（重複排除）。
- **責務重複の排除**: PlanGate upstream（plan 検証）と river-reviewer の
  upstream スキル（plangate-plan-integrity 等）は **C-2 で一方のみ実行**。
  `.plangate-reviewers.yaml` に `c2` が定義されていれば river-reviewer を
  正とし、PlanGate 内蔵 C-2 は受け取り + ゲート判定に徹する。

## 5. 3 つの導入パターン

| パターン | `.plangate-reviewers.yaml` | 動作 |
|----------|----------------------------|------|
| **PlanGate だけ** | ファイル自体を置かない | 内蔵 C-1/V-1 + `PLANGATE_EXTERNAL_REVIEWER`（codex 既定）|
| **river-reviewer だけ** | `c2` と `v3` を river-reviewer に設定 | 外部レビューに一本化（PlanGate は受け取り + ゲート判定）|
| **両方** | `c2` を river-reviewer、`v3` を別 provider 等 | フェーズごとに最適な provider を選択 |

> `.plangate-reviewers.yaml` を **置く場合は `reviewers` に `c2` /
> `v3` のうち最低 1 つが必須**（schema `minProperties:1`）。レビューアを
> 一切使わない場合はファイル自体を置かない。

いずれもゲート判定（C-3/C-4）と承認境界は PlanGate 側が保持（外部レビューアは
判定材料を提供するのみ・[responsibility-classes.md](../../.claude/rules/responsibility-classes.md)）。

## 6. 検証

- `.plangate-reviewers.yaml` は [`schemas/plangate-reviewers.schema.json`](../../schemas/plangate-reviewers.schema.json)
  で機械検証（`additionalProperties:false`）。
- severity マッピング（§3.2）の変更は破壊的変更として扱い CHANGELOG
  `[BREAKING]` を付与（[versioning-stability-policy.md](./versioning-stability-policy.md) §4）。

## 7. 関連

- [`.claude/rules/review-principles.md`](../../.claude/rules/review-principles.md) §7-bis — C-2 2 レーン責務契約（正本）
- [`schemas/review-external.schema.json`](../../schemas/review-external.schema.json) — 変換先スキーマ
- [`ai/contracts/review.md`](./contracts/review.md) — review phase contract
- [`ai/gate-event-normalization.md`](./gate-event-normalization.md) — events 正規化（#230）
- [`ai/versioning-stability-policy.md`](./versioning-stability-policy.md) — severity 表変更の互換性扱い
- river-reviewer 側: [s977043/river-reviewer#802](https://github.com/s977043/river-reviewer/issues/802)
