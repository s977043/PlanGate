# TASK-0123 Handoff

## ステータス: 部分完了（承認トークン書込ガードは deployed / HMAC 署名層は未適用・要 Human 判断）

> **状態訂正（bookkeeping 2026-07-05）**: 旧記載「ステータス: DONE」は不正確だったため訂正した。実測で以下を確認:
>
> - ✅ **Part A（承認トークン書込ガード / AC-1〜4）は稼働済み**: `scripts/check-approval-token-write.sh` が存在し、`.claude/settings.json`（L65 / L74 の PreToolUse）に配線済み。C-3 も APPROVED（`approvals/c3.json` 実在）。
> - ❌ **Part B（HMAC 署名 / AC-5）は未適用**: `schemas/maintenance.schema.json` に `hmac_signature` フィールドが**存在しない**（grep 実測 0 件）。`apply-task-0123-patches.sh` は生成済みだが **一度も実行されていない**（引数なし実行で適用・`--dry-run` で事前確認。HO パスのため Human-owned）。したがって旧 AC-5「PASS（patch 適用後）」・TC-06「hmac_signature field present」は **現 main を反映しない偽 PASS**。
> - 親 issue **#420 は #427（本 TASK の PR）で CLOSED COMPLETED**。#427 コミット本文自身が "Closes #420 (partial — HO patches pending human application)" と明記しており、HMAC 層は当初から Human 適用待ち。
>
> **⚠️ 要 Human 判断（承認境界・security）**: HMAC 署名層（Part B）を
> (a) 今から適用する（Human が `sh scripts/apply-task-0123-patches.sh` を実行 = 多層防御を完成。`--dry-run` で事前確認後、引数なしで適用）か、
> (b) 適用せず「Part A ガードで #420 の実害は解消済み」として **Deferred/Superseded でクローズ**するか、
> を人間が決定する。AI は本判断を行わない（`.claude/rules/responsibility-classes.md`）。
>
> **残る防御課題（C-2 Gemini 指摘 / security-medium）**: Part A ガード本体 `scripts/check-approval-token-write.sh` は HO 保護対象外（`scripts/hooks/` でも `.claude/` でもない）ため、AI が当該スクリプトを改変すればガードをバイパスしうる。Part B（HMAC 署名）の適用、またはガードスクリプト自体の HO 化（`scripts/hooks/` への移設 + settings 参照更新）が、この迂回を塞ぐ残存対策。上記 (a)/(b) の判断材料。

---

## 1. 要件適合確認結果（AC ごとの PASS / FAIL / WARN）

| AC   | 内容                                                         | 結果      | 備考                                                                                                   |
| ---- | ------------------------------------------------------------ | --------- | ------------------------------------------------------------------------------------------------------ |
| AC-1 | `check-approval-token-write.sh` が存在・実行可能             | PASS      | deployed: script 実在 + `.claude/settings.json` L65/74 配線済（2026-07-05 実測）。TC-01/02 PASS        |
| AC-2 | maintenance.json パスへの書き込みを block                    | PASS      | TC-03 PASS (exit 1)                                                                                    |
| AC-3 | approvals/*.json パスへの書き込みを block                    | PASS      | TC-04 PASS (exit 1)                                                                                    |
| AC-4 | 通常ファイルは通過                                           | PASS      | TC-05 PASS (exit 0)                                                                                    |
| AC-5 | schemas/maintenance.schema.json に hmac_signature フィールド | ❌ 未適用 | `hmac_signature` は schema に不在（2026-07-05 grep 実測 0 件）。旧「適用後 PASS」は未実現条件＝偽 PASS |
| AC-6 | apply-task-0123-patches.sh が存在・syntax OK                 | PASS      | TC-07 PASS                                                                                             |

---

## 2. 既知課題一覧

| ID   | 内容                                                                                                                                                | 優先度 |
| ---- | --------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| KI-1 | `.claude/settings.json` への hook wiring は **完了済み**（L65/74 PreToolUse に配線・2026-07-05 実測）。旧「Human 手動必要」は当時の未配線状態の記載 | 中     |
| KI-2 | `PLANGATE_MAINTENANCE_KEY` の鍵ローテーション手順が未整備                                                                                           | 低     |
| KI-3 | CI の `check-maintenance-provenance.yml` は `PLANGATE_MAINTENANCE_KEY_CI` GitHub Secret の登録が Human 操作必須                                     | 中     |

---

## 3. V2 候補（今回のスコープ外）

- CI での HMAC 署名検証（鍵照合）の完全自動化（`PLANGATE_MAINTENANCE_KEY_CI` 設定後）
- `bin/plangate doctor` への EH-token-guard wiring 確認項目の追加
- 鍵ローテーション CLI コマンド（`plangate maintenance rotate-key`）

---

## 4. 妥協点（採用しなかった選択肢と理由）

| 選択肢                                      | 不採用理由                                                    |
| ------------------------------------------- | ------------------------------------------------------------- |
| plan.md のフィールド名 `hmac_sha256` を使用 | コンダクター指示が `hmac_signature` だったため合わせた        |
| `openssl dgst -hmac` を使った署名           | Python `hmac` モジュールの方が macOS/Linux 互換性が高いため   |
| `required` 配列に `hmac_signature` を追加   | 後方互換のため省略（新規 start 時は bin/plangate が自動付与） |

---

## 5. 引き継ぎ文書

### 実装概要

TASK-0123 では承認境界の核心的な迂回経路を二重に閉じる防御を実装した。

**EH-token-guard**:

- `scripts/hooks/check-approval-token-write.sh`（新規）
- AI が `maintenance.json` や `approvals/*.json` に直接書き込もうとすると exit 1 でブロック
- `.claude/settings.json` への PreToolUse hook wiring は Human が手動実施（Human 向け手順: `docs/ai/approval-token-guard.md`）

**HMAC 署名検証**:

- `schemas/maintenance.schema.json` に `hmac_signature` フィールドを追加
- `bin/plangate maintenance start` が `PLANGATE_MAINTENANCE_KEY` 設定時に自動付与
- EH-3 (`check-plan-hash.sh`) が署名検証を実施（署名あり・鍵設定済み → 一致必須、鍵未設定 → 通過（後方互換））

**Human が次に実施すべき操作**:

1. `.claude/settings.json` に `check-approval-token-write.sh` を PreToolUse hook として追加
2. `export PLANGATE_MAINTENANCE_KEY=$(openssl rand -hex 32)` でローカル鍵を設定
3. GitHub Secret `PLANGATE_MAINTENANCE_KEY_CI` を登録

### ファイル一覧

| ファイル                                             | 種別                    | 備考                                             |
| ---------------------------------------------------- | ----------------------- | ------------------------------------------------ |
| `scripts/apply-task-0123-patches.sh`                 | 新規（非 HO）           | HO ファイルへの変更を Human が適用するスクリプト |
| `scripts/hooks/check-approval-token-write.sh`        | 新規（HO/patch 適用後） | EH-token-guard 本体                              |
| `schemas/maintenance.schema.json`                    | 変更（HO/patch 適用後） | hmac_signature フィールド追加                    |
| `scripts/hooks/check-plan-hash.sh`                   | 変更（HO/patch 適用後） | HMAC 署名検証ブロック追加                        |
| `bin/plangate`                                       | 変更（HO/patch 適用後） | maintenance start に署名生成追加                 |
| `.github/workflows/check-maintenance-provenance.yml` | 新規（HO/patch 適用後） | CI 署名検証 workflow                             |
| `tests/extras/ta-25-approval-token-guard.sh`         | 新規（非 HO）           | TC-01〜TC-07 テストスクリプト                    |
| `docs/ai/approval-token-guard.md`                    | 新規（非 HO）           | Human 向け運用ガイド                             |

---

## 6. テスト結果サマリ

```
sh tests/run-tests.sh
Results: 228 passed, 0 failed
```

**ta-25 詳細:**

- TC-01: PASS — check-approval-token-write.sh exists and is executable
- TC-02: PASS — check-approval-token-write.sh syntax ok
- TC-03: PASS — maintenance.json path blocked (exit 1)
- TC-04: PASS — approvals/c3.json path blocked (exit 1)
- TC-05: PASS — normal file passes (exit 0)
- TC-06: ⚠️ 現 main 不一致 — 上記ログはローカルで patch を一時適用した際の記録。現 main では `hmac_signature` フィールドは schema に不在（未適用）
- TC-07: PASS — apply-task-0123-patches.sh exists and syntax ok

既存テスト（ta-12 maintenance 等）への回帰なし確認済み。
