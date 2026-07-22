# TEST CASES — TASK-0873

> plan: [`plan.md`](./plan.md)。必須 fixture 10 件（issue #873 verbatim）を TC-01〜10 に 1:1 対応させる。

## 受入基準 → テストケース マッピング

| 受入基準 | テストケースID | 種別 |
|---------|--------------|------|
| AC-1 状態遷移の機械可読契約 | TC-11, TC-12 | Unit |
| AC-2 旧 head SHA の CI success で MERGE_READY にならない | TC-06 | Unit/E2E |
| AC-3 required review pending で MERGE_READY にならない | TC-02 | Unit |
| AC-4 CI failure → 修正・push・再評価遷移（taxonomy 5 分類） | TC-03, TC-13 | Unit/E2E |
| AC-5 review 指摘 → 修正 commit / evidence 付き不採用の追跡 | TC-04, TC-05 | Unit |
| AC-6 Plan 外修正 → exec 差し戻し or C-3' 再裁定 | TC-14 | Unit |
| AC-7 conflict 解消後の三点照合 + 再評価 | TC-07 | Unit |
| AC-8 round 4 へ進まず HUMAN_ESCALATED | TC-08, TC-E1 | Unit |
| AC-1/判断表 全 8 行の正規化（優先度 3 / 7-8 分離） | TC-22, TC-23 | Unit |
| AC-10 中断原子性（intent/receipt） | TC-E5, TC-E6 | Unit |
| AC-9 permission/API 不明で成功扱いせず HUMAN_ESCALATED | TC-09 | Unit |
| AC-10 resume 冪等（重複なし） | TC-10, TC-15 | Unit/E2E |
| AC-11 MERGE_READY record 6 フィールド | TC-16 | Unit |
| AC-12 merge 実行経路なし・C-4 待ち停止 | TC-17, TC-18 | Unit/E2E |

## テストケース一覧（fixture 10 = TC-01〜10）

### TC-01: CI pending（fixture 1）

- 前提条件: c3-prime AUTO_APPROVED record + PR_CREATED record
- 入力: snapshot（head=H1, checks=pending, reviews=none）
- 期待出力: サブステート `WAITING_FOR_CHECKS`・MERGE_READY にならない・アクション=待機
- 種別: Unit

### TC-02: CI green・review pending（fixture 2）

- 前提条件: 同上
- 入力: snapshot（head=H1, checks=success@H1, required review=pending）
- 期待出力: `WAITING_FOR_REVIEW`・MERGE_READY にならない（AC-3）
- 種別: Unit

### TC-03: CI fail → repair → green（fixture 3）

- 前提条件: 同上
- 入力: snapshot1（checks=failure, taxonomy=code）→ repair 記録（round 1, commit C1）→ snapshot2（head=H2, **H2 の全 checks green + required review 着弾済み approve + 全 disposition 解決**）
- 期待出力: `CHECKS_FAILED`→repair アクション→再評価で `MERGE_READY`。round=1 が record に残る。**repair 後条件のいずれか未充足（旧 head の checks / review 未着弾 / disposition 未解決）なら `WAITING_FOR_CHECKS` / `WAITING_FOR_REVIEW` に留まる負側も検証**（Refs: R-001）
- 種別: Unit + E2E（ta-56 実走）

### TC-04: major review → repair → re-review（fixture 4）

- 前提条件: 同上
- 入力: finding(major) → disposition=adopted(repair_commit=C2) → 再評価 snapshot（**repair 後 head の全 checks green + re-review 着弾を明示**）
- 期待出力: `REVIEW_REPAIR` → disposition 解決 + fresh CI/review 充足後にのみ MERGE_READY 候補へ（未充足は該当 WAITING 系に留まる / Refs: R-001）
- 種別: Unit

### TC-05: false positive → 実測 evidence 付き不採用（fixture 5）

- 前提条件: 同上
- 入力: finding(major) → disposition=rejected(evidence_ref=実測ログパス)
- 期待出力: evidence_ref 必須（欠落なら未解決扱いで MERGE_READY 拒否）。付与時は解決済み
- 種別: Unit

### TC-06: stale CI on old SHA（fixture 6）

- 前提条件: 同上
- 入力: snapshot（head=H2, checks=success@H1）
- 期待出力: MERGE_READY **拒否**（AC-2）。`WAITING_FOR_CHECKS` へ
- 種別: Unit + E2E

### TC-07: merge conflict → 解消 → 再評価（fixture 7）

- 前提条件: 同上
- 入力: snapshot（mergeable=CONFLICTING）→ 解消記録（base/head/result 三点照合フィールド付き）→ 再評価 snapshot
- 期待出力: `CONFLICT` → 三点照合欠落なら fail-closed（解消と認めない）→ 照合付きで CI/review 再評価を強制
- 種別: Unit

### TC-08: round limit 超過（fixture 8）

- 前提条件: record に round=3 の repair 履歴
- 入力: 4 回目の repair を要する snapshot
- 期待出力: `HUMAN_ESCALATED`（round 4 に進まない・AC-8）
- 種別: Unit

### TC-09: API permission 不足（fixture 9）

- 前提条件: 同上
- 入力: snapshot（taxonomy=permission または checks 取得不能フラグ）
- 期待出力: `HUMAN_ESCALATED`（成功扱いしない・AC-9）
- 種別: Unit

### TC-10: process 中断 → resume（fixture 10）

- 前提条件: TC-03 途中の record
- 入力: 同一 snapshot で assess を 2 回実行
- 期待出力: 2 回目はアクション重複ゼロ（**stable action ID = canonical payload sha256 + intent/receipt 2 段**で抑止・AC-10 / Refs: R-005）。record 追記も重複しない。同一 head/round で **finding_id が異なる同種アクションは誤抑止されない**ことも検証
- 種別: Unit + E2E（ta-56 で実走）

## 追加テストケース

### TC-11: contract emit（AC-1）

- 入力: `delivery.py contract`
- 期待出力: TRANSITIONS の JSON（決定論・2 回実行 byte 同一）
- 種別: Unit

### TC-12: doc↔contract 整合（AC-1）

- 入力: contract emit + delivery-state-machine.md の遷移表
- 期待出力: 状態集合・遷移集合が一致（drift 検出で FAIL）
- 種別: E2E（ta-56）

### TC-13: taxonomy 5 分類の網羅（AC-4）

- 入力: taxonomy = code / flaky / environment / permission / unknown の各 snapshot
- 期待出力: code/flaky/environment→repair 系遷移、permission/unknown→HUMAN_ESCALATED。**未知の分類値→fail-closed（HUMAN_ESCALATED）**
- 種別: Unit

### TC-14: Plan 逸脱（AC-6）

- 入力: snapshot（changed_files に plan の Files to Touch 外パス）
- 期待出力: `EXEC_RETURN`（exec 差し戻し）or C-3' 再裁定要求。MERGE_READY 不可
- 種別: Unit

### TC-15: resume 冪等の E2E（AC-10）

- 入力: ta-56 sandbox で中断 → resume 実走 2 回
- 期待出力: record 差分ゼロ（2 回目）
- 種別: E2E

### TC-16: MERGE_READY record 契約（AC-11）

- 入力: MERGE_READY 到達 record
- 期待出力: PR 番号 / head SHA / check summary / review disposition / round / plan hash の 6 フィールド全存在（欠落で FAIL）
- 種別: Unit

### TC-17: NO MERGE — 遷移不在（AC-12）

- 入力: TRANSITIONS 全走査
- 期待出力: `MERGED` への遷移が 0 件。MERGE_READY が終端（C-4 待ち）
- 種別: Unit

### TC-18: NO MERGE — 純判定器ソース走査（AC-12 / Refs: R-007）

- 入力: delivery.py ソース
- 期待出力: merge シンボル（`gh pr merge` / `merge_pull_request`）0 件 **かつ** 禁止 import/シンボル（`subprocess` / `os.system` / `urllib` / `socket` / `http.client` / `requests`）0 件（ネットワーク・プロセス実行なしの純判定器契約。check-delegation-commit-boundary.sh L105-107 様式）
- 種別: E2E（ta-56）

### TC-22: 優先度 3 — 同型指摘の再発（recurse / Refs: R-002）

- 前提条件: record に同一 finding 型の過去 disposition あり
- 入力: snapshot（同型 finding 再発）
- 期待出力: `REVIEW_REPAIR` へ復帰 + record に `feedback_loop_referral` アクション（review-feedback-loop 還元要求）が刻まれる。独立 state は増えない
- 種別: Unit

### TC-23: 優先度 7 candidate と 8 の分離（Refs: R-003）

- 入力: snapshot（minor/info のみ・DoD 未判定）→ DoD 判定入力（CI green + 全件対応記録）
- 期待出力: 前者 = `MERGE_READY` **candidate（非終端）** + DoD 再評価アクション。後者のみ `MERGE_READY`。candidate から直接終端に短絡しない
- 種別: Unit

## c3-prime trust boundary（統合）

### TC-19: decision != AUTO_APPROVED → BLOCK

- 入力: HUMAN_ESCALATED / BLOCKED の c3-prime record
- 期待出力: delivery 起動拒否（BLOCK）
- 種別: Integration

### TC-20: c3-prime 再検証 FAIL → BLOCK

- 入力: 手 mutate した偽造 record（hash 不整合 / 未知キー / c3_status 混入）
- 期待出力: c3prime_verify 再検証で BLOCK（decision を無検証で信頼しない・契約 §7）
- 種別: Integration

### TC-21: head が source_sha の子孫でない → fail-closed

- 入力: snapshot（head=source_sha と無関係の SHA・ancestry=false）
- 期待出力: MERGE_READY 拒否 + escalate
- 種別: Integration

## エッジケース

### TC-E1: round 境界値

- 入力: round=3 で repair 要求（可）/ round=3 完了後さらに要求（round 4 相当）
- 期待出力: 前者=repair 遷移可、後者=HUMAN_ESCALATED
- 種別: Unit

### TC-E2: 空 / 壊れた snapshot

- 入力: 空 JSON / 必須キー欠落 / 型不一致
- 期待出力: fail-closed（明示エラー + 対象キー名をメッセージに含む）
- 種別: Unit

### TC-E3: 非 git 環境での ancestry 検証不能

- 入力: ancestry 判定材料なし
- 期待出力: 成功扱いにしない（fail-closed・**bin/plangate exec preflight（L2052-2061「c3-prime exec requires resolvable HEAD」）と同方針** / Refs: R-015）
- 種別: Unit

### TC-E5: 外部作用**前**の中断 → resume（Refs: R-005）

- 前提条件: intent 記録済み・receipt なし（要求記録直後に中断）
- 入力: resume で同一 snapshot 再投入
- 期待出力: 当該アクションを**再要求する**（未完了扱い・実行ゼロ回に終わらない）
- 種別: Unit

### TC-E6: 外部作用**後**の中断 → resume（Refs: R-005）

- 前提条件: intent + receipt 記録済み（完了記録後に中断）
- 入力: resume で同一 snapshot 再投入
- 期待出力: 当該アクションを**再要求しない**（実行済み抑止・二重実行に至らない）
- 種別: Unit

### TC-E4: disposition 1 件未解決残し

- 入力: findings 3 件中 2 件解決・1 件未解決で CI green
- 期待出力: MERGE_READY 拒否（全件解決が DoD）
- 種別: Unit
