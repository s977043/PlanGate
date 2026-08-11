# TASK-1012 exec 実測サマリ（A-1〜A-5）

> base: `origin/main` = `fac3445` / branch: `feat/1012-exec`
> 実装変更: `tests/extras/ta-26-plugin-sync.sh` の 1 ファイルのみ

## A-1 baseline（適用前）

| 項目 | 実測 |
|------|------|
| 親サマリ | `TA-26 standalone: 32 passed, 0 failed`（`t26-parent-base.log`） |
| rc | 0 |
| 実行時間 2 回 | 52.224s / 50.783s |
| ゲート A 予定範囲 | `421-521`（TC-20 L421 〜 TC-25 ブロック終端 L521） |
| ゲート B 予定範囲 | `558-730`（TC-26 L558 〜 TC-36 ブロック終端 L730） |
| シンボル越境検査（TC-A6a） | `containment_violations=0` / `identifiers=77 crossings=0` / rc=0 |
| V-A 行の抽出検証（参考） | `sh tests/extras/ta-26-plugin-sync.sh </dev/null && PG_T26_NO_RECURSE=1 sh tests/extras/ta-26-plugin-sync.sh </dev/null && sh tests/run-tests.sh`（実コマンド列と一致） |

## A-2 適用

- ゲート A / B を L62-68 と同型で適用（説明コメント + `if` / `printf` / `else` / `fi`）
- ヘルパー定義（`_T26_AI_LOOP_REFS_REL` / `_t26_mk_ai_loop_guard_sandbox` / `_t26_mk_refs_guard_sandbox`）と TC-30 / TC-33 はゲート外に維持
- `sh -n` rc=0
- TC-INV: `git diff -w HEAD -- tests/extras/ta-26-plugin-sync.sh` の差分は **ゲート追加分 4 hunk のみ**（既存行の内容変化 0）
- `git add` 済み（`git diff --cached --stat` に当該ファイルが載ることを確認）

### 適用後の動的導出（awk）

```text
67-92      ← 既存（TC-03/04）
293-321    ← 既存（TC-13）
427-531    ← 新規ゲート A（SKIP 文言 'TC-20〜TC-25' で特定）
572-748    ← 新規ゲート B（SKIP 文言 'TC-26〜29/32/34〜36' で特定）
```

導出件数 = **4**（想定どおり）。うち新規 2 件を SKIP 文言で特定。

## A-3 受入検証

| AC | 判定 | 実測 |
|----|------|------|
| AC-1 | **PASS** | TC-A1a=2 / TC-A1b=0 / TC-A1c: TC-30=1・TC-33=1（`t26-child.log`・子サマリ `15 passed, 0 failed`） |
| AC-2 | **PASS** | サマリ diff rc=0（`32 passed, 0 failed` 一致）+ PASS TC-ID 集合 diff rc=0（32 要素） |
| AC-3 | **PASS** | `t26-parent-opt.log` = `32 passed, 0 failed` / rc=0 |
| AC-4 | **PASS** | `full-suite.log` = `Results: 539 passed, 0 failed` / rc=0 |
| AC-6 | **PASS** | 適用後 tree・動的導出範囲 `427-531` / `572-748` で `containment_violations=0` / `crossings=0` / rc=0 |

## A-4 変異検証 4 種

| 変異 | 内容 | 期待 | 実測 | 復元後 |
|------|------|------|------|--------|
| ① | 新規 2 ゲートのみ条件反転（L427 / L572） | AC-2 が FAIL | 親サマリ `18 passed`（baseline 32）→ summary diff rc=1 | `git checkout --` 後に `32 passed` で一致（再 PASS） |
| ② | ゲート B の終端 `fi` を TC-36 の手前へ移動 | AC-1（TC-A1b）が FAIL | TC-A1b=**1**（`[PASS] TC-36` が子で実行された） | 復元後 TC-A1b=**0**（再 PASS） |
| ③ | ファイル末尾へ `: "$_t26_tgt36"` を注入 | AC-6 が越境 ≥1 | `CROSS _t26_tgt36 (def L738) <- L824` / `crossings=1` / rc=1 | 復元後 `crossings=0` / rc=0 |
| ④ | 範囲入力（call site）を広げる。ファイル無改変 | (1b) 排他アサーションが `IN-RANGE` | `572-759` → `IN-RANGE gate B: TC-30 at L750` / violations=1 / rc=1。`572-810` → TC-30 + TC-33 の 2 件 / violations=2 / rc=1 | 正しい範囲 `572-748` で violations=0 / crossings=0 / rc=0 |

**④ の範囲値について**: plan の値（`558-741` / `558-791`）は **適用前 tree の推定値**。適用でファイル行がずれるため、
適用後の実測（TC-30 = L750 / TC-33 = L761 / ゲート B 終端 `fi` の次の桁 0 `fi` = L759）から
`572-759`（TC-30 のみ飲み込む・現実的な誤り）と `572-810`（TC-30 + TC-33）へ置き換えて実施した。

## A-5 交互 A/B 実測（AC-5）

退避コピー方式（`/tmp/ta26.base` / `/tmp/ta26.opt`）で BASE / OPT を交互に各 4 回。
BASE 健全性アサーション（`grep -q 'TC-20〜TC-25' /tmp/ta26.base`）は **0 件** = 実装未 commit を確認済み。

| 回 | BASE (s) | OPT (s) |
|----|---------|--------|
| 1 | 53.669 | 47.433 |
| 2 | 50.162 | 43.306 |
| 3 | 48.994 | 41.251 |
| 4 | 49.416 | 42.112 |
| **中央値** | **49.789** | **42.709** |

- `OPT / BASE = 0.8578` → **短縮率 14.22%**
- 判定基準 `OPT ≤ BASE × 0.85`（15% 以上）に **わずかに届かない**
- 追加往復は plan の上限（最大 4 往復）まで実施済み

→ **AC-5 = WARN（人間判断待ち）**。AI は PASS 扱いにしない。
C-4（H-1）で「子プロセスのカバレッジ縮小を受け入れるか」を人間が明示判断する。

### 人間判断のための材料

1. **便益**: 交互 A/B 中央値で 49.789s → 42.709s（**-7.08s / 14.22%**）
2. **恒久コスト**: 再帰防止モードの子プロセスで TC-20〜25 / 26〜29 / 32 / 34 / 35 / 36 が実行されなくなる
   （TC-13 の判定目的は「子が `TA-26 standalone: … 0 failed` を出す」＝ standalone fallback の証明に限られ、
   これらの TC は必ず親プロセス側で実行されるため親のカバレッジは不変 — AC-2 で実証済み）
3. **取り消し手順**: `git revert` 1 手

> plan の参考値（≈40% 短縮）は **TC-35/36 追加前の tree** での測定であり、現 tree では再現しない。
> 現 tree では子で省略される TC が全体に占める割合が当時より小さい。
