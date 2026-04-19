# TASK-0022 EXECUTION PLAN

> 生成日: 2026-04-20
> PBI: [TASK-0021-A] Workflow 5 phase を定義する（WF-01〜WF-05）
> チケットURL: https://github.com/s977043/plangate/issues/23

## Goal

`docs/workflows/` 配下に 5 phase（WF-01 Context Bootstrap 〜 WF-05 Verify & Handoff）の定義ファイルと目次 README を新設し、親チケット #22 のハイブリッドアーキテクチャの実行層骨格を確定する。各 phase は **Rule 1 準拠**（順序と完了条件のみ、実装ノウハウなし）で記述する。

## Constraints / Non-goals

### Constraints

- **Rule 1 準拠**: Workflow は順序と完了条件だけ。実装ノウハウは書かない
- 配置先: `docs/workflows/`（`.claude/` 配下ではない）
- 命名規則: `0N_snake_case.md`
- 既存 `docs/plangate.md` / `docs/plangate-v6-roadmap.md` を書き換えない
- 既存 CI（markdown lint）に適合する

### Non-goals

- Skill の実装（#24）
- Agent の実装（#25）
- WF-03 Solution Design の詳細 artifact テンプレート化（#26）
- WF-05 Verify & Handoff の詳細 artifact テンプレート化（#27）
- Rule 1〜5 の統合ドキュメント（#28）
- 既存 PlanGate フェーズの書き換え

## Approach Overview

1. `docs/workflows/` ディレクトリ新設
2. 5 phase 定義ファイルを親 PBI の仕様に従って作成（1 ファイル ~50-80行）
3. README（目次 + PlanGate 既存フェーズとの対応表）を作成
4. Rule 1 違反がないかセルフチェック（「手順」「How to」系の単語を含まないか）
5. 既存 `docs/plangate.md` 等との整合確認

## Work Breakdown

### Step 1: ディレクトリ新設と命名確定

- **Output**: `docs/workflows/` 空ディレクトリ
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: `docs/workflows/` が存在する

### Step 2: WF-01〜WF-05 定義ファイルの作成

- **Output**:
  - `docs/workflows/01_context_bootstrap.md`
  - `docs/workflows/02_requirement_expansion.md`
  - `docs/workflows/03_solution_design.md`
  - `docs/workflows/04_build_and_refine.md`
  - `docs/workflows/05_verify_and_handoff.md`
- **Owner**: agent
- **Risk**: 中（Rule 1 違反を防ぐ必要）
- **🚩 チェックポイント**:
  - 各ファイルに必須6項目（目的 / 入力 / 完了条件 / 呼び出しSkill / 主担当Agent / 次phaseへの引き継ぎ）が全て存在
  - 「〜を明文化する」「〜を実施する」のような手順形式が完了条件に含まれていない
  - 「〜が明文化されている」「〜が決定されている」のような状態形式で記述

### Step 3: README（目次 + 対応表）の作成

- **Output**: `docs/workflows/README.md`
- **Owner**: agent
- **Risk**: 中（PlanGate 既存フェーズとの対応表の粒度判断）
- **🚩 チェックポイント**:
  - 5 phase の目次がある
  - PlanGate 既存フェーズ（A/B/C-1〜D/L-0/V-1〜V-4）と WF-01〜WF-05 の対応表が含まれる
  - 親 PBI の実行シーケンス（orchestrator → requirements-analyst → ... → orchestrator）が記載される

### Step 4: Rule 1 準拠セルフチェック（2段階）

- **Output**: `docs/working/TASK-0022/evidence/rule1-compliance-check.md`
- **Owner**: agent
- **Risk**: 中（EX-02 major 指摘反映）
- **🚩 チェックポイント（2段階）**:
  - **Layer 1（機械的）**: 全 5 phase ファイルに対して、禁止単語（手順 / 実施する / 実行する / How to / Steps）の出現を確認
  - **Layer 2（目視ルーブリック / EX-02 対応）**: 各完了条件項目ごとに以下のルーブリックで state / procedure を判定:
    - **state（合格）**: 「〜が明文化されている」「〜が決定されている」「〜が一覧化されている」
    - **procedure（不合格）**: 「〜を明文化する」「〜を実施する」「〜を決定する」「〜を洗い出す」
    - **判定記録**: evidence ファイルに「各完了条件項目のテキスト」と「state / procedure 判定」をテーブルで列挙
  - Layer 1 + Layer 2 の両方で合格すること

### Step 5: 既存ドキュメント整合確認

- **Output**: `docs/working/TASK-0022/evidence/consistency-check.md`
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**:
  - `docs/plangate.md` の既存フェーズ定義と矛盾しない
  - `docs/plangate-v6-roadmap.md` の記述と矛盾しない
  - 矛盾が見つかった場合は追加対応か #28 でのフォローアップを記録

### Step 6: markdown lint 検証

- **Output**: lint 結果 OK
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: CI と同じ設定で lint が通る

## Files / Components to Touch

### 新規作成（6ファイル）

- `docs/workflows/README.md`
- `docs/workflows/01_context_bootstrap.md`
- `docs/workflows/02_requirement_expansion.md`
- `docs/workflows/03_solution_design.md`
- `docs/workflows/04_build_and_refine.md`
- `docs/workflows/05_verify_and_handoff.md`

### 参照のみ（書き換えない）

- `docs/plangate.md`（整合確認のみ）
- `docs/plangate-v6-roadmap.md`（整合確認のみ）
- `docs/working/TASK-0021/pbi-input.md`（親PBI、仕様の正本）

## Testing Strategy

### Unit / Integration

| 種別 | 対象 | 方法 |
|---|---|---|
| Unit | 各 phase ファイルの必須6項目の存在 | grep による見出し確認 |
| Unit | Rule 1 違反単語の非存在 | grep で禁止パターン検出 |
| Integration | README と 5 phase ファイルの整合 | README が全 5 phase を参照しているか確認 |
| Integration | 既存 `docs/plangate.md` との整合 | 手動読み合わせ |

### Verification Automation

- markdown lint（既存 CI と同じ設定）: `.github/workflows/` の markdown lint job を活用
- 成果物チェック: `ls docs/workflows/` で 6 ファイル存在確認

### E2E

本 TASK は docs のみのため E2E は不要。ただし、後続 #24 / #25 で Skill / Agent を実装した際に、本 phase 定義を参照して正しく動作するかが事実上の E2E となる（本 TASK では Out of scope）。

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Rule 1 違反（実装ノウハウの混入） | Medium | Step 4 で禁止単語チェック、レビューで明示確認 |
| 既存 PlanGate フェーズとの対応が不明瞭 | Medium | Step 3 で対応表を作成、Step 5 で整合確認 |
| Skill / Agent 名が #24 / #25 実装時に変わる | Low | 本 TASK の命名を正本とする旨を PBI で合意済み |
| PlanGate v5/v6 ドキュメントとの矛盾 | Medium | Step 5 で整合確認、矛盾があれば #28 でフォロー |

## Questions / Unknowns（C-2 反映後に解消済み）

**解消履歴**: Codex C-2 レビュー（`review-external.md` EX-01〜EX-04 + Questions 見解）を反映し、以下の方針で確定:

- [x] **Q1 完了条件の粒度**: 状態形式で記述しつつ、**親 PBI で固定済みの要素は完了条件に含める**。例: WF-01 なら「対象範囲 / 使用可能技術 / 禁止事項 / 成果物定義が明文化されている」まで含める。書き方や手順は含めない。
- [x] **Q2 PlanGate 対応表の粒度**: **全フェーズ（A / B / C-1 / C-2 / C-3 / D / L-0 / V-1 / V-2 / V-3 / V-4）を並べる**。WF=実行層 / PlanGate=統制層の境界を明示するため、省略しない。
- [x] **Q3 次 phase 引き継ぎ artifact**: **artifact クラス名（requirements / design / known-issues / handoff）を本 TASK で固定**する。テンプレート本文は後続サブに委ねる。

## Mode判定

**モード**: `full`（高）

> **判定履歴**: 初版は `standard` としていたが、Codex C-2 レビュー（EX-01 major）で `mode-classification.md` 基準との不整合が指摘された。再分類の結果、以下の通り `full` が妥当と確定。

**判定根拠**:

- 変更ファイル数: 6（5 phase + README） → **full**（6-15 帯）
- 受入基準数: 7 → **full**（6-10 帯）
- タスク数: 14（T-1〜T-14） → **full**（11-20 帯）
- 変更種別: 新規ドキュメント追加（骨格定義） → standard
- リスク: 中（後続 5 サブ issue の基盤） → standard
- 影響範囲: **複数レイヤー相当**（#24〜#28 の基盤） → **full**
- ロールバック: 容易（docs のみ） → light 寄り
- **最終判定**: `full`（定量基準の最大値採用、オーバーライドなし）

**フェーズ適用**（mode-classification.md より / full 列）:

| フェーズ | 適用 |
|---|---|
| brainstorm | ○（親 PBI で実施済） |
| plan 生成 | ○ 実行済 |
| C-1 セルフレビュー | ○ 17項目 |
| C-2 外部AIレビュー | ○ **必須**（Codex で実施済 → CONDITIONAL） |
| C-3 人間レビュー | ○ |
| exec (TDD) | ○ TDD + 並列（T-3〜T-7 並列） |
| L-0 リンター | ○ |
| V-1 受け入れ検査 | ○ |
| V-2 コード最適化 | ○ **必須**（docs のため実質的な最適化は README 整合確認のみで充足） |
| V-3 外部レビュー | ○ |
| V-4 リリース前チェック | - スキップ（full モードは V-4 不要、critical のみ） |
| PR 作成 | ○ |
| C-4 PRレビュー | ○ |
