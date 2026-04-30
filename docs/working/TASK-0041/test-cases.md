# TEST CASES — TASK-0041 (PBI-116-06 / Issue #122)

## 受入基準 → テストケース マッピング

| AC | TC ID | 種別 |
|----|------|------|
| AC-1: 責務境界整理 | TC-1 | doc-review |
| AC-2: phase 別 allowed tools | TC-2 | 自動 + doc-review |
| AC-3: Hook enforcement 不変条件 | TC-3 | 自動（grep） + doc-review |
| AC-4: tool_policy 値ごとの射影 | TC-4 | 自動 + doc-review |
| AC-5: validation_bias: strict 追加条件 | TC-5 | 自動 + doc-review |
| AC-6: プロンプト vs runtime 強制の区別 | TC-6 | doc-review |
| AC-7: 既存 Iron Law 維持 | TC-7 | 自動（grep） |

## テストケース一覧

### TC-1: responsibility-boundary.md に 4 layer × 責務マトリクス
- 入力: `grep -E "^\| (Prompt|Tool Policy|Hook|CLI)" docs/ai/responsibility-boundary.md`
- 期待: 4 layer すべてヒット、各々に責務記述あり
- 種別: 自動 + doc-review

### TC-2: phase 別 allowed tools
- 入力: `grep -E "plan|approve-wait|exec|review|handoff" docs/ai/tool-policy.md`
- 期待: 5 phase すべて allowed tools と紐づき
- 種別: 自動 + doc-review

### TC-3: Hook enforcement 不変条件 6 件以上
- 入力: `grep -cE "ブロック|block|禁止" docs/ai/hook-enforcement.md`
- 期待: 6 件以上ヒット
- 種別: 自動

### TC-4: tool_policy 射影定義
- 入力: `grep -E "narrow|allowed_tools_by_phase|expanded" docs/ai/tool-policy.md`
- 期待: 3 値域すべて + 各々の射影記述
- 種別: 自動 + doc-review

### TC-5: validation_bias: strict 追加条件 3 件以上
- 入力: `grep -A 5 "strict" docs/ai/hook-enforcement.md | grep -cE "追加条件|additional"`
- 期待: 3 件以上
- 種別: 自動 + doc-review

### TC-6: プロンプト vs runtime 強制の区別
- 入力: `grep -E "プロンプト|runtime" docs/ai/responsibility-boundary.md`
- 期待: 両方の用語ありで対比明示
- 種別: doc-review

### TC-7: 既存 Iron Law 維持
- 入力: `grep -E "C-3 承認|scope|verification honesty" docs/ai/{responsibility-boundary,tool-policy,hook-enforcement}.md`
- 期待: Iron Law 関連が削除されず保持されている
- 種別: 自動 + doc-review

## エッジケース

### TC-E1: PBI-116-02 model-profile schema との整合
- 入力: `grep -E "tool_policy|validation_bias" docs/ai/{tool-policy,hook-enforcement}.md docs/ai/model-profiles.yaml 2>/dev/null`
- 期待: 両者で値域一致（PBI-116-02 マージ後）
- 種別: 自動 + doc-review

### TC-E2: 既存 `.claude/settings.json` hooks との衝突確認
- 入力: docs/ai/hook-enforcement.md 内の既存 hook 参照と実 settings.json の照合
- 期待: 衝突なし（既存 hooks の上に追加するか、明示的な置換であること）
- 種別: doc-review

### TC-E3: 境界定義のみで実装に踏み込まない
- 入力: docs/ai/{responsibility-boundary,tool-policy,hook-enforcement}.md 全体
- 期待: 「実装は別 PBI」「境界定義のみ」明示、コードブロックなし
- 種別: doc-review

## 自動化サマリ

| TC | 自動化 |
|----|------|
| TC-1〜TC-7 | 5 件自動、2 件 doc-review |
| TC-E1〜TC-E3 | 1 件自動、2 件 doc-review |

自動化率: 6/10。
