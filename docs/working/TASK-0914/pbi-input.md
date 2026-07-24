# PBI INPUT PACKAGE — TASK-0914

> Issue: [#914](https://github.com/s977043/plangate/issues/914)（fix / sync / #877 follow-up）
> 由来: TASK-0877 AC-6（F5 の別 issue 分離）+ C-2 コードベース整合レーン R-204
> 作成: 2026-07-25（main 51489e1 基点。#877 = PR #915 merge 済みを前提）

## Context / Why

`scripts/sync-plugin-plangate.sh` の mass-delete safety guard（#861 / #877）は **`sync_dir` 内の削除ループ（1 経路）にしか適用されていない**。#877 で fail-closed 化（`guard_fired` → 終端 exit 3 + `PLANGATE_ALLOW_MASS_DELETE=1` override + stale ベース判定）は完了したが、src 駆動の無ガード削除が **2 経路** 残存する。

実測（main 51489e1 で行番号を再測。issue #914 本文の行番号は PR #915 マージ前の stale のため本表が正）:

| 行域（51489e1 実測） | 対象 | 駆動元 | hazard |
|------|--------|--------|--------|
| 汎用 references 削除ループ（`_src_refs`/`_dst_refs` 突合・L173-182 付近） | `plugin/plangate/skills/<name>/references/*.md` | src `references/` の内容 | △ `-d "$_src_refs"` ガードによりディレクトリ消失には耐性。**空化時のみ**全削除 |
| ai-loop references 削除ループ（`_ai_loop_expected_refs` 駆動 `case`・L316-330 付近） | `plugin/plangate/skills/ai-loop-cycle/references/*.md` | `_ai_loop_expected_refs` 構築（L243-264 付近） | ⚠️ **真の hazard**。正本 2 ディレクトリが消失/空化すると期待集合が空になり全 `.md` 削除 |
| （参考）scripts allowlist `case` 削除（L350-362 付近） | `.../scripts/*.py` | ハードコード allowlist の `case` | ✕ 対象外。src 欠損に依存しないため mass-delete しない |

> 注: #877 の pbi-input と issue 本文は「references 3 経路」と記載していたが、実測では **src 駆動は 2 経路**（allowlist 経路は mass-delete しない）。本 PBI は 2 経路を対象とする。issue #914 本文の行番号（L140-150 / L283-296 / L210-231 / L317-330）は起票時点のもので、#915 マージ後の 51489e1 では上表へシフト済み。

あわせて、C-2 R-204 で指摘された harness/standalone 判別方式（`${FIXTURES_DIR:-}` 単独判定）の不統一を解消する。

## What（Scope）

### In scope

1. **F5**: 上記 2 経路（汎用 references 削除ループ / ai-loop references 削除ループ。行番号は目安・記号アンカーを正とする）への guard 適用
   - `sync_dir` 内の判定を共通関数（`_mass_delete_guard` 等）へ切り出して再利用するか、経路ごとに個別実装するかは plan 段階の設計判断
   - `PLANGATE_ALLOW_MASS_DELETE=1` override と `guard_fired` → 終端 exit 3 の枠組みは #877 実装を踏襲
2. **R-204**: harness/standalone 判別方式の統一
   - `tests/extras/README.md` の規約に「新規 extras は `PG_HARNESS_SOURCED`（非 export・`FIXTURES_DIR` との AND）を使う」を追記
   - `${FIXTURES_DIR:-}` 単独判定の既存 11 extras（ta-39/43/44/45/46/47/49/50/51/52/53）を `PG_HARNESS_SOURCED` 方式へ移行

### Out of scope

- `sync_dir` 内 guard 本体の再設計（#877 / PR #915 で完了済み）
- `.github/workflows/*.yml` の変更（#877 と同じく exit 3 で job は自動 fail する = HO 回避）

## 受入基準

- AC-1: ai-loop references 削除ループ（`_ai_loop_expected_refs` 駆動）で期待集合が空/極小のとき削除を保留し、`guard_fired` 経由で終端 exit 3 する
- AC-2: 汎用 references 削除ループ（`_src_refs`/`_dst_refs` 突合）でも同様（空化ケース）
- AC-3: 各経路の負側テスト（guard 発火）と正常系テスト（通常削除）が `tests/extras/ta-26-plugin-sync.sh` に追加される
- AC-4: `PLANGATE_ALLOW_MASS_DELETE=1` による override が全経路で一貫して効く
- AC-5: `tests/extras/README.md` に harness 判別規約が明記される
- AC-6: 既存 11 extras が `PG_HARNESS_SOURCED` 方式へ移行し、`sh tests/run-tests.sh` と各 standalone 実行の双方が exit 0

## Notes from Refinement

- **Mode 見込み**: **high-risk**（定量: 変更ファイル数 = sync スクリプト 1 + README 1 + ta-26 1 + 既存 extras 11 = 最大 14 → high 帯 6-15。mode-classification の最大値採用ルールに従い定量で確定。`scripts/sync-plugin-plangate.sh` は `scripts/` 直下で HO 対象外。plan 段階で extras 移行を分割スライス化する場合のみ再判定）
- guard 判定式の設計根拠は `docs/working/TASK-0877/plan.md` 論点 A / B / C を参照（stale ベース判定・閾値・override の設計判断を再利用する）
- extras 11 本の移行は機械的な置換だが、**standalone 実行の後方互換**（AC-6 の双方 exit 0）を負側で確認する

## Estimation Evidence

- **Risks**: 期待集合構築（`_ai_loop_expected_refs`）は 2 正本ディレクトリ合成のため、「空/極小」の閾値設計を誤ると正当な reference 削減も block する（override 頻発 = 形骸化）
- **Unknowns**: 共通関数化 `_mass_delete_guard` の切り出し範囲（`sync_dir` 内 guard と閾値パラメタが揃うか）
- **Assumptions**: #877 実装（PR #915）の `guard_fired` / 終端 exit 3 / override の枠組みが main で安定していること（51489e1 で確認済み）
