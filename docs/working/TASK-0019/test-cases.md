# TASK-0019 テストケース定義

> 生成日: 2026-04-19

## 受入基準 → テストケース マッピング

| 受入基準 | テストケースID | 種別 |
|---------|--------------|------|
| 8 agents 全てが plugin/plangate/agents/ 配下に存在 | TC-1 | Unit |
| 各 agent 定義から固有前提が除去されている | TC-2 | Integration |
| rules 3 ファイルが plugin/plangate/rules/ 配下に存在 | TC-3 | Unit |
| plugin.json の agents / rules エントリが正しく記載 | TC-4 | Unit |
| plan → C-1 → exec → L-0 → V-1 → PR フロー完結 | TC-5 | E2E |
| agents 間相互参照が plugin 内で解決 | TC-6 | Integration |
| rules 3 ファイルが plugin 内 agents から参照可能 | TC-7 | Integration |
| 既存 .claude/agents/ 側の動作が壊れていない | TC-8 | Integration |
| plugin 中核スクリプトが bin/ に配置 | TC-9 | Unit |

## テストケース一覧

### TC-1: 8 agents ファイル存在確認

- **前提条件**: TASK-0017, TASK-0018 完了
- **入力**: `ls plugin/plangate/agents/*.md`
- **期待出力**: 8 ファイル: workflow-conductor, spec-writer, implementer, test-engineer, linter-fixer, acceptance-tester, code-optimizer, release-manager
- **種別**: Unit

### TC-2: 固有前提除去確認

- **前提条件**: TC-1 パス
- **入力**: `grep -r "Laravel\|PostgreSQL\|Eloquent\|ECS\|CodeBuild\|CodeDeploy\|Cloudflare\|Vitest\|PHPUnit" plugin/plangate/agents/`
- **期待出力**: 0 件（汎用化済み）
- **種別**: Integration

### TC-3: rules 3 ファイル存在確認

- **前提条件**: TC-1 パス
- **入力**: `ls plugin/plangate/rules/`
- **期待出力**: 3 ファイル: `working-context.md`, `review-principles.md`, `mode-classification.md`
- **種別**: Unit

### TC-4: plugin.json agents/rules エントリ件数

- **前提条件**: `plugin/plangate/.claude-plugin/plugin.json` 存在
- **入力**:
  ```bash
  python3 -c "import json; d=json.load(open('plugin/plangate/.claude-plugin/plugin.json')); print(len(d.get('agents',[])), len(d.get('rules',[])))"
  ```
- **期待出力**: `8 3`
- **種別**: Unit

### TC-5: フロー完結検証

- **前提条件**: TC-1〜TC-4 全てパス
- **入力**: 小規模テストチケット（例: typo 修正）を plugin 内 8 agents のみで plan → C-1 → exec → L-0 → V-1 → PR まで実行
- **期待出力**: 全フェーズが plugin 内 agents で完結、各ステップの成果物（plan.md, review-self.md, コミット, PR）が生成される。結果は `evidence/flow-completion-test.md` に記録
- **種別**: E2E

### TC-6: agents 間相互参照検証（prefix / 解決規則一致）

- **前提条件**: TC-1 パス、T-3a で `evidence/reference-resolution.md` に参照方式（例: `plangate:implementer` prefix、rules は `plugin/plangate/rules/` 絶対参照）が確定
- **入力**: `workflow-conductor` の定義から他 7 agents への参照記述を抽出し、`reference-resolution.md` で定義された prefix / 解決規則に一致するかを照合
- **期待出力**: すべての参照が `reference-resolution.md` の規則に準拠し、plugin 内で解決可能
- **種別**: Integration

### TC-7: rules 参照解決確認

- **前提条件**: TC-3 パス
- **入力**: agents 内の rules 参照記述（例: `working-context.md` を参照する箇所）を抽出し、plugin 内パスを指すか確認
- **期待出力**: 全 rules 参照が `plugin/plangate/rules/` を指す
- **種別**: Integration

### TC-8: .claude/agents/ と .claude/rules/ 非破壊確認

- **前提条件**: T-3c で本 TASK 着手前 commit SHA が `evidence/base-commit.md` に記録済み
- **入力**: `BASE=$(grep -oE '[a-f0-9]{7,40}' docs/working/TASK-0019/evidence/base-commit.md | head -1) && git diff --stat $BASE -- .claude/agents/ .claude/rules/`
- **期待出力**: 変更 0 件
- **種別**: Integration

### TC-9: plugin 中核スクリプトのファイル名一致確認

- **前提条件**: T-3b で `evidence/script-inventory.md` に具体スクリプト名が列挙済み
- **入力**: `diff <(ls plugin/plangate/scripts/ | sort) <(grep -oE '^- [^ ]+' docs/working/TASK-0019/evidence/script-inventory.md | awk '{print $2}' | sort)`
- **期待出力**: 差分 0（script-inventory.md のリストと plugin/plangate/scripts/ の実体が完全一致）
- **種別**: Unit

## エッジケース

### TC-E1: 汎用化過剰による挙動劣化検出

- **前提条件**: TC-2 パス
- **入力**: 汎用化された agent 定義を既存 plangate リポジトリ（Laravel 前提あり）で実行
- **期待出力**: 汎用化後も動作する（プロジェクト側の文脈を読み取って判断できる）
- **種別**: E2E（健全性確認）

### TC-E2: 同名 agent 衝突時の解決規則一致

- **前提条件**: `.claude/agents/workflow-conductor.md` と `plugin/plangate/agents/workflow-conductor.md` が両方存在、T-3a の `reference-resolution.md` で衝突時の解決規則が明文化済み
- **入力**: `reference-resolution.md` で定義された prefix（例: `plangate:workflow-conductor`）で呼び出し、legacy 側は従来 syntax で呼び出し
- **期待出力**: 呼び出し結果が `reference-resolution.md` の期待規則と一致（prefix ありは plugin、無しは legacy 等）
- **種別**: E2E

### TC-E3: 中核スクリプトの動作確認

- **前提条件**: TC-9 パス
- **入力**: 各中核スクリプトを実行
- **期待出力**: スクリプトが期待通り動作する（異常終了無し）
- **種別**: Integration

### TC-E4: plugin.json 構造 valid

- **前提条件**: TC-4 パス
- **入力**: `python3 -c "import json; json.load(open('plugin/plangate/.claude-plugin/plugin.json'))"`
- **期待出力**: JSON valid（exit code 0）
- **種別**: Unit

### TC-E5: rules/agents エントリ形式確認

- **前提条件**: TC-4 パス
- **入力**: plugin.json のエントリ形式を TASK-0017 Step 1 の仕様と突合
- **期待出力**: 仕様準拠の形式である
- **種別**: Unit
