# TASK-0018 EXECUTION PLAN

> 生成日: 2026-04-19
> PBI: [TASK-0016-B] PlanGate 主要 skills を plugin に移植する
> チケットURL: https://github.com/s977043/plangate/issues/18

## Goal

PlanGate の主要導線 7 skills を `plugin/plangate/skills/` に配置し、plugin 経由で呼び出し可能な状態にする。`.claude/skills/` 側は温存（デュアル運用）。

## Constraints / Non-goals

- 対象は 5 skills（`brainstorming`, `self-review`, `subagent-driven-development`, `systematic-debugging`, `codex-multi-agent`）+ 2 commands（`working-context`, `ai-dev-workflow`）
- skills/commands の挙動変更は禁止（コピーのみ）
- `.claude/skills/` 側の削除は禁止（デュアル運用）
- **Non-goals**: 他 skill の移植、skill リファクタリング、commands → skills 変換（commands はそのまま）

## Approach Overview

1. 実在する skills (5) と commands (2) の現行配置・相互参照を調査
2. `plugin/plangate/skills/` に 5 skills、`plugin/plangate/commands/` に 2 commands をコピー配置
3. 各ファイル内の相対パス参照を plugin 構造に合わせて修正
4. plugin 経由の呼び出し検証（dual-run 含む）
5. commands 併存の境界ルールを evidence に記録（TASK-0020 の素材）

## Work Breakdown

### Step 1: skills/commands 調査と前提取得

- **Output**:
  - `docs/working/TASK-0018/evidence/skills-inventory.md`（5 skills + 2 commands の構造、参照パス、依存関係）
  - `docs/working/TASK-0018/evidence/invocation-syntax.md`（TASK-0017 の調査結果を引用した正式 plugin 呼び出し syntax。commands と skills で異なる可能性も記録）
  - `docs/working/TASK-0018/evidence/base-commit.md`（本 TASK 着手時点の commit SHA）
- **Owner**: agent
- **Risk**: 中
- **🚩 チェックポイント**:
  - 5 skills + 2 commands のファイル一覧と相対パス参照箇所が特定されている
  - plugin 経由呼び出しの正式 syntax が skill/command それぞれ確定
  - `.claude/` 基準 SHA が記録されている

### Step 2: skills/commands コピー配置

- **Output**:
  - `plugin/plangate/skills/{skill名}/` × 5
  - `plugin/plangate/commands/{command名}.md` × 2
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: 5 skill ディレクトリ + 2 command ファイルが plugin 側に存在し、内容が原本と一致

### Step 3: 参照パス修正

- **Output**: plugin 内 skills の参照パス修正差分
- **Owner**: agent
- **Risk**: 高
- **🚩 チェックポイント**: Step 1 で特定した参照箇所すべてが plugin 内パスに書き換えられ、壊れた参照が無い

### Step 4: plugin.json 更新

- **Output**: `plugin/plangate/.claude-plugin/plugin.json` の skills エントリ追記
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: 7 skills が列挙され、JSON valid

### Step 5: 呼び出し prefix 検証（dual-run 含む）

- **Output**: `docs/working/TASK-0018/evidence/skill-invocation-test.md`
- **Owner**: agent
- **Risk**: 中
- **🚩 チェックポイント**:
  - Step 1 で確定した syntax（例: `plangate:working-context`）で plugin 側 skill が呼び出せる証跡
  - 同 syntax で `.claude/skills/` 側（legacy）も従来どおり呼び出せ、plugin / legacy が識別できる証跡（呼び出し元の出力やログで判別）
  - 全 7 skills について成功判定が記録されている

### Step 6: commands 併存の境界記録（TASK-0020 向け素材）

- **Output**: `docs/working/TASK-0018/evidence/command-skill-boundary.md`
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**:
  - どの command が skill 化されたか、併存方針が文書化されている
  - 成果物は evidence として保存、公開 README / docs への反映は TASK-0020 で実施（本 TASK の責務ではない旨を記載）

### Step 7: `.claude/skills/` 非破壊確認（runtime + 差分）

- **Output**: `docs/working/TASK-0018/evidence/non-destructive-check.md`
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**:
  - `git diff --stat <base-sha> -- .claude/skills/` で変更 0 件（基準 SHA は `evidence/base-commit.md` 参照）
  - Step 5 の runtime 検証で legacy `.claude/skills/` 側が従来どおり動作した証跡を引用

## Files / Components to Touch

| 種別 | ファイルパス | 変更内容 |
| --- | --- | --- |
| 新規 | plugin/plangate/skills/working-context/** | コピー |
| 新規 | plugin/plangate/skills/ai-dev-workflow/** | コピー |
| 新規 | plugin/plangate/skills/brainstorming/** | コピー |
| 新規 | plugin/plangate/skills/self-review/** | コピー |
| 新規 | plugin/plangate/skills/pr-review-response/** | コピー |
| 新規 | plugin/plangate/skills/pr-code-review/** | コピー |
| 新規 | plugin/plangate/skills/setup-team/** | コピー |
| 修正 | plugin/plangate/.claude-plugin/plugin.json | skills エントリ追記 |
| 新規 | docs/working/TASK-0018/evidence/skills-inventory.md | 調査結果 |
| 新規 | docs/working/TASK-0018/evidence/skill-invocation-test.md | 呼び出し検証 |
| 新規 | docs/working/TASK-0018/evidence/command-skill-boundary.md | 境界記録 |

## Testing Strategy

- **Unit**: 各 skill ファイルがコピー先で存在すること
- **Integration**: plugin.json の skills エントリが 7 件列挙
- **E2E**: plugin 経由で `/working-context` と `/ai-dev-workflow` が動作
- **Edge cases**: 同名 skill の呼び出し衝突、相対参照の破損、`.claude/` 側の変更有無
- **Verification Automation**:
  - `ls plugin/plangate/skills/ | wc -l` → 7
  - `python3 -c "import json; print(len(json.load(open('plugin/plangate/.claude-plugin/plugin.json'))['skills']))"` → 7
  - 手動: plugin 経由 `/working-context` 呼び出し成功

## Risks & Mitigations

| リスク | 対策 |
| --- | --- |
| skill 内の相対パス参照が plugin 配置で壊れる | Step 1 で全参照箇所を一覧化、Step 3 で systematic に修正 |
| 同名 skill が `.claude/skills/` と plugin 側で衝突 | 呼び出し prefix（`plangate:`）で明示、CC 仕様を確認 |
| plugin 経由呼び出しが CC 仕様で先行しない | 必要なら `.claude/skills/` 側を一時リネームして検証、結果を記録 |
| 7 skills 内に未知の外部依存がある | Step 1 の調査フェーズで徹底的に洗い出す |

## Questions / Unknowns

- plugin 経由 skill の呼び出し syntax（`plangate:skill-name` or `/skill-name`）
- CC の skill 解決順序（plugin vs `.claude/` の優先度）
- skills ディレクトリ内の参照が auto-discovery されるか

## Mode判定

**モード**: `standard`

**判定根拠**:
- 変更ファイル数: 9-15（7 skills + plugin.json + evidence 3） → standard
- 受入基準数: 8 → standard
- 変更種別: ファイル配置＋参照修正 → standard
- リスク: 中（参照破壊リスク） → standard
- **最終判定**: standard

## 依存

- **前提**: TASK-0017 完了（plugin ディレクトリが存在）
- **後続**: TASK-0019（agents 移植）、TASK-0020（README）
