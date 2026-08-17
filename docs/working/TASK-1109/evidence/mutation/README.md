# 変異注入 evidence — TASK-1109 (#1109)

変異は **関数ではなく call site を壊す**。各変異は「適用 → FAIL 確認 → 復元 → PASS 確認」
の 4 手を踏み、復元は元ファイルのバックアップからのコピーで行い `diff` で同一性を確認した。

検証コマンド: `sh tests/extras/ta-68-skill-spec-presence.sh </dev/null`
baseline: **17 passed, 0 failed / rc=0**（v2。V-3 REJECT 反映後）

| ログ | 状態 | 結果 |
|------|------|------|
| `m0-baseline.log` | 変異なし | 17 passed, 0 failed / rc=0 |
| `m1-applied.log` | **M-1** 適用 | 14 passed, **3 failed**（TC-03 / TC-14 / TC-17）/ rc=1 |
| `m1-restored.log` | M-1 復元 | 17 passed, 0 failed / rc=0 |
| `m2-applied.log` | **M-2** 適用 | 15 passed, **2 failed**（TC-05 / TC-06）/ rc=1 |
| `m2-restored.log` | M-2 復元 | 17 passed, 0 failed / rc=0 |
| `m3-applied.log` | **M-3** 適用 | 15 passed, **2 failed**（TC-07 / TC-15）/ rc=1 |
| `m3-restored.log` | M-3 復元 | 17 passed, 0 failed / rc=0 |
| `ma-applied.log` | **M-A** 適用（V-3 レビューア由来） | 14 passed, **3 failed**（TC-02 / TC-13 / TC-16）/ rc=1 |
| `ma-restored.log` | M-A 復元 | 17 passed, 0 failed / rc=0 |
| `mb-applied.log` | **M-B** 適用（V-3 レビューア由来） | 16 passed, **1 failed**（TC-14）/ rc=1 |
| `mb-restored.log` | M-B 復元 | 17 passed, 0 failed / rc=0 |
| `mc-extra-file.log` | **M-C**（非注入・skills root にファイル 1 枚追加） | **17 passed, 0 failed / rc=0**（時限爆弾が消えたことの実証）|

## 変異の内容

### M-1 — presence 検査を外す（旧実装の silent skip を復元）

`inspect()` の走査ループ（`has_yaml` を求めた直後の call site）に旧実装と同じ
`if not has_yaml: continue` を挿入する。

kill: **TC-03**（明示 target）/ **TC-14**（既定経路）/ **TC-17**（root 区別）。

### M-2 — `--warn-only` の rc=0 保証を壊す

shell 末尾の rc 方針ブロックを `exit "$_rc"` 1 行に置き換える。

kill: **TC-05**（violation ありの `--warn-only`）と **TC-06**（target 不在の `--warn-only`）。

### M-3 — target 不在ガードを無効化する

`inspect()` の `if not os.path.isdir(target):` を `if False:` にする。
`os.listdir` が `FileNotFoundError` を投げ、try/except が violation 化する。

kill: **TC-07**（明示 target の名指し）/ **TC-15**（既定 root 不在の名指し）。
traceback は出ないため TC-08 は PASS のまま = **例外の握り方は正しく、
壊れたのは「不在をどう説明するか」だけ**であることが分かる。

### M-A（V-3 レビューア由来）— 宣言した既定 root を不在パスへ差し替える

`DEFAULT_TARGETS` の 1 行目を `.codex/skills-MUTANT-ABSENT` にする
（#1086 で `.codex/skills` が消えた後の状態を再現）。

**v1 では 12/12 PASS で生存した。** v2 では
kill: **TC-02**（実リポジトリ既定 rc=0）/ **TC-13**（fixture repo 既定経路）/
**TC-16**（既定出力に 2 root が両方現れる）。

### M-B（V-3 レビューア由来）— 既定経路の presence 検査だけ無効化する

`for name in missing:` → `for name in (missing if explicit else []):`。

**v1 では 12/12 PASS で生存した**（負側 TC が全て `--target` 経由だったため）。
v2 では kill: **TC-14**（fixture repo の既定経路で欠落を検出する TC）。

### M-C（V-3 レビューア由来・非注入）— skills root にファイルを 1 枚追加

`plugin/plangate/skills/ZZZ-tmp-note.txt` を置いて `ta-68` を実行する。

**v1 では TC-10 が FAIL した**（`ignored=1` という絶対件数を契約値にしていたため、
無関係 PR の Test CI を落とす時限爆弾）。
v2 では **17/17 PASS**（`ignored` の summary 合計 2 と行数 2 の同値照合に置換）。

## 空振りした変異（正直な記録）

| 版 | 変異 | 結果 | 原因と是正 |
|----|------|------|-----------|
| v1 初版 | **M-2** | **生存**（12 TC 全 PASS） | `--warn-only` の rc 方針が python と shell に**二重実装**され、片方の破壊を他方が隠していた。rc 方針の実装点を shell 1 箇所へ集約して解消 |
| v1 提出版 | **M-A** | **生存**（12 TC 全 PASS） | 「既定 root の不在は violation にしない」設計 + 既定経路の TC 不足。v2 で fail-closed 化し TC-13/15/16 を追加 |
| v1 提出版 | **M-B** | **生存**（12 TC 全 PASS） | 負側 TC が全て `--target` 経由で、**CI が実際に通る既定経路の検出力がゼロ**だった。v2 で fixture repo 経由の TC-14 を追加 |

**教訓**: 自分の変異セット（M-1/M-2/M-3）が全部 kill でも、変異の**経路が偏っていれば
穴は露出しない**。M-1 は `--target` 経路で kill されており、既定経路の穴を隠していた。
「どの call site を壊したか」だけでなく「**どの実行経路を通る TC が kill したか**」まで
見ないと、検出力の証明にならない。
