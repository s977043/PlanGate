# EXECUTION PLAN — TASK-0141

## Goal

EH-2 の承認判定を python3 strict JSON 化し、EH-1/EH-2 に stdin fallback を追加する。
ta-06 ログ握りつぶしを解消し、ta-43 で EH-2 strict を自動テスト化する。

## Constraints / Non-goals

- scripts/hooks/*.sh は HO → apply-script パターン（AI 作成、Human 適用）
- settings wiring / doctor 変更・EH-4/5/7/EHS 群は別 TASK

## Work Breakdown

### Step 1: apply-script 生成（AC-1/AC-2）

Output: scripts/apply-task-0141-eh2-strict.sh

EH-2 python3 strict JSON 化:
  - check-c3-approval.sh の grep/sed を python3 json.load に置換
  - 壊れた JSON / 非 object / フィールド欠落 → 空文字（fail-safe）
  - EH-3（check-plan-hash.sh）と対称

stdin fallback（EH-1/EH-2 共通）:
  - env PLANGATE_HOOK_TASK → arg → stdin tool_input.file_path の優先順
  - python3 で file_path から TASK-XXXX を抽出
  - cat 2>/dev/null || true でハング防止

Owner: AI（apply は Human）
CP1: dry-run で期待差分が出ること

### Step 2: ta-43 新設（AC-4）

Output: tests/extras/ta-43-eh2-strict-json.sh

- TC-01: 正常 APPROVED c3.json → allow
- TC-02: 壊れた JSON → warn + allow（非 APPROVED 扱い）
- TC-03: コメント行に "c3_status":"APPROVED" 埋め込み → 非 APPROVED
- TC-04: c3_status フィールドなし → 非 APPROVED
- TC-05: stdin file_path から TASK-ID 解決 → APPROVED 判定
- TC-06: stdin なし + env なし → SKIP（allow）

Owner: AI（test ファイルは非 HO）
CP2: run-tests.sh で ta-43 が認識される

### Step 3: ta-06 修正（AC-3）

Output: tests/extras/ta-06-hooks.sh（直接編集・非 HO）

- [>/dev/null 2>&1] を排除
- hook test 結果を [PASS]/[FAIL] 形式で run-tests.sh に報告
Owner: AI
CP3: run-tests.sh で ta-06 の結果が PASS/FAIL として見える

## Files / Components to Touch

- scripts/apply-task-0141-eh2-strict.sh  (新規, AI 作成)
- tests/extras/ta-43-eh2-strict-json.sh  (新規, AI 作成)
- tests/extras/ta-06-hooks.sh            (修正, AI 直接編集・非 HO)
- scripts/hooks/check-c3-approval.sh     (HO パッチ対象, Human 適用)
- scripts/hooks/check-plan-exists.sh     (HO パッチ対象, Human 適用)

## Testing Strategy

- Unit: ta-43（hooks コピーで直接実行）
- Integration: apply-script --dry-run でパッチ差分検証
- V-1: sh tests/run-tests.sh 全 PASS、FAIL=0

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| python3 エラーで c3_status が空文字 | 2>/dev/null で保護（空文字=非 APPROVED が fail-safe） |
| stdin 読み込みでハング | cat 2>/dev/null || true で防御 |
| ta-06 unsilence で hook テスト失敗露出 | 意図的（露出が目的）|

## Mode 判定

モード: high-risk
- 変更ファイル数: 5
- 受入基準数: 5
- リスク: 承認境界・Hardening Override 対象パス
- lite_eligible: false（Hardening Override パス含む）
