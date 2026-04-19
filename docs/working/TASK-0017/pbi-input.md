# PBI INPUT PACKAGE: plugin 最小構成スケルトン作成

> 作成日: 2026-04-19
> PBI: [TASK-0016-A] Claude Code plugin 最小構成スケルトンを作成する
> チケットURL: https://github.com/s977043/plangate/issues/17
> 親チケット: https://github.com/s977043/plangate/issues/16

---

## Context / Why

Issue #16（plugin 化）の最初のステップとして、Claude Code plugin としてインストール可能な最小構成のスケルトンを用意する。

中身（skills / agents / rules）の移植は後続 issue（#18, #19）で実施するため、本 issue では **ディレクトリ構造と manifest のみ** に集中する。このスケルトンがあることで、後続作業は各資産を配置するだけで済む。

**なぜ最初にスケルトンか**: 後続の skills / agents 移植は plugin 構造が確定していないと着手できない。manifest の仕様検証もこの段階で済ませる。

---

## What（Scope）

### In scope

- plugin ディレクトリを新規作成（配置候補: `plugin/plangate/` または `plugins/plangate/`）
- `plugin.json` manifest を作成
  - plugin 名: `plangate`
  - version: 初版 `0.1.0`
  - description: PlanGate workflow for Claude Code
  - skills / agents / rules / hooks のエントリポイント定義
- 空のサブディレクトリを作成:
  - `skills/`（#18 で埋める）
  - `agents/`（#19 で埋める）
  - `rules/`（#19 で埋める）
  - `hooks/`（将来拡張用、初版空）
  - `bin/`（#19 で埋める）
- `settings.json` のデフォルト設定を定義
- plugin 用 `README.md`（プレースホルダー、#20 で本文追加）
- Claude Code への **インストール試行検証** を実施

### Out of scope

- skills / agents / rules の実体移植（#18, #19 で実施）
- README 本文の完成（#20 で実施）
- `hooks/` の実装本体
- marketplace 登録メタデータ
- Codex CLI 対応
- 既存 `.claude/` への変更（デュアル運用維持）

---

## 受入基準

- [ ] `plugin/plangate/` ディレクトリが作成されている
- [ ] `plugin.json` manifest が Claude Code plugin 仕様に準拠している
- [ ] `skills/`, `agents/`, `rules/`, `hooks/`, `bin/` サブディレクトリが存在する
- [ ] `settings.json` にデフォルト設定が定義されている
- [ ] `README.md`（プレースホルダー）が配置されている
- [ ] Claude Code にインストール試行してエラーにならない
- [ ] `plugin.json` がスキーマ検証（JSON Schema 等）をパスする
- [ ] 既存 `.claude/` 構成が破壊されていない（差分を確認）

---

## Notes from Refinement

### 決定事項（親 TASK-0016 より継承）

- plugin 名: `plangate`（namespace 無し）
- 配布境界: B. 中核
- 互換方針: A. デュアル運用（`.claude/` 維持）
- `hooks/` は枠のみ、実装は将来

### 想定ディレクトリ構造（本 issue 完了時）

```text
plugin/plangate/
├── plugin.json
├── README.md            # プレースホルダー
├── settings.json
├── skills/              # 空
├── agents/              # 空
├── rules/               # 空
├── hooks/               # 空（将来拡張）
└── bin/                 # 空
```

### 想定モード判定

**light**（低）を想定。

- 変更ファイル数: 2-4（plugin.json, settings.json, README.md, ディレクトリ作成）
- 変更種別: 設定ファイル追加
- リスク: 低（既存に影響しない）

---

## Estimation Evidence

### Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Claude Code plugin 仕様が未確定・変更される可能性 | Medium | 公式ドキュメントに最新仕様を確認、最小限の必須フィールドに留める |
| `plugin.json` のスキーマ検証ツールが未整備 | Low | 手動検証 + Claude Code でのインストール試行で代替 |
| ディレクトリ配置場所（`plugin/` vs `plugins/`）の選択誤り | Low | 他プロジェクトの慣習を調査して決定 |

### Unknowns

- `plugin.json` の正式スキーマ（`skills` / `agents` / `rules` / `hooks` エントリの定義方法）
- plugin のインストール方法（ローカルパス指定 / symlink / marketplace）
- `settings.json` のデフォルト値として設定すべき項目

### Assumptions

- Claude Code は 2026-04 時点で plugin 機構を持つ
- `plugin.json` で skills / agents / rules を束ねられる
- ローカル plugin のインストール試行が可能

---

## 次フェーズへの申し送り

- B: plan 生成（workflow-conductor 委譲）
- plan では Claude Code plugin 仕様の事前調査タスクを先頭に含める
- C-1 セルフレビュー（light モードのため Plan 7項目のみで可）
- C-3 ゲート後に exec
