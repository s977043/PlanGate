# 変異注入 M2b による検出力の実証 — TASK-1180 / AC-2

変異 M2b: `scripts/check-skill-name-collisions.py:188` の
`return len({d.intra_root_path for d in defs}) == 1` を `return True` に置換
（= 条件④ `_same_intra_root_path` を無効化）。**commit していない**（測定後 `git checkout --` で revert）。

## 1. 修正前 baseline（変異なし）

```
$ bash tests/extras/ta-69-distribution-checks.sh
  [PASS] TC-C6: same name at non-mirrored paths -> rc=1
TA-69 standalone: 27 passed, 0 failed
```

## 2. 修正前 + 変異 M2b → **SURVIVE**（検出力ゼロの証拠）

```
$ bash tests/extras/ta-69-distribution-checks.sh
  [PASS] TC-C6: same name at non-mirrored paths -> rc=1
TA-69 standalone: 27 passed, 0 failed
```

条件④を潰しても全テストが緑のまま。TC-C6 は条件③（非 export plugin）で rc=1 になっていた。

## 3. 修正後（fixture を `plugin/plangate/skills` へ）+ 変異 M2b → **KILL**

```
$ bash tests/extras/ta-69-distribution-checks.sh
  [FAIL] TC-C6: expected rc=1 for a non-mirrored same-name pair, got 0
TA-69 standalone: 26 passed, 1 failed
```

## 4. 変異 revert 後（修正のみ）

```
$ git checkout -- scripts/check-skill-name-collisions.py
$ sed -n '188p' scripts/check-skill-name-collisions.py
    return len({d.intra_root_path for d in defs}) == 1
$ bash tests/extras/ta-69-distribution-checks.sh
  [PASS] TC-C6: same name at non-mirrored paths -> rc=1
TA-69 standalone: 27 passed, 0 failed
$ git diff --name-only
docs/working/_audit/skip-decision-log.jsonl
tests/extras/ta-69-distribution-checks.sh
```

（`skip-decision-log.jsonl` は本セッション開始時点で既に変更されていた他者の作業分。commit 対象に含めない）

## 独立再現

W チェックの 2 体（Model A / Model B）が本手順を**独立に再実行**し、同じ SURVIVE → KILL の遷移を確認している。
