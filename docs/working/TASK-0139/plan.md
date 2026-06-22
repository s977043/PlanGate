# EXECUTION PLAN — TASK-0139 (#550)

## Goal

`plangate approve` の L3/L4 presence gate に残る best-effort ギャップ（read -r 漏れ・FAKE_PPID 本番有効・overwrite policy・out-of-band 未設計）を修正し、strict enforcement に近づける。

## Constraints / Non-goals

- out-of-band の実装は次フェーズ（本 PBI は設計 ADR まで）
- `bin/plangate` は HO → AI は apply-script 生成のみ、実行は Human
- テスト既存ロジック破壊禁止（FAKE_PPID_COMM を使う既存テストは PLANGATE_TEST_MODE=1 を追加）

## Approach Overview

1. `read -r` 化: 3 行の機械的変換（cmd_approve L2160/L2164, _plangate_presence_gate L2124 + maintenance L1314）
2. FAKE_PPID_COMM ガード: `&& [ "${PLANGATE_TEST_MODE:-0}" = "1" ]` 条件を追加（2箇所）
3. overwrite policy: `[ -f "$_ap_c3" ] && [ "$_ap_force" = "false" ]` → note → **return 2 (abort)**
4. ADR: `docs/decisions/adr-001-approve-out-of-band.md` 新規作成

## Work Breakdown

### Step 1: apply-script 生成（`scripts/apply-approve-hardening.sh`）

`bin/plangate` の変更をパッチとして記述し Human が適用するスクリプト。
- read -r: 3行変換
- FAKE_PPID_COMM guard: 2箇所に `&& [ "${PLANGATE_TEST_MODE:-0}" = "1" ]` 追加
- overwrite block: note メッセージ → `printf 'error: ...
' >&2; return 2`
- 🚩 dry-run オプション付き

### Step 2: ADR 作成（`docs/decisions/adr-001-approve-out-of-band.md`）

out-of-band 承認設計の選択肢（A: OS keychain / B: HMAC token / C: OTP）と推奨案を記述。HO 対象外のため AI が直接作成。

### Step 3: テスト既存修正（`PLANGATE_TEST_MODE=1` 追記）

FAKE_PPID_COMM を使っている既存テストに `PLANGATE_TEST_MODE=1` を追加。

### Step 4: ta-40-approve-hardening.sh 作成

- TC-01: read -r が機能し backslash が展開されないこと（模擬入力）
- TC-02: FAKE_PPID_COMM が PLANGATE_TEST_MODE 未設定時は L3 に影響しないこと
- TC-03: 既存 c3.json があり --force なしは abort
- TC-04: 既存 c3.json があり --force 付きは overwrite 継続

### Step 5: run-tests.sh に ta-40 登録

### Step 6: apply → テスト確認（Human apply 後）

## Files / Components to Touch

| ファイル | 変更 | HO |
|---------|------|----|
| `bin/plangate` | read -r / FAKE_PPID guard / overwrite block | ✅ HO |
| `scripts/apply-approve-hardening.sh` | 新規（apply用） | — |
| `docs/decisions/adr-001-approve-out-of-band.md` | 新規 ADR | — |
| `tests/extras/ta-40-approve-hardening.sh` | 新規 | — |
| `tests/run-tests.sh` | 1行追加 | — |
| 既存テスト（FAKE_PPID 使用箇所） | PLANGATE_TEST_MODE=1 追記 | — |

## Mode判定

**モード**: high-risk（HO: bin/plangate）
**lite_eligible**: false
**autonomous APPROVE**: 不可
