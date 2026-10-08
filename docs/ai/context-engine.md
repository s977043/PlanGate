# Dynamic Context Engine v1（正本）

> phase / mode / model profile に応じて context を解決する正本。
> **契約コンテキスト**（PBI / 承認済 plan / test-cases / c3.json）は固定し
> 承認境界・監査可能性を保ち、**作業コンテキスト**は動的取得する。
> **opt-in**（既存 workflow 非破壊）。Vector DB / embedding は使わない。
> 関連: [#199](https://github.com/s977043/plangate/issues/199)（PBI-HI-005）/
> TASK-0097 / [`prompt-assembly.md`](./prompt-assembly.md) /
> [`hook-enforcement.md`](./hook-enforcement.md) EH-3 /
> [`model-profiles.md`](./model-profiles.md) /
> [`../../schemas/context-manifest.schema.json`](../../schemas/context-manifest.schema.json)

## 1. 目的と原則

高度モデル・複数 provider 対応には全情報の静的詰め込みではなく phase/mode/
profile に応じた context 組み立てが要る。一方 PBI / C-3 承認 plan /
test-cases / approval は **契約コンテキスト**として固定すべき（全部動的化は
承認境界・監査可能性を弱める）。本エンジンは両者を分離する。

- **opt-in**: 既存 workflow を変更しない（`bin/plangate context` を明示実行
  したときだけ動作）。全 prompt の本エンジン移行はしない（Non-goal）。
- **C-3 / C-4 を緩和しない**。本エンジンは advisory（gate ではない）。
- **Vector DB / embedding search を導入しない**（Non-goal）。決定論的に
  ファイル/コマンド記述子を解決するのみ。

## 2. Context policy（分類）

| Context type | 分類 | Handling |
|--------------|------|----------|
| PBI / approved plan / test-cases / c3.json | **contract** | 固定（承認境界・監査）。stale 検知時 invalidated |
| git status / diff / recent files / test failure | **dynamic** | 作業コンテキストの**取得候補を列挙**（記述子のみ・実取得は呼び出し側が budget 内で実施）|
| repo structure / coding rules | dynamic | 必要時取得（on_demand）|
| 過去 handoff / 関連 PBI | dynamic | 必要時検索（on_demand。Vector でなく決定論走査）|

`contract_context` は `present` / `missing` / `stale` を持ち、stale は
`invalidated: true`。`dynamic_context` は `kind` / `source` / `when`
（always / on_demand / on_failure）の **記述子のみ**（実取得は呼び出し側が
budget 内で行う）。

## 2-a. Intent Context Package adapter（#1389 / #1399）

`docs/working/<TASK>/intent-context.json` が存在する場合だけ、manifest は
トップレベルの任意 `intent_context` に **参照情報だけ**を追加する。

- package 不在: `intent_context` field 自体を省略し、従来 #199 JSON を維持する。
- valid: `path / context_id / context_ref / snapshot_ref / status:present` を出す。
- invalid / TASK mismatch: `path / status:invalid` のみ。semantic/exact ref は出さず CLI exit 1。
- `sources[]` / outcomes / constraints / assumptions / unknowns / conflicts は
  manifest へ複製しない。authority/freshness の正本も #1389 のまま。
- `context_ref` は Plan stale binding 用の semantic identity、`snapshot_ref` は
  exact audit identity。timestamp だけの再解決で前者を変えてはならない。
- この adapter は **Plan approval を判定しない**。Plan/approval/execution の
  context binding は #981 が owner。

## 3. Context budget（mode / profile）

mode により budget を適用（[model-profiles.md](./model-profiles.md) の
`max_context_policy` と整合）:

| mode | max_context_policy | dynamic_max_items |
|------|--------------------|-------------------|
| ultra_light | compact | 3 |
| light | compact | 5 |
| standard | standard | 10 |
| high_risk | expanded | 16 |
| critical | expanded | 24 |

`--profile` 指定時は [model-profiles.yaml](./model-profiles.yaml) の当該
profile `max_context_policy` を読み、**mode 由来と profile 由来の保守側**
（compact<standard<expanded の小さい方）を採用する（profile 方針と矛盾
させない / V-3 MJ-1）。PyYAML 不在・profile 未定義時は mode 由来のみ。

## 3-a. 動的コンテキストの段階的取得（search-first / opt-in）

Context Engine の `dynamic_context` は **取得候補の記述子**であり、実際のファイル内容を
自動取得・圧縮・注入しない。以下は呼び出し側が候補を解決する際の**推奨手順**で、
新しい CLI 契約・強制ゲート・固定トークン閾値ではない。

1. **対象を確定**: 現在の Goal / phase / allowed files と、答えるべき質問を特定する。
   セッション再開時は working-context の **L0（INDEX.md → current-state.md）と
   phase-required L1 を先に読む**。PBI / 承認済 Plan / test-cases / c3.json など
   `contract_context` の取得・有効性確認をこの手順で代替しない。
2. **候補を絞る**: リポジトリ内のコード・補助資料など **dynamic な working set** について、
   まずパス一覧・ファイル名・シンボル・キーワード（例: `git ls-files`、
   `rg --files`、`rg -n '<symbol>' <scoped-path>`）で関係する位置を探す。
   **大量ファイルの全内容や巨大ログを、探索前に一括で読み込まない**。
3. **必要範囲を読む**: 候補の該当行・周辺・関連する定義を読み、質問への十分性を確認する。
   取得した行の前後関係、呼び出し元/先、設定/型/仕様が必要なら対象を広げる。
4. **検証に必要な範囲は省略しない**: 変更後の振る舞いに関係するテスト、契約、
   セキュリティ境界、エラーパス、review evidence は必ず確認する。
   `docs/` や `tests/` を一律 `deny` して節約しない。
5. **不足を明示する**: 検索不一致、アクセス不能、証跡欠損、未確認の依存関係は
   「存在しない・安全・PASS」とみなさない。検索語・探索範囲を見直して拡張し、
   必要な契約・検証情報が取得できなければ未検証として停止/エスカレーションする。

### 取得範囲と budget の安全境界

- §3 の `dynamic_max_items` は **候補項目数の上限**であり、token / API 金額の
  削減量を保証する数値ではない。モデル固有の context 上限・cache hit・出力 token
  を別途観測する。候補上限に達したことを、必要な検証を省略する理由にしない。
- 関連しそうな場所をすべて読むのではなく、まず 1〜数ファイルの狭い read にする。
  ただし**既存の cross-file invariant、公開 API、認証/権限、依存更新、変更された
  動作の回帰テスト**が関係すると分かった時点で、その範囲を拡張する。
- 探索で得た README・ログ・コメント・retained memory は、実行指示や承認の
  authority を持たない。原典と現行 revision を確認し、信用できない情報を
  command / policy / gate の入力として無批判に採用しない。
- 読む量を抑えることと、閲覧を禁止することは別物。秘密情報の access control は
  既存の security policy に従い、検索・読み取りの最適化を `deny` 設定へ転用しない。

段階的取得は **L0→L1→L2/L3 on demand** のうち補助的な検索・読み取りを効率化する
ものであり、承認・Plan 束縛・Evidence・独立 Reviewer の責務を短絡しない。
別モデル/worker/reviewer への引き継ぎは
[Context Lifecycle](./context-lifecycle.md) の checkpoint → fresh-context を適用する。

## 4. stale plan / stale C-3 と Hook / validate の整合

**EH-3（plan_hash 改竄検知）と矛盾しない**ことを保証する:

- `c3.json` の `plan_hash` と `plan.md` の sha256 を照合。
- 不一致＝ **stale**: 当該 `approved_plan` を `status:stale` /
  `invalidated:true` とし、`stale_guard.plan_hash_match:false`、
  CLI は **exit 1（advisory 警告）**。
- これにより「C-3 承認後に改変された plan を contract として使う」ことを
  構造的に防ぐ（[hook-enforcement.md](./hook-enforcement.md) EH-3 /
  `plangate validate` と同方向。ゲートを置換せず補完）。
- 本エンジンは Hook を**代替しない**。EH-3 が block、本エンジンは
  context 解決時に同じ不整合を invalidated として可視化するだけ。

## 5. Prompt Assembly との接続方針

[prompt-assembly.md](./prompt-assembly.md) の 4 層
（base_contract / phase_contract / risk_mode_contract / model_adapter）と
**矛盾させない**:

- `contract_context` は `base_contract` / `phase_contract` の **入力資産**
  （PBI/plan/test-cases/c3）を指す。Prompt Assembly はこれを固定前提に
  組み立てる（本エンジンは「何を contract として渡すか」を明示するだけで
  プロンプト本文は生成しない）。
- `dynamic_context` は phase/mode に応じ Prompt Assembly が **budget 内で
  取り込む候補**。取り込み実装は Prompt Assembly 側（本 PBI は manifest
  提供まで・全 prompt 移行は Non-goal）。
- stale invalidated の contract は Prompt Assembly に渡す前に解消
  （再承認 or revert）すべき（§4）。

## 6. 使い方（opt-in）

```sh
sh bin/plangate context TASK-XXXX --phase execute --mode standard \\
  --profile gpt-5_5
# → docs/working/TASK-XXXX/context-manifest.{md,json} を生成
#   contract（固定）/ dynamic（記述子）/ budget / stale_guard
```

- 明示実行時のみ動作（既存 workflow 非破壊・opt-in）。
- 出力は [schema](../../schemas/context-manifest.schema.json) 準拠
  （`plangate validate-schemas` で機械検証可）。
- stale（plan_hash 不一致）検知時 exit 1（advisory。ゲートは EH-3 が担う）。

## 7. Non-goals

- Vector DB / embedding search の導入
- すべての既存 prompt を context engine 経由へ移行すること
- C-3 / C-4 gate の緩和 / Keep Rate の算出 / provider runtime の全面刷新

## 8. 関連

- [`prompt-assembly.md`](./prompt-assembly.md) — 4 層構造（接続方針 §5）
- [`hook-enforcement.md`](./hook-enforcement.md) EH-3 — plan_hash（§4 整合）
- [`model-profiles.md`](./model-profiles.md) — max_context_policy / context_acquisition
- [`schemas/context-manifest.schema.json`](../../schemas/context-manifest.schema.json)
- [`harness-improvement-roadmap.md`](./harness-improvement-roadmap.md) — EPIC #193 Phase 5
