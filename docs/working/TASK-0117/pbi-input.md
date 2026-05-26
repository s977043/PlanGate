# TASK-0117 PBI INPUT PACKAGE

> Issue: [#351](https://github.com/s977043/plangate/issues/351)
> Codex 推奨優先順 (2026-05-26): #351 が #352 (codex-mvp-split) の前提条件
> 参考実装: PocketEitan `docs/plangate.md` 「事前メトリクス検証」

## Context / Why

PlanGate A → B 遷移 (PBI INPUT → plan 生成) で AI が **規模見積もりの実数検証なしに Mode 判定** することがあり、実態と乖離するケース実害あり (PocketEitan で 1697 ファイル = 規模 XL を Codex が「M」推定)。

本セッションでも、9 PBI 量産 / process drift / mode 補正の reactive 対応 (TASK-0106 retro → TASK-0112 mode 例外ルール) など、**事前メトリクス検証があれば回避可能だった軌道修正**が複数発生。

#352 (codex-mvp-split) で Phase 分割を扱う前提として、本 PBI で「実数を取る」フェーズを ai-dev-plan skill に組み込む。

## What (Scope)

### In scope

- `ai-dev-plan` skill (**実体: `.agents/skills/ai-dev-plan/SKILL.md`**) に **「事前メトリクス検証」step 追加** (R-001 反映: `.claude/skills/` 配下ではなく `.agents/skills/` が実体)
  - 「全部 / 全件 / 残り N 件」系の対象は実数取得を必須化
  - `grep -rln <symbol> | wc -l` / `find . -name <pattern> | wc -l` 等のコマンド例
- 判定基準明文化:
  - 実数 / 見積もり ≥ 3 → **スコープ縮小 or 別タスクへ切替**
  - 1〜3 倍 → 採用、plan Risks に記録
  - < 1 → 採用、Mode 1 段下げる候補
- `docs/ai/plan-metrics-verification.md` (新規 or 既存追記) 運用ガイド
- 既存実例 1 件以上: PocketEitan 抽象語イラスト 17 グループ / 1697 ファイル を docs に記載
- `tests/extras/ta-19-plan-metrics-verification.sh` (新規) — skill に「事前メトリクス検証」セクションが含まれることを grep で機械検証

### Out of scope

- AI が実コマンド実行を Hook で強制する仕組み (本 PBI は skill の guidance 強化のみ)
- Mode 自動推定の実装変更 (TASK-0112 例外ルールで対応済)
- #352 codex-mvp-split との統合 (順次別 PBI)

## 受入基準

- AC-1: `.agents/skills/ai-dev-plan/SKILL.md` に「事前メトリクス検証」セクションが追加 (Plan 生成前必須 step、B-1 → B-2 mandatory gate に配置 / R-003)
- AC-2: 検証コマンド例 (grep / wc / find 等) が docs に明記
- AC-3: 判定基準 (3 倍以上はスコープ縮小 / 1〜3 倍は記録 / < 1 倍は Mode 降格候補) が docs に明文化
- AC-4: 既存実例 ≥ 1 件 (PocketEitan 抽象語イラスト 17 グループ / 1697 ファイル) を docs に記載
- AC-5: **TASK-0112 plan は merged だが exec 未実施 → mode-classification.md に「承認境界周辺→最低 高」ルール本体は未追加 (R-004 反映)**。本 PBI では「TASK-0112 と将来統合候補」として相互参照、本 PBI exec 時点では境界判定を独立して持つ
- AC-6: `tests/extras/ta-19-plan-metrics-verification.sh` で skill 構造を機械検証 (該当セクション grep)
- AC-7: markdownlint + 既存テスト regression なし
- **AC-8 (R-003)**: skill が plan.md template に **`## Metrics Evidence` 欄** を必須化 (実数 / 見積もり / ratio / 判定 を plan.md 内に残す出力契約)。ta-19 で plan.md 内の該当文字列を grep 検証

## Notes from Refinement

- `.claude/skills/ai-dev-plan/` 配下は Hardening Override 対象 (`.claude/` 配下) → C-3 APPROVED + maintenance window 経由
- PocketEitan PR #371 の該当セクションを参考に最小ポート
- 「事前メトリクス検証」は AI 判定の客観化であり、process drift (前回 session review 最大 risk) に直接効く
- #352 codex-mvp-split は本 PBI 完了後に着手する前提

## Estimation

### Risks
- skill 追記が AI 行動に確実に反映されるかは LLM 解釈依存 (ソフトルール) → mitigation: docs 明示 + 例 + 判定基準数値化
- TASK-0112 例外ルールとの境界曖昧化 → mitigation: 相互参照のみで重複定義なし、本 PBI = plan 生成前のメトリクス検証、TASK-0112 = mode 自動補正
- skill 構造変更で既存 ai-dev-plan 動作 regression → mitigation: 追記のみ (additive)、既存 step を破壊しない

### Unknowns
- 既存 `.claude/skills/ai-dev-plan/` の正確な構造 → T-01 で調査
- skill / commands 配置の選択 (本 PBI 段階) → T-01 で決定

### Assumptions
- `ai-dev-plan` 等の skill が `.claude/skills/` または `.claude/commands/` 配下に存在
- Hardening Override 対象のため maintenance window 必須
