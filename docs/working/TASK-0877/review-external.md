# TASK-0877 外部レビュー結果（C-2 / 2 レーン）

> レビュー日: 2026-07-25
> 対象: `plan.md` / `todo.md` / `test-cases.md`（plan_hash 確定前）
> 責務契約: [`.claude/rules/review-principles.md`](../../../.claude/rules/review-principles.md) §7-bis（2 レーン分離）
> 追記専用（append-only）。指摘は R-NNN で採番し、反映は **1 回だけ確定反映**する。

## レーン構成と判定

| レーン | 実行 | verdict | critical | major | minor | info |
|--------|------|---------|---------|-------|-------|------|
| 設計妥当性レーン（plan / todo / test-cases / issue） | Claude（独立サブエージェント） | **conditional** | 0 | 2 | 5 | 5 |
| コードベース整合レーン（既存コード・既存パターン） | Claude（独立サブエージェント） | **conditional** | **1** | 6 | 5 | 1 |

> Codex CLI レーンは本セッションでは起動していない（過去 3 セッション連続でハング事例あり）。
> 代替として 2 レーンとも独立 Claude サブエージェントで実施し、**相互の結論を見せない**独立性を担保した。
> 記録規約: [`docs/ai/external-reviewer-interface.md`](../../../docs/ai/external-reviewer-interface.md) §10。

## オーガナイザーによる一次ソース裏取り（受理前）

| 指摘 | 裏取り方法 | 結果 |
|------|-----------|------|
| R-101（TC-12 空振り） | scratchpad に sandbox を作り現行スクリプトを src=3 / stale=4 で dry-run / 実行の 2 回実測 | **CONFIRMED**: dry-run は guard 非発火で `WOULD DELETE` 4 件を予告、実行は `src=3 / dst=7` で発火 → 判定が食い違う。src=1 / stale=4 では両モードとも発火するため TC-12 は空振り |
| R-201（行番号誤り） | `grep -n` で L64-97 を直接確認 | **CONFIRMED**: guard 実体は **L64-82**（判定式 **L79** / WARN L80 / `return 0` L81）、**L83-92 は削除ループ**。plan の「L76-85 / L82-84」は誤り |
| R-110 / 実測「`sync_dir` は単一呼び出し」 | `grep -n "sync_dir "` | **CONFIRMED**: 定義 L39・呼び出しは L96 の 1 箇所のみ（サブシェル・パイプ非経由）→ `guard_fired` の global 集約は成立 |

## 指摘一覧（設計妥当性レーン）

| ID | severity | 指摘 | disposition | 反映先 |
|----|----------|------|------------|--------|
| R-101 | major | TC-12 の fixture（src=1/stale=4）は現行実装でも両モードで発火し AC-3 を検証できない。乖離帯は `src < stale ≤ 2*src` | **採用** | test-cases TC-12 を src=3 / stale=4 へ |
| R-102 | major | TC-13 の 2 経路は現行 `FIXTURES_DIR` 判定でも同結果で AC-4 を検証できない。`FIXTURES_DIR` 汚染時のケースが必要 | **採用**（R-202 と統合実装） | test-cases TC-13③ |
| R-103 | minor | AC-8 文言が `$?` 捕捉のみで充足と読め、OR 判定が残ると空振り再発 | **採用** | plan AC-8 を AND + rc 捕捉へ厳格化 |
| R-104 | minor | AC-1 後半「CI job 自動 fail」の TC が無く根拠が推論 | **採用** | AC-1 を exit 3 に限定し、CI fail は Evidence として plan に記録 |
| R-105 | minor | E-4（複数 label 同時発火）に TC 未割当。A-1 採用根拠が未検証 | **採用**（R-209 と同一） | test-cases TC-16 新設 |
| R-106 | minor | override フラグの責務帰属・監査が未定義 | **採用** | AC-2 に override ログ必須 + CI `env:` 禁止を追加 |
| R-107 | minor | E-2 が廃止予定の `_dst_count` を条件式に使用 | **採用** | test-cases E-2 を stale=0 表記へ |
| R-108 | info | `_src_count` は README.md を含み dst 側は除外する非対称 | **採用** | plan 論点 B に「src 側も README 除外で対称化」を明記 |
| R-109 | info | 論点 B は実行時に旧式と**厳密に等価**（`D = S + stale` より `2S < D ⟺ stale > S`）。境界 src=3/stale=3・src=0/stale=0・src=0/stale=N も検算済みで穴なし | **採用** | plan 論点 B の「ほぼ等価」を「実行時は厳密に等価・差分は dry-run のみ」へ |
| R-110 | info | 終端 exit 3 は `set -eu` + `trap EXIT` 下でも伝播（dash/bash 実測） | **採用**（出典明記） | plan Risks に「C-2 レーン実測」注記 |
| R-111 | info | `PLANGATE_ALLOW_MASS_DELETE` は既存 `PLANGATE_*` 解除フラグ命名と同型 | **採用** | plan 論点 4 の回答根拠として記録 |
| R-112 | info | F5 の経路数が issue（2）と plan（3）で不一致 | **採用**（R-207 で確定） | plan Q2 / AC-6 |

## 指摘一覧（コードベース整合レーン）

| ID | severity | 指摘 | disposition | 反映先 |
|----|----------|------|------------|--------|
| R-201 | major | plan の guard 行番号が実測と不一致（実測 L64-82 / 判定式 L79。plan の L76-85 は削除ループを 3 行含む） | **採用**（オーガナイザー実測で CONFIRMED） | plan Metrics Evidence / 論点 B |
| R-202 | **critical** | TC-13 を ta-26 内で `sh tests/extras/ta-26...` / `sh tests/run-tests.sh` として起動すると**無限再帰**（後者は全スイート再入）。extras からの自己/スイート再実行は repo 内前例 0 件 | **採用** | test-cases TC-13 を「ガード env 付き子プロセス 1 段 + 静的自己証明」へ再設計 |
| R-203 | major | `PG_HARNESS_SOURCED` の env 衛生未定義（export 不可 / 外部汚染時の誤判定 / standalone は `set -u` 無しで空展開が静かに通る） | **採用** | plan 論点 C に「非 export・`FIXTURES_DIR` との AND 判定・run-tests の unset リスト追加」を明記 |
| R-204 | major | `${FIXTURES_DIR:-}` 判別は既存 11 extras の事実上の規約。ta-26 だけ新シグナルへ移すと二機構併存 | **部分採用** | ta-26 冒頭コメントで方針明記 + README 規約追記は follow-up issue に含める（Files to Touch 3 件を維持） |
| R-205 | major | exit 3 は drift-check job の `run:` 1 行目で即失敗するため、yml L53 の説明メッセージに到達しない。可観測性は script 側でしか担保できない | **採用** | **AC-9 新設**（guard メッセージが stderr + override 手順 + label を含む） |
| R-206 | minor | exit code の優先順位（先行 fatal exit 1 > guard exit 3）が未定義 | **採用** | plan 論点 A に明記 + TC-10 の期待に「exit 1 でないこと」 |
| R-207 | major | F5 の実態は「src 駆動の無ガード削除 **2 経路**」（L140-150 / L283-296）。L317-330 は allowlist 駆動で mass-delete hazard ではない。危険度も (2) が真の hazard | **採用** | plan Q2 / AC-6 を 2 経路へ訂正（+ hazard クラス注記） |
| R-208 | minor | 新 TC が TC-05 のフル sandbox を真似ると marketplace 経路（exit 1）が有効化され exit 3 の assert が汚染される | **採用** | test-cases TC-09〜TC-12/16 前提に「TC-08 と同じ**最小** sandbox」を明記 |
| R-209 | minor | E-4 に TC 未割当。かつ TC-08 sandbox は agents 1 label しか通らない | **採用**（R-105 と同一） | TC-16 |
| R-210 | minor | `_stale_count` を 3 本目の走査で数えると README 除外条件が 2 箇所に分散 | **採用** | plan 論点 B に「既存 dst ループ内で同時集計」 |
| R-211 | minor | 命名は既存 39 個の `PLANGATE_*` と整合。ただし run-tests の unset リスト外のため開発者環境に export されると恒久無効化に気づけない | **採用** | AC-2 の override ログ必須化 + 論点 C の unset 追加 |
| R-212 | info | `ta-54` が実リポジトリに対し sync を生実行している（`|| true` 吸収のため回帰しないが非退行対象として明示すべき） | **採用** | plan Testing Strategy の E2E に ta-54 を名指し |

## レーン間で返された事項（コードベース整合 → 設計妥当性）

| # | 追加 AC 候補 | 結果 |
|---|-------------|------|
| A | guard メッセージの stderr 出力 + override 手順 + label | **AC-9 として採用** |
| B | exit code 優先順位の定義 | plan 論点 A に明記（AC 化せず設計制約として固定） |
| C | 複数 label 同時発火の TC 割当 | **TC-16 として採用**（AC-1 の検証手段に追加） |
| D | TC-13 が自己再帰しない不変条件 | **TC-13 の設計要件として採用**（R-202） |

## 集計

- critical: 1（R-202）→ 全採用・反映済み
- major: 8（R-101 / R-102 / R-201 / R-203 / R-204 / R-205 / R-207 / R-209 相当）→ 7 採用 + 1 部分採用（R-204）
- minor / info: 10 → 全採用
- **不採用: 0 件**

## 確定反映（1 回）

反映コミットに `Refs: R-101, R-102, R-103, R-104, R-105, R-106, R-107, R-108, R-109, R-110, R-111, R-112, R-201, R-202, R-203, R-204, R-205, R-206, R-207, R-208, R-209, R-210, R-211, R-212` を付す。

| R-NNN | status | reflected_in(commit) | notes |
|-------|--------|---------------------|-------|
| R-101〜R-112 | reflected | （plan 確定反映コミット） | 全採用 |
| R-201〜R-212 | reflected | （同上） | R-204 のみ部分採用（README 規約追記は follow-up） |

確定反映後の plan で両レーンの critical / major は全て解消済み（不採用 0 件）のため、C-2 判定を **approve** とする。

C2-VERDICT: approve plan=sha256:a49aca66b085c8cc77522b736c649c16bc252d15871da955f8040af82811dc10

---

## 追記: W チェック（ai-loop C-3' / run-027 round 1）による R-109 / R-211 の精緻化

> 本節は追記専用規約に従い、C-2 の記録を書き換えずに**後続レビューでの是正**を記録する。

| 元 R-NNN | W チェックの発見 | 反映 |
|----------|----------------|------|
| R-109（info・「実行時は厳密に等価」） | Model B（adversarial）が **R-108 の README 対称化を併用すると厳密等価は崩れる**ことを指摘。旧式は実質 `stale > S_old + R`、新式は `stale > S_old − R` で**発火側（安全側）へ 2R 件ずれる**（実測 R=1） | plan 論点 B を「README が両側に無い場合のみ厳密等価。実 repo では安全側へ最大 2 件ずれる」へ訂正。#861 の意図（削除しすぎの防止）と同方向のため採用 |
| R-211（minor・unset リスト） | Model B が **plan 本文に `PLANGATE_ALLOW_MASS_DELETE` の unset 追加が書かれていない**ことを検出（disposition は「採用」だった） | plan 論点 C と Files to Touch に明記。`tests/run-tests.sh` L15 が明示列挙でワイルドカードでないことも実測で確認 |
| （新規・Model A） | Stop Condition / todo A-11 が AC-1〜8・TC-01〜TC-13 のまま / 「extras 56 本」は実数 53 | いずれも是正済み（実数はオーガナイザーが再実測） |

W チェック 2 体の判定: **model_a = approve / model_b = approve**（証跡: `evidence/w-check/model-a.md` / `model-b.md`）
