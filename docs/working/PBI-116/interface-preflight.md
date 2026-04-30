# Interface Preflight — PBI-116 Phase 2

> Codex 相談 D1 採用の前提条件: 「並行開始前に 02/06 の `tool_policy` 接続点だけ interface preflight を行う」
> Phase 2 子 PBI 間の **共有語彙・データ受け渡し境界** を事前合意するドキュメント

## 目的

PBI-116-02 (Model Profile) と PBI-116-06 (Tool Policy / Hook 境界) は並行実行可能だが、**`tool_policy` フィールドが両者の境界** に跨る。事前に共有語彙を固定しないと、独立実装後に不整合が発覚するリスクが Medium。

PBI-116-04 (Structured Outputs) は独立性が高いため preflight 対象外。

## 共有語彙（02 と 06 で同一意味で使う）

### `tool_policy`

Model Profile 内の設定項目。実行モデルがどのツール呼び出しを許可されるかを表す。

| 値 | 意味 |
|----|------|
| `narrow` | 限定された tool セット（小型モデル / 低 reasoning effort 用） |
| `allowed_tools_by_phase` | phase 別の allowed tools リストに従う（標準） |
| `expanded` | 広範な tool セット（高 reasoning effort / 探索型タスク用） |

### `validation_bias`

Model Profile 内の設定項目。検証の厳格度を表す。

| 値 | 意味 |
|----|------|
| `lenient` | 軽い検証（ultra-light / light モード相当） |
| `normal` | 標準検証 |
| `strict` | 厳格検証（high-risk / critical モード相当） |

### `phase_allowed_tools`

Tool Policy ドキュメント側で定義する phase 別 tool セット。

| Phase | Allowed tools 例 |
|-------|----------------|
| plan | read / search のみ |
| approve-wait | write tools 禁止 |
| exec | edit / test / build allowed |
| review | read / test / diff のみ |
| handoff | read / write docs のみ |

## 接続点の合意

### 接続 1: `tool_policy` の参照先

- **PBI-116-02 (Model Profile)** が `tool_policy: <value>` を Model Profile の各エントリに設定
- **PBI-116-06 (Tool Policy)** が `<value>` ごとの実 tool セット（phase_allowed_tools への射影）を定義
- 例: profile `gpt-5_5_pro` で `tool_policy: allowed_tools_by_phase` → 06 で「phase: exec → edit/test/build」と解決

### 接続 2: `validation_bias` の解釈

- **PBI-116-02** がプロファイル別に `validation_bias` を設定
- **PBI-116-06** が `validation_bias: strict` 時の追加 Hook 強制条件を定義（例: 検証ログなし PR ブロックを必須化）

### 接続 3: ファイル配置の境界

- **02 の出力**: `docs/ai/model-profiles.yaml` / `docs/ai/profiles/**`
- **06 の出力**: `docs/ai/tool-policy.md` / `docs/ai/hook-enforcement.md` / `docs/ai/responsibility-boundary.md`
- **重複領域**: なし（schema レベルでの参照関係のみ、ファイルは独立）

## 並行実行時のチェックリスト（Phase 2 開始前）

Phase 2 で 3 子 PBI を並行起動する前に、各 PBI の plan.md で以下を明示:

- [ ] PBI-116-02 plan.md: `tool_policy` フィールドの値域として `narrow / allowed_tools_by_phase / expanded` を採用
- [ ] PBI-116-02 plan.md: `validation_bias` フィールドの値域として `lenient / normal / strict` を採用
- [ ] PBI-116-06 plan.md: 上記 `tool_policy` 値ごとの phase_allowed_tools 射影を定義
- [ ] PBI-116-06 plan.md: `validation_bias: strict` 時の追加 Hook 条件を定義
- [ ] PBI-116-04 plan.md: 02/06 の出力 schema に依存しない独立 schema 設計

## Stop rule（Phase 2 開始ブロッカー）

以下が発生した場合、Phase 2 並行実行を停止し、preflight を再実施:

- 02 と 06 の `tool_policy` 値域が乖離
- 02 と 06 の `validation_bias` 解釈が乖離
- 04 の Structured Outputs schema が 02/06 のドキュメント schema と衝突

## 関連

- 親計画: [`parent-plan.md`](./parent-plan.md)
- 子 PBI YAML: [`children/PBI-116-02.yaml`](./children/PBI-116-02.yaml) / [`children/PBI-116-04.yaml`](./children/PBI-116-04.yaml) / [`children/PBI-116-06.yaml`](./children/PBI-116-06.yaml)
- Codex 相談結果: [`_codex-phase2-consult-result.md`](./_codex-phase2-consult-result.md)
- 依存関係: [`dependency-graph.md`](./dependency-graph.md)
- リスク: [`risk-report.md`](./risk-report.md)
