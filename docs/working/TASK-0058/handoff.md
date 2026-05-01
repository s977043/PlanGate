---
task_id: TASK-0058
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-05-01
author: qa-reviewer
v1_release: ""
related_issue: 169
---

# Handoff: TASK-0058 / Issue #169 セッション C — EH-7 + EHS-1 実装（#169 完走）

## 1. 要件適合確認結果

| AC | 判定 | 根拠 |
|----|------|------|
| AC-1: EH-7 4 mode | PASS | both APPROVED PASS / c4 missing default WARN / no approvals strict exit 1 / bypass exit 0 |
| AC-2: EHS-1 5 mode | PASS | review-external present standard PASS / missing default WARN / missing strict high-risk exit 1 / light skip / bypass critical exit 0 |
| AC-3: hook 単体 42 PASS | PASS | `Results: 42 passed, 0 failed`（既存 33 + EH-7 4 + EHS-1 5 = 9 件追加）|
| AC-4: run-tests.sh 24 PASS | PASS | loader 経由で 24 件 PASS 維持 |
| AC-5: hook-enforcement v5 / 10/10 | PASS | Status v5、§ 4 表に 10 hook 完備、§ 4.5「全 10 hook 完了（#169 完走）」 |
| AC-6: PR closes #169 | PASS | PR #185 本文に `closes #169` 含む |
| AC-7: 既存 8 hook 無変更 | PASS | check-c3-approval / check-plan-* / check-test-cases / check-verification-evidence / check-forbidden-files / check-handoff-elements / check-fix-loop は無編集 |

**総合**: **7 / 7 PASS**

## 2. 既知課題一覧

| 課題 | Severity | 状態 |
|------|---------|------|
| EH-7 の GitHub branch protection 自動連携は scope 外 | minor | accepted（別 PBI 候補、外部 API 操作必要）|
| EHS-1 で C-2 vs V-3 の review-external.md 区別なし | info | accepted（どちらの phase でも review-external があれば PASS、phase 分離は v2 候補）|
| EHS-1 で `PLANGATE_HOOK_MODE` 未指定時は standard 扱い | info | accepted（安全側、必須化）|

## 3. V2 候補

| V2 候補 | 理由 | 優先度 |
|--------|------|--------|
| EH-7 GitHub branch protection 自動適用 | 完全自動化（CLI 検証のみでは強制力不十分）| Medium |
| EHS-1 で C-2 / V-3 phase 分離 | 同 review-external.md を共用しないモデル | Low |
| 共通 hook helper（_lib.sh）| DRY、10 ファイル × 各 60〜100 行 | Low（重複は許容範囲）|
| Hook を `bin/plangate hook <name>` の subcommand に統合 | UX 向上 | Low |

## 4. 妥協点

| 選択 | 諦めた代替 | 理由 |
|------|-----------|------|
| 1 PBI で 2 hook 一括 | 2 PBI 分離 | 同じ「マージ前 / PR 前 検証」グループ、test fixture 近接 |
| EH-7 を CLI のみ実装 | branch protection 自動操作併用 | 外部 API 操作はリスク高、別 PBI 候補 |
| EHS-1 で `review-external.md` を C-2/V-3 共用 | phase 別ファイル化 | 既存運用（PBI-116 配下）を踏襲、後方互換 |
| `PLANGATE_HOOK_MODE` 未指定時 standard | 必須引数化 | 既存パターン（`PLANGATE_HOOK_TASK` も optional）に整合 |

## 5. 引き継ぎ文書

### 概要

#169 残 Hook EPIC の **セッション C** で EH-7 + EHS-1 を実装、**10/10 hooks 完成**で #169 完走。tests/hooks 33 → **42 件 PASS**（+9）。`docs/ai/hook-enforcement.md` Status v4 → **v5（10/10 hooks Done）**。

主要成果:
- `scripts/hooks/check-merge-approvals.sh`（EH-7、CLI）: マージ前 2 段階レビュー検証
- `scripts/hooks/check-v3-review.sh`（EHS-1、CLI、mode 連携）: standard 以上で V-3 必須化、light/ultra-light skip
- 全 10 hook で 3 mode 設計（default / strict / bypass）+ 監査ログ統一
- #169 EPIC 完了（4 セッション × 計 11 PR：#164 + #183 + #184 + #185）

### 触れないでほしいファイル

- `scripts/hooks/check-merge-approvals.sh` の c4 file fallback ロジック: `c4-approval.json` 優先、`c4.json` 後方互換
- `scripts/hooks/check-v3-review.sh` の mode 分岐: light/ultra-light SKIP は意図的
- `tests/fixtures/hooks/v3-review-exists/review-external.md`: 他 hook の fixture と独立

### 次に手を入れるなら

- **EH-7 上位拡張**: GitHub branch protection ruleset の自動適用（`gh api repos/:owner/:repo/rulesets`）→ 別 PBI
- **v8.5 リリース判断**: hook 完成 + 10/10 → milestone として打ち出す価値あり
- アンチパターン: 共通ヘルパへの大幅リファクタ（10 ファイルでも管理可能、現状で十分）

### 参照リンク

- Issue: #169（**本 PR で auto-close**）
- 過去セッション: #164（A 前段）/ #183（A）/ #184（B）/ #185（C / 本 PR）
- 全 10 hook の表: `docs/ai/hook-enforcement.md` § 4

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP |
|---------|------|------|-----------|
| Hook 単体（tests/hooks/run-tests.sh）| **42** | **42** | 0 / 0 |
| Integration（tests/run-tests.sh）| 24 | 24 | 0 / 0 |

検証コマンド:
```sh
sh tests/hooks/run-tests.sh    # 42 PASS（既存 33 + EH-7 4 + EHS-1 5 = 9 件追加）
sh tests/run-tests.sh          # 24 PASS（loader 経由）
ls scripts/hooks/*.sh | wc -l  # 10
```
