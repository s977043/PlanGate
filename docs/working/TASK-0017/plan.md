# TASK-0017 EXECUTION PLAN

> 生成日: 2026-04-19
> PBI: [TASK-0016-A] Claude Code plugin 最小構成スケルトンを作成する
> チケットURL: https://github.com/s977043/plangate/issues/17

## Goal

Claude Code plugin としてインストール可能な `plangate` plugin の最小構成スケルトン（manifest + 空ディレクトリ構造）を整備し、後続 issue（#18, #19）が即座に着手できる土台を作る。

## Constraints / Non-goals

- plugin 名は `plangate`（namespace 無し、親チケットで決定済）
- 既存 `.claude/` 構成は破壊しない（デュアル運用）
- 空ディレクトリは `.gitkeep` で保持
- **Non-goals**: skills / agents / rules の実体移植、README 本文完成、hooks 実装、marketplace 登録

## Approach Overview

1. Claude Code plugin 仕様を事前調査（完了: evidence/plugin-spec-research.md）
2. `plugin/plangate/` ディレクトリとサブディレクトリを作成
3. `plugin/plangate/.claude-plugin/plugin.json` manifest（metadata のみ）を作成
4. 空サブディレクトリ（skills / agents / rules / hooks / **scripts**）を `.gitkeep` で用意
5. プレースホルダー `README.md` を作成
6. Claude Code でのインストール試行を実施し、エラーが無いことを確認

**注**: 当初計画の `settings.json` は plugin 仕様に存在しないため不要（`evidence/settings-defaults.md` 参照）。`bin/` は `scripts/` に変更（plugin 標準慣習）。

## Work Breakdown

### Step 1: Claude Code plugin 仕様調査

- **Output**:
  - `docs/working/TASK-0017/evidence/plugin-spec-research.md`（仕様要約）
  - `docs/working/TASK-0017/evidence/schema-validation-method.md`（`plugin.json` を検証する公式 schema / validator コマンドの特定）
  - `docs/working/TASK-0017/evidence/settings-defaults.md`（`settings.json` の必須キー・初期値リスト）
  - `docs/working/TASK-0017/evidence/base-commit.md`（本 TASK 着手時点の commit SHA を記録、後続 `.claude/` 非破壊確認の基準に使用）
- **Owner**: agent
- **Risk**: 中
- **🚩 チェックポイント**:
  - `plugin.json` の必須フィールド一覧、skills/agents/rules/hooks エントリの記述方法が確定
  - `plugin.json` を検証する公式 schema または validator コマンドが特定されている
  - `settings.json` の必須キーと初期値が列挙されている
  - `.claude/` 非破壊確認の基準コミット SHA が記録されている

### Step 2: ディレクトリ構造作成

- **Output**: `plugin/plangate/` 以下に `.claude-plugin/` + 5 サブディレクトリ（skills, agents, rules, hooks, **scripts**）と `.gitkeep`
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: `plugin/plangate/` に `.claude-plugin/` + 5 サブディレクトリ（skills/agents/rules/hooks/scripts）が存在し、それぞれに `.gitkeep` が配置（ファイル作成は Step 3〜5 で行う）

### Step 3: plugin.json manifest 作成

- **Output**: `plugin/plangate/.claude-plugin/plugin.json`
- **Owner**: agent
- **Risk**: 中
- **🚩 チェックポイント**: name / version / description / author.name が記載され、JSON valid、Level 1-3 検証コマンド（`schema-validation-method.md` 参照）が全て成功

### Step 4: プレースホルダー README 作成

- **Output**: `plugin/plangate/README.md`
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: README にプレースホルダーと「TASK-0020 で完成予定」の注記、`${CLAUDE_PLUGIN_ROOT}` の使い方への言及

### Step 5: `.gitkeep` 配置（空ディレクトリ保持）

- **Output**: `plugin/plangate/{skills,agents,rules,hooks,scripts}/.gitkeep`
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: `git status` で 5 つの `.gitkeep` が追跡対象

### Step 6: Claude Code インストール試行検証

- **Output**: `docs/working/TASK-0017/evidence/install-verification.md`
- **Owner**: agent
- **Risk**: 中
- **🚩 チェックポイント**: インストール試行でエラーが出ない、または想定内の warning のみ

### Step 7: 既存 `.claude/` 非破壊確認

- **Output**: `docs/working/TASK-0017/evidence/non-destructive-check.md`（Step 1 で記録した基準 SHA との差分）
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: `git diff --stat <base-sha> -- .claude/` で変更が 0 件であることが evidence に記録されている

## Files / Components to Touch

| 種別 | ファイルパス | 変更内容 |
| --- | --- | --- |
| 新規 | plugin/plangate/.claude-plugin/plugin.json | plugin manifest（metadata） |
| 新規 | plugin/plangate/README.md | プレースホルダー |
| 新規 | plugin/plangate/skills/.gitkeep | 空ディレクトリ保持 |
| 新規 | plugin/plangate/agents/.gitkeep | 空ディレクトリ保持 |
| 新規 | plugin/plangate/rules/.gitkeep | 空ディレクトリ保持（非標準、カスタム配置） |
| 新規 | plugin/plangate/hooks/.gitkeep | 空ディレクトリ保持 |
| 新規 | plugin/plangate/scripts/.gitkeep | 空ディレクトリ保持 |
| 新規 | docs/working/TASK-0017/evidence/plugin-spec-research.md | 仕様調査結果 |
| 新規 | docs/working/TASK-0017/evidence/install-verification.md | インストール試行結果 |

## Testing Strategy

- **Unit**: `plugin.json` の JSON パース成功、metadata 必須フィールド（name/version/description/author.name）検証
- **Integration**: Claude Code でのインストール試行成功（Level 4 検証）
- **E2E**: 対象外（中身が無いため）
- **Edge cases**: 空ディレクトリが git で追跡されるか、既存 `.claude/` が影響を受けないか、必須フィールド欠落時にエラーが検出されるか
- **Verification Automation**:
  - `python3 -c "import json; json.load(open('plugin/plangate/.claude-plugin/plugin.json'))"` → エラーなし
  - `schema-validation-method.md` Level 2-3 コマンド（必須フィールド + 型 + semver 検証） → 成功
  - `git diff --stat cae1ac649384cbc7ba8f85cbab1b2fc312ddf05d -- .claude/` → 0 件
  - Claude Code plugin インストール試行 → 成功

## Risks & Mitigations

| リスク | 対策 |
| --- | --- |
| Claude Code plugin 仕様が未確定で manifest 構造が変わる | 最小必須フィールドのみ記載、仕様変更時に追記可能な構造にする |
| plugin.json スキーマ検証ツールが無い | 手動で JSON valid を確認 + インストール試行で代替 |
| `.gitkeep` が commit されず空ディレクトリが失われる | `git status` で明示的に確認、commit に含める |

## Questions / Unknowns

- Claude Code plugin の公式仕様ドキュメントの所在（Step 1 で調査確定）
- `settings.json` に記載すべき推奨キー（仕様調査で判明）
- plugin 配置場所は `plugin/plangate/` か `plugins/plangate/` か（慣習調査、PBI では前者を採用）

## Mode判定

**モード**: `light`

**判定根拠**:
- 変更ファイル数: 8-10 → light/standard 境界
- 受入基準数: 8 → light
- 変更種別: 設定ファイル追加 → light
- リスク: 低〜中 → light
- **最終判定**: light（ドキュメント＋設定中心、実動作コード無し）
