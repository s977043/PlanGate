# PBI INPUT — TASK-0101 / #277 scripts パス定数共有モジュール化（reuse M-2）

## Context / Why
#277（reuse M-2）: 11 script が REPO root + docs/working + schemas を各自定義、
命名も REPO/REPO_ROOT・WORKING/WORKING_DIR・parent.parent/parents[1] 混在。
EPIC #193 完遂・クローズで「EPIC 混入懸念」消滅 → focused PBI 化可能。
Codex 相談で「今・最小リファクタとして実装」推奨（YAGNI 拡張は入れない）。

## What
- In: scripts/_paths.py 新規（固定定数 REPO_ROOT/SCRIPTS_DIR/WORKING_DIR/
  SCHEMAS_DIR）/ 11 script を _paths 参照へ（既存変数名は alias 維持＝差分最小）
- Out: env override / 設定注入 / package 化(__init__.py) / shell・hooks 巻込 /
  plan_hash_util（path 定数なし＝対象外）/ 振る舞い変更

## 受入基準
- AC1: scripts/_paths.py に REPO_ROOT/SCRIPTS_DIR/WORKING_DIR/SCHEMAS_DIR 固定定数
- AC2: 11 script（context-engine/keep-rate/reporting/baseline-snapshot/
  metrics_collector/eval-runner/doctor_check/metrics_reporter/metrics_timeline/
  schema_mapping/validate-schemas）が _paths 参照・ローカル重複定義除去
- AC3: 全テストスイート（run-tests.sh）回帰なし（全 PASS）
- AC4: 主要 CLI/出力が behavior-preserving（smoke + metrics plan_hash 等価）
- AC5: shell/hooks/bin 無変更（承認境界・対象外を侵さない）

## Notes
Codex 助言: 固定定数のみ・override/env/package化なし・既存 sys.path.insert
慣習に整合・plan_hash_util 無理に依存させない。alias import で既存変数名温存
→ 下流参照不変＝behavior-preserving by construction。

## Estimation
Risks: import 経路（scripts/ が sys.path 必要）→ bootstrap 1行で両実行経路担保
+ 全スイート/smoke で機械検証 / Unknowns: なし
