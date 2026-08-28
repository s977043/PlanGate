# PR 前レビューで検出した AC-1 未達と是正 — repo root 除去の大小文字依存

> 検出: 2026-08-15 PR 前レビュー（独立 2 体 + オーガナイザー再現） / Human 判断「本 PBI 内で是正」
> 是正: exec ワーカー / branch `feat/1101-ho-normalization` / 是正前 HEAD `9f1635c`
> OS: Darwin 25.6.0 (macOS 26.6.1 / arm64) / `/bin/sh` = bash 3.2 系

## 欠陥

`_pg_fold_path` の適用順が **(4) repo root 除去 → (5) 小文字化** だったため、
**root 前置部の比較だけが大小文字厳密**だった。相対パス側は (5) の後に `case` で
受けるので効いていたが、**root 前置部を大文字にした絶対パス**が root 除去を
すり抜け、絶対パスのまま HO パターンに当たらず素通りしていた。

**到達性**: macOS は既定で case-insensitive FS のため
`/USERS/user/Documents/GitHub/plangate/CLAUDE.md` と `/Users/.../CLAUDE.md` は
**同一実体（6,572 bytes）に到達する**。理論上の話ではなく**書き込みが成立する経路**。

### なぜテストが緑だったか

`ta-65` TC-08 の直積が **repo root 形を常に正しい大小文字で生成**し、大小文字変換を
**相対パターンにしか当てていなかった**。plan の AC-1 が要求する
**「repo root 跨ぎ × 大小文字」の 2 種複合が 1 度も評価されていなかった**。
本 PBI 自身が Risks に挙げた「既知ケース狙い撃ちで緑になる」形そのもの。

## 是正前の実測（sandbox / `--emit` の patched hook・`PLANGATE_HOOK_TASK` 設定）

```
REPO_ROOT(sandbox) = /tmp/pg1101-repro.qvnESK
rc=2	CLAUDE.md
rc=2	claude.md
rc=2	/tmp/pg1101-repro.qvnESK/CLAUDE.md
rc=2	/tmp/pg1101-repro.qvnESK/./CLAUDE.md
rc=0	/TMP/PG1101-REPRO.QVNESK/CLAUDE.md        ← 素通り 🔴
rc=0	/TMP/PG1101-REPRO.QVNESK/CLAUDE.MD        ← 素通り 🔴
```

## 検出力の実証（**是正前の実装に対して新 TC が FAIL する**）

TC-08 の直積に **repo root 形への大小文字変換 2 形**（root 前置部のみ大文字 /
root 全体 + パターン大文字）を追加し、**関数を直す前に** `ta-65` を実行した:

```
  [FAIL] TC-08 (AC-1): 直積で 30/195 件が block されない
TA-65 standalone: 15 passed, 1 failed          (rc=1)

    product miss: [/VAR/FOLDERS/_H/FFWB.../T/TMP.CR6CSMQDVO/.claude/rules/x.md] → rc=0
    product miss: [/VAR/FOLDERS/_H/FFWB.../T/TMP.CR6CSMQDVO/.CLAUDE/RULES/X.MD] → rc=0
    product miss: [/VAR/FOLDERS/_H/FFWB.../T/TMP.CR6CSMQDVO/.claude/settings.json] → rc=0
    product miss: [/VAR/FOLDERS/_H/FFWB.../T/TMP.CR6CSMQDVO/.CLAUDE/SETTINGS.JSON] → rc=0
    product miss: [/VAR/FOLDERS/_H/FFWB.../T/TMP.CR6CSMQDVO/.claude/settings.local.json] → rc=0
    …（15 パターン × 2 形 = 30 件）
```

**30 = 15 パターン × 追加した 2 形**。追加分がすべて漏れていたことが件数で一致する。

## 是正の内容

**(4) と (5) を入れ替え、root 側にも同じ写像を通してから比較する**（`$3=1` のときのみ）。

```
旧: (4) repo root 除去（大小文字厳密） → (5) 小文字化
新: (4) 小文字化（_pf_final と _pf_root の両方） → (5) repo root 除去
```

制約はすべて維持:

| 制約 | 維持の根拠 |
|---|---|
| `_norm_target` の値を変えない | hook 側の既存 root 除去は**未変更**。`_pg_fold_path` も `$3=0`（小文字化なし）では **root 比較が従来どおり大小文字厳密**（実測: `$RUP/CLAUDE.md` を `$3=0` で渡すと入力そのまま） |
| fork を増やさない | `_pg_fold_tolower` を root にも当てるだけ。外部コマンド呼び出しゼロは不変 |
| 単語分割に依存しない | パラメータ展開のみ。4 シェルで出力 byte 一致を再実測 |
| POSIX sh / 4 シェル同一 | `sh` / `dash` / `bash` / `zsh` で `diff` 差分ゼロ、`LANG=ja_JP.UTF-8` でも同一 |
| **絶対パスを一律 block しない** | `/PRIVATE/TMP/x/NOTE.md` → `/private/tmp/x/note.md`（**絶対のまま**＝非 HO）。`ta-65` TC-09b（絶対パス 4 件が rc≠2）も PASS |

> **既知の副作用（意図的・fail-closed 方向）**: case-sensitive FS（Linux CI 等）では
> `/USERS/...` は repo root と別実体だが、本実装は root と**大小文字非依存で一致**と
> 見なして block する。存在しないパスへの書き込みを止めるだけであり、
> **fail-open より fail-closed を選ぶ**方針に沿う。

## 是正後の実測（同じ 6 パターン）

```
REPO_ROOT(sandbox) = /tmp/pg1101-repro.p2iOiK
rc=2	CLAUDE.md
rc=2	claude.md
rc=2	/tmp/pg1101-repro.p2iOiK/CLAUDE.md
rc=2	/tmp/pg1101-repro.p2iOiK/./CLAUDE.md
rc=2	/TMP/PG1101-REPRO.P2IOIK/CLAUDE.md        ← 是正 ✅
rc=2	/TMP/PG1101-REPRO.P2IOIK/CLAUDE.MD        ← 是正 ✅
```

`ta-65`:

```
  [PASS] TC-08 (AC-1): 直積 195 件（15 パターン × 変換 13 形）すべて rc=2 + HARDENING_OVERRIDE
  [PASS] TC-09b (TC-11b): 絶対パス 4 件は block されない（偽陽性の回帰検出）
  [PASS] TC-12: 正規化関数が正本 tests/fixtures/pg-fold-path.sh と byte 一致（drift なし）
TA-65 standalone: 16 passed, 0 failed          (rc=0)
```

## 4 シェル直接評価の再実行（**root 大文字入力を含む**）

`sh` / `dash` / `bash` / `zsh` の 4 本とも rc=0、`diff` 3 本すべて差分ゼロ。
`LANG=ja_JP.UTF-8 LC_ALL=ja_JP.UTF-8` でも各シェルの C locale 実行と byte 一致。

| 入力 | 出力 | rc |
|---|---|---|
| `$REPO_ROOT_UPPER/CLAUDE.md` | `claude.md` | 0 |
| `$REPO_ROOT_UPPER/CLAUDE.MD` | `claude.md` | 0 |
| `$REPO_ROOT_UPPER/./bin/plangate` | `bin/plangate` | 0 |
| `$REPO_ROOT_UPPER/BIN/PLANGATE` | `bin/plangate` | 0 |
| `$REPO_ROOT_UPPER//CLAUDE.md` | `claude.md` | 0 |
| `$REPO_ROOT_UPPER/x/../CLAUDE.md` | `claude.md` | 0 |
| `$REPO_ROOT/CLAUDE.md` | `claude.md` | 0 |
| **`$REPO_ROOT_UPPER/CLAUDE.md`（`$3=0`）** | **入力そのまま** | 0 |
| `$REPO_ROOT/other/note.md` | `other/note.md` | 0 |
| `/PRIVATE/TMP/x/NOTE.md` | `/private/tmp/x/note.md` | 0 |

## M10 変異（root 比較を大小文字厳密に戻す）

```
--- M10-root-case-sensitive : ta65 rc=1
  [FAIL] TC-08 (AC-1): 直積で 45/195 件が block されない
  [FAIL] TC-12: 正規化関数が正本と一致しない — tests/fixtures/pg-fold-path.sh と hook のどちらかだけが変更された

  うち 30 件が今回追加した root 大文字 2 形（`grep -c 'product miss: \[/VAR/FOLDERS' = 30`）
```

> 45 件のうち残り 15 件は**正しい大小文字の root 形**。是正後は `_pf_final` が
> 先に小文字化されるため、root 側の写像を外すと mktemp パスに含まれる大文字
> （`/T/tmp.Ck2M2oTIZ5`）で全 root 形が一致しなくなる。**M10 は root 除去そのものを
> 壊す変異**として機能し、追加 TC（30 件）を確実に kill する。

## 併せて確認した非退行

| 対象 | 結果 |
|---|---|
| apply スクリプト sandbox 7 項目 | 全項目 OK（`--apply` smoke OK 20 runs 0.86s / `--revert` byte 一致復元 / smoke 失敗時の自動 revert 成功） |
| `ta-39-eh3-doc-light` | rc=0 / 8 passed, 0 failed |
| `ta-45-c3-mode-config` | rc=0 / 6 passed, 0 failed |
| `ta-12-maintenance` | rc=0（本文中の `[FAIL]` 文字列は負側ケースの診断ラベル。**baseline clone と同一**） |
| `scripts/hooks/check-plan-hash.sh` | **未変更**（`git diff --name-only -- scripts/hooks/` = 0 件） |
