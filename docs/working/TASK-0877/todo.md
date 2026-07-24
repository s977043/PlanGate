# EXECUTION TODO — TASK-0877

> 入力: [`plan.md`](./plan.md) / [`test-cases.md`](./test-cases.md)
> Mode: `high-risk`（`lite_eligible=false`）
> 実行方式: ai-loop（C-3' 裁定 → `HUMAN_ESCALATED` 見込み → Human C-3）

## 👤 Human タスク

- [ ] H-1: **C-3 ゲート**（plan.md Questions 6 論点の判定 → `bin/plangate approve TASK-0877` を対話 TTY で実行）
  - depends_on: A-3（C-1）/ A-4（C-2）/ ai-loop run 結果
  - 🚩 checkpoint: `approvals/c3.json` の `plan_hash` が確定 plan と一致
- [ ] H-2: **C-4 ゲート**（PR レビュー → merge）
  - depends_on: A-12
  - 🚩 checkpoint: CI 全緑・AC-1〜9 の Completion Evidence 提示済み

## 🤖 Agent タスク

### 準備

- [ ] A-1: 現行 guard 実体と CI 起動経路の再実測（`sync-plugin-plangate.sh` L64-82〔判定式 L79〕/ workflow L51・L76）
  - Output: 実測ログ（plan Metrics Evidence の裏取り）
  - rollback: 不要（読取のみ）
- [ ] A-2: ベースライン取得 — `sh tests/run-tests.sh` をクリーンな作業ツリーで 1 回実行し passed/failed を記録
  - Output: ベースライン件数
  - rollback: 不要（読取のみ）
- [ ] A-3: **C-1 セルフレビュー**（25 項目）→ `review-self.md`（`C1-VERDICT: PASS plan=sha256:<hash>` マーカー付き）
  - depends_on: A-1, A-2
  - 🚩 checkpoint: FAIL があれば plan へ戻す
  - rollback: `review-self.md` を削除して再生成
- [ ] A-4: **C-2 外部レビュー 2 レーン**（設計妥当性レーン / コードベース整合レーン）→ `review-external.md`（R-NNN 採番 + `C2-VERDICT: approve plan=sha256:<hash>`）
  - depends_on: A-3
  - 🚩 checkpoint: critical/major は 1 回確定反映 → 簡易 C-1 再実行（plan_hash 変化に注意）
  - rollback: `review-external.md` を削除して再生成
- [ ] A-5: **ai-loop run**（`python3 scripts/ai-loop/plan_package.py` 検証 → arbiter 裁定 → record 保存）
  - depends_on: A-3, A-4, H-1 前
  - 🚩 checkpoint: exit 2（`HUMAN_ESCALATED`）を record に保存し H-1 へ引き渡す。exit 0 が返った場合は plan の予測と食い違うため **停止して人間判断**
  - rollback: record を削除（判定は非破壊）

### 実装（H-1 承認後）

- [ ] A-6: F2 — guard 判定式を stale ベース（`_stale_count > _src_count`）へ変更
  - Output: `scripts/sync-plugin-plangate.sh` 差分
  - rollback: `git checkout -- scripts/sync-plugin-plangate.sh`
- [ ] A-7: F1 — `guard_fired` フラグ + `PLANGATE_ALLOW_MASS_DELETE` override + 終端 exit 3（dry-run は exit 0 維持）
  - depends_on: A-6
  - 🚩 checkpoint: `sh -n` syntax OK・実 repo dry-run で発火しないこと
  - rollback: 同上
- [ ] A-8: F3 — `tests/run-tests.sh` に `PG_HARNESS_SOURCED=1` を追加し、`ta-26` L9 をそれ参照へ
  - rollback: `git checkout -- tests/run-tests.sh tests/extras/ta-26-plugin-sync.sh`
- [ ] A-9: F4 + AC-8/AC-9 — TC-09 / TC-10 / TC-11 / TC-12（src=3 / stale=4）/ TC-13（自己再帰しない設計）/ TC-16（複数 label）追加 + TC-03 判定式是正 + 冒頭に判別方式の方針コメント
  - depends_on: A-7, A-8
  - 🚩 checkpoint: 全 TC が `rc=0; out="$(cmd)" || rc=$?` の正書式・sandbox は TC-08 と同じ最小構成
  - rollback: `git checkout -- tests/extras/ta-26-plugin-sync.sh`

### 検証

- [ ] A-10: Verification Automation 実行 — `sh tests/run-tests.sh && sh tests/extras/ta-26-plugin-sync.sh`
  - depends_on: A-9
  - 🚩 checkpoint: exit 0・A-2 ベースラインから既存 TC の退行ゼロ
  - rollback: 不要（読取のみ）
- [ ] A-11: **V-1 受け入れ検査** — `test-cases.md` の TC-01〜TC-16（TC-14/TC-15 は文書・差分検査）を機械突合し AC-1〜9 を PASS/FAIL 判定
  - depends_on: A-10
  - rollback: 不要
- [ ] A-12: AC-6 follow-up issue を起票し番号を plan/handoff に記録。スコープ = ①F5（src 駆動の無ガード削除 **2 経路**: L140-150 / L283-296）②R-204（`tests/extras/README.md` の harness 判別規約追記 + 既存 11 extras の `PG_HARNESS_SOURCED` 移行）
  - depends_on: A-11
  - rollback: issue を close

### 完了

- [ ] A-13: `handoff.md` 発行（必須 6 要素）+ `status.md` / `current-state.md` / `decision-log.jsonl` 更新
  - depends_on: A-11, A-12
- [ ] A-14: PR 作成前レビュー（セルフ + 複数エージェント敵対レビュー + River Review ローカル）→ 指摘是正 → PR 作成
  - depends_on: A-13
  - 🚩 checkpoint: critical/major ゼロ収束
  - rollback: PR を close してブランチ再作成

## ⚠️ 依存関係

- A-5（ai-loop run）は A-3/A-4 の evidence マーカーが揃って初めて実行可能（`plan_package.py` が fail-closed）
- A-6〜A-9 は H-1（C-3 承認）後に着手（EH-3 が plan_hash 一致を要求）
- A-12 は AC-6 の充足条件そのもの（記録だけでなく実 issue 番号が必要）
