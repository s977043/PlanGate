# TASK-0021 シリーズ 振り返り

> 実施日: 2026-04-20
> 対象セッション: PlanGate × Workflow/Skill/Agent ハイブリッドアーキテクチャ導入 → v7.0.0 リリース

---

## 1. セッション成果サマリ

### マージ済み PR（12 本）

| PR | 種別 | 内容 |
|---|---|---|
| #29 | PBI | ハイブリッド構想 PBI + 画像 |
| #34 | docs | TASK-0016 系 status.md 完了化 |
| #35 | feat | TASK-0022: Workflow 5 phase 定義（WF-01〜WF-05） |
| #36 | feat | TASK-0024: Skill 10 個 + phase マッピング |
| #37 | feat | TASK-0025: 責務ベース Agent 4 体 + 実行シーケンス |
| #38 | feat | TASK-0026: WF-03 Solution Design 独立化 + design.md テンプレ |
| #39 | feat | TASK-0027: WF-05 Verify & Handoff 標準化 + handoff.md テンプレ |
| #40 | feat | TASK-0028: Rule 1〜5 統合ルール + v7 ハイブリッド統合文書 |
| #41 | docs | CLAUDE.md に v7 参照追加 |
| #43 | fix | 3 エージェント並列レビュー指摘 5 件反映 |
| #44 | release | v7.0.0 リリース準備（release-notes + plugin.json bump） |
| #45 | docs | v7 参照を残り 7 ドキュメントに伝播 |
| #46 | feat | Codex CLI 側に v7 責務ベース Agent 4 体を同期 |

### リリース公開

- **v7.0.0** — PlanGate v7: ハイブリッドアーキテクチャ（Latest）
- Release URL: https://github.com/s977043/plangate/releases/tag/v7.0.0
- plugin バージョン: `0.1.0` → `0.2.0`

### Issue クローズ

- 親 #22 + サブ #23〜#28（計 7 件）すべて CLOSED
- TASK-0016 系の付随整理: #17〜#20 + #16 も本セッション前半で CLOSED

### 逆輸入改善点の達成

親 PBI で合意された 4 改善点をすべて実装:

1. ✅ review 観点の Skill 化
2. ✅ solution-architect を独立フェーズ化
3. ✅ Verify & Handoff を標準 phase 化
4. ✅ 責務ベース subagent

---

## 2. 良かった点（Keep）

### K-1: 並列 3 エージェントによるレビュー

**explorer-agent（一貫性）/ general-purpose（品質・Rule 遵守）/ codex:codex-rescue（第三者）** の 3 視点で並列レビューを実施。3 者が共通して指摘した `release-manager` 不在参照、鮮度ズレ、`self-review` 帰属不明の 5 件を PR #43 で一括解消。1 視点だけでは見落としたはずの項目が収束した。

### K-2: サブ issue を独立番号（TASK-0022〜0028）で切った

Issue 番号 #23〜#28 に対して、PlanGate の既存命名規則（TASK-0016 系→#17〜#20）を踏襲し、独立番号を割り当てた。依存関係・進捗管理が明瞭で、既存ディレクトリ構造（`docs/working/TASK-XXXX/`）と整合。

### K-3: v5/v6 を破壊せず v7 を opt-in で導入

既存の PlanGate v5 ワークフロー（A/B/C-1〜V-4/PR作成/C-4）を一切変更せず、`docs/workflows/` に新規追加・実行層を構築。既存の 17 Agent は維持しつつ、責務ベース 5 Agent を追加。`orchestrator` のみ上書き更新で、汎用調整機能は保持。

### K-4: Codex C-2 の CONDITIONAL を毎回誠実に対応

TASK-0022 では EX-01（モード `standard` → `full`）、EX-02（Rule 1 検証の 2 段階化）などの major 指摘を受け、その場で修正 → APPROVE に格上げ。PlanGate のゲート思想（CONDITIONAL は修正前提の暫定承認）が機能した。

### K-5: リリースまで一気通貫で完了

PR 作成 → マージ → tag → GitHub Release → Issue 告知まで、手戻りなく一直線で v7.0.0 リリースまで到達。`release-notes/v7.0.0.md` で v5/v6/v7 の関係、Breaking changes、アップグレードガイドを明示したため、利用者が迷わず判断できる状態にした。

---

## 3. 改善点（Problem / Try）

### P-1: 並行 Codex 作業がローカルブランチと干渉

Codex が別セッションで先行作業していたローカルブランチ（`feat/plangate-v7-agents-5` / `feat/plangate-v7-solution-design` 等）と、私がローカルで作ったブランチの間で混乱が発生。特に `chore/task-0016-closure` からの派生時にブランチ名がズレた。

**Try**: 毎セッション開始時に `git branch --show-current` と `git log --all --oneline -5` を確認するルーチンを徹底する。ブランチ作成前に `git fetch --prune` も入れる。

### P-2: TASK 番号の命名ブレ

初期レビュー時、Codex が `docs/working/TASK-0023/` を Issue #23 用の雛形として作成していた（実体は私が TASK-0022 として進めた Workflow 5 phase 定義と重複）。ユーザー確認時に「TASK-0022 で進める」と決めたが、並行 Codex プロセスが別番号で走っていた。

**Try**: 親 PBI 時点で番号マッピング表を明示的に作る（Issue # → TASK-00XX）。並行 Codex は無効化するか、番号合意を先に取る。

### P-3: 「TASK-XXXX で作成予定」鮮度ズレ

先行 Issue（#26〜#28）の雛形で参照された「TASK-XXXX で作成予定」が、実装完了後も現在形に更新されていなかった（5 Agent + insertion-map で 7 箇所）。PR #43 で一括置換したが、本来は実装完了時に都度更新すべき。

**Try**: 未来時制の表現（「〜予定」「〜で作成される」「仕様確定」）をコミット前に `grep -rn "作成予定\|仕様確定\|整備予定"` でチェックするフックを hybrid-architecture.md の deterministic hooks 候補に追加。

### P-4: markdown lint MD060 / MD040 の繰り返し修正

テーブル区切り行 `|---|---|` と `| --- | --- |` のブレで lint エラーが頻発。各 PR で `perl -i -pe` による一括置換が必要だった。

**Try**: 既存の CI に `docs/workflows/**/*.md` を追加済（PR #35 の V-3 対応）。今後は新規ファイル作成時に `| --- |` 形式で書く（既存 `docs/plangate.md` 慣習）。テンプレート `docs/working/templates/design.md` / `handoff.md` は既に正しい形式で統一済み。

### P-5: 存在しない Agent への参照

Codex 生成の初期 README.md で `release-manager` agent が V-4 主担当として参照されていたが、`.claude/agents/release-manager.md` は存在せず（TASK-0025 で作成対象外）。3 エージェント全員が指摘して発覚。

**Try**: Agent/Skill 名を文書に書く際、`.claude/agents/` と `.claude/skills/` のディレクトリ存在チェックを自動化する。`grep -rh "^| .* |" docs/workflows/*.md | extract agent names | while read a; do test -f .claude/agents/$a.md; done` のような検証を V-1 受け入れ検査に組み込む。

### P-6: main への直接コミット疑惑

PR #36 マージ時、一時的に `feat/plangate-v7-skills-10` ブランチが「main と同じ位置」と誤認しかけた（実際は Codex が自動で PR 作成・マージを並行実行していた）。本人が git log で確認するまで、状況把握が遅れた。

**Try**: 重要な push / PR 作成前に `gh pr list --state all --limit 5` で他の作業者の進行を確認する。

---

## 4. 学び（Lessons Learned）

### L-1: ハイブリッドアーキテクチャの設計原則は強力

Rule 1〜5（Workflow=順序と完了条件だけ / Skill=再利用単位 / Agent=責務だけ / 案件固有=CLAUDE.md / handoff=毎回集約）は、レビュー時の判定軸として非常に有効だった。各ファイルが Rule X 準拠かを機械的に判定できた。

### L-2: Codex による C-2 / V-3 は投資対効果が高い

各 TASK で Codex に plan / 実装差分を独立レビューさせた結果、CONDITIONAL 判定による指摘が毎回有用（TASK-0022: EX-01〜04、TASK-0024: 78/100 major 4件、TASK-0026: major 4件）。C-2 / V-3 は PlanGate full モードで必須化されている意味を実感。

### L-3: 3 エージェント並列レビューは最終品質保証に有効

V-3 単発では見つからなかった鮮度ズレ 7 箇所、`self-review` の帰属不明、v6 roadmap の v7 導線欠落を 3 視点の並列投票で検出。本番リリース前の最終チェックとして再利用すべきパターン。

### L-4: リリースノートに v5/v6/v7 の関係図を入れる

v7.0.0 リリース時、`release-notes/v7.0.0.md` に「v5/v6/v7 の関係表」と「非破壊的な変更の明示」を含めたことで、既存ユーザーが迷わずアップグレード判断できる状態にした。今後のメジャーリリースでも踏襲する。

### L-5: 命名の逸脱は早期発見が重要

「TASK-0016-A」と「TASK-0017」のような階層表記 vs 独立番号、`orchestrator.md` の既存 vs 新規、`release-manager` の実体の有無など、命名と実体の不一致はどれも後から発覚した。**実装開始前に grep で実体確認する**習慣が必要。

---

## 5. 次回セッションへの申し送り

### 推奨される次のアクション（優先順）

1. **Runtime 検証（ドッグフーディング）**: 小さな実 PBI で v7 WF-01〜WF-05 を一周させる。orchestrator から委譲が正しく回るか、各 Skill の呼び出しが期待通りか確認。
2. **CHANGELOG.md 新規作成**: v3〜v7 の履歴統合（各 GitHub Release を取り込み）。OSS 品質向上に寄与。
3. **deterministic hooks 実装**: v6 P1 / hybrid-architecture.md で基盤記述のみ。Rule 1 準拠チェック（手順ワード検出）を hooks 化すれば P-3 の再発防止になる。
4. **release-manager agent 作成**: V-4 の専任 agent。現状は `workflow-conductor` で代替中。

### 参照すべきドキュメント

- `docs/plangate-v7-hybrid.md` — v7 全体像
- `.claude/rules/hybrid-architecture.md` — Rule 1〜5 統合
- `docs/workflows/README.md` — Workflow 5 phase 目次 + PlanGate 対応表
- `docs/workflows/execution-sequence.md` — Agent 間の実行シーケンス

### 注意事項

- **v5/v6 は継続利用可能**。既存プロジェクトへの影響を最小化するため、v7 は opt-in。
- `orchestrator.md` は **汎用調整 + v7 実行層** の両方を担う統合版（既存機能は維持）。

---

## 6. 総括

PlanGate v5/v6 の統制層を破壊せず、v7 ハイブリッドアーキテクチャ（Workflow/Skill/Agent 3 層）を段階的に導入し、v7.0.0 として正式リリースを完了した。逆輸入改善点 4 件をすべて達成、Rule 1〜5 を統合ドキュメント化し、Codex CLI 側にも同期した。

次回以降のセッションでは、**実運用での検証（ドッグフーディング）**が最大の価値創出機会。Agent 間の委譲が想定通り機能するか、各 Skill が案件固有情報を引き込まずに動作するか、handoff.md が次スプリントへの引き継ぎ資産として機能するかを、小さな実 PBI で確認することが推奨される。

**Governance × Modularity =「強固な運用 × 柔軟な実行」** は、ドキュメントとしては完成した。次は実運用で証明する段階。
