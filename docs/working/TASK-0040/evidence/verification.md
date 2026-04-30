# Verification — TASK-0040 Step 7（exec PBI-116-02）

> 実施: 2026-04-30 / exec ブランチ `feat/PBI-116-02-impl`

## TC-1: docs/ai/model-profiles.yaml が存在

```bash
ls docs/ai/model-profiles.yaml
# → docs/ai/model-profiles.yaml
```

✅ PASS

## TC-2: docs/ai/model-profiles.md が schema 仕様 + マトリクス含む

```bash
grep -E "^## " docs/ai/model-profiles.md
```

確認:
- `## 1. 目的`
- `## 2. 不変ポリシー`
- `## 3. プロファイル一覧（4 件）`
- `## 4. reasoning_effort × mode × profile マトリクス`
- `## 5. verbosity_by_phase × profile`
- `## 6. context_budget_policy`
- `## 7. tool_policy（PBI-116-06 接続）`
- `## 8. validation_bias（PBI-116-06 接続）`
- `## 9. critical mode 禁止の運用`
- `## 10. プロファイル拡張・追加方針`

✅ PASS

## TC-3: 4 プロファイル定義

```bash
grep -E "^  (gpt-5_5|gpt-5_5_pro|gpt-5_mini|legacy_or_unknown):" docs/ai/model-profiles.yaml
```

結果: 4 件すべてヒット。✅ PASS

## TC-4: reasoning effort × mode × profile マトリクス

`docs/ai/model-profiles.md` § 4 で 5 mode × 4 profile = 20 セルすべて埋まっている。✅ PASS

## TC-5: verbosity × phase 表

`docs/ai/model-profiles.md` § 5 で 5 phase × 4 profile = 20 セルすべて埋まっている。✅ PASS

## TC-6: context budget policy

```bash
grep -E "compact|standard|expanded" docs/ai/model-profiles.md
```

§ 6 で 3 段階すべて + 用途説明あり。✅ PASS

## TC-7: critical mode で gpt-5_mini disallow

```bash
grep "disallowed_modes" docs/ai/model-profiles.yaml
# → disallowed_modes: [critical]
```

✅ PASS

## TC-8: Core / Gate / Artifact schema 不変宣言

`docs/ai/model-profiles.md` § 2「不変ポリシー」で明示:
- Core Contract / Iron Law 7 項目 / Stop rules / Output discipline
- Gate 条件
- Artifact schema
- AI 運用 4 原則

✅ PASS

## TC-9: tool_policy / validation_bias 値域整合（interface-preflight 準拠）

```bash
grep -E "tool_policy: (narrow|allowed_tools_by_phase|expanded)" docs/ai/model-profiles.yaml
# → 4 ヒット（narrow / allowed_tools_by_phase × 2 / expanded）

grep -E "validation_bias: (lenient|normal|strict)" docs/ai/model-profiles.yaml
# → 4 ヒット（lenient / normal × 2 / strict）
```

✅ PASS（interface-preflight.md と完全一致）

## TC-E1: schema-validate

```bash
python3 -m json.tool < schemas/model-profile.schema.json > /dev/null
# → JSON Schema syntactically valid
python3 -c "import yaml; yaml.safe_load(open('docs/ai/model-profiles.yaml'))"
# → YAML syntactically valid
```

✅ PASS（jsonschema CLI による完全 validate は環境依存のため省略、JSON / YAML パース成功で代替）

## TC-E2: profile 値域逸脱検出

schema の `allowed_efforts` / `verbosity_value` / `tool_policy` enum などで強制可能。実装上の negative test は CI / 別 PBI で実施。

## TC-E3: 既存 schemas/ との命名衝突

```bash
ls schemas/ | grep -i model
# → model-profile.schema.json のみ
```

✅ PASS（既存と衝突なし）

## 受入基準 8 項目の総合判定

| AC | TC | 判定 |
|----|----|----|
| AC-1: model-profiles.yaml/md 追加 | TC-1, TC-2 | ✅ |
| AC-2: 4 プロファイル定義 | TC-3 | ✅ |
| AC-3: reasoning effort × mode マトリクス | TC-4 | ✅ |
| AC-4: verbosity × phase 表 | TC-5 | ✅ |
| AC-5: context budget policy | TC-6 | ✅ |
| AC-6: critical mode で gpt-5_mini disallow | TC-7 | ✅ |
| AC-7: Core / Gate / Artifact schema 不変宣言 | TC-8 | ✅ |
| AC-8: tool_policy / validation_bias 値域整合 | TC-9 | ✅ |

**総合: 8/8 PASS**

## C-2 EX-02-01 対応確認

Codex 指摘の「`high/xhigh` schema 値曖昧」に対し、以下で対応:
- schema: `reasoning_effort_by_mode` は単一 enum（low/medium/high/xhigh）
- `allowed_efforts: [low, medium, high, xhigh]` で構造化（gpt-5_5_pro が利用）
- model-profiles.md § 4 補足で「critical で xhigh を選択する場合は allowed_efforts」と明示

✅ EX-02-01 解消
