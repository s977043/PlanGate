# TASK-0123 EXECUTION TODO

## 凡例

- `[x]` = 完了
- `[ ]` = 未着手
- Owner: `agent` = AI / `human` = Human
- 🚩 = チェックポイント（前後で状態確認必須）

---

## Phase 0: 準備

| # | タスク | Owner | 完了条件 |
|---|--------|-------|---------|
| T-01 | `openssl dgst -hmac` 出力形式確認（macOS/Linux 差異） | agent | 確認スクリプト `docs/working/TASK-0123/check-openssl-format.sh` 生成 |
| T-02 | 既存 ta-12-maintenance.sh の全テスト PASS 確認（ベースライン） | agent | `sh tests/run-tests.sh` で ta-12 全 PASS |

---

## Phase 1: patch ファイル生成（AI-owned）

| # | タスク | Owner | 完了条件 |
|---|--------|-------|---------|
| T-03 | `check-plan-hash.sh` HMAC 検証追加 patch 生成 | agent | `docs/working/TASK-0123/patches/check-plan-hash.patch` 生成 |
| T-04 | `bin/plangate` maintenance start 署名追加 patch 生成 | agent | `docs/working/TASK-0123/patches/bin-plangate.patch` 生成 |
| T-05 | `check-approval-token-write.sh` 新規スクリプト生成 | agent | `docs/working/TASK-0123/patches/check-approval-token-write.sh` 生成 |
| T-06 | `schemas/maintenance.schema.json` hmac_sha256 フィールド patch 生成 | agent | `docs/working/TASK-0123/patches/maintenance-schema.patch` 生成 |
| T-07 | CI workflow `check-maintenance-signature.yml` 生成 | agent | `docs/working/TASK-0123/patches/check-maintenance-signature.yml` 生成 |
| T-08 | `scripts/apply-task-0123-patches.sh` 生成（apply 手順・検証込み） | agent | `scripts/apply-task-0123-patches.sh` 生成 |

🚩 **CP-1**: patch ファイル群の内容を Human がレビュー

---

## Phase 2: テストスクリプト実装（AI-owned）

| # | タスク | Owner | 完了条件 |
|---|--------|-------|---------|
| T-09 | `ta-25-maintenance-hmac.sh` 実装 | agent | ファイル生成済み・構文エラーなし |
| T-10 | `ta-26-approval-token-guard.sh` 実装 | agent | ファイル生成済み・構文エラーなし |
| T-11 | ta-25/ta-26 の dry-run 確認（hook 未配線でも構文 PASS） | agent | `sh -n` で構文確認 PASS |

🚩 **CP-2**: patch 適用前の状態でテスト構文 PASS 確認

---

## Phase 3: C-3 人間レビュー（Human-owned） 👤

| # | タスク | Owner | 完了条件 |
|---|--------|-------|---------|
| T-12 | plan.md / pbi-input.md / test-cases.md / review-self.md の確認 | human | C-3 APPROVED (`approvals/c3.json` 発行) |

> **依存**: T-01〜T-11 全完了が前提

---

## Phase 4: Human による patch 適用（Human-owned） 👤

| # | タスク | Owner | 完了条件 |
|---|--------|-------|---------|
| T-13 | `sh scripts/apply-task-0123-patches.sh` 実行 | human | 全 HO ファイルへの patch が PASS |
| T-14 | `.claude/settings.json` に `check-approval-token-write.sh` の hook wiring 追加 | human | settings.json 更新済み |
| T-15 | `PLANGATE_MAINTENANCE_KEY` をローカル環境に設定 | human | env 設定済み（`.env.local` 等） |
| T-16 | GitHub Secrets `PLANGATE_MAINTENANCE_KEY_CI` 登録 | human | Secrets 登録済み |
| T-17 | `sh tests/run-tests.sh` 全件 PASS 確認 | human | 全 PASS |

🚩 **CP-3**: `sh tests/run-tests.sh` 全件 PASS（Human 実施後に AI が V-1 確認）

---

## Phase 5: 受入検査・完了（AI-owned）

| # | タスク | Owner | 完了条件 |
|---|--------|-------|---------|
| T-18 | AC-1〜AC-6 突合 | agent | 全 AC PASS |
| T-19 | `bin/plangate doctor` PASS 確認 | agent | PASS |
| T-20 | handoff.md 生成 | agent | 必須 6 要素含む |
| T-21 | PR 作成 | agent | PR draft 作成済み |

🚩 **CP-4**: C-4 Human PR レビュー

---

## 依存関係

```
T-01, T-02
  └─ T-03〜T-08 (Phase 1)
       └─ T-09〜T-11 (Phase 2)
            └─ T-12 C-3 Gate 👤
                 └─ T-13〜T-17 (Phase 4 Human)
                      └─ T-18〜T-21 (Phase 5)
```

⚠️ Phase 4 は全て Human-owned。AI は Phase 4 完了待ちで V-1 に進む。
