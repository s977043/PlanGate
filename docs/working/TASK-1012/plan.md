# EXECUTION PLAN — TASK-1012

> issue: [#1012](https://github.com/s977043/plangate/issues/1012)
> 入力: `docs/working/TASK-1012/pbi-input.md`
> 由来: PR #986 の V-2 事後補完 H-1（証跡 = `docs/working/TASK-0914/review-external.md` R-407）
> **改訂 2**: C-1 を 3 ラウンド実施し、計 12 件の指摘を反映した。

## Goal

`tests/extras/ta-26-plugin-sync.sh` の TC-13 が起動する再帰防止モードの子プロセス（`PG_T26_NO_RECURSE=1`）で、**sandbox 実行を伴う重い TC 群**をスキップし、`ta-26` の実行時間を短縮する。**親プロセスのカバレッジは変えない。**

## C-1 指摘の反映

### ラウンド 1（major 4 件）

| 指摘 | 実測 | 反映 |
|------|------|------|
| ゲート内定義の関数をゲート外が参照 | `_t26_mk_refs_guard_sandbox` は **L527 定義**、**L683（TC-35）/ L713（TC-36）が参照**。`set -e` 無しのため子は `command not found` で継続 FAIL → TC-13 の `0 failed` 判定を壊す | **ゲートを 2 組に分割**し、ヘルパー定義を**両方ゲート外**に残す（コード移動なし） |
| 「#914 TC 群 = TC-20〜34」が誤り | #914 の **TC-30 / TC-33 は範囲外**の静的検査 | スコープを「**sandbox 実行を伴う TC**」で定義し直す |
| TC-A1b の判定式が両解釈とも不成立 | `\|` が literal pipe で常に 0 / 意図した ERE では TC-30・TC-33 を拾う | ゲート対象へ限定して是正 |
| Unknowns「なし」の根拠が失効 | R-407 のプロトタイプは **TC-35/36 追加前**の tree で検証 | 現 tree 基準へ書き直し |
| 「触らないファイル」が Files 節に同居 | `extract_allowed_paths()` が禁止パスを allowed_paths へ取り込む | Constraints へ移動 |

### ラウンド 2（major 3 + minor 2）

| 指摘 | 反映 |
|------|------|
| **AC 数 6 は「高」の帯**（`6-10`）で Mode が high-risk になり lite / C-3' の前提が崩れる | AC-6 を **AC-1 の静的前提へ畳んで 5 件**に戻す |
| `derive_loopspec()` が要求する `Verification Automation:` + バッククォート囲みの行が無い | 追加（下記 Testing Strategy） |
| `docs/working/TASK-1012/*` がセグメント境界で止まり `evidence/` に一致しない | `**` へ修正 |
| TC-A6b の AC 紐付け誤り + 「TC-35/36 が外に残る」は誤記 | AC-1 へ訂正・「TC-36 のみ」へ是正 |
| TC-A1a を `[SKIP]` 総数で判定すると誤 FAIL（既存 2 本 → 適用後 4 本） | 新規 2 本を名指しする判定式に固定 |

### ラウンド 3（major 4 + minor 5）

| 指摘 | 実測 | 反映 |
|------|------|------|
| **タスク数 11 は「高」の帯**（`11-20`）。Mode 判定でこの軸を欠落しており、ラウンド 2 と同一クラスの再発 | todo Agent タスク 11 / Work Breakdown 11 | **6 タスクへ統合**（検証 3 つを 1 つ、変異 3 つを 1 つに） |
| **変異③が構造的に空振り** | `_t26_mk_refs_guard_sandbox` の参照は **562〜713 とすべてゲート B（558-731）の内側** → 定義を中へ移しても越境 0 件のまま | **ゲート外からゲート A 内変数 `_t26_t20` を参照する 1 行を注入**する形へ変更 |
| `git checkout --` が変異復元と実装取り消しを兼ねて両立しない | staged なら index へ、未 staged なら HEAD へ戻る | **T-02 で `git add` を必須化**し、復元セマンティクスを todo に明記 |
| pbi-input が改訂前のまま plan と矛盾 | In scope / Unknowns が旧記述 | 同期 |
| 変異①の適用範囲が未指定（ゲートは計 4 箇所） | 一括置換すると TC-13 が孫を無限 spawn | **新規 2 箇所限定**を todo に明記 |
| 行番号 stale / extras 本数 14 | `derive_loopspec` は L188 / extras は 57 本 | 是正・絶対件数を撤去 |

## Constraints / Non-goals

### Constraints

- **実装変更は `tests/extras/ta-26-plugin-sync.sh` の 1 ファイルのみ**（+ working context 文書）
- **ヘルパー関数の定義を移動しない**。ゲートを 2 組に分けて定義を外に残す
- 新規イディオムを導入しない。**L62-68 の既存ゲートと同一形**（説明コメント + `if` / `printf` / `else` / `fi`）で書く
- extras の standalone preamble・判別式には**触らない**（TC-33 が静的走査するため）
- `scripts/sync-plugin-plangate.sh` の**素実行禁止**（TASK-0914 `handoff.md:129`）。検証は sandbox 経由
- 総数を契約値にしない（`0 failed` で判定）

### Non-goals

- production code（`scripts/sync-plugin-plangate.sh`）の変更
- **静的検査 TC（TC-30 / TC-33）のゲート化**（軽量でありスキップしても時間短縮に寄与しない）
- TC-13 の連鎖 FAIL 構造の是正（**#1011**）
- TC-03/04 の `md5sum` 4 回実行・sync 内の `python3` 多重起動の最適化（**#914 diff 外**・#771 / #790 由来）
- guard 本体の欠陥（**#1009** / **#1010** / **#970** / **#991**）

### 触らないファイル

`scripts/sync-plugin-plangate.sh` / `tests/extras/` の他のスクリプト全て / `tests/extras/README.md` / `tests/run-tests.sh`

> ⚠️ 本項を Files 節に置くと `extract_allowed_paths()` が**禁止パスを allowed_paths に取り込み**、C-3' の scope 逸脱検査（priority 1.5）が無効化される（C-1 R1 が実測で検出）。そのため Constraints 側に置く。

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

各ゲートは次の形（SKIP 文言は**ゲート外の TC-30/33 を含意しない**表記にする）:

```sh
if [ "${PG_T26_NO_RECURSE:-0}" = "1" ]; then
  printf '  [SKIP] TC-20〜TC-25（再帰防止の子プロセスでは省略・親で実行済み）\n'
  # ゲート B 側の文言は '  [SKIP] TC-26〜29/32/34〜36（…）'
else
  ...（既存ブロックそのまま・インデントのみ調整）...
fi
```

**論拠**（既存コメント L62-68 の踏襲）: TC-13 の判定は「子が `TA-26 standalone: … 0 failed` を出すこと」＝ standalone fallback がサマリ行を出すことの証明に限られ、これらの TC は必ず親プロセス側で実行されるためカバレッジは変わらない。

**TC-35/36 を含める理由**: #970 由来だが、`_t26_mk_refs_guard_sandbox` を使う**同じ重さの sandbox 実行 TC** であり、ゲート B の連続領域に位置する。除外すると (a) ヘルパー定義の移動が必要になり (b) 時間短縮効果が減る。

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 |
|------|------|--------|-------|------|----|
| **T-01** | baseline 実測（TC 総数 / PASS 数 / rc + 実行時間 2 回）+ ゲート A / B の範囲確定 + **シンボル越境検査**（ゲート内で定義しゲート外で参照される関数・変数が 0 件） | `evidence/test-runs/t01-baseline.log` / `evidence/verification/t01-symbol-scope.log` | agent | **高** | 🚩 baseline 記録 + **越境 0 件を機械確認**（行境界の一致だけでは不十分） |
| **T-02** | ゲート A / B を適用（L62-68 と同型）。ヘルパー定義は移動しない。**適用後に `git add` して index に載せる**（T-04 の変異復元が実装を消さないため） | 差分 | agent | 中 | 🚩 `sh -n` rc=0 + `git diff -w` の変化がゲート追加分のみ + `git diff --cached --stat` に当該ファイルが載る |
| **T-03** | **受入検証**: AC-1（子で `[SKIP]` 2 本 + ゲート対象 TC の非実行 + ゲート外 TC-30/33 は実行）/ AC-2（親のカバレッジが baseline と完全一致）/ AC-3・AC-4（ta-26 standalone・フルスイートとも 0 failed） | `evidence/test-runs/t03-acceptance.log` | agent | 中 | 🚩 AC-1〜AC-4 すべて PASS |
| **T-04** | **変異検証 3 種**（1 つずつ入れて戻す）。①条件反転（**新規 2 ゲート限定**）→ AC-2 が FAIL ②ゲート B 終端を TC-36 手前へ → AC-1 が FAIL ③**ゲート外にゲート A 内変数 `_t26_t20` を参照する 1 行を注入** → T-01 の越境検査が ≥1 件 | `evidence/test-runs/t04-mutations.log` | agent | **高** | 🚩 3 変異すべてで期待 FAIL + 各復元後に再 PASS |
| **T-05** | **AC-5**: 交互 A/B（BASE / OPT を交互に各 2 回以上）で実行時間を実測 | `evidence/test-runs/t05-ab-timing.log` | agent | 低 | 🚩 交互測定であること |
| **T-06** | handoff / status / current-state / INDEX を整備。handoff に「**ゲート境界の直後に TC を足すときは越境検査を再実行する**」旨を明記 | 各文書 | agent | 低 | 🚩 handoff 6 要素 + 再発防止の申し送り |

## Files / Components to Touch

| ファイル | 変更 |
|---------|------|
| `tests/extras/ta-26-plugin-sync.sh` | sandbox 実行 TC 群を `PG_T26_NO_RECURSE` ゲート 2 組で包む（**唯一の実装変更**） |
| `docs/working/TASK-1012/**` | working context 一式 + evidence 配下（**`*` ではなく `**`**。`*` はセグメント境界で止まり evidence 配下に一致しない） |

## Testing Strategy

| 種別 | 内容 |
|------|------|
| **Integration** | 親（`PG_T26_NO_RECURSE` 未設定）と子相当（`=1`）の 2 系統 |
| **Regression** | フルスイート `sh tests/run-tests.sh` で 0 failed |
| **静的検査** | T-01 のシンボル越境検査 / TC-INV（`git diff -w` でゲート以外の内容変化 0） |
| **検出力の実証** | **変異 3 系統**（T-04）。①条件反転 → AC-2 が FAIL ②ゲート B 終端の縮小 → AC-1 が FAIL ③**ゲート外からゲート A 内変数を参照する 1 行を注入** → 越境検査が ≥1 件。③は当初「ヘルパー定義をゲート内へ移す」としていたが、**同関数の参照はすべてゲート B の内側（562-713）にあるため越境が発生せず空振り**だった（C-1 R3 が実測で検出）。人工的な外部参照の注入に変更し、検査そのものの検出力を直接実証する |

- Verification Automation: `sh tests/extras/ta-26-plugin-sync.sh </dev/null && PG_T26_NO_RECURSE=1 sh tests/extras/ta-26-plugin-sync.sh </dev/null && sh tests/run-tests.sh`

> `derive_loopspec()`（`scripts/ai-loop/plan_package.py` の L188）は「`Verification Automation:` の直後にバッククォート囲みのコマンド列が続く」形式で抽出する。この行が無いと `PlanPackageError` で fail-closed になり、宣言した C-3' 経路に入れない（TASK-0874 `plan.md:655-659` と同形式）。

## Risks & Mitigations

| リスク | 緩和 |
|-------|------|
| **ゲート内定義のシンボルをゲート外が参照して子が壊れる**（初版で実際に踏んだ） | T-01 で**シンボル越境 0 件**を機械確認し、T-04 変異③でその検査の検出力を実証 |
| ゲート範囲を誤り、親でも対象 TC がスキップされる | T-03（親のカバレッジ不変）+ T-04 変異① |
| ゲート範囲が狭すぎて子で重い TC が残る | T-03（子で非実行）+ T-04 変異② |
| **変異の復元が実装ごと消す** | T-02 で `git add` を必須化し、復元は `git checkout -- <file>`（index 経由）に固定。手順は todo に明記 |
| **変異①の一括置換が TC-13 のゲートまで反転させ孫プロセスを無限 spawn する** | 適用を**新規 2 ゲートに限定**（todo に明記） |
| 子のカバレッジが狭まることで将来の退行を見逃す | TC-13 の判定目的が standalone fallback の証明に限られることを根拠とし、handoff に**既知の妥協点**として明記 |
| 実行時間の改善が測定ノイズに埋もれる | T-05 で**交互 A/B**（連続測定にしない） |
| インデント調整で意図せず中身が変わる | T-02 の 🚩 で `git diff -w` の変化がゲート追加分のみであることを機械確認 |
| **今後 TC が追加され、またゲート範囲と依存が食い違う** | handoff の申し送りに、**ゲート境界の直後に TC を足すときは越境検査を再実行する**旨を明記 |

## Questions / Unknowns

| # | 内容 | 解消方法 |
|---|------|---------|
| U-1 | ゲート境界と、後から追加された TC（TC-35/36 = #970 / PR #1014）およびヘルパー定義の相互作用。**R-407 のプロトタイプは TC-35/36 追加前の tree で検証されており現 tree に対して有効でない** | **T-01 で解消**（シンボル越境 0 件の機械確認）。設計上はゲート 2 分割で回避済みだが実測で確定させる |
| U-2 | ゲート B に TC-35/36 を含めることが #970 の意図（symlink 集計の厳密一致検証）を損なわないか | 親では従来どおり実行されるため損なわない。T-03（親カバレッジ不変）で確定 |

## Mode 判定

判定結果: **standard**

**判定根拠**（定量は**全軸**を評価する — C-1 で軸の欠落が 2 度発生したため）:

| 判定軸 | 実測値 | 帯 |
|-------|-------|----|
| 変更ファイル数 | 1（実装） | 超低〜低 |
| 受入基準数 | **5**（AC-1〜AC-5） | **中** |
| **タスク数（見込み）** | **6**（T-01〜T-06） | **中** |
| 変更種別 | code（test のみ・production code 不変） | 低〜中 |
| リスク | 中（テスト意味論の変更を伴う） | **中** |
| 影響範囲 | 当該ファイルのみ | 低 |

定量・定性とも最大が「中」→ **standard**。承認境界パス外のため例外ルールによる引き上げなし。

### lite_eligible 判定

| 軸 | 値 | 根拠 |
|----|---|------|
| 変更ファイル数 | ✅ **1**（≤ `SIZE_OK_MAX_FILES`=2） | `ta-26-plugin-sync.sh` のみ |
| 新規設計の有無 | ✅ **なし** | L62-68 の既存ゲートと同一形を 2 箇所に適用するのみ。**ヘルパー関数を移動しないため「定義をどこへ置くか」の設計判断が発生しない** |
| 既存パターン踏襲 | ✅ **あり** | 同一ファイル内の同一イディオム・同一論拠 |
| 可逆性 | ✅ **あり** | `git revert` 1 手 |

→ **`lite_eligible=true`**（**計画時の C-3' 裁定に限る**）

> **成立範囲の注記**: `size_ok` が成立するのは **計画時の裁定のみ**。実装後の再裁定では実差分（実装 1 + working context 一式 + evidence）が `SIZE_OK_MAX_FILES`=2 を超えるため **priority 1.9 で human escalate する見込み**。これは仕様どおりの挙動であり、再裁定は Human 判断を前提とする。handoff にも明記する。

### 境界チェック

| 項目 | 判定 |
|------|------|
| Hardening Override 9 カテゴリ | **非該当**（`tests/extras/` は `scripts/hooks/check-plan-hash.sh` L124-134 のいずれにも含まれない） |
| ai-loop 判定基盤 carve-out | **非接触**（`scripts/ai-loop/**` / `docs/workflows/ai-loop/**` / `docs/ai/ai-loop/**` / `*/skills/ai-loop-cycle/**` のいずれでもない） |
| rollout-policy #780 slice C 前提 | **充足**。`scripts/ai-loop/arbiter.py` に `SIZE_OK_MAX_FILES = 2` の機械検証が実装済み。加えて**本変更は test のみで「実機能」ではない** |

**ゲート**: Human C-3 の代わりに **ai-loop の C-3' 裁定（`/ai-loop-cycle`）** を用いる。`arbiter.py` が `HUMAN_ESCALATED`（exit 2）を返した場合は**停止して人間へ提示**し、AI が自己解決しない。
