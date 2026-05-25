# TASK-0110 EXECUTION PLAN

> Source: pbi-input.md / GitHub issue #301 / Mode: **light**
> Generated: 2026-05-25 / Codex 提案順位 B (2026-05-25)

## Goal

`docs/working/_audit/skip-decision-log.jsonl` の 148 record (全 `acknowledged_by:null`) を一括追認するためのスクリプトと適用手順を整備し、CI "SKIP_REASON 追認" が PASS する状態に到達する。**適用は Human-owned**、AI はスクリプト + dry-run + 検証手順までを担当。

## Constraints / Non-goals

### Constraints
- AI は `acknowledged_by` を発行しない (適用は Human の CLI 実行)
- **R-001 timing 確定**: Human は **PR ブランチで `--apply` 実行 → 変更を同一 PR にコミット (apply commit) → CI PASS 確認後 merge**。AC-3 は PR 上の最終 commit で評価
- **R-002 byte-equal 実装契約**: JSON parse→dump せず、既存行を raw line として読み、`acknowledged_by` / `acknowledged_at` の 2 field のみを **既存 key 順を維持して置換/追加** する line-preserving 方式を採用 (key order / spacing / escape / trailing newline すべて保持)
- **R-004 C-3 同期固定**: 監査ログ一括変更 CLI のため、mode=light でも **C-3 同期固定** (非同期降格なし)
- **R-005**: `acknowledged_at` は ISO 8601 UTC `YYYY-MM-DDTHH:MM:SSZ`
- 既存 entry の `acknowledged_by` / `acknowledged_at` 以外のフィールドは一切変更しない (byte-equal except 2 field)
- `check-skip-acknowledged.sh` 仕様変更しない (strict 維持)
- 既存テスト regression なし (tests/run-tests.sh + tests/hooks/run-tests.sh)

### Non-goals
- skip エントリの prune / deletion (#301 (c))
- 新規 SKIP 記録の都度追認 (#301 (b))
- check-skip-acknowledged.sh 仕様変更

## Approach Overview

(1) `scripts/batch-acknowledge-skip-decisions.py` を新規作成 (dry-run / apply 分岐 / **raw-line-preserving atomic RMW with .bak**)、(2) `tests/extras/ta-14-skip-acknowledge.sh` で fixture jsonl に対する unit test (**byte-equal except 2 field を機械検証**)、(3) dry-run を実 log で実行し reason 分布を evidence/ に保存 (**event: EH-3_SKIP 優先スキャン**)、(4) `docs/ai/skip-acknowledge-cli.md` で Human 適用手順を documented (**PR ブランチで --apply → コミット → CI → merge の順を明記**)。

**R-001/R-002/R-003/R-004/R-005/R-006 反映済** (review-external.md 参照)。

## Work Breakdown

| # | Step | Output | Owner | Risk | 🚩 Checkpoint |
|---|------|--------|-------|------|--------------|
| 1 | **準備**: skip-decision-log.jsonl の現状調査、schema 確認、check-skip-acknowledged.sh 既存実装読解 | 調査メモ | AI | low | 既存資産マップ完成 |
| 2 | **T-02 (R-002/R-005)**: `scripts/batch-acknowledge-skip-decisions.py` 新規。引数 `--dry-run` / `--apply --acknowledged-by NAME` / `--log PATH`。**raw-line-preserving 方式**: 各行を文字列として読み、line-by-line で `acknowledged_by`/`acknowledged_at` 2 field のみ既存 key 順維持で置換/追加。**ISO 8601 UTC** (`YYYY-MM-DDTHH:MM:SSZ`)。atomic RMW (.bak + os.replace) | scripts/batch-acknowledge-skip-decisions.py | AI | medium | dry-run/apply 両動作、fixture で byte-equal except 2 field を機械検証 |
| 3 | **T-03**: `tests/extras/ta-14-skip-acknowledge.sh` unit test 追加 (fixture jsonl 3 case: 全 null / 一部 null / 全 ack 済) | tests/extras/ta-14-skip-acknowledge.sh | AI | low | tests/run-tests.sh PASS + 新 case 全 PASS |
| 4 | **T-04**: 実 log で dry-run 実行 → evidence/ に reason 分布 + 追記予定 entry 数を保存 | docs/working/TASK-0110/evidence/dry-run-result.md | AI | low | 148 record 全件検出確認 |
| 5 | **T-05**: `docs/ai/skip-acknowledge-cli.md` 運用ガイド作成 (Human が適用する手順、dry-run → review → apply → CI 確認) | docs/ai/skip-acknowledge-cli.md | AI | low | Human が見て適用できる |
| 6 | **T-06**: handoff.md (Rule 5) + V-1 | docs/working/TASK-0110/handoff.md | AI | low | AC-1..7 PASS |

## Files / Components to Touch

| ファイル | 性質 |
|---------|------|
| `scripts/batch-acknowledge-skip-decisions.py` | 新規 |
| `tests/extras/ta-14-skip-acknowledge.sh` | 新規 |
| `tests/run-tests.sh` | dispatcher 追記 |
| `docs/ai/skip-acknowledge-cli.md` | 新規 (Human 適用ガイド) |
| `docs/working/TASK-0110/evidence/dry-run-result.md` | 新規 |
| `docs/working/TASK-0110/handoff.md` | WF-05 |

> **適用される側** (`docs/working/_audit/skip-decision-log.jsonl`) は AI 不可。Human が `--apply` 実行時に変更。

## Testing Strategy

- **Unit**: fixture jsonl 3 case (全 null / 一部 null / 全 ack 済) で batch スクリプト動作
- **Byte-equal 検証**: dry-run + apply で `--dry-run | sort` と適用後 `--check | sort` が一致 (acknowledged_by/at 2 field のみ差分)
- **CI**: 既存 `tests/run-tests.sh` 維持、新 case 追加

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| atomic RMW 失敗で jsonl 破損 | medium | .bak 保持 + os.replace pattern (TASK-0106 で実証済) |
| 既存 entry の他フィールド意図せず変更 | medium | byte-equal except 2 field を test で機械検証 |
| 一括追認で個別 reason 点検が形骸化 | low | dry-run 出力に reason 集計を含め、Human が点検対象選別可能 |
| Human が `--acknowledged-by` 空で実行 | low | 空文字 reject + 必須引数 validation |
| **PR merge と --apply の timing 矛盾 (R-001)** | medium | Human は **PR ブランチで --apply → apply コミット追加 → CI PASS → merge** の順を遵守。docs/ai/skip-acknowledge-cli.md に明記 |
| **JSON parse→dump で既存 key order/spacing 破壊 (R-002)** | medium | raw-line-preserving 方式採用、JSON parse は validation 用のみで write には使わない |
| **C-3 非同期降格で監査 CLI が無監視で進む (R-004)** | medium | C-3 同期固定明記、lite_eligible=false 維持 |

## Mode 判定

**light**

- 変更ファイル数: 5-6
- 受入基準数: 7
- 変更種別: スクリプト追加 + テスト + ドキュメント
- リスク: 中 (atomic RMW + 監査ファイル変更スクリプト)
- ロールバック: 容易 (.bak 復元)
- 影響範囲: skip-decision-log.jsonl の整備のみ、承認境界不変

→ light で進行。`lite_eligible=false` (新規スクリプト + 監査ファイル操作で完全な既存パターン踏襲ではない)
