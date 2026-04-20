# TASK-0027 テストケース定義

> 生成日: 2026-04-20

## 受入基準 → TC マッピング

| 受入基準 | TC | 種別 |
|---------|-----|------|
| WF-05 標準 phase 化 | TC-1 | Unit |
| handoff.md テンプレ作成 | TC-2 | Unit |
| status/current-state/handoff の役割分担明示 | TC-3 | Integration |
| acceptance-review / known-issues-log Skill 連携 | TC-4 | Integration |
| 全 PBI 必須ルール明記 | TC-5 | Unit |
| V-1 との関係明示 | TC-6 | Unit |

## テストケース

### TC-1: WF-05 深化（phase 共通契約維持）

- **入力**: `docs/workflows/05_verify_and_handoff.md` 内容確認
- **期待出力**:
  - #23 基盤の phase 共通契約 5 要素（目的/入力/完了条件/呼び出しSkill/主担当Agent）が維持されている
  - handoff 6 要素・Skill 連携・V-1 との関係が追加記載
- **種別**: Unit

### TC-1a: handoff.md 命名規約記載

- **入力**: `docs/working/templates/handoff.md` の冒頭
- **期待出力**: 命名規約が明記（例: `docs/working/TASK-XXXX/handoff.md` 固定、1 PBI につき 1 ファイル）
- **種別**: Unit

### TC-2: handoff.md テンプレ 6 要素

- **入力**: `cat docs/working/templates/handoff.md`
- **期待出力**: 以下 6 要素の見出し
  - 要件適合確認結果
  - 既知課題一覧
  - V2 候補
  - 妥協点
  - 引き継ぎ文書
  - テスト結果サマリ
- **種別**: Unit

### TC-3: 役割分担明示

- **入力**: 05_verify_and_handoff.md と `.claude/rules/working-context.md` の役割分担表確認
- **期待出力**: status.md / current-state.md / handoff.md の更新タイミング・読者・目的が表形式で記載
- **種別**: Integration

### TC-4: Skill 連携

- **入力**: 05_verify_and_handoff.md 内の Skill 連携セクション
- **期待出力**: `acceptance-review` → 要件適合確認、`known-issues-log` → 既知課題 の流れが記載
- **種別**: Integration

### TC-5: 全 PBI 必須ルール

- **入力**: `grep -n "handoff" .claude/rules/working-context.md | head -5`
- **期待出力**: 1 箇所以上で「全 PBI で handoff 必須」旨の記述
- **種別**: Unit

### TC-6: V-1 との関係

- **入力**: 05_verify_and_handoff.md 内で V-1 について言及している箇所
- **期待出力**: 「V-1 = 実装ゲート、handoff = 完了後資産」等、両者の違いが記述
- **種別**: Unit

## エッジケース

### TC-E1: rules 既存構造非破壊

- `git diff .claude/rules/working-context.md` で「追加のみ、既存行の削除・修正なし」を確認

### TC-E2: サンプル妥当性

- `sample-handoff.md` の題材 TASK-0017 が実在し、6 要素全てに妥当な内容が記載
