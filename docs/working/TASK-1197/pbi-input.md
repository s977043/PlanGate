# PBI INPUT PACKAGE: no-task セッションでも ai-loop の前提 plan.md を作成可能にする（#1197）

> **状態: Human 確定（2026-11-07、C-3 CONDITIONAL）**。受入基準とスコープはこの内容で確定した。
> 基準: `origin/main` = `9445df17`（2026-11-06 実測）。

## Context / Why

Human 決定「基本的に開発は ai-loop-workflow を使って開発をして欲しい」（`docs/workflows/ai-loop/rollout-policy.md` に verbatim 記録）が、`PLANGATE_HOOK_TASK` 未設定のセッションでは実行できない。ai-loop-cycle の前提は C-1 PASS であり、C-1 の対象 plan.md を EH-3 が no-task で block するためである。

CLI（Bash）経路なら plan.md を書けるが、それは #1104 の穴を通る迂回である。

Human の方針: **案 B を採用候補とする**。案 A（起動導線の明記）では TASK ごとの再起動が人の作業として残るため。条件は、当該 TASK の C-3 承認トークンが未発行かつ plan.md の新規作成のときだけ許可し、既存 plan.md の改変と承認後の改変は block のままとすること。

- Discovery depth: expanded
- PBI author: ai（Human 方針に基づく下書き）
- Application timing: follow_up
- Target layer: harness（EH-3 は承認境界の enforcement）

## What（Scope）

### In scope

- EH-3 no-task 分岐への、plan.md 新規作成に限定した許可経路の追加（**適用は Human**。HO のため）
- その patch 文書、検証つき適用スクリプト、回帰テスト、変異注入
- rollout-policy.md への起動条件・no-task 挙動・迂回禁止の明記
- hook-enforcement.md の EH-3 記述更新

### Out of scope

- #1104（Bash 経路のガード配線）
- EH-3 の plan.md block の単純撤去
- Codex / Cursor 橋渡しの TASK 自動導出の変更（実測した非対称は #1642）
- TASK 文脈ありで別 TASK の plan.md を編集できる既存挙動、および非 STRICT の hash 不一致が WARNING で通る既存挙動の是正（実測済み・#1641）

## 受入基準（issue の AC を正本として転記）

- [ ] AC-1: 採用案が決まり、`rollout-policy.md` または `ai-loop-cycle/SKILL.md` に起動条件が明記されている
- [ ] AC-2: no-task セッションで `/ai-loop-cycle` を起動した場合の挙動が定義されている（即 escalate / エラー終了 / 起動導線の提示）
- [ ] AC-3（案 B を採る場合）: C-3 承認トークン存在下では従来どおり block されることを変異注入で実証する
- [ ] AC-4: 「CLI 経路なら書ける」ことが迂回として使われないよう明示的に扱われている（禁止の明文化 / ガード配線 / 許可条件の明示のいずれか）

issue の案 B 安全条件（新規作成のみ・トークン未発行に限る）は AC-3 と同格の設計制約として plan.md に展開する。

## Notes from Refinement

- 不採用案と理由は plan.md の Approach Comparison を参照（repo 配置時は decision-log へ構造化する）。
- 本是正は carve-out（`docs/workflows/ai-loop/**`）と HO（`scripts/hooks/*.sh`）に触れるため ai-loop-cycle では裁定できない。Human 経路固定。

## Estimation Evidence

### Risks

- 承認境界の緩和であり、判定漏れは承認済み plan の改変に直結しうる。
- 「新規作成」は hook 入力だけでは判定できず、FS・git・worktree の状態に依存する（TOCTOU は残る）。

### Unknowns

plan.md の Questions / Unknowns を参照。最大の未決は「作成後の C-1 修正をどう通すか」である。

### Assumptions

- 承認の実効性は plan_hash 照合が担い、本 hook は早期 block の 1 層である。
- EH-3 の適用は Human がスクリプトで行う。
