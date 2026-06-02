# TASK-0123 C-1 セルフレビュー

実施日: 2026-06-02
レビュアー: spec-writer（AI）
対象: plan.md / todo.md / test-cases.md

---

## Plan チェック（7 項目）

### C1-PLAN-01: 受入基準網羅性

AC-1〜AC-6 が plan の Work Breakdown および Testing Strategy に全て対応しているか。

| AC | 対応 Step/テスト |
|----|----------------|
| AC-1 | S2-a (ta-25), TC-01〜03 |
| AC-2 | S2-a (ta-25), TC-04〜05 |
| AC-3 | S2-b (ta-26), TC-06〜08 |
| AC-4 | S1-f (CI workflow), TC-09 |
| AC-5 | TC-10（ta-12 regression） |
| AC-6 | TC-11（run-tests.sh 全件） |

**判定**: PASS — 全 AC が網羅されている

---

### C1-PLAN-02: Unknowns 処理

plan に記載された Unknowns:
1. `openssl dgst -hmac` の macOS/Linux 出力形式差異 → T-01 で事前確認スクリプト生成（対処済み）
2. GitHub Actions secrets 設定タイミング → Notes に記載・Human 担当（対処済み）

**判定**: PASS — Unknowns は明示され処理方針が定まっている

---

### C1-PLAN-03: スコープ制御

In scope / Out of scope の境界が明確か。

- In scope: HMAC 署名・PreToolUse ガード・CI 検出・テスト・patch スクリプト
- Out of scope: 既存承認境界の緩和・L1〜L4 仕様変更・maintenance CLI 運用性変更・HMAC 鍵ローテーション基盤

**判定**: PASS — 境界が明確。Out of scope の記載が具体的。

---

### C1-PLAN-04: テスト戦略

Unit / Regression / Integration / CI テストが定義されているか。

- Unit: ta-25（HMAC）, ta-26（approval path）
- Regression: ta-12（既存 maintenance テスト）
- Integration: `sh tests/run-tests.sh` 全件
- CI: `.github/workflows/check-maintenance-signature.yml`
- Verification: AC-1〜AC-6 手動突合

**判定**: PASS — 全種別が揃っている

---

### C1-PLAN-05: Work Breakdown Output

各 Step に Output が定義されているか。

| Step | Output |
|------|--------|
| Step 1 | `patches/` 配下の patch ファイル群 |
| Step 2 | ta-25, ta-26 テストスクリプト |
| Step 3 | HO ファイル更新済み（Human） |
| Step 4 | V-1 結果 + handoff.md |

**判定**: PASS — 各 Step に明確な Output がある

---

### C1-PLAN-06: 依存関係

Human/AI タスクの依存関係が明確か。

- Phase 1（patch 生成）→ Phase 2（テスト）→ C-3 Gate → Phase 4（Human apply）→ Phase 5（V-1）
- AI が直接実行できない HO ファイル変更は全て Phase 4（Human-owned）に分離済み
- Phase 4 は Phase 3（C-3 APPROVED）が前提

**判定**: PASS — 依存が明示され Human/AI の責務分界が明確

---

### C1-PLAN-07: 動作検証自動化

`sh tests/run-tests.sh` で AC-1〜AC-6 のほぼ全てが自動検証可能か。

- AC-1〜AC-3, AC-5, AC-6: 自動検証可能（ta-25, ta-26, ta-12）
- AC-4: CI が必要（手動確認が残るが CI が自動検証）

**判定**: PASS — AC の 5/6 が自動化。AC-4 は CI で補完。

---

## ToDo チェック（5 項目）

### C1-TODO-01: タスク粒度

各タスクが 1 セッション以内で完了できる粒度か。

T-01〜T-11 は全て 1 タスク = 1 ファイル生成 or 確認。Phase 4 は Human タスクで各操作が独立。

**判定**: PASS

---

### C1-TODO-02: depends_on 設定

依存関係が todo.md に明示されているか。

「依存関係」セクションに依存グラフを記載。Phase 4 が Phase 3（C-3 Gate）完了後であることも明示。

**判定**: PASS

---

### C1-TODO-03: チェックポイント設定

🚩 CP-1〜CP-4 が適切に配置されているか。

- CP-1: patch ファイル Human レビュー後
- CP-2: テスト構文 PASS 確認
- CP-3: patch apply + tests/run-tests.sh PASS（Human）
- CP-4: C-4 Human PR レビュー

**判定**: PASS — 各フェーズ境界にチェックポイントが設置されている

---

### C1-TODO-04: Iron Law 遵守

HO ファイルへの AI 直接 Edit/Write が todo に含まれていないか。

Phase 1 は patch ファイル「生成」（非 HO ファイル）で HO ファイルへの直接変更なし。Phase 4（HO ファイル apply）は全て Human-owned。

**判定**: PASS — Iron Law 違反なし

---

### C1-TODO-05: 完了条件

各タスクに完了条件が明記されているか。

todo.md の全タスクに「完了条件」列があり、具体的な状態（ファイル生成済み・PASS 等）が記述されている。

**判定**: PASS

---

## TestCases チェック（3 項目）

### C1-TC-01: 受入基準との紐付き

全 AC にテストケースが紐付いているか。

test-cases.md の「受入基準 → テストケースマッピング」表で AC-1〜AC-6 の全てに TC が割り当て済み。

**判定**: PASS

---

### C1-TC-02: Edge case 網羅

重要なエッジケースが定義されているか。

- E-1: malformed JSON
- E-2: hmac_sha256 空文字列
- E-3: PLANGATE_MAINTENANCE_KEY 空文字列（設計判断保留明示）
- E-4: approvals/ 配下の非 JSON
- E-5: openssl 出力形式差異（macOS/Linux）
- E-6: BYPASS_HOOK と approval-token-guard の関係

**判定**: PASS（E-3 は設計判断が保留だが明示済みで WARN 相当）

---

### C1-TC-03: 自動化可否

自動化できないテストケースが適切に識別されているか。

- TC-01〜TC-08, TC-10, TC-11: 自動化可
- TC-09: CI 依存（自動化可だが CI 環境要）
- 全て `tests/run-tests.sh` または CI で実行可能

**判定**: PASS

---

## 総合判定

| カテゴリ | 判定 |
|---------|------|
| Plan チェック（7 項目） | PASS |
| ToDo チェック（5 項目） | PASS |
| TestCases チェック（3 項目） | PASS |
| **総合** | **PASS** |

### 指摘事項

1. **E-3（`PLANGATE_MAINTENANCE_KEY` 空文字列の挙動）**: 後方互換（通過）vs fail-closed（block）の設計判断が保留。exec 前に仕様確定を推奨。（WARN）
2. **E-6（`PLANGATE_BYPASS_HOOK=1` と approval-token-guard の関係）**: check-approval-token-write.sh が BYPASS_HOOK を無効化する設計とするか plan に明示したが、テストケースに対応ケースを追加するとより堅固。（WARN）

上記 2 点は exec 前に確認することを推奨するが、計画の根幹には影響しないため **PASS** とする。
