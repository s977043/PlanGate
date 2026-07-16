---
task_id: TASK-0842
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-07-13
author: orchestrator
v1_release: ""
---

# HANDOFF — TASK-0842

> #842 HO リスト二重管理の整合（**B'案** = 限定 HO + CI 強化）。PR-1 = #860（C-4 待ち）/ PR-2 = #843 同期（PR-1 merge 後）
>
> **改訂 2（2026-07-14）**: 敵対 W チェックで B案の前提崩壊（R-005〜R-009）が判明し B'案へ再設計。C-3 再承認済み（--force・新 plan_hash）。独自実体 = `HO-plugin-dist` 4 パターン / 派生成果物 = PR 段階 drift check job（AC-8〜AC-12 全 PASS・drift-check CI 実測 green）

## 1. 要件適合確認結果

| AC | 判定 | 根拠 |
|----|------|------|
| AC-1（ho-paths.md の HO-plugin 3 箇所削除差分を提示・AI は非編集） | **PASS** | plan.md「提案差分 1」に変更指示 + `git apply` 可能な patch を生成。ho-paths.md への唯一のコミットは Human の bdbc58e（`git log --format="%an"` = mine_take で確認）。AI 編集ゼロ |
| AC-2（`docs/ai/ai-loop/` 配下の plugin 言及の横断確認） | **PASS** | `evidence/verification/grep-plugin-ai-loop.log` — ヒットは ho-paths.md のみ（3 箇所）。concept.md 等は 0 件 |
| AC-3（EH-3 正本・実装が無変更） | **PASS** | `evidence/verification/eh3-no-change.log` — branch 全差分（`origin/main...HEAD`）・未コミット差分の 2 段確認とも空 |
| AC-4（plugin 担保の CI-owned 一本化を記録） | **PASS** | ho-paths.md 関連ドキュメント節の注記（Human 適用 bdbc58e）+ `asset-inventory.md` の専用節（35f15c5）。**加えて trigger 拡張により CI-owned が実際に成立**（R-001 対応） |
| AC-5（#843 同期の手順・完了条件が明記） | **PASS** | todo.md T-5（dry-run）→ T-6（本番 → PR-2）→ H-4（C-4 merge）。plan Risks 3/4 に drift 混在・状態変化の Fallback を記載 |
| AC-6（C-3 が同期 Human 承認・autonomous 対象外） | **PASS** | todo H-1 に明示。実際に `bin/plangate approve`（L1-L4 presence 検証）で Human が APPROVED を発行（c3.json） |
| AC-7（AC ↔ issue 論点のトレーサビリティ） | **PASS** | pbi-input.md のトレーサビリティ表 |

**総合: 7/7 PASS**

機械検証: `bin/plangate validate TASK-0842` = PASS（artifact 5/5・C-3 gate 3/3・plan_hash 一致）

## 2. 既知課題一覧

- **#843 の同期は未実施**（PR-1 merge 後に PR-2 として実施）。同期 PR には #840 由来（arbiter.py / test_arbiter.py / test_metrics.py）以外の drift（`rules/orchestrator-mode.md` / `rules/responsibility-classes.md` / `skills/ai-loop-cycle/references/decision-table.md` 等）が同時に含まれる見込み — PR 本文で出自を区別する
- **CI trigger 拡張の実効性は main merge 後にしか検証できない**（`on.push.branches: [main]` のため）。PR-1 merge 後の初回 `docs/ai/ai-loop/**` 変更で同期 PR が自動起動することを確認する
- plugin への配布反映は次回 version bump 時（plugin.json / CHANGELOG 経由）
- **plan.md の誤記（WONTFIX / gemini 指摘・PR #860）**: L32・L64 の「D-2」は「B-2（アプローチ比較）」の誤り。指摘は正当だが、plan.md は `c3.json` の plan_hash で保護された承認済み artifact であり、修正すると EH-3 が mismatch を検知し C-3 再承認が必要になる。内部参照 1 箇所の誤記に対しコストが見合わないため本 PR では修正せず、次回 plan 改訂時に是正する
- **テスト副作用（要 follow-up）**: `sh tests/run-tests.sh` の実行がリポジトリの `plugin/plangate/agents/*.md` 7 件を削除する事象を実測（本 PR の 592b615 に混入 → 4240718 で復元）。テストが repo の `plugin/` を直接書き換えている疑い。他 PR でも同種事故を起こしうるため独立 issue 化する

## 3. V2 候補

- **C案（統一 HO リスト正本）**: EH-3 9 カテゴリと ai-loop ho-paths を単一正本から参照する構造。今回は乖離が HO-plugin 1 項目のみで維持コストが便益を上回るため不採用としたが、HO 定義が今後増える場合は再検討に値する（#842 論点 3）
- ai-loop Phase 2（arbiter 本実装）での HO 判定の機械化（現状 ho-paths.md は human-readable な表 + 疑似コード）

## 4. 妥協点（採用しなかった選択肢と理由）

| 選択肢 | 不採用理由 |
|-------|-----------|
| **A案**（EH-3 9 カテゴリに `plugin/**` を追加） | 正規の sync スクリプト実行（`scripts/sync-plugin-plangate.sh` 経由の書き込み）まで block され、#843 型の同期作業が恒久的に Human 手動化する。正本側は既に EH-3 で保護済みであり、二重ゲートの限界便益が小さい一方コストが大きい |
| **C案**（統一リスト正本の新設） | 乖離は HO-plugin 1 項目のみ。新正本の維持コストが便益を上回る（V2 候補として保持） |

## 5. 引き継ぎ文書（5 分サマリ）

`plugin/plangate/**` は「EH-3 なら素通り、ai-loop なら escalate」という非対称な HO 扱いを受けていた。本 PBI は **B案 = plugin を HO 対象から外し、CI drift ゲートに担保を一本化**する判断を C-3（Human 同期承認）で確定し、その適用まで実施した。

最大の収穫は **C-2 外部レビュー（codex）が発見した構造的欠陥（R-001）**: sync CI の trigger paths が同期元（`docs/ai/ai-loop/**` / `scripts/ai-loop/**`）をカバーしておらず、「CI が担保する」という B案の前提自体が成立していなかった。これが #840 の未同期（#843）の構造原因でもある。trigger 拡張を Human 適用差分に追加して解消した。

HO パス（`ho-paths.md` = HO-contract / workflow yml = HO-ci）は AI 編集不可のため、AI は `git apply` 可能な patch を生成し、Human が適用（bdbc58e）。責務 4 分類（AI-owned = 設計・検証・patch 生成 / Human-owned = HO 適用・merge）どおりの分担で完了している。

**次の担当者へ**: PR #860 の C-4 merge 後、`sh scripts/sync-plugin-plangate.sh --dry-run` → 本番実行 → PR-2 作成（#843 クローズ）。以降の ai-loop 変更は CI が自動同期する。

## 6. テスト結果サマリ

| テスト | 結果 |
|-------|------|
| TC-1（提案差分の明示・AI 非編集） | PASS（`git log --format="%an"` で Human 適用を確認） |
| TC-2（横断 grep） | PASS（ヒットは ho-paths.md のみ） |
| TC-3（EH-3 無変更・2 段確認） | PASS（両段とも空） |
| TC-4（CI-owned 記録 + trigger 拡張） | PASS（`grep -c "HO-plugin"` = 0 / yml paths 2 行追加） |
| TC-5, TC-6（#843 同期） | **未実施**（PR-1 merge 後に実施） |
| TC-7（C-3 Human タスク明示） | PASS |
| TC-8（トレーサビリティ） | PASS |
| `bin/plangate validate TASK-0842` | PASS |

コード変更なし（doc + 運用ゲートの変更）のため unit/integration テストは対象外。

---

## 追補（B'案 / 2026-07-14）

### 追加 AC の結果

| AC | 判定 | 根拠 |
|----|------|------|
| AC-8（独自実体 → touches-HO） | **PASS** | `evidence/verification/limited-ho-boundary.log` — scripts/hooks/agents-yaml/manifest の 4 種すべて touches-HO |
| AC-9（派生成果物 → clean） | **PASS** | 同 log — bundled ho-paths.md / SKILL.md / agents/*.md / README すべて clean（正規 sync を阻害しない） |
| AC-10（trigger 完全化 + PR drift check） | **PASS** | drift-check job が PR #860 で実測 **success**（sync job は PR 上で正しく skipped） |
| AC-11（readiness-gate 更新） | **PASS** | Forbidden zones を限定 HO パスに更新（Human 適用 ff25506） |
| AC-12（テスト・同期整合） | **PASS** | test_arbiter 236 tests OK（count=21）/ CLI テスト 403 passed（FAIL 1 は既知 flaky TA-42 TC-04 — 単体 rc=1 正常・2 回目の観測）/ `--dry-run` 差分ゼロ |

### 新たに判明した既知課題（追加）

- **Actions の PR 作成が repo 設定で禁止されている**: main push の sync workflow は
  2026-07-13 の 2 run とも「GitHub Actions is not permitted to create or approve
  pull requests」で failure。**同期 PR の自動作成は従来から機能していない**（Human-owned:
  Settings → Actions → General → 「Allow GitHub Actions to create and approve pull
  requests」を ON にすると解消）。ただし本 PR の drift check job が「drift を持ち込む
  PR を merge 前に fail させる」ため、乖離の混入自体は防止される
- **TA-42 TC-04 の flaky**（2 回観測）: スイート内でのみ `status` の exit code 期待が
  崩れる。単体実行では正常。テスト間の状態汚染疑い — #861 と同根の可能性

### インシデント記録（本タスク中・すべて是正済み）

1. コミットが local main に乗る（三点照合 → ff-only 移送で復旧・push 前）
2. テスト実行が plugin agents 7 件を削除（origin/main から復元 4240718 → **#861 起票**）
3. **AI 生成 patch のヘッダ破損で HO ファイル 3 本が削除 commit に**（sed 置換順序ミス。
   `git apply --check` では検出不能だった。未 push のうちに reset+restore で復旧し、
   worktree 実編集 → `git diff` ネイティブ生成 + **clean worktree での実適用テスト**方式に変更）
4. 破損 patch の迷子ファイル掃除で正規 `workflows/*.yaml` を誤削除（`git restore` で即復旧）
