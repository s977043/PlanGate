# EXECUTION TODO — TASK-0970

> 入力: [`plan.md`](./plan.md) / [`test-cases.md`](./test-cases.md)
> Mode: `standard`（lite 4 軸 = true / `boundary=clean`）
> 実行方式: ai-loop（C-3' 裁定 → `AUTO_APPROVED` 見込み。escalate 時は Human C-3）

## 👤 Human タスク

- [ ] H-1: **C-4 ゲート**（PR レビュー → merge）
  - depends_on: A-8
  - 🚩 checkpoint: CI 全緑・AC-1〜4 の Completion Evidence 提示済み
  - 備考: C-3' が `HUMAN_ESCALATED` を返した場合は H-0（Human C-3）が先行して必要になる

## 🤖 Agent タスク

### 準備

- [ ] A-1: baseline 再実測 — clean env で `sh tests/run-tests.sh` と
      `sh tests/extras/ta-26-plugin-sync.sh` を 1 回ずつ実行し passed/failed を記録
  - Output: baseline 件数（plan の 537 / 30+1 と突合）
  - rollback: 不要（読取のみ）
- [ ] A-2: **C-1 セルフレビュー** → `review-self.md`（`C1-VERDICT: PASS plan=sha256:<hash>` マーカー付き）
  - depends_on: A-1
  - 🚩 checkpoint: FAIL があれば plan へ戻す
  - rollback: `review-self.md` を削除して再生成
- [ ] A-3: **C-2 外部レビュー 2 レーン**（設計妥当性 / コードベース整合）→ `review-external.md`
      （R-NNN 採番 + `C2-VERDICT: approve plan=sha256:<hash>`）
  - depends_on: A-2
  - 🚩 checkpoint: critical/major は 1 回確定反映 → 簡易 C-1 再実行（plan_hash 変化に注意）
  - rollback: `review-external.md` を削除して再生成
- [ ] A-4: **C-3' 裁定**（Plan Package 検証 → W チェック 2 体 → arbiter 裁定 → record 保存）
  - depends_on: A-2, A-3
  - 🚩 checkpoint: `AUTO_APPROVED` なら実装へ。`HUMAN_ESCALATED` なら停止して Human C-3 を待つ
  - rollback: record を削除（判定は非破壊）

### 実装（C-3' 承認後）

- [ ] A-5: 集計と削除の非対称を解消 — dst 側 stale 集計ループの
      `[ -L "$_rf" ] && continue`（L206）を削除
  - Output: `scripts/sync-plugin-plangate.sh` の 1 行削除差分
  - 🚩 checkpoint: `sh -n scripts/sync-plugin-plangate.sh` が syntax OK・
        実リポジトリ `--dry-run` で guard が発火しないこと
  - rollback: `git checkout -- scripts/sync-plugin-plangate.sh`
- [ ] A-6: TC-35 追加（symlink stale 混入で「集計 = 削除」を検証。
      ダングリング symlink の対称除外も同 TC で固定）
  - depends_on: A-5
  - Output: `tests/extras/ta-26-plugin-sync.sh` の TC 追加差分
  - 🚩 checkpoint: `_t26_mk_refs_guard_sandbox` のシグネチャを変更していないこと
  - rollback: `git checkout -- tests/extras/ta-26-plugin-sync.sh`

### 検証

- [ ] A-7: **変異注入 M-1**（AC-2） — 削除した 1 行を復元した実装（= 修正前実装）に対して
      TC-35 が FAIL することを実測し、ログを evidence へ残す
  - depends_on: A-6
  - 🚩 checkpoint: FAIL しなければ RT-2 発火 → fixture 再設計
  - rollback: 不要（一時コピーに対する検証。正本には触れない）
- [ ] A-8: Verification Automation 実行 —
      `sh tests/extras/ta-26-plugin-sync.sh && sh tests/run-tests.sh` が exit 0
  - depends_on: A-7
  - 🚩 checkpoint: baseline+1（538 passed / 0 failed）と一致すること。不一致なら RT-4
  - rollback: 不要（読取のみ）

### 完了

- [ ] A-9: AC-1〜4 の突合（V-1 受け入れ検査）→ `status.md` / `current-state.md` 更新
  - depends_on: A-8
  - rollback: 不要（記録のみ）
- [ ] A-10: `handoff.md` 発行（必須 6 要素）→ PR 作成
  - depends_on: A-9
  - rollback: PR を close

## ⚠️ 依存関係

- A-5 は **A-4（C-3' 承認）完了まで着手不可**（Plan-first 束縛）
- A-7（変異注入）は A-6 完了後にのみ意味を持つ（TC が存在しないと検出力を測れない）
- H-1（C-4 / merge）は **Human-owned 固定**。AI は merge しない（NO MERGE BY AI）

## 実行時の共通規律

- テスト実行は clean env（`PLANGATE_HOOK_TASK` / `PLANGATE_HOOK_FILE` /
  `PG_HARNESS_SOURCED` / `FIXTURES_DIR` / `PLANGATE_ALLOW_MASS_DELETE` を unset）、
  かつ stdin リダイレクト付き（`sh <対象ファイル> </dev/null`）
- 変更は Files / Components to Touch の範囲内に限定する。逸脱が必要になった時点で停止
