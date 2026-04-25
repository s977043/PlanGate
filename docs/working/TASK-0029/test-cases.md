# テストケース定義: TASK-0029

> 生成日: 2026-04-26

## 受入基準 → テストケースマッピング

| AC | 受入基準 | テストケース ID |
|----|---------|--------------|
| AC-1 | Intent を 7 分類できる（structured output） | TC-01, TC-02, TC-03 |
| AC-2 | Mode を判定できる（定量・定性基準） | TC-04, TC-05 |
| AC-3 | Intent + Mode から GatePolicy を返せる | TC-06, TC-07 |
| AC-4 | high-risk 以上で approval/worktree/TDD/review/verify が必須 | TC-08 |
| AC-5 | ultra-light/light では重いゲートを要求しない | TC-09 |
| AC-6 | test-cases.md にテストケースが記述されている | TC-10 |
| AC-7 | README または docs に mode 分類基準が記載されている | TC-11 |

## テストケース一覧

### TC-01: feature Intent の分類

| 項目 | 内容 |
|------|------|
| 前提条件 | intent-classifier SKILL.md が存在する |
| 入力 | `「ログイン機能を追加してほしい」` |
| 期待出力 | `{ "intent": "feature", "confidence": 0.9以上, "reasoning": "..." }` |
| 種別 | Skill 仕様突合 |

### TC-02: bug Intent の分類

| 項目 | 内容 |
|------|------|
| 前提条件 | intent-classifier SKILL.md が存在する |
| 入力 | `「認証画面でエラーが発生しているのを直してほしい」` |
| 期待出力 | `{ "intent": "bug", "confidence": 0.8以上, "reasoning": "..." }` |
| 種別 | Skill 仕様突合 |

### TC-03: 7 分類の網羅性確認

| 項目 | 内容 |
|------|------|
| 前提条件 | intent-classifier SKILL.md が存在する |
| 入力 | SKILL.md の分類定義セクション |
| 期待出力 | feature / bug / refactor / research / review / docs / ops の 7 種類が全て定義されている |
| 種別 | ドキュメント仕様確認 |

### TC-04: Mode 定量基準による判定

| 項目 | 内容 |
|------|------|
| 前提条件 | mode-classification.md が更新済みである |
| 入力 | 変更ファイル数=1, 受入基準数=1, 変更種別=typo修正 |
| 期待出力 | Mode = `ultra-light` |
| 種別 | ドキュメント仕様確認 |

### TC-05: `full` ラベルが `high-risk` にリネームされている

| 項目 | 内容 |
|------|------|
| 前提条件 | mode-classification.md が存在する |
| 入力 | mode-classification.md の内容全体 |
| 期待出力 | `full` というラベルが存在せず、`high-risk` が定義されている |
| 種別 | ドキュメント仕様確認 |

### TC-06: ultra-light Mode の GatePolicy

| 項目 | 内容 |
|------|------|
| 前提条件 | skill-policy-router SKILL.md が存在する |
| 入力 | `{ "intent": "docs", "mode": "ultra-light" }` |
| 期待出力 | `{ "requiresUserApproval": false, "requiresWorktree": false, "requiresFailingTestFirst": false, "requiredSkills": ["verify"] }` |
| 種別 | Skill 仕様突合 |

### TC-07: high-risk Mode の GatePolicy

| 項目 | 内容 |
|------|------|
| 前提条件 | skill-policy-router SKILL.md が存在する |
| 入力 | `{ "intent": "feature", "mode": "high-risk" }` |
| 期待出力 | `requiredSkills` に `think`, `approval`, `worktree`, `tdd`, `check`, `review`, `verify` が全て含まれる |
| 種別 | Skill 仕様突合 |

### TC-08: high-risk 以上での必須ゲート確認

| 項目 | 内容 |
|------|------|
| 前提条件 | skill-policy-router SKILL.md が存在する |
| 入力 | mode = `high-risk` および mode = `critical` それぞれのポリシー定義 |
| 期待出力 | 両 Mode で `requiresUserApproval=true`, `requiresWorktree=true`, `requiresFailingTestFirst=true`, `requiredSkills` に `review` と `verify` が含まれる |
| 種別 | Skill 仕様突合 |

### TC-09: ultra-light / light での軽量ゲート確認

| 項目 | 内容 |
|------|------|
| 前提条件 | skill-policy-router SKILL.md が存在する |
| 入力 | mode = `ultra-light` および mode = `light` それぞれのポリシー定義 |
| 期待出力 | 両 Mode で `requiresUserApproval=false`, `requiresWorktree=false`, `requiresFailingTestFirst=false` |
| 種別 | Skill 仕様突合 |

### TC-10: test-cases.md の存在確認

| 項目 | 内容 |
|------|------|
| 前提条件 | docs/working/TASK-0029/ ディレクトリが存在する |
| 入力 | docs/working/TASK-0029/test-cases.md |
| 期待出力 | ファイルが存在し、7 件の受入基準に対応するテストケースが記述されている |
| 種別 | 成果物存在確認 |

### TC-11: mode 分類基準のドキュメント確認

| 項目 | 内容 |
|------|------|
| 前提条件 | mode-classification.md が存在する |
| 入力 | plugin/plangate/rules/mode-classification.md |
| 期待出力 | ultra-light / light / standard / high-risk / critical の 5 段階モードと GatePolicy 定義が記載されている |
| 種別 | ドキュメント仕様確認 |

## エッジケース

| ケース | 対応方針 |
|--------|---------|
| Intent が曖昧で複数候補あり | confidence を下げて上位候補を reasoning に記載する |
| Mode 判定で定量・定性が不一致 | 高い方を採用（mode-classification.md の判定ロジックに従う） |
| GatePolicy で unknown の Intent が渡された | intent に関わらず mode のみで GatePolicy を決定する |
