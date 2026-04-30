# Verification — TASK-0041 Step 7（exec PBI-116-06）

> 実施: 2026-04-30 / exec ブランチ `feat/PBI-116-06-impl`

## TC-1: responsibility-boundary.md に 4 layer 責務マトリクス

```bash
grep -E "^\| \*\*(Prompt|Tool Policy|Hook|CLI)" docs/ai/responsibility-boundary.md
```

→ 4 layer すべてヒット（Prompt / Tool Policy / Hook / CLI / validate）。✅ PASS

## TC-2: tool-policy.md に 5 phase × allowed tools

```bash
grep -E "^\| \*\*(classify|plan|approve-wait|exec|review|handoff)" docs/ai/tool-policy.md
```

→ 5 phase + handoff を含む 6 行ヒット。各々に allowed / 禁止 tools 記述。✅ PASS

## TC-3: Hook 不変条件 6 件以上

```bash
grep -cE "^### EH-[1-9]" docs/ai/hook-enforcement.md
# → 7
```

EH-1 (plan なし production 編集) / EH-2 (C-3 承認なし exec) / EH-3 (plan_hash 改竄) / EH-4 (test-cases なし V-1) / EH-5 (検証ログなし PR) / EH-6 (scope 外編集) / EH-7 (2 段階レビューなし マージ)。✅ PASS

## TC-4: tool_policy 射影定義

```bash
grep -E "narrow|allowed_tools_by_phase|expanded" docs/ai/tool-policy.md
```

§ 3 で 3 値域すべて + 各々の phase 射影記述。✅ PASS

## TC-5: validation_bias: strict 追加条件 3 件以上

```bash
grep -cE "^### EHS-[1-9]" docs/ai/hook-enforcement.md
# → 3
```

EHS-1 (V-3 必須化) / EHS-2 (handoff 必須 6 要素) / EHS-3 (V-1 fix loop 上限)。✅ PASS

## TC-6: プロンプト vs runtime 強制の区別

`responsibility-boundary.md` § 3 で「Prompt（モデル判断）に置くもの」と「Hook（runtime 強制）に置くもの」を明示分離。§ 5 では具体例 5 件で対比表。✅ PASS

## TC-7: 既存 Iron Law 維持

```bash
grep -E "C-3|C-4|scope discipline|verification honesty" docs/ai/{responsibility-boundary,tool-policy,hook-enforcement}.md
```

→ C-3 / C-4 / scope の各キーワードが各ファイルに残存、Iron Law 関連が削除されず保持。✅ PASS

## TC-E1: PBI-116-02 model-profile schema との整合

```bash
grep -E "tool_policy|validation_bias" docs/ai/{tool-policy,hook-enforcement}.md docs/ai/model-profiles.yaml
```

- model-profiles.yaml の値: `tool_policy: narrow / allowed_tools_by_phase / expanded`、`validation_bias: lenient / normal / strict`
- tool-policy.md / hook-enforcement.md でも同一値域

✅ PASS（interface-preflight.md と完全一致）

## TC-E2: 既存 `.claude/settings.json` hooks との衝突確認

`hook-enforcement.md` § 5「既存 `.claude/settings.json` hooks との関係」で:
- 既存 hooks は本ファイルの実装で参照すべき入口
- EH-1〜EH-7 + EHS-1〜EHS-3 を新規実装（重複なし）
- v8.1 ガードレール（`plugin/plangate/rules/*-gate.md`）と共存

✅ PASS

## TC-E3: 境界定義のみで実装に踏み込まない

3 ドキュメント全体で「実装は別 PBI」「境界定義のみ」を明示:
- responsibility-boundary.md § 6
- tool-policy.md § 5
- hook-enforcement.md § 4

コードブロックなし、実装 script なし。✅ PASS

## 受入基準 7 項目の総合判定

| AC | TC | 判定 |
|----|----|----|
| AC-1: 責務境界整理 | TC-1 | ✅ |
| AC-2: phase 別 allowed tools | TC-2 | ✅ |
| AC-3: Hook enforcement 不変条件（6 件以上） | TC-3 | ✅（7 件達成） |
| AC-4: tool_policy 値ごとの射影 | TC-4 | ✅ |
| AC-5: validation_bias: strict 追加条件 | TC-5 | ✅（3 件達成） |
| AC-6: プロンプト vs runtime 強制の区別 | TC-6 | ✅ |
| AC-7: 既存 Iron Law 維持 | TC-7 | ✅ |

**総合: 7/7 PASS**

## C-2 EX-06-01 / EX-06-02 対応確認

- EX-06-01（minor）「02 完了前提」表現修正 → plan.md L115 で「interface-preflight 値域を正、02 成果物が main マージ済の場合は照合」に修正済。本 PBI exec 時点では PBI-116-02 はマージ済 (cd3609b) のため、整合確認可能 ✅
- EX-06-02（info）clip relation typo 修正 → plan.md L71 で `cross relation` に修正済 ✅

✅ EX-06-01 / EX-06-02 解消

## 行数（過剰肥大化防止）

`wc -l docs/ai/{responsibility-boundary,tool-policy,hook-enforcement}.md`:
- responsibility-boundary.md: 80
- tool-policy.md: 92
- hook-enforcement.md: 115
- **合計: 287 行**（目標 300 行以下達成）✅
