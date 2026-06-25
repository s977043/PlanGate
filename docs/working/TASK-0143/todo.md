# TASK-0143 EXECUTION TODO — hook 6→12 配線

> mode=high-risk / lite_eligible=false。L-0〜V-4・PR は workflow-conductor が自動制御するため本リストに含めない。

## 👤 Human ゲート

- [ ] **C-3**: 本 plan の承認（exec 前ゲート）。特に **群B発火層 candidate1（conductor 単一判定層）** と **EH-7 GH連携の別PBI切出し** を明示判断
- [ ] **C-4**: PR レビュー（GitHub 上）

## 🤖 Agent タスク

### 準備
- [ ] T1: EH-4/5/7 の現行呼出箇所を conductor 定義 / CI / bin/plangate で棚卸し（重複配線回避）｜owner: agent｜🚩配線先確定｜rollback: 不要（読取のみ）
- [ ] T2: `validation_bias` の現参照箇所（model-profiles.yaml 消費層）を特定し群B発火層の接続点を確定｜owner: agent｜🚩Unknown1 解消｜rollback: 不要（読取のみ）

### 実装
- [ ] T3: 群A配線 — conductor のフェーズ前（V-1前/PR前/merge前）に EH-4/5/7 CLI 呼出を追加（default=warning）｜owner: agent｜🚩既定挙動不変｜rollback: conductor 定義の該当呼出行を revert
- [ ] T4: CI ガード — `.github/workflows/*.yml` に PR/merge 時の EH-5/EH-7 呼出を追加｜owner: agent｜🚩CI 失敗時の影響確認｜rollback: workflow 差分 revert
- [ ] T5: `doctor --check-settings` を群A含む必須 hook 表に拡張し drift を exit≠0 検出｜owner: agent｜🚩既存6hook検証の非退行｜rollback: check-settings-wiring.sh 差分 revert
- [ ] T6: 群B配線 — C-3 確定案で conductor が strict 時のみ EHS-1〜3 を発火｜owner: agent｜🚩strict限定・既定OFF回帰｜rollback: conductor の EHS 呼出ブロック revert
- [ ] T7: `docs/ai/hook-enforcement.md` 配線表を 12/12 に更新（doctor 出力と一致）｜owner: agent｜🚩doc整合｜rollback: doc 差分 revert

### 検証
- [ ] T8: `tests/extras/ta-06-hooks.sh` を拡張し EH-4/5/7 呼出を assert｜owner: agent｜rollback: テスト差分 revert
- [ ] T9: doctor wiring negative test（群A未配線→exit≠0）追加｜owner: agent｜rollback: テスト差分 revert
- [ ] T10: 群B回帰 — 非strict既定で EHS-1〜3 非発火を assert｜owner: agent｜rollback: テスト差分 revert
- [ ] T11: `sh tests/run-tests.sh` 全 PASS（V-1 受け入れ検査の前提）｜owner: agent｜rollback: 不要（検証のみ）

### 完了
- [ ] T12: handoff.md 生成（必須6要素）｜owner: agent

## ⚠️ 依存関係

- T3〜T6（実装）は T1/T2（棚卸し）完了後
- T6（群B）は **C-3 で発火層確定後**にのみ着手（未確定なら T6 は保留・群A配線のみで段階リリース可）
- T8〜T11（検証）は対応する実装ステップ完了後
