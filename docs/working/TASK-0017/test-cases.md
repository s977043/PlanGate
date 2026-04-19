# TASK-0017 テストケース定義

> 生成日: 2026-04-19

## 受入基準 → テストケース マッピング

| 受入基準 | テストケースID | 種別 |
|---------|--------------|------|
| `plugin/plangate/` ディレクトリが作成されている | TC-1 | Integration |
| `plugin.json` manifest が Claude Code plugin 仕様に準拠 | TC-2, TC-3 | Unit / Integration |
| 5 サブディレクトリが存在 | TC-4 | Unit |
| `settings.json` にデフォルト設定が定義されている | TC-5 | Unit |
| `README.md`（プレースホルダー）が配置されている | TC-6 | Unit |
| Claude Code にインストール試行してエラーにならない | TC-7 | E2E |
| `plugin.json` がスキーマ検証をパス | TC-2 | Unit |
| 既存 `.claude/` 構成が破壊されていない | TC-8 | Integration |

## テストケース一覧

### TC-1: plugin ディレクトリ存在確認

- **前提条件**: リポジトリ root で作業
- **入力**: `ls -la plugin/plangate/`
- **期待出力**: ディレクトリが存在し、以下が含まれる: `.claude-plugin/`, `README.md`, `skills/`, `agents/`, `rules/`, `hooks/`, `scripts/`（settings.json / bin/ は含まれない）
- **種別**: Integration

### TC-2: plugin.json JSON valid 検証

- **前提条件**: `plugin/plangate/.claude-plugin/plugin.json` 存在
- **入力**: `python3 -c "import json; print(json.load(open('plugin/plangate/.claude-plugin/plugin.json')))"`
- **期待出力**: 標準出力に dict 表示、エラーなし（exit code 0）
- **種別**: Unit

### TC-2a: plugin.json metadata 検証（Level 2-3）

- **前提条件**: TC-2 パス、`evidence/schema-validation-method.md` 参照
- **入力**:
  ```bash
  python3 -c "
  import json, re
  d = json.load(open('plugin/plangate/.claude-plugin/plugin.json'))
  assert isinstance(d.get('name'), str) and d['name'], 'name missing or empty'
  assert isinstance(d.get('version'), str) and re.match(r'^\d+\.\d+\.\d+$', d['version']), 'version invalid semver'
  assert isinstance(d.get('description'), str) and d['description'], 'description missing or empty'
  assert isinstance(d.get('author'), dict) and d['author'].get('name'), 'author.name missing'
  print('OK')
  "
  ```
- **期待出力**: `OK`、exit code 0
- **種別**: Unit

### TC-3: plugin.json 値確認

- **前提条件**: TC-2a パス
- **入力**: `plugin.json` の内容確認
- **期待出力**: 以下が記載されている
  - `name`: `"plangate"`
  - `version`: `"0.1.0"`
  - `description`: `plangate` workflow for Claude Code（任意の自然文）
  - `author.name`: プロジェクト所有者名
- **種別**: Unit

### TC-4: 5 サブディレクトリ存在確認

- **前提条件**: `plugin/plangate/` 存在
- **入力**: `for dir in skills agents rules hooks scripts; do test -d "plugin/plangate/$dir" || echo "missing: $dir"; done`
- **期待出力**: 出力なし（全ディレクトリ存在）
- **種別**: Unit

### ~~TC-5: settings.json 必須キー検証~~ **削除**

settings.json は plugin 仕様に存在しないため削除。詳細は `evidence/settings-defaults.md` 参照。

### TC-6: README.md プレースホルダー確認

- **前提条件**: `plugin/plangate/README.md` 存在
- **入力**: ファイル内容確認
- **期待出力**: プレースホルダー記述と「TASK-0020 で完成予定」の注記が含まれる
- **種別**: Unit

### TC-7: Claude Code インストール試行

- **前提条件**: TC-1〜TC-6 全てパス、Claude Code CLI が利用可能
- **入力**: Claude Code plugin インストールコマンド（仕様調査 Step 1 で確定した方法）
- **期待出力**: インストール成功、または想定内 warning のみ（critical エラー無し）。結果は `evidence/install-verification.md` に記録
- **種別**: E2E

### TC-8: 既存 `.claude/` 非破壊確認

- **前提条件**: T-2c で本 TASK 着手前の commit SHA が `docs/working/TASK-0017/evidence/base-commit.md` に記録済み
- **入力**: `BASE=$(grep -oE '[a-f0-9]{7,40}' docs/working/TASK-0017/evidence/base-commit.md | head -1) && git diff --stat $BASE -- .claude/`
- **期待出力**: `.claude/` 配下に変更が 0 件（exit code 0 かつ出力空）
- **種別**: Integration

## エッジケース

### TC-E1: `.gitkeep` による空ディレクトリ保持

- **前提条件**: 5 サブディレクトリ（skills/agents/rules/hooks/scripts）に `.gitkeep` 配置済み
- **入力**: `git ls-files plugin/plangate/ | grep .gitkeep | wc -l`
- **期待出力**: `5`
- **種別**: Unit

### TC-E2: JSON 構文エラー時の挙動

- **前提条件**: 意図的に `plugin.json` に不正 JSON を書き込んでテスト（CI 不要、開発中の確認用）
- **入力**: 不正 JSON を含む `plugin.json`
- **期待出力**: TC-2 がエラー exit code 1 を返す（検証が機能していることの確認）
- **種別**: Unit（開発確認用）

### TC-E3: plugin 配置パス変更時の検討

- **前提条件**: `plugin/` ではなく `plugins/` を採用する仕様変更があった場合
- **入力**: パス差分を検出する検証
- **期待出力**: Step 1 の仕様調査で決定したパスに従う。変更があれば plan.md を更新してから着手
- **種別**: Manual Review
