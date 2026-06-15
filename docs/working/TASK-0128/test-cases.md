# TEST CASES: TASK-0128

> rev.2: C-2 指摘 R-001..R-008 反映。

## 受入基準 → テストケース マッピング

| AC | テストケース |
|----|------------|
| AC-01 | TC-01 |
| AC-02 | TC-02 |
| AC-03 | TC-03 |
| AC-04 | TC-04, TC-05 |
| AC-05 | TC-06 |
| AC-06 | TC-07, TC-12 |
| AC-07 | TC-08 |
| AC-08 | TC-09 |
| AC-09 | TC-10 |
| AC-10（新: schema 準拠） | TC-11 |
| AC-11（新: 三値分離） | TC-13 |

## テストケース一覧

### TC-01: 対話承認で c3.json 生成（正常系）
- 入力: `plangate approve TASK-XXXX`（TTY）
- 期待: approvals/c3.json（APPROVED）生成、終了コード 0
- 種別: integration

### TC-02: plan_hash 自動一致
- 期待: plan_hash が `plangate_sha256 plan.md` と一致 / 種別: integration

### TC-03: approved_by 自動解決 + identity 注記（R-006）
- 期待: approved_by=git config 値、`approver_identity_unverified: true` / `approved_by_source: git-config` を併記 / 種別: unit

### TC-04: 非対話拒否（パイプ / stdin リダイレクト）
- 入力: `plangate approve TASK-XXXX < /dev/null`
- 期待: L1 で拒否、c3.json 未生成、非ゼロ終了 / 種別: security

### TC-05: 非対話拒否（多層 env/ppid）
- 期待: maintenance と同等に L2/L3 拒否 / 種別: security

### TC-06: 三値発行（schema 必須フィールド付き / R-004）
- 入力: `--reject --reason "..."` / `--conditional --conditions "..."`
- 期待: REJECTED は rejection_reason、CONDITIONAL は conditions を含み生成 / 種別: unit
- 負例: `--reject` で reason 未指定 → エラー（schema 違反を未然に防止）

### TC-07: AI 直接書込 block — Edit|Write（R-002）
- 前提: hook 配線後
- 入力: AI が Write/Edit で approvals/c3.json を書く
- 期待: PreToolUse hook が block / 種別: verification

### TC-12: AI 直接書込 block — **Bash 経由**（R-002 中核）
- 前提: Bash matcher 配線後
- 入力: AI が Bash で `cat > docs/working/TASK-XXXX/approvals/c3.json`（or printf/tee）
- 期待: hook が Bash コマンド文字列から対象 path を検出し block / 種別: security
- 補足: 本セッションで実際に AI が試みた書込経路。Edit|Write のみでは防げないことの回帰防止

### TC-08: bin/plangate は apply-script 経由
- 入力: scripts/apply-task-0128-approve.sh --dry-run
- 期待: diff 表示、本体未変更、AI は実適用しない / 種別: verification

### TC-09: 再承認（plan 変更後）
- 期待: plan_hash が新 plan に更新され c3.json 上書き / 種別: integration

### TC-10: 承認後 validate PASS（APPROVED）
- 期待: APPROVED で validate PASS / 種別: integration

### TC-11: schema 検証（R-008）
- 入力: 生成した APPROVED/CONDITIONAL/REJECTED の c3.json
- 期待: `schemas/c3-approval.schema.json` で全て PASS（壊れた JSON は検出される） / 種別: unit/verification

### TC-13: 最終確認の分離（R-003）
- 入力: REJECTED/CONDITIONAL で approve
- 期待: validate を呼ばず（APPROVED 外 FAIL を誤発生させない）、schema 検証 + plan_hash 記録 + status 表示で完了 / 種別: integration

### 回帰
### TC-R1: maintenance 既存挙動不変（R-005）
- 入力: L1-L4 共通化後の `maintenance start`（TTY 許可 / 非対話拒否）
- 期待: 共通化前と同一挙動。`_maintenance` 生成・監査イベントが approve 実行時に混入しない / 種別: regression

## エッジケース
- plan.md 不在 → 明示エラー、c3.json 未生成
- git config user 未設定 → approved_by フォールバック（明示警告）or エラー
- approvals/ 未作成 → 自動 mkdir
- `--reject` と `--conditional` 同時指定 → エラー（排他）
