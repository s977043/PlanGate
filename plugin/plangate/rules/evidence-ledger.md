# Evidence Ledger ルール（正本）

> 正本。Evidence Ledger の定義・ルール・Completion Gate 条件はこのファイルのみで管理する。
> 参照元: `evidence-ledger` Skill、`/pg verify` コマンド、`working-context.md`（evidence/ ディレクトリ）

## 目的

AIエージェントが「完了した」と主張する際に、実行コマンド・終了コード・出力抜粋・結論を証拠として記録させ、証拠なしの完了宣言を防ぐ。

## ステータス計算ルール

| 条件 | status |
|------|--------|
| `exitCode != 0` の EvidenceItem が 1 件以上ある | `"failed"` |
| `evidence` が空 | `"unknown"` |
| `missingEvidence` が 1 件以上ある | Completion Gate ブロック |
| 上記以外 | `"passed"` |

## Completion Gate ブロック条件

以下のいずれかに該当する場合、Completion Gate は passed にならない:

1. `EvidenceLedger.status` が `"failed"` または `"unknown"`
2. `EvidenceLedger.missingEvidence` が 1 件以上ある
3. EvidenceLedger 自体が存在しない（V-1 受け入れ検査フェーズ以降）

## 保存場所

```text
docs/working/TASK-XXXX/evidence/
└── verification/
    └── evidence-ledger.json   # EvidenceLedger の保存先
```

既存の `working-context.md` の `evidence/` ディレクトリ構造に統合する。

## 使用フェーズ

| フェーズ | 使用方法 |
|---------|---------|
| D（実装） | 各タスク完了時に EvidenceItem を追加 |
| V-1（受け入れ検査） | EvidenceLedger を生成し Completion Gate に渡す |
| `/pg verify` | EvidenceLedger を出力形式として使用 |

## 関連

- Skill: `evidence-ledger`（記録手順・出力形式）
- Command: `/pg verify`（実行検証フロー）
- Working context: `.claude/rules/working-context.md`（evidence/ ディレクトリ）
- Iron Law: `NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE`
