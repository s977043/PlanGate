---
name: evidence-ledger
description: "完了主張を証拠付きで記録し、EvidenceLedger を出力する。Use when: 「完了した」「修正した」「テストが通った」と言う前に証拠を記録したい時。/pg verify の出力先として使用。「証拠を残したい」「完了判定をしたい」「TDD証跡を残したい」「Completion Gateに渡したい」。"
---

# Evidence Ledger

完了主張を証拠付きで記録し、EvidenceLedger として出力する。

## Iron Law

`NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE`

「should work now」「probably fixed」「テスト通るはず」等の推測的完了宣言は禁止。
コマンド実行結果・終了コード・出力抜粋を証拠として記録せよ。

TDD 必須 mode では、単なる「テストが通った」だけでは不十分。
**RED（期待通り失敗）→ GREEN（最小実装で成功）→ REFACTOR VERIFY（整理後も成功）** の証跡を分けて記録する。

## Common Rationalizations

| こう思ったら | 現実 |
|---|---|
| 「CIが通ったから証拠不要」 | CI はカバレッジの保証ではない。claim ごとに証拠を記録せよ |
| 「小さな修正だから証拠不要」 | 規模は関係ない。exitCode=0 を確認して記録せよ |
| 「レビューしたから大丈夫」 | review type の EvidenceItem として記録せよ |
| 「テストが通ったからTDD済み」 | GREENだけではTDD証跡にならない。REDの失敗理由も記録せよ |
| 「REDは見たがログは残していない」 | high-risk / critical では RED 証跡がなければ Completion Gate で block 対象 |

## データスキーマ

### EvidenceStatus

```json
"passed" | "failed" | "skipped" | "unknown"
```

### EvidenceType

```json
"command" | "diff" | "test" | "review" | "manual"
```

### EvidencePhase

`phase` は任意フィールド。ただし `type="test"` かつ TDD 証跡として使う場合は必須。

```json
"tdd_red" | "tdd_green" | "refactor_verify" | "verification" | "baseline"
```

| phase | 用途 | 期待する exitCode |
|---|---|---|
| `baseline` | 実装前の既存テスト確認 | `0` |
| `tdd_red` | failing test が期待通り失敗することの確認 | `!= 0` |
| `tdd_green` | 最小実装で対象テストが成功することの確認 | `0` |
| `refactor_verify` | refactor後も対象テスト・関連検証が成功することの確認 | `0` |
| `verification` | TDD以外の通常検証 | `0` |

`tdd_red` の `exitCode != 0` は失敗ではなく、**期待されたRED証跡**として扱う。ただし、`conclusion` には「なぜ期待通りの失敗と言えるか」を必ず書く。

### EvidenceItem

```json
{
  "id": "string（例: ev-001）",
  "type": "command | diff | test | review | manual",
  "phase": "baseline | tdd_red | tdd_green | refactor_verify | verification（任意。TDD証跡では必須）",
  "command": "string（type=command/test の場合）",
  "exitCode": "number（type=command/test の場合）",
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

### TddEvidenceLedger

TDD必須modeの実装タスクでは、EvidenceLedgerに以下のTDD証跡が含まれていること。

```json
{
  "claim": "Task N の実装はTDDで完了した",
  "status": "passed",
  "evidence": [
    {
      "id": "ev-001",
      "type": "test",
      "phase": "tdd_red",
      "command": "pnpm test path/to/test.test.ts",
      "exitCode": 1,
      "outputExcerpt": "Expected failure: function is not defined",
      "filePath": "path/to/test.test.ts",
      "conclusion": "未実装の対象関数が存在しないため、追加したテストが期待通り失敗した",
      "createdAt": "2026-06-21T10:00:00+09:00"
    },
    {
      "id": "ev-002",
      "type": "test",
      "phase": "tdd_green",
      "command": "pnpm test path/to/test.test.ts",
      "exitCode": 0,
      "outputExcerpt": "1 passed",
      "filePath": "path/to/test.test.ts",
      "conclusion": "最小実装により対象テストが成功した",
      "createdAt": "2026-06-21T10:03:00+09:00"
    },
    {
      "id": "ev-003",
      "type": "test",
      "phase": "refactor_verify",
      "command": "pnpm test path/to/test.test.ts && pnpm typecheck",
      "exitCode": 0,
      "outputExcerpt": "1 passed; typecheck passed",
      "filePath": "path/to/test.test.ts",
      "conclusion": "refactor後も対象テストと型検査が成功した",
      "createdAt": "2026-06-21T10:06:00+09:00"
    }
  ],
  "missingEvidence": []
}
```

## 手順

### ステップ 1: claim を宣言する

完了を主張したい事柄を 1 文で記述する。

例: `"ログイン 500 エラーを修正した"`

TDD必須modeの例:

```json
"Task 3: validation helper はTDDで実装完了した"
```

### ステップ 2: evidence を収集する

claim に対して実行したコマンド・確認した差分・レビュー結果を記録する。

**command type**:
```bash
# コマンドを実行して exitCode と出力を記録
pnpm test auth.test.ts
# exitCode=0, outputExcerpt="12 passed"
```

**test type**: テストファイルのパス、phase、コマンド、exitCode、結果を記録

**TDD RED**:
```bash
pnpm test path/to/test.test.ts
# exitCode != 0, outputExcerpt="期待した失敗理由"
```

**TDD GREEN**:
```bash
pnpm test path/to/test.test.ts
# exitCode=0, outputExcerpt="1 passed"
```

**refactor verify**:
```bash
pnpm test path/to/test.test.ts && pnpm typecheck
# exitCode=0, outputExcerpt="pass"
```

**diff type**: 変更ファイルのパスと差分サマリを記録

**review type**: レビュアー名と結論を記録

**manual type**: 手動確認した内容と結論を記録

### ステップ 3: status を計算する

以下のルールを順番に適用する:

1. `missingEvidence` が 1 件でもある → Completion Gate がブロックされる
2. `phase` が未指定、または `phase != "tdd_red"` の EvidenceItem で `exitCode != 0` が 1 件でもある → `status = "failed"`（`phase` 省略時は tdd_red 以外として扱う）
3. `phase = "tdd_red"` で `exitCode = 0` → `status = "failed"`（REDになっていない）
4. `phase = "tdd_red"` で `exitCode != 0` かつ `conclusion` が期待失敗を説明している → RED証跡として有効
5. `evidence` が空 → `status = "unknown"`
6. 上記いずれでもない → `status = "passed"`

### ステップ 4: TDD必須modeの不足証跡を判定する

`requiresFailingTestFirst=true` の場合、以下の欠落は `missingEvidence` に追加する。

- `phase="tdd_red"` のEvidenceItemがない
- `phase="tdd_green"` のEvidenceItemがない
- REDの失敗理由が期待失敗として説明されていない（判定方針: `conclusion` が非空かつ失敗内容に言及していること。期待との厳密一致は LLM 補助判定とし、機械チェックの最低条件は `conclusion` 非空 + `exitCode != 0`）
- GREENの成功コマンド・exitCode・出力抜粋がない
- refactorを行ったのに `phase="refactor_verify"` がない（判定方針: 直前の `tdd_green` 証跡以降に**ソースコード変更ありかつテストコード変更なし**を refactor とみなす。機械判定が不能な場合は安全側で `refactor_verify` を必須化せず任意とする）

### ステップ 5: EvidenceLedger を出力する

```json
{
  "claim": "ログイン 500 エラーを修正した",
  "status": "passed",
  "evidence": [
    {
      "id": "ev-001",
      "type": "command",
      "phase": "verification",
      "command": "pnpm test auth.test.ts",
      "exitCode": 0,
      "outputExcerpt": "12 passed",
      "conclusion": "auth 関連テストは全て成功",
      "createdAt": "2026-04-26T10:00:00Z"
    },
    {
      "id": "ev-002",
      "type": "command",
      "phase": "verification",
      "command": "pnpm typecheck",
      "exitCode": 0,
      "outputExcerpt": "No errors",
      "conclusion": "型エラーなし",
      "createdAt": "2026-04-26T10:01:00Z"
    }
  ],
  "missingEvidence": []
}
```

## 保存先

### 通常検証

`/pg verify` コマンドは Evidence Ledger を出力形式として使用する。
verify コマンド実行時は本スキルの手順に従い EvidenceLedger JSON を生成し、
`docs/working/TASK-XXXX/evidence/verification/` に保存する。

### TDD証跡

TDD必須modeでは、TDD証跡を以下に保存する。

```text
docs/working/TASK-XXXX/evidence/tdd/
├── task-001-red.json
├── task-001-green.json
├── task-001-refactor-verify.json
└── task-001-ledger.json
```

`task-N-ledger.json` は、RED / GREEN / REFACTOR VERIFY をまとめた EvidenceLedger とする。

## 出力フォーマット

EvidenceLedger JSON を出力する。
`status = "failed"` または `missingEvidence` が存在する場合は、
Completion Gate へ「ブロック」として通知する。
