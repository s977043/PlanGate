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

> #842 governance: HO リスト二重管理の整合。
> **改訂 2（2026-07-13 / B'案・C-3 再承認対象）**: W チェック（敵対的レビュー）で
> B案の前提「CI が plugin を担保する」が**成立していない**ことが実測判明（R-005〜
> R-009）。**限定 HO + CI 強化**に再設計する。

## Goal

`plugin/plangate/**` に対する HO 判定の非対称（EH-3 素通り / ai-loop escalate）を、
**担保を純減させずに**解消する。

**B'案**:
1. plugin 配下を 2 分し、**同期元のない独自実体（実行系）だけを限定 HO
   （`HO-plugin-dist`）として残す** — `scripts/**`（配布実行スクリプト）/
   `hooks/**`（配布 hook = 安全装置）/ `**/agents/*.yaml`（配布 agent 設定）/
   `.claude-plugin/**`（plugin manifest）
2. **派生成果物（sync が生成する 87 件）は HO 対象外**にする（A案の弊害＝正規 sync の
   block を回避）。担保は **PR 段階の drift check job**（`sync-plugin-plangate.sh
   --dry-run` が差分ゼロを検証）で行う
3. sync CI の **trigger を完全化**（`plugin/plangate/**` / `docs/workflows/ai-loop/**` /
   `scripts/_ai_loop_link_rewrite.py` / `scripts/sync-plugin-plangate.sh` を追加）
4. #843 の plugin 同期（sync スクリプト実行 → PR）を実施

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
| **B'案（採用 / 改訂 2）** | plugin を 2 分。**独自実体（実行系）のみ限定 HO**、**派生成果物は HO 外 + PR drift check**、trigger 完全化 | ✅ 担保を純減させずに非対称を解消。正規 sync を阻害しない。discovery.py の `"plugin"` 語彙とも整合が回復（R-008 解消） |
| ~~B案（改訂 1・却下）~~ | ho-paths.md から HO-plugin を**全削除**し、担保を CI drift ゲートに一本化 | ❌ **前提が成立しない**（実測）。①CI trigger に `plugin/**` が無く直接変更で発火しない（R-005）②同期元のない独自実体 47 件は drift 比較対象が無く**どのゲートにも守られない**（R-006・`install-plangate-skills.sh` / 配布 hook を含みサプライチェーン面の実害）→ **担保の純減** |
| A案 | EH-3 9 カテゴリに `plugin/**` を追加 | ❌ 正規 sync 実行も block され #843 系の同期が恒久 Human 手動化。二重ゲートの限界便益小 |
| C案（参考） | 統一リスト正本を新設し EH-3 / ho-paths 双方が参照 | ❌ 新正本の維持コストが便益を上回る（V2 候補として handoff に記録） |

### plugin 配下の 2 分（実測・2026-07-13）

| 区分 | 対象 | 件数 | 担保 |
|------|------|------|------|
| **独自実体（限定 HO）** | `plugin/plangate/scripts/**` / `hooks/**` / `**/agents/*.yaml` / `.claude-plugin/**` | 39 | **`HO-plugin-dist`**（AI 直接編集不可）。sync が生成しないため drift 比較が構造的に不可能 |
| **派生成果物（HO 外）** | `skills/*/SKILL.md` / `references/` / `agents/*.md` / `rules/` / `commands/` | 87 | **PR 段階の drift check job**（`--dry-run` 差分ゼロ検証）+ main push の同期 PR |
| 残存リスク | orphan SKILL.md 7 件（`.agents/skills/` に正本なし） | 7 | sync 対象外のため drift 検出不能。限定 HO にも含めない（同期対象 SKILL.md と同一パターンになり sync を阻害）→ **follow-up issue で正本化** |

## Metrics Evidence（事前メトリクス検証）

| 項目 | 実数 | AI 見積もり | ratio | 判定 |
|------|------|------------|-------|------|
| ho-paths.md 内 HO-plugin 言及箇所 | 3（L42 表行 / L59 分類定義 / L95 パターン例） | 3（pbi-input AC-1） | 1.0 | 採用 |
| `docs/ai/ai-loop/` 配下で plugin 言及ファイル | 1（ho-paths.md のみ。`grep -rln "plugin" docs/ai/ai-loop/` = 1・2026-07-13 実測） | 1 | 1.0 | 採用 |

concept.md の plugin 言及ゼロ（pbi-input Known Fact）を再実測で確認済み。

## Approach Overview

**Phase 1（適用済み・commit bdbc58e / 35f15c5）**:
1. ho-paths.md から HO-plugin を削除（提案差分 1・Human 適用済み）
2. sync yml trigger に `docs/ai/ai-loop/**` / `scripts/ai-loop/**` を追加（提案差分 2・適用済み）
3. `asset-inventory.md` へ担保記録（AC-4）/ evidence 保存（AC-2・AC-3）

**Phase 2（B'案・本改訂で追加）**:
4. **限定 HO の復活**: ho-paths.md に `HO-plugin-dist` 4 パターンを追加（提案差分 3・Human 適用）
5. **CI 完全化**: trigger に `plugin/plangate/**` 他 3 パスを追加 + **PR drift check job** を新設
   （提案差分 4・Human 適用。`.github/workflows/*.yml` は HO-ci）
6. `plan-review-readiness-gate.md` の Forbidden zones を限定 HO に更新（提案差分 5・Human 適用）
7. `test_arbiter.py` / `asset-inventory.md` を限定 HO に追従（AI-owned）
8. #843: sync 実行 → PR-2（AC-5）

### 提案差分 3: ho-paths.md に限定 HO を追加（R-006 / Human 適用用）

> 手動編集用の変更指示。ho-paths.md は HO-contract のため AI 編集不可。
> **HO パス一覧**の表に 4 行、**分類定義**に 1 行、**パターンマッチの例**に 2 行を追加する。

```diff
@@ HO パス一覧（.github/workflows/*.yaml の行の後に追加）
 | `.github/workflows/*.yaml` | HO-ci | CI/CD 定義（yaml 拡張子）。AI 直接編集不可 |
+| `plugin/plangate/scripts/**` | HO-plugin-dist | 配布実行スクリプト（利用者が実行）。同期元が無く drift 検出不能。サプライチェーン防護 |
+| `plugin/plangate/hooks/**` | HO-plugin-dist | 配布 hook（安全装置本体）。同期元が無く drift 検出不能 |
+| `plugin/plangate/**/agents/*.yaml` | HO-plugin-dist | 配布 agent 設定。同期元が無く drift 検出不能 |
+| `plugin/plangate/.claude-plugin/**` | HO-plugin-dist | plugin manifest（version 行以外に同期元が無い） |
 | `docs/ai/ai-loop/ho-paths.md` | HO-contract | HO 境界定義そのもの（本ファイル）...

@@ 分類定義（HO-approval の行の後に追加）
 | HO-approval | 人間承認トークン・provenance 証跡 |
+| HO-plugin-dist | plugin 配布物のうち**同期元を持たない独自実体**（実行系）。派生成果物（sync が生成するもの）は対象外 |

@@ パターンマッチの例
 docs/working/TASK-0123/approvals/c3.json → HO-approval
+plugin/plangate/scripts/install-plangate-skills.sh → HO-plugin-dist
+plugin/plangate/skills/ai-loop-cycle/references/ho-paths.md → clean（派生成果物・PR drift check で担保）
```

**根拠（R-006 実測）**: plugin 配下 136 件のうち 47 件は sync スクリプトがコピーしない
独自実体。`grep -c "install-plangate-skills" scripts/sync-plugin-plangate.sh` = **0**、
`arbiter.boundary_check(['plugin/plangate/scripts/install-plangate-skills.sh'])` →
`('clean', [])`。HO 全削除では**どのゲートにも守られない**（担保の純減）。

### 提案差分 4: sync yml の trigger 完全化 + PR drift check job（R-005 / R-007 / Human 適用用）

> 手動編集用の変更指示。`.github/workflows/sync-plugin-plangate.yml`（HO-ci）。

```diff
@@ on.push.paths
     paths:
       - '.claude/**'
       - '.agents/skills/**'
       - 'CHANGELOG.md'
       - 'docs/ai/ai-loop/**'
       - 'scripts/ai-loop/**'
+      - 'plugin/plangate/**'
+      - 'docs/workflows/ai-loop/**'
+      - 'scripts/_ai_loop_link_rewrite.py'
+      - 'scripts/sync-plugin-plangate.sh'
+  pull_request:
+    paths:
+      - '.claude/**'
+      - '.agents/skills/**'
+      - 'docs/ai/ai-loop/**'
+      - 'docs/workflows/ai-loop/**'
+      - 'scripts/ai-loop/**'
+      - 'plugin/plangate/**'
+      - 'scripts/_ai_loop_link_rewrite.py'
+      - 'scripts/sync-plugin-plangate.sh'

@@ jobs（新規 job を追加）
+  drift-check:
+    # PR 段階で plugin と正本の drift を検出する（R-005）。
+    # push 後の同期 PR だけでは「マージされてから気づく」構造のため。
+    if: github.event_name == 'pull_request'
+    permissions:
+      contents: read
+    runs-on: ubuntu-latest
+    timeout-minutes: 10
+    steps:
+      - name: Checkout
+        uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0 # v7
+      - name: Verify plugin is in sync with sources
+        run: |
+          sh scripts/sync-plugin-plangate.sh
+          if ! git diff --quiet -- plugin/plangate/; then
+            echo "::error::plugin/plangate/ が正本と乖離しています。sh scripts/sync-plugin-plangate.sh を実行してコミットしてください。"
+            git diff --stat -- plugin/plangate/
+            exit 1
+          fi
+          echo "plugin/plangate/ is in sync."
```

**根拠（R-005 実測）**: 現行 trigger に `plugin/plangate/**` が無く、plugin を直接
書き換える PR では drift 検出が**一度も起動しない**。PR 段階の drift check により、
派生成果物（87 件）の改変は必ず CI で検出される。

### 提案差分 5: plan-review-readiness-gate.md の Forbidden zones 更新（R-009 / Human 適用用）

> `docs/ai/*.md`（トップレベル）は HO-contract のため AI 編集不可。

```diff
@@ Forbidden zones の例（L84 付近）
-  plugin/plangate/**
+  plugin/plangate/scripts/**   # 限定 HO（HO-plugin-dist）。派生成果物は対象外
```

### 提案差分 1: ho-paths.md（AC-1 / **適用済み** commit bdbc58e）

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

### 提案差分 2: sync-plugin-plangate.yml trigger 拡張（R-001 / **適用済み** commit bdbc58e）

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
| **S7**（B'案） | W チェック指摘を review-external に集約（R-005〜R-009）→ plan/todo/test-cases へ 1 回確定反映 → 簡易 C-1 → **C-3 再承認** | 改訂 plan / 新 c3.json | agent→human | — | 🚩 **C-3 再承認**（scope 変更・Human 必須） |
| **S8**（B'案） | Human が **PR-1 ブランチ上で** 提案差分 3（限定 HO）+ 4（trigger 完全化 + PR drift check job）+ 5（readiness-gate）を commit | HO 差分 3 commit | **human** | 中 | 🚩 適用確認（AI が arbiter 実行で検証） |
| **S9**（B'案） | `test_arbiter.py` / `asset-inventory.md` を限定 HO に追従（ho_pattern_count 17 → 21・`scripts/**` を touches-HO 期待に）+ plugin bundled 再同期 | 追従 commit | agent | 中 | |
| **S10**（B'案） | PR drift check job の実効性を PR 上で確認（CI green）+ 全 CLI テスト再実行 | CI 結果 | agent | 低 | 🚩 C-4（PR-1） |

順序: S1/S2 → S3（C-3）→ S4（Human 適用）→ S5（PR-1）→ **S7（C-3 再承認）→ S8（Human 適用）→ S9 → S10 → C-4** → S6（PR-2）。

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
- `plugin/plangate/**` — sync スクリプト経由のみ（S6・S9・直接編集なし）
- `scripts/ai-loop/test_arbiter.py` — AI（S9・限定 HO 追従）
- `docs/ai/plan-review-readiness-gate.md` — **Human のみ**（S8・提案差分 5。HO-contract）
- 変更しない: `.claude/rules/mode-classification.md` / `scripts/hooks/check-plan-hash.sh`

## 追加受入基準（B'案 / 改訂 2）

- [ ] **AC-8**: `docs/ai/ai-loop/ho-paths.md` に `HO-plugin-dist` 4 パターン
      （`plugin/plangate/scripts/**` / `hooks/**` / `**/agents/*.yaml` /
      `.claude-plugin/**`）が追加され、`arbiter.boundary_check(['plugin/plangate/scripts/install-plangate-skills.sh'])`
      が `touches-HO` を返す（R-006）
- [ ] **AC-9**: `arbiter.boundary_check(['plugin/plangate/skills/ai-loop-cycle/references/ho-paths.md'])`
      が **`clean`** を返す（派生成果物は HO 外＝正規 sync を阻害しない）
- [ ] **AC-10**: sync yml の trigger に `plugin/plangate/**` / `docs/workflows/ai-loop/**` /
      `scripts/_ai_loop_link_rewrite.py` / `scripts/sync-plugin-plangate.sh` が追加され、
      **PR 段階の drift check job** が存在して PR #860 上で PASS する（R-005 / R-007）
- [ ] **AC-11**: `docs/ai/plan-review-readiness-gate.md` の Forbidden zones が限定 HO に
      更新されている（R-009）
- [ ] **AC-12**: `python3 scripts/ai-loop/test_arbiter.py` と全 CLI テスト（`sh tests/run-tests.sh`）が
      PASS し、`sh scripts/sync-plugin-plangate.sh --dry-run` が差分ゼロ

## Testing Strategy

- Unit/Integration: `scripts/ai-loop/test_arbiter.py`（限定 HO の boundary 判定）+ 全 CLI テスト
- Verification Automation:
  - AC-2: `grep -rn "plugin" docs/ai/ai-loop/` ログ保存
  - AC-3（R-003 修正）: 2 段確認 — ①ブランチ全差分
    `git diff --stat origin/main...HEAD -- .claude/rules/mode-classification.md scripts/hooks/check-plan-hash.sh` が空
    ②未コミット差分 `git diff --stat -- <同パス>` が空（両方をログ保存）
  - S4 事後検証: `grep -c "HO-plugin" docs/ai/ai-loop/ho-paths.md` = 0
  - **S8 事後検証（AC-8/AC-9）**: `python3 -c "...arbiter.boundary_check([...])"` で
    `scripts/install-plangate-skills.sh` → `touches-HO` / `references/ho-paths.md` → `clean`
  - **AC-10**: PR #860 の CI で drift check job が green
  - AC-5: `sh scripts/sync-plugin-plangate.sh --dry-run` の差分ゼロ

## Risks & Mitigations（内容 / 検証手段 / Fallback）

1. **削除漏れ**（3 箇所散在）/ 検証: S4 後に `grep -c "HO-plugin"` = 0 / Fallback: 残存箇所の追加差分を再提示
2. **提案→適用のタイムラグ**で「提案済み未適用」状態 / 検証: todo.md の Human タスク + handoff で未適用を明示追跡 / Fallback: 未適用の間は ai-loop run が escalate（安全側）
3. **#843 同期 PR に #840 由来以外の drift が混在** / 検証: dry-run 出力で差分の出自を区別し PR 本文に明記 / Fallback: 分割 PR 化
4. **plan 時点の dry-run 状態が main push で変化** / 検証: S6 直前に `--dry-run` 再実行 / Fallback: 差分再確認の上 PR 本文を更新
5. **【B'案】限定 HO のパターンが広すぎて正規 sync を block する** / 検証: S8 後に AC-9（派生成果物 → `clean`）と `sh scripts/sync-plugin-plangate.sh`（実行成功）を確認 / Fallback: パターンを絞り込んだ差分を再提示
6. **【B'案】PR drift check job が既存 PR を軒並み fail させる** / 検証: PR #860 上で実際に green になることを確認（AC-10）/ Fallback: job を `continue-on-error` で導入し警告のみにする段階導入
7. **【B'案】orphan SKILL.md 7 件は限定 HO にも drift check にも掛からない**（既知の残存リスク）/ 検証: なし（構造的に検出不能）/ Fallback: `.agents/skills/` に正本を立てる follow-up issue で解消

## Questions / Unknowns

- なし（B'案の実現可能性は arbiter の `**` パターン対応を実測確認済み）

## Mode判定

**モード**: high-risk

**判定根拠**:
- 変更種別: 承認境界（HO 判定基準）の定義変更 + CI ゲート新設 → 例外ルール「承認境界周辺の変更 → 最低でも高」
- **改訂 2 で影響拡大**: 限定 HO 復活（arbiter 判定変更）+ PR drift check job 新設（全 PR に影響）
- **最終判定**: high-risk（**C-3 再承認が必要** — scope 変更 / `lite_eligible=false`・autonomous 不可）

**lite_eligible**: false（high-risk のため。Standard・同期 C-3 固定・autonomous APPROVE 不可）
