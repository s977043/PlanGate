# テストケース定義 — TASK-0914

> Plan: [`plan.md`](./plan.md) / ToDo: [`todo.md`](./todo.md) / C-2: [`review-external.md`](./review-external.md)
> 実装先: `tests/extras/ta-26-plugin-sync.sh`（既存 **16 TC**（TC-01〜13 / 15 / 16 / 17。TC-14 は欠番）に追記。**新規は TC-20 以降 = 14 本**（TC-20〜30 / 32 / 33 / 34）。TC 番号の非衝突は実測確認済み）
> baseline: main `90c313d` で `sh tests/run-tests.sh` = **430 passed / 0 failed**（実測）
> C-2 指摘 `R-301..R-309` / `R-350..R-354` + River Review `RV-M1..M4` / `RV-m1..m5` / `RV-i1` 反映済み

## 受入基準 → テストケース マッピング

| AC | 内容 | 対応 TC | 種別 |
|----|------|---------|------|
| AC-1 | 経路2（ai-loop refs）guard 発火 + exit 3 | TC-20, TC-21, TC-22, **TC-25** | Integration（負側 + dry-run 一致） |
| AC-2 | 経路1（汎用 refs）guard 発火 + exit 3 | TC-26, TC-27, **TC-32** | Integration（負側 + dry-run 一致） |
| AC-3 | 各経路の負側 + 正常系 TC が ta-26 に存在 | 負側: TC-20, TC-21, TC-22, TC-26, TC-27 / **正常系: TC-24, TC-29** / 境界: **TC-34** / dry-run 一致: TC-25, TC-32 / 検出力: M-1〜M-7（M-6b 含む） | Integration |
| AC-4 | override が全経路で一貫 | TC-23, TC-28 + 既存 TC-11（override 動作）+ 既存 TC-15（`.github/` に override フラグ非埋込） | Integration + 静的検査 |
| AC-5 | README.md に判別規約が明記 | TC-30 | 静的検査 |
| AC-6 | 11 extras 移行後、harness 444/0 + standalone が **①`[FAIL]` 不在 ②exit 0 ③`[PASS]` 件数が baseline 一致** | V-1-A | Verification Automation |
| AC-7 | **汚染 env 下**でも AC-6 の 3 条件と同結果 | V-1-B（`FIXTURES_DIR` 漏れ）+ **V-1-B'**（`PG_HARNESS_SOURCED` 単独漏れ） | Verification Automation |
| AC-8 | exit code 伝播欠落が別 issue として起票 + handoff に妥協点記録 | V-1-C | 成果物確認 |
| AC-9 | 単独判別の**残存 0**（件数ハードコードなし）+ unset 集合の包含（`ta-26` も対象） | **TC-33** | 静的検査 |
| （不変） | `sync_dir` 経路の挙動が共通関数化で変わらない | 既存 TC-08〜TC-17 全 PASS | Regression |

> **AC-3 は範囲指定をやめ個別列挙にした**（R-303c）。正常系 TC-24 / TC-29 が「形骸化防止」の裏付けとして明示的に AC-3 へ紐付く。

---

## テストケース一覧

### 経路2: ai-loop references（`_ai_loop_expected_refs` 駆動 / L316-329）

> **全 TC 共通の sandbox 要件（R-354）**: 経路2 は `_sync_ai_loop_ref_content` が `python3 "$AI_LOOP_LINK_REWRITER"` を可用性ガードなしで呼ぶため、**`scripts/_ai_loop_link_rewrite.py` を sandbox へ必ず同梱する**。不在だと guard ロジックと無関係な理由で TC が落ちる。

#### TC-20: 正本 2 ディレクトリ両方が消失 → guard 発火・削除保留

- **前提条件**: 最小構成 sandbox（`CHANGELOG.md` / `.claude-plugin/marketplace.json` を置かない）+ `scripts/_ai_loop_link_rewrite.py` 同梱。`plugin/plangate/skills/ai-loop-cycle/references/` に `*.md` を 5 件配置。`docs/workflows/ai-loop/` と `docs/ai/ai-loop/` を**両方削除**（= `_ai_loop_expected_refs` が空）
- **入力**: `sh scripts/sync-plugin-plangate.sh`（sandbox 内、DRY_RUN なし）
- **期待出力**: stderr に `DELETE skipped` + label（`skills/ai-loop-cycle/references` 相当）と `PLANGATE_ALLOW_MASS_DELETE=1` の案内。**dst の 5 件が全件残存**
- **種別**: Integration（負側 / #877 の実害と同型）

#### TC-21: 正本 2 ディレクトリが空化（ディレクトリは存在・中身なし） → guard 発火

- **前提条件**: TC-20 と同じ dst 構成。`docs/workflows/ai-loop/` と `docs/ai/ai-loop/` は**存在するが `*.md` を 0 件**にする
- **入力**: 同上
- **期待出力**: TC-20 と同一（ディレクトリ存在の有無で挙動が分岐しないこと＝`[ -d ]` ガードすり抜けの封鎖を証明）
- **種別**: Integration（負側・境界）

#### TC-22: guard 発火時に終端 exit 3

- **前提条件**: TC-20 と同じ
- **入力**: 同上。rc を `_rc=0; _out=$(sh ...) || _rc=$?` で捕捉
- **期待出力**: `_rc = 3`。かつ stderr に `mass-delete safety guard が発火` を含む
- **種別**: Integration（負側 / `guard_fired` の global 伝播をサブシェル問題ごと実証）

#### TC-23: `PLANGATE_ALLOW_MASS_DELETE=1` で override（経路2）

- **前提条件**: TC-20 と同じ
- **入力**: `PLANGATE_ALLOW_MASS_DELETE=1 sh scripts/sync-plugin-plangate.sh`
- **期待出力**: exit 0。stderr に `解除しました` を含む。**dst の 5 件が全件削除**
- **種別**: Integration（override）

#### TC-24: 正常系 — 1 件だけ正当に削除（guard 非発火・経路2）

- **前提条件**: `scripts/_ai_loop_link_rewrite.py` 同梱。正本に `*.md` を 4 件、dst に 5 件（うち 1 件が正本に無い stale）
- **入力**: `sh scripts/sync-plugin-plangate.sh`
- **期待出力**: exit 0。stale 1 件のみ `DELETE`、残り 4 件は保持。`DELETE skipped` を**含まない**
- **種別**: Integration（正常系 / 形骸化防止 = 正当な削減を block しないことの証明。検出力は M-6 で実証）

#### TC-25: dry-run と実行の判定一致（経路2・乖離帯）

- **前提条件**: `scripts/_ai_loop_link_rewrite.py` 同梱。base=3 / stale=4 の構成（#877 論点 B で旧式が乖離した帯）
- **入力**: `sh scripts/sync-plugin-plangate.sh --dry-run` と `sh scripts/sync-plugin-plangate.sh` の両方
- **期待出力**: 両者で guard の発火/非発火判定が**一致**する（dry-run は exit 0 維持・実行は exit 3）。`WOULD DELETE` と `DELETE` の判定が同じ集合を指す
- **種別**: Integration（境界 / dry-run 乖離の回帰防止）

### 経路1: 汎用 references（`_src_refs`/`_dst_refs` 突合 / L173-183）

#### TC-26: `_src_refs` 空化 → 当該 skill のみ guard 発火

- **前提条件**: 2 つの skill（skill-A / skill-B）を用意。skill-A は src `references/` が存在するが `*.md` 0 件、dst に 4 件。skill-B は src/dst 正常（同期対象 3 件）
- **入力**: `sh scripts/sync-plugin-plangate.sh`
- **期待出力**: skill-A の dst 4 件が全件残存 + `DELETE skipped` に skill-A の label。**skill-B は正常に同期される**（他 skill の処理が落ちない = `break` 誤用の封鎖）
- **種別**: Integration（負側 + 制御フロー）

#### TC-27: guard 発火時に終端 exit 3（経路1）

- **前提条件**: TC-26 と同じ
- **入力**: rc 捕捉付きで実行
- **期待出力**: `_rc = 3`
- **種別**: Integration（負側）

#### TC-28: `PLANGATE_ALLOW_MASS_DELETE=1` で override（経路1）

- **前提条件**: TC-26 と同じ
- **入力**: `PLANGATE_ALLOW_MASS_DELETE=1 sh scripts/sync-plugin-plangate.sh`
- **期待出力**: exit 0。skill-A の dst 4 件が全件削除。`解除しました` を含む
- **種別**: Integration（override）

#### TC-29: 正常系 — src に 3 件・stale 1 件（guard 非発火・経路1）

- **前提条件**: skill-A の src `references/` に 3 件、dst に 4 件（1 件 stale）
- **入力**: `sh scripts/sync-plugin-plangate.sh`
- **期待出力**: exit 0。stale 1 件のみ削除。`DELETE skipped` を含まない
- **種別**: Integration（正常系。検出力は M-6 で実証）

#### TC-32: dry-run と実行の判定一致（経路1・乖離帯） 🆕 R-303b

- **前提条件**: skill-A の src `references/` に 3 件、dst に 7 件（うち 4 件が stale）= base=3 / stale=4 の乖離帯
- **入力**: `sh scripts/sync-plugin-plangate.sh --dry-run` と `sh scripts/sync-plugin-plangate.sh` の両方
- **期待出力**: 両者で発火/非発火判定が**一致**（dry-run は exit 0 維持・実行は exit 3）。`WOULD DELETE` と `DELETE` が同じ集合を指す
- **種別**: Integration（境界）
- **追加理由**: plan Testing Strategy が「経路1/2 それぞれで 4 系統」と宣言していたのに経路1 の dry-run 一致が欠落していた。dry-run 乖離は #877 論点 B が正面から潰した性質で、片方だけ未検証だと「dry-run では安全に見えるが実行では全削除」という最も気付きにくい退行が残る

### R-204: harness 判別 / 規約

#### TC-30: `tests/extras/README.md` に判別規約が存在

- **前提条件**: なし（静的検査）
- **入力**: `grep -q 'PG_HARNESS_SOURCED' tests/extras/README.md` および「非 export」「AND」「standalone 側（安全側）」に相当する記述の存在確認
- **期待出力**: 全て検出（exit 0）
- **種別**: 静的検査（AC-5）

#### TC-33: 単独判別の残存 0 + unset 集合の包含 🆕 R-304 / R-306

- **前提条件**: なし（静的検査。**11 という件数をハードコードしない**）
- **入力**:
  1. `tests/extras/ta-*.sh` のうち `FIXTURES_DIR:-` を含み `PG_HARNESS_SOURCED` を含まないファイルを列挙
  2. `run-tests.sh` の `unset` 行から env 名集合を抽出し、`FIXTURES_DIR` 判別を持つ各 extras の standalone unset 集合が**それを包含**するか照合
- **期待出力**: 1 の列挙結果が **0 件**。2 の包含が全ファイルで成立
- **種別**: 静的検査（AC-9）
- **追加理由**: 「統一」は残存 0 という**全体性質**であり、個別ファイルの置換完了とは別命題。挙動テスト（AC-6/AC-7）は clean env なら単独判定が残っていても PASS するため残存を検出できない。件数固定だと将来/別ファイルの単独判定を取りこぼす

### TC-34: 境界 — base = stale（同数）で guard 非発火 🆕 RV-M4

- **前提条件**: skill-A の src `references/` に 3 件、dst に 6 件（うち **3 件が stale**）= base=3 / stale=3
- **入力**: `sh scripts/sync-plugin-plangate.sh`
- **期待出力**: exit 0。stale 3 件が削除され、src と一致する 3 件は保持。`DELETE skipped` を**含まない**（`stale > base` が偽なので非発火が正しい）
- **種別**: Integration（境界 / 形骸化防止）
- **追加理由**: 閾値の `>` を `>=` に 1 段ずらす変異（M-6b）を検出できる fixture が既存 TC に存在しなかった（乖離帯は stale=base+1 のため）。E-3 の「`base = stale` は TC 不要」判断を撤回して新設

> **TC-31 は撤回**（R-307）。既存 TC-15（`.github/` に override フラグ非埋込）と同内容の再掲で二重管理になるため、AC-4 のマッピング表から既存 TC-15 を参照する形へ変更した。

---

## 変異注入（検出力の実証・必須）

新規 TC が空振り fixture でないことを証明する。**変異を注入した実装に対して該当 TC が FAIL することを確認**してから TC を受理する。
**guard 弱体化方向（M-1〜M-5）だけでは負側 TC しか実証できない**ため、過剰発火方向（M-6）と override 無効化（M-7）を必須に含める（R-305）。

| ID | 変異内容 | 対象 TC | 期待 | 実証対象 |
|----|---------|---------|------|---------|
| M-1 | 経路2 の guard 呼び出しを削除（**`git show 90c313d:scripts/sync-plugin-plangate.sh`** の該当ブロックへ戻す。`HEAD:` は exec 中に移動して非決定論になる — RV-i1） | TC-20, TC-21, TC-22 | **FAIL**（dst 全削除・exit 0 になる） | 負側 |
| M-2 | 経路1 の guard 呼び出しを削除 | TC-26, TC-27 | **FAIL** | 負側 |
| M-3 | 閾値を `stale > base` → `stale > base + 100` に改変（発火しなくなる方向） | TC-20, TC-26 | **FAIL** | 負側 |
| M-4 | `guard_fired=1` の代入をサブシェル `$( )` 内へ移す | TC-22, TC-27 | **FAIL**（exit 3 にならず 0 になる） | 負側（silent failure） |
| M-5 | **経路1 の skip の粒度を「当該 skill の references 削除のみ」から「skill ループ全体の中断」へ変える**（実装が `continue` か `if` ネストかに依存しない振る舞い記述 — RV-M4③） | TC-26 | **FAIL**（skill-B が同期されない） | 制御フロー |
| **M-6** | `_mass_delete_blocked` を**常に blocked 返却**に改変＝**過剰発火**方向 | **TC-24, TC-29 のみ** | **FAIL**（正当な 1 件削除が block される） | **正常系（形骸化防止）** |
| **M-6b** 🆕 | 閾値を `stale > base` → **`stale >= base`** に改変（境界の 1 段だけ過剰発火） | **TC-34** | **FAIL**（base=stale で発火してしまう） | **境界（形骸化防止）** |
| **M-7** | `_mass_delete_blocked` 内の `PLANGATE_ALLOW_MASS_DELETE` 判定行を削除 | TC-23, TC-28 | **FAIL** | **override（AC-4）** |

### M-6 / M-6b の対象 TC を絞った理由（RV-M4）

- **M-6 に TC-25 / TC-32 を含めてはいけない**: この 2 件は base=3 / stale=4 = **guard が発火する帯**の fixture であり、期待出力は「dry-run exit 0 / 実行 exit 3 で判定一致」。`_mass_delete_blocked` が常に blocked を返しても両モードで発火するため期待どおり **PASS のまま**になり、「期待 FAIL 不出」として RT-3 / Stop Condition 3 を誤発火させる
- **`stale >= base` 変種は M-6 から分離して M-6b とし、専用 fixture（TC-34）を用意する**: 挙動が変わるのは `stale == base` のときだけで、乖離帯（stale = base+1）を突く既存 TC ではどれも FAIL しない。E-3 の「`base = stale` は TC 不要」判断を撤回して TC-34 を新設した

M-1〜M-7（M-6b 含む計 8 変異）の実行ログは `evidence/test-runs/` へ保存する。**M-6 / M-6b は plan Risks 表の最上位リスク（閾値誤りによる形骸化）の mitigation が空振りでないことを保証する唯一の手段**。

---

## Verification Automation（AC-6 / AC-7 / AC-8 / AC-9）

> ⚠️ **3 つの注意点**（いずれも実測で顕在化した欠陥の是正）:
>
> 1. **V-1-A と V-1-B はループを別々に定義する**（R-302）。V-1-A の `env -u` を V-1-B に流用すると注入した汚染が実行直前に剥がされ、**AC-7 の検出力がゼロになる**（実害の主因 `PLANGATE_HOOK_TASK` がまさに `-u` 対象）。
> 2. **`sh "$f"` は必ず `</dev/null` を付ける**（RV-M1）。`ta-50-precompact-guard.sh` が起動する `scripts/precompact-memory-guard.sh` は非 tty stdin のとき `cat` で EOF まで読むため、リダイレクトなしだと**無限ハングする**（10 秒監視で実測確認）。`sh tests/run-tests.sh` は source 型で `[ -t 0 ]` の条件が変わるため 430/0 を通り、**この故障は standalone ループでのみ顕在化する**。
> 3. **汚染注入で `PG_HARNESS_SOURCED` と `FIXTURES_DIR` を同時に立ててはいけない**（RV-M2）。移行後の判別式は AND なので両方揃うと **harness 分岐へ入り** ROOT 解決が壊れて全 TC が消える（実測: ta-39 が PASS=0 / baseline 8）。この結果は移行前後で同一なので、AC-7 が原理的に達成不能になり RT-4 が誤発火する。単独注入は V-1-B' に分離する。

### V-1-A: AC-6 — clean env での standalone 実行（3 条件）

```sh
cd "$(git rev-parse --show-toplevel)"   # 相対 glob のため cwd を repo root に固定（RV-i1）
# baseline は T-01 で実測した「ファイル名 → [PASS] 件数」の表を参照する
for f in tests/extras/ta-39-*.sh tests/extras/ta-43-*.sh tests/extras/ta-44-*.sh \
         tests/extras/ta-45-*.sh tests/extras/ta-46-*.sh tests/extras/ta-47-*.sh \
         tests/extras/ta-49-*.sh tests/extras/ta-50-*.sh tests/extras/ta-51-*.sh \
         tests/extras/ta-52-*.sh tests/extras/ta-53-*.sh; do
  out=$(env -u PLANGATE_HOOK_TASK -u PLANGATE_HOOK_FILE -u PG_HARNESS_SOURCED \
            -u FIXTURES_DIR -u PLANGATE_ALLOW_MASS_DELETE sh "$f" </dev/null 2>&1); rc=$?
  n_pass=$(printf '%s\n' "$out" | grep -c '\[PASS\]' || true)   # 0 件で rc=1 になるため || true
  case "$out" in *"[FAIL]"*) echo "NG(FAIL detected): $f";; esac      # 条件①
  [ "$rc" = "0" ] || echo "NG(rc=$rc): $f"                            # 条件②
  echo "COUNT $f=$n_pass"                                             # 条件③ baseline と照合
done
```

**期待**: `NG` が 1 件も出力されない **かつ** 全ファイルの `COUNT` が T-01 baseline と一致。加えて `sh tests/run-tests.sh` が `444 passed, 0 failed`（430 + 新規 14 TC）。

> 条件③がないと「置換ミスで standalone 分岐に入らず 1 件も実行せず exit 0」でも PASS してしまう（R-301）。判別式そのものを触る変更なので、この故障モードが本命。

### V-1-B: AC-7 — 汚染 env での standalone 実行（**独立したループ / `FIXTURES_DIR` 側の漏れ**）

```sh
cd "$(git rev-parse --show-toplevel)"
for f in tests/extras/ta-39-*.sh tests/extras/ta-43-*.sh tests/extras/ta-44-*.sh \
         tests/extras/ta-45-*.sh tests/extras/ta-46-*.sh tests/extras/ta-47-*.sh \
         tests/extras/ta-49-*.sh tests/extras/ta-50-*.sh tests/extras/ta-51-*.sh \
         tests/extras/ta-52-*.sh tests/extras/ta-53-*.sh; do
  out=$(env PLANGATE_SKIP_REASON=x PLANGATE_HOOK_TASK=TASK-9999 \
            PLANGATE_HOOK_FILE=/nonexistent/x.md PLANGATE_BYPASS_HOOK=1 \
            PLANGATE_HOOK_STRICT=1 PLANGATE_ALLOW_MASS_DELETE=1 \
            FIXTURES_DIR=/nonexistent/fixtures sh "$f" </dev/null 2>&1); rc=$?
  n_pass=$(printf '%s\n' "$out" | grep -c '\[PASS\]' || true)
  case "$out" in *"[FAIL]"*) echo "NG(FAIL detected): $f";; esac
  [ "$rc" = "0" ] || echo "NG(rc=$rc): $f"
  echo "COUNT $f=$n_pass"
done
```

- **注入する env は 6 件**（論点 F の 7 env のうち `PG_HARNESS_SOURCED` を除く全件 — RV-m1 で 5 件から拡張）。`PG_HARNESS_SOURCED` は AND の片側なので V-1-B' で単独検証する（RV-M2）
- **期待**: V-1-A と**完全に同一の結果**（NG ゼロ・COUNT 一致）
- **検出力の証明（T-01 で先に実施）**: 移行**前**に同じループを流すと `FIXTURES_DIR` 単独判定が harness と誤判定して ROOT が壊れ **NG が出る**。移行後は AND の片側が欠けるため standalone 側（安全側）へ倒れて NG が消える。ログは `evidence/test-runs/` へ保存

### V-1-B': AC-7 — `PG_HARNESS_SOURCED` 単独漏れ（第 3 ループ / RV-M2）

```sh
cd "$(git rev-parse --show-toplevel)"
for f in <V-1-A と同じ 11 本の glob>; do
  out=$(env PG_HARNESS_SOURCED=1 -u FIXTURES_DIR sh "$f" </dev/null 2>&1); rc=$?
  ...  # 判定は V-1-A と同一の 3 条件
done
```

> `FIXTURES_DIR` を注入しないこと（AND の他方が欠けるので standalone 側へ倒れるのが正しい挙動）。上記 `<...>` は V-1-A のファイルリストをそのまま使う。

**期待**: V-1-A と同一結果（NG ゼロ・COUNT 一致）。**移行前もこのケースは NG が出ない**（`FIXTURES_DIR` 単独判定は `PG_HARNESS_SOURCED` を見ないため）ので、これは**回帰防止（移行後に壊れないこと）専用**であり検出力の証明対象ではない。

### V-1-C: AC-8 — 別 issue の起票 + handoff 記録の確認

`gh issue view <番号>` で本文に「standalone exit code 伝播」「`exit $fail` 欠落」「ta-39 の実測」が含まれることを確認。あわせて handoff.md の「妥協点」に R-309 の 2 点（2 回触るコスト / 代理判定の恒久化）と follow-up issue 番号が記録されていることを確認。

---

## エッジケース

| # | ケース | 扱い |
|---|--------|------|
| E-1 | 正本の片方だけが消失（`docs/workflows/ai-loop/` のみ消失、`docs/ai/ai-loop/` は健全） | 期待集合は部分的に残るため base > 0。stale との比較次第で発火/非発火が決まる。**閾値の意味どおりの挙動**であり TC-24 の正常系と TC-20 の負側の中間帯。plan 論点 C のとおり専用閾値は設けない |
| E-2 | dst の references ディレクトリ自体が存在しない | 既存 `[ -d ]` ガードでループに入らない → guard 判定にも到達しない（削除ゼロ = 安全）。TC 不要 |
| E-3 | base = stale（同数） | `stale > base` が偽 → 非発火（削除実行）。**TC-34 で専用 fixture を持つ**（RV-M4。乖離帯 fixture は stale=base+1 なので `stale >= base` への 1 段ずれを検出できなかった） |
| E-4 | `plugin/plangate/skills/*/references/README.md` が存在する場合 | **C-2 で実測解消**（R-353）: 経路1 の対象 skill（skill-creator / review-gate）の src 側には不在 → D-2 維持。`ai-loop-cycle/references/README.md` は経路2 が `_ai_loop_spec_files` で正規同期する対象で D の判断対象外 |
| E-5 | `set -- $_ai_loop_expected_refs` が位置パラメータを破壊 | **C-2 で実測解消**（U-2）: 後段の `$@` / `shift` / `set --` 使用は 0 件（`$1` は L10 の `--dry-run` のみ）→ 安全 |
| E-6 | 11 本のうち harness 実行時に `unset` が漏れて harness の env を壊す | `unset` は else 節（standalone 分岐）の内側のみ。`sh tests/run-tests.sh` 430/0 の維持で担保（T-07 🚩） |
| **E-7** 🆕 | 経路1 の `references/` に symlink が存在する場合 | コピーループ（L163）は `[ -L ]` で除外するため、集計側も同一条件で除外しないと「N 件と数えて M 件消す」= #861 再発型の guard 無効化になる（R-351 / 論点 D'-2）。現状 symlink は 0 件で顕在化しないが、Step 3 実装時に集計ループへ `[ -L "$_rf" ] && continue` を必ず入れる。TC で直接は覆わず**実装レビュー観点として V-3 へ引き継ぐ** |
| **E-8** 🆕 | 11 本の失敗表記が `[FAIL]` で統一されていない本がある | T-01 の grep 実測で確認（U-4）。非統一なら AC-6 条件①の判定語彙を拡張して本ファイルを更新する |

## 自動化可否

| TC | 自動化 | 備考 |
|----|--------|------|
| TC-20〜TC-29, TC-32, TC-34 | ✅ 可 | ta-26 の sandbox パターンで完全自動化 |
| TC-30, TC-33 | ✅ 可 | grep ベースの静的検査（TC-33 は件数ハードコードなし） |
| M-1〜M-7（M-6b 含む計 8） | ⚠️ 半自動 | 変異は手動注入 → TC 実行は自動。ログを evidence へ保存 |
| V-1-A, V-1-B, V-1-B' | ✅ 可 | 上記 3 ループ。**別々に定義**し `</dev/null` + `cd` repo root を必ず含めて status.md に記録し V-1 で再実行 |
| V-1-C | ❌ 手動 | issue 起票内容 + handoff 記録の確認 |
| E-7（symlink 対称性） | ❌ 手動 | 実装レビュー観点として V-3 へ引き継ぐ |
