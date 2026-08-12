---
task_id: TASK-1036
artifact_type: plan
schema_version: 1
status: draft
mode: standard
related_issue: https://github.com/s977043/plangate/issues/1036
created_by: claude-worker
---

# TASK-1036 Implementation Plan

## Goal

`PG_T26_NO_RECURSE` が呼び出し元 env から漏れても **harness 経路（`sh tests/run-tests.sh`）では無害化**され、`ta-26` の TC 群（mass-delete guard 回帰テスト #877/#914/#970 を含む）が黙って消えない状態にする。漏れは回帰テストで機械的に検出でき、その検出力は変異注入で実証されている。

## Context

- 対象: `tests/extras/ta-26-plugin-sync.sh` の再帰防止シグナル `PG_T26_NO_RECURSE`（#1012/#1039 でゲートが 4 箇所に拡大）
- 関連 Issue: [#1036](https://github.com/s977043/plangate/issues/1036)（由来: #1012 exec への独立 river-review）/ 関連: #921・#914・#970
- pbi-input: [`pbi-input.md`](./pbi-input.md)（base `408cebb` 時点で U-1/U-3 実走決着済み）
- **本 plan の base SHA: `48f6971`**（pbi-input 起票後に TASK-0921 Slice 1（#1046: 共有 exit 契約 `_extra-contract.sh` + 層 A 12 本移行 + ta-61）と TASK-1023 がマージ済みのため、前提を全数再実測した — 下記「前提の実測検証」）

## 前提の実測検証（2026-08-12 / base `48f6971` / macOS sh）

pbi-input（base `408cebb`）の実測値が現 main で再現するかを全数照合した。

| # | 前提（pbi-input） | 現 main での再実測 | 判定 |
|---|---|---|---|
| P-1 | `run-tests.sh:20` unset 集合 = 7 env、`PG_T26_NO_RECURSE` を含まない | L20 で同一 7 env を確認 | ✅ 再現 |
| P-2 | `ta-26` ゲート 4 箇所（L67/L293/L427/L572、`PG_T26_NO_RECURSE:-0`） | 同一 4 箇所 | ✅ 再現 |
| P-3 | TC-13 の env 前置 2 箇所（L298/L301、`_t26_out13a=` / `_t26_out13b=`） | 同一 | ✅ 再現 |
| P-4 | TC-33 = L761（unset 集合の包含検査、`ta-26` 自身も対象） | L761 で同一 | ✅ 再現 |
| P-5 | env なし `32 passed, 0 failed` / `[SKIP]` 0、env 前置 `15 passed, 0 failed` / `[SKIP]` 4 | 同一（32/15/4） | ✅ 再現（スナップショット、契約値にしない） |
| P-6 | `PG_HARNESS_SOURCED=1` は非 export（L163）、案 (d) の else 節（L37 `PG_T26_STANDALONE=0`）が存在 | 同一 | ✅ 再現 |
| P-7 | （pbi-input に無い追加事実）`ta-26` は #921 実行契約に**未移行**（`_extra-contract.sh` 不使用・旧型 preamble のまま） | grep で確認 | ⚠️ 追加事実 1 |
| P-8 | （同上）新規 extras は #921 checklist（`PG_EXTRA_CAPABILITY` marker / bootstrap / finalize / 3 条件 AND 判定）に従う必要がある。README「実行契約」節が正本 | README + ta-61 実物で確認 | ⚠️ 追加事実 2 |
| P-9 | （同上）`ta-26` standalone 全 TC 実行 = **実測 約 44 秒**（`time` 実測 43.7s） | 実測 | ⚠️ 追加事実 3（動的同値 TC のコスト設計に直結） |
| P-10 | （同上）`ta-61` に同型ガード `PG_T61_NO_RECURSE` が存在し、同じ「呼び出し元漏れ」クラスが残る | ta-61 冒頭コメントで確認 | ⚠️ 追加事実 4（Out of scope、handoff の V2 候補へ） |

> **P-7 の含意**: 案 (d) の挿入点（harness 分岐 else 節）は #921 マージ後も無傷で存在する。`ta-26` の契約移行（層 B 以降）は本 PBI の scope 外であり、移行が先行した場合は挿入点が変わるため replan trigger とする。

## Scope

### In scope（pbi-input の写像）

- `PG_T26_NO_RECURSE` が呼び出し元から漏れても harness 経路では無害化されるようにする
- 漏れを機械的に検出する回帰テストを追加し、修正前実装で FAIL することを変異注入で実証する
- `tests/extras/README.md` の規約更新（本 env の扱いの明文化）

### Out of scope（pbi-input の写像）

- `ta-26` のゲート構造そのものの変更（#1012/#1039 で確定済み）
- `ta-26` の TC 内容・期待値の見直し
- 他 extras の env 汚染耐性の一斉点検（P-10 の `PG_T61_NO_RECURSE` を含む — handoff の V2 候補として記録）
- 直接 standalone 起動時の保護（案 (b) を採らない限り残る。既知の残存リスクとして handoff に明記）
- `ta-26` の #921 実行契約への移行（別 PBI）

## Approach Comparison

| 案 | 内容 | 評価 | 判定 |
|---|---|---|---|
| (a) `run-tests.sh:20` へ 1 語追加 | harness 冒頭一括の既存構造に沿う | **単独では TC-33 が FAIL**（pbi-input N-1 で 15 ファイル欠落を実証済み）。carve-out をセットにすると全 extras の env 無害化契約に触れ high-risk | 不採用 |
| (b) シグナルを argv 化 | standalone 経路まで塞げる | 変更範囲が大きく #1012 確定構造に触れる | 不採用 |
| (c) `ta-26` preamble（無条件経路）で unset | — | **採用禁止**（TC-13 の子でも走りガード自体が壊れ、孫 spawn の再入ループ）。pbi-input N-3 | ❌ |
| **(d) `ta-26` の harness 分岐（else 節）で unset** | 親（harness で source された ta-26）だけが通る経路で漏れを無害化。TC-13 の子は standalone 分岐＝前置 env が保持されガード継続。`run-tests.sh` の unset 集合を増やさないため TC-33 非波及 | pbi-input N-7 で実走検証済み（D-A〜D-D + BASE の 5 条件）。触るのは `ta-26` 1 本 + README + 新規 TC | **採用** |

### Recommended Approach（案 (d)）

`tests/extras/ta-26-plugin-sync.sh` の harness 分岐（`else` 節、記号アンカー: `PG_T26_STANDALONE=0` の行。現 L37）に以下を追加する（pbi-input N-7 の sandbox 実証と同形）:

```sh
else
  PG_T26_STANDALONE=0
  # harness 分岐でのみ呼び出し元 env の漏れを無害化する（#1036）。
  # preamble / standalone 分岐で unset してはならない — TC-13 の子でも走り
  # 再帰防止ガード自体が壊れる（孫 spawn の再入ループ）。
  unset PG_T26_NO_RECURSE 2>/dev/null || true
fi
```

依存する構造的前提（Risks R-P6 で固定）: `run-tests.sh` は `PG_HARNESS_SOURCED=1` を **export しない**（L159-163 コメント + L163 代入。export すると TC-13 の子まで harness 判定になり本 unset が子でも走る）。この規約は README 規約 8 と TC-30 が静的に固定している。

### 回帰テストの設計（U-2 / U-4 の plan 決着）

**配置: 新規 extras `tests/extras/ta-62-t26-recurse-env-guard.sh`**（次の空き番号。#921 実行契約 checklist 準拠 = capability marker `standalone-capable` / bootstrap / `pg_extra_contract_finalize` / 3 条件 AND 判定 / TC-33 静的包含要件の明示 unset 行）。

`ta-26` 内に置く案は不採用: 漏れ検証は「ta-26 を harness 相当で source し直す」必要があり、`ta-26` 内に置くと再帰防止ゲートとの相互作用（自分自身が消える位置・再入）を管理するコストが高い（pbi-input U-2 の懸念どおり）。

TC は 2 層で構成する:

- **T1036-TC-D（動的・同値照合 / AC-2 の主担体）**: tmp のミニ harness ラッパ（`pass=0; fail=0; register_cleanup(){ :; }` 相当 + 実 `FIXTURES_DIR` + `PG_HARNESS_SOURCED=1` を定義して `ta-26` を source する薄いドライバ）を使い、
  1. `PG_T26_NO_RECURSE=1` を export した leak 実行
  2. env なしの clean 実行
  の 2 回を走らせ、**出力の完全一致（`diff`）+ leak 実行に再帰防止起因の `[SKIP]` 行が 0** を assert する。件数のハードコードなし・`ta-26` の TC 増減に自動追従（pbi-input U-3 の決着方式をテスト内に内蔵）。
- **T1036-TC-S（静的・配置検査 / 案 (c)・案 (a) 混入の予防線）**: `ta-26` の harness 分岐（`PG_T26_STANDALONE=0` 直後のブロック）に `unset PG_T26_NO_RECURSE` が**存在**し、preamble の standalone 分岐（無条件経路）には**存在しない**こと、`run-tests.sh` の unset 集合に `PG_T26_NO_RECURSE` が**混入していない**ことを grep で検査する。動的に実行できない変異（下記 M-2）の kill を担う。

**変異注入（U-4 の決着 / 変異は call site を壊す）**:

| 変異 | 内容 | kill する TC | 実行方式 |
|---|---|---|---|
| M-1 | tmp 複製の `ta-26` から修正行（harness 分岐の `unset PG_T26_NO_RECURSE`）を削除 | **T1036-TC-D が FAIL**（leak 実行に `[SKIP]` が出て diff 不一致） | 動的実走。修正前実装（現 main HEAD）への RED 実走と同値（AC-2 の「修正前の実装で FAIL」を兼ねる） |
| M-2 | tmp 複製で unset を preamble 無条件経路へ移す（案 (c) 型） | **T1036-TC-S が FAIL** | **静的 kill のみ・動的実行禁止**。動的に走らせると TC-13 の子がガードを失い孫 spawn の再入ループ（#1012 todo の警告を踏襲）。`sh -n` で構文のみ確認 |
| M-3 | sandbox の `run-tests.sh` unset 行へ `PG_T26_NO_RECURSE` を追加（案 (a) 型） | **既存 TC-33 が FAIL**（pbi-input N-1 で 15 ファイル欠落を実証済みの再確認）+ T1036-TC-S が FAIL | リポジトリ外 sandbox（`git archive`）で実走 |

**実行時間の設計判断（P-9 起因・本 plan 固有の論点）**: `ta-26` の全 TC 実行は実測 約 44 秒。T1036-TC-D は harness 相当実行を 2 回行うため **suite 全体へ +約 90 秒**の追加になる。#1039 が ta-26 短縮を主題にした直後であり、無条件で常時 2 回走らせる設計は逆行する。よって:

- T1036-TC-D 自身に再帰防止ガード（`PG_T62_NO_RECURSE` 型）は**設けない**（本 PBI が塞ぐ穴と同型の穴を新設しない）
- 代わりに **exec で実測し、suite 追加時間を evidence に記録**する。+120 秒を超える場合は軽量化（clean 側 1 回の結果をファイルキャッシュ等）を **C-3/C-4 の判断事項として提示**し、AI 単独で AC-2 の同値照合要件を弱めない（停止条件 S-5）

## Files / Components to Touch

| ファイル | 操作 | 目的 |
|---|---|---|
| `tests/extras/ta-26-plugin-sync.sh` | modify（harness 分岐 else 節へ 3-4 行） | 案 (d) 本体 |
| `tests/extras/ta-62-t26-recurse-env-guard.sh` | create | 回帰テスト（T1036-TC-D / T1036-TC-S）。#921 契約準拠 |
| `tests/extras/README.md` | modify（規約 7 / 8 追記） | AC-5。TC-30 が grep する既存文言（`PG_HARNESS_SOURCED` / 非 export / AND / standalone 側（安全側））を壊さない追記のみ |
| `docs/working/TASK-1036/**` | create/update | Plan Package / evidence / handoff |

**Hardening Override 対象パス: 含まない**（`tests/` + `docs/working/` のみ。`.github/workflows/*` / `scripts/hooks/*` / `bin/plangate` 等に触らない）。触る必要が生じた時点で停止し replan（Mode 引き上げ）。

## Work Breakdown

### T-01: 前提の実測再検証（完了 / 本 plan フェーズ内）

- Output: 上記「前提の実測検証」表（P-1〜P-10）
- Owner: agent / Risk: low / rollback: 不要（読取のみ）

### T-02: Plan Package + C-1 セルフレビュー（本成果物）

- Output: plan / todo / test-cases / INDEX / current-state / decision-log / review-self
- Owner: agent / Risk: low / rollback: 文書は削除せず差分改訂 + decision-log 追記

### H-01: Human C-3（c3.json 初回発行）👤

- 確認事項 4 点（todo H-01 / INDEX と同一）: (1) 案 (d) 採用、(2) Mode=standard / `lite_eligible=false`、(3) T1036-TC-D の実行時間設計（上記）、(4) AC 候補-1 の採否
- 🚩 チェックポイント: **C-3 APPROVED（c3.json）まで exec 着手禁止**

### T-03: RED — `ta-62` 新規作成 + 修正前 FAIL 証跡（AC-2 前段）

- `ta-62-t26-recurse-env-guard.sh` を #921 checklist 準拠で作成（T1036-TC-D / T1036-TC-S）
- 修正前の tree（案 (d) 未適用）で T1036-TC-D / T1036-TC-S が **FAIL することをログ付きで実証**（`evidence/test-runs/red.log`）
- depends_on: H-01 / Owner: agent / Risk: mid（ミニ harness ラッパの再現度）
- 🚩 チェックポイント: RED が「leak 実行に `[SKIP]` が出る」ことを理由に FAIL していること（別要因の FAIL は設計不備）
- rollback: test commit を `git revert`。T-04 より先に戻さない

### T-04: 案 (d) 本体 — `ta-26` harness 分岐へ unset

- 上記 Recommended Approach の差分（3-4 行 + コメント）を適用
- depends_on: T-03 / Owner: agent / Risk: mid
- 🚩 チェックポイント: T-03 の RED が GREEN 化 + `PG_T26_NO_RECURSE=1` 前置の直接起動（子相当）で従来どおり `15 passed` 級の skip 挙動（AC-3）
- rollback: 実装 commit を `git revert`（漏れ穴が復活するだけで既存挙動は不変）

### T-05: README 規約 7 / 8 追記（AC-5）

- 規約 7: `PG_T26_NO_RECURSE` は harness 側（`ta-26` の harness 分岐）で無害化される対象であることを追記
- 規約 8 近傍: `ta-26` の standalone 分岐では**意図的に unset しない**（unset するとガード自体が壊れる）ことを追記
- TC-30 の grep 対象文言を変更しない（追記のみ）
- depends_on: T-04 / Owner: agent / Risk: low / rollback: doc commit revert

### T-06: 変異注入検証（AC-2 本体）

- M-1（動的 kill）/ M-2（静的 kill・**動的実行禁止**）/ M-3（sandbox で TC-33 FAIL 再確認）を実施し `evidence/test-runs/mutation.log` に保存
- 各変異: tmp 複製 or リポジトリ外 sandbox へ 1 箇所ずつ注入・置換件数=1・mutant `sh -n` PASS・指定 TC FAIL・復元後 PASS
- depends_on: T-04 / Owner: agent / Risk: mid
- 🚩 チェックポイント: kill は**実 TC（T1036-TC-D / T1036-TC-S / 既存 TC-33）の FAIL** で示す。検証スクリプト内のインライン assert の FAIL を kill と申告しない（#874 既往 / R-029 同型）
- rollback: 検証成果物のみなら削除せず FAIL として記録し T-03/T-04 へ戻す

### T-07: 3 系統 + harness 同値照合 + full suite（AC-1 / AC-3 / AC-4）

- (i) `sh tests/run-tests.sh`（harness）、(ii) `sh tests/extras/ta-26-plugin-sync.sh </dev/null`（standalone）、(iii) `PG_T26_NO_RECURSE=1` 前置（子相当）の 3 系統で `ta-26` / `ta-62` が 0 failed
- `PG_T26_NO_RECURSE=1` export 下と env なしの `sh tests/run-tests.sh` を 2 回実走し、**`ta-26` セクション（`=== TA-26` 〜 次の `=== TA-` 直前）を切り出して `diff` 完全一致**（pbi-input N-7 D-C/D-D 方式）を evidence 化
- TC-33 が PASS のまま（AC-4）+ T1036-TC-D の suite 追加時間を実測記録
- depends_on: T-05, T-06 / Owner: agent / Risk: low
- rollback: 不要（検証のみ）

### T-08: status / handoff 整備

- 既知の残存リスク（直接 standalone 起動経路 / `PG_T61_NO_RECURSE` 同型クラス = P-10）を handoff に明記
- depends_on: T-07 / Owner: agent / Risk: low / rollback: addendum で訂正

## Testing Strategy

| 層 | 内容 |
|---|---|
| Unit（静的） | T1036-TC-S: unset の配置検査（harness 分岐に有・無条件経路に無・run-tests.sh に無） |
| Integration（動的） | T1036-TC-D: ミニ harness で leak/clean 2 回実行の出力同値照合 + `[SKIP]` 0 |
| Regression | 既存 TC-13（子ガード）/ TC-33（unset 包含）/ TC-30（README 規約）が PASS のまま |
| Mutation | M-1 動的 / M-2 静的（実行禁止）/ M-3 sandbox — 各 1 箇所注入・実 TC の FAIL で kill 判定 |
| Verification Automation | run-tests.sh 2 回実行 + ta-26 セクション diff（AC-1 の機械判定）。すべて件数ハードコードなし |

## 受入基準（pbi-input の AC 正本を写像 — 拡張しない）

- [ ] **AC-1**: `PG_T26_NO_RECURSE=1` export 下の `sh tests/run-tests.sh` で `ta-26` セクションの実行 TC 件数が env なし実行と一致（2 回実行のセクション diff で判定。再帰防止起因の `[SKIP]` 0 でも確認）
- [ ] **AC-2**: AC-1 を検証する TC を追加し、修正前実装への変異注入でその TC が実際に FAIL することをログ付きで実証。TC は通常実行との同値照合で書き、変異は修正の call site を壊す形
- [ ] **AC-3**: TC-13 が起動する子（L298/L301 の env 前置 2 系統）が従来どおりゲートを発火させ、#1012 の AC-1 が引き続き PASS
- [ ] **AC-4**: 修正後に `ta-26` が 3 系統すべてで 0 failed。とくに TC-33 が PASS のまま
- [ ] **AC-5**: `tests/extras/README.md` 規約 7（および必要なら規約 8）に、本 env が harness 側で無害化される対象であること + `ta-26` の standalone 分岐では意図的に unset しないことが読み取れる

### AC 候補（提案 — AC 正本には含めない / C-3 で採否判断）

- **AC 候補-1**: 追加 TC（`ta-62`）自体が #921 実行契約（capability marker / finalize / rc 意味レイヤー）に準拠していることを `ta-61` の契約回帰テストで確認する（新規 extras は自動的に ta-61 の検査対象に入るため、実質 AC-4 の full suite 0 failed に内包される。独立 AC にするかは C-3 判断）

## Risks & Mitigations

| ID | リスク | 影響 | 緩和 |
|---|---|---|---|
| R-P1 | 案 (a) 型の混入で TC-33 FAIL（pbi-input R-1） | CI レッド + 15 ファイル波及 | 案 (d) 採用で構造的に回避 + T1036-TC-S が混入を検出 + M-3 で既存ゲートの検出力を再確認 |
| R-P2 | 案 (c) 型の実装ミスで再帰防止ガード破壊（pbi-input R-2） | 孫 spawn 再入ループ | unset は harness 分岐のみ + T1036-TC-S が配置を静的固定 + AC-3 で子の挙動固定。M-2 は動的実行禁止 |
| R-P3 | 追加 TC の空振り（pbi-input R-3） | 「塞いだつもり」 | M-1 で call site を壊し実 TC の FAIL で kill 実証。RED 証跡（T-03）必須 |
| R-P4 | 絶対件数の契約化（pbi-input R-4） | 無関係 PR の時限爆弾 | TC は diff 同値照合のみ。32/15/17/44s は測定日 + SHA 付きスナップショット隔離 |
| R-P5 | 直接 standalone 起動経路は塞がらない（pbi-input R-5） | ローカル誤検知残存 | Out of scope 明示 + handoff 既知残存リスク |
| R-P6 | `PG_HARNESS_SOURCED` 非 export 前提への依存（pbi-input R-6） | 将来 export 化で静かに破壊 | 前提を本 plan とコード内コメントに明記。TC-30/TC-13 が規約を静的固定。N-7 で実走検証済み |
| R-P7 | **T1036-TC-D の実行時間（+約 90 秒 / P-9）**が suite 短縮方針（#1039）と逆行 | CI 時間増 | exec で実測記録。+120 秒超なら軽量化案を C-3/C-4 判断事項として提示（AI 単独で同値照合要件を弱めない） |
| R-P8 | ミニ harness ラッパが実 harness（run-tests.sh の source 環境）を忠実に再現できない | TC-D の偽陰性/偽陽性 | ラッパは `pass/fail/register_cleanup/FIXTURES_DIR/PG_HARNESS_SOURCED` の最小集合に限定し、乖離が出たら AC-1 の実 run-tests.sh 2 回実走（T-07）が最終判定を担う二重化 |
| R-P9 | `ta-26` の #921 契約移行（層 B）が先行マージされ挿入点が変わる | conflict / 挿入点消失 | Replan trigger に登録。exec 開始時に base を再確認 |

## Questions / Unknowns

- ~~U-1（採用方式）~~ **plan で決着: 案 (d)**（pbi-input N-7 実走 + 本 plan 再実測。最終確定は C-3）
- ~~U-2（TC の配置）~~ **plan で決着: 新規 `ta-62`**（理由は「回帰テストの設計」節）
- ~~U-3（AC-1 の機械判定）~~ **決着済**: セクション切り出し + diff（pbi-input N-7）
- ~~U-4（変異の具体形）~~ **plan で決着: M-1/M-2/M-3**（M-2 は静的 kill のみ・動的実行禁止）
- U-5（残）: T1036-TC-D の実測追加時間が許容範囲か → exec T-07 で実測し、超過時は C-3/C-4 判断（R-P7）

## Stop Conditions（停止条件）

- S-1: Human C-3 未承認 / plan_hash 不一致 / base SHA drift（`48f6971` から `tests/extras/ta-26-plugin-sync.sh` または `tests/run-tests.sh` に後続変更が入った場合は再実測してから続行）
- S-2: TC-33 が FAIL した（案 (a) 型の波及が発生 = 設計前提の崩壊）
- S-3: TC-13 の子で `[SKIP]` が消えた（再帰防止ガード破壊 = 案 (c) 化）。孫 spawn の兆候（子プロセスの異常増殖）を検知した場合は**即座に実行を中断**
- S-4: M-1 で T1036-TC-D が FAIL しない（変異 survivor = 検出力未実証のまま進まない）
- S-5: T1036-TC-D の suite 追加時間が +120 秒を超えた（軽量化の判断を人間へ）。**測定方法を固定**: wall clock は負荷依存で揺れる（`ta-26` standalone 実測 43.7s → 再実測 56.4s）ため、判定は **`time` の user+sys 合計を同一環境で 3 回計測した中央値**で行い、測定環境（機種・並列負荷の有無）を evidence に注記する
- S-6: scope 外ファイル（特に HO 対象パス）への変更が必要になった

## Replan Triggers

- 案 (d) が現 tree で N-7 の結果を再現しない（D-A〜D-D 相当の再実走で乖離）
- `ta-26` の #921 契約移行が先行し harness 分岐の構造が変わった（R-P9）
- `run-tests.sh` 本体への変更が必要になった（案 (a) への転換 = Mode を high-risk へ引き上げて replan）

## Mode判定

**モード**: `standard` / `lite_eligible=false`

**判定根拠**（[`mode-classification.md`](../../../.claude/rules/mode-classification.md) 準拠 / pbi-input N-6 の条件付き確定を現 main で再判定）:

- 変更ファイル数: 3（ta-26 / README / ta-62 新規。docs/working は除外慣行）→ 中
- 受入基準数: 5 → 中
- タスク数（見込み）: 8（T-01〜T-08）→ 中
- 変更種別: code（テストハーネスのバグ修正 + 回帰 TC 追加）→ 低〜中
- リスク: 中（mass-delete guard **回帰テストの検出力**に関わる。guard 本体・承認境界には触れない）→ 中
- Hardening Override 対象パス: **含まない**（tests/ + docs/working のみ。N-5 の懸念だった `.github/workflows/test.yml` にも触れない）→ 引き上げなし
- 例外ルール該当: なし（セキュリティ関連コード本体の変更ではない。ただし判定不確実性の安全側として standard を下限とする）
- **最終判定: standard**（定量・定性とも中。pbi-input N-6 の「案 (d) → standard」と一致）
- `lite_eligible=false`: 案 (d) は「呼び出し元 env の無害化は harness 冒頭で一括」という既存パターンから外れる**新規設計判断**を含み、新規 extras ファイルも追加するため、AC-8 安全側で false（Lite/非同期降格の対象にしない。C-3 は同期・Human 判断）
