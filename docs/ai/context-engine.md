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
