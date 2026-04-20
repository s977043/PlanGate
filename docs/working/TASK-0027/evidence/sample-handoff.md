# サンプル: Handoff Package（TASK-0017 題材）

> 参考例として TASK-0017（plugin skeleton 作成）の handoff.md を書いた場合のサンプル。

## メタ情報

```yaml
task: TASK-0017
related_issue: https://github.com/s977043/plangate/issues/17
author: qa-reviewer
issued_at: 2026-04-19
v1_release: 40109b5 (PR #21 マージ前の実装コミット)
```

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| plugin ディレクトリが作成されている | PASS | `plugin/plangate/` + 5 サブディレクトリ存在確認 |
| plugin.json が仕様準拠 | PASS | TC-2a metadata 検証 PASS（name/version/description/author.name） |
| `settings.json` にデフォルト設定 | **DELETED** | plugin 仕様に settings.json は存在しないと判明、TC-5 削除 |
| README.md プレースホルダー配置 | PASS | TASK-0020 で完成予定の注記付き |
| Claude Code インストール試行エラーなし | PASS | validation 警告のみ（既存 legacy commands と同じ） |
| schema validation パス | PASS | Level 1-3 metadata 検証 PASS |
| 既存 `.claude/` 非破壊 | PASS | git diff --stat 0 件 |

**総合**: `7/7 基準 PASS`（1 基準は plugin 仕様に基づき削除）

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| Commands に frontmatter なし | minor | accepted | No（既存 legacy commands も同じ、既存パターン維持） |
| Marketplace 未公開 | info | accepted | Yes |

**Critical 課題**: なし

## 3. V2 候補

| V2 候補 | 理由 | 推定優先度 | 関連 Issue |
|--------|------|----------|-----------|
| Marketplace 公開準備 | 今回は最小構成、公開は別スコープ | Low | — |
| Hooks 実装 | 将来の自動化基盤 | Medium | — |
| Commands frontmatter 整備 | 警告は pre-existing、個別対応予定 | Low | — |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| metadata のみの plugin.json | skills/agents エントリを明示列挙 | 仕様調査で auto-discovery と判明 |
| `scripts/` ディレクトリ名 | `bin/` | plugin 標準慣習に従う |
| `settings.json` を作成しない | plugin 内 settings 作成 | plugin 仕様に存在しない |

## 5. 引き継ぎ文書

### 概要
Claude Code plugin `plangate` の最小構成スケルトンを作成。`.claude-plugin/plugin.json` + 5 サブディレクトリ（skills/agents/rules/hooks/scripts）+ プレースホルダー README を配置。中身は TASK-0018 以降で順次移植する前提。

### 触れないでほしいファイル
- `plugin/plangate/.claude-plugin/plugin.json`: manifest、後続 TASK で更新予定（name/version は変更しない）
- `.claude/` 配下: デュアル運用のため破壊禁止

### 次に手を入れるなら
- TASK-0018 (skills 移植) → TASK-0019 (agents 移植) → TASK-0020 (README 完成) の順
- プロジェクト固有 agents は同梱しない（汎用性維持）

### 参照リンク
- 親 PBI: #16
- plan.md: `docs/working/TASK-0017/plan.md`
- status.md: `docs/working/TASK-0017/status.md`
- evidence: `docs/working/TASK-0017/evidence/`

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| Unit | 5 (TC-2, TC-2a, TC-3, TC-4, TC-6) | 5 | 0 | — |
| Integration | 3 (TC-1, TC-7, TC-8) | 3 | 0 | — |
| E2E | 0 | — | — | — |
| Edge cases | 2 (TC-E1, TC-E3) | 2 | 0 | — |

**SKIP**: TC-5（settings.json 検証）は settings.json 不採用により削除

---

## 備考

本サンプルは TASK-0017（2026-04-19 PR #21 マージ済）の振り返り用 handoff.md として作成。
実プロジェクトでは、TASK 完了時に qa-reviewer が作成し、orchestrator が PR 作成前に発行するフロー。
