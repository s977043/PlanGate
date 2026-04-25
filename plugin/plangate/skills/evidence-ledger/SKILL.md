---
name: evidence-ledger
description: "完了主張を証拠付きで記録し、EvidenceLedger を出力する。Use when: 「完了した」「修正した」「テストが通った」と言う前に証拠を記録したい時。/pg verify の出力先として使用。「証拠を残したい」「完了判定をしたい」「Completion Gateに渡したい」。"
---

# Evidence Ledger

完了主張を証拠付きで記録し、EvidenceLedger として出力する。

## Iron Law

`NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE`

「should work now」「probably fixed」「テスト通るはず」等の推測的完了宣言は禁止。
コマンド実行結果・終了コード・出力抜粋を証拠として記録せよ。

## Common Rationalizations

| こう思ったら | 現実 |
|---|---|
| 「CIが通ったから証拠不要」 | CI はカバレッジの保証ではない。claim ごとに証拠を記録せよ |
| 「小さな修正だから証拠不要」 | 規模は関係ない。exitCode=0 を確認して記録せよ |
| 「レビューしたから大丈夫」 | review type の EvidenceItem として記録せよ |

## データスキーマ

### EvidenceStatus

```json
"passed" | "failed" | "skipped" | "unknown"
```

### EvidenceItem

```json
{
  "id": "string（例: ev-001）",
  "type": "command | diff | test | review | manual",
  "command": "string（type=command の場合）",
  "exitCode": "number（type=command の場合）",
  "outputExcerpt": "string（出力の一部抜粋）",
  "filePath": "string（type=diff/test の場合）",
  "reviewer": "string（type=review の場合）",
  "conclusion": "string（必須 - この証拠から何が言えるか）",
  "createdAt": "string（ISO 8601）"
}
```

### EvidenceLedger

```json
{
  "claim": "string（完了したという主張）",
  "status": "EvidenceStatus",
  "evidence": "EvidenceItem[]",
  "missingEvidence": "string[]（必須だが欠けている証拠の説明）"
}
```

## 手順

### ステップ 1: claim を宣言する

完了を主張したい事柄を 1 文で記述する。

例: `"ログイン 500 エラーを修正した"`

### ステップ 2: evidence を収集する

claim に対して実行したコマンド・確認した差分・レビュー結果を記録する。

**command type**:
```bash
# コマンドを実行して exitCode と出力を記録
pnpm test auth.test.ts
# exitCode=0, outputExcerpt="12 passed"
```

**test type**: テストファイルのパスと結果を記録

**diff type**: 変更ファイルのパスと差分サマリを記録

**review type**: レビュアー名と結論を記録

**manual type**: 手動確認した内容と結論を記録

### ステップ 3: status を計算する

以下のルールを順番に適用する:

1. `exitCode != 0` の EvidenceItem が 1 件でもある → `status = "failed"`
2. `missingEvidence` が 1 件でもある → Completion Gate がブロックされる
3. `evidence` が空 → `status = "unknown"`
4. 上記いずれでもない → `status = "passed"`

### ステップ 4: EvidenceLedger を出力する

```json
{
  "claim": "ログイン 500 エラーを修正した",
  "status": "passed",
  "evidence": [
    {
      "id": "ev-001",
      "type": "command",
      "command": "pnpm test auth.test.ts",
      "exitCode": 0,
      "outputExcerpt": "12 passed",
      "conclusion": "auth 関連テストは全て成功",
      "createdAt": "2026-04-26T10:00:00Z"
    },
    {
      "id": "ev-002",
      "type": "command",
      "command": "pnpm typecheck",
      "exitCode": 0,
      "outputExcerpt": "No errors",
      "conclusion": "型エラーなし",
      "createdAt": "2026-04-26T10:01:00Z"
    }
  ]
}
```

## /pg verify との連携

`/pg verify` コマンドは Evidence Ledger を出力形式として使用する。
verify コマンド実行時は本スキルの手順に従い EvidenceLedger JSON を生成し、
`docs/working/TASK-XXXX/evidence/verification/` に保存する。

## 出力フォーマット

EvidenceLedger JSON を出力する。
`status = "failed"` または `missingEvidence` が存在する場合は、
Completion Gate へ「ブロック」として通知する。
