# EXECUTION PLAN — TASK-0877

> Issue: [#877](https://github.com/s977043/plangate/issues/877)（P1 / bug / area:workflow）
> 由来: #861 safety guard の未完部分 + #875 敵対的レビュー残件
> 入力: [`pbi-input.md`](./pbi-input.md)（2026-07-20 作成・main c0461bb 裏取り）
> 作成: 2026-07-25（B-1 既決の再確認 → 実測リフレッシュ → B-2 比較 → B-3 生成）
> 実行方式: **ai-loop（`/ai-loop-workflow run TASK-0877`）で C-3' 裁定を通す**（[`feedback_develop_via_ai_loop_workflow`] 方針・#907 で Phase 1 適用ドメイン拡張済み）

## 確認事項（B-1 / 既決）

| # | 論点 | 確定内容 | 出典 |
|---|------|---------|------|
| Q1 | dry-run の exit 方針（pbi-input Risks / TC-03 前提と衝突しうる） | **dry-run は exit 0 維持・実行時のみ guard 発火で exit 3**。CI 2 job（drift-check L51 / sync L76）はいずれも `--dry-run` を使わない生実行のため、AC-1 の「CI job 自動 fail」は実行側 exit 3 のみで成立（実測: `.github/workflows/sync-plugin-plangate.yml` L51/L76） | #877 セッション B-1 既決（carry-over v15） |
| Q2 | F5（無ガード削除経路） | **別 issue 分離**。本 PBI では扱わず AC-6 として「分離した」ことを plan/handoff に記録する。**対象は src 駆動の無ガード削除 2 経路**（L140-150 = skills `<name>/references` / L283-296 = ai-loop-cycle references）。L317-330 は**ハードコード allowlist の `case` 駆動で src 欠損に依存しない**ため mass-delete hazard ではなく対象外。危険度は L283-296 が真の hazard（正本 2 ディレクトリが空化すると期待集合が空になり全 .md 削除）（Refs: R-207, R-112） | 同上 + C-2 実測 |

## Goal

`scripts/sync-plugin-plangate.sh` の mass-delete safety guard（#861）を **silent（WARN + `return 0`）から fail-closed（終端 exit 3）** へ変更し、`PLANGATE_ALLOW_MASS_DELETE=1` による明示 override と、stale 件数ベースの dry-run/実行で一致する判定式、DELETE 正常系テスト（TC-09）を追加する。CI workflow（`.github/workflows/*.yml`）は一切 touch しない。

## Constraints / Non-goals

- **HO 非接触**: touch 対象 3 ファイルはいずれも Hardening Override 対象外（`scripts/hooks/*.sh` でも `bin/plangate` でも `.github/workflows/*.yml` でもない）。実測: `scripts/hooks/check-plan-hash.sh` L124-134 の case 文に `scripts/sync-plugin-plangate.sh` / `tests/**` は不在
- **CI yml 不変（AC-7）**: exit 3 は `run:` ステップの既定 shell（`bash -e`）で job を自動 fail させるため、workflow 側の変更は不要
- **後方互換**: guard が発火しない通常運用（stale 少数）では従来どおり削除が実行され exit 0。既存 TC-01〜TC-08 は全て PASS のまま
- **POSIX sh 準拠**: `local` を使わない。`sync_dir` は同一シェルで呼ばれるため global 変数でのフラグ集約が成立する（サブシェル呼び出しに変えない）
- Non-goals: F5（src 駆動の無ガード削除 2 経路への guard 適用）/ guard の共通関数 `_mass_delete_guard` 化 / CI workflow 変更 / sync 対象範囲そのものの見直し

## Approach Overview

### 論点 A: 発火時の exit 経路（F1）

| 案 | 内容 | 長所 | 短所 |
|----|------|------|------|
| **A-1（採用）** | `guard_fired` global フラグを立てて `sync_dir` は従来どおり削除ループのみ skip（コピーは継続）。スクリプト終端の "Sync complete" 出力後に `guard_fired=1 かつ DRY_RUN=0` なら **exit 3** | 既存の「コピーは阻害しない」設計を維持したまま silent を解消。複数 label で発火しても 1 回の終端集約で判定でき、部分実行の副作用が読みやすい | 発火してもスクリプト自体は最後まで走る（即時停止ではない） |
| A-2 | 発火箇所で即 `exit 3` | 実装が最小 | 後続 label のコピーが行われず、CI 自動 PR の内容が発火位置依存で非決定になる。既存 guard の「削除ループのみスキップ・コピーは阻害しない」契約を壊す |

A-1 の成立条件（C-2 実測で確認済み）:

- `sync_dir` は定義 L39・**呼び出しは L96 の 1 箇所のみ**で、`$(...)`・パイプ・サブシェルを一切経由しない素の `for` ループ内 → POSIX sh に `local` が無くても `guard_fired` の global 集約が成立（Refs: R-201 実測）
- 終端 `exit 3` は `set -eu` + `trap 'rm -f ...' EXIT INT TERM` 配下でも保持される（trap 本体に `exit` が無いため元の status が維持。dash / bash で実測 — 出典: C-2 設計妥当性レーン / Refs: R-110）
- **exit code の優先順位**: 先行 fatal（marketplace.json 同期失敗の `exit 1`）> guard（`exit 3`）。先行 fatal が起きた run では終端に到達しないため exit 1 が勝つ。TC-10 は「exit 3 であること」を厳密に assert し、exit 1 を誤って PASS 判定しない（Refs: R-206）
- **可観測性**: exit 3 は drift-check job の `run:` ブロック 1 行目でステップを即失敗させるため、yml L53 の `::error::` 説明メッセージには**到達しない**。したがって「何が起きたか / どう解除するか」は **script 側の出力でしか伝えられない** → AC-9 で stderr 出力と override 手順の明示を要求する（Refs: R-205）

### 論点 B: 判定式（F2）

現行は `_src_count * 2 < _dst_count`（**実測: 判定式は L79**、guard 実体は L64-82。L83-92 は削除ループ / Refs: R-201）。`_dst_count` は **コピーループ通過後**に数えるため、dry-run（コピーしない）と実行（コピーする）で同じ入力から異なる値になり、判定が食い違う。

**乖離の実証（オーガナイザー自身の sandbox 実測）**: src=3 / stale=4 で
dry-run は guard 非発火（`WOULD DELETE` 4 件を予告）、実行は `src=3 / dst=7` で発火。
乖離帯は `src < stale ≤ 2*src`（Refs: R-101）。

| 案 | 判定式 | 評価 |
|----|--------|------|
| **B-1（採用）** | stale（dst にあって src に無い＝削除候補、README.md 除外）を数え、`_stale_count > _src_count` で発火 | `_dst_count` に依存しないため dry-run/実行で完全一致（AC-3）。**README.md が両側に無い場合、実行時は旧式と厳密に等価**（コピー後は `dst ⊇ src` が保証され `D = S + stale` が恒等成立するため `2S < D ⟺ stale > S`。旧式の `_dst_count > 0` ガードも `stale > S` に包含される / Refs: R-109）。**README.md が実在する現行 repo では厳密等価ではない**: 旧式は実質 `stale > S_old + R`（`D = S_old − R + stale` を代入。R = src 側 README 件数）、R-108 の対称化後の新式は `stale > S_old − R` となり、**発火側（安全側）へ最大 2 件ずれる**（W チェック Model B 指摘・実測 R=1）。#861 は「削除しすぎ」を防ぐ装置であり、早く発火する方向のズレは意図と同方向のため採用する。TC-08（src=1 / stale=4 → 発火）・TC-09（src=2 / stale=1 → 削除実行）を両立 |
| B-2 | `_dst_count` を dry-run 時のみ補正 | モード分岐が判定式に混入し、以後の変更で再び乖離しうる |

B-1 の実装制約:

- **README.md の対称化**: 現行は `_src_count` が README.md を**含み**、dst 側は**除外**する非対称がある（実測: `agents` で src=18 / dst=17 / stale=0）。B-1 では `_src_count` 側も README.md を除外して対称にする（Refs: R-108）
- **走査の一本化**: `_stale_count` は新規の 3 本目のループを作らず、**既存の dst 走査ループ（L73-78）内で `_dst_count` と同時に集計**する。README 除外条件を 1 箇所に保つため（Refs: R-210）
- **境界検算**: src=3/stale=3 → 非発火（削除実行）/ src=0/stale=0 → 非発火 / src=0/stale=N>0（#861 本来ケース）→ 発火 / src=1/stale=1 → 非発火。旧式と結論一致（Refs: R-109）
- **実リポジトリでの誤発火**: 同期済み repo は全 label で stale=0（agents 18/0・rules 6/0・commands 6/0 実測）のため構造的に発火しない

### 論点 C: standalone 判定（F3）

`tests/extras/ta-26-plugin-sync.sh` L9 は `FIXTURES_DIR` 未定義を standalone 判定に使っている（暗黙の副作用依存）。`tests/run-tests.sh` の extras source ループ直前で `PG_HARNESS_SOURCED=1` を設定し、ta-26 はそれを明示参照する（AC-4）。

env 衛生（C-2 実測由来 / Refs: R-203, R-211）:

- **export しない**（単純代入）。export すると子プロセスが harness 実行と誤判定し、standalone fallback（`pass` / `fail` / `register_cleanup` の自前定義）に入らず壊れる
- 判定は **`[ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]` の AND**。片方でも欠ければ standalone 側（安全側）に倒す。standalone 実行時は `set -u` が効かないため、`FIXTURES_DIR` が空展開のまま L27 の `cd -- "$FIXTURES_DIR/../.."` が cwd 基準の誤ルートを静かに返す事故を防ぐ
- `tests/run-tests.sh` L15 の無害化 unset リスト（`PLANGATE_SKIP_REASON` 等 5 個の**明示列挙**でワイルドカードではない）に **`PG_HARNESS_SOURCED` と `PLANGATE_ALLOW_MASS_DELETE` の 2 つを追加**してから代入する。前者は harness/standalone 判別の誤りを、後者は開発者環境に export された override による guard の恒久無効化を遮断する（Refs: R-203, R-211 / W チェック Model B 指摘）
- **二機構併存への対処（Refs: R-204 / 部分採用）**: `${FIXTURES_DIR:-}` 判別は既存 11 extras の事実上の規約であり、ta-26 だけ新シグナルへ移すと 2 系統が併存する。Files to Touch を 3 件に保つため `tests/extras/README.md` の規約追記は**行わず**、ta-26 冒頭コメントに方針（新規 extras は `PG_HARNESS_SOURCED`、既存 11 本の移行と README 規約追記は follow-up）を明記する。follow-up は AC-6 の分離 issue に同梱する

### 論点 D: TC-03 の判定式（F4 隣接・新規発見）

実測で `tests/extras/ta-26-plugin-sync.sh` L50-51 が
`_t26_out=$(...) || true` の直後に `[ $? -eq 0 ]` を評価しており、**`$?` は直前の `|| true` の結果（常に 0）**になる。すなわち TC-03 は現状 exit code を検証していない（後段の `grep -q "Sync complete"` も OR なので常に真になりうる）。

本 PBI は exit code の意味を変える変更であり、この空振りを残すと AC-1/AC-3 の回帰検出力が無い。よって **TC-03 の判定式是正を in scope に含める**（新規 AC-8。touch ファイルは増えない）。

是正は `tests/extras/README.md` 規約 4 の正書式 `rc=0; out="$(cmd)" || rc=$?` に統一し、判定は
**`rc = 0` かつ `Sync complete` を含む**の **AND** とする（OR のままだと、guard 発火時も終端で
`Sync complete` を出力してから exit 3 する設計のため空振りが再発する）。同誤パターンは repo 全
extras 53 本中 `ta-26:51` の 1 箇所のみ（オーガナイザーが `ls tests/extras/ta-*.sh | wc -l` で再実測。C-2 レーンの「56 本」は誤り）（C-2 実測 / Refs: R-103）。新規 TC-10〜TC-13/TC-16 も
同じ正書式で書く。

## Files / Components to Touch

| # | パス | 変更 |
|---|------|------|
| 1 | `scripts/sync-plugin-plangate.sh` | guard を stale ベース判定へ + `guard_fired` 集約 + override + 終端 exit 3 + 発火メッセージの stderr 化（F1/F2/AC-9） |
| 2 | `tests/extras/ta-26-plugin-sync.sh` | standalone 判定を `PG_HARNESS_SOURCED` + `FIXTURES_DIR` の AND へ（F3）+ TC-09 追加（F4）+ TC-03 判定式是正（AC-8）+ TC-10〜TC-13 / TC-16 追加 + 冒頭に判別方式の方針コメント |
| 3 | `tests/run-tests.sh` | extras source ループ直前に `PG_HARNESS_SOURCED=1`（非 export）+ L15 の unset リストへ `PG_HARNESS_SOURCED` / `PLANGATE_ALLOW_MASS_DELETE` を追加（F3） |

いずれも非 HO。3 ファイルとも plugin 配布物の生成元ではないため sync による再生成ファイルは発生しない。

## Metrics Evidence（事前メトリクス検証）

| 対象 | 実数（実測） | 見積もり | ratio | 判定 |
|------|-------------|---------|-------|------|
| touch ファイル数 | 3（上表） | 3 | 1.0 | 採用 |
| 受入基準数 | 9（AC-1〜9） | 7（pbi-input） | 1.29 | 採用（AC-8 = 論点 D / AC-9 = C-2 R-205） |
| 追加行数 | +70〜120 行見込み（guard 25 / ta-26 80 / run-tests 3） | pbi-input の +40〜130 | — | 採用 |
| 現行 guard 実体行 | **L64-82**（コメント L64-67 / `_src_count` L68-72 / `_dst_count` L73-78 / 判定式 **L79** / WARN L80 / `return 0` L81）。**L83-92 は削除ループ** | — | — | オーガナイザーが `grep -n` で実測（pbi-input の L79-81・C-1 前の plan の L76-85 はいずれも誤り / Refs: R-201） |
| 無ガード削除経路（F5 対象） | **2 経路**（L140-150 / L283-296）。L317-330 は allowlist 駆動で対象外 | 3（pbi-input） | — | 実測値を採用（Refs: R-207） |

## Testing Strategy

- Unit: 該当なし（POSIX sh スクリプト。テストは E2E 相当の sandbox 実走で担保）
- Integration: `tests/extras/ta-26-plugin-sync.sh` — TC-08（guard 発火・削除保留）/ TC-09（DELETE 正常系）/ TC-10（発火時 exit 3・exit 1 でないこと・メッセージ検査）/ TC-11（`PLANGATE_ALLOW_MASS_DELETE=1` で削除実行・exit 0・解除ログ）/ TC-12（**src=3 / stale=4** の乖離帯で dry-run と実行の guard 判定一致）/ TC-13（`PG_HARNESS_SOURCED` による standalone 判別・**自己再帰しない設計**）/ TC-16（複数 label 同時発火で WARN は label ごと・exit 3 は 1 回）
- E2E: `tests/run-tests.sh` 全系（extras 自動 source）で既存 TA 群の非退行を確認。特に **`ta-54-ai-loop-link-selfcontained.sh` は実リポジトリに対し sync を生実行している**（L43/L63・`|| true` で吸収）ため、exit code 変更の影響有無を名指しで確認する（Refs: R-212）
- Edge cases: dry-run で guard 発火（exit 0 維持・WARN 出力あり）/ stale=0（発火しない）/ dst 空（stale=0 で発火しない）/ standalone 実行と harness source 実行の両経路 / `FIXTURES_DIR` が外部 env で汚染された standalone 実行
- Verification Automation: `sh tests/run-tests.sh && sh tests/extras/ta-26-plugin-sync.sh`

## Risks & Mitigations

| リスク | 影響 | 緩和 |
|--------|------|------|
| 終端 exit 3 が `set -eu` 配下の trap（EXIT）と干渉 | 一時ファイル残留 | trap は `rm -f` のみで exit code を変えない（**dash / bash で実測済み** — 出典: C-2 設計妥当性レーン / Refs: R-110）。TC-10 で実 exit code を assert |
| stale ベース判定が実 repo で誤発火 | CI が恒常 fail | 実 repo は全 label で stale=0（agents 18/0・rules 6/0・commands 6/0・C-2 実測）。exec 中にも `--dry-run` で再実測（TC-03/TC-04 でも担保） |
| dry-run exit 0 維持によりローカル事前確認で発火を見落とす | 検知遅延 | dry-run でも WARN 行は出力する。C-3 論点 3 として提示 |
| TC-03 是正で既存の緩い判定が厳格化し別要因で fail | 回帰検出 | exec 時に単体実行で切り分け（是正前後の exit code を実測。standalone ベースライン = **8 passed / 0 failed / exit 0**） |
| exit 3 が drift-check job の説明メッセージに到達しない | 失敗理由が CI ログで裸の exit 3 のみになる | AC-9 で guard メッセージに override 手順と対象 label を含め **stderr** へ出す（Refs: R-205） |
| 新 TC がフル sandbox を真似ると marketplace 経路（`exit 1`）が有効化され exit 3 の assert を汚染 | テストの偽陰性 | TC-09〜TC-12/TC-16 は **TC-08 と同じ最小 sandbox**（`CHANGELOG.md` / `.claude-plugin/marketplace.json` を置かない）に固定（Refs: R-208） |
| TC-13 の子プロセス起動がスイート再入を起こす | テストハング | ガード env を前置した 1 段起動 + 静的自己証明に置換（Refs: R-202・critical） |

## Questions / Unknowns（C-3 論点）

1. **論点 D（AC-8）の in scope 化**: TC-03 の `$?` 空振り是正を本 PBI に含める判断でよいか（含めない場合は別 issue 分離）
2. **B-1 判定式の semantics 変更**: `src*2 < dst` → `stale > src`。C-2 検証で **実行時は厳密に等価**（`D = S + stale` より）と確認済み。差分は dry-run 側のみで、そこが是正対象。この読み替えを承認するか（Refs: R-109）
3. **dry-run exit 0 維持**（Q1 既決の再確認）: guard 発火時も dry-run は exit 0 で良いか
4. **override 環境変数名** `PLANGATE_ALLOW_MASS_DELETE`: C-2 検証で既存 `PLANGATE_*` 解除フラグ（`PLANGATE_BYPASS_HOOK` / `PLANGATE_SKIP_SCOPE_CHECK` 等・計 39 個）と同型と確認済み（Refs: R-111）。承認でよいか
5. **override の責務帰属**: `PLANGATE_ALLOW_MASS_DELETE` は #861（データ損失インシデント）由来の安全装置の解除フラグ。**Human-owned のローカル操作限定**とし CI の `env:` には置かない、という位置づけで確定してよいか（AC-2 / AC-7 で機械検証 / Refs: R-106, R-211）
6. **R-204 の部分採用**: `${FIXTURES_DIR:-}` 判別を使う既存 11 extras の移行と `tests/extras/README.md` 規約追記を本 PBI に含めず follow-up へ回す判断でよいか（Files to Touch 3 件維持のため）

## Loop Scope

単一 PBI（TASK-0877）の exec 内における「検証コマンド失敗 → 自己修正」の反復のみを対象とする。

## Stop Condition

変更が Files to Touch 内 / Verification Automation が exit 0 / AC-1〜9 全 PASS / 残課題は handoff に明示。

## Resume Condition

stop 後の再開は、原因・修正方針・検証手順を本 plan に追記し Replan 判定を通す。

## Replan Triggers

- 変更ファイル数 > 4（= 想定 3 + 1）
- 同一検証コマンドの連続失敗 3 回
- 同一ファイルへの修正反復 3 回

## 受入基準

| ID | 内容 | 検証 |
|----|------|------|
| AC-1 | guard 発火時に script が **exit 3** で終了する（silent 廃止）。複数 label で発火しても exit 3 は 1 回・WARN は label ごとに出る | TC-10 / TC-16 |
| AC-2 | `PLANGATE_ALLOW_MASS_DELETE=1` で override でき、意図的な mass-delete を通せる（exit 0・削除実行）。**override 時は必ず解除ログを出力**し、CI workflow の `env:` には設定しない（Human-owned ローカル操作） | TC-11 + AC-7 の差分検査 |
| AC-3 | stale カウントが dry-run と実行で一致する | TC-12（乖離帯 src=3 / stale=4 で両モードの guard 判定が一致） |
| AC-4 | standalone 実行と harness source 実行を `PG_HARNESS_SOURCED`（非 export・`FIXTURES_DIR` との AND）で判別する | TC-13 |
| AC-5 | DELETE 正常系（src=2 / stale=1）が負側テストとして固定される | TC-09 |
| AC-6 | F5（**src 駆動の無ガード削除 2 経路**）の扱い＝**別 issue 分離**を明示記録する（R-204 の README 規約追記も同 issue に含める） | plan Q2 + handoff §3 + follow-up issue |
| AC-7 | `.github/workflows/*.yml` を touch しない | `git diff --name-only` に yml 不在 |
| AC-8 | TC-03 が dry-run の exit code を**変数に捕捉**し、`rc = 0` **かつ** `Sync complete` を含むことを **AND** で判定する（`$?` 空振りと OR 救済の解消） | TC-03 是正版 |
| AC-9 | guard 発火メッセージが **stderr** に出力され、**対象 label** と **override 手順（`PLANGATE_ALLOW_MASS_DELETE=1`）** を含む（CI drift-check では yml の説明メッセージに到達しないため） | TC-10 |

## Mode 判定

**モード**: `high-risk`

**判定根拠**:
- 変更ファイル数: 3 → standard
- 受入基準数: 9 → **high**（mode-classification 定量基準 6-10 = 高）
- 変更種別: バグ修正 + 安全性ガードの挙動変更 → standard〜high
- リスク: CI 全体を止めうる exit code 変更 + #875 で一度差し戻された領域 → 高
- **最終判定**: `high-risk`（定量の最大値採用）

**`lite_eligible`**: **false**
- size_ok（`SIZE_OK_MAX_FILES=2`）を 3 ファイルで超過
- 安全性ガードの semantics 変更を含み「既存パターン踏襲のみ」に当たらない
- AC-8 安全側原則により判定不能要素は false 側へ

**Hardening Override**: 非該当（対象 3 ファイルはいずれも HO 表外・実測済み）

## ai-loop run との関係

- **rollout eligibility（Phase 1）**: 対象 3 ファイルは `rollout-policy.md` §2 の判定基盤 carve-out 3 系統（`scripts/ai-loop/**` / `docs/workflows/ai-loop/**`+`docs/ai/ai-loop/**` / `.agents/skills/ai-loop-cycle/**`+`.claude/skills/ai-loop-cycle/**`）に**いずれも該当しない** → Phase 1 の適用対象（eligible）
- **予測される裁定**: `boundary=clean` だが `lite=false`（size_ok 超過）→ arbiter は **`HUMAN_ESCALATED`（exit 2）** を返す見込み。さらに §2 の #780 ハード順序制約（`lite.size_ok` 機械算出の未導入下では実機能 auto-approve は決定論的に escalate）が二重に効く
- **したがって C-3 は Human 承認が正規経路**。ai-loop run は「承認境界を機械が正しく escalate する」ことの実証と、W チェック 2 体による独立レビューの取得を目的として実行する
