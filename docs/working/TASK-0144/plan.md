---
task_id: TASK-0144
artifact_type: plan
schema_version: 1
---

# EXECUTION PLAN — TASK-0144（C-2 反映版）

> C-2 指摘 R-001〜R-008 反映済み（2026-06-25）
> 主要設計変更: cmd_exec ではなく cmd_approve が conversation モード時の c3.json 生成を担う

## Goal

`.plangate.yml` の `c3_approval.mode` 設定により、C-3 承認を CLI（`bin/plangate approve`）と会話内 APPROVE（AI が exec 前に c3.json を生成）の 2 モードで切り替えられるようにする。デフォルトは `cli`（後方互換）。

## Constraints / Non-goals

- **デフォルト `cli`**: `.plangate.yml` 未存在 = `cli` モード（既存動作完全維持）
- **`bin/plangate`, `scripts/hooks/*.sh`, `schemas/*.schema.json` は HO パス** → apply-script 経由で Human が適用
- **`cmd_exec` は変更しない**（R-001/R-002 反映: ゲート自己充足を防ぐ）
- EH-3 provenance 完全検証は Out of scope（issue #420）
- HMAC 署名・セッション検証は V2 候補

## Mode 判定

**モード**: `high-risk`

**判定根拠**:
- 変更ファイル数: 6-8（bin/plangate + scripts/hooks/check-plan-hash.sh + schemas/*.schema.json x2 + apply-script x2 + .plangate.yml + test）→ high
- 受入基準数: 6 → standard 上限
- 承認境界周辺（bin/plangate / scripts/hooks/*.sh / schemas/*.schema.json）→ 例外ルールにより最低 high
- `lite_eligible: false`（HO パス含む / high-risk）

## Approach Overview（R-001/R-002 反映後の設計）

```
人間が会話内で「APPROVE」発話
      ↓
AI が c3.json を生成（source: conversation, c3_status: APPROVED, plan_hash: 現 plan.md のハッシュ）
      ↓
EH-3: approvals/c3.json + conversation mode → SKIP (exit 0)  ← 「通す」だけ
      ↓（Write 成功）
bin/plangate exec TASK
  → approvals/c3.json 存在チェック → PASS
  → EH-2: c3_status=APPROVED 確認 → PASS
  → exec 開始
```

**重要**: `cmd_exec` は変更しない。c3.json は exec 前に存在する必要がある（現行コントラクト維持）。
`cmd_approve` が conversation モード時の c3.json 生成を担う（または AI 会話内での直接 Write）。

**EH-3 例外経路の責務分担**（R-003 反映）:
- EH-3 SKIP: `docs/working/TASK-XXXX/approvals/c3.json` パス + conversation モード → Write を通す（「通す」のみ）
- 中身の検証: AI 生成コードが schema 準拠・plan_hash 付与を保証
- exec 時: EH-2 が c3_status=APPROVED を確認（従来通り）

**EH-3 は c3.json の "書込みポリシー制御" のみ担い、内容検証は行わない。**

## Work Breakdown

### Step 1: 調査・設計確認 ✅（完了）
- **Output**: EH-3 が c3.json を maintenance.json なしでブロックすること、`c3-approval.schema.json` が `additionalProperties: false` であることを確認
- **Owner**: AI

### Step 2: `.plangate.yml` サンプル + `plangate-config.schema.json` 作成
- **Output**:
  - `.plangate.yml` — プロジェクトルート（AI 直接作成可、HO 対象外）
  - `schemas/plangate-config.schema.json` — HO パス → apply-script
- **Owner**: AI（.plangate.yml 直接）+ apply-script 経由 Human（schema）
- 🚩 **チェックポイント**: `.plangate.yml` にサンプル設定が存在し、schema が enum で `cli|conversation` を検証する

### Step 3: `schemas/c3-approval.schema.json` に `source` フィールド追加
- **Output**: `source: cli | conversation` の **optional** フィールド追加（R-004 反映: additionalProperties: false のため schema 追加必須）
- **Owner**: apply-script 経由 Human
- **Risk**: 既存 c3.json（source なし）が引き続き valid であること → test でカバー
- 🚩 **チェックポイント**: TA-35（schema test）が 0 FAIL、旧 c3.json も新 c3.json も valid

### Step 4: `scripts/hooks/check-plan-hash.sh` に conversation モード経路追加
- **Output**:
  - `approvals/c3.json` + conversation mode → SKIP (exit 0)
  - SKIP ログを `_audit/skip-decision-log.jsonl` に `EH-3_C3_CONVERSATION_SKIP` として記録
- **Owner**: apply-script 経由 Human
- **Risk**: c3.json パターンの誤マッチ → `^docs/working/TASK-[0-9]+/approvals/c3\.json$` で strict 限定
- 🚩 **チェックポイント**: conversation モード時 c3.json Write が exit 0 で通過する

### Step 5: `bin/plangate` に config 読み込み + approve/doctor 分岐追加（R-001/R-002 反映）
- **Output**:
  - `_read_plangate_config()`: `.plangate.yml` の `c3_approval.mode` を読む（python3 yaml fallback あり）
  - `.plangate.yml` 存在 + 読めない/不正 mode → **stderr に警告を出力**（R-005 反映）
  - `cmd_approve` (conversation mode): 人間の APPROVE 発話後に AI が c3.json を生成するロジック（source: conversation, c3_status: APPROVED, plan_hash 付き）
  - `cmd_approve` (cli mode): 従来動作（変更なし）
  - `cmd_exec`: **変更なし**（R-001/R-002 反映: ゲート自己充足を防ぐ）
  - `cmd_doctor`: 現在の承認モード（cli / conversation）表示
- **Owner**: apply-script 経由 Human
- **Risk**: PyYAML 未インストール → `cli` にフォールバック（ただし警告表示）
- 🚩 **チェックポイント**: `bin/plangate doctor` に承認モードが表示、`.plangate.yml` 不正値で警告が出る

### Step 6: apply-script 作成（`_apply_task_0144_patches.py` + wrapper）
- **Output**: `scripts/_apply_task_0144_patches.py`（dry-run/apply 2 mode）+ `scripts/apply-task-0144-c3-mode.sh`
- **Owner**: AI
- **含む patch**: Step 2（schema）/ Step 3（c3 schema）/ Step 4（EH-3）/ Step 5（bin/plangate）
- **Risk**: apply-script の patch が実際の bin/plangate テキストと不一致 → dry-run で事前確認必須

### Step 7: テスト作成（`tests/extras/ta-45-c3-mode-config.sh`）
- **Output**: ta-45（6 TC + edge cases）
- **Owner**: AI
- apply 前: TC-01 が SKIP（TASK-0143/ta-44 と同様の skip 分岐）
- apply 後: TC-01〜06 が PASS
- TC-06: R-006 反映 — `.plangate.yml` の schema 検証 TC（jsonschema or python3 check）
- 🚩 **チェックポイント**: `sh tests/run-tests.sh` 0 FAIL

### Step 8: docs 更新
- **Output**: `docs/ai/settings-wiring-contract.md` に EH-3 conversation 経路を明記
- **Owner**: AI（.md → doc-light SKIP、HO なし）

## Files / Components to Touch（R-007 反映: HO 表記修正）

| ファイル | 変更種別 | HO | 方法 |
|--------|--------|----|----|
| `.plangate.yml` | 新規 | — | AI 直接 |
| `schemas/plangate-config.schema.json` | 新規 | ✅ | apply-script |
| `schemas/c3-approval.schema.json` | 修正 | ✅ | apply-script |
| `scripts/hooks/check-plan-hash.sh` | 修正 | ✅ | apply-script |
| `bin/plangate` | 修正 | ✅ | apply-script |
| `scripts/_apply_task_0144_patches.py` | 新規 | — | AI 直接 |
| `scripts/apply-task-0144-c3-mode.sh` | 新規 | — | AI 直接 |
| `tests/extras/ta-45-c3-mode-config.sh` | 新規 | — | AI 直接 |
| `docs/ai/settings-wiring-contract.md` | 追記 | — | AI 直接（doc-light SKIP） |

## Testing Strategy

- **Unit**: ta-45（6 TC）— conversation/cli モード切り替え・schema 検証・doctor 出力・.plangate.yml 不正値 WARN
- **Regression**: `sh tests/run-tests.sh` 全件 0 FAIL（R-008 反映: 件数固定せず exit 0 + TA-45 PASS 数）
- **E2E**: apply-script --dry-run で diff 確認 → --apply → doctor PASS

## Risks & Mitigations

| リスク | 軽減策 |
|------|------|
| `.plangate.yml` 未存在時に python3 yaml が crash | `try/except ImportError` / `try/except` で `cli` にフォールバック＋警告 |
| PyYAML 未インストール | 同上 |
| `.plangate.yml` 存在 + 読めない/不正 mode | R-005 反映: stderr に WARN 出力＋doctor で WARN 表示 |
| c3.json regex 誤マッチ | `^docs/working/TASK-[0-9]+/approvals/c3\\.json$` で strict 限定 |
| 既存 c3.json の schema 破壊 | R-004 反映: `source` を optional として schema に追加。旧 c3.json も valid を TC でカバー |
| cmd_exec のゲート自己充足 | R-001/R-002 反映: cmd_exec は変更しない。c3.json は exec 前に生成 |

## Questions / Unknowns

- conversation モード時の c3.json 生成を `cmd_approve` に組み込むか、会話内で AI が直接 Write するか → 本 PBI では「AI が会話内で Write（EH-3 SKIP 経由）」を優先。cmd_approve は cli モードで従来通り。
- EH-3 の SKIP ログをどこに記録するか → `_audit/skip-decision-log.jsonl`（EH-3_C3_CONVERSATION_SKIP イベント）
