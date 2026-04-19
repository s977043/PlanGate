# TASK-0018 テストケース定義

> 生成日: 2026-04-19

## 受入基準 → テストケース マッピング

| 受入基準 | テストケースID | 種別 |
|---------|--------------|------|
| 7 skills 全てが plugin/plangate/skills/ 配下に存在 | TC-1 | Unit |
| plugin.json の skills エントリに 7 件列挙 | TC-2 | Unit |
| plugin 経由で /working-context 動作 | TC-3 | E2E |
| plugin 経由で /ai-dev-workflow 動作 | TC-4 | E2E |
| 他 5 skills も plugin 経由呼び出し可能 | TC-5 | E2E |
| skill 間相互参照パスが機能 | TC-6 | Integration |
| 既存 .claude/skills/ 側動作が壊れていない | TC-7 | Integration |
| ハイブリッド方針の境界ルール文書化 | TC-8 | Unit |

## テストケース一覧

### TC-1: 7 skills ディレクトリ存在確認

- **前提条件**: TASK-0017 完了済み、`plugin/plangate/skills/` 存在
- **入力**: `ls plugin/plangate/skills/`
- **期待出力**: 7 ディレクトリ: `working-context`, `ai-dev-workflow`, `brainstorming`, `self-review`, `pr-review-response`, `pr-code-review`, `setup-team`
- **種別**: Unit

### TC-2: plugin.json skills エントリ件数

- **前提条件**: `plugin/plangate/.claude-plugin/plugin.json` 存在
- **入力**: `python3 -c "import json; print(len(json.load(open('plugin/plangate/.claude-plugin/plugin.json')).get('skills', [])))"`
- **期待出力**: `7`
- **種別**: Unit

### TC-3: plugin 経由 working-context 呼び出し検証

- **前提条件**: TC-1, TC-2 パス、T-2a で `evidence/invocation-syntax.md` に確定した正式 syntax 記録済み
- **入力**: 確定 syntax（例: `plangate:working-context` 相当のコマンド）で呼び出し
- **期待出力**: plugin 側の skill が起動し、正常応答する。応答内容から plugin 側が応答したことが識別できる（legacy 側ではない）。結果を `evidence/skill-invocation-test.md` に記録
- **種別**: E2E

### TC-4: plugin 経由 ai-dev-workflow 呼び出し検証

- **前提条件**: TC-3 と同様
- **入力**: 確定 syntax（例: `plangate:ai-dev-workflow`）で呼び出し
- **期待出力**: plugin 側 skill が起動、plugin 応答であることが識別できる
- **種別**: E2E

### TC-5: 残り 5 skills 呼び出し可否

- **前提条件**: TC-3, TC-4 パス
- **入力**: `plangate:brainstorming`, `plangate:self-review`, `plangate:pr-review-response`, `plangate:pr-code-review`, `plangate:setup-team` を順次呼び出し
- **期待出力**: 全 5 件が plugin 側で起動（応答から識別）
- **種別**: E2E

### TC-5a: dual-run 下で legacy 側動作保証

- **前提条件**: TC-3, TC-4 パス
- **入力**: legacy `.claude/skills/working-context` を従来 syntax（例: `/working-context` が legacy に解決する syntax、または明示 prefix）で呼び出し
- **期待出力**: legacy skill が従来どおり起動、応答から plugin ではなく legacy が応答していることが識別できる
- **種別**: E2E

### TC-6: skill 間相互参照確認

- **前提条件**: TC-1 パス、skill 内の `@` や相対パス参照を持つファイルを特定
- **入力**: Step 1 で特定した参照元から参照先ファイルが解決できるか確認
- **期待出力**: すべての参照が plugin 内で解決できる
- **種別**: Integration

### TC-7: .claude/skills/ 非破壊確認

- **前提条件**: T-2b で本 TASK 着手前 commit SHA が `evidence/base-commit.md` に記録済み
- **入力**: `BASE=$(grep -oE '[a-f0-9]{7,40}' docs/working/TASK-0018/evidence/base-commit.md | head -1) && git diff --stat $BASE -- .claude/skills/`
- **期待出力**: `.claude/skills/` 配下に変更が 0 件
- **種別**: Integration

### TC-8: 境界ルール文書化

- **前提条件**: T-16 完了
- **入力**: `cat docs/working/TASK-0018/evidence/command-skill-boundary.md`
- **期待出力**: 以下が含まれる
  - skill 化された command 一覧
  - 併存方針（両方残す / skill 優先 等）
  - 将来の移行方針
- **種別**: Unit

## エッジケース

### TC-E1: 同名 skill 呼び出し時の解決順序

- **前提条件**: `.claude/skills/working-context` と `plugin/plangate/skills/working-context` が両方存在（デュアル運用）
- **入力**: `/working-context` を通常通り呼び出し
- **期待出力**: いずれか一方が呼ばれ、動作に支障がない。どちらが優先されたかを記録
- **種別**: E2E（調査）

### TC-E2: 参照パス修正漏れ検出

- **前提条件**: plugin 内 skills 全件
- **入力**: `grep -r "../../" plugin/plangate/skills/` で相対参照を検索
- **期待出力**: `.claude/` 側を指す参照が残っていない
- **種別**: Unit

### TC-E3: plugin.json skills エントリ形式確認

- **前提条件**: TC-2 パス
- **入力**: `plugin.json` の skills エントリ形式を確認
- **期待出力**: CC plugin 仕様（TASK-0017 Step 1 で特定）に準拠した形式
- **種別**: Unit
