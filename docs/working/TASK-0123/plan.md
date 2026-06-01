# TASK-0123 EXECUTION PLAN

## Goal

EH-3 maintenance.json 発行元検証（HMAC 署名）と承認トークン系ファイルへの AI 直接 Write/Edit を決定論 PreToolUse ガードで block し、承認境界の核心的な迂回経路を二重に閉じる。

---

## Constraints / Non-goals

- **全実装対象ファイルが HO（Hardening Override）対象**。AI は直接 Edit/Write ツールで変更できない。
  - `scripts/hooks/check-plan-hash.sh` ★HO
  - `bin/plangate` ★HO
  - `scripts/hooks/check-approval-token-write.sh`（新規）★HO
  - `.github/workflows/*.yml` ★HO
  - `schemas/maintenance.schema.json` ★HO
- AI が担当できる範囲:
  - テストスクリプト（`tests/extras/ta-25-*.sh`, `ta-26-*.sh`）— 非 HO
  - パッチファイル群（`docs/working/TASK-0123/patches/*.patch`）— 非 HO（patch を Human が apply）
  - ドキュメント（本ディレクトリ）— 非 HO
- Human が担当する範囲:
  - `sh scripts/apply-task-0123-patches.sh` で HO ファイルに patch を適用
  - `.claude/settings.json` の hook wiring（新規 hook EH-9 相当の配線）
  - GitHub Secrets `PLANGATE_MAINTENANCE_KEY_CI` の登録
- Non-goals: 既存承認境界の緩和・L1〜L4 仕様変更・maintenance CLI 運用性変更

---

## Mode 判定

**モード**: critical

**判定根拠**:
- 変更ファイル数: 6+ → high-risk 以上
- 変更種別: 承認境界・セキュリティ hook のアーキテクチャ変更 → critical
- リスク: 承認境界核心（HO 9 カテゴリ全てに触れる横断的変更） → critical
- 影響範囲: EH-3 全経路・全 maintenance 窓・全 approvals パス → システム全体
- 例外ルール: 承認境界周辺の変更は最低でも「高」（本 PBI は「超高」）
- **lite_eligible=false**（承認境界核心・HO 対象・critical mode → AC-10 Hardening Override 強制）
- **C-3 同期固定**（非同期降格不可）

---

## Approach Overview

### 全体アーキテクチャ

```
[Human TTY]
  └─ bin/plangate maintenance start
       ├─ L1〜L4 多層防御（既存）
       ├─ HMAC 署名生成（NEW: openssl dgst -hmac $PLANGATE_MAINTENANCE_KEY）
       └─ maintenance.json 書き込み（hmac_sha256 フィールド追加）

[EH-3 check-plan-hash.sh]
  └─ maintenance valid 判定（既存）
       └─ HMAC 署名検証（NEW: 鍵設定済みの場合は必須）
            ├─ 署名なし → block（fail-closed）
            ├─ 鍵なし → block（fail-closed）
            └─ 一致 → 通過

[EH-NEW check-approval-token-write.sh]
  └─ PreToolUse（Write/Edit/Bash）
       └─ path パターン判定
            ├─ docs/working/_maintenance/maintenance.json → BLOCK
            ├─ **/approvals/*.json → BLOCK
            └─ その他 → PASS

[CI: check-maintenance-signature.yml]
  └─ maintenance.json が staging に含まれる場合
       └─ hmac_sha256 フィールド存在・鍵照合 → fail if absent/invalid
```

### HMAC 署名方式の詳細

- 署名対象: `scope|until|granted_at|reason|approved_by` を `|` 区切りで連結した文字列
- 署名アルゴリズム: `openssl dgst -sha256 -hmac "$PLANGATE_MAINTENANCE_KEY"`
- 出力形式: 16 進数文字列（64 chars）
- フィールド名: `hmac_sha256`
- 後方互換: `PLANGATE_MAINTENANCE_KEY` 未設定環境では署名検証を SKIP（既存 v1/v2 ファイルに対する回帰防止）
  - ただし CI 環境（`PLANGATE_MAINTENANCE_KEY_CI` 設定）は必須検証
- fail-closed 原則: 鍵設定済みで署名なし / 不一致の場合は必ず block

---

## Work Breakdown

### Step 1: 設計確認・patch 準備（AI-owned）

**Output**: `docs/working/TASK-0123/patches/` 配下に各 HO ファイルの変更 patch ファイル

| サブタスク | 担当 | 内容 |
|-----------|------|------|
| S1-a | AI | `openssl dgst -hmac` の出力形式確認スクリプト生成 |
| S1-b | AI | `check-plan-hash.sh` 変更 patch 生成（HMAC 検証ロジック追加） |
| S1-c | AI | `bin/plangate` 変更 patch 生成（maintenance start に署名追加） |
| S1-d | AI | `check-approval-token-write.sh` 新規スクリプト生成（非 HO だが patch 経由） |
| S1-e | AI | `schemas/maintenance.schema.json` 変更 patch 生成（hmac_sha256 フィールド） |
| S1-f | AI | CI workflow 変更 patch 生成 |
| S1-g | AI | `scripts/apply-task-0123-patches.sh` 生成 |

🚩 **CP-1**: patch ファイル群の内容確認 → Human レビュー後に適用

### Step 2: テストスクリプト実装（AI-owned）

**Output**: `tests/extras/ta-25-maintenance-hmac.sh`, `tests/extras/ta-26-approval-token-guard.sh`

| サブタスク | 担当 | 内容 | Risk |
|-----------|------|------|------|
| S2-a | AI | `ta-25-maintenance-hmac.sh`: 署名なし block / 署名一致 PASS テスト | フィクスチャ構築の複雑さ |
| S2-b | AI | `ta-26-approval-token-guard.sh`: approval path block テスト | hook wiring 前は path テスト不可 |

🚩 **CP-2**: `sh tests/run-tests.sh` で ta-25/ta-26 PASS 確認

### Step 3: Human による patch 適用（Human-owned）

**Output**: HO ファイル群が更新済み状態

| サブタスク | 担当 | 内容 |
|-----------|------|------|
| S3-a | Human | `sh scripts/apply-task-0123-patches.sh` 実行 |
| S3-b | Human | `.claude/settings.json` に `check-approval-token-write.sh` の hook wiring 追加 |
| S3-c | Human | `PLANGATE_MAINTENANCE_KEY` をローカル環境に設定 |
| S3-d | Human | GitHub Secrets `PLANGATE_MAINTENANCE_KEY_CI` 登録 |

🚩 **CP-3**: patch apply 後に `sh tests/run-tests.sh` PASS 確認（Human 実施）

### Step 4: 受入検査（AI-owned）

**Output**: V-1 結果 + handoff.md

| サブタスク | 担当 | 内容 |
|-----------|------|------|
| S4-a | AI | `sh tests/run-tests.sh` 全件 PASS 確認 |
| S4-b | AI | AC-1〜AC-6 突合 |
| S4-c | AI | handoff.md 生成 |

---

## Files / Components to Touch

| ファイル | 変更種別 | 担当 | HO |
|---------|---------|------|-----|
| `scripts/hooks/check-plan-hash.sh` | 変更（HMAC 検証追加） | Human（patch apply） | ★HO |
| `bin/plangate` | 変更（署名生成追加） | Human（patch apply） | ★HO |
| `scripts/hooks/check-approval-token-write.sh` | 新規 | Human（patch apply） | ★HO |
| `.github/workflows/check-maintenance-signature.yml` | 新規 | Human（patch apply） | ★HO |
| `schemas/maintenance.schema.json` | 変更（hmac_sha256 追加） | Human（patch apply） | ★HO |
| `scripts/apply-task-0123-patches.sh` | 新規 | AI | 非 HO |
| `tests/extras/ta-25-maintenance-hmac.sh` | 新規 | AI | 非 HO |
| `tests/extras/ta-26-approval-token-guard.sh` | 新規 | AI | 非 HO |
| `docs/working/TASK-0123/patches/*.patch` | 新規 | AI | 非 HO |

---

## Testing Strategy

| 種別 | 内容 | ファイル |
|------|------|---------|
| Unit | HMAC 署名生成・検証・block ロジック | `ta-25-maintenance-hmac.sh` |
| Unit | approval token path block ロジック | `ta-26-approval-token-guard.sh` |
| Regression | 既存 maintenance テスト（ta-12）PASS 維持 | `ta-12-maintenance.sh` |
| Integration | `sh tests/run-tests.sh` 全件 PASS | 全 extras |
| CI | maintenance.json 署名検証 | `.github/workflows/check-maintenance-signature.yml` |
| Verification | AC-1〜AC-6 手動突合 | V-1 受入検査 |

---

## Risks & Mitigations

| ID | リスク | 対策 |
|----|--------|------|
| R-1 | 既存 maintenance.json との後方互換破壊 | 鍵未設定環境では署名検証を SKIP（段階移行） |
| R-2 | テスト環境での鍵モック | `PLANGATE_FAKE_MAINTENANCE_KEY` env 注入パターンを定義 |
| R-3 | patch 適用順序ミス | `apply-task-0123-patches.sh` に順序制御と検証ステップを組み込む |
| R-4 | hook wiring 漏れ（settings.json 未更新） | CP-3 で `bin/plangate doctor` PASS を必須条件とする |

---

## Questions / Unknowns

- `openssl dgst -hmac` の macOS/Linux 出力形式差異（`(stdin)= <hex>` vs `<hex>`）を要確認
- GitHub Actions で `secrets.PLANGATE_MAINTENANCE_KEY_CI` を未設定の場合の CI 動作（skip vs fail）を決定する必要がある
