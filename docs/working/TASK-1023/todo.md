# EXECUTION TODO — TASK-1023

> Plan: [`plan.md`](./plan.md) / Tests: [`test-cases.md`](./test-cases.md)
> Mode: **critical** / `lite_eligible=false` / Human C-3必須

## Dependency Graph

```text
T-01 Plan evidence → T-02 C-1 → T-03 C-2 → H-01 Human C-3
→ T-04 RED → T-05 fix → T-06 mutation/compat → T-07 full verification
→ T-08 Draft PR更新 → T-09 Hook E2E → T-10 evidence push/CI再確認
→ MERGE_READY → H-02 Human C-4/merge
```

## Human Tasks

- [ ] **H-01**: 確定plan hash、AC-01〜11、案B、critical、C-3'停止を確認してC-3判断
- [ ] **H-02**: Draft PRのsecurity closure・CI・reviewを確認しC-4/merge判断
- [ ] **H-03**: 既存approval artifact監査結果に基づき再承認範囲を決定

## Agent Tasks

- [x] **T-01**: main/Issue/history/PoCをread-onlyで再検証
  - rollback: 不要（読取のみ）
- [x] **T-02**: Plan PackageとC-1セルフレビューを作成
  - rollback: Plan文書を削除せず、replan時は差分改訂とdecision-log追記
- [ ] **T-03**: C-2を設計妥当性・コードベース整合の2独立レーンで実施
  - checkpoint: critical/majorを反映後、簡易C-1を再実行
  - rollback: review-externalはappend-only。誤りは追記で訂正
- [ ] **T-04**: TA-25 legacy TC-01〜07を保持し、`T1023-TC-*` RED casesとstandalone rc伝播を追加
  - depends_on: H-01
  - rollback: test commitを`git revert <sha>`。T-05より先に戻さない
- [ ] **T-05**: stdin常時capture・env/`$1`/stdin独立評価・exit 2・parse-unknown block・代表write surfaceを最小実装
  - depends_on: T-04
  - rollback: 実装commitを`git revert <sha>`。脆弱性復活中はC-3'停止を維持
- [ ] **T-06**: mutation 3種、決定論的no-jq PATH、positive/negative/non-TTY CLIを実行
  - depends_on: T-05
  - rollback: FAIL時はT-05へ戻し、テストを弱めない
- [ ] **T-07**: syntax/focused/full suite/V-1〜V-4とgit履歴を含むread-only artifact監査
  - depends_on: T-06
  - rollback: evidenceを消さずFAILとして記録
- [ ] **T-08**: 明示fileだけcommit/pushしDraft PRを更新
  - depends_on: T-07
  - rollback: branch上でfollow-up commit。mainへ直接書かない
- [ ] **T-09**: configured Claude CodeでEdit/Write/BashのPreToolUse E2Eを実行し、tool非実行・artifact不変を保存
  - depends_on: T-08
  - rollback: 実行不能/FAILならBLOCKEDを維持しMERGE_READYにしない
- [ ] **T-10**: T-09 evidenceをcommit/pushし、新headのCI・CodeQL・reviewを再確認
  - depends_on: T-09
  - rollback: evidenceの誤りは削除せず訂正commitを追加し、再検証までBLOCKED
