# STATUS — TASK-0874（RunEvidence 契約 / issue #874）

## モード判定結果

**critical**（承認境界周辺 + 契約層の新設。`lite_eligible=false` / 同期 C-3 固定）

## 全体構成

| PR | branch | 状態 |
|----|--------|------|
| PR-1（予定） | `feat/task-0874-exec` | exec 実装中（未 push・未 PR） |

## フェーズ履歴

| 日時 | フェーズ | 内容 |
|------|---------|------|
| 2026-08-02 | B / C-1 / C-2 | plan / todo / test-cases 生成、C-1 是正、C-2 22 件反映 |
| 2026-08-04 | C-3 | **APPROVED**（`approvals/c3.json`・Unknowns 12 件の判断確定。todo「T-1 完了記録」が正本） |
| 2026-08-04 | exec 前半 | T-1 〜 T-11（契約 doc / schema / 受理器 / producer の RED） |
| 2026-08-04 | exec 後半 | T-12 〜 T-36（producer GREEN / legacy 互換 / privacy / c3-prime 接続 / adapter / fixture / ta-60 / 配布同期リスト） |
| 2026-08-05 09:00 | T-37 | 統合担当が `sh scripts/sync-plugin-plangate.sh` を実行し `plugin/` を commit（`9ffe144`） |
| 2026-08-05 10:00 | T-38 / T-39 | 敵対レビュー R1 / R2 実施（R2 = major 5 / minor 4）。**レポート artifact は evidence/ 未配置**のため todo 上は未了 |
| 2026-08-05 12:30 | R2 反映 | MJ-3 / MJ-5 を code へ反映（`52bd791`）。MJ-1 / MJ-2 / MJ-4 / MN-1 〜 MN-4 を working context へ反映 |
| 2026-08-05 12:45 | T-40 / T-41 | 65 TC 対応表（機械 63 / 手動 2）+ handoff 必須 6 要素を完成 |

## C-3 Gate: APPROVED

`docs/working/TASK-0874/approvals/c3.json`（**未 commit の承認記録**。commit に含めない）。

## 実装状態（exec 後半）

| commit | 内容 |
|--------|------|
| `23b16e5` | producer 本体（T-12 〜 T-18 / T-25 / T-26）+ 契約 doc 是正 |
| `ecebfcd` | legacy record 4 分類（T-19 〜 T-21） |
| `c23b099` | privacy の producer 側強制（T-22 / T-23） |
| `a911308` | 下流 consumer adapter（T-28 〜 T-31） |
| `2730594` | golden fixture 10 件 + `ta-60` + 配布同期リスト（T-32 / T-33 / T-35 / T-36 / T-24） |
| `9ffe144` | T-37 plugin 同期（統合担当） |
| `52bd791` | **R2 major 2 件**（MJ-3 AC-12 未検査の証跡化 / MJ-5 実 corpus 件数の脱ハードコード）+ K-10（ta-60 失敗経路の unbound variable） |

### 変更ファイル一覧（`origin/main` からの差分）

| ファイル | 種別 |
|---------|------|
| `docs/workflows/ai-loop/run-evidence-contract.md` | 新設（前半）+ 実装で顕在化した 6 点を是正 |
| `docs/schemas/run-evidence.schema.json` | 新設（前半・変更なし） |
| `docs/workflows/ai-loop/c3-prime-contract.md` | §7 に #874 consumer 節を **additive 追記のみ** |
| `scripts/ai-loop/run_evidence.py` | 新設（producer + legacy 分類 + privacy + adapter） |
| `scripts/ai-loop/test_run_evidence.py` | 新設（78 tests） |
| `scripts/ai-loop/run_evidence_verify.py` | 新設（前半・変更なし） |
| `scripts/ai-loop/test_run_evidence_verify.py` | 新設（前半・30 tests） |
| `tests/fixtures/run-evidence/fx-01 〜 fx-10.json` | golden fixture 10 件 |
| `tests/extras/ta-60-run-evidence.sh` | 新設（CI 導線 + EH-8 実走） |
| `scripts/sync-plugin-plangate.sh` | 2 箇所へ新規 4 本を追加（24 → 28） |

## 計画からの変更点

1. **`ta-59` → `ta-60`**（plan / todo / test-cases の記載は `ta-59` だが #976 で使用済み）
2. **`harness_version` を注入値に追加**（契約 §2 と §3-2 の内部矛盾を §2 優先で解消）
3. **`--pr-number` は cross-check 専用**（注入値だけで `repair_rounds` を実値化しない）
4. **`BLOCKED` の `unavailable` は 8 件**（test-cases.md の「7 件」は `quality_metrics` の従属を未計上）
5. **`ci_outcomes` に `reasons` を混ぜない**（`observation` へ回す）
6. **§6-5 の矛盾を確定**（`decision` 値のみ供給元扱い + 後段束縛の producer 側再検証）

詳細な根拠は `todo.md` の「T-12 〜 T-36 完了記録」を参照。

## V 系ステップ進捗

| ステップ | 状態 |
|---------|------|
| L-0（lint） | ✅ `npx markdownlint-cli2` 0 issues（変更 md 全件） |
| V-1（受け入れ検査） | ✅ 65 TC 対応表を handoff §5-bis に記載（**機械 63 / 手動 2**・SKIP 0）+ 不変 7 ファイル差分 0 行 |
| V-2 / V-3 | ✅ 敵対レビュー R1 / R2 実施済み（R2 の major 5 / minor 4 を反映済み）。⚠️ レポート artifact は `evidence/` へ未配置 |
| V-4（リリース前チェック） | ⬜ 未（critical モードのため PR 前に統合担当が実施） |

## 残タスク

- [x] T-37: `sh scripts/sync-plugin-plangate.sh` 実行 → `plugin/` を commit（`9ffe144`。R2 反映で producer / 契約 doc を変更したため**再実行済み**・`git diff --quiet -- plugin/` clean）
- [ ] T-38 / T-39: 敵対レビュー R1 / R2 — **レビュー自体は実施済み**（R2 指摘は反映済み）。**残りはレポート artifact を `docs/working/TASK-0874/evidence/` へ配置すること**（完了判定が artifact の存在のため）
- [x] T-40: 65 TC 対応表（handoff §5-bis）+ 不変差分 0 の最終確認
- [x] T-41: handoff 必須 6 要素の完成（§1-bis 見直し前提 / §5-bis TC 対応表 / §6 内訳を含む）
- [ ] T-42: issue #874 への DoD コメント（**close 条件未達の明記が必須**）
- [ ] T-43: #870 への evidence link
- [ ] T-44: `schemas/` 昇格 PBI の予約起票

## 次セッション用プロンプト

> PlanGate TASK-0874（#874）の残作業を進める。worktree `plangate-wt-0874exec`・
> branch `feat/task-0874-exec`。**T-1 〜 T-41 は完了**（R2 敵対レビューの major 5 / minor 4 も反映済み・
> 詳細は `handoff.md` §7 の disposition 表）。残りは
> ① T-38 / T-39 の**レポート artifact を `docs/working/TASK-0874/evidence/` へ配置**して todo を閉じる
> ② T-42（issue #874 の DoD コメント・**close 条件未達**と **routing 実カバレッジ 0** の明記が必須）
> ③ T-43（#870 への evidence link）④ T-44（`schemas/` 昇格 PBI の予約起票）⑤ PR 作成 → C-4。
> `approvals/c3.json` は未 commit の承認記録なので `git add -A` を使わず名指し add する。
> `scripts/ai-loop/*.py` / `docs/workflows/ai-loop/*.md` を変更したら **sync 再実行が必須**。
> 検証は `python3 scripts/ai-loop/test_run_evidence.py`（**80 tests**）/
> `test_run_evidence_verify.py`（**32 tests**）/ `sh tests/run-tests.sh </dev/null`（**523 passed / 0 failed**）。

## 参照ファイル

- `docs/workflows/ai-loop/run-evidence-contract.md`（契約正本）
- `docs/schemas/run-evidence.schema.json`
- `docs/working/TASK-0874/{plan,todo,test-cases,review-self,review-external}.md`
- `docs/working/TASK-0874/handoff.md`
