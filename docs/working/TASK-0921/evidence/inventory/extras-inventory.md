# TASK-0921 Phase 1 — extras Runtime Inventory

> #921「extras の standalone 実行が内部 FAIL を exit code に反映せず、失敗が静かに通る」の
> C-3 Ready 前提条件（runtime inventory の取得）。**実装コードは 1 行も変更していない**。
> 本ファイルと `extras-files.txt` のみが本 Phase の書き込み対象。

## 0. 測定条件（再現情報）

| 項目 | 値 |
|---|---|
| 測定日 | 2026-08-05 |
| HEAD | `4448420cb48261aefa9fd274e498f140ab5e4cf7` |
| checkout branch | `docs/1009-pbi-input`（別セッションが同一 checkout で並行作業中。**branch 切替・commit・stash は一切行っていない**） |
| OS | darwin 25.5.0 / `/bin/sh`（bash POSIX mode） |
| python3 | 3.14.2（Homebrew）。`jsonschema` / `PyYAML` は利用可 |
| timeout 実装 | `timeout(1)` / `gtimeout(1)` **不在**のため `perl -e 'alarm N; exec @ARGV'` を使用 |

### 0.1 対象ファイルの確定コマンド

```sh
find tests/extras -maxdepth 1 -type f -name 'ta-*.sh' -print | sort
```

- 実測総件数: **57 件**（出力そのままを `extras-files.txt` に保存）
- 件数と ta 番号は**測定時点の実測値**であり、正本は `extras-files.txt` / 再実行結果。
  仕様・実装へハードコードしないこと（plan.md L25 / L70 と一致。pbi-input 時点 53 → 本測定 57）。

### 0.2 standalone 実行コマンド（全 57 件）

```sh
# 7 env を先に無害化してから 1 件ずつ実行
unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
  PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
  PLANGATE_ALLOW_MASS_DELETE
find tests/extras -maxdepth 1 -type f -name 'ta-*.sh' -print | sort | while IFS= read -r f; do
  perl -e 'alarm 60; exec @ARGV' /bin/sh "$f" </dev/null >"$OUT/$(basename "$f").log" 2>&1
done
```

> **測定時の env 汚染**: 実行シェルには `PLANGATE_HOOK_TASK=TASK-0914` が
> export されていた（`tests/extras/README.md` 規約 7 / #914 が想定する実害パターンそのもの）。
> 上記 unset で無害化した。**`docs/working/_audit/skip-decision-log.jsonl` の
> sha は実行前後で不変**（汚染なしを実測確認済み）。

> **単語分割の注意（zsh 罠）**: 集計・実行ループはすべて `sh -c` / `find | while read`
> 経由で実行した。Bash tool の対話シェルは zsh であり `for f in $VAR` が
> 単語分割されないため、zsh 直書きのループは使っていない。

---

## 1. 12 項目 inventory（全 57 件）

### 凡例

**fixture fallback（ROOT 解決方式）**

| 記号 | 意味 | standalone での正しさ |
|---|---|---|
| `FD` | `"$FIXTURES_DIR/../.."`（fallback なし） | ✗ `FIXTURES_DIR` 未定義 → ROOT が `//` になる |
| `T0` | `"$(dirname -- "$0")/.."`（fallback なし） | ✗ source 時は `$0`=run-tests.sh 前提。standalone では `tests/` を指す |
| `T0F` | `T0` + schemas 存在プローブで 1 段上へ補正 | ✓ 正しい repo root に解決 |
| `GD` | `PG_HARNESS_SOURCED` && `FIXTURES_DIR` の AND 判定 + standalone 分岐で `"$(dirname -- "$0")/../.."` | ✓ README 規約 8 準拠 |
| `GD+FX` | `GD` 相当 + standalone 分岐で `FIXTURES_DIR` も自前定義 | ✓ 規約 8 準拠（最も完全） |
| `-` | ROOT 変数を持たず `FIXTURES_DIR` / `PLANGATE_BIN` を直接参照 | ✗ |

**current direct execution**: `rc` / `[PASS]` / `[FAIL]` / `[SKIP]` の実測。
`vacuous` = rc=0・FAIL=0 だが ROOT 誤解決により assertion が空振りしている（後述 §4）。

| # | file | current direct execution | fixture fallback | counter init | early exit/return | top-level trap | cleanup | stdin dep | external dep | proposed capability | rationale | migration risk |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `ta-04-check-pr-issue-link.sh` | rc=0 / P0 F4 | `T0` (L7) → `tests/scripts/...` 不在 | なし | `return` (L20) | なし | なし | なし | なし | **harness-only** | ROOT が `tests/` に解決し対象 script が全欠落。4 件全 FAIL しつつ rc=0 | low |
| 2 | `ta-05-validate-schemas.sh` | rc=0 / P2 F2 | `-`（`FIXTURES_DIR`/`PLANGATE_BIN` 直参照） | なし | なし | なし | `mktemp -d` + 直 `rm -rf` (L41/52) | なし | python3 + `jsonschema` (L7) | **harness-only** | standalone 用 fixture 解決が一切存在しない | low |
| 3 | `ta-06-hooks.sh` | rc=0 / P0 F0 S1 | `T0` (L7) | なし | なし | なし | なし | なし | なし | **harness-only** | `tests/hooks/run-tests.sh` を解決できず全体が SKIP。検査 0 件 | low |
| 4 | `ta-07-eval-runner.sh` | rc=0 / P0 F3 | `T0` (L10) | なし | なし | **`trap cleanup_eval EXIT INT TERM` (L13) / `trap - EXIT INT TERM` (L49)** | trap 経由 `rm -rf "$EVAL_TASK_DIR"` (L12) | なし | python3 + `jsonschema` (L7) | **harness-only** | fixture コピー元が解決できず全 FAIL。加えて top-level EXIT trap を張り、末尾で **解除**する | medium |
| 5 | `ta-08-codex-log-parser.sh` | rc=0 / P0 F0 S1 | `T0` (L8/L36) | なし | なし | なし | 直 `rm -rf` (L38/52) | なし | python3 (L14/33) | **harness-only** | parser/fixture 未解決で丸ごと SKIP。検査 0 件 | low |
| 6 | `ta-09-metrics.sh` | rc=0 / P2 F21 S2 | `T0` (L8/73) | なし | なし | **`trap cleanup_metrics EXIT INT TERM` (L23)（解除なし）** | trap + `mktemp -d` (L425) + 末尾明示 `rm -rf` (L455/457) | なし | python3 + `jsonschema` | **harness-only** | `PLANGATE_BIN` 未定義で 21 件 FAIL。top-level EXIT trap あり | medium |
| 7 | `ta-10-doctor-fix.sh` | rc=0 / P2 F10 | `T0` (L10) | なし | なし | なし | `mktemp -d` (L17) + 直 `rm -rf` ×4 | なし | python3 | **harness-only** | `tests/.claude/settings.example.json` を参照して cp 失敗 → 誤ったパスで動く | low |
| 8 | `ta-11-plan-hash-contract.sh` | rc=0 / **P4 F0（vacuous）** | `FD` (L17) | なし | なし | なし | なし | なし | python3 | **harness-only** | ROOT=`//` で fixture が全欠落 → shell/python 双方が空文字を返し「parity 一致」で **4 件とも偽 PASS**。§4 参照 | medium |
| 9 | `ta-12-maintenance.sh` | rc=0 / P1 F13 | `FD` (L7) | なし | なし | なし | `mkdir -p //docs/...`（Read-only FS で失敗） | なし | python3 | **harness-only** | `//docs` への書込を試み失敗。誤ったパスで動く典型 | low |
| 10 | `ta-13-plangate-setup.sh` | rc=0 / P7 F10 S1 | `FD` (L7) | なし | なし | なし | なし | `cat <<'JSON'`（heredoc・待機しない） | python3 | **harness-only** | ROOT=`//` で agent/command 定義を解決できず | low |
| 11 | `ta-14-codex-guarded.sh` | rc=0 / **P0** F8 | `FD` (L7) | なし | なし | なし | なし | なし | なし | **harness-only** | 8 件全 FAIL・PASS 0 件。検査が 1 件も成立しない | low |
| 12 | `ta-14-skip-acknowledge.sh` | rc=0 / P1 F11 | `FD` (L7) | なし | なし | なし | `mktemp -d` (L21) + `rm -rf` (L129) | なし | python3 | **harness-only** | 対象 script が `//scripts/...` で解決不能 | low |
| 13 | `ta-15-codex-hook-bridge.sh` | rc=0 / **P0** F7 | `FD` (L7) | なし | なし | なし | なし | なし | python3 | **harness-only** | 7 件全 FAIL・PASS 0 件 | low |
| 14 | `ta-16-pollution-guard.sh` | rc=0 / P2 F12 | `FD` (L8) | なし | なし | なし | なし | なし | python3 | **harness-only** | hook 実体を解決できず。残 2 PASS も「不在時 SKIP 扱い」由来 | low |
| 15 | `ta-17-pre-push-guard.sh` | rc=0 / P1 F13 | `FD` (L7) | なし | なし | なし | `mktemp -d` (L104) + `rm -rf` (L113) | なし | なし | **harness-only** | ROOT=`//` で hook/installer 不在 | low |
| 16 | `ta-18-tag-main-parity.sh` | rc=0 / P4 F11 | `FD` (L7) | なし | なし | なし | `mktemp -d` ×2 (L29/120) + `rm -rf` (L113/259) | なし | `git`（**ローカル bare remote のみ**。`git push -q origin` は sandbox 内 file remote 宛でネットワーク不要） | **harness-only** | 対象 script が解決できず 11 件 FAIL | low |
| 17 | `ta-19-plan-metrics-verification.sh` | rc=0 / P2 F8 | `FD` (L7) | なし | なし | なし | なし | なし | なし | **harness-only** | `//.agents/skills/...` を grep して失敗 | low |
| 18 | `ta-20-codex-review.sh` | rc=0 / P1 F9 | `FD` (L7) | なし | なし | なし | なし | なし | なし | **harness-only** | `//bin/plangate` を grep して失敗 | low |
| 19 | `ta-21-codex-mvp-split.sh` | rc=0 / **P0** F9 | `FD` (L7) | なし | なし | なし | なし | なし | なし | **harness-only** | 9 件全 FAIL・PASS 0 件 | low |
| 20 | `ta-22-git-add-scope.sh` | rc=0 / **P0** F8 | `FD` (L7) | なし | なし | なし（コメントで trap 非依存を明記 L16-17） | `mktemp -d` (L15) + `register_cleanup` (L18) | なし | なし | **harness-only** | standalone では `register_cleanup: command not found`（L18）。8 件全 FAIL・PASS 0 件 | low |
| 21 | `ta-23-gh-account-pin.sh` | rc=0 / **P0** F7 | `FD` (L7) | なし | なし | なし | なし | なし | `gh`（**不在をシミュレートする検証**。実 gh 呼び出し・credential 不要） | **harness-only** | 7 件全 FAIL・PASS 0 件 | low |
| 22 | `ta-24-parallel-review.sh` | rc=0 / P6 F4 | `FD` (L7) | なし | なし（L130 等の `return` は python コード内） | **`trap 'rm -rf "$t24_tmpdir4"' EXIT INT TERM` (L252) / `trap -` (L280)** | `mktemp -d` ×4 + 直 `rm -rf` | なし | python3 + `jsonschema` / `PyYAML` | **harness-only** | schema 実体を解決できず 4 件 FAIL。top-level EXIT trap あり | medium |
| 23 | `ta-25-approval-token-guard.sh` | rc=0 / **P0** F7 | `FD` (L8) | なし | なし | なし | なし | なし | python3 | **harness-only** | 7 件全 FAIL・PASS 0 件 | low |
| 24 | `ta-26-plugin-sync.sh` | **rc=0 / P30 F0**（実行 54 秒。alarm 60 では TC-12 で打ち切られる） | **`GD+FX`** (L18-40) | **`pass=0`/`fail=0` (L25-26)** | `exit 1` (L744, standalone fail 時) | なし（`register_cleanup` 自前定義 L28 / trap 非依存 L100） | `mktemp -d` (L99) + 自前 drain (L737-741) | なし | python3（可用性ガードあり）/ `git` 不要 | **standalone-capable** | 判別・counter・cleanup・summary・`fail>0 → exit 1` を**既に完備**。#921 が求める契約の参照実装 | medium |
| 25 | `ta-27-codex-commands.sh` | rc=0 / P2 F3 | `FD` (L7) | なし | なし | なし | `mktemp -d` (L35) + `rm -rf` (L43) | なし | なし | **harness-only** | 対象 script 不在で FAIL | low |
| 26 | `ta-28-plugin-version.sh` | rc=0 / P1 F10 | `FD` (L7) | なし | なし | なし（trap は**サブシェル内**に閉じ込め L87/L114） | `mktemp` / `mktemp -d` + subshell trap | なし | python3 | **harness-only** | ROOT=`//` で plugin メタを解決できず | low |
| 27 | `ta-29-committed-pollution.sh` | rc=0 / P1 F4 | `FD` (L7) | なし | なし | なし | `mktemp` ×2 (L35/45) | なし | なし | **harness-only** | 対象 script 不在 | low |
| 28 | `ta-30-install-skills.sh` | rc=0 / **P0** F9 | `FD` (L7) | なし | なし | なし | `mktemp -d` (L38) + `rm -rf` (L100) | なし | python3 (L86) | **harness-only** | 9 件全 FAIL・PASS 0 件 | low |
| 29 | `ta-31-codex-plugin-status.sh` | rc=0 / **P0** F7 | `FD` (L7) | なし | `return 0 2>/dev/null \|\| true` ×4 (L43/56/72/73, mktemp 失敗時) | なし（L54 で trap 不使用を明記） | `mktemp -d` ×4 + 直 `rm -rf` | なし | `gh`（**PATH 除外で不在を作る検証**。ネットワーク非依存と明記 L69-71） | **harness-only** | 7 件全 FAIL・PASS 0 件 | low |
| 30 | `ta-32-real-ssot-pollution.sh` | rc=0 / **P1(+WARN1) F0（vacuous）** | `FD` (L16) | なし | なし | なし（L41 で trap 不使用を明記） | `mktemp` (L43) + `rm -f` | なし | なし | **harness-only** | `//scripts/check-committed-memory-pollution.sh` が rc≠0 になるだけで TC-01 は WARN(=pass 加算)、TC-02 は「guard が非 0 を返した」と誤判定して PASS。**偽 PASS**。§4 参照 | medium |
| 31 | `ta-33-agent-model-tier.sh` | rc=0 / P2 F2 | `T0` (L7) | なし | なし | なし | なし | なし | なし | **harness-only** | ROOT=`tests/` で agent 定義 0 件（`toml総数=0(expect 17)`）→ 誤ったパスで動く | low |
| 32 | `ta-34-cli-min-coverage.sh` | rc=0 / P1 F5 | `T0` (L8) | なし | なし | なし（L63 で trap 非依存を明記） | 冒頭 `rm -rf` (L11) + 末尾 `rm -rf` (L64) | なし | なし | **harness-only** | `PLANGATE_BIN` 未定義で `sh: : No such file` | low |
| 33 | `ta-35-yaml-schema.sh` | rc=0 / P1 F1 | `T0` (L8) | なし | なし | なし | `mktemp -d` (L22) + `rm -rf` (L30) | なし | python3 + `PyYAML` + `jsonschema` (L10) | **harness-only** | `tests/scripts/validate-yaml-schemas.py` 不在で rc=2 | low |
| 34 | `ta-36-fixloop-event.sh` | rc=0 / **P0** F1 | `T0` (L8) | なし | なし | なし | なし | なし | python3 + `jsonschema` (L10) | **harness-only** | 1 件 FAIL・PASS 0 件 | low |
| 35 | `ta-37-cli-coverage-batch2.sh` | rc=0 / P1 F6 | `T0` (L8) | なし | なし | なし（L75 で trap 非依存を明記） | 冒頭 `rm -rf` (L11) + 末尾 `rm -rf` (L76) | なし | なし | **harness-only** | `PLANGATE_BIN` 未定義 | low |
| 36 | `ta-38-agent-tools.sh` | rc=0 / **P1 F0（vacuous）** | `T0` (L8) | なし | なし | なし | なし | なし | なし | **harness-only** | ROOT=`tests/` → `tests/.claude/agents/*.md` が 0 件マッチ → `_t38_bad` が空のまま **偽 PASS**。§4 参照 | medium |
| 37 | `ta-39-eh3-doc-light.sh` | **rc=0 / P8 F0** | **`GD`** (L14-20) | なし | `return 0 2>/dev/null \|\| exit 0` (L59) / `exit 0` (L61) | なし | `mktemp -d` (L23) + `register_cleanup` 条件付き (L24-25) + 末尾 `rm -rf` (L136) | なし | なし | **standalone-capable** | 規約 8 準拠の判別・env unset・ROOT 解決を保持し、standalone で 8 件すべて実検査が成立。**不足は counter 初期化と exit code のみ** | low |
| 38 | `ta-40-task-0129-review-gate.sh` | **rc=0 / P12 F0** | **`T0F`** (L7-10, schemas 存在プローブで補正) | なし | なし | なし | なし | なし | python3 + `jsonschema` (L90) | **standalone-capable** | プローブ補正で ROOT が正しく解決し 12 件すべて実検査が成立。ただし **README 規約 8 の判別方式ではなく env unset も無い** | medium |
| 39 | `ta-41-approve-hardening.sh` | rc=0 / P1 F6 S1 | `FD` (L15) | なし | なし | なし | `register_cleanup` (L73/108) — standalone では未定義 | なし（L24 等の `read -r` は grep 対象文字列） | なし | **harness-only** | `//bin/plangate` を grep して失敗 | low |
| 40 | `ta-42-cli-subcommands.sh` | rc=0 / P1 F9 | `FD` (L14) | なし | なし | なし | `register_cleanup` (L23/91) + 直 `rm -rf` | なし | なし | **harness-only** | `register_cleanup: command not found` の後 `//bin/plangate` で rc=127 連発 | low |
| 41 | `ta-43-eh2-strict-json.sh` | **rc=0 / P6 F0** | **`GD`** (L17-23) | なし | `return 0 2>/dev/null \|\| exit 0` (L56) | なし | `mktemp -d` (L28) + `register_cleanup` 条件付き + 末尾 `rm -rf` (L152) | **明示 `</dev/null`** (L84) で回避済 | python3 | **standalone-capable** | 規約 8 準拠。6 件すべて実検査成立。hook 呼び出しに `</dev/null` を付与済みで stdin ハング耐性あり | low |
| 42 | `ta-44-eh457-cli-wiring.sh` | **rc=0 / P5 F0** | **`GD`** (L16-22) | なし | `return 0 2>/dev/null \|\| exit 0` (L49) | なし | `register_cleanup` 条件付き (L63-65) + 未定義環境向け fallback (L104-) | なし | なし | **standalone-capable** | 規約 8 準拠。`register_cleanup` 不在環境の fallback まで持つ | low |
| 43 | `ta-45-c3-mode-config.sh` | **rc=0 / P6 F0** | **`GD`** (L14-20) | なし | `return 0 2>/dev/null \|\| true` (L52) | **`trap cleanup_t45 EXIT` (L76) → 末尾で `cleanup_t45; trap - EXIT` (L223-224)** | `mktemp -d` (L56) + trap 経由 (L72-75) | なし | python3 | **standalone-capable** | 検査自体は 6 件すべて成立。ただし **top-level EXIT trap を張り末尾で解除する唯一の standalone-capable ファイル**。plan 案 C の共通 helper exit trap と直接競合する（§5 P0） | **high** |
| 44 | `ta-46-ehs-wiring.sh` | **rc=0 / P4 F0** | **`GD`** (L10-16) | なし | `return 0 2>/dev/null \|\| true` (L23) | なし | なし（一時ファイル生成なし） | なし | なし | **standalone-capable** | 規約 8 準拠・静的検査のみ・副作用なし | low |
| 45 | `ta-47-ehs23-wiring.sh` | **rc=0 / P6 F0** | **`GD`** (L10-16) | なし | `return 0 2>/dev/null \|\| true` (L23) | なし | なし | なし | なし | **standalone-capable** | 規約 8 準拠・静的検査のみ・副作用なし | low |
| 46 | `ta-49-bias-export.sh` | **rc=0 / P6 F0** | **`GD`** (L12-18) | なし | `return 0 2>/dev/null \|\| true` (L72) | なし | `/tmp/ta49_err` / `/tmp/ta49_err2` を**固定名**で使用（L52/60、削除なし） | なし | python3 | **standalone-capable** | 規約 8 準拠・6 件成立。固定名 `/tmp` ファイルの後始末欠落は別途 minor | low |
| 47 | `ta-50-precompact-guard.sh` | `</dev/null` あり: **rc=0 / P9 F0** / **stdin 未リダイレクトで無限ハング（alarm 20s で rc=142・出力はヘッダのみ）** | **`GD`** (L12-18) | なし | なし | なし | `mktemp -d` (L21) + `register_cleanup` 条件付き + 末尾 `rm -rf` (L128) | **あり**。`sh "$_T50_HOOK"` を L38/51/66/76/85/95/104/114 の **8 箇所すべてで `</dev/null` なしに呼ぶ**。hook が stdin を待つため非 tty で停止 | なし | **standalone-capable** | ROOT 解決・検査成立ともに問題なし。ただし **直接実行の前提として stdin リダイレクトが必須**。migration 時は 8 箇所へ `</dev/null` 付与か helper 側での一括リダイレクトが要る | medium |
| 48 | `ta-51-doctor-w6.sh` | **rc=0 / P5 F0** | **`GD`** (L12-18) | なし | なし | なし | `mktemp -d` (L21) + `register_cleanup` 条件付き + 末尾 `rm -rf` (L116) | なし | python3 | **standalone-capable** | 規約 8 準拠・5 件成立 | low |
| 49 | `ta-52-doctor-skill-collision.sh` | **rc=0 / P5 F0** | **`GD`** (L11-17) | なし | なし | なし | `mktemp -d` (L20) + `register_cleanup` 条件付き + 末尾 `rm -rf` (L104) | なし | python3 | **standalone-capable** | 規約 8 準拠・5 件成立 | low |
| 50 | `ta-53-doctor-prepush.sh` | **rc=0 / P4 F0** | **`GD`** (L11-17) | なし | なし | なし | `mktemp -d` (L20) + `register_cleanup` 条件付き + 末尾 `rm -rf` (L94) | なし | python3 | **standalone-capable** | 規約 8 準拠・4 件成立 | low |
| 51 | `ta-54-ai-loop-link-selfcontained.sh` | rc=0 / P2 F7 | `FD` (L11) | なし | なし | なし（L37 で trap 非依存を明記） | `mktemp -d` (L38) + `register_cleanup` (L39) + 末尾 `rm -rf` (L138) | なし | python3 | **harness-only** | `register_cleanup: command not found` + rewriter 未解決 | low |
| 52 | `ta-55-c3prime-accept.sh` | rc=0 / **P0** F1 | `FD` (L14) | なし | なし | なし | `mktemp -d` (L33) + `register_cleanup` (L34) | なし | python3 | **harness-only** | `//scripts/ai-loop/c3prime_verify.py` 不在で即 FAIL・PASS 0 件 | low |
| 53 | `ta-56-delivery.sh` | rc=0 / **P0** F1 | `FD` (L16) | なし | なし | なし | `mktemp -d` (L35) + `register_cleanup` (L36) | なし | python3 | **harness-only** | `//scripts/ai-loop/delivery.py` 不在で即 FAIL・PASS 0 件 | low |
| 54 | `ta-57-pr-convergence.sh` | rc=0 / P1 F11 | `FD` (L36) | なし | `return 0` (L54, 関数内) | なし（L31 で trap 不使用を明記） | `mktemp -d` (L44) + `register_cleanup` (L45) + 末尾 `rm -rf` (L668) | なし | python3。`gh` は**python fixture で完全に偽装**（L204 / L537 が「実 subprocess 起動 0 件＝実ネットワーク不到達」を検証）。credential 不要 | **harness-only** | `register_cleanup: command not found` + test module 未解決で 11 件 FAIL | low |
| 55 | `ta-58-git-destructive-guard.sh` | **rc=0 / P40 F0** | **`GD`** (L38-46) | **`pass=0`/`fail=0` (L50-51)** | `return 0` (L132, 関数内) / **`[ "$fail" -eq 0 ] \|\| exit 1` (L382)** | なし（L33 で trap 不使用を明記） | `mktemp -d` ×2 (L73-74) + `register_cleanup` 自前定義 (L53) + 末尾 drain (L377-380) | **明示 `</dev/null`** (L259) | `git`（ローカル sandbox repo のみ。`git push` は**判定文字列**として渡すだけで実行しない） | **standalone-capable** | 契約を**既に完備**（判別・unset・counter・cleanup・summary・exit 1） | low |
| 56 | `ta-59-apply-settings-merge.sh` | **rc=0 / P22 F0** | **`GD+FX`** (L21-43) | **`pass=0`/`fail=0` (L28-29)** | **`[ "$fail" -eq 0 ] \|\| exit 1` (L507)** | なし（L15 で trap 不使用を明記） | `mktemp -d` (L54) + `register_cleanup` 自前定義 (L31) + 末尾 drain (L502-505)。TC-22 が後片付けの実効性を検証 | なし | python3 | **standalone-capable** | 契約を**既に完備** | low |
| 57 | `ta-60-run-evidence.sh` | **rc=0 / P9 F0** | **`GD+FX`** (L24-45) | **`pass=0`/`fail=0` (L30-31)** | **`[ "$fail" = "0" ] \|\| exit 1` (L184)** | なし（L18 で trap 不使用を明記） | `mktemp -d` (L79) + `register_cleanup` (L80) + 末尾明示 `rm -rf` (L179-) | なし | python3（`PLANGATE_PYTHON` で差替可 L49） | **standalone-capable** | 契約を**既に完備**。最新の推奨パターン | low |

---

## 2. capability 内訳（実測）

| capability | 件数 | ファイル |
|---|---|---|
| **standalone-capable** | **16 / 57** | `ta-26`, `ta-39`, `ta-40`, `ta-43`, `ta-44`, `ta-45`, `ta-46`, `ta-47`, `ta-49`, `ta-50`, `ta-51`, `ta-52`, `ta-53`, `ta-58`, `ta-59`, `ta-60` |
| **harness-only** | **41 / 57** | 上記以外の全件 |

**分類不能なファイルは 0 件。第三カテゴリは不要**（§6 参照）。

### 2.1 standalone-capable の内訳（migration 作業量の実態）

| 状態 | 件数 | ファイル | 残作業 |
|---|---|---|---|
| 契約完備（counter 初期化 + summary + `fail>0 → exit 1`） | 4 | `ta-26`, `ta-58`, `ta-59`, `ta-60` | 共通 helper への置換のみ |
| ROOT 解決・env unset は規約 8 準拠、counter/exit code のみ欠落 | 10 | `ta-39`, `ta-43`, `ta-44`, `ta-45`, `ta-46`, `ta-47`, `ta-49`, `ta-51`, `ta-52`, `ta-53` | counter 初期化 + finalizer |
| 上記 + 個別の追加対応が必要 | 2 | `ta-40`（規約 8 判別なし・env unset なし）、`ta-50`（stdin リダイレクト必須） | 上記 + 個別修正 |

> plan.md L75 の問い「standalone-capable files が現在の 11 + ta-26 以外に増えているか」への回答:
> **増えている**。plan 起草時の 11 件（`ta-39`/`43`/`44`/`45`/`46`/`47`/`49`/`50`/`51`/`52`/`53`）+ `ta-26` に加え、
> **`ta-58` / `ta-59` / `ta-60`（規約 8 完全準拠の新規 3 件）と `ta-40`（プローブ型 ROOT 補正）の計 4 件が追加**され 16 件。

## 3. migration risk 内訳（実測）

| risk | 件数 | ファイル | 引き上げ理由 |
|---|---|---|---|
| **high** | **1** | `ta-45` | standalone-capable かつ top-level EXIT trap を張り末尾で解除（§5 P0） |
| **medium** | **9** | `ta-07`, `ta-09`, `ta-24` | top-level EXIT trap を持つ |
| | | `ta-11`, `ta-32`, `ta-38` | 偽 PASS を出す（§4.3）。`fail>0 → exit 1` では検出できない |
| | | `ta-26` | 実行 54 秒・自己再帰起動あり |
| | | `ta-40` | ROOT 解決が README 規約 8 非準拠（プローブ型）・env unset なし |
| | | `ta-50` | stdin 未リダイレクトで無限ハング |
| **low** | **47** | 上記以外 | — |

合計 1 + 9 + 47 = **57**。

---

## 4. 【最重要】#921 の症状を実証するデータ

### 4.1 standalone 実行で rc=0 なのに `[FAIL]` を出しているファイル — **35 件**

「失敗が静かに通る」という #921 の主張そのもの。**FAIL を 1 件でも出したファイルのうち、非 0 の exit code を返したものは 0 件**。

| # | file | `[FAIL]` 件数 | `[PASS]` 件数 |
|---|---|---|---|
| 1 | `ta-05-validate-schemas.sh` | 2 | 2 |
| 2 | `ta-07-eval-runner.sh` | 3 | 0 |
| 3 | `ta-09-metrics.sh` | **21** | 2 |
| 4 | `ta-10-doctor-fix.sh` | 10 | 2 |
| 5 | `ta-12-maintenance.sh` | 13 | 1 |
| 6 | `ta-13-plangate-setup.sh` | 10 | 7 |
| 7 | `ta-14-codex-guarded.sh` | 8 | 0 |
| 8 | `ta-14-skip-acknowledge.sh` | 11 | 1 |
| 9 | `ta-15-codex-hook-bridge.sh` | 7 | 0 |
| 10 | `ta-16-pollution-guard.sh` | 12 | 2 |
| 11 | `ta-17-pre-push-guard.sh` | 13 | 1 |
| 12 | `ta-18-tag-main-parity.sh` | 11 | 4 |
| 13 | `ta-19-plan-metrics-verification.sh` | 8 | 2 |
| 14 | `ta-20-codex-review.sh` | 9 | 1 |
| 15 | `ta-21-codex-mvp-split.sh` | 9 | 0 |
| 16 | `ta-22-git-add-scope.sh` | 8 | 0 |
| 17 | `ta-23-gh-account-pin.sh` | 7 | 0 |
| 18 | `ta-24-parallel-review.sh` | 4 | 6 |
| 19 | `ta-25-approval-token-guard.sh` | 7 | 0 |
| 20 | `ta-27-codex-commands.sh` | 3 | 2 |
| 21 | `ta-28-plugin-version.sh` | 10 | 1 |
| 22 | `ta-29-committed-pollution.sh` | 4 | 1 |
| 23 | `ta-30-install-skills.sh` | 9 | 0 |
| 24 | `ta-31-codex-plugin-status.sh` | 7 | 0 |
| 25 | `ta-33-agent-model-tier.sh` | 2 | 2 |
| 26 | `ta-34-cli-min-coverage.sh` | 5 | 1 |
| 27 | `ta-35-yaml-schema.sh` | 1 | 1 |
| 28 | `ta-36-fixloop-event.sh` | 1 | 0 |
| 29 | `ta-37-cli-coverage-batch2.sh` | 6 | 1 |
| 30 | `ta-41-approve-hardening.sh` | 6 | 1 |
| 31 | `ta-42-cli-subcommands.sh` | 9 | 1 |
| 32 | `ta-54-ai-loop-link-selfcontained.sh` | 7 | 2 |
| 33 | `ta-55-c3prime-accept.sh` | 1 | 0 |
| 34 | `ta-56-delivery.sh` | 1 | 0 |
| 35 | `ta-57-pr-convergence.sh` | 11 | 1 |

**合計 FAIL 件数: 256 件。そのすべてが exit code 0 で握り潰されている。**

### 4.2 standalone 実行で `[PASS]` が 0 件のファイル — **14 件**

検査が 1 件も走らず素通りしている（`[FAIL]` すら出ない 2 件を含む）。

| # | file | `[PASS]` | `[FAIL]` | `[SKIP]` | 素通りの態様 |
|---|---|---|---|---|---|
| 1 | `ta-06-hooks.sh` | 0 | 0 | 1 | **FAIL すら出ず SKIP のみで完全素通り** |
| 2 | `ta-07-eval-runner.sh` | 0 | 3 | 0 | 全 FAIL |
| 3 | `ta-08-codex-log-parser.sh` | 0 | 0 | 1 | **FAIL すら出ず SKIP のみで完全素通り** |
| 4 | `ta-14-codex-guarded.sh` | 0 | 8 | 0 | 全 FAIL |
| 5 | `ta-15-codex-hook-bridge.sh` | 0 | 7 | 0 | 全 FAIL |
| 6 | `ta-21-codex-mvp-split.sh` | 0 | 9 | 0 | 全 FAIL |
| 7 | `ta-22-git-add-scope.sh` | 0 | 8 | 0 | 全 FAIL |
| 8 | `ta-23-gh-account-pin.sh` | 0 | 7 | 0 | 全 FAIL |
| 9 | `ta-25-approval-token-guard.sh` | 0 | 7 | 0 | 全 FAIL |
| 10 | `ta-30-install-skills.sh` | 0 | 9 | 0 | 全 FAIL |
| 11 | `ta-31-codex-plugin-status.sh` | 0 | 7 | 0 | 全 FAIL |
| 12 | `ta-36-fixloop-event.sh` | 0 | 1 | 0 | 全 FAIL |
| 13 | `ta-55-c3prime-accept.sh` | 0 | 1 | 0 | 全 FAIL |
| 14 | `ta-56-delivery.sh` | 0 | 1 | 0 | 全 FAIL |

**特に危険な 2 件**: `ta-06` / `ta-08` は `[PASS]`=0 かつ `[FAIL]`=0 かつ rc=0。
「静かに通る」どころか **何も検査していないことすら出力から判らない**。
`fail > 0 → exit 1` だけでは救えず、**harness-only の直接実行拒否（exit 2）が必要**な代表例。

### 4.3 【追加発見】rc=0・FAIL=0 だが assertion が空振りしている「偽 PASS」— **3 件**

#921 の issue 本文には無い、**より危険な症状クラス**。ROOT が誤解決した結果、
検査対象が「存在しない」ため assertion が成立してしまい、**FAIL が 1 件も出ない**。
`fail > 0 → exit 1` を導入しても **この 3 件は検出できない**。

| file | 偽 PASS 件数 | 機序 |
|---|---|---|
| `ta-11-plan-hash-contract.sh` | 4 / 4（全件） | `PHC_FIX="//plan-hash-contract"` で fixture が全欠落 → `phc_shell` も `phc_python` も空文字を返し「shell≡python の parity 一致」で PASS |
| `ta-32-real-ssot-pollution.sh` | 2 / 2（全件、うち 1 件は WARN で `pass` 加算） | `//scripts/check-committed-memory-pollution.sh` が rc=127 → TC-01 は「汚染検出」と誤認して WARN(pass 加算)、TC-02 は「guard が非 0 を返した＝正常」と誤認して PASS |
| `ta-38-agent-tools.sh` | 1 / 1（全件） | `_t38_root="tests/"` → `tests/.claude/agents/*.md` が 0 件マッチ → 検査対象 0 件で `_t38_bad` が空のまま PASS |

**含意**: `standalone-capable` の判定を「standalone で FAIL が出ないこと」だけに置くと
この 3 件を誤って standalone-capable に分類する。本 inventory は
**ROOT 解決の正しさ（fixture fallback 欄）を第一基準**にして分類しており、
3 件はすべて `harness-only` に落としている。

### 4.4 ハング / timeout したファイル

| file | 条件 | 結果 |
|---|---|---|
| `ta-50-precompact-guard.sh` | **stdin 未リダイレクト**（非 tty 継承） | **無限ハング**。alarm 20s で rc=142、出力はヘッダ 1 行のみ。`</dev/null` を付ければ rc=0 / 9 PASS |
| `ta-26-plugin-sync.sh` | alarm **60s** | 打ち切り（rc=142、TC-12 まで） |
| `ta-26-plugin-sync.sh` | alarm **240s** | **ハングではない**。**54 秒**で正常完了・rc=0・`TA-26 standalone: 30 passed, 0 failed` |

- `ta-26` の 54 秒は TC-13 が **自分自身を standalone で子プロセスとして 2 回起動する**ため
  （`PG_T26_NO_RECURSE=1` で再帰防止）。ファイル冒頭 L63 に「合計約 13 秒」の記載があるが、
  本測定では **54 秒**。CI/contract test のタイムアウト設計時に考慮が要る。
- standalone-capable 候補 16 件を **stdin 未リダイレクト**で再実行した結果、
  **ハングするのは `ta-50` のみ**（他 15 件は rc=0 で完走）。

---

## 5. 【P0】plan.md 案 C の replan トリガに該当する発見

plan.md L95:

> ただし、exec 前 inventory で **top-level exit trap を持つ extras が 1 件でも見つかり
> 共存方法を証明できない場合は、案 D へ replan する。trap 導入を強行しない。**

**該当する。top-level EXIT trap を持つ extras は 4 件見つかった。**

| file | trap 設置 | trap 解除 | capability | 案 C helper への影響 |
|---|---|---|---|---|
| **`ta-45-c3-mode-config.sh`** | `trap cleanup_t45 EXIT` (L76) | **`trap - EXIT` (L224)** | **standalone-capable** | **最も深刻**。standalone 時に helper が張る exit trap を (a) L76 で**上書き**し、(b) L224 で**完全に消す**。結果 finalizer が発火せず `fail>0` でも rc=0 のまま — 修正対象そのものが修正機構を無効化する |
| `ta-07-eval-runner.sh` | `trap cleanup_eval EXIT INT TERM` (L13) | `trap - EXIT INT TERM` (L49) | harness-only | harness-only は body 到達前に exit 2 で拒否する設計のため、trap 到達前に終わるなら影響は限定的。ただし **拒否 guard が trap 設置行より前にあること**が前提条件になる |
| `ta-09-metrics.sh` | `trap cleanup_metrics EXIT INT TERM` (L23) | **解除なし** | harness-only | 同上 |
| `ta-24-parallel-review.sh` | `trap 'rm -rf "$t24_tmpdir4"' EXIT INT TERM` (L252) | `trap - EXIT INT TERM` (L280) | harness-only | 同上 |

> 参考: `ta-28-plugin-version.sh` の trap (L87 / L114) は **サブシェル内に閉じ込め済み**
> （L82 / L110 にその意図がコメントで明記）で、親シェルの trap を汚染しない。
> 案 C が採るべきパターンの既存例。

**判断は Human 側（plan.md L95 の replan 判定）に委ねる。**本 Phase では事実の提示のみ行う。
参考として、案 C を維持しうる回避策は以下（いずれも要検証・本 Phase では未実施）:

1. `ta-45` の `trap cleanup_t45 EXIT` / `trap - EXIT` を `register_cleanup` + 末尾明示 `rm -rf`
   へ書き換える（`ta-58`/`ta-59`/`ta-60` と同じ trap 非依存パターン。README §隔離・後始末の規約 2 に合致）
2. helper の finalizer を exit trap ではなく **各ファイル末尾の明示呼び出し**にする
   （= `ta-26`/`ta-58`/`ta-59`/`ta-60` が既に採っている方式。`early exit` が無い前提が要る）

案 2 は現在 `standalone-capable` 16 件中 8 件が持つ `return 0 2>/dev/null || exit 0` 型の
early exit（`ta-31`, `ta-39`, `ta-43`, `ta-44`, `ta-45`, `ta-46`, `ta-47`, `ta-49`）を
finalizer 経由に書き換える必要がある点に注意。

---

## 6. 第三カテゴリの要否

**不要。57 件すべてが `standalone-capable` / `harness-only` の 2 分類で表現できた。**

判断の根拠:

- §4.3 の「偽 PASS」3 件は新カテゴリではなく、**`harness-only` の一形態**
  （分類基準「直接実行すると未定義値や誤ったパスで動く」に正しく合致する）。
  ただし *検出方法* としては `fail>0 → exit 1` では捕まらないため、
  **harness-only の直接実行拒否（exit 2）が必須**であることの補強材料になる。
- §4.2 の「PASS 0 件」14 件も同様に `harness-only` に収まる
  （分類基準「test body が意味のある検査として成立しない」）。
- `ta-50` の stdin ハングは capability の問題ではなく **呼び出し規約の問題**
  （`standalone-capable` のまま、migration 時に `</dev/null` を付与すれば解決）。
- `ta-45` の top-level trap も capability ではなく **実装方式の問題**
  （`standalone-capable` のまま、§5 の回避策で解決しうる）。

---

### 4.5 【追加発見】standalone 実行が repo を汚染する — `ta-09`

standalone 実行後、**リポジトリに未追跡ファイルが残留**した:

```
tests/docs/working/_audit/hook-events.log   (5 行 / TASK-9991 の fixture イベント)
```

- 機序: `ta-09-metrics.sh` は `METRICS_REPO_ROOT="$(dirname -- "$0")/.."`(`T0`) を使うため、
  standalone では ROOT が `tests/` になり、hook が `tests/docs/working/_audit/` へ書き込む。
- `cleanup_metrics` (L17) が削除するのは `$METRICS_TASK_DIR`（= `tests/docs/working/TASK-9991`）だけで、
  **`_audit/` 配下は回収対象外**のため残る。
- 実 `docs/working/_audit/skip-decision-log.jsonl` は**汚染されていない**（sha 不変を実測確認済み）。
  汚染先が誤 ROOT 配下だったのは偶然の幸運であり、`FD` 型（ROOT=`//`）が Read-only FS で
  失敗しているのと同様、**設計による防御ではない**。
- 本 Phase は書き込み許可範囲外のため **この残留ファイルは削除していない**（§7-5 参照）。

**含意**: harness-only の直接実行拒否（exit 2）は「静かに通る」の解消だけでなく、
**実リポジトリ汚染の防止**としても必要。

---

## 7. 本 Phase で観測したスコープ外事項（報告のみ・未着手）

1. **`/tmp` 固定名ファイルの残留** — `ta-49-bias-export.sh` L52 / L60 が
   `/tmp/ta49_err` / `/tmp/ta49_err2` を固定名で作成し削除していない。
   並行実行時の衝突・他ユーザとの競合の可能性（README §隔離・後始末の規約 3 に抵触しうる）。
2. **`ta-26` の実行時間乖離** — ファイル冒頭コメント L63 は「合計 約 13 秒」だが実測 **54 秒**。
   自己再帰起動 2 回分が算入されていない可能性。contract test のタイムアウト設計に影響。
3. **`docs/working/_audit/hook-events.log.bak.*` が 40 個超堆積** — 本 Phase の実行とは無関係だが、
   `_audit/` に PID 付きバックアップが大量に残存している。
4. **並行セッションの成果物が同一ディレクトリに存在** — 本 Phase の実行中に
   `docs/working/TASK-0921/evidence/inventory/trap-cleanup-audit.md`（Phase 2 / trap 監査、
   別セッション作成）と `.gitkeep` が同ディレクトリに存在することを確認した。
   **本 Phase では一切読み書きしていない**（内容の重複・矛盾がないかは Human 側で突合を推奨。
   本 inventory §5 と主題が重なる）。同様に `docs/working/TASK-0921/decision-log.jsonl` の modify と
   `review-external.md` の追加も別セッション由来であり触れていない。
5. **standalone 実行の残留ファイル `tests/docs/working/_audit/hook-events.log`（未追跡・5 行）** —
   §4.5 の `ta-09` 由来。**書き込み許可範囲外のため削除していない**。
   誤って commit されないよう Human 側での削除を推奨（`rm -rf tests/docs`）。
6. **checkout の branch が `main` ではなく `docs/1009-pbi-input`** — 指示では `main` 想定だったが
   HEAD は指定どおり `4448420`。**branch 切替は行っていない**（別セッションの並行作業を尊重）。
   作業ツリーには他セッション由来の未コミット変更
   （`docs/working/_audit/skip-decision-log.jsonl` の modify、`docs/working/TASK-0874/approvals/`、
   `docs/working/TASK-1009/` の untracked）があり、**一切触れていない**。
