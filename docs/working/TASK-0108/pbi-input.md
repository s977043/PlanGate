# PBI INPUT PACKAGE: TASK-0108 — 公開ドキュメント外部 UX 改善 (#310 残 5 項目)

> Source: issue #310 (Codex+Gemini 公開サイト評価 2026-05-22) / Parent issue / Created: 2026-05-22

## Context / Why

#310 (Codex+Gemini 公開サイト評価) の HIGH 2 項目 (#1 3 ページ順序 / #2 Requirements) は短期 PR #311 で完了。**残 5 項目** (MEDIUM 4 + LOW 1) を PBI 化して plan→C-3→exec フローで対応する。

両者が指摘した「公開導線の二重性」「デメリット記述不足」「用語洪水」を、PBI スコープ内で構造的に解消することで、新規外部 OSS 利用者の初期導入を **CONDITIONAL Yes → Yes** に引き上げる。

## What (Scope)

### In scope (5 項目、優先順)

| # | 改善案 | 優先 | 規模 |
|---|--------|------|------|
| 3 | **30-minute first run を 1 本に統一** — README 10 分チュートリアル vs `staged-adoption-guide.md` Phase 0 のどちらが推奨かを明示、相互参照と順序を固定 | HIGH | 中 |
| 4 | **`doctor --fix` 必須度を README install 直後に強調** — 「これをやらないとゲートは機能しない」警告を target_emphasis に | MEDIUM | 小 |
| 5 | **`When NOT to use PlanGate` / Trade-offs ページ追加** — `docs/when-not-to-use.md` 新規、philosophy.md からリンク。学習負荷・PBI 記入コスト・Claude Code 依存範囲・短期プロトタイプには過剰、を明記 | MEDIUM | 小 |
| 6 | **用語クイックリファレンス** — EH-1〜EH-9 / WF-01〜WF-05 / V-1〜V-4 / C-1〜C-4 / L-0 等の略号 1 行解説。主要 doc (plangate.md, philosophy.md, hook-enforcement.md, workflows/README.md) 冒頭に「Glossary」blockquote 追加 or `docs/glossary.md` 新規 + リンク | MEDIUM | 中 |
| 7 | **A/B/C/D ↔ WF-01..05 呼称統合** — 歴史的経緯で並存している ABCD (plangate.md) と WF-XX (workflows/) の対応表を 1 箇所に集約、新規ユーザー向けに WF-XX 優先表記へ段階的移行 | LOW | 中-大 |

### Out of scope

- Pages 配信構造の根本変更（#295 で別途）
- 公開サイト全体の情報設計再構成（規模過大）
- 過去の design doc (v4/v5) 全面更新（既に Historical Archive マーク済）

## 受入基準 (Acceptance Criteria)

- [ ] **AC-1**: 公開トップ + README + staged-adoption-guide の 3 箇所で「30 分初回体験のエントリポイント」が 1 本に統一・矛盾なし
- [ ] **AC-2**: README install 節直後に `doctor --fix` 必須度の警告ブロックがあり、見落とせない強調（**太字** + 注意マーク）
- [ ] **AC-3**: `docs/when-not-to-use.md`（or 同等セクション）が存在し、Trade-offs / 適用しないべきケース 5 件以上を具体例で記載
- [ ] **AC-4**: 用語略号 (EH/WF/V/C/L) の意味と参照先を Glossary として 1 箇所に集約、主要 doc 冒頭からリンク
- [ ] **AC-5**: 呼称統合 — plangate.md と workflows/ で同じフェーズ参照に WF-XX 主・ABCD 副 (or 統一) の表記方針を docs/ai/project-rules.md or 専用 readme で明文化
- [ ] **AC-6**: Codex / Gemini に 再委任 — 全 5 項目反映後、両者から「公開導線が一貫して新規ユーザーに優しい」評価が得られる
- [ ] **AC-7**: 既存テスト regression なし（CLI 82/0 + Hook 79/0 維持）、追加 doc が markdownlint pass

## Notes from Refinement

- #311 マージ後の plan_hash 算出してから C-3
- #310 (parent issue) は本 PBI 完了後に手動 close（auto-close は本 PBI PR 単独でなく、関連 7 件全完了で）
- 用語 Glossary は新規ドキュメント `docs/glossary.md` が最小工数（既存 doc 冒頭への blockquote 注入は本数多い）
- 呼称統合 (#7 LOW) は段階的移行で破壊回避（既存 ABCD 参照を一掃しない、対応表で吸収）

## Estimation Evidence

### Risks
- 呼称統合 (#7) で既存内部 doc (.claude/rules/, docs/working/) の参照が壊れるリスク → 主要対外 doc に限定し内部は次フェーズへ
- Glossary 新規追加で main doc との重複や不一致リスク → 略号一覧 + 参照先 URL のみで本文重複を避ける
- `When NOT to use` で過度に競合排他的な記述になる risk → 「適用しないべきケース」表現に統一し攻撃的にならないトーン

### Unknowns
- 30 分初回体験を「README 主・staged-adoption 副」or「staged-adoption 主・README 副」のどちらに統一すべきか → C-2 外部レビューで両者意見を集約
- 用語 Glossary の場所: 専用 `docs/glossary.md` vs 主要 doc 冒頭 blockquote → small 規模で完結する前者を仮採用、C-2 で検証

### Assumptions
- 短期 PR #311 がマージされた状態を前提に作業（pull main から exec 着手）
- markdownlint 設定変更不要（既存 MD013/MD024 設定で pass する範囲）

## Mode 判定（参考）

`standard`（5 項目、各小規模、構造的安全側）

- 変更ファイル数: 5-10 想定 (README, README_en, docs/index.md, plangate.md, philosophy.md, workflows/README.md, docs/glossary.md 新規, docs/when-not-to-use.md 新規)
- 受入基準数: 7 → standard
- リスク: 中 (#7 呼称統合のみ波及範囲広)
- ロールバック: 容易 (docs only)

## Labels / Milestone

- Labels: `documentation` / `enhancement` / `priority:P2`
- Milestone: 未割当
- Parent: issue #310

## Parent / Related

- Parent issue: #310 (公開ドキュメント外部 UX 改善 7 項目)
- 短期完了: PR #311 (#1 + #2)
- 関連: #226 段階的導入ガイド (v8.7.0)、#225 versioning-stability-policy
