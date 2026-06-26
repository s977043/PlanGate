# TASK-0146 EXECUTION PLAN — EHS-2/3 bin/plangate 配線（#527 増分2/3）

> EPIC #527 の残: EHS-2（handoff 6要素チェック）/ EHS-3（fix-loop 上限）を `bin/plangate` に配線。
> TASK-0145（EHS-1 配線）の後続。hook-enforcement.md §EHS の「設計済み・未実装（2）」を解消。

## Goal

`bin/plangate` が `PLANGATE_VALIDATION_BIAS=strict` 時に EHS-2 / EHS-3 を強制発火する機構を配線し、
hook-enforcement.md の配線状態表を「⏳ 設計済み・未実装（2）」→「✅ CLI 配線」へ更新する。
非 strict（既定 normal）では warn のみ / 既存挙動不変。

## Constraints / Non-goals

- `bin/plangate` は HO → AI 直接編集不可。apply-script を Human が適用（TASK-0143/0145 と同方式）。
- `validation_bias` の conductor 自動注入は将来拡張（本 PR は env 注入方式のみ）。
- `check-fix-loop.sh` / `check-handoff-elements.sh` 自体の変更なし（既実装を利用するだけ）。

## Approach

### EHS-3: fix-loop 上限（増分2）

**配線先**: `cmd_verify` 内の V-1 失敗ブロック。V-1 FAIL 時に `check-fix-loop.sh` を increment で呼び出す。
strict 時は `PLANGATE_HOOK_STRICT=1` で上限超過時 return 1（block）。

配線イメージ:
- V-1 失敗後（既存 "return 1" の前）に EHS-3 increment 処理を挿入
- `PLANGATE_VALIDATION_BIAS=strict` 時: `PLANGATE_HOOK_STRICT=1 sh check-fix-loop.sh $task_id increment || return 1`
- 非 strict: `sh check-fix-loop.sh $task_id increment 2>/dev/null || true`

### EHS-2: handoff 6要素チェック（増分3）

**配線先**: `cmd_handoff` に `--verify` フラグを追加。呼び出し時に `check-handoff-elements.sh` を発火。
strict 時は `PLANGATE_HOOK_STRICT=1` で 6要素不足時 return 1（block）。

配線イメージ:
- `cmd_handoff` 先頭で `--verify` フラグを解析
- `--verify` 指定時: check-handoff-elements.sh を呼び出して return 0 (strict 違反は return 1)
- 通常のテンプレートコピーは `--verify` なし時のみ

## Work Breakdown

### Step 1: apply-script 作成（非 HO）
- **Output**: `scripts/_apply_task_0146_patches.py`（EHS-3 + EHS-2 の 2 patch）
- **Owner**: agent
- **Risk**: 低（非 HO ファイル）
- 🚩 チェックポイント: dry-run で diff が期待通り

### Step 2: shell wrapper 作成（非 HO）
- **Output**: `scripts/apply-task-0146-ehs23-wiring.sh`（dry-run/--apply wrapper）
- **Owner**: agent

### Step 3: テスト作成（非 HO）
- **Output**: `tests/extras/ta-47-ehs23-wiring.sh`（SKIP/PASS テスト、TASK-0145 ta-46 と同方式）
- **Owner**: agent
- 🚩 チェックポイント: 未適用時 SKIP・`sh tests/run-tests.sh` 0 FAIL

### Step 4: hook-enforcement.md 更新
- **Output**: EHS-2/3 を「CLI 配線（apply 後）」へ更新
- **Owner**: agent

### 🚩 C-3 ゲート (Human 必須)
- high-risk / Hardening Override 対象 → 人間レビュー必須

### Step 5: 手動適用確認（Human 実行）
- Human が `sh scripts/apply-task-0146-ehs23-wiring.sh --apply` を実行
- `sh tests/run-tests.sh` で ta-47 全 TC PASS を確認

## Files / Components to Touch

| ファイル | 種別 | 変更者 |
|--------|------|--------|
| `scripts/_apply_task_0146_patches.py` | 新規・非HO | AI |
| `scripts/apply-task-0146-ehs23-wiring.sh` | 新規・非HO | AI |
| `tests/extras/ta-47-ehs23-wiring.sh` | 新規・非HO | AI |
| `bin/plangate` | 変更・**HO** | **Human**（apply-script 経由） |
| `docs/ai/hook-enforcement.md` | 更新 | AI（doc 更新） |
| `docs/working/TASK-0146/` 各ファイル | 新規 | AI |

## Testing Strategy

- `ta-47-ehs23-wiring.sh`: 未適用 SKIP / 適用後 TC-01〜06 PASS
  - TC-01: EHS-3 配線確認（check-fix-loop.sh 呼び出し経路）
  - TC-02: EHS-3 strict 時 block（return 1）
  - TC-03: EHS-3 非 strict 既定（warn のみ）
  - TC-04: EHS-2 配線確認（`--verify` フラグ存在）
  - TC-05: EHS-2 strict 時 block（return 1）
  - TC-06: patched bin/plangate 構文健全（sh -n）

## Risks & Mitigations

| Risk | 対策 |
|------|------|
| bin/plangate の行変化で patch 失敗 | 文字列アンカー方式（行番号非依存）+ dry-run 先行確認 |
| EHS-1（TASK-0145）未適用での二重 return 1 | apply-script は独立。ta-47 は ta-46 同様 SKIP |
| check-fix-loop.sh が .fix-loop-count を生成 | テスト内で mktemp sandbox / PLANGATE_BYPASS_HOOK 利用 |

## Mode判定

**モード**: high-risk（`bin/plangate` = Hardening Override パス）/ lite_eligible=false

**判定根拠**:
- 変更ファイル数（実体）: `bin/plangate` 1 本（HO）+ 補助スクリプト 3 本
- 受入基準数: 6（EHS-2/3 配線 + strict/non-strict 各 1 + 構文健全）
- 変更種別: HO パスへの機能追加
- リスク: 高（bin/plangate は承認境界周辺 → Hardening Override 対象）
- **最終判定**: high-risk（HO 対象につき自動引き上げ）
