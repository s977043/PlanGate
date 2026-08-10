# EXECUTION TODO — TASK-1023

> Plan: [`plan.md`](./plan.md) / Tests: [`test-cases.md`](./test-cases.md)
> Mode: **critical** / `lite_eligible=false` / Human C-3必須

## Dependency Graph

```text
T-01 Plan evidence → T-02 C-1 → T-03 C-2 → T-03b 追記2(R-026〜034)の1回確定反映 + 簡易C-1 → H-01 Human C-3（要 c3.json 再発行）
→ T-04 RED → T-05 fix → T-06 mutation/compat → T-07 full verification
→ T-08 Draft PR更新 → T-09 Hook E2E → T-10 evidence push/CI再確認
→ MERGE_READY → H-02 Human C-4/merge
```

## Human Tasks

- [ ] **H-01**: **再計算後の**確定plan hash、AC-01〜11、案B、critical、C-3'停止を確認してC-3判断。既発行`c3.json`（plan `24fcdf9f…`）はC-2追記2の反映で**stale**のため、**新plan_hashに対するc3.json再発行が必要**（AI は発行しない）
- [ ] **H-02**: Draft PRのsecurity closure・CI・reviewを確認しC-4/merge判断。**closureはEdit/Write/MultiEdit/Bashの4 surfaceに限定**（R-034 否定宣言）
- [ ] **H-03**: 既存approval artifact監査結果に基づき再承認範囲を決定（**母集団は全体・保護状態3区分** / R-030）
- [ ] **H-04**: `EH-10` の採番衝突（`settings-wiring-contract.md:152` ↔ `hook-enforcement.md:10-18` ↔ `settings.example.json:98`）の寄せ先を決定（plan「Human C-3 の判断事項」G-6）
- [ ] **H-05**: TTY起動を block 側で統一する副作用の許容可否（G-7）と、`parsed-safe` tool 集合の導出方式（G-8）を決定

## Agent Tasks

- [x] **T-01**: main/Issue/history/PoCをread-onlyで再検証
  - rollback: 不要（読取のみ）
- [x] **T-02**: Plan PackageとC-1セルフレビューを作成
  - rollback: Plan文書を削除せず、replan時は差分改訂とdecision-log追記
- [ ] **T-03**: C-2を設計妥当性・コードベース整合の2独立レーンで実施
  - checkpoint: critical/majorを反映後、簡易C-1を再実行
  - rollback: review-externalはappend-only。誤りは追記で訂正
- [x] **T-03b**: PR #1024 敵対的レビュー（major 5 / minor 3 / info 1）を `review-external.md`「追記 2」へ R-026〜R-034 として集約し、plan / todo / test-cases / pbi-input へ **1 回確定反映**。R-033（EH-10 ID 衝突）は Human 判断へ回し AI は正本を書き換えない
  - rollback: review-external は append-only。誤りは追記で訂正
- [ ] **T-04**: TA-25 legacy TC-01〜07を保持し、`T1023-TC-*` RED casesとstandalone rc伝播を追加
  - **`PG_T25_GUARD` の env override を実装**（`tests/extras/ta-25-approval-token-guard.sh:9` のハードコード解消 / R-029）
  - **legacy TC-03/04 を `< /dev/null`、TC-05 を valid normal payload の pipe に変更**（stdin未リダイレクトTCの根絶 / R-027）
  - **TC-02a/02b 分割・TC-13c-file/13c-cmd 分割・TC-22a/22b（MultiEdit）・TC-23（TTY非ハング）・TC-24 を追加**（R-026 / R-027 / R-028 / R-032）
  - depends_on: H-01
  - rollback: test commitを`git revert <sha>`。T-05より先に戻さない
- [ ] **T-05**: stdin常時capture・env/`$1`/stdin独立評価・exit 2・parse-unknown block・代表write surfaceを最小実装
  - depends_on: T-04
  - rollback: 実装commitを`git revert <sha>`。脆弱性復活中はC-3'停止を維持
- [ ] **T-06**: **mutation 5種**（exit / stdin capture / parse-unknown / `[ ! -t 0 ]`追加 / stdin抽出のenv再従属）、決定論的no-jq PATH、positive/negative/non-TTY CLIを実行。**kill は `PG_T25_GUARD` override 下で実TCがFAILすることで示す**（インラインassertのFAILはkillと認めない / R-029）
  - depends_on: T-05
  - rollback: FAIL時はT-05へ戻し、テストを弱めない
- [ ] **T-07**: syntax/focused/full suite/V-1〜V-4とgit履歴を含むread-only artifact監査（**母集団全体・保護状態3区分・起点根拠をhandoffへ** / R-030。**`$1` dead code と #928 drift の明記も必須** / R-031）
  - depends_on: T-06
  - rollback: evidenceを消さずFAILとして記録
- [ ] **T-08**: 明示fileだけcommit/pushしDraft PRを更新
  - depends_on: T-07
  - rollback: branch上でfollow-up commit。mainへ直接書かない
- [ ] **T-09**: configured Claude CodeでEdit/Write/**MultiEdit**/BashのPreToolUse E2Eを実行し、tool非実行・artifact不変を保存。**否定宣言（NotebookEdit / MCP write / Codex 経路は対象外）を併記**（R-034）
  - depends_on: T-08
  - rollback: 実行不能/FAILならBLOCKEDを維持しMERGE_READYにしない
- [ ] **T-10**: T-09 evidenceをcommit/pushし、新headのCI・CodeQL・reviewを再確認
  - depends_on: T-09
  - rollback: evidenceの誤りは削除せず訂正commitを追加し、再検証までBLOCKED
