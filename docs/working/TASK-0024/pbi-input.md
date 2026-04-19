# PBI INPUT PACKAGE: 再利用可能な Skill 10 個を整備する

> 作成日: 2026-04-20
> PBI: [TASK-0021-B] 再利用可能な Skill 10 個を整備する
> チケットURL: https://github.com/s977043/plangate/issues/24
> 親チケット: https://github.com/s977043/plangate/issues/22

---

## Context / Why

review 観点や手順を **再利用可能な Skill** として切り出す（逆輸入改善点①）。案件ごとのばらつきを減らし、plan.md への埋め込みを排除する。Rule 2 に従い、Skill は再利用単位に限定し、案件固有の話を入れない。

---

## What（Scope）

### In scope

- `.claude/skills/` に 10 個の Skill を配置（`.claude/commands/` ではなく skills 側に統一）
- 各 Skill に以下を定義:
  - 入力（どんな情報を受け取るか）
  - 出力（何を成果物として返すか）
  - 想定利用 phase（WF-01〜WF-05 のどれで呼ばれるか）
  - カテゴリ（Scan / Check / Design / Review / Build）
- 既存 `.claude/skills/`（brainstorming, self-review 等 8 件）との重複チェック
- 重複する場合の統合方針（新規で追加 or 既存に取り込み）

### 対象 Skill（10 件）

| Skill | カテゴリ | WF | 役割 | 出力 |
|-------|---------|-----|------|------|
| context-load | Scan | WF-01 | CLAUDE.md と依頼文から前提を抽出 | 前提サマリ |
| requirement-gap-scan | Scan | WF-02 | 要件の抜け漏れ検出 | 追加要件候補 |
| nonfunctional-check | Check | WF-02 | 性能・保守性・安全性の確認 | 非機能要件 |
| edgecase-enumeration | Check | WF-02 | 境界条件・例外条件の列挙 | エッジケース一覧 |
| risk-assessment | Check | WF-02 | 制約・未確定要素の洗い出し | リスク一覧 |
| acceptance-criteria-build | Design | WF-02 | 受け入れ条件の明文化 | AC 一覧 |
| architecture-sketch | Design | WF-03 | 構成案の叩き台作成 | 構成案 |
| feature-implement | Build | WF-04 | 個別機能の実装 | コード差分 |
| acceptance-review | Review | WF-05 | 要件適合レビュー | 適合/不足一覧 |
| known-issues-log | Review | WF-05 | 妥協点・既知不具合の文書化 | 既知課題表 |

### Out of scope

- Workflow 定義（#23 で対応済）
- Agent 5 体の配置（#25 で対応）
- Rule 1〜5 の明文化（#28 で対応）
- Skill の実行エンジン実装

---

## 受入基準

- [ ] 10 個の Skill が `.claude/skills/` に配置されている
- [ ] 各 Skill に 入力 / 出力 / 想定利用 phase / カテゴリ が定義されている
- [ ] 各 Skill が Rule 2 を満たす（再利用単位限定、案件固有情報なし）
- [ ] 4 カテゴリ（Scan/Check/Design/Review、+ Build）への分類が明示
- [ ] 既存 `.claude/skills/` との重複が解消 or 共存理由が明記
- [ ] WF-01〜WF-05 との phase マッピング表が作成されている

---

## Notes from Refinement

### 配置先

`.claude/skills/` に統一（親 PBI の `.claude/commands/` or `.claude/skills/` のうち skills 側を採用）。理由:
- 既存 `.claude/skills/` と同じ場所にまとめることで管理が単純
- `SKILL.md` 形式で frontmatter 整合取れる
- TASK-0018 で plugin 側にも skills/ として配置済

### 既存 Skill との関係

既存 `.claude/skills/`:
- brainstorming / self-review / codex-multi-agent / subagent-driven-development / systematic-debugging / skill-creator / skill-optimizer / skill-ops-planner

本 TASK で追加する 10 個と重複なし（全て新規 Skill）。

### 想定モード判定

**standard**（中）を想定。

- 変更ファイル数: 11（10 Skill + マッピング表）
- 受入基準数: 6
- 変更種別: 再利用資産の新規整備
- リスク: 中（Skill 定義の粒度・品質が重要）

---

## Estimation Evidence

### Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Skill 定義が案件固有情報を含み Rule 2 違反 | Medium | レビュー時にチェック、違反箇所は CLAUDE.md 側に移す |
| 既存 Skill との粒度不整合 | Medium | 既存 SKILL.md を参照し、構造・粒度を揃える |
| Skill 間の依存・呼び出し順序が不明瞭 | Low | WF-01〜WF-05 の phase マッピングで解決 |

### Unknowns

- 各 Skill の具体入出力フォーマット（YAML / Markdown / JSON）は Skill 毎に決定
- 将来 plugin 同梱する場合、TASK-0018 と同様のコピーで対応可能

### Assumptions

- SKILL.md 形式は既存 `.claude/skills/brainstorming/SKILL.md` 等と同じ
- 10 個の Skill は相互独立（ループ依存なし）

---

## 依存

- **前提**: #23（Workflow 定義）完了
- **後続**: #25 / #26 / #27 で参照される
