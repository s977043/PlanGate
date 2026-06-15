# EXECUTION TODO: TASK-0128

> rev.2: C-2 指摘 R-001..R-008 反映。Mode=critical。

## 🤖 Agent タスク

### 準備
- [ ] T01 maintenance L1-L4 実装精読・context 引数付き共通化方針確定（R-005） — Owner: agent / depends_on: - / files: bin/plangate
- [ ] T02 c3-approval.schema.json の三値必須フィールド確認（conditions/rejection_reason / R-004） — Owner: agent / depends_on: - / files: schemas/c3-approval.schema.json
- [ ] T03 既存 check-approval-token-write.sh の Bash 対応要否確認（R-002）+ TASK-0123 配線責務確認（R-001） — Owner: agent / depends_on: - / files: scripts/check-approval-token-write.sh

### 実装（すべて apply-script 経由・bin/plangate 直接編集なし）
- [ ] T04 L1-L4 を context 引数付き共通関数へ抽出（副作用分離 / R-005） — Owner: agent / depends_on: T01 / files: scripts/apply-task-0128-approve.sh 🚩
- [ ] T05 cmd_approve 引数解析（TASK / --reject --reason / --conditional --conditions / R-004） — Owner: agent / depends_on: T04 / files: scripts/apply-task-0128-approve.sh
- [ ] T06 Human-presence 検証→失敗で非ゼロ終了（自己承認不可） — Owner: agent / depends_on: T04 / files: scripts/apply-task-0128-approve.sh 🚩
- [ ] T07 plan_hash 算出 + approved_by 解決 + identity_unverified 注記（R-006） — Owner: agent / depends_on: T05 / files: scripts/apply-task-0128-approve.sh
- [ ] T08 三値 c3.json 生成（schema 準拠・条件付き必須フィールド / R-004） — Owner: agent / depends_on: T07 / files: scripts/apply-task-0128-approve.sh 🚩
- [ ] T09 最終確認の分離: APPROVED のみ validate / 他は schema+status（R-003） — Owner: agent / depends_on: T08 / files: scripts/apply-task-0128-approve.sh 🚩
- [ ] T10 既存 c3.json 上書き（再承認・plan_hash 更新） — Owner: agent / depends_on: T08 / files: scripts/apply-task-0128-approve.sh
- [ ] T11 dispatch approve) + help 追記 — Owner: agent / depends_on: T05 / files: scripts/apply-task-0128-approve.sh
- [ ] T12 check-approval-token-write.sh を Edit|Write + **Bash** matcher で配線 + Bash path 検出（R-002） — Owner: agent / depends_on: T03 / files: scripts/apply-task-0128-approve.sh, scripts/check-approval-token-write.sh 🚩
- [ ] T13 apply-script 完成（冪等・--dry-run・アンカー検証・settings example 同期 / R-002） — Owner: agent / depends_on: T08,T11,T12 / files: scripts/apply-task-0128-approve.sh 🚩
- [ ] T14 ドキュメント更新（C-3 手順 → plangate approve） — Owner: agent / depends_on: T08 / files: docs/

### 検証
- [ ] T15 unit: plan_hash / approved_by / 三値生成 — Owner: agent / depends_on: T08 / files: evidence/test-runs/
- [ ] T16 schema 検証: APPROVED/CONDITIONAL/REJECTED の c3.json が schema PASS（R-008） — Owner: agent / depends_on: T08 / files: evidence/test-runs/ 🚩
- [ ] T17 integration: 対話 TTY で approve(APPROVED)→validate PASS — Owner: agent / depends_on: T13 / files: evidence/verification/ 🚩
- [ ] T18 security 負例: 非対話 approve 拒否 + **Bash `cat > approvals/c3.json` を hook block**（R-002） — Owner: agent / depends_on: T06,T12 / files: evidence/verification/ 🚩
- [ ] T19 分離確認: REJECTED/CONDITIONAL で validate 非実行・schema+status 完了（R-003） — Owner: agent / depends_on: T09 / files: evidence/verification/
- [ ] T20 回帰: maintenance start/stop 既存挙動不変（R-005） — Owner: agent / depends_on: T04 / files: evidence/test-runs/ 🚩

### 完了
- [ ] T21 status/handoff 更新、apply-script dry-run 出力を evidence 保存 — Owner: agent / depends_on: T15,T16,T17,T18,T19,T20 / files: docs/working/TASK-0128/

## 👤 Human タスク
- [ ] H01 C-3: plan 承認（bootstrap interim 手段） — Owner: human / depends_on: C-1
- [ ] H02 apply-task-0128-approve.sh を dry-run → 適用（bin/plangate + settings + example） — Owner: human / depends_on: T13 ⚠️ AI 実行不可（HO/self-mod）
- [ ] H03 適用後 plangate approve で TASK-0127/0128 を正規承認（コンセプト達成確認） — Owner: human / depends_on: H02
- [ ] H04 C-4: PR レビュー — Owner: human / depends_on: PR

## ⚠️ 依存関係
- H02（HO + settings self-mod 適用）は人間専任。AI は dry-run のみ
- 本 PBI の C-3（H01）は機構未完成のため interim、完成後 H03 で正規化
