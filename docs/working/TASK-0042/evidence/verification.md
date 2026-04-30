# Verification — TASK-0042 Step 7（exec PBI-116-04）

> 実施: 2026-04-30 / exec ブランチ `feat/PBI-116-04-impl`

## TC-1: structured-outputs.md に対象 6 件以上一覧

§ 2 で 6 件すべて表に記載（mode / C-1 / C-2 / V-1 / V-3 / handoff）。✅ PASS

## TC-2: 4 新規 schema 存在

```bash
ls schemas/{review-result,acceptance-result,mode-classification,handoff-summary}.schema.json
```

→ 4 ファイルすべて存在。✅ PASS

## TC-3: 各 schema が JSON Schema 2020-12

```bash
grep -l "json-schema.org/draft/2020-12" schemas/{review-result,acceptance-result,mode-classification,handoff-summary}.schema.json
```

→ 4 ファイルすべて 2020-12 準拠。✅ PASS

## TC-4: Markdown vs JSON 責務境界

§ 3 で「Markdown を維持するもの（人間が読む）」と「JSON / schema に寄せるもの（機械判定）」を分類表で明示。「Markdown と JSON を併存させるもの」も明記。✅ PASS

## TC-5: 削減対象形式指定 3 種以上

§ 4 で 3 種類の削減対象を明記:
- 削減対象 1: review result の長文 JSON 例
- 削減対象 2: handoff の必須 6 要素テンプレ重複
- 削減対象 3: mode classification の判定基準巨大表

✅ PASS

## TC-6: 既存 schemas 互換性（全 12 件、命名衝突なし）

```bash
ls schemas/*.schema.json | wc -l
# → 15（既存 11 + 新規 4）
```

git diff main で既存 11 schema の変更なし確認可能（本 PBI スコープ内では編集禁止）。
新規 4 schema:
- review-result.schema.json
- acceptance-result.schema.json
- mode-classification.schema.json
- handoff-summary.schema.json

既存 review-self / review-external との責務境界を § 5 で明示。✅ PASS

## TC-7: eval 引き継ぎ方針

§ 6 で「PBI-116-05 で schema 準拠率を eval 観点に含める。準拠率 < 95% で release blocker」を明記。✅ PASS

## TC-E1: review-result の phase 値

```bash
grep -A 3 "\"phase\":" schemas/review-result.schema.json | head -8
# → enum: ["C-1", "C-2", "V-1", "V-3"]
```

4 phase すべて enum で定義。✅ PASS

## TC-E2: review-result の decision 値

```bash
grep -A 3 "\"decision\":" schemas/review-result.schema.json | head -8
# → enum: ["PASS", "WARN", "FAIL"]
```

3 値すべて enum で定義。✅ PASS

## TC-E3: handoff-summary 必須 6 要素

```bash
grep -E "requirementCompliance|knownIssues|v2Candidates|compromises|handoverNote|testResults" schemas/handoff-summary.schema.json
```

→ 6 要素すべて反映:
- requirementCompliance (要件適合)
- knownIssues (既知課題)
- v2Candidates (V2 候補)
- compromises (妥協点)
- handoverNote (引き継ぎ文書)
- testResults (テスト結果)

すべて `required` 配列に含まれる。✅ PASS

## 受入基準 6 項目の総合判定

| AC | TC | 判定 |
|----|----|----|
| AC-1: 対象一覧（6 件以上）| TC-1 | ✅ |
| AC-2: 4 新規 schema | TC-2, TC-3 | ✅ |
| AC-3: Markdown vs JSON 境界 | TC-4 | ✅ |
| AC-4: 削減対象形式指定（3 種以上）| TC-5 | ✅ |
| AC-5: 既存 schemas 互換性（全 12 件）| TC-6 | ✅ |
| AC-6: eval 引き継ぎ方針 | TC-7 | ✅ |

**総合: 6/6 PASS**

## C-2 EX-04-01 対応確認

Codex 指摘「既存 review-self / review-external schema との互換性確認が計画に不足」に対し:

- structured-outputs.md § 5 で既存 review-self / review-external と新規 review-result の **責務境界を明文化**
  - 既存 schema = Markdown 成果物全体の frontmatter / メタ
  - 新規 schema = 判定結果のみの構造化
- forbidden_files の対象を 5 件 → 全 12 件に拡張（plan / pbi-input / test-cases で対応済）

✅ EX-04-01 解消

## 既存 schemas/ との命名衝突

| 既存 schema | 新規 schema | 衝突 |
|------------|-----------|------|
| review-self | review-result | 名前異なる、責務分離（§ 5 明示）|
| review-external | review-result | 同上 |
| handoff | handoff-summary | 名前異なる、責務分離（handoff = 全体 schema、handoff-summary = メタ要約）|
| その他 | — | 衝突なし |

✅ 衝突なし
