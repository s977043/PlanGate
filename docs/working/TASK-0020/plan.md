# TASK-0020 EXECUTION PLAN

> 生成日: 2026-04-19
> PBI: [TASK-0016-D] plugin 導入手順と migration note を整備する
> チケットURL: https://github.com/s977043/plangate/issues/20

## Goal

既存 plangate リポジトリ利用者と他プロジェクト開発者の双方が plugin への移行・導入を判断できるよう、Root README の plugin 導入セクション、`docs/plangate-plugin-migration.md`、plugin 内 README を整備する。

## Constraints / Non-goals

- 実装（#17-#19）完了後に着手することで、同梱範囲の記述乖離を防ぐ
- デュアル運用前提を明記（急な移行強制を避ける）
- Codex CLI 対象外を明記
- **Non-goals**: marketplace 登録、英語版、視覚資料、既存 `.claude/` ドキュメントの全面改訂

## Approach Overview

1. 既存 README.md 構成を調査し、plugin 導入セクションの挿入位置を決定
2. Root README に plugin 導入セクションを追加（新旧差分表含む）
3. `docs/plangate-plugin-migration.md` を新規作成（詳細版）
4. plugin 内 README（プレースホルダー）を本文で置換
5. ドキュメント間の相互参照リンクを設定
6. 既存利用者向け移行手順を段階的に記述

## Work Breakdown

### Step 1: 既存 README 調査 + TASK-0017 成果物引用

- **Output**:
  - `docs/working/TASK-0020/evidence/readme-structure.md`（既存構成の要約と挿入位置案）
  - `docs/working/TASK-0020/evidence/install-syntax-reference.md`（TASK-0017 の plugin 仕様調査・インストール検証成果物から、README/plugin README で使う install syntax を抜粋・固定）
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**:
  - 挿入位置が決定、既存セクションとの衝突が無い
  - plugin install syntax が TASK-0017 成果物から引用・固定されている（推測値は使わない）

### Step 2: TASK-0018 の境界記録参照

- **Output**: `docs/working/TASK-0020/evidence/boundary-summary.md`（TASK-0018 の `evidence/command-skill-boundary.md` から migration note に使う要素を抽出した要約）
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: commands → skills 移行の実態が要約として記録されている

### Step 3: Root README plugin 導入セクション追加

- **Output**: `README.md` 更新差分 + `docs/working/TASK-0020/evidence/readme-update.md`（追加セクションの diff 抜粋）
- **Owner**: agent
- **Risk**: 中
- **🚩 チェックポイント**:
  - plugin 導入手順が記載（install syntax は Step 1 の `install-syntax-reference.md` を引用）
  - 新旧導入方法の差分が表形式で記載
  - Codex CLI 対象外が明記
  - migration note への導線がある
  - Step 3a の同梱範囲記述が反映されている

### Step 3a: README 同梱範囲・未同梱 agents 情報の記載

- **Output**: Step 3 に含まれる「同梱 skills/agents/rules 一覧」「未同梱 agents の理由と入手方法」セクション
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**:
  - 同梱 7 skills の一覧と役割が記載
  - 同梱 8 agents の一覧と役割が記載
  - 未同梱 agents（backend-specialist 等）の理由（プロジェクト固有前提）と、既存 `.claude/agents/` での入手方法が記載

### Step 4: docs/plangate-plugin-migration.md 新規作成

- **Output**: `docs/plangate-plugin-migration.md`
- **Owner**: agent
- **Risk**: 中
- **🚩 チェックポイント**:
  - 背景・目的・デュアル運用前提が記述
  - 同梱範囲詳細（7 skills + 8 agents + 3 rules）
  - 対象外の理由（プロジェクト固有 agents 等）
  - 将来計画（marketplace 想定）
  - 既存利用者向け段階的移行手順

### Step 5: plugin 内 README 本文化

- **Output**: `plugin/plangate/README.md`（TASK-0017 のプレースホルダーを置換）
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**:
  - インストール手順
  - 基本使い方（`/ai-dev-workflow` 呼び出し例）
  - 同梱 skills / agents / rules 一覧
  - トラブルシュート（既知制約）

### Step 6: 相互参照リンク設定 + 検証

- **Output**: `docs/working/TASK-0020/evidence/link-verification.md`（手動確認したリンクの一覧と結果）
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**:
  - Root README → migration note → plugin README のナビゲーションが機能
  - 各 md 内の相対リンクを Read ツールで辿り、リンク先ファイルが存在することを手動確認（`markdown-link-check` 等の外部依存は使わない）
  - 確認結果が `link-verification.md` に記録（リンク一覧 + OK/NG）

### Step 7: 最終確認

- **Output**: 受入基準 9 項目の突合結果
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: 全基準 PASS

## Files / Components to Touch

| 種別 | ファイルパス | 変更内容 |
| --- | --- | --- |
| 修正 | README.md | plugin 導入セクション追加 |
| 新規 | docs/plangate-plugin-migration.md | 詳細 migration note |
| 修正 | plugin/plangate/README.md | プレースホルダーを本文で置換 |
| 新規 | docs/working/TASK-0020/evidence/readme-structure.md | 既存構成調査 |

## Testing Strategy

- **Unit**: 各 md ファイルの存在と必須セクション確認
- **Integration**: リンク整合（Root → migration → plugin README）
- **E2E**: 読者目線での理解可能性（完全な手順で plugin 導入できるか）
- **Edge cases**: 既存 README の既存セクションへの影響、リンク切れ
- **Verification Automation**:
  - `grep -c "plugin" README.md` → plugin 導入セクションの存在
  - `test -f docs/plangate-plugin-migration.md` → 存在確認
  - `grep -c "Codex" README.md` → Codex CLI 対象外記述の存在
  - 手動リンク確認: 各 md のリンクを Read で辿り、`evidence/link-verification.md` に結果記録（外部ツール非依存）
  - 手動: README 通りに plugin 導入試行（install syntax は Step 1 の evidence 参照）

## Risks & Mitigations

| リスク | 対策 |
| --- | --- |
| 同梱範囲の記述が実装と乖離 | #17-#19 完了後に着手、実装結果を参照 |
| 移行手順が不明確で混乱を招く | デュアル運用前提を明記、「急いで移行不要」記載 |
| 将来計画がコミットメント化 | 「想定」「検討中」等の曖昧表現で余地を残す |
| Codex CLI 対象外の記述が誤解を招く | 「現時点は対象外、将来検討」と明記 |
| リンク切れ | Step 6 でリンクチェック |

## Questions / Unknowns

- marketplace 公開の具体的時期（未定、note に記載せず）
- plugin install コマンド syntax（TASK-0017 Step 1 調査結果を参照）

## Mode判定

**モード**: `light`

**判定根拠**:
- 変更ファイル数: 3 → light
- 受入基準数: 9 → light/standard 境界
- 変更種別: ドキュメント追加・更新 → light
- リスク: 低（既存コード挙動に影響しない） → light
- **最終判定**: light

## 依存

- **前提**: TASK-0017, TASK-0018, TASK-0019 全て完了
- **後続**: 本 TASK 完了時に親 #16 を Close 可能
