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

## 8. v2.0: 並列マルチレビューア（Mode 連動自動スケール）

> v2.0 拡張（TASK-0122 / #424）。v1.0 との後方互換を維持する additive 拡張。

### 8.1 フィールド説明

| フィールド | 型 | 必須 | 説明 |
|------------|---|------|------|
| `lane` | `"design" \| "codebase" \| "security"` | 任意 | レビューレーン（[review-principles §7-bis](../../.claude/rules/review-principles.md) に対応） |
| `mode_threshold` | enum（後述） | 任意 | このレビューアが起動する最低 Mode。タスクの Mode がこの値未満なら自動スキップ |
| `command` | string **または** array of string | 必須 | v2.0 では文字列配列も許容（配列は空白結合して実行） |

### 8.2 Mode スケール表

`mode_threshold` の値と起動条件:

| `mode_threshold` 値 | 起動するタスク Mode |
|---------------------|---------------------|
| `ultra-light` | ultra-light 以上（全 Mode） |
| `light` | light 以上 |
| `standard` | standard 以上 |
| `high-risk` | high-risk 以上 |
| `critical` | critical のみ |

タスクの Mode は `docs/working/TASK-XXXX/current-state.md` または `plan.md` の
`**Mode**:` / `**モード**:` 行から自動取得する。取得不能な場合は
`mode_threshold` フィルタを無効化して全レビューアを実行する。

### 8.3 v2.0 設定例

```yaml
version: "2.0"
reviewers:
  c2:
    - provider: codex
      lane: design
      mode_threshold: standard
      command: "codex review --phase upstream --output-format json"
      output_mapping:
        severity: finding.severity
        evidence: finding.evidence
        location: "finding.file + ':' + finding.line"
    - provider: gemini
      lane: security
      mode_threshold: high-risk
      command: "gemini review --phase upstream --output-format json"
      output_mapping:
        severity: finding.severity
        evidence: finding.evidence
        location: "finding.file + ':' + finding.line"
  v3:
    provider: codex
    command: "codex review --phase midstream --output-format json"
    output_mapping:
      severity: finding.severity
      evidence: finding.evidence
      location: "finding.file + ':' + finding.line"
```

### 8.4 並列実行の動作

1. `.plangate-reviewers.yaml` の当該フェーズが配列形式の場合、各レビューアを `&` で並列起動し `wait` で全完了を待つ
2. 失敗したレビューアは `warn` 扱いでスキップ（他のレビューアには影響しない）
3. 結果は `provider` 名アルファベット順にソートし `R-001`, `R-002` ... と連番を付けて `review-external.md` に集約
4. 並列実行の記録は `decision-log.jsonl` に `parallel_review` イベントとして append される

### 8.5 後方互換

- v1.0 設定（`version: "1.0"` / command が文字列 / 単体 reviewerSpec）は **v2.0 schema で引き続き valid**
- `.plangate-reviewers.yaml` が存在しない場合は従来どおり `PLANGATE_EXTERNAL_REVIEWER` 環境変数（既定 `codex`）で動作する
- `python3` または `PyYAML` が未インストールの場合は `warn` を出力してレガシーフォールバック動作に切り替わる

## 9. 専門 Reviewer Skill 一覧（TASK-0126〜 段階導入）

> 既存の 2 レーン設計（[`review-principles.md §7-bis`](../../.claude/rules/review-principles.md)）を
> 維持しながら、C-2 / V-3 に接続する専門 Skill を段階的に整備する。
> 導入順: ① plan-quality → ② security-risk → ③ test-strategy → ④ 残 4 本（high-risk+ 限定）

| フェーズ | Skill | Lane | Mode 閾値 | 状態 |
|---------|-------|------|----------|------|
| C-2 | `plan-quality-reviewer` | design-validity | light+ | ✅ 導入済み（TASK-0126）|
| C-2 / V-3 | `security-risk-reviewer` | security | standard+ | 🔜 予定 |
| C-2 / V-3 | `test-strategy-reviewer` | test-strategy | standard+ | 🔜 予定 |
| V-3 | `implementation-quality-reviewer` | code-quality | high-risk+ | 🔜 予定 |
| V-4 | `release-readiness-reviewer` | release | critical+ | 🔜 予定 |
| V-3 | `docs-handoff-reviewer` | docs | high-risk+ | 🔜 予定 |

### 9.1 plan-quality-reviewer（設計妥当性レーン）

- **Skill**: [`.claude/skills/plan-quality-reviewer/SKILL.md`](../../.claude/skills/plan-quality-reviewer/SKILL.md)
- **責務**: plan.md / todo.md / test-cases.md を読み、受入基準網羅性・スコープ整合を確認。実コード原則不読。
- **出力**: `R-NNN / lane=design-validity / severity / status` — `review-external.md` 追記互換
- **設定例（v2.0）**:

```yaml
version: "2.0"
reviewers:
  c2:
    - provider: plan-quality-reviewer
      lane: design-validity
      mode_threshold: light
      command: "/plan-quality-reviewer"
      output_mapping:
        severity: finding.severity
        evidence: finding.body
        location: "finding.id"
```


## 10. 外部レビュー実行不可時の記録規約（#463）

C-2 / V-3 の外部 AI レビューが**実行不可**（CLI 未導入・API 不達・quota 超過・ネットワーク遮断等）の場合、`review-external.md` に以下を**必須記録**する。これにより「指摘なし（実行したが finding ゼロ）」と「実行不可（実行できなかった）」を区別し、監査連続性を保つ。

### 必須記録項目（`unavailable` 時）

| 項目 | 説明 |
|------|------|
| `実行状態` | `executed` / `unavailable` を明示 |
| `実行不可の理由` | 具体的事由（例: `codex CLI 未導入` / `Gemini quota 超過`）|
| `代替レビュー観点` | セルフレビュー（C-1）で補った観点、または後追いレビューの予定 |
| `未充足リスク` | 外部レビュー欠如で残るリスク（severity 相当の見積り）|

### 判定への影響

- `unavailable` かつ上記 `unavailable` 時必須の 3 項目（実行不可の理由 / 代替レビュー観点 / 未充足リスク）が記録されていれば、C-3 / 後続フェーズは**条件付きで進行可**（未充足リスクを承認境界の判断材料にする）。この場合、`review-external.md` のフロントマター `verdict` は **`WARN`** とする。
- `unavailable` なのに理由・代替観点・未充足リスクが空欄の場合、監査上**無効**として扱い、レビュー成果物を **FAIL** とする。この場合、フロントマター `verdict` は **`FAIL`** とする。

### events 連携（#230 と additive）

将来 events 化する場合の最小フィールド:

```json
{ "review_id": "R-NNN", "lane": "design|codebase|security",
  "review_status": "executed|unavailable",
  "unavailable_reason": "<string|null>",
  "alternative_perspective": "<string|null>",
  "residual_risk": "<string|null>" }
```

テンプレート: [`docs/working/templates/review-external.md`](../working/templates/review-external.md) の「外部レビュー実行可否（必須）」セクション。
