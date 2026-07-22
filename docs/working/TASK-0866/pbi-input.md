# PBI INPUT PACKAGE — TASK-0866

> Issue: [#866](https://github.com/s977043/plangate/issues/866)（P1 / bug）
> 作成: 2026-07-20（調査リフレッシュ・main c0461bb 裏取り済み。事前調査から構造変化を反映）

## Context / Why

`intent-classifier` / `skill-policy-router` スキルの正本宣言と実体が不整合。事前調査（2026-07-19）の「三つ巴（.claude 新版 / .agents 旧版 / plugin 旧版）」は最新 main で**構造が変化**しており、実測で以下を確認:

- **四つ巴**（`.codex/skills/` 追加）: `.claude` = **新版8分類**（intent 153 行・`exploratory`×3）/ `.agents` = `.codex` = `plugin` = **旧版7分類**（150 行・`exploratory`×0・byte 同一）
- **宣言テキストは統一済み**: 全 8 ファイル（4 箇所×2 スキル）の L8 が「正本: `.claude/skills/…`」で一致（三つ巴の宣言矛盾は解消）
- **真の矛盾は三者不整合**: 宣言(`.claude`) vs **sync 実体(`.agents/skills`)** vs 新版コンテンツ(`.claude`)。`sync-plugin-plangate.sh` L19 `SKILLS_DIR=.agents/skills` が旧版を読むため、`.claude` の新版8分類が distribution（plugin/.codex）へ届かない
- **回帰原因**: #862 が orphan SKILL.md を `.agents/skills` へ移設し sync 正本化した際、`.claude` の新版8分類を持ち越さず旧版7分類を seed した

## What（Scope）

### In scope

1. **新版8分類の distribution 反映**: `.agents/skills/{intent-classifier,skill-policy-router}/SKILL.md` を旧7→新8分類（`exploratory`/WF-07 advisory/breakdown-gate 参照）へ更新
2. **正本宣言と sync 実体の整合**: 全 8 ファイルの L8 正本宣言を sync 実体（`.agents/skills` = sync 元）と整合する表記へ是正（#862 準拠: 「`.agents/skills` = sync 正本、`.claude`/`.codex`/`plugin` はミラー」）
3. **sync 再生成**: `plugin/plangate/skills/` と `.codex/skills/` を sync スクリプトで byte 追従（手編集しない）
4. **drift 0 の確認**: `sync-plugin-plangate.sh --dry-run` が no changes
5. **相対リンク切れの是正（issue コメント 2026-07-19 で scope 追加）**: `.agents/skills/{intent-classifier,skill-policy-router}/SKILL.md` の `../../rules/mode-classification.md` は `.agents/rules/` 不存在でリンク切れ（実測: `.agents/rules/` は No such file）。gemini 提案の `../../../plugin/plangate/rules/` は sync 先（plugin）で逆に切れる。**正本/sync 先の両方で成立するリンク方針**（例: リンクをやめてコードスパンで正本パスを記す）を設計・適用
6. **subagent-dispatch のバッククォート表示バグ是正（issue コメントで scope 追加）**: `.agents/skills/subagent-dispatch/SKILL.md` L67/74 付近の 4 バッククォートブロック内の不要なエスケープ（`` \`\`\`mermaid `` 等）が GitHub レンダリングで文字表示される（plugin 版と共通の既存欠陥）→ 修正 + sync 追従

### Out of scope

- sync 元を `.agents → .claude` へ変更する案（#862 の「sync/drift check 担保下へ」意図と衝突 → C-3 論点として記録・本 PBI では採らない前提）
- 8→7 以外の分類体系の再設計

## 受入基準（#866 issue + 調査反映）

- AC-1: 4 箇所すべての intent-classifier が「8 分類」宣言・`exploratory` 行・exploratory→WF-07 advisory・breakdown-gate 参照を含む
- AC-2: 4 箇所すべての skill-policy-router の intent enum に `exploratory` を含み GatePolicy 表に exploratory 行を持つ
- AC-3: **ファイルペア単位**で sync 先 byte 同一を検証（ディレクトリ全体比較でなく各 `skills/<name>/SKILL.md`）:
  - `cmp -s .agents/skills/<name>/SKILL.md .codex/skills/<name>/SKILL.md` = SAME（`install-plangate-skills-to-codex.sh` 経路）
  - `cmp -s .agents/skills/<name>/SKILL.md plugin/plangate/skills/<name>/SKILL.md` = SAME（`sync-plugin-plangate.sh` 経路）
  - `.claude/skills/<name>/SKILL.md` は runtime コピー。**In scope 5 のリンク方針適用後は `.agents` と byte 同一**（リンクをコードスパン化して相対パス依存を除去する場合）。リンク相対パス差を残す設計を選ぶ場合のみ、その差分が唯一の許容差（`diff` がリンク行に限定）— どちらを採るかは C-3 論点
  - （`<name>` = intent-classifier / skill-policy-router の 2 スキル各々）
- AC-4: 全 4 コピーの **L8 正本宣言テキストが完全一致**（`.agents/skills` = sync 元と整合。AC-3 の `.claude` 差分許容は L8 を含まない = L8 は全コピー同一）
- AC-5: `sync-plugin-plangate.sh --dry-run` が no changes（drift なし）
- AC-6: **8→7 分類の勝敗を明示**: 勝者 = 新版8分類（`exploratory` 含む）。根拠 = WF-00 正本 `00_intent_intake.md` が「Intent 8 分類」+ exploratory→WF-07 セクションを持つこと・#493 で追加され `.claude` に生存・旧7分類は #862 の sync 移設時の回帰
- AC-7（In scope 5 対応）: `.agents/skills/{intent-classifier,skill-policy-router}/SKILL.md` の `mode-classification.md` 参照が**正本（`.agents/skills`）と sync 先（`plugin`/`.codex`）の両方でリンク切れ 0**（到達可能 or コードスパン化）
- AC-8（In scope 6 対応）: `subagent-dispatch/SKILL.md` の 4 バッククォートブロックが GitHub レンダリングで文字化けしない（不要なエスケープが除去され、4 箇所 sync 後も一致）

## Notes from Refinement（調査で確定した設計方針）

- **touch ファイル数**: 本体 SKILL 8（intent-classifier / skill-policy-router × 4 箇所）= 手編集 4（`.agents`×2 新版反映+宣言是正 / `.claude`×2 宣言是正のみ）+ sync 再生成 4（`plugin`×2 / `.codex`×2）。**加えて In scope 5,6（リンク/バッククォート是正）で `subagent-dispatch` 系が加算**（`.agents`/`.claude`/`.codex`/`plugin` × 該当スキル数）。確定 8 + 追加分は plan で確定
- **HO 該当なし**（Hardening Override 対象外）: `.claude/skills/**` は HO 列挙外、`.agents/**` / `.codex/**` は clean、`plugin/plangate/skills/*.md` は sync 派生で明示 clean（`ho-paths.md` L62/L99/L132-136）。sync スクリプト（`plugin/plangate/scripts/**` は HO）自体は touch しない。**autonomous APPROVE 可否は Mode に従う**（下記 Assumptions: high-risk = autonomous 不可・人間 C-3 必須）
- **新版=正の傍証**: WF-00 正本の「Intent 8 分類」+ exploratory→WF-07 セクション実在 / WF-07（`07_exploratory_debug.md`）実在 / breakdown-gate 4 箇所 byte 同一（#802 新設）
- **git 履歴**: `a0e65f2 (#493)` exploratory 追加（.claude 8 分類化）→ `f164dee (#862)` .agents へ旧版 seed で distribution が 8→7 回帰

## Estimation Evidence

### Risks

| リスク | 検証手段 | Fallback |
|--------|---------|----------|
| sync 元の方向（.agents 維持 vs .claude 変更）で設計が割れる | C-3 で #862 準拠（.agents 維持）を確認 | .claude 正本化は別 PBI（sync スクリプト HO 変更を伴う）|
| sync 再生成で他スキルの drift を巻き込む | sync 前後で対象 2 スキル以外の diff 0 を確認 | 対象スキルのみ手動 byte 同期 |

### Unknowns

- `.codex/skills` の sync 元（`install-plangate-skills-to-codex.sh` の `SOURCE_DIR=.agents/skills`）も同時に追従するか → plan で sync 手順を確定

### Assumptions

- touch 8 ファイル（本体 SKILL）+ リンク/バッククォート是正で subagent-dispatch 等が加わり得る・全 .md・非 HO
- **Mode 見込み: high-risk**（`mode-classification.md` 定量基準: 変更ファイル数 6-15 = 高。「定量と定性の高い方を最終 Mode」）。**autonomous APPROVE 不可・人間 C-3 必須**（working-context.md の autonomous マトリクスで high-risk は ❌）。定性はスキル正本の byte 同一 sync・新規設計なしで軽微だが、定量が高いため安全側で high-risk 固定。8→7 の勝敗（新版8分類が正）は AC-6 で明示
