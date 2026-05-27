# TASK-0108 EXECUTION PLAN

> Source: pbi-input.md / GitHub issue #310 / Mode: **standard**
> Generated: 2026-05-22 / Codex 優先順確認 (2026-05-22): TASK-0108 → 0109

## Goal

issue #310 残 5 項目 (#3-#7) を反映し、外部新規 OSS 利用者の初期導入を **CONDITIONAL Yes → Yes** に引き上げる。Codex+Gemini 公開サイト評価で指摘された「公開導線の二重性」「デメリット記述不足」「用語洪水」を構造的に解消。

## Constraints / Non-goals

### Constraints
- **docs only**: コード変更なし、CLI/hook/schema には触れない
- **後方互換**: 既存ページ URL を破壊しない（リダイレクト不要レベルで現状維持）
- **既存ABCD呼称残置**: #7 で WF-XX を主表記化するが、既存 ABCD 参照は対応表で吸収 (破壊回避)
- **markdownlint pass**: `.markdownlint-cli2.jsonc` の MD013/MD024 設定範囲で markdown 標準準拠

### Out of scope (#356 で完了済、本 PBI 対象外)

- **#1 「最初に読む 3 ページ」順序明示** — README L21-25 + docs/index.md L9-17 で達成済
- **#2 Requirements 明文化** — README + docs/index.md 両方で達成済
- **#4 doctor --fix 必須度強調** — README L143-155 で達成済
- **#5 When NOT to use** — `docs/when-not-to-use.md` 新設済
- **#6 用語 Glossary** — `docs/glossary.md` 新設済

本 PBI の **実 scope は #3 (30-min 統一) + #7 (ABCD↔WF 呼称統合) の 2 項目** に絞られる (T-01 evidence で確認、PR #373)。

### Non-goals
- Pages 配信構造の根本変更（#295 別途）
- 過去 design doc (v4/v5) の本文更新（既に Historical Archive マーク済）
- 公開サイト情報設計の全面再構成

## Approach Overview

5 項目を **小規模 PR 1 本で集約反映**（doc only で互いに独立性が高く、レビュー単位として適切）。新規ファイル 2 件 (`docs/glossary.md`, `docs/when-not-to-use.md`) + 既存ファイル 5-7 件への小規模追記。

## Work Breakdown

| # | Step | Output | Owner | Risk | 🚩 Checkpoint |
|---|------|--------|-------|------|--------------|
| 1 | **#3 30-min first run 単一化** — README + README_en + docs/index.md の 3 箇所で `staged-adoption-guide.md` Phase 0 を**正本**として明示、README は短縮版・docs/index.md は導線。アンカー `[Phase 0](./docs/staged-adoption-guide.md#phase-0-体験day-1)` まで具体化 | README.md + README_en.md + docs/index.md + staged-adoption-guide.md | AI | low | 3 ファイル冒頭で導線統一、アンカー解決確認 |
| ~~2~~ | ~~**#4 doctor --fix 必須度強調**~~ — **#356 (merged) で完了** (README L143-155 `### 導入後: hook 強制 🚨 必須` + ⚠️ 重要 box 追加済) | — | — | **DONE via #356** | スコープから除外、AC-4 既に達成 |
| ~~3~~ | ~~**#5 When NOT to use ページ新規**~~ — **#356 (merged) で完了** (`docs/when-not-to-use.md` 新設) | — | — | **DONE via #356** | スコープから除外、AC-5 既に達成 |
| ~~4~~ | ~~**#6 用語 Glossary 新規**~~ — **#356 (merged) で完了** (`docs/glossary.md` 新設、L23-31 に ABCD↔WF 対応表含む) | — | — | **DONE via #356** | スコープから除外、AC-6 既に達成 |
| 5 | **#7 呼称統合 (LOW)** — A/B/C/D ↔ WF-01..05 対応表は**`docs/glossary.md` を正本**とし、既存 `docs/workflows/README.md` 対応表は glossary.md 参照に切替 (重複解消)。`docs/plangate.md` の見出しは `## A: PBI INPUT (WF-01/02)` のように**併記**に留め既存アンカー ID を維持。docs/ai/project-rules.md に「新規 doc は WF-XX 優先、既存 ABCD は対応表で吸収」方針追記 | docs/glossary.md (正本) + docs/workflows/README.md (参照に切替) + docs/plangate.md (見出し併記) + docs/ai/project-rules.md (方針追記) | AI | medium | 正本/参照関係明確 + 既存アンカー破壊なし + 対応表が機械的に正しい |
| 6 | **C-2 任意外部レビュー** — Codex + Gemini 再委任、本 PR 反映後の評価で `CONDITIONAL Yes → Yes` を再確認 (AC-6) | review-external.md (本セッション内) | AI | low | 両レビュアから新たな major 0 件 |
| 7 | **handoff + V-1** | TASK-0108/handoff.md | AI | low | AC-1..7 全 PASS |

## Files / Components to Touch

| ファイル | 性質 |
|---------|------|
| `README.md` | 追記 (#3 first-run link / #4 doctor --fix box) |
| `README_en.md` | 追記 (#4 英訳) |
| `docs/staged-adoption-guide.md` | 追記 (#3 first-run 主導線明示) |
| `docs/when-not-to-use.md` | 新規 (#5) |
| `docs/glossary.md` | 新規 (#6, #7 対応表含む) |
| `docs/philosophy.md` | リンク追記 (#5) |
| `docs/index.md` | リンク追記 (#5, #6) |
| `docs/plangate.md` | 冒頭 Glossary link (#6) |
| `docs/ai/project-rules.md` | 呼称方針追記 (#7) |
| `README_en.md` | T-03 (#3) 英訳 + アンカー追加 |
| `docs/plangate.md` | T-07 (#7) 見出し併記 (アンカー維持) |
| `docs/workflows/README.md` | T-07 (#7) 対応表を glossary 参照に切替 |
| `docs/workflows/README.md` | 必要なら対応表参照 (#7) |
| `docs/working/TASK-0108/handoff.md` | WF-05 |

## Testing Strategy

- **markdownlint**: `.markdownlint-cli2.jsonc` 設定で全 markdown ファイル pass
- **リンク健全性**: 新規・変更リンクが実ファイルに到達することを `find` + `grep` で機械検証
- **既存テスト**: `tests/run-tests.sh` 101/0 + `tests/hooks/run-tests.sh` 79/0 維持（コード変更なしのため自明）
- **C-2 外部レビュー**: Codex + Gemini に「新規 OSS 利用者の初期導入を Yes と判定できるか」を委任 (AC-6)

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| **#7 呼称統合で既存 ABCD 参照リンクが壊れる** | medium | 既存 ABCD 表現は本文に残し、`docs/plangate.md` の見出しは「`## A: PBI INPUT (WF-01/02)`」のように併記でアンカー ID 維持。対応表は `docs/glossary.md` 正本 + `docs/workflows/README.md` 参照切替で重複解消 (R-codex#1) |
| **markdownlint MD028 (blank-line-in-blockquote) 違反** | low | T-04 警告 box の空行にも `> ` を含める実装ガイドを本 plan に明記 (R-gemini#1) |
| **TC-08 外部レビュー判定プロトコル弱い** | medium | AC-6 の判定基準を「同一プロンプト / 対象ファイル一覧 / APPROVE-CONDITIONAL-REJECT / major 0・未解決 conditional 0」まで固定 (R-codex#2、test-cases.md TC-08 詳細化) |
| **docs/index.md 「最初に読む 3 ページ」の純度** | low | #5 When NOT to use と #6 Glossary は「最初に読む 3 ページ」ではなく `## Reference` 等の補足セクションに配置 (R-gemini#3) |
| **Glossary が肥大化して維持コスト増** | low | 略号一覧 + 参照先 URL のみで本文重複を避ける、各略号は 1 行解説 |
| **When NOT to use が攻撃的トーンになる** | low | 「適用しないべきケース」「他ツールが適する場合」表現に統一、競合排他的表現を避ける |
| **doctor --fix 強調 box が markdownlint MD028 (blank-line-in-blockquote) 違反** | low | 標準 blockquote 構文で書く、必要なら警告マーク用 emoji 使用 |

## Questions / Unknowns

- **#3 first-run 単一化**: README 10 分 と staged-adoption Phase 0 のどちらが「正」か → **staged-adoption-guide が主、README は短縮チュートリアル**（Codex 評価で staged-adoption が高評価）と固定。代替案は C-2 で再評価
- **#6 Glossary 配置**: 専用 `docs/glossary.md` vs 主要 doc 冒頭 blockquote → **専用ファイル**（重複と維持コスト最小）
- **#7 統合方針**: ABCD 完全廃止 vs 対応表で吸収 → **対応表で吸収** (破壊回避)

## Plan Health (T-01 反映後)

| 項目 | plan 見積もり | T-01 実数 | 比率 | 判定 |
|------|--------------|----------|------|------|
| 変更ファイル数 | 7 (Step 1-7) | **5** (Step 1 + Step 5 + Step 6 任意 + Step 7) | 0.71 倍 | 1 段降格候補 |
| 受入基準数 | 7 | **2 残** (AC-3 + AC-7 / 他 5 件 #356 達成) | — | 本 PBI 実 scope は 2 件 |
| 実 work breakdown | Step 1-7 | **Step 1 + Step 5 + Step 6 + Step 7** (Step 2/3/4 削除) | — | 簡素化 |

→ #351 (TASK-0117) 事前メトリクス検証「< 1 倍 → Mode 1 段下げ候補」に該当。ただし本 PBI は **scope 縮小済で実 work が 2 項目** のため、Mode は standard 維持しつつ AC 充足率を明示 (5/7 既達成 + 2/7 残)。

## Mode 判定

**standard**

- 変更ファイル数: 8-10
- 受入基準数: 7 → standard
- 変更種別: docs 追記・新規（小機能追加に類似）
- リスク: 中 (#7 のみ)
- ロールバック: 容易 (docs only)
- 影響範囲: 公開ドキュメントのみ、CLI/hook/schema 不変
