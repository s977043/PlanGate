# TASK-0108 EXECUTION TODO

> Source: plan.md / Mode: standard / Generated: 2026-05-22

## 🤖 Agent タスク

### Phase 1: 準備
- [ ] **T-01**: 既存 README 10 分チュートリアル + staged-adoption-guide Phase 0 を読み比べ、統一方針 (staged-adoption が主) を確定 (owner=agent / Risk=low / 🚩 両方の現状抽出)
- [ ] **T-02**: 既存 docs/philosophy.md / docs/index.md / plangate.md の冒頭構造を確認、Glossary/When-NOT リンク挿入位置を決定 (owner=agent / Risk=low)

### Phase 2: 実装 (5 改善項目)
- [ ] **T-03 (#3)**: 30-min first run 単一化 — staged-adoption-guide.md Phase 0 を「正」とし、README は「短縮版・正本へのリンク」と冒頭で明示。両ファイルの相互参照固定 (owner=agent / Risk=low / depends_on=T-01 / 🚩 矛盾なし)
- [ ] **T-04 (#4)**: README install 直後に doctor --fix 必須度 警告 box 追加 (⚠️ + blockquote)。README_en.md にも英訳 (owner=agent / Risk=low / 🚩 視覚的目立つ、英訳整合)
- [ ] **T-05 (#5)**: docs/when-not-to-use.md 新規作成 (短期プロト過剰/PBI 文化なし/Claude Code 非利用時制約 等 5 件以上)。docs/philosophy.md と docs/index.md からリンク (owner=agent / Risk=low / 🚩 5 件以上、攻撃的でない)
- [ ] **T-06 (#6)**: docs/glossary.md 新規作成 (EH-1〜EH-9 / EHS-1〜3 / WF-01〜05 / V-1〜4 / C-1〜4 / L-0 / PBI 等 略号 1 行解説 + 参照 URL)。docs/index.md + plangate.md + philosophy.md 冒頭から 1 行リンク (owner=agent / Risk=low / 🚩 全略号網羅、参照先実在)
- [ ] **T-07 (#7)**: ABCD ↔ WF-01..05 対応表を docs/glossary.md 末尾に追加。docs/ai/project-rules.md に「新規 doc は WF-XX 優先表記、既存 ABCD は対応表で吸収」方針追記 (owner=agent / Risk=medium / depends_on=T-06 / 🚩 対応表が機械的に正しい、既存 ABCD 参照は壊さない)

### Phase 3: 検証
- [ ] **T-08**: markdownlint 全 markdown ファイル pass (owner=agent / Risk=low / 🚩 lint pass)
- [ ] **T-09**: リンク健全性検証 — 新規・変更リンクが実ファイル到達 `find docs -name '*.md' | xargs grep ...` (owner=agent / Risk=low / 🚩 broken link 0)
- [ ] **T-10 (任意)**: C-2 外部レビュー — Codex + Gemini に再委任、新規 OSS 利用者視点で CONDITIONAL Yes → Yes になるか確認 (owner=agent / Risk=low / 🚩 両者 major 0、AC-6)

### Phase 4: 完了
- [ ] **T-11**: handoff.md 作成 (Rule 5 必須 6 要素) + V-1 受け入れ検査 (test-cases.md 全件突合) (owner=agent / Risk=low / depends_on=全完了 / 🚩 AC-1..7 PASS)

## 👤 Human タスク

- [ ] **H-01**: **C-3 ゲート** — plan/todo/test-cases/review-self.md 確認 → APPROVE/CONDITIONAL/REJECT 三値判定 → `approvals/c3.json` 発行 (必須・AI 不可)
- [ ] **H-02**: **C-4 ゲート (PR レビュー)** — exec 完了後の PR を GitHub 上で確認 → APPROVE/REQUEST CHANGES/REJECT
- [ ] **H-03**: **merge** — C-4 APPROVE 後の squash merge (Human-owned 固定)

## ⚠️ 依存関係

- T-03..T-09 は H-01 (C-3) 通過後にのみ着手可
- T-01/T-02 (read-only 調査) は C-3 前でも実行可
- 全 T-* 完了 → PR 作成 → H-02 → H-03

## Iron Law 遵守

- Edit/Write 前に PLANGATE_HOOK_TASK=TASK-0108 を設定
- docs only のため EH-3 Hardening Override 対象パス (`.claude/`, `scripts/hooks/`, `bin/plangate`, `schemas/`, `.github/workflows/`, `AGENTS.md`, `CLAUDE.md`) は触らない（自然に安全）

## 完了条件

全項目 ✅ + handoff 6 要素 + 全 AC PASS + markdownlint pass + リンク健全性 + tests/run-tests 101/0 + tests/hooks 79/0 維持 (コード変更なしで自明)
