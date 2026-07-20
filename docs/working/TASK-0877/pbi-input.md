# PBI INPUT PACKAGE — TASK-0877

> Issue: [#877](https://github.com/s977043/plangate/issues/877)（P1 / bug / area:workflow）
> 由来: #861 safety guard の未完部分 + #875 敵対的レビュー残件
> 作成: 2026-07-20（2026-07-20 調査リフレッシュ・main c0461bb 裏取り済みを反映）

## Context / Why

`scripts/sync-plugin-plangate.sh` の mass-delete safety guard（#861 由来）が **silent（WARN + `return 0`）** で、exit code を変えないまま copy 側で `changed=1` になるため、CI 自動 PR が生成され毎 run 発火し続ける恒久 drift リスクがある。#875 敵対的レビューで F1〜F5 が未反映と指摘された。

実測（2026-07-20・main c0461bb）:

- guard 実体: `sync-plugin-plangate.sh` L79-81（`if src*2 < dst then WARN; return 0`）— silent 経路が残存
- DELETE 正常系テスト（TC-09）は `tests/extras/ta-26-plugin-sync.sh` に**不在**（TC-08 = guard 発火側のみ）
- **全対象ファイルが非 HO**（`scripts/sync-plugin-plangate.sh` は `scripts/` 直下で `scripts/hooks/*.sh` に非該当）

## What（Scope）

### In scope（#877 F1〜F5）

- **F1（major）**: guard の silent `return 0` を **fail-closed 化** — `guard_fired` を global フラグに立て、`sync_dir` ループ後の script 終端で集約 **exit 3**。`PLANGATE_ALLOW_MASS_DELETE=1` override を追加。**CI yml は touch 不要**（drift-check / sync job とも生 `sh` 実行で exit 3 により job 自動 fail = HO 回避成立）
- **F2（minor）**: stale 数ベースのカウントへ（dry-run/実行の判定一致）。該当 L68-82
- **F3（minor）**: standalone 判定を `PG_HARNESS_SOURCED` へ（`run-tests.sh` の source 直前に設定 + `ta-26` L9 をそれ参照へ）
- **F4（minor）**: `ta-26` に **TC-09（DELETE 正常系）** 追加（src=2/stale=1 で削除実行・WARN 無を assert。TC-08 と同じ sandbox 構造）
- **F5（既知課題）**: 無ガード削除経路（references 3 経路: L141-149 / L290-291 / L320-321）へ guard 適用、**または別 issue 分離**（実装方針として採否を記録）

### Out of scope

- CI workflow（`.github/workflows/sync-plugin-plangate.yml`）の変更（F1 設計で不要）
- guard の共通関数 `_mass_delete_guard` 化の是非（F5 の実装判断に委ねる）

## 受入基準（#877 issue + 調査反映）

- AC-1: guard 発火時に script が **非ゼロ終了（exit 3）** し、CI job が自動 fail する（silent 廃止）
- AC-2: `PLANGATE_ALLOW_MASS_DELETE=1` で override でき、意図的な mass-delete を通せる
- AC-3: stale カウントが dry-run と実行で一致する（F2）
- AC-4: standalone 実行と harness source 実行を `PG_HARNESS_SOURCED` で判別（F3）
- AC-5: DELETE 正常系（TC-09）が負側テストとして固定（F4）
- AC-6: references 3 経路の無ガード削除の扱い（F5 適用 or 別 issue 分離）を明示記録
- AC-7: `.github/workflows/*.yml` を touch しない（HO 回避）

## Notes from Refinement（調査で確定した設計方針）

- **HO 該当なし**: 対象 3 ファイル（`sync-plugin-plangate.sh` / `ta-26-plugin-sync.sh` / `run-tests.sh`）は全て非 HO → `lite_eligible` 判定は通常どおり・Hardening Override 不発
- **Mode 見込み**: standard（lite=false）〜 high。#875 経緯（安全性 guard の再是正）から**人間 C-3 推奨**
- **exec 経路**: `scripts/` 編集に EH-1 が plan+TASK 文脈を要求 → `PLANGATE_HOOK_TASK=TASK-0877` 専用セッションでメイン直実装が正規（worker 委譲不可・token 不要）
- **仕様調整の論点**: dry-run の exit 3 化は TC-03 の「dry-run exit 0」前提と衝突しうる → plan で dry-run と実行の exit 方針を確定する

## Estimation Evidence

### Risks

| リスク | 検証手段 | Fallback |
|--------|---------|----------|
| dry-run exit 3 化が既存 TC-03 前提と衝突 | ta-26 の TC-03 を実測・plan で exit 方針確定 | dry-run は exit 0 維持・実行のみ exit 3 |
| F5 を本 issue に含めると scope 肥大 | references 3 経路の変更行数を見積もり | F5 を別 issue 分離（採否を AC-6 で記録） |

### Unknowns

- guard 集約 exit 3 が POSIX sh の subshell/関数境界で正しく伝播するか（`local` 不可環境）→ plan で実装検証

### Assumptions

- touch は 3 ファイル・+40〜130 行の範囲（調査見積もり）
- CI yml touch 不要が成立（exit 3 で job 自動 fail）
