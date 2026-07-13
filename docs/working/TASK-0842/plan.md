---
task_id: TASK-0842
artifact_type: plan
schema_version: 1
status: draft
related_issue:
  - https://github.com/s977043/plangate/issues/842
  - https://github.com/s977043/plangate/issues/843
created_by: orchestrator
---

# EXECUTION PLAN — TASK-0842

> #842 governance: HO リスト二重管理の整合（B案 = ho-paths.md から HO-plugin を
> 削除し、plugin 同期の担保を既存 CI drift ゲートに一本化）。#843（#840 由来
> ファイルの plugin bundled 同期）を後段に含む。

## Goal

`plugin/plangate/**` に対する HO 判定の非対称（EH-3 素通り / ai-loop escalate）を
解消する。B案採用: `docs/ai/ai-loop/ho-paths.md` から HO-plugin を削除する差分を
**テキストで提案**（AI は同ファイルを編集しない）、担保一本化の記録先を確定し、
B案確定後に #843 の plugin 同期（sync スクリプト実行 → 同期 PR）まで実施する。

## Constraints / Non-goals

- **AI は `docs/ai/ai-loop/ho-paths.md` を Write/Edit しない**（HO-contract 自己登録。
  適用は Human のワンアクション）
- EH-3 正本（`.claude/rules/mode-classification.md` 9 カテゴリ）と実装
  （`scripts/hooks/check-plan-hash.sh`）は**変更しない**（A案不採用の帰結）
- Non-goals: EH-3 への `plugin/**` 追加（A案）/ 統一リスト新正本の作成（issue #842
  論点3 — B案採用により HO-plugin 削除 + 記録で十分と判断、下記 D-2）/
  plugin 配下の同期以外の編集 / ai-loop Phase 2 機能追加

## 確認事項（B-1）

質問なし。判断材料はすべて確定済み:
- B案採用推奨は Human が 2026-07-13 に再確認済み（「HOOK設定を強化しない」= A案不採用）
- 最終確定は本 plan の同期 C-3（Human・autonomous 不可）で行う

## アプローチ比較（B-2）

| 案 | 内容 | 評価 |
|----|------|------|
| **B案（採用候補）** | ho-paths.md から HO-plugin を削除。plugin の担保は CI（`sync-plugin-plangate.yml` drift 検出 → 同期 PR → Human C-4 merge）に一本化。**ただし現行 CI trigger は同期元を未カバー（R-001）のため、trigger paths 拡張（`docs/ai/ai-loop/**` / `scripts/ai-loop/**` 追加）を Human 適用差分として本 PBI に含める** | ✅ 正本（`.claude/**`）は EH-3 で保護済み。派生成果物は CI-owned で PR 経由が強制される。sync スクリプトによる正規同期を阻害しない |
| A案 | EH-3 9 カテゴリに `plugin/**` を追加 | ❌ 正規 sync 実行も block され #843 系の同期が恒久 Human 手動化。二重ゲートの限界便益小 |
| C案（参考） | 統一リスト正本を新設し EH-3 / ho-paths 双方が参照 | ❌ 本件の乖離は HO-plugin 1 項目のみ。新正本の維持コストが便益を上回る（V2 候補として handoff に記録） |

## Metrics Evidence（事前メトリクス検証）

| 項目 | 実数 | AI 見積もり | ratio | 判定 |
|------|------|------------|-------|------|
| ho-paths.md 内 HO-plugin 言及箇所 | 3（L42 表行 / L59 分類定義 / L95 パターン例） | 3（pbi-input AC-1） | 1.0 | 採用 |
| `docs/ai/ai-loop/` 配下で plugin 言及ファイル | 1（ho-paths.md のみ。`grep -rln "plugin" docs/ai/ai-loop/` = 1・2026-07-13 実測） | 1 | 1.0 | 採用 |

concept.md の plugin 言及ゼロ（pbi-input Known Fact）を再実測で確認済み。

## Approach Overview

1. ho-paths.md の HO-plugin 3 箇所削除の unified diff を本 plan に確定記載（AC-1）
2. `docs/ai/ai-loop/` 横断 grep の実行ログを evidence に保存（AC-2）
3. EH-3 側の無変更を diff で確認（AC-3）
4. 担保一本化の記録は **ho-paths.md「関連ドキュメント」節への追記**（Human 適用差分に
   含める）+ `asset-inventory.md` への 1 行追記（AI-owned）で行う（AC-4 / D-2）
5. Human が ho-paths.md へ差分適用（🚩 Human ゲート）
6. #843: `sync-plugin-plangate.sh --dry-run` 再確認 → 本番実行 → 同期 PR 作成
   （merge は Human C-4）（AC-5）

### 提案差分 1: ho-paths.md（AC-1 正本 / Human 適用用）

> **形式注記（R-004）**: 以下は `git apply` 可能な unified diff ではなく
> **手動編集用の変更指示**（hunk header は説明用）。対象行（origin/main
> 5ad2056 時点）: 削除 = L42（HO パス一覧表の HO-plugin 行）/ L59（分類定義表の
> HO-plugin 行）/ L95（パターンマッチ例の plugin 行）、追加 = L126（関連
> ドキュメント節末尾）の後に注記ブロック。適用後検証:
> `grep -c "HO-plugin" docs/ai/ai-loop/ho-paths.md` = 0。

```diff
--- a/docs/ai/ai-loop/ho-paths.md
+++ b/docs/ai/ai-loop/ho-paths.md
@@ HO パス一覧
 | `.github/workflows/*.yaml` | HO-ci | CI/CD 定義（yaml 拡張子）。AI 直接編集不可 |
-| `plugin/plangate/**` | HO-plugin | プラグイン本体。AI 直接編集不可 |
 | `docs/ai/ai-loop/ho-paths.md` | HO-contract | HO 境界定義そのもの（本ファイル）。Arbiter が自己の判定基準を自己改変しないための機械層（原則 1 参照） |
@@ 分類定義
 | HO-approval | 人間承認トークン・provenance 証跡 |
-| HO-plugin | CLI プラグイン本体 |
@@ パターンマッチの例
 docs/working/TASK-0123/approvals/c3.json → HO-approval
-plugin/plangate/index.js    → HO-plugin
@@ 関連ドキュメント
 - `docs/ai/autonomous-degraded-gates-spec.md` — `NoHardeningOverridePath` 条件の定義元
+
+> **注（#842 B案確定）**: `plugin/plangate/**` は HO 対象外。正本 `.claude/**` 等は
+> EH-3 9 カテゴリで保護済みであり、派生成果物 `plugin/plangate/**` の整合は
+> CI-owned（`.github/workflows/sync-plugin-plangate.yml` の drift 検出 → 同期 PR →
+> Human C-4 merge）に一本化する。
```

### 提案差分 2: sync-plugin-plangate.yml trigger 拡張（R-001 対応 / Human 適用用）

> **形式注記**: 手動編集用の変更指示。`.github/workflows/*.yml` は HO-ci
> （EH-3 9 カテゴリ）のため AI 編集不可 — Human が適用する。
> 対象: `.github/workflows/sync-plugin-plangate.yml` の `on.push.paths`
> （現行 L10-12）に 2 行追加。

```diff
     paths:
       - '.claude/**'
       - '.agents/skills/**'
       - 'CHANGELOG.md'
+      - 'docs/ai/ai-loop/**'
+      - 'scripts/ai-loop/**'
```

**根拠（R-001 実測）**: sync スクリプトは `docs/ai/ai-loop/`（思想・仕様層抜粋）と
`scripts/ai-loop/`（arbiter.py 等）も plugin bundled resources へ同期する
（`scripts/sync-plugin-plangate.sh` L151-152）が、現行 trigger はこれらを
含まないため、#840 型（scripts/ai-loop のみの変更）は main マージ後も同期 PR が
起動しない。この拡張が適用されるまで「CI-owned 一本化」（AC-4）は**成立しない**
（未適用の間は AI が手動で sync スクリプトを実行して補完する — S6 と同型）。

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 |
|------|------|--------|-------|------|-----|
| S1 | 横断 grep 実行ログを evidence 保存（AC-2） | `evidence/verification/grep-plugin-ai-loop.log` | agent | 低 | |
| S2 | EH-3 無変更確認（AC-3） | `evidence/verification/eh3-no-change.log`（`git diff` 空） | agent | 低 | |
| S3 | 本 plan の C-1 セルフレビュー → C-2 反映 → 同期 C-3 | review-self.md / review-external.md / c3.json | agent→human | — | 🚩 C-3（high-risk・Human 必須） |
| S4 | Human が **PR-1 ブランチ上で** 提案差分 1（ho-paths.md）+ 提案差分 2（yml trigger 拡張）を commit | HO 差分 2 commit（PR-1 に含める） | **human** | 中（適用漏れ） | 🚩 適用確認（AI が grep / yml paths で検証） |
| S5 | asset-inventory.md へ担保一本化の 1 行追記（AC-4）→ **PR-1 作成**（plan 成果物 + asset-inventory + S4 の HO 差分を含む） | PR-1（merge は Human C-4） | agent | 低 | 🚩 C-4（PR-1） |
| S6 | #843: `sync-plugin-plangate.sh --dry-run` → 本番実行 → **PR-2（同期 PR）作成**（AC-5） | PR-2（merge は Human C-4） | agent | 中（drift 混在） | 🚩 C-4（PR-2） |

順序: S1/S2 並列可 → S3（C-3）→ S4（Human・PR-1 ブランチ上）→ S5（PR-1）→ S6（PR-2）。

**PR 構成（R-002 確定）**: main 直接 commit 禁止のため、Human 適用も PR 経由とする。
- **PR-1**（本タスクブランチ `docs/task-0842-plan`）: plan 系成果物（AI commit）+
  asset-inventory.md 追記（AI commit）+ **提案差分 1・2 の Human commit** を同一
  ブランチに載せ、C-4 で HO 変更ごと承認・merge する
- **PR-2**（#843 同期）: sync スクリプトが作る同期ブランチ。PR-1 merge 後に実施
  （trigger 拡張適用後なら CI 自動起動でも可。手動実行時は AI が PR 作成まで）

（Unknowns の実施順序: **S4/PR-1 を先行**とする — HO 判定の非対称と CI trigger の
欠落を先に解消してから同期する方が、以後の同期が CI-owned で回るため）

## Files / Components to Touch

- `docs/working/TASK-0842/**`（plan 系成果物・evidence）— AI
- `docs/ai/ai-loop/asset-inventory.md` — AI（S5・1 行追記）
- `docs/ai/ai-loop/ho-paths.md` — **Human のみ**（S4・提案差分 1 適用）
- `.github/workflows/sync-plugin-plangate.yml` — **Human のみ**（S4・提案差分 2 適用。HO-ci）
- `plugin/plangate/**` — sync スクリプト経由のみ（S6・直接編集なし）
- 変更しない: `.claude/rules/mode-classification.md` / `scripts/hooks/check-plan-hash.sh`

## Testing Strategy

- Unit/Integration: 対象外（コード変更なし。doc + 運用ゲートの変更）
- Verification Automation:
  - AC-2: `grep -rn "plugin" docs/ai/ai-loop/` ログ保存
  - AC-3（R-003 修正）: 2 段確認 — ①ブランチ全差分
    `git diff --stat origin/main...HEAD -- .claude/rules/mode-classification.md scripts/hooks/check-plan-hash.sh` が空
    ②未コミット差分 `git diff --stat -- <同パス>` が空（両方をログ保存）
  - S4 事後検証: `grep -c "HO-plugin" docs/ai/ai-loop/ho-paths.md` = 0 かつ
    `grep -c "ai-loop" .github/workflows/sync-plugin-plangate.yml` ≥ 2
  - AC-5: `sh scripts/sync-plugin-plangate.sh --dry-run` の差分ゼロ化（同期 PR merge 後）

## Risks & Mitigations（内容 / 検証手段 / Fallback）

1. **削除漏れ**（3 箇所散在）/ 検証: S4 後に `grep -c "HO-plugin"` = 0 / Fallback: 残存箇所の追加差分を再提示
2. **提案→適用のタイムラグ**で「提案済み未適用」状態 / 検証: todo.md の Human タスク + handoff で未適用を明示追跡（settings タスクロック方式に準拠）/ Fallback: 未適用のまま S6 に進む場合は ai-loop run が escalate される（安全側なので実害なし）
3. **#843 同期 PR に #840 由来以外の drift が混在** / 検証: dry-run 出力で差分の出自を区別し PR 本文に明記 / Fallback: レビューで区別困難なら drift を分割 PR 化
4. **plan 時点の dry-run 状態が main push で変化** / 検証: S6 直前に `--dry-run` 再実行 / Fallback: 差分再確認の上で PR 本文を更新

## Questions / Unknowns

- なし（実施順序の Unknown は S4 先行で確定済み — Work Breakdown 参照）

## Mode判定

**モード**: high-risk

**判定根拠**:
- 変更ファイル数: 実編集 2（asset-inventory.md + plugin 同期）→ light 相当だが
- 変更種別: 承認境界（HO 判定基準）の定義変更 → 例外ルール「承認境界周辺の変更 → 最低でも高」に該当（ho-paths.md は 9 カテゴリ外だが安全側で該当扱い）
- **最終判定**: high-risk（pbi-input Assumptions と一致）

**lite_eligible**: false（high-risk のため。Standard・同期 C-3 固定・autonomous APPROVE 不可）
