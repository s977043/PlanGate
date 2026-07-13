---
task_id: TASK-0842
artifact_type: test-cases
schema_version: 1
status: draft
created_by: orchestrator
---

# TEST CASES — TASK-0842

> コード変更なし（doc + 運用ゲート変更）のため、全ケース検証コマンド・目視突合で自動化。

## 受入基準 → テストケースマッピング

| AC | テストケース |
|----|------------|
| AC-1 | TC-1 |
| AC-2 | TC-2 |
| AC-3 | TC-3 |
| AC-4 | TC-4 |
| AC-5 | TC-5, TC-6 |
| AC-6 | TC-7 |
| AC-7 | TC-8 |

## テストケース一覧

| ID | 前提条件 | 入力 / 手順 | 期待出力 | 種別 |
|----|---------|------------|---------|------|
| TC-1 | plan.md 生成済み | plan.md「提案差分」節を確認。かつ TASK-0842 内の git log で ho-paths.md への AI コミットが無いこと | unified diff が HO-plugin 3 箇所（表行 L42 / 分類定義 L59 / パターン例 L95）の削除を含む。AI による ho-paths.md 編集コミットなし | 検証（目視+git log） |
| TC-2 | — | `grep -rn "plugin" docs/ai/ai-loop/` | ヒットは ho-paths.md のみ（適用前 3 箇所）。ログが evidence/verification/ に保存済み | 自動 |
| TC-3 | — | ①`git diff --stat origin/main...HEAD -- .claude/rules/mode-classification.md scripts/hooks/check-plan-hash.sh` ②同パスの未コミット差分（R-003 対応・2 段） | 両方とも出力空（変更なし）。ログ保存済み | 自動 |
| TC-4 | H-2 適用後 | ho-paths.md 関連ドキュメント節の注記 + asset-inventory.md の追記行 + sync-plugin-plangate.yml の trigger paths（`docs/ai/ai-loop/**` / `scripts/ai-loop/**`）を確認 | CI-owned 一本化の記録 + trigger 拡張が存在 | 検証 |
| TC-5 | H-2 適用後 | `sh scripts/sync-plugin-plangate.sh --dry-run` | 差分一覧が出力され、#840 由来（arbiter.py / test_arbiter.py / test_metrics.py 等）と他 drift の出自が記録される | 自動 |
| TC-6 | T-6 実行後 | `gh pr view <sync-pr>` | 同期 PR が open、本文に差分出自の内訳あり、merge は未実施（Human C-4 待ち） | 自動 |
| TC-7 | todo.md 生成済み | todo.md の H-1 を確認 | C-3 が Human タスクとして明示され autonomous 対象外の記載あり | 目視 |
| TC-8 | pbi-input.md | トレーサビリティ表（AC ↔ #842/#843 論点）を確認 | 全 AC が論点に対応付く | 目視 |

## Edge cases

| ID | ケース | 期待動作 |
|----|-------|---------|
| EC-1 | H-2 適用で 3 箇所のうち削除漏れが発生 | T-4 の `grep -c "HO-plugin"` ≠ 0 で検出 → 残存箇所の追加差分を再提示 |
| EC-2 | T-5 dry-run の差分が plan 時点（2026-07-12 実測）から変化 | dry-run ログに最新差分を記録し PR 本文に反映（Risks 4 の手順どおり） |
| EC-3 | H-2 未適用のまま ai-loop run が `plugin/**` に触れる | 従来どおり escalate（安全側・実害なし）。handoff で未適用状態を明示追跡 |
| EC-4 | 同期 PR に意図しない大量 drift が混在 | 出自区別が困難なら分割 PR 化（Fallback 3） |
| EC-5 | 提案差分 2（yml trigger 拡張）が未適用のまま ai-loop 系のみの変更が main に入る | CI 同期 PR は起動しない（R-001 の既知ギャップ）→ AI が手動 sync 実行で補完し、handoff で未適用を追跡 |

---

## B'案 追加テストケース（改訂 2）

| ID | 前提条件 | 入力 / 手順 | 期待出力 | 種別 |
|----|---------|------------|---------|------|
| TC-9 (AC-8) | H-5 適用後 | `python3 -c "import sys;sys.path.insert(0,'scripts/ai-loop');import arbiter;print(arbiter.boundary_check(['plugin/plangate/scripts/install-plangate-skills.sh']))"` | `('touches-HO', [...])` — 限定 HO が効いている | 自動 |
| TC-10 (AC-9) | H-5 適用後 | 同上で `plugin/plangate/skills/ai-loop-cycle/references/ho-paths.md` | `('clean', [])` — 派生成果物は HO 外（正規 sync を阻害しない） | 自動 |
| TC-11 (AC-10) | H-5 適用後 | PR #860 の CI | **drift check job** が存在し PASS | 自動（CI） |
| TC-12 (AC-10) | H-5 適用後 | `grep -c "plugin/plangate\|docs/workflows/ai-loop\|_ai_loop_link_rewrite\|sync-plugin-plangate.sh" .github/workflows/sync-plugin-plangate.yml` | trigger に 4 パスすべて存在 | 自動 |
| TC-13 (AC-11) | H-5 適用後 | `grep -n "plugin/plangate" docs/ai/plan-review-readiness-gate.md` | 限定 HO パス（`scripts/**`）に更新済み | 目視 |
| TC-14 (AC-12) | T-12/T-14 後 | `python3 scripts/ai-loop/test_arbiter.py` / `sh tests/run-tests.sh` / `sh scripts/sync-plugin-plangate.sh --dry-run` | 全 PASS + 差分ゼロ | 自動 |

### 追加 Edge case

| ID | ケース | 期待動作 |
|----|-------|---------|
| EC-6 | 限定 HO パターンが広すぎて sync スクリプトの書き込みまで block | TC-10 で検出（派生成果物が touches-HO になったら FAIL）→ パターン絞り込みの差分を再提示 |
| EC-7 | PR drift check job が既存 PR を軒並み fail させる | PR #860 上で green を確認（TC-11）。fail する場合は `continue-on-error` で段階導入 |
| EC-8 | orphan SKILL.md（7 件）が改変される | **検出不能**（既知の残存リスク）。follow-up issue（T-16）で `.agents/skills/` 正本化により解消 |
