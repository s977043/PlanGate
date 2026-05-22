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

### Non-goals
- Pages 配信構造の根本変更（#295 別途）
- 過去 design doc (v4/v5) の本文更新（既に Historical Archive マーク済）
- 公開サイト情報設計の全面再構成

## Approach Overview

5 項目を **小規模 PR 1 本で集約反映**（doc only で互いに独立性が高く、レビュー単位として適切）。新規ファイル 2 件 (`docs/glossary.md`, `docs/when-not-to-use.md`) + 既存ファイル 5-7 件への小規模追記。

## Work Breakdown

| # | Step | Output | Owner | Risk | 🚩 Checkpoint |
|---|------|--------|-------|------|--------------|
| 1 | **#3 30-min first run 単一化** — README の「10 分チュートリアル」を `docs/staged-adoption-guide.md` の Phase 0 とリンクで紐付け、どちらが「正」(staged-adoption が主、README は短縮版) かを冒頭で明示 | README.md + staged-adoption-guide.md | AI | low | 両ファイル冒頭で導線統一を確認、内容矛盾なし |
| 2 | **#4 doctor --fix 必須度強調** — README install 節直後に「⚠️ これを実行しないとゲート (強制力) は機能しません」blockquote 追加 | README.md / README_en.md | AI | low | 視覚的目立つ box 表示、英訳整合 |
| 3 | **#5 When NOT to use ページ新規** — `docs/when-not-to-use.md` 新規作成、philosophy.md からリンク。短期プロト過剰/PBI 文化なし/Claude Code 非利用時の制約等 5 件以上 | docs/when-not-to-use.md (新規) + docs/philosophy.md (link) + docs/index.md (link) | AI | low | 5 件以上の具体的トレードオフ、攻撃的でないトーン |
| 4 | **#6 用語 Glossary 新規** — `docs/glossary.md` 新規作成、EH-1〜EH-9/EHS-1〜3/WF-01〜05/V-1〜4/C-1〜4/L-0 等の略号 1 行解説 + 参照先 URL。主要 doc 冒頭から 1 行リンク | docs/glossary.md (新規) + docs/index.md (link) + 主要 doc (plangate.md/philosophy.md 等) 冒頭 link | AI | low | 全略号網羅、参照先実在 |
| 5 | **#7 呼称統合 (LOW)** — A/B/C/D ↔ WF-01..05 の対応表を 1 箇所 (docs/glossary.md or workflows/README.md) に集約、新規ユーザー向けに WF-XX 優先表記方針を docs/ai/project-rules.md に明文化 (破壊的変更なし、対応表で吸収) | docs/glossary.md (or workflows/README.md) + docs/ai/project-rules.md (方針追記) | AI | medium | 対応表が機械的に正しい、既存 ABCD 参照は壊さない |
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
| `docs/workflows/README.md` | 必要なら対応表参照 (#7) |
| `docs/working/TASK-0108/handoff.md` | WF-05 |

## Testing Strategy

- **markdownlint**: `.markdownlint-cli2.jsonc` 設定で全 markdown ファイル pass
- **リンク健全性**: 新規・変更リンクが実ファイルに到達することを `find` + `grep` で機械検証
- **既存テスト**: `tests/run-tests.sh` 82/0 + `tests/hooks/run-tests.sh` 79/0 維持（コード変更なしのため自明）
- **C-2 外部レビュー**: Codex + Gemini に「新規 OSS 利用者の初期導入を Yes と判定できるか」を委任 (AC-6)

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| **#7 呼称統合で既存 ABCD 参照リンクが壊れる** | medium | 既存 ABCD 表現は本文に残し、新規 ABCD ↔ WF-XX 対応表を docs/glossary.md に追加するだけにする（破壊回避） |
| **Glossary が肥大化して維持コスト増** | low | 略号一覧 + 参照先 URL のみで本文重複を避ける、各略号は 1 行解説 |
| **When NOT to use が攻撃的トーンになる** | low | 「適用しないべきケース」「他ツールが適する場合」表現に統一、競合排他的表現を避ける |
| **doctor --fix 強調 box が markdownlint MD028 (blank-line-in-blockquote) 違反** | low | 標準 blockquote 構文で書く、必要なら警告マーク用 emoji 使用 |

## Questions / Unknowns

- **#3 first-run 単一化**: README 10 分 と staged-adoption Phase 0 のどちらが「正」か → **staged-adoption-guide が主、README は短縮チュートリアル**（Codex 評価で staged-adoption が高評価）と固定。代替案は C-2 で再評価
- **#6 Glossary 配置**: 専用 `docs/glossary.md` vs 主要 doc 冒頭 blockquote → **専用ファイル**（重複と維持コスト最小）
- **#7 統合方針**: ABCD 完全廃止 vs 対応表で吸収 → **対応表で吸収** (破壊回避)

## Mode 判定

**standard**

- 変更ファイル数: 8-10
- 受入基準数: 7 → standard
- 変更種別: docs 追記・新規（小機能追加に類似）
- リスク: 中 (#7 のみ)
- ロールバック: 容易 (docs only)
- 影響範囲: 公開ドキュメントのみ、CLI/hook/schema 不変
