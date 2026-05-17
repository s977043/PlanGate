# PBI INPUT — TASK-0100 / Plan Hash Utility 共有化（#193 follow-up / reuse H-1）

## Context / Why
/simplify reuse レビュー + Codex 相談 + 実証検証で確定: plan_hash 抽出/生成が
check-plan-hash.sh(shell EH-3 正本) / metrics_collector / keep-rate /
context-engine の 4 箇所分散。Python 3 消費者は _read_c3_plan_hash を同名同実装
ローカル重複。承認境界（plan_hash 不一致=stale）に関わるため共有正本化する。

## What
- In: scripts/plan_hash_util.py（新規・strict json 正本）/ keep-rate.py /
  context-engine.py / metrics_collector.py を util へ差し替え /
  tests/extras/ta-11 + fixtures（EH-3 shell 整合契約テスト）
- Out: check-plan-hash.sh 実行経路変更（Non-goal・承認境界変更になる）/
  paths(M-2)共有化 / plan_hash 形式変更 / metrics schema 変更 / import 基盤再設計

## 受入基準
- AC1: scripts/plan_hash_util.py に current_plan_hash / current_plan_hash_prefixed /
  recorded_plan_hash（strict json）を集約
- AC2: keep-rate/context-engine/metrics_collector が util を使用（ローカル重複除去）
- AC3: 3 消費者の出力が main 版と完全等価（in-place 検証）
- AC4: EH-3 shell ↔ python util の契約テスト（正常/注入/無=parity、不正JSON=
  python strict 拒否の意図的差異を仕様固定）が PASS
- AC5: 全テストスイート回帰なし（run-tests.sh）

## Notes
実証検証（/tmp/phtest）で確定: 正常/注入/重複キーは shell≡python、不正JSON
（末尾カンマ）のみ python(strict json)が拒否＝**不正 c3.json を承認記録に
信用しない安全側**。Codex 案「shell を正に合わせる」を補正し python strict を
正本とした。check-plan-hash.sh は不触（c4 ハードニング sed→python -c は V2）。

## Estimation
Risks: 承認境界の意味ズレ（緩和: 契約テストで parity+意図的差異を機械固定）/
等価性崩れ（緩和: 3 消費者 in-place 等価検証）/ Unknowns: なし
