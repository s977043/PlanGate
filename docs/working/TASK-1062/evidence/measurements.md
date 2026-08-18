# TASK-1062 生計測ログ

計測環境は `../investigation.md` §0 を参照。すべて worktree
`.claude/worktrees/agent-ac27753a3527d0f94` 内で実行。

## 並走チェック

各計測の直前に `pgrep -f 'ta-61|run-tests.sh'` を実行し rc=1（該当なし）を確認した。

> **注意（後から判明した落とし穴）**: `pgrep -f 'ta-61|run-tests.sh'` は
> **自分自身のラッパーシェルのコマンドライン**に含まれるパターン文字列に
> マッチして false positive を出すことがある。確定判定には
> `ps -eo pid,command | grep -E 'sh .*(run-tests|ta-2[0-9]|ta-6[0-9])'` を使うこと。
> 本セッションで実際に、自分の 2 ジョブが重なっていたのを `pgrep` では
> 検知できず `ps` で発見した（該当データは下記で除外済み）。

## 1. `ta-62` 実行回数（決定論的・カウンタ実測）

`pg_extra_contract_init` 直後に `PG_T62_COUNT_FILE` への追記を一時的に仕込み、
フルスイートを完走させて行数を数えた（計測後に revert 済み）。

### 現状（`standalone-capable`）

```
=== full suite [base] rc=0 elapsed=1147s ===
Results: 776 passed, 0 failed
ta-62 invocations counted: 7
   1 invoked mode=harness    dir=<repo>/tests/extras
   3 invoked mode=standalone dir=<repo>/tests/extras
   3 invoked mode=standalone dir=/var/folders/.../tmp.NwP83I1aNK/sandbox/repo/tests/extras
```

### 案 (a) 試作（`harness-only`）

```
=== full suite [opt_a] rc=1 elapsed=969s ===
Results: 773 passed, 1 failed
ta-62 invocations counted: 1
   1 invoked mode=harness    dir=<repo>/tests/extras
```

失敗行:

```
[FAIL] TC-D 同値照合不成立 (rc_leak=0 rc_clean=142 期待0/0 / diff一致=0 期待1 /
       leak側再帰防止SKIP=0 期待0 / clean側PASS行=4 期待>=1): 7,35c7;...
```

`142` = `perl -e 'alarm 180'` の SIGALRM。詳細は `../investigation.md` §5。

案 (a) で新たに非 vacuous 化した被覆（同 run より）:

```
[PASS] TC-11: ta-62-t26-recurse-env-guard direct execution rejected (rc=2 + id-bearing message)
```

（現状は harness-only が 0 件のため `ta-61` TC-11 は
`vacuous PASS (recorded, not hidden)` の info 行しか出ていない。）

## 2. `ta-62` 単体の所要

```
# セッション序盤 (09:36頃) / standalone
run1 rc=0 elapsed=89s
run2 rc=0 elapsed=86s
run3 rc=0 elapsed=95s

# セッション終盤 (10:30頃) / harness (mini-runner)
run1 rc=0 elapsed=166s
run2 rc=0 elapsed=188s
run3 rc=0 elapsed=215s
run4 rc=0 elapsed=304s   <- 自分の別ジョブと重なっていたため除外
```

### 対照実験（並走ゼロ・連続・同一時刻帯）

```
CLEAN standalone rc=0 elapsed=206s : TA-62 standalone: 2 passed, 0 failed
CLEAN harness    rc=0 elapsed=207s : MINI-RESULT: 2 passed, 0 failed
```

→ 2 経路のコストは同一。89 秒 → 206 秒の差は**測定時刻による環境劣化**。

## 3. `ta-26` 単体の所要と内訳

```
ta-26 standalone run1 rc=0 elapsed=68s
ta-26 standalone run2 rc=0 elapsed=50s
ta-26 standalone run3 rc=0 elapsed=50s
```

出力行にタイムスタンプを打って TC 間の差分を取った内訳（上位、秒）:

```
20.10  TC-13 PG_HARNESS_SOURCED で harness/standalone を判別  <- ta-26 を子として 2 回起動
 6.42  TC-05 sandbox 実行後 ...
 5.94  TC-04 --dry-run がファイルを変更しない
 5.57  TC-03 --dry-run が exit 0 で正常終了
 1.33  TC-33 ...
 0.90  TC-25 ...
 (以下 28 TC は合計 6 秒程度)
```

`ta-62` 89 秒 ≒ 2 × 44 秒 → **`ta-62` のコストはほぼ全部 TC-D の `ta-26` 2 本**。

## 4. 実装した変更の検証

### 変異注入（新設 timeout 分岐が本当に発火するか）

`_T62_TIMEOUT` を 180 → 1 に落として実行:

```
[PASS] TC-S ...
[FAIL] TC-D driver run TIMED OUT (>1s / rc_leak=142 rc_clean=142) — 同値照合は未実施。FAIL 扱い（SKIP にしない）。...
MINI-RESULT: 1 passed, 1 failed
```

→ 新分岐が発火し、旧実装が出していた誤診断（「同値照合不成立」+ 途中で切れた
diff 断片）ではなく正しい診断が出ることを実物で確認。`_T62_TIMEOUT` を 180 に
戻して再実行し、通常経路が PASS することも確認（下記）。

### 変更後の通常経路

```
sh -n tests/extras/ta-62-t26-recurse-env-guard.sh   -> rc=0
CLEAN standalone rc=0 : TA-62 standalone: 2 passed, 0 failed
CLEAN harness    rc=0 : MINI-RESULT: 2 passed, 0 failed
```

### patch の妥当性

```
git apply --check docs/working/TASK-1062/evidence/option-a-harness-only.patch     -> rc=0
git apply --check docs/working/TASK-1062/evidence/option-b-timeout-minutes.patch  -> rc=0
```

いずれも **`--check` のみ。適用していない。**

## 5. 未完了・未実施の測定（正直な記録）

- **案 (a) 適用後のフルスイートを、劣化後の環境で再測定していない。**
  現レート（`ta-62` 1 本 206 秒）だとフルスイート 1 回が 30 分超になる見込みで、
  1 回 15 分目安の計測予算を超えるため。よって
  「(a) 適用後のフルスイート秒数」の同一条件対照値は存在しない。
  削減根拠は実行回数 7 → 1（決定論的）に置く。
- **CI (ubuntu-latest) 上での実測は行っていない。** ローカル値からの外挿のみ。
