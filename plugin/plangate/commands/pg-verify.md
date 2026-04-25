# /pg-verify

完了宣言前の証拠確認を行い、Evidence Ledger を出力する。

## 目的

「完了した」「直した」「テストが通るはず」という推測的完了宣言を防ぐ。
実行コマンド・終了コード・出力抜粋を証拠として記録し、EvidenceLedger を生成する。

## Iron Law

`NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE`

exitCode=0 の証拠がない状態で完了を宣言しない。

## 引数

`$ARGUMENTS` に完了を主張したい事柄（claim）を渡す。

## 前提条件

- `evidence-ledger` Skill が利用可能なこと
- 検証すべきコマンドが実行可能なこと

## 実行フロー

1. **Claim**: 完了を主張したい事柄を 1 文で記述する
2. **Commands Run**: 実行したコマンドと結果を記録する
3. **Exit Codes**: 各コマンドの終了コードを確認する
4. **Output Excerpts**: 関連する出力抜粋を記録する
5. **Conclusion**: 証拠に基づいた結論を述べる
6. **EvidenceLedger 出力**: `evidence-ledger` Skill の形式で JSON を出力する

## 出力フォーマット

### Claim

\<完了を主張したい事柄\>

### Commands Run

| コマンド | Exit Code | 出力抜粋 |
|--------|---------|--------|
| `<コマンド 1>` | 0 | `<出力>` |

### Conclusion

\<証拠に基づいた結論\>

### EvidenceLedger

```json
{
  "claim": "<主張>",
  "status": "passed | failed | unknown",
  "evidence": [
    {
      "id": "ev-001",
      "type": "command",
      "command": "<コマンド>",
      "exitCode": 0,
      "outputExcerpt": "<出力抜粋>",
      "conclusion": "<この証拠から言えること>",
      "createdAt": "<ISO 8601>"
    }
  ]
}
```

## 保存先

生成した EvidenceLedger は `docs/working/TASK-XXXX/evidence/verification/evidence-ledger.json` に保存する。

## GatePolicy との連携

全モードで `verify` は `requiredSkills` に含まれる。
`skill-policy-router` から自動要求される。
