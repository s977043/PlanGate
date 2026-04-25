# /pg-tdd

TDD サイクル（Red → Green → Refactor）を実行し、各ステップの証拠を Evidence Ledger に記録する。

## 目的

本番コードを書く前に失敗テストを用意する。証拠なしの「テスト通るはず」宣言を防ぐ。

## Iron Law

`NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST`

failing test の exitCode=1 証拠がない場合、Green フェーズへ進まない。

## 引数

`$ARGUMENTS` に実装したい機能・バグ修正の説明を渡す。

## 実行フロー

### Phase 1: Red（失敗テストを書く）

1. テストケースを記述する（機能の期待動作を定義）
2. テストを実行し、失敗を確認する（exitCode != 0）
3. 失敗証拠を Evidence Ledger に記録する:
   - type: "test"
   - exitCode: 1（または != 0）
   - outputExcerpt: 失敗メッセージ
   - conclusion: "期待通りの失敗 - Red フェーズ完了"

### Phase 2: Green（最小実装でテストを通す）

1. テストを通す最小実装を書く（過剰設計しない）
2. テストを実行し、成功を確認する（exitCode = 0）
3. 成功証拠を Evidence Ledger に記録する:
   - type: "test"
   - exitCode: 0
   - outputExcerpt: 成功メッセージ
   - conclusion: "テスト通過 - Green フェーズ完了"

### Phase 3: Refactor（品質改善）

1. テストを通したまま、コードをリファクタリングする
2. リファクタリング後のテストを実行し、引き続き成功を確認する
3. リファクタリング証拠を Evidence Ledger に記録する:
   - type: "test"
   - exitCode: 0
   - outputExcerpt: 成功メッセージ
   - conclusion: "リファクタリング後もテスト通過 - Refactor フェーズ完了"

## 出力フォーマット

### TDD サイクル記録

| フェーズ | 状態 | コマンド | Exit Code | 結果 |
|---------|------|--------|---------|------|
| Red | ✅ 完了 | `<テストコマンド>` | 1 | テスト失敗を確認 |
| Green | ✅ 完了 | `<テストコマンド>` | 0 | テスト通過を確認 |
| Refactor | ✅ 完了 | `<テストコマンド>` | 0 | リファクタ後も通過 |

### EvidenceLedger（/pg-verify 形式で出力）

```json
{
  "claim": "<実装した機能>の TDD サイクル完了",
  "status": "passed",
  "evidence": [
    { "id": "tdd-red", "type": "test", "exitCode": 1, "conclusion": "Red フェーズ完了" },
    { "id": "tdd-green", "type": "test", "exitCode": 0, "conclusion": "Green フェーズ完了" },
    { "id": "tdd-refactor", "type": "test", "exitCode": 0, "conclusion": "Refactor フェーズ完了" }
  ]
}
```

## GatePolicy との連携

`requiresFailingTestFirst: true` のモード（high-risk / critical）では、
Red フェーズの証拠（exitCode=1 の EvidenceItem）なしに Green フェーズへ進めない。
