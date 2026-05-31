# TASK-0121 TEST CASES

## 受入基準 → テストケース対応

| AC | テストケース |
|----|--------------|
| AC-1 新配点と合計100 | TC-01, TC-06, TC-07 |
| AC-2 C-1 語彙で計画精度を評価 | TC-02 |
| AC-3 成果物品質を保全達成度として再定義 | TC-03 |
| AC-4 4 複製サイト同期 | TC-01, TC-04, TC-06 |
| AC-5 `.codex` thin pointer 未変更 | TC-05 |
| AC-6 consistency script の検出能力 | TC-06, TC-07, TC-08 |
| AC-7 RED → GREEN 証跡 | TC-06, TC-07 |
| AC-8 pre-push / CI は人間編集 | TC-09 |
| AC-9 HO 2 件は人間編集 | TC-10 |

## テストケース一覧

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|----------|------|----------|------|
| TC-01 | 対象 4 サイト更新後 | `sh scripts/check-retro-scoring-consistency.sh` | 計画精度30 / テスト品質15 / プロセス遵守15 / 効率性10 / 成果物品質30 を全対象で確認し exit 0 | Integration |
| TC-02 | `docs/ai-driven-development.md` 更新後 | `rg '受入基準網羅性|スコープ制御|テスト戦略妥当性' docs/ai-driven-development.md .claude/agents/retrospective-analyst.md` | C-1 語彙が計画精度の評価内容として確認できる | Structural |
| TC-03 | 対象 4 サイト更新後 | `rg '計画で定めた品質|保全達成度' docs/ai-driven-development.md .claude/agents/retrospective-analyst.md` | 成果物品質の再定義が確認できる | Structural |
| TC-04 | 対象 4 サイト更新後 | `rg '計画精度15|効率性25|計画精度15/テスト品質15/プロセス遵守15/効率性25/成果物品質30' docs/ai-driven-development.md .claude/agents/workflow-conductor.md .claude/agents/retrospective-analyst.md plugin/plangate/agents/workflow-conductor.md` | 該当 0 件 | Regression |
| TC-05 | exec 前後の diff 取得可能 | `git diff -- .codex/agents/retrospective_analyst.toml` | diff なし | Structural |
| TC-06 | script 作成直後、旧配点が残る状態 | `sh scripts/check-retro-scoring-consistency.sh` | 旧配点残存または新配点欠落を検出して non-zero exit | RED |
| TC-07 | agent 更新 + human HO 更新完了後 | `sh scripts/check-retro-scoring-consistency.sh` | exit 0。出力に旧配点 0、新 5 軸存在、合計 100 が示される | GREEN |
| TC-08 | 合計不一致の fixture または一時コピーを用意 | 計画精度30 / テスト品質15 / プロセス遵守15 / 効率性25 / 成果物品質30 | 合計 115 として non-zero exit | Negative |
| TC-09 | human が pre-push / CI 配線後 | `rg 'check-retro-scoring-consistency.sh' scripts/templates .github/workflows` | pre-push または CI の配線先で script 参照を確認できる | Structural |
| TC-10 | HO ファイル更新が必要な状態 | PR diff と作業ログ確認 | `.claude/agents/workflow-conductor.md` と `.claude/agents/retrospective-analyst.md` は human-owned 変更として扱われる | Review |

## Edge Cases

| ID | ケース | 期待 |
|----|--------|------|
| EC-01 | `docs/working/` の過去 artifact に旧配点が残る | consistency script は権威サイトのみを対象にし、履歴 artifact では失敗しない |
| EC-02 | 1 サイトだけ旧配点のまま | consistency script が non-zero exit |
| EC-03 | 新 5 軸はあるが合計が 100 ではない | consistency script が non-zero exit |
| EC-04 | `.codex/agents/retrospective_analyst.toml` に配点を追加しようとした | 対象外 pointer 変更として review で FAIL |
| EC-05 | pre-push 未配線だが script は GREEN | TC-09 が FAIL し、drift guard の運用連携未完了として扱う |
