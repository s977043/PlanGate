# EXECUTION TODO — TASK-1036

> Plan: [`plan.md`](./plan.md) / Tests: [`test-cases.md`](./test-cases.md)
> Mode: **standard** / `lite_eligible=false` / Human C-3 必須（同期）

## Dependency Graph

```text
T-01 前提再実測 → T-02 Plan + C-1 → (C-2 任意) → H-01 Human C-3（c3.json 初回発行）
→ T-03 RED（ta-62 作成 + 修正前 FAIL 証跡）→ T-04 案 (d) 本体 → T-05 README 追記
→ T-06 変異注入検証 → T-07 3 系統 + harness 同値照合 + full suite → T-08 status/handoff
→ PR 作成 → H-02 Human C-4 / merge
```

## Human Tasks

- [ ] **H-01** 👤: C-3 判断。確認事項 — (1) 案 (d) 採用（vs 案 (a)+carve-out）、(2) Mode=standard / `lite_eligible=false`、(3) T1036-TC-D の suite 追加時間（実測 約 +90 秒見込み / plan R-P7）の許容、(4) AC 候補-1 の採否。**確定後 plan_hash に対する c3.json 初回発行**（AI は発行しない）
- [ ] **H-02** 👤: C-4 / merge 判断。既知残存（直接 standalone 起動経路 / ta-61 同型クラス）が handoff に明記されていることを確認

## Agent Tasks

- [x] **T-01**: 前提の実測再検証（P-1〜P-10 / plan「前提の実測検証」表）
  - rollback: 不要（読取のみ）
- [x] **T-02**: Plan Package + C-1 セルフレビュー作成
  - rollback: 文書は削除せず差分改訂 + decision-log 追記
- [ ] **T-03**: RED — `tests/extras/ta-62-t26-recurse-env-guard.sh` を #921 契約 checklist 準拠で新規作成（T1036-TC-D / T1036-TC-S）。修正前 tree で両 TC が FAIL する証跡を `evidence/test-runs/red.log` に保存
  - depends_on: H-01
  - 🚩 checkpoint: FAIL 理由が「leak 実行に再帰防止 `[SKIP]` が出る / 配置検査不成立」であること（別要因の FAIL は設計不備として停止）
  - rollback: test commit を `git revert <sha>`。T-04 より先に戻さない
- [ ] **T-04**: 案 (d) 本体 — `ta-26` harness 分岐（`PG_T26_STANDALONE=0` の else 節）へ `unset PG_T26_NO_RECURSE` + 禁止理由コメントを追加
  - depends_on: T-03
  - 🚩 checkpoint: T-03 の RED が GREEN 化 + `PG_T26_NO_RECURSE=1` 前置の直接起動で従来どおり skip 挙動（AC-3 の即時確認）
  - rollback: 実装 commit を `git revert <sha>`（漏れ穴が戻るだけで既存挙動不変）
- [ ] **T-05**: `tests/extras/README.md` 規約 7 / 8 追記（AC-5）。TC-30 の grep 対象文言は変更しない
  - depends_on: T-04
  - rollback: doc commit を `git revert <sha>`
- [ ] **T-06**: 変異注入検証 — M-1（動的 kill）/ M-2（静的 kill・**動的実行禁止**）/ M-3（sandbox で既存 TC-33 FAIL 再確認）。ログを `evidence/test-runs/mutation.log` へ
  - depends_on: T-04
  - 🚩 checkpoint: kill は実 TC（T1036-TC-D / T1036-TC-S / TC-33）の FAIL で示す。インライン assert の FAIL を kill と申告しない
  - rollback: 検証成果物は削除せず FAIL として記録、T-03/T-04 へ戻す
- [ ] **T-07**: 3 系統（harness / standalone / 子相当前置）0 failed + `PG_T26_NO_RECURSE=1` export 下と env なしの `sh tests/run-tests.sh` 2 回実走 → `ta-26` セクション diff 完全一致（AC-1）。TC-33 PASS 確認（AC-4）。T1036-TC-D の suite 追加時間を実測記録（plan S-5: +120 秒超で停止）
  - depends_on: T-05, T-06
  - rollback: 不要（検証のみ）
- [ ] **T-08**: status.md / handoff.md 整備（既知残存: 直接 standalone 起動経路・`PG_T61_NO_RECURSE` 同型クラスを V2 候補へ）
  - depends_on: T-07
  - rollback: addendum で訂正

## ⚠️ 依存関係・注意

- L-0 / V-1〜V-3 / PR 作成は workflow-conductor が自動制御（本 todo に含めない。standard のため V-2 / V-4 はスキップ）
- **M-2（案 (c) 型変異）は絶対に動的実行しない**（孫 spawn 再入ループ / plan S-3）
- exec 開始時に base SHA `48f6971` からの `tests/` 差分有無を確認（plan S-1 / R-P9）
