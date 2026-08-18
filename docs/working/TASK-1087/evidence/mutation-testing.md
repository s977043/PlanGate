# Evidence: 変異注入による検出力の実証（TASK-1087 / AC-11）

> 測定日: 2026-08-18 / base commit: `f219680`
> 手順: 各変異を **作業ツリーの実ファイルに適用** → `sh tests/extras/ta-69-distribution-checks.sh`
> を実走 → 結果を記録 → `git checkout -- <file>` で復元。
> 準拠: `.claude/skills/diff-audit/SKILL.md` Phase 6 item 6〜8

## 方針（diff-audit Phase 6 item 6）

- 変異は**関数定義ではなく call site を壊す**
- **「レーン全体を落とす変異」だけで済ませない** — レーンごと殺す変異では
  レーン内部の分類ミスは原理的に検出できないため、
  **分岐・レーン内部の分類を誤らせる変異を別に立てる**
- **空振り（適用しても PASS のまま）なら正直に記録する**

## 結果サマリ

| ID | 系統 | 変異した call site | kill された TC | 判定 |
|----|------|------------------|---------------|------|
| **M1** | レーン全体（collisions） | `run_scan`: `[c for c in collisions if not c.is_export_mirror]` → `if False` | TC-C4 / TC-C5 / TC-C6 / TC-C7（**4 件**） | ✅ kill |
| **M2a** | レーン内部（collisions） | `is_export_mirror`: `_has_exactly_two(defs)` → `True` | **なし** | ⚠️ **空振り** |
| **M2b** | レーン内部（collisions） | `is_export_mirror`: `_same_intra_root_path(defs)` → `True` | **TC-C6 のみ** | ✅ kill（精密） |
| **M2c** | レーン内部（collisions） | `is_export_mirror`: `_has_repo_local_and_single_plugin(defs)` → `True` | **TC-C5 のみ** | ✅ kill（精密） |
| **M3** | レーン内部（stale） | `run_scan`: `if rel_target in ignored` → `if False`（何も除外しない） | TC-S7 / TC-S1（**2 件**） | ✅ kill |
| **M3b** | レーン全体（stale） | `run_scan`: `gitignored_paths(...)` → `{f[3] for f in findings}`（全部除外） | TC-S4 / TC-S5 / TC-S8 / TC-S9（**4 件**） | ✅ kill |
| **M4** | レーン内部（stale） | `extract_candidates`: `MD_LINK_RE.finditer("".join(masked))` → `finditer(text)` | TC-S6 / TC-S1 + **selftest**（**3 件**） | ✅ kill |

**レーン全体（M1 / M3b）とレーン内部（M2b / M2c / M3 / M4）の両方で kill を実証した。**

## 実行ログ

### M1 — レーン全体（collisions の分類を全部ミラー扱いにする）

```
  [FAIL] TC-C4: expected rc=1 for 3 definitions of one name
  [FAIL] TC-C5: expected rc=1 for plugin-vs-plugin collision
  [FAIL] TC-C6: expected rc=1 for a non-mirrored same-name pair
  [FAIL] TC-C7: expected rc=1 for a same-root duplicate
TA-69 standalone: 13 passed, 4 failed
```

「ミラー除外が広すぎれば真の衝突が通る」ことを 4 クラスすべてで検出できる。

### M2b — レーン内部（root 内相対パス一致の条件だけを落とす）

```
  [FAIL] TC-C6: expected rc=1 for a non-mirrored same-name pair
TA-69 standalone: 16 passed, 1 failed
```

**TC-C6 だけが落ちる。** レーン全体変異では区別できない
「非ミラー位置での同名」の分類ミスをピンポイントで捕捉している。

### M2c — レーン内部（repo-local + 単一 plugin の条件だけを落とす）

```
  [FAIL] TC-C5: expected rc=1 for plugin-vs-plugin collision
TA-69 standalone: 16 passed, 1 failed
```

**TC-C5 だけが落ちる。** plugin 同士の同名を「ミラー」と誤分類する穴を捕捉。
TC-C4（3 定義）は `_has_exactly_two` が、TC-C7（同一 root 重複）は
`_same_intra_root_path` が引き続き守るため落ちない
= **条件どうしが相互に補強している**ことも同時に示している。

### M2a — レーン内部（「定義がちょうど 2 つ」の条件だけを落とす）→ **空振り**

```
TA-69 standalone: 17 passed, 0 failed
SELFTEST PASS (28 checks)
```

**kill されなかった。正直に記録する。**

**原因は TC の欠陥ではなく実装側の論理的冗長性**である。
`root_label()` は必ず `"repo-local"` か `"plugin:<p>"` のどちらかを返す
（未知構造は `"repo-local"` にフォールバックする）。したがって
`_has_repo_local_and_single_plugin` の
「repo-local がちょうど 1 つ **かつ** plugin がちょうど 1 つ」が成り立つとき、
**定義数は必然的に 2 になる**。`_has_exactly_two` は
現在の `root_label` の値域のもとで **strictly redundant**。

**対応: 条件は残す（削らない）。**
`root_label` に第 3 のラベル種別が将来導入された場合、
`_has_exactly_two` は load-bearing に変わる。
「変異が kill されないから安全条件を削る」のは検査を弱める方向であり、
本 PBI の趣旨に反する。冗長であること自体は害がない。

> 参考: M2c の結果が示すとおり、`_has_repo_local_and_single_plugin` を壊すと
> **`_has_exactly_two` が TC-C4 を守る側に回る**。つまり片方を壊した状態では
> もう片方が load-bearing になる。冗長なのは「両方健全なとき」に限られる。

### M3 — レーン内部（gitignore 除外を一切効かせない）

```
  [FAIL] TC-S7: expected rc=0 + INFO for a gitignored path
  [FAIL] TC-S1: expected rc=0 on the production tree
TA-69 standalone: 15 passed, 2 failed
```

除外が実際に本番経路で効いていることを実証（TC-S1 が本番ツリーで落ちる）。

### M3b — レーン全体（stale を全部除外して握り潰す）

```
  [FAIL] TC-S4: expected rc=1 for a genuinely stale markdown link
  [FAIL] TC-S5: expected rc=1 for a stale inline-code path
  [FAIL] TC-S8: expected rc=1 for a typo that no ignore pattern matches
  [FAIL] TC-S9: expected rc=1 (no exclusion) without git, got 0
TA-69 standalone: 13 passed, 4 failed
```

**除外が広すぎたときに 4 クラスで検出できる。**
`--warn-only` 相当の握り潰しを後から誰かが入れても TC が落ちる。

### M4 — レーン内部（コードスパンのマスクを外す = 修正前の状態を再現）

```
  [FAIL] TC-S6: expected rc=0 for link notation inside a code span
  [FAIL] TC-S1: expected rc=0 on the production tree
TA-69 standalone: 15 passed, 2 failed

SELFTEST FAIL:
  - code-span link notation is not extracted as a link
```

TC-S6 に加えて **本番ツリー（TC-S1）と selftest も落ちる**。
これは修正前の実際の偽陽性（`.claude/skills/diff-audit/SKILL.md` の `./file.md`）を
再現しており、**修正が本番経路で load-bearing であること**の直接証拠。

## 本番経路の確認（diff-audit Phase 6 item 7）

ta-69 の負側 TC は **引数なしの既定経路**でスクリプトを起動する。
`--extra-root` / テスト専用 env を負側に使っていない。
サンドボックス化は「スクリプトを `<tmp>/scripts/` にコピーして
`REPO_ROOT`（`__file__/../..`）ごと切り替える」方式（ta-39 / ta-50 / ta-52 と同じ）で行い、
**CI が実際に通る経路と同一のコードパス**を通している。

M4 と M3 が **本番ツリー TC（TC-S1）を落とした**ことは、
負側の検出力が本番経路にも存在することの実測的裏付けになっている。

## 件数 assert の不在（diff-audit Phase 6 item 8 / AC-9）

ta-69 は `46` / `7` 等の絶対件数を assert していない。
`.claude/` と `plugin/` は運用でファイルが増減するため、
件数契約は**無関係な PR の CI を落とす時限爆弾**になる。
契約は集合の性質で置いた:

- 「本番ツリーで true collision = 0」（rc で表現）
- 「本番ツリーで stale = 0」（rc で表現）
- 「注入した違反の名前が出力集合に含まれる」（`grep` で表現）
