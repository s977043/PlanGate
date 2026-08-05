# EXECUTION PLAN — TASK-1012

> issue: [#1012](https://github.com/s977043/plangate/issues/1012)
> 入力: `docs/working/TASK-1012/pbi-input.md`
> 由来: PR #986 の V-2 事後補完 H-1（証跡 = `docs/working/TASK-0914/review-external.md` R-407）
> **改訂 1（C-1 FAIL 反映）**: 初版のゲート範囲は実コードと不一致だった（下記「C-1 指摘の反映」）。

## Goal

`tests/extras/ta-26-plugin-sync.sh` の TC-13 が起動する再帰防止モードの子プロセス（`PG_T26_NO_RECURSE=1`）で、**sandbox 実行を伴う重い TC 群**をスキップし、`ta-26` の実行時間を短縮する。**親プロセスのカバレッジは変えない。**

## C-1 指摘の反映（改訂 1）

初版は「#914 TC 群 = TC-20〜TC-34 を 1 つのゲートで包む」としていたが、実コードと 3 点で不一致だった（C-1 が実測で検出）。

| 指摘 | 実測 | 反映 |
|------|------|------|
| ゲート内定義の関数をゲート外が参照 | `_t26_mk_refs_guard_sandbox` は **L527 定義**、**L683（TC-35）/ L713（TC-36）が参照**。`set -e` 無しのため子は `command not found` で継続し FAIL → TC-13 の `0 failed` 判定を壊す | **ゲートを 2 組に分割**し、ヘルパー定義を**両方ゲート外**に残す（コード移動なし） |
| 「#914 TC 群 = TC-20〜34」が誤り | #914 の **TC-30（L732）/ TC-33（L743）は範囲外**の静的検査 | スコープを「**sandbox 実行を伴う TC**」で定義し直す。TC-30/33 は軽量（静的検査）のため**ゲートしない** |
| Unknowns「なし」の根拠が失効 | R-407 のプロトタイプは **TC-35/36 追加前**の tree で検証（TC-35/36 は #970 / PR #1014・現 main `a2a02b9`） | Unknowns を現 tree 基準で書き直し（下記） |

## Constraints / Non-goals

### Constraints

- **実装変更は `tests/extras/ta-26-plugin-sync.sh` の 1 ファイルのみ**（+ working context 文書）
- **ヘルパー関数の定義を移動しない**（コード移動は差分と設計判断を増やす）。ゲートを 2 組に分けて定義を外に残す
- 新規イディオムを導入しない。**L62-68 の既存ゲートと同一形**（説明コメント + `if` / `printf` / `else` / `fi`）で書く
- extras の standalone preamble・判別式（AND 判別 / 7 env unset）には**触らない**（TC-33 が静的走査するため）
- `scripts/sync-plugin-plangate.sh` の**素実行禁止**（TASK-0914 `handoff.md:129`）。検証は sandbox 経由
- 総数を契約値にしない（`0 failed` で判定 — TASK-0914 handoff §2 鮮度の運用）

### Non-goals

- production code（`scripts/sync-plugin-plangate.sh`）の変更
- **静的検査 TC（TC-30 / TC-33）のゲート化**（軽量であり、スキップしても時間短縮に寄与しない）
- TC-13 の連鎖 FAIL 構造の是正（**#1011**）
- TC-03/04 の `md5sum` 4 回実行・sync 内の `python3` 多重起動の最適化（**#914 diff 外**・#771 / #790 由来）
- guard 本体の欠陥（**#1009** / **#1010** / **#970** / **#991**）

### 触らないファイル

`scripts/sync-plugin-plangate.sh` / `tests/extras/` の他 14 本 / `tests/extras/README.md` / `tests/run-tests.sh`

> ⚠️ 本項を `## Files / Components to Touch` に置くと、`plan_package.py` の `extract_allowed_paths()` が**禁止パスを allowed_paths に取り込み**、C-3' の scope 逸脱検査（priority 1.5）が無効化される（C-1 が実測で検出）。そのため Constraints 側に置く。

## Approach Overview

既存の TC-03/04 ゲート（L62-68）と**同型**の分岐を **2 組**適用する。ヘルパー関数の定義（`_t26_mk_ai_loop_guard_sandbox` L394 / `_t26_mk_refs_guard_sandbox` L527）と `_T26_AI_LOOP_REFS_REL`（L388）は**いずれもゲート外に残す**。

```text
L388  _T26_AI_LOOP_REFS_REL=...          ← ゲート外
L394  _t26_mk_ai_loop_guard_sandbox()    ← ゲート外
      ┌─ ゲート A ─────────────────────┐
L421  │ TC-20 / 21 / 22 / 23 / 24 / 25 │  ← 経路2（sandbox 実行）
      └────────────────────────────────┘
L527  _t26_mk_refs_guard_sandbox()       ← ゲート外（TC-35/36 が参照するため）
      ┌─ ゲート B ─────────────────────┐
L558  │ TC-26 / 27 / 28 / 29 / 32 / 34 │  ← 経路1（sandbox 実行）
L673  │ TC-35 / 36                     │  ← #970（同じく sandbox 実行）
      └────────────────────────────────┘
L732  TC-30 / TC-33                      ← ゲート外（静的検査・軽量）
```

各ゲートは次の形:

```sh
if [ "${PG_T26_NO_RECURSE:-0}" = "1" ]; then
  printf '  [SKIP] TC-NN〜TC-MM（再帰防止の子プロセスでは省略・親で実行済み）\n'
else
  ...（既存ブロックそのまま・インデントのみ調整）...
fi
```

**論拠**（既存コメント L62-68 の踏襲）: TC-13 の判定は「子が `TA-26 standalone: … 0 failed` を出すこと」＝ standalone fallback がサマリ行を出すことの証明に限られ、これらの TC は必ず親プロセス側で実行されるためカバレッジは変わらない。

**TC-35/36 を含める理由**: #970 由来だが、`_t26_mk_refs_guard_sandbox` を使う**同じ重さの sandbox 実行 TC** であり、ゲート B の連続領域に位置する。除外すると (a) ヘルパー定義の移動が必要になり (b) 時間短縮効果が減る。

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 |
|------|------|--------|-------|------|----|
| **T-01** | baseline 実測。現行 tree で `ta-26` standalone の TC 総数 / PASS 数 / rc + 実行時間 2 回 | `evidence/test-runs/t01-baseline.log` | agent | 低 | 🚩 総数・PASS 数・rc を記録 |
| **T-02** | ゲート A / B の範囲を確定。**ゲート内で定義されゲート外で参照される shell 関数・変数が 0 件**であることを機械確認 | 範囲メモ + `evidence/verification/t02-symbol-scope.log` | agent | **高** | 🚩 **シンボル越境 0 件**を機械確認（行境界の一致だけでは不十分 — C-1 指摘） |
| **T-03** | ゲート A / B を適用（L62-68 と同型）。ヘルパー定義は移動しない。インデント調整のみで中身は 1 行も変えない | 差分 | agent | 中 | 🚩 `sh -n` rc=0 + **`git diff -w` の変化がゲート追加分のみ** |
| **T-04** | **AC-1**: `PG_T26_NO_RECURSE=1` で 2 本の `[SKIP]` が出て、ゲート対象 TC が 1 件も実行されない | `evidence/test-runs/t04-child-skip.log` | agent | 低 | 🚩 SKIP 行 2 本 + 非実行の両方を確認 |
| **T-05** | **AC-2**: 親の TC 総数・PASS 数が T-01 baseline と**完全一致** | `evidence/test-runs/t05-parent-parity.log` | agent | 中 | 🚩 baseline と数値一致 |
| **T-06** | **AC-3 / AC-4**: `ta-26` standalone 0 failed・フルスイート 0 failed | `evidence/test-runs/t06-suites.log` | agent | 低 | 🚩 両方 rc=0 |
| **T-07** | **AC-5**: 交互 A/B（BASE / OPT を交互に各 2 回以上）で実行時間を実測 | `evidence/test-runs/t07-ab-timing.log` | agent | 低 | 🚩 交互測定であること |
| **T-08a** | 変異①（AC-2 の検出力）: ゲート条件を反転（`!= "1"`）→ 親でもスキップされる → **T-05 が FAIL** することを確認 → 復元 | `evidence/test-runs/t08a-mutation-invert.log` | agent | 中 | 🚩 期待 FAIL を実測 + 復元後 T-05 再 PASS |
| **T-08b** | 変異②（**AC-1 の検出力**）: ゲート B の終端を TC-36 の**手前**へ縮める（= **TC-36 のみ**がゲート外に残る）→ 子で TC-36 が走り **T-04 が FAIL** することを確認 → 復元 | `evidence/test-runs/t08b-mutation-range.log` | agent | 中 | 🚩 期待 FAIL を実測 + 復元後 T-04 再 PASS |
| **T-08c** | 変異③（**AC-1 の静的前提の検出力**）: `_t26_mk_refs_guard_sandbox` の**定義をゲート B の内側へ移す**（初版が踏んだ構造の再現）→ **T-02 の越境検査が ≥1 件を報告**し、子は `command not found` で T-06 も FAIL することを確認 → 復元 | `evidence/test-runs/t08c-mutation-crossing.log` | agent | 中 | 🚩 越境 ≥1 の検出 + 復元後 T-02 再 PASS |
| **T-09** | handoff / status / current-state / INDEX を整備 | 各文書 | agent | 低 | 🚩 handoff 6 要素が揃う |

## Files / Components to Touch

| ファイル | 変更 |
|---------|------|
| `tests/extras/ta-26-plugin-sync.sh` | sandbox 実行 TC 群を `PG_T26_NO_RECURSE` ゲート 2 組で包む（**唯一の実装変更**） |
| `docs/working/TASK-1012/**` | working context 一式 + `evidence/` 配下（**`*` ではなく `**`**。`*` はセグメント境界で止まるため `evidence/test-runs/*.log` に一致せず、再裁定時に priority 1.5 の scope 逸脱へ倒れる — C-1 が実測で検出） |

## Testing Strategy

| 種別 | 内容 |
|------|------|
| **Integration** | 親（`PG_T26_NO_RECURSE` 未設定）と子相当（`=1`）の 2 系統 |
| **Regression** | フルスイート `sh tests/run-tests.sh` で 0 failed |
| **静的検査** | T-02 のシンボル越境検査 / TC-INV（`git diff -w` でゲート以外の内容変化 0） |
| **検出力の実証** | **変異 3 系統**。T-08a（条件反転 → AC-2 が FAIL）/ T-08b（範囲縮小 → AC-1 が FAIL）/ **T-08c（ヘルパー定義をゲート内へ → AC-1 の静的前提が FAIL）**。AC-1 とその静的前提の**双方に変異を当てる**のは C-1 指摘（空振り fixture 防止） |
| **Verification Automation** | 親/子の TC 総数・PASS 数比較と、シンボル越境検査をコマンド化して evidence に残す |

- Verification Automation: `sh tests/extras/ta-26-plugin-sync.sh </dev/null && PG_T26_NO_RECURSE=1 sh tests/extras/ta-26-plugin-sync.sh </dev/null && sh tests/run-tests.sh`

> `derive_loopspec()`（`scripts/ai-loop/plan_package.py:216`）は「`Verification Automation:` の直後にバッククォート囲みのコマンド列が続く」形式で抽出する。この行が無いと `PlanPackageError` で fail-closed になり、宣言した C-3' 経路に入れない（TASK-0874 `plan.md:655-659` と同形式）。

## Risks & Mitigations

| リスク | 緩和 |
|-------|------|
| **ゲート内定義のシンボルをゲート外が参照して子が壊れる**（初版で実際に踏んだ） | T-02 で**シンボル越境 0 件**を機械確認。ゲートを 2 組に分けて定義を外に残す設計自体が構造的な緩和 |
| ゲート範囲を誤り、親でも対象 TC がスキップされる | T-05（親のカバレッジ不変）+ T-08a（変異でその状態を作り FAIL 確認） |
| ゲート範囲が狭すぎて子で重い TC が残る | T-04（子で非実行）+ T-08b（範囲縮小変異で FAIL 確認） |
| 子のカバレッジが狭まることで将来の退行を見逃す | TC-13 の判定目的が standalone fallback の証明に限られることを根拠とし、handoff に**既知の妥協点**として明記 |
| 実行時間の改善が測定ノイズに埋もれる | T-07 で**交互 A/B**（連続測定にしない） |
| インデント調整で意図せず中身が変わる | T-03 の 🚩 で `git diff -w` の変化がゲート追加分のみであることを機械確認 |
| **今後 TC が追加され、またゲート範囲と依存が食い違う** | handoff の「触れないでほしいファイル / 注意」に、**ゲート境界の直後に TC を足すときはシンボル越境検査を再実行する**旨を明記（本 PBI で踏んだ再発防止） |

## Questions / Unknowns

| # | 内容 | 解消方法 |
|---|------|---------|
| U-1 | ゲート境界と、後から追加された TC（TC-35/36 = #970 / PR #1014）およびヘルパー定義の相互作用。**R-407 のプロトタイプは TC-35/36 追加前の tree で検証されており、その検証は現 tree に対して有効でない** | **T-02 で解消**（シンボル越境 0 件の機械確認）。設計上はゲート 2 分割で回避済みだが、実測で確定させる |
| U-2 | ゲート B に TC-35/36 を含めることが #970 の意図（symlink 集計の厳密一致検証）を損なわないか | 親では従来どおり実行されるため損なわない。T-05（親カバレッジ不変）で確定 |

## Mode 判定

判定結果: **standard**

**判定根拠**:

- 変更ファイル数: 1（実装）→ 超低〜低
- 受入基準数: **5**（AC-1〜AC-5）→ **中**
- 変更種別: code（test のみ・production code 不変）→ 低〜中
- リスク: 中（テスト意味論の変更を伴う）→ **中**
- 影響範囲: 当該ファイルのみ → 低
- **最終判定**: **standard**

> **AC 数について（C-1 再レビュー B-1 の反映）**: 一時的に「AC-6: ゲート範囲がヘルパー定義の依存を壊さない」を独立の受入基準として立てたが、`.claude/rules/mode-classification.md` L23 の定量基準では **受入基準数 6 は「高」の帯**（`0-1 / 1-2 / 3-5 / 6-10 / 11+`）であり、判定ロジック「定量と定性の高い方を最終モードとする」により **high-risk** になっていた。
>
> AC-6 の実体は**独立した要求ではなく「AC-1 が成立するための静的前提」**（シンボル越境が無いこと）なので、**AC-1 の検証条件として畳む**。これにより受入基準数は 5（＝中）に戻り、最終判定は **standard** で正しくなる。検証手段（TC-A6a / TC-A6b / TC-A6c）は削除せず AC-1 配下に残す。

### lite_eligible 判定（C-1 指摘を受けて再導出）

| 軸 | 値 | 根拠 |
|----|---|------|
| 変更ファイル数 | ✅ **1**（≤ `SIZE_OK_MAX_FILES`=2） | `ta-26-plugin-sync.sh` のみ |
| 新規設計の有無 | ✅ **なし** | L62-68 の既存ゲートと同一形を 2 箇所に適用するのみ。**ヘルパー関数を移動しないため「定義をどこへ置くか」の設計判断が発生しない**（C-1 が初版に対して指摘した論点は、2 分割設計により消滅） |
| 既存パターン踏襲 | ✅ **あり** | 同一ファイル内の同一イディオム・同一論拠 |
| 可逆性 | ✅ **あり** | `git revert` 1 手 |

→ **`lite_eligible=true`**（**計画時の C-3' 裁定に限る** — 下記）

> **成立範囲の注記（C-1 再レビュー B-7）**: `size_ok` が成立するのは **計画時の裁定のみ**。SKILL.md Step 1 により計画時の `changed_files` は plan の Files to Touch（2 件）だが、**実装後の再裁定では実差分**（実装 1 + working context 一式 + evidence 8 本 ≈ 10 件超）となり `SIZE_OK_MAX_FILES=2` を超えるため、**priority 1.9 で human escalate する見込み**。これは仕様どおりの挙動であり、再裁定を行う場合は Human 判断を前提とする。handoff にも明記する。

### 境界チェック

| 項目 | 判定 |
|------|------|
| Hardening Override 9 カテゴリ | **非該当**（`tests/extras/` は `scripts/hooks/check-plan-hash.sh` L124-134 のいずれにも含まれない） |
| ai-loop 判定基盤 carve-out | **非接触**（`scripts/ai-loop/**` / `docs/workflows/ai-loop/**` / `docs/ai/ai-loop/**` / `*/skills/ai-loop-cycle/**` のいずれでもない） |
| rollout-policy #780 slice C 前提 | **充足**。`scripts/ai-loop/arbiter.py` に `SIZE_OK_MAX_FILES = 2` の機械検証が実装済み（L421）。加えて**本変更は test のみで「実機能」ではない** |

**ゲート**: Human C-3 の代わりに **ai-loop の C-3' 裁定（`/ai-loop-cycle`）** を用いる。`arbiter.py` が `HUMAN_ESCALATED`（exit 2）を返した場合は**停止して人間へ提示**し、AI が自己解決しない。
