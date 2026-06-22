# EXECUTION PLAN — TASK-0138 (#528)

## Goal

EH-3（check-plan-hash.sh）に doc-light 経路を追加し、非 HO `.md` ファイルへの TASK 文脈なし Edit/Write を記録付き自動 SKIP にする。

## Constraints / Non-goals

- HO パス（CLAUDE.md / .claude/rules/*.md 等 9 カテゴリ）は従来 BLOCK を維持（AC-10 不変）
- plan.md の BLOCK は不変（上流ロジック非変更）
- TASK 文脈あり経路は変更しない
- maintenance.json / SKIP_REASON 経路のロジックは変更しない

## Approach Overview

`check-plan-hash.sh` の `no task_id` ブランチに doc-light 判定ブロックを追加。
挿入位置: Hardening Override 判定（step ii）直後・maintenance チェック（step iii）前。

```
HO override check (_override=1 → exit 2)
   ↓
[NEW] doc-light check: 拡張子 .md かつ 非 HO → DOC_LIGHT_SKIP + ログ → exit 0
   ↓
maintenance check (既存)
   ↓
SKIP_REASON check (既存)
```

## Work Breakdown

### Step 1: check-plan-hash.sh に doc-light 経路追加

- Output: HO 判定後・maintenance 判定前に doc-light ブロックを挿入
- Owner: AI（HO パスのため apply は Human）
- Risk: HO 判定漏れで承認境界崩壊 → ta-14 回帰テストが保護
- チェックポイント: `sh tests/extras/ta-14-hook-eh3.sh` PASS

### Step 2: ta-39-eh3-doc-light.sh 作成

- Output: doc-light 経路専用テスト（TC-01〜TC-05）
- Owner: AI
- Risk: ロジックの仕様漏れ → AC を網羅した TC で担保

### Step 3: tests/run-tests.sh に ta-39 登録

- Output: ta-39 が `sh tests/run-tests.sh` で実行されること
- Owner: AI（run-tests.sh は HO 対象外）
- Risk: 低

### Step 4: apply-script 生成（HO 適用用）

- Output: `scripts/apply-eh3-doc-light.sh` — HO ファイル変更を人間が適用するためのパッチスクリプト
- Owner: AI（作成のみ）/ Human（実行）
- Risk: スクリプト誤適用 → dry-run オプション付き

## Files / Components to Touch

| ファイル | 変更種別 | HO |
|---------|---------|-----|
| `scripts/hooks/check-plan-hash.sh` | 機能追加 | ✅ HO → apply-script 経由 |
| `tests/extras/ta-39-eh3-doc-light.sh` | 新規 | - |
| `tests/run-tests.sh` | 1行追加 | - |
| `scripts/apply-eh3-doc-light.sh` | 新規（apply用） | - |

## Testing Strategy

- Unit: ta-39（doc-light 経路 TC-01〜05）
- Regression: ta-14（既存 EH-3 TC が全 PASS）
- Integration: `sh tests/run-tests.sh` で ta-14 + ta-39 の全 TC PASS

## Risks & Mitigations

| リスク | 対策 |
|-------|------|
| HO 判定漏れ | ta-14 regression が検知。HO パスは既存 case 文を変更しない |
| plan.md への doc-light 誤適用 | plan.md は上流 case 文で BLOCK 済みのため doc-light に到達しない |
| apply-script 誤実行 | dry-run モード付き + 変更は 1 ファイルのみ |

## Mode判定

**モード**: high-risk

**判定根拠**:
- 変更ファイル数: 4 → standard
- 承認境界周辺: `scripts/hooks/check-plan-hash.sh` = HO → high-risk 強制
- lite_eligible: false（HO 対象 AC-10）
- **最終判定**: high-risk（HO 強制）

**HO 適用方式**: AI が `scripts/apply-eh3-doc-light.sh` を生成し、Human が実行。
