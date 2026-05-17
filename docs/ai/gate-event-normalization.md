# Gate Event Normalization（正本 / #230 PBI-HI-014 / v8.8.0）

> gate / hook / workflow event の表現揺れを正規化する**正本**。
> Trace Timeline v1（[#229](../../schemas/plangate-event.schema.json) /
> `metrics --timeline`）と Dogfooding Eval v1（#231）が同じ gate signal を
> 読めるようにする。**既存 vocabulary / schema を壊さず**、正規化「ビュー」を
> 定義する（schema enum は不変・後方互換）。

## 1. Gate event / 非 Gate event の判定ルール

| 区分 | 定義 | 該当 `event`（schema 1.x enum） |
|------|------|--------------------------------|
| **Gate event** | 通過可否・人間判断・検証結果を持つ | `c3_decided` / `c4_decided` / `v1_completed` / `external_review_completed` / `hook_violation` / `fix_loop_incremented` |
| **非 Gate event** | 進行・生成・状態遷移 | `task_initialized` / `plan_generated` / `exec_started` / `pr_created` / `handoff_completed` |

判定: `gate_id` が付与され、status（§3）に正規化できる event を Gate event と
みなす。**status 入力が schema 上 optional な Gate event の扱い（V-3 MJ-1）**:
- `external_review_completed`: `verdict` があれば §3 で正規化。無ければ
  `conditional`（レビュー実施済だが判定未確定）として扱い signal を落とさない。
- `fix_loop_incremented`: status を持たない進行 signal。`fix_loop_count` を
  メタとして保持し status は `skipped`（gate 判定対象外）に正規化。
  Dogfooding Eval(#231) は count を別途参照する。

## 2. gate_id 命名規則

`gate_id` は schema 1.1 の pattern `^[A-Za-z0-9._:-]{1,64}$`（#229 確定）に
従い、以下の**正規語彙**を用いる:

| カテゴリ | gate_id 正規値 |
|---------|---------------|
| 計画レビュー | `C-1` / `C-2` / `C-3` |
| PR レビュー | `C-4` |
| 検証 | `V-1` / `V-2` / `V-3` / `V-4` |
| リンター | `L-0` |
| 引き継ぎ | `handoff` |
| 強制 Hook | `EH-1`〜`EH-9` / `EHS-1`〜`EHS-3` |

**gate_id と phase の関係（V-3 MJ-2 反映）**: workflow/承認 gate（C-x/V-x/L-0/
handoff）は gate_id と phase が一致する。一方 **hook gate（EH-x/EHS-x）は
gate_id が phase enum に無く、phase は「その hook が発火した WF/Gate」を指す**
（例: `gate_id:"EH-3"`, `phase:"WF-04"`）。両者は別軸であり一致を要求しない。
未知 gate_id（pattern OK でも上表外）は「未正規化」として扱い、
reporter / eval は警告対象にしてよい（破棄しない）。

## 3. status 正規化マップ

既存 enum（`verdict` / `hook_result` / hook 監査 level / `c3_status`）を
**5 正規 status** に写像する（元 enum は不変＝正規化はビュー）:

| 正規 status | 元の表現（verdict / hook_result / 監査 level / c3_status） |
|------------|--------------------------------------------------------|
| `pass` | `APPROVED` / `PASS` / `pass` |
| `fail` | `REJECTED` / `FAIL` / `block` / `BLOCK` / `VIOLATION` / `MAINTENANCE_INVALID`（fail-closed）/ `SKIP_BLOCKED`（理由欠如で SKIP 拒否＝release blocker） |
| `conditional` | `CONDITIONAL` / `WARN` / `warn` / `WARNING` / `REQUEST_CHANGES` |
| `skipped` | `SKIP` / `MAINTENANCE_SKIP`（規約に沿った未実行）。`INCREMENT`（fix_loop_incremented）も gate 判定対象外として `skipped`＋count メタ保持 |
| `bypassed` | `BYPASS`（`PLANGATE_BYPASS_HOOK=1` の明示的強制解除のみ） |

> 注: 機械実装の決定論性のため (1) `SKIP_BLOCKED`（SKIP_REASON 欠如での
> SKIP 拒否）は **`fail`**（Dogfooding Eval の release blocker）、
> (2) `MAINTENANCE_INVALID` は **`fail`**（fail-closed）、(3) `BYPASS` のみ
> `bypassed`、(4) 規約準拠の未実行（`SKIP`/`MAINTENANCE_SKIP`/`INCREMENT`）は
> `skipped` と一意に定める。reporter / eval は正規 status で横断集計する。

## 4. phase 許容値 ↔ WF / Gate 対応表

schema 1.1 `phase` enum と一致（#229）。1.0 値 + 1.1 additive:

| phase | 対応 WF / Gate | 区分 |
|-------|---------------|------|
| `A`/`B`/`C-1`/`C-2`/`C-3`/`D` | 計画〜承認〜実行 | 1.0 |
| `L-0`/`V-1`/`V-2`/`V-3`/`V-4` | リンター/検証 | 1.0 |
| `PR`/`C-4` | PR/PR レビュー | 1.0 |
| `WF-01`〜`WF-06` | ハイブリッド実行層 phase | 1.1 |
| `handoff` | WF-05 完了資産発行 | 1.1 |

## 5. privacy-safe fixture

`tests/fixtures/gate-events/` に正規化済 sample を配置。
Metrics Privacy Policy（#202）の forbidden field（prompt 全文 / secret /
credential / 人名等）を**含まない**識別子のみの event とする。

## 6. 後方互換・整合

- 本ドキュメントは**正規化ルールの定義のみ**。`schemas/plangate-event.schema.json`
  の enum は変更しない（既存 Metrics v1 event は引き続き valid）。
- #228 Run Outcome Review v1 の 5 評価項目 / #229 Trace Timeline と矛盾しない
  （gate_id/phase は #229 schema 1.1 と一致）。
- #231 Dogfooding Eval v1 は本正規化を judge 入力の前処理に用いる。

## 関連

- schema: [`schemas/plangate-event.schema.json`](../../schemas/plangate-event.schema.json)（1.1 / #229）
- [`docs/ai/metrics.md`](./metrics.md) Trace Timeline v1（experimental）
- [`docs/ai/hook-enforcement.md`](./hook-enforcement.md) EH-1〜9 / EHS-x
- 親 EPIC: #193 / 前提: #229 / 後続: #231
