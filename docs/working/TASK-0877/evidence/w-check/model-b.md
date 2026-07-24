# W チェック Model B（逆方向・adversarial） — TASK-0877 run-027 round 1

> 実行: 2026-07-25 / 独立サブエージェント（Model A の結論は未提示）
> 対象: `scripts/sync-plugin-plangate.sh` / `tests/extras/ta-26-plugin-sync.sh` / `tests/run-tests.sh`（target_sha: ee9a1b5）

verdict: approve
reject_category: none
理由: touch 対象 3 ファイルは HO 表（check-plan-hash.sh L124-134）に不在で、exit code 契約の変更先も CI 2 job（yml L51/L76）と ta-26 / ta-54（いずれも `|| true` 吸収）の 4 経路のみ、実 repo は全 label で stale=0 のため誤発火経路が実測で塞がっており、変更はコード限定で revert 可能・権限/秘密情報・データ移行に非接触。override フラグは発火時も現行挙動へ戻すだけで新たな権限を与えず、CI `env:` 非設定 + 解除ログ必須（AC-2/AC-9）で濫用が可観測になる。

## 指摘（minor 2 件）と disposition

| 指摘 | disposition |
|------|------------|
| 論点 B の「実行時は旧式と厳密に等価」は **README 対称化（R-108）を入れると成立しない**。旧式は実質 `stale > S_old + R`、新式は `stale > S_old − R` で **発火側（安全側）へ 2R 件ずれる** | **採用・是正済み**（plan 論点 B を「README が両側に無い場合のみ厳密等価。実 repo では安全側へ最大 2 件ずれる」へ訂正。#861 は削除しすぎを防ぐ装置であり早期発火は意図と同方向のため採用） |
| R-211 で採用とした `PLANGATE_ALLOW_MASS_DELETE` の unset リスト追加が plan 本文に無い | **採用・是正済み**（plan 論点 C と Files to Touch に「`PG_HARNESS_SOURCED` と `PLANGATE_ALLOW_MASS_DELETE` の 2 つを unset リストへ追加」を明記。実測で L15 は明示列挙でありワイルドカードでないことを確認） |
