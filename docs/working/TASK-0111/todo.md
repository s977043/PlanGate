# TASK-0111 EXECUTION TODO

> Source: plan.md / Mode: standard / Generated: 2026-05-25

## 🤖 Agent タスク

### Phase 1: 準備
- [ ] **T-01 (R-002/R-005/R-006)**: root `pages/` 参照箇所 (`grep -rn "pages/" --include="*.md"` 等) 全件抽出、Cloudflare Pages / .github/workflows/ 等 secondary deploy 影響評価、外部 link 影響メモ作成 (owner=agent / Risk=low / 🚩 全参照マップ完成)

### Phase 2: 実装
- [ ] **T-02**: `git mv pages/ docs/pages/` (history 保持) (owner=agent / Risk=low / depends_on=T-01 / 🚩 git log --follow で履歴追跡可)
- [ ] **T-03 (R-004/R-005)**: **全 `docs/**/*.md`** の `../pages/...` GitHub blob URL を `./pages/...` 相対パスに置換 (T-01 で特定した全箇所) (owner=agent / Risk=medium / depends_on=T-02 / 🚩 全 link が `./pages/...` 形式 + markdownlint pass)
- [ ] **T-04**: `docs/_config.yml` で `docs/pages/` 配信確認 (relative_links / collections 既存設定で動作するか) + 必要なら microadjustment (owner=agent / Risk=low / depends_on=T-02 / 🚩 _config.yml で `docs/pages/` 認識)

### Phase 3: 検証
- [ ] **T-05**: reference 健全性 CI を local 実行で事前確認 (`sh scripts/check-reference-health.sh` 等)、markdownlint 全 PASS (owner=agent / Risk=medium / depends_on=T-03 / 🚩 全 CI PASS)

### Phase 4: 完了
- [ ] **T-07**: handoff.md (Rule 5) + V-1 (test-cases 全件突合) (owner=agent / Risk=low / depends_on=全完了 / 🚩 AC-1..7 PASS)

## 👤 Human タスク

- [ ] **H-01**: **C-3 ゲート** — plan/todo/test-cases/review-self.md 確認 → APPROVE/CONDITIONAL/REJECT → `approvals/c3.json` 発行
- [ ] **H-02 (T-06, R-003 mandatory pre-C-3 gate)**: ローカル Jekyll build 検証 (AI 不可、**C-3 前に必須実施**) — `bundle exec jekyll serve` で `/docs/pages/...` 200 OK 確認
- [ ] **H-03**: **C-4 ゲート (PR レビュー)** + **merge** (Human-owned 固定)
- [ ] **H-04 (AC-4)**: merge 後 公開サイト https://s977043.github.io/PlanGate/ で 200 OK 確認

## ⚠️ 依存関係

- T-02..T-07 は H-01 (C-3) 通過後にのみ着手可
- T-01 (read-only 調査) は C-3 前可
- H-02 / H-04 は AI 不可、Human が個別実施

## Iron Law 遵守

- Edit/Write 前に PLANGATE_HOOK_TASK=TASK-0111 設定
- docs/ 配下のみ操作、承認境界 (.claude/, scripts/hooks/, bin/plangate) には触れない

## 完了条件

全 T + handoff 6 要素 + AC-1..7 PASS + markdownlint pass + reference 健全性 CI PASS
