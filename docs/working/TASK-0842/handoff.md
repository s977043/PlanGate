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

> #842 HO リスト二重管理の整合（B案）。PR-1 = #860（C-4 待ち）/ PR-2 = #843 同期（PR-1 merge 後）

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
