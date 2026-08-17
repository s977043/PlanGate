# 変異注入 evidence — TASK-1109 (#1109)

変異は **関数ではなく call site を壊す**。各変異は「適用 → FAIL 確認 → 復元 → PASS 確認」
の 4 手を踏み、復元は元ファイルのバックアップからのコピーで行い `diff` で同一性を確認した。

検証コマンド: `sh tests/extras/ta-68-skill-spec-presence.sh </dev/null`

| ログ | 状態 | 結果 |
|------|------|------|
| `m0-baseline.log` | 変異なし | 12 passed, 0 failed / rc=0 |
| `m1-applied.log` | **M-1** 適用 | 11 passed, **1 failed**（TC-03）/ rc=1 |
| `m1-restored.log` | M-1 復元 | 12 passed, 0 failed / rc=0 |
| `m2-applied.log` | **M-2** 適用 | 10 passed, **2 failed**（TC-05 / TC-06）/ rc=1 |
| `m2-restored.log` | M-2 復元 | 12 passed, 0 failed / rc=0 |
| `m3-applied.log` | **M-3** 適用 | 11 passed, **1 failed**（TC-07）/ rc=1 |
| `m3-restored.log` | M-3 復元 | 12 passed, 0 failed / rc=0 |

## 変異の内容

### M-1 — presence 検査を外す（旧実装の silent skip を復元）

`inspect()` の走査ループ（`has_yaml` を求めた直後の call site）に旧実装と同じ
`if not has_yaml: continue` を挿入する。

kill: **TC-03**。出力が `missing-yaml=0 / All skills PASS` に化けることまで
FAIL メッセージに残っている（= 「見ていないのに緑」の再現）。

### M-2 — `--warn-only` の rc=0 保証を壊す

shell 末尾の rc 方針ブロックを `exit "$_rc"` 1 行に置き換える。

kill: **TC-05**（violation ありの `--warn-only`）と **TC-06**（target 不在の `--warn-only`）。

### M-3 — target 不在ガードを無効化する

`inspect()` の `if not os.path.isdir(target):` を `if False:` にする。
`os.listdir` が `FileNotFoundError` を投げ、try/except が violation 化する。

kill: **TC-07**（`target directory not found` の名指しが消える）。
traceback は出ないため TC-08 は PASS のまま = **例外の握り方は正しく、
壊れたのは「不在をどう説明するか」だけ**であることが分かる。

## 空振りした変異（正直な記録）

**初版実装に対する M-2 は生き残った（12 TC 全 PASS）。**

初版は `--warn-only` の rc 方針を **python 側（`if not warn_only: sys.exit(1)`）と
shell 側（`if WARN_ONLY -eq 1; exit 0`）の 2 箇所**に持っていた。
shell 側だけを壊しても python 側が rc=0 を返し続けるため、テストは検出できなかった。

これは「テストが弱い」のではなく **契約が二重実装されていた**ことが原因である。
そこで実装を変更し、

- python = 「violation があれば必ず `exit 1`」（検出のみ）
- shell = 「`--warn-only` なら rc=0」（rc 方針のみ・**唯一の実装点**）

に分離した。この変更後に M-2 を再注入して TC-05 / TC-06 の kill を確認している
（上表の `m2-applied.log`）。空振りログは実装変更で意味を失ったため差し替えたが、
経緯は本節に残す。
