# Verification — TASK-0043 Step 7（exec PBI-116-03）

> 実施: 2026-04-30 / exec ブランチ `feat/PBI-116-03-impl`

## TC-1: 4 層定義

```bash
grep -cE "base_contract|phase_contract|risk_mode_contract|model_adapter" docs/ai/prompt-assembly.md
# → 9（4 層すべて複数箇所で言及、責務マトリクス + 構造図 + 解決ロジック）
```

✅ PASS

## TC-2: 各層の責務境界

prompt-assembly.md § 2 で 4 layer × 役割 / 変更頻度 / 配置の責務マトリクス完備。✅ PASS

## TC-3: 7 phase contract

```bash
ls docs/ai/contracts/*.md | wc -l
# → 7
```

classify / plan / approve-wait / execute / review / verify / handoff すべて存在、各 50 行以下。✅ PASS

## TC-4: 4 model adapter（schema enum 全件）

```bash
ls docs/ai/adapters/*.md | wc -l
# → 4
```

outcome_first / outcome_first_strict / explicit_short / legacy_or_unknown すべて存在。✅ PASS

## TC-5: prompt full fork 回避方針

prompt-assembly.md § 6「モデル別 prompt full fork を避ける方針」セクション + § 1 冒頭「モデル変更時にプロンプト全文を fork せず adapter 差替え」明記。✅ PASS

## TC-6: .claude / plugin 両適用構造

prompt-assembly.md § 7「`.claude/` と `plugin/plangate/` への適用」で論理的な適用範囲を明示。✅ PASS

## TC-7: 解決ロジック（擬似コード）

prompt-assembly.md § 5 で TypeScript 型定義（`PlanGatePromptContext` / `PhaseId` / `ModeId`）+ `assemble()` / `resolveVerbosity()` 関数の擬似コード。✅ PASS

## TC-E1: adapter enum 完全一致（C-2 EX-03-03 強化）

```bash
jq -r '."$defs".profile.properties.adapter.enum[]' schemas/model-profile.schema.json | sort > /tmp/schema-adapters.txt
ls docs/ai/adapters/*.md | xargs -I {} basename {} .md | sort > /tmp/doc-adapters.txt
diff /tmp/schema-adapters.txt /tmp/doc-adapters.txt
# → empty（PASS、完全一致）
```

✅ PASS

## TC-E2: 過剰肥大化防止

```bash
wc -l docs/ai/prompt-assembly.md docs/ai/contracts/*.md docs/ai/adapters/*.md
```

- prompt-assembly.md: 170 行（200 以下 ✅）
- contracts/*.md: 28-36 行（各 50 以下 ✅）
- adapters/*.md: 40-49 行（各 50 以下 ✅）
- **合計: 574 行**（700 以下 ✅）

✅ PASS

## TC-E3: 既存 docs/ai/ との命名衝突

```bash
ls docs/ai/contracts/ docs/ai/adapters/
```

新規サブディレクトリ `contracts/` `adapters/` で既存 `docs/ai/*.md`（core-contract / model-profiles / structured-outputs / responsibility-boundary / tool-policy / hook-enforcement）と衝突なし。✅ PASS

## 受入基準 7 項目の総合判定

| AC | TC | 判定 |
|----|----|----|
| AC-1: 4 層定義 | TC-1 | ✅ |
| AC-2: 各層の責務境界 | TC-2 | ✅ |
| AC-3: 7 phase contract | TC-3 | ✅ |
| AC-4: 4 model adapter（schema enum 全件） | TC-4 | ✅ |
| AC-5: prompt full fork 回避方針 | TC-5 | ✅ |
| AC-6: .claude / plugin 両適用構造 | TC-6 | ✅ |
| AC-7: 解決ロジック（擬似コード） | TC-7 | ✅ |

**総合: 7/7 PASS**

## C-2 全 5 件の対応確認

| ID | 対応箇所 | 確認 |
|----|---------|------|
| EX-03-01 (major) | prompt-assembly.md § 4 | ✅ Core Contract v1 互換説明（6→7 phase） |
| EX-03-02 (major) | PBI-116-03.yaml allowed_files に `docs/working/TASK-0043/**` | ✅ 前 PR で対応済 |
| EX-03-03 (minor) | TC-E1 jq + diff | ✅ 完全一致確認 |
| EX-03-04 (minor) | adapter 4 種 = schema enum 全件 | ✅ 完全一致 |
| EX-03-05 (info) | prompt-assembly.md § 3「上位概念との接続」 | ✅ Responsibility Boundary との関係明示 |

## Phase 2 verbosity 互換確認（追加 Gemini 指摘対応）

prompt-assembly.md § 4「Phase 2 schema 互換」 + § 5 解決ロジック `resolveVerbosity()`:

- approve-wait → null（不適用）
- verify → review 値継承
- 他 5 phase → schema 値そのまま

contracts/approve-wait.md と contracts/verify.md でも明記。✅ PASS
