# TASK-0921 Phase 3 — Current Baseline

> 取得日時: 2026-08-05
> 基点: `origin/main` = `4448420cb48261aefa9fd274e498f140ab5e4cf7`
> 取得者: オーガナイザー（full-suite / syntax）+ 独立ワーカー（standalone 全 57 件）
> **実装コードは 1 行も変更していない**（`git diff -- tests scripts bin .github` が空であることを確認）
>
> **【2026-08-10 追記 — 基点 SHA の表記差について】**
> 同梱ログのヘッダが記録している HEAD は本文の宣言（`4448420`）と一致しない:
> `syntax.log:1` = `HEAD=1242420` / `full-suite.log:5` = `HEAD=ded2b4c`。
> これは採取が dirty worktree 上の複数ステップで行われたことによる表記差であり、
> **検査対象コードは同一**である。独立検証（2026-08-10）:
>
> ```console
> $ git diff --stat 1242420 ded2b4c
>  docs/working/TASK-1009/pbi-input.md | 2 +-        ← 差分はこの 1 ファイルのみ
> $ git diff --stat 4448420 ded2b4c
>  docs/working/TASK-1009/pbi-input.md | 125 +++++   ← 同上（新規追加）
> $ git diff --stat 4448420 ded2b4c -- tests bin scripts .github
>                                                    ← 空（コード側は完全に同一）
> ```
>
> したがって本 baseline の測定値（539 passed / 0 failed / rc=0 / 231 秒、
> 構文チェック 58 ファイル エラー 0、standalone 全 57 件）は
> **`4448420` の測定値として扱ってよい**。

## 1. 対象の確定（runtime inventory / 件数はハードコードしない）

```sh
find tests/extras -maxdepth 1 -type f -name 'ta-*.sh' -print | sort
```

- 実測 **57 件** → [`../inventory/extras-files.txt`](../inventory/extras-files.txt)
- 注記: `ta-48` は欠番、`ta-14` は同番 2 ファイル（`ta-14-codex-guarded` / `ta-14-skip`）。
  **ta 番号は連番でも一意でもない** ため、番号を識別子に使う設計は不可。

## 2. 構文チェック

```sh
sh -n tests/run-tests.sh
sh -n tests/extras/ta-*.sh   # 57 件を個別に実行
```

- 結果: **エラー 0 件 / 58 ファイルすべて rc=0**
- 証跡: [`syntax.log`](./syntax.log)

## 3. Full suite（harness 経路）

```sh
sh tests/run-tests.sh
```

| 項目 | 実測 |
|---|---|
| 結果 | **539 passed / 0 failed** |
| rc | **0** |
| 実行時間 | **231 秒** |
| `[FAIL]` 行 | **0 件** |

- 証跡: [`full-suite.log`](./full-suite.log)（先頭に取得時点の `git status --porcelain` と HEAD を記録）
- **main の baseline は緑**。`plan.md` の「main の baseline が既に赤い場合は実装へ進まない」停止条件には**該当しない**。
- 総数 `539` は基点依存で振れる（既知事象 #947 / #942。worktree と primary checkout で差が出る）。
  **総数を契約値にせず、判定は「0 failed」で行う**（[[全体量化子 AC の鮮度]]）。

## 4. Standalone 実行（直接実行経路）— #921 の症状の実証

全 57 件を `sh "$f" </dev/null` で実行（7 env を unset した clean env・`perl -e 'alarm N; exec @ARGV'` で timeout 付与）。

| 分類 | 件数 | 意味 |
|---|---:|---|
| **`[FAIL]` を出しながら rc=0** | **35** | **#921 の症状そのもの。失敗が静かに通る** |
| 上記の `[FAIL]` 合計 | **256** | |
| **`[FAIL]` を出して非 0 を返したもの** | **0** | 現状 1 件も伝播していない |
| `[PASS]` が 0 件 | **14** | 検査が 1 件も走らずに終了している |
| うち `[PASS]`=0 かつ `[FAIL]`=0 かつ rc=0 | **2**（`ta-06` / `ta-08`） | `fail>0 → exit 1` では救えない。**harness-only の exit 2 拒否が必須**な代表例 |
| stdin 未リダイレクトでハング | **1**（`ta-50`） | `</dev/null` なしで rc=142（alarm 20 秒）。`</dev/null` 付きでは正常終了 |

- 証跡: [`standalone-current.log`](./standalone-current.log)
- **オーガナイザーによる独立再現**（サンプル 2 件）:

```console
$ sh tests/extras/ta-05-validate-schemas.sh </dev/null   # 7 env unset 済み
  rc=0  FAIL件数=2
$ sh tests/extras/ta-13-plangate-setup.sh </dev/null
  rc=0  FAIL件数=10
```

### 4-bis. 偽 PASS（issue #921 の AC に無い症状クラス）

Phase 1 が **rc=0 / FAIL=0 だが assertion が空振りして PASS を出す** ケースを 3 件検出した。

| file | 空振り PASS |
|---|---:|
| `ta-11` | 4 件すべて |
| `ta-32` | 2 件すべて |
| `ta-38` | 1 件すべて |

**`fail > 0 → exit 1` を入れても検出できない。** #921 のスコープ内で扱うか別 issue にするかは
Human 判断（C-2 Lane 2 へ提言を依頼済み）。

## 5. Capability 分類（Phase 1 実測）

| 分類 | 件数 | 一覧 |
|---|---:|---|
| standalone-capable | **16** | ta-26, 39, 40, 43, 44, 45, 46, 47, 49, 50, 51, 52, 53, 58, 59, 60 |
| harness-only | **41** | 上記以外 |

- migration risk: high **1**（`ta-45`）/ medium 9 / low 47
- `plan.md:75` の Unknown「standalone-capable が 11 + ta-26 以外に増えているか」→ **増えている**。
  `ta-58` / `ta-59` / `ta-60`（規約 8 完全準拠の新規）と `ta-40`（プローブ型 ROOT 補正）が追加。
- **第三カテゴリは不要**（57 件すべて 2 分類で表現でき、偽 PASS も harness-only の一形態として表現できる）。

## 6. Trap / cleanup（Phase 2 実測）

| 項目 | 実測 |
|---|---|
| top-level trap 保有 | **4 件**（`ta-07` L13,49 / `ta-09` L23 / `ta-24` L252,280 / `ta-45` L76,224） |
| うち standalone-capable | **1 件（`ta-45`）** — L76 `trap cleanup_t45 EXIT` / L224 `trap - EXIT` |
| subshell 内のみの trap | 1 件（`ta-28` L87,114。親を汚染しない） |
| `tests/run-tests.sh` の trap | **0 件**（helper が壊す既存 trap は存在しない） |
| trap 本体が repo path を削除 | **3 件**（`ta-07:12` / `ta-09:17-18` / `ta-45:74`） |
| finalizer 到達性の証明が要る top-level early exit 経路 | **17**（うち 11 は `return 0 2>/dev/null \|\| …` の統一イディオム。裸の脱出は `ta-27:37` の 1 件のみ） |

- 証跡: [`../inventory/trap-cleanup-audit.md`](../inventory/trap-cleanup-audit.md)

## 7. dirty worktree 依存の有無

baseline 取得時点の `git status --porcelain`:

```text
 M docs/working/_audit/skip-decision-log.jsonl     # hook の追記副作用（正常）
?? docs/working/TASK-0874/approvals/               # 別 TASK の untracked（AI 書込不可）
```

- **`tests/` `scripts/` `bin/` `.github/` 配下の変更は 0 件**（C-3 前の不実装を実測で担保）
- full-suite は上記 dirty 状態でも **0 failed**。dirty worktree 依存は観測されなかった。

### 7-bis. standalone 実行が生んだツリー汚染（実害・要 Human 対処）

standalone 全数実行の副作用として **`tests/docs/working/_audit/hook-events.log`（未追跡・5 行）が残留**した。

- 中身は `TASK-9991` fixture ＝ **`ta-09-metrics.sh` 由来**
- 原因: standalone 実行時に ROOT が repo root ではなく **`tests/` に解決**され、
  `cleanup_metrics` が `_audit/` を回収しない
- **`.gitignore` 対象外**（`git check-ignore` が 0 件）＝ 放置すると commit へ混入する
- **#921 が扱う問題クラス（standalone 実行時の path 解決差）の実例**であり、
  同時に Phase 2 が指摘した「テストが repo 内パスへ書く」リスクの実証でもある
- **削除は Human 対処**（`rm -rf tests/docs`）。AI は名指し外の untracked を破棄しない方針のため未実行

## 8. baseline から導かれる判定

| 判定 | 結論 |
|---|---|
| main baseline | **緑**（539/0・rc=0）→ 実装可否の停止条件に該当しない |
| #921 の症状 | **実証済み**（35 件が FAIL を出しながら rc=0・伝播 0 件） |
| 案 C（trap 方式） | **採用不可**（§6。`ta-45` が standalone-capable かつ top-level trap 保有） |
| 第三カテゴリ | **不要**（§5） |
| 新規に判明した症状クラス | **偽 PASS 3 件**（§4-bis）。#921 の AC では拾えない |
