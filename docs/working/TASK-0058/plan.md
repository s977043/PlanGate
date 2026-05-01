# EXECUTION PLAN: TASK-0058 / Issue #169 セッション C

> Mode: **critical**

## Goal

#169 残 2 hook（EH-7 + EHS-1）を実装し、**10/10 hooks 完走**で #169 close。次の milestone (v8.5) 候補へ。

## Approach

### EH-7: check-merge-approvals.sh（CLI）
- `approvals/c3.json` の `c3_status` と `approvals/c4-approval.json` (or `c4.json`) の `c4_status` をどちらも `APPROVED` 確認
- 既存 `read_status` ヘルパパターンで grep + sed 抽出
- 片方でも欠損 / 別ステータス → warn（default）/ exit 1（strict）/ exit 0（bypass）
- branch protection 自動連携は scope 外（CLI 検証のみ）

### EHS-1: check-v3-review.sh（CLI、mode 連携）
- `PLANGATE_HOOK_MODE` 環境変数で対象 PBI mode を受領
  - light / ultra-light → SKIP（V-3 不要）
  - standard / high-risk / critical → 必須化
- `docs/working/$TASK/review-external.md` または `evidence/v3-review/*` の存在確認
- 不在で warn / strict 時 exit 1

## 変更ファイル

| ファイル | 種別 |
|---------|------|
| `scripts/hooks/check-merge-approvals.sh` | 新規 |
| `scripts/hooks/check-v3-review.sh` | 新規 |
| `tests/hooks/run-tests.sh` | 編集（fixture + 9 件追加）|
| `tests/fixtures/hooks/{both-approvals,v3-review-exists}/` | 新規 |
| `docs/ai/hook-enforcement.md` | 編集（Status v4 → v5、§ 4 表 + 4.5 完了宣言）|
| `docs/working/TASK-0058/*` | 新規 |

## Mode判定

**critical**（既存 EH パターン踏襲、ロールバック容易、3 mode 設計で誤検出緩和）

## Risks & Mitigations

| Risk | Mitigation |
|------|----------|
| EH-7 で c4 ファイル名揺れ（`c4.json` vs `c4-approval.json`）| 両方フォールバック対応（c4-approval.json 優先、なければ c4.json）|
| EHS-1 で C-2 と V-3 の混在（同 review-external.md を使う）| 本 PBI では「review-external.md があれば PASS」で十分、phase 分離は v2 候補 |
| mode 環境変数未指定 | デフォルト `standard` として安全側（必須化） |
| 既存 review-external.md fixture 流用で他 hook test に影響 | fixture は本 PBI 専用 dir（v3-review-exists/）に配置、他 hook test と独立 |

## 確認方法

- `sh tests/hooks/run-tests.sh` → **42 件 PASS**
- `sh tests/run-tests.sh` → 24 件 PASS
- `grep "Status.*v5" docs/ai/hook-enforcement.md` ヒット
- `grep "10/10" docs/ai/hook-enforcement.md` ヒット
- PR マージで `#169` が auto-close される
