# TASK-0028 テストケース定義

> 生成日: 2026-04-20

## 受入基準 → TC マッピング

| 受入基準 | TC | 種別 |
|---------|-----|------|
| docs/plangate-v7-hybrid.md 作成 | TC-1 | Unit |
| Rule 1〜5 明記 | TC-2 | Unit |
| 境界ルール明記 | TC-3 | Unit |
| 接続表記載 | TC-4 | Unit |
| v5/v6 との整合 | TC-5 | Integration |
| `.claude/rules/` 更新 | TC-6 | Unit |

## テストケース

### TC-1: v7 ドキュメント存在

- **入力**: `test -f docs/plangate-v7-hybrid.md && wc -l docs/plangate-v7-hybrid.md`
- **期待出力**: ファイル存在、100 行以上（必須セクション網羅の目安）
- **種別**: Unit

### TC-2: Rule 1〜5 記載

- **入力**: `grep -c "^| Rule [1-5]" docs/plangate-v7-hybrid.md` または `grep -c "Rule 1\|Rule 2\|Rule 3\|Rule 4\|Rule 5" docs/plangate-v7-hybrid.md`
- **期待出力**: 5 以上（5 Rule 全て記載）
- **種別**: Unit

### TC-3: 境界ルール記載

- **入力**: `grep -l "CLAUDE.md.*Skill.*Hook\|境界" docs/plangate-v7-hybrid.md`
- **期待出力**: ヒット（境界ルール記載あり）、表形式で CLAUDE.md / Skill / Hook の役割が明示
- **種別**: Unit

### TC-4: 接続表記載（機械検証）

- **入力**:
  ```bash
  grep -c "GATE\|STATUS\|APPROVAL\|ARTIFACT" docs/plangate-v7-hybrid.md
  grep -c "Workflow\|Skill\|Agent" docs/plangate-v7-hybrid.md
  ```
- **期待出力**: 前者 4 以上、後者 3 以上（表形式で関連付けされて記載）
- **種別**: Unit

### TC-5: v5/v6 整合（導線 + 差分・位置付け節）

- **入力**:
  - `grep "v7\|plangate-v7-hybrid" docs/plangate.md`
  - `grep "v7\|plangate-v7-hybrid" docs/plangate-v6-roadmap.md`
  - v7 ドキュメント内で「v5」「v6」「差分」「位置付け」キーワード確認
- **期待出力**:
  - 既存ドキュメント 2 件から v7 への導線記載あり
  - v7 ドキュメント内に「v5/v6 との差分・位置付け」節が存在、`docs/plangate-v7-hybrid.md` 内で「v5」「v6」「差分」「位置付け」の 4 キーワードが全て出現
- **種別**: Integration

### TC-6: .claude/rules/ 更新

- **入力**: `test -f .claude/rules/hybrid-architecture.md && grep -c "Rule" .claude/rules/hybrid-architecture.md`
- **期待出力**: ファイル存在、Rule 1〜5 記載（5 以上ヒット）
- **種別**: Unit

## エッジケース

### TC-E1: 既存 rules 非破壊

- `git diff .claude/rules/working-context.md .claude/rules/review-principles.md .claude/rules/mode-classification.md` で変更なし（追加新規ファイルのみ）

### TC-E2: #23-#27 への参考記述（非ブロッキング）

- v7 ドキュメント内で #23-#27 は issue 番号レベルの参考記述のみ（仮リンク必須化なし）
- #23-#27 の未完成果物への依存は完成条件・テスト条件から除外されている
