# TASK-0110 PBI INPUT PACKAGE

> Issue: [#301](https://github.com/s977043/plangate/issues/301)
> 出自: #300 で除外された follow-up（gemini-code-assist critical 指摘実測確認）

## Context / Why

`docs/working/_audit/skip-decision-log.jsonl` (148 record / 2026-05-25 時点) は全 entry が `acknowledged_by:null` 状態で、`scripts/check-skip-acknowledged.sh` (CI required "SKIP_REASON 追認") が exit 1 となるため repo に保全できない。acknowledge 追記は Human-owned のため、AI は batch acknowledge **スクリプト + 適用手順 + 監査** の作成までを担当し、適用は Human が実施する。

## What (Scope)

### In scope

- `scripts/batch-acknowledge-skip-decisions.py` (新規): jsonl を読んで `acknowledged_by` `acknowledged_at` を一括追記 (in-place atomic RMW)。AI 実装可
- 適用前後の **CI "SKIP_REASON 追認" が PASS する** ことを検証する手順書
- dry-run / production mode 分岐
- 適用 dry-run 結果 (evidence/) と diff サマリ
- documented limitation: AI は適用しない、Human が CLI 実行

### Out of scope

- `check-skip-acknowledged.sh` 仕様変更 (現行 strict 維持)
- skip エントリの prune / deletion (#301 Approach (c) は将来)
- 新規 SKIP 記録の都度追認フロー変更 (#301 (b) は将来)

## 受入基準

- AC-1: `scripts/batch-acknowledge-skip-decisions.py --dry-run` で全 `acknowledged_by:null` を検出、追記予定 entry 数 / sample 出力
- AC-2: `--apply --acknowledged-by <name>` で実 jsonl を atomic 更新 (元 file は `.bak` 保持)
- AC-3: 適用後の jsonl で `scripts/check-skip-acknowledged.sh` が PASS (exit 0)
- AC-4: schema 互換性: 既存 entry の他フィールド (ts, run_id, hook, reason 等) が一切変更されない (byte-equal except 2 field)
- AC-5: `--apply` は明示 `--acknowledged-by` 必須 (空文字 reject)
- AC-6: dry-run 結果と evidence サマリを `docs/working/TASK-0110/evidence/` に保存
- AC-7: `tests/extras/ta-14-skip-acknowledge.sh` で fixture jsonl に対する batch 動作を unit test

## Notes from Refinement

- Approach (a) 一括追認 を採用 (#301 候補のうち最も影響が予測可能)
- 適用は Human-owned (AI 不可): スクリプト作成 + dry-run までが AI 担当
- 適用後の `acknowledged_at` は **batch-timestamp** で統一 (個別の record timestamp とは区別)

## Estimation

### Risks

- 既存 entry の意味喪失 (一括追認で個別 reason 点検が形骸化) → mitigation: dry-run 出力に reason 集計を含め、Human が点検対象を選別可能に
- atomic RMW 失敗で jsonl 破損 → mitigation: `.bak` 保持 + os.replace + 適用前 schema 検証

### Unknowns

- 148 record の reason 分布 (EH-3 SKIP vs 他) — dry-run で測定

### Assumptions

- `check-skip-acknowledged.sh` 仕様は不変
- 新規 SKIP 記録は今後 C-3/C-4 都度追認 (本 PBI 範囲外)
