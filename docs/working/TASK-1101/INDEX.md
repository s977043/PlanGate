# TASK-1101 INDEX

> 生成日: 2026-08-15 / 最終更新: 2026-08-28（handoff 発行）
> **現在フェーズ**: `verify（L-0 / V-1〜V-4）`
> **総合判定（handoff §1 の判定語をそのまま転記）**: **8 / 11 PASS・3 WARN・0 FAIL**
> （WARN = AC-6 `run-tests.sh` 通し未実施 / AC-7 追跡 issue 未起票 / AC-8 fail-closed の plan 逸脱）
> 判定の正本は [`handoff.md`](./handoff.md) §1 → [`status.md`](./status.md) → 本ファイルの順。

## 次のアクション

1. 👤 **H-02**: `sh scripts/apply-1101-ho-normalization.sh --apply`（HO 対象パスのため Human-owned）→ 成功したら `tests/fixtures/eh3-normalization-pending-1101.flag` を削除
2. 🤖 オーケストレータ: 未起票の追跡 issue 2 件（FS エイリアス / `ta-45` TC-01）を起票 → AC-7 が PASS になる
3. CI で `sh tests/run-tests.sh` の緑を確認（AC-6 の degrade 解消）
4. 👤 **H-03**: C-4 ゲート

## ファイル一覧

| ファイル | 状態 |
| --- | --- |
| pbi-input.md | final（AC-1〜AC-11）|
| plan.md | **final v4 / C-3 APPROVED（編集禁止・`plan_hash` 一致）** |
| todo.md | final |
| test-cases.md | final（TC-01〜TC-14 + TC-11b）|
| review-self.md / review-self-2.md | final |
| review-external.md | final（R-001〜R-013 / S-1〜S-4）|
| status.md | 更新中 |
| current-state.md | 更新中 |
| **handoff.md** | **発行済み（2026-08-28 / `82dbe8e`）** |
| evidence/ | test-runs 7 本 / c2-review 1 本 |

## 変更ファイル（実装側）

| ファイル | 種別 |
| --- | --- |
| `tests/fixtures/pg-fold-path.sh` | 正規化関数の**正本**（新規）|
| `scripts/apply-1101-ho-normalization.sh` | patch 適用スクリプト（新規 / 実適用は Human）|
| `tests/extras/ta-65-eh3-ho-task-context.sh` | TC-06 拡充 / TC-07 反転 / TC-08〜TC-12 / **TC-09c** |
| `tests/extras/ta-67-pg-fold-path-portability.sh` | 4 シェル可搬性（新規）|
| `tests/fixtures/eh3-normalization-pending-1101.flag` | PENDING-APPLY flag（新規 / 適用時に削除）|
| `docs/ai/hook-enforcement.md` | 既知の残存 + 残存脅威モデル |
| `scripts/apply-eh3-ho-always.sh` / `scripts/fix-eh3-doc-light-maint-guard.sh` | 退役注記 |
| `scripts/hooks/check-plan-hash.sh` | **未変更（HO 対象パス / Human 適用待ち）** |
