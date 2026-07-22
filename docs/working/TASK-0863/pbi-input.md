# PBI INPUT PACKAGE — TASK-0863

> Issue: [#863](https://github.com/s977043/plangate/issues/863)（bug / priority:P1 / area:cli）
> 作成: 2026-07-14 / 鮮度是正: 2026-07-22（#862 CLOSED = orphan 正本移設後の main で全実測を再取得）
>
> #863: CLI 依存スキルの graceful degradation 明記 + `bin/plangate` 表記の
> PATH 解決形式への統一 + README 依存列挙の是正。

## Context / Why

PR #860（#842）の検証過程で、plugin 配布物の CLI 依存に 2 つの不整合を実測確認した:

1. **README の依存列挙が不足**: `plugin/plangate/README.md` L36 は CLI 依存
   スキル/コマンドを 7 個列挙するが、実測（`grep -rln "bin/plangate"
   plugin/plangate/`・2026-07-22 main 再取得）では **26 ファイル**が参照する。
   内訳: SKILL.md **9 本** + コマンド 1 本 + agents 定義 2 本
   （setup-coordinator / workflow-conductor）+ rules 2 本 + README 2 本 +
   ai-loop-cycle 同梱物 10 本（references 5 + scripts 5）
2. **PATH を通しても字義どおりでは動かない**: README の対処法は
   `export PATH="$HOME/plangate/bin:$PATH"` だが、スキル本文の呼び出しは全て
   `bin/plangate <cmd>` の**相対パス形式**（実測・スキル正本+複製の SKILL.md 合算:
   `bin/plangate exec` ×7 / `bin/plangate validate` ×6 / `bin/plangate doctor` ×6 /
   `bin/plangate review` ×5 / `bin/plangate resume` ×5 等）。PATH 解決される
   コマンド名は `plangate` であり、導入先リポジトリの cwd に `bin/plangate` は
   存在しないため、plugin 単体導入環境でスキル記載を字義どおり実行すると失敗する

「CLI 依存スキルを plugin から外す」案は検討の上**不採用**（2026-07-14
オーガナイザー評価・ユーザー合意）: CLI 依存スキルは PlanGate の中核価値
（ゲートワークフロー本体）であり、外すと「ゲートの無い PlanGate plugin」になる。
段階的導入ガイド（plugin 単体 → CLI 追加）の導線とも衝突し、sync スクリプトへの
除外リスト追加は新たな drift 面を作る（#842 と同型のリスク）。

**前提の更新（2026-07-19 / #862 CLOSED）**: issue 起票時に orphan だった
`intent-classifier` / `skill-policy-router` は PR #865（f164dee）で正本が
`.agents/skills/` へ移設され、sync / drift check の担保下に入った。本 PBI の
対象スキル正本は **`.agents/skills/` の CLI 参照 SKILL.md 9 本**（旧記述の
「.agents 7 本 + .claude 3 本 = 10 本」を置き換える）。`.claude/skills/` 側の
複製 3 本（plangate-setup / intent-classifier / skill-policy-router）は
正本と整合させる。

## What — Scope

### In scope

1. **CLI 依存スキル正本への degrade 節の追加**（各 SKILL.md に 1 節）:
   - 対象（AI 編集可・非 HO）: `.agents/skills/{ai-dev-plan,ai-dev-exec,ai-dev-verify,plan-review-gate,working-context,local-exec-handoff,plangate-setup,intent-classifier,skill-policy-router}/SKILL.md`（**9 本**・2026-07-22 実測の CLI 参照 SKILL.md 全数）
   - 内容: 「`plangate` CLI 未導入時: 機械検証（validate / doctor / metrics 等）は
     スキップし、手動チェックリストで代替する。ゲートの厳密な強制（EH-3 /
     plan_hash / presence gate）には CLI + hooks の導入が必要」の定型 1 節
2. **呼び出し表記の統一**: スキル正本 9 本内の `bin/plangate <cmd>` →
   `plangate <cmd>`（PATH 解決形式）。PlanGate リポジトリ自身での実行を説明する
   文脈のみ `bin/plangate`（相対）を残してよいが、その場合は
   「リポジトリルートで実行」を明記
3. **`.claude/skills/` 複製 3 本の整合**: `plangate-setup` /
   `intent-classifier` / `skill-policy-router` を正本（`.agents/skills/`）の
   degrade 節・表記統一と一致させる（整合方向は plan で確定。下記 Risks 参照）
4. **README 是正**: `plugin/plangate/README.md` の依存列挙を実測
   （スキル 9 + コマンド 1 + agents 2）に更新し、「スキル内の表記は
   `plangate`（PATH 解決）。リポジトリ内では `bin/plangate`」の注記を追加。
   README 本文は sync 対象外の独自実体（version 行のみ sync）のため直接編集
   （#842 B'案の限定 HO 4 パターン外 = AI 編集可）
5. **HO パスの差分提案**（AI は編集せず、patch 提案 → Human 適用）:
   `.claude/commands/plangate-setup.md` / `.claude/agents/setup-coordinator.md` /
   `.claude/agents/workflow-conductor.md`（EH-3 9 カテゴリ該当・実測
   `bin/plangate` 参照 3 + 6 + 2 = 11 箇所）
6. **plugin への反映**: `sh scripts/sync-plugin-plangate.sh` で派生分
   （.agents/skills 由来 9 本 + rules / commands / agents）を同期。
   #862 解消により旧「orphan 2 本の直接編集」は**不要**（sync が担保）

### Out of scope

- CLI 依存スキルの plugin 同梱除外（不採用案として記録のみ）
- `bin/plangate` CLI 自体の変更・plugin への CLI 同梱
- ai-loop-cycle 同梱物（references / scripts）・rules
  （mode-classification / working-context）内の `bin/plangate` 参照の表記統一
  （リポジトリ内実行・ai-loop ドメインの文脈。必要なら別 issue）
- `.claude/skills/` 側の新規 CLI 参照ファイル（`ai-loop-cycle` /
  `plan-quality-reviewer` / `plangate-working-discipline` テンプレート / README）
  の表記統一（同上・スキル配布 10 本のスコープ外）
- テスト（ta-26 の rm -rf 問題）— #861（CLOSED 済みだが本 PBI では扱わない）

## 受入基準

- [ ] AC-1: 対象スキル正本 9 本（`.agents/skills/`）すべてに degrade 節
      （CLI 未導入時の代替手順 + 「厳密な強制には CLI + hooks が必要」の明記）が
      追加されている
- [ ] AC-2: スキル正本 9 本 + `.claude/skills/` 複製 3 本の `bin/plangate` 参照が
      `plangate`（PATH 解決）に統一されている（リポジトリ内実行の文脈で残す場合は
      「リポジトリルートで実行」が併記されている）。
      `grep -rn "bin/plangate" .agents/skills/*/SKILL.md .claude/skills/{plangate-setup,intent-classifier,skill-policy-router}/SKILL.md`
      の残存が全て意図的注記であることをレビューで確認
- [ ] AC-3: `plugin/plangate/README.md` の依存列挙が実測（スキル 9 + コマンド 1 +
      agents 2）と一致し、`plangate` / `bin/plangate` の使い分け注記がある
- [ ] AC-4: HO パス 3 本（commands/plangate-setup.md・agents 2 本）の差分が
      `git apply --check` 済み patch として提案され、Human 適用後に plugin へ
      sync 反映されている
- [ ] AC-5: `sh scripts/sync-plugin-plangate.sh --dry-run` が差分ゼロ（正本と
      plugin の一致）。`.claude/skills/` 複製 3 本は `diff` で正本
      （`.agents/skills/`）と degrade 節・表記が整合
- [ ] AC-6: 全 CLI テスト（`sh tests/run-tests.sh`）PASS

### In scope ↔ AC 対応

| In scope | AC |
|----------|-----|
| 1. degrade 節追加（正本 9 本） | AC-1 |
| 2. 表記統一（正本 9 本） | AC-2 |
| 3. `.claude/skills/` 複製 3 本の整合 | AC-2 / AC-5 |
| 4. README 是正 | AC-3 |
| 5. HO パス 3 本の patch 提案 | AC-4 |
| 6. plugin sync 反映 | AC-4 / AC-5 / AC-6 |

## Notes from Refinement

- **2026-07-14 決定（ユーザー + オーガナイザー）**: 「plugin から CLI 依存分を
  外さない。同梱維持 + degrade 明記 + 表記統一」で進める
- **2026-07-19 前提更新**: #862 が PR #865 で CLOSED。orphan 2 本
  （intent-classifier / skill-policy-router）の正本は `.agents/skills/` に移設済み。
  issue 本文の「正本 `.agents/skills/` 7 本 + `.claude/skills/` 3 本」は
  「正本 `.agents/skills/` 9 本 + `.claude/skills/` 複製 3 本」に読み替える
- degrade 節は 9 本に同一定型を貼るのではなく、各スキルの機械検証ステップに
  対応した代替（例: `plangate validate` → plan/todo/test-cases の存在と frontmatter
  を目視確認）を 2〜4 行で書く
- テスト実行後は必ず `git status` を取り直してから add する（#861 の副作用対策・
  memory 済み）

## Estimation Evidence

**実測メトリクス（2026-07-22・main b632a91）**:

- 正本側 `bin/plangate` 参照: `.agents/skills/` SKILL.md **9 ファイル 39 箇所**、
  `.claude/skills/` 7 ファイル 12 箇所（うち本 PBI 対象の複製 3 本 = 7 箇所）、
  commands/agents **3 ファイル 11 箇所**（HO）
- 実編集ファイル数: 正本 9 + `.claude/skills/` 複製 3 + README 1 +
  HO patch 3（Human 適用）= **16**（うち AI 直接編集 13、Human 適用 3）。
  plugin sync 派生は別途 ~12（skills 9 + commands 1 + agents 2）で
  **PR 全体の変更ファイルは ~28**

### Risks

| リスク | 検証手段 | Fallback |
|--------|---------|----------|
| 表記統一が V-3/CI の文書整合チェック（ref-integrity 等）に引っかかる | L-0 / `sh tests/run-tests.sh` 全 PASS で検証 | 該当箇所のみ `bin/plangate` + 「リポジトリルートで実行」注記に戻す |
| `.claude/skills/` 複製 2 本（intent-classifier / skill-policy-router）が `.agents/skills/` 正本より新しい内容を含む（実測: exploratory intent・breakdown-gate 言及の差分）— 単純上書きで先行変更を失う | 整合作業前に `diff` で差分を全数確認し、内容差は正本へ逆反映してから整合 | 逆反映の要否判断を C-3 論点に上げ、Human 判断で確定 |
| HO patch 適用と AI 編集分の順序不整合 | AI 分を先に commit → patch 提案 → Human 適用 → sync の順（TASK-0842 H-2/H-5 と同型のフロー） | 順序が崩れた場合は sync --dry-run 差分で検出し再 sync |
| `plangate` への表記統一により、リポジトリ内で PATH 未設定の開発者が混乱 | README / スキル冒頭に使い分けを 1 行明記 | doctor / setup 導線に PATH 案内を追記（別 PBI 提案） |

### Unknowns

- degrade 節の粒度（定型 vs スキル個別）は plan で確定（推奨: 個別 2〜4 行）
- `.claude/skills/` 複製 3 本の整合方向（正本へ逆反映する差分の範囲）は
  plan で diff 全数を根拠に確定

### Assumptions

- **Mode: critical で確定**（`mode-classification.md` 定量基準の機械判定:
  変更ファイル数 = 実編集 16 + sync 派生 ~12 = **~28 で「16+ → 超高」が決定論**。
  受入基準数 6 → 高。定性: HO 対象パス（`.claude/commands/*.md` /
  `.claude/agents/*.md`）を含む「承認境界周辺の変更 → 最低 高」。
  判定ロジック「各軸の最大値を採用」で **critical 確定**）。
  Hardening Override 発火により `lite_eligible=false`・同期 C-3 固定・
  autonomous APPROVE 不可・V-4 リリース前チェック要
- plan.md の正式生成は EH-3 の制約により `PLANGATE_HOOK_TASK=TASK-0863` で
  起動したセッションで行う（起動時固定・実行中の切替不可）
