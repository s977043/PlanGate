# Codex 相談結果 — TASK-0039 Step 3-8

> 実施: 2026-04-30 / Codex CLI (`codex-cli 0.124.0`) / `codex exec` 経由
> 入力プロンプト: [`_codex-consult.txt`](./_codex-consult.txt)
> 目的: PR #132 (Step 1+2) 完了後、Step 3-8 の進め方の第三者見解

## Q1: Core Contract 品質レビュー

- 判定: **ACCEPTABLE**
- 強み: Role / Goal / Success criteria / Stop rules が分離され、入口ファイルから参照する正本として成立。Iron Law 7 項目も hard constraints に集約され、prompt slimming の基盤になる。
- 弱み・改善点: AI 運用 4 原則が「併存」として書かれており、Core Contract との優先順位が少し曖昧。`project-rules.md` 側の F セクションとの重複管理方針も明記した方がよい。
- **重大な指摘 CC-01**: `docs/ai/core-contract.md` が「Iron Law / 制約 / 停止条件の正本」と宣言している一方、`project-rules.md` もプロジェクトルール正本。Step 5 で「**Core Contract は実行契約の正本、project-rules はプロジェクト共通ルールの正本**」と責務境界を明記すべき。

## Q2: 削減目標達成可能性

### CLAUDE.md (43 → 22 行以下)

- 達成可能性: **MEDIUM**
- 削る要素: 共通ルール説明、参照先テーブルの詳細行、判断基準の重複、`project-rules.md` と重なる説明文
- 残す要素: `core-contract.md` / `project-rules.md` への導線、Claude 固有参照先の最小セット、`<language>` / `<character_code>` / `<law>`、AI 運用 4 原則全文
- 現実的な落としどころ: **21〜22 行**。4 原則全文が重いため、空行削減と参照先圧縮が必須

### AGENTS.md (61 → 30 行以下)

- 達成可能性: **HIGH**
- 削る要素: リポジトリ性質の詳細、Progressive Disclosure 表、Codex 固有参照先テーブルの網羅列挙、作業ルールの重複
- 残す要素: 読む順序、Core Contract / project-rules / `.codex/instructions.md`、実行入口、package manager 不在、AGENT_LEARNINGS の扱い、日本語出力
- 現実的な落としどころ: **24〜28 行**。表をやめて短い箇条書きにすれば達成可能

## Q3: PR 分割粒度

- 推奨: **2 PR**
- 境界:
  - **PR-A** = Step 3-5（CLAUDE.md / AGENTS.md / project-rules.md の薄型化と参照整合）
  - **PR-B** = Step 6-8（hard-mandate 削減、検証、handoff）
- 理由:
  - 入口ファイル薄型化は起動破壊リスクが高く、単独でレビュー・検証しやすい
  - hard-mandate 削減は対象が `.claude/` と `plugin/plangate/` に広がるため、別 PR にすると Plugin 同期漏れや Iron Law 弱化を集中レビューできる

## Q4: リスクと順序

### 順序見直し提案

**Step 5 → Step 3 → Step 4** の順が良い:
- まず `project-rules.md` に Core Contract の責務境界と参照を追加
- その後 CLAUDE.md / AGENTS.md を薄くすると、入口ファイルの削除根拠が明確

### 想定リスク

| Severity | リスク |
|---------|--------|
| high | CLAUDE.md 薄型化で `<law>` の保持要件を満たせず、22 行以下と衝突する |
| high | Core Contract / project-rules の正本宣言が衝突し、参照優先順位が曖昧になる |
| medium | Codex CLI 入口から `core-contract.md` への導線不足で運用契約が読まれない |
| medium | Plugin 配布版とローカル `.claude/` の hard-mandate 表現が乖離する |
| medium | `必ず` / `絶対` の機械削減で Iron Law の強制力まで弱く見える |

### 各 Step の Stop rule 候補

| Step | Stop trigger |
|------|------------|
| Step 3 | `<law>` 全文維持と 22 行以下が両立しない場合 |
| Step 4 | `.codex/instructions.md` と AGENTS.md の読み込み順序が矛盾する場合 |
| Step 5 | Core Contract と project-rules の正本責務を一意に定義できない場合 |
| Step 6 | Iron Law / AI 運用 4 原則以外の hard mandate か判断できない表現が出た場合 |
| Step 7 | grep 残存件数が説明不能、またはリンク到達性・行数目標が未達の場合 |
| Step 8 | handoff に未検証項目、WARN、手動確認未実施が残る場合 |

## 総合推奨

次セッションは **Step 5 → Step 3 → Step 4** の順で進める:
1. まず Core Contract と project-rules の責務境界を明文化
2. その後、CLAUDE.md は `<law>` 維持を最優先に 21〜22 行へ圧縮
3. AGENTS.md は Core Contract 参照中心に 24〜28 行へ落とす
4. Step 6 以降は別 PR に切り、Plugin 同期と hard-mandate 削減を集中レビューする

## 本 PR (#132) で取り込むべき変更

| ID | 対応 |
|----|------|
| **CC-01** | `docs/ai/core-contract.md` に **正本責務境界** セクションを追加（Core Contract = 実行契約、project-rules = プロジェクト共通ルール） |
| **plan.md 順序** | Step 5 → 3 → 4 に並び替え + PR 分割方針（PR-A / PR-B）を明記 |
| **plan.md Stop rule** | 各 Step の Stop trigger を明記 |
| **status.md** | 次セッションを「PR-A: Step 5 → 3 → 4」に更新 |
