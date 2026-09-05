# #1278 — EH-3 `log_event` の監査ログ書込失敗を block 判定から分離する（機械適用可能な patch）

> 測定基点: **`origin/main` = `f23d31d`**（PR #1274 マージ後）/ 2026-09-06。以下の rc・出力はすべてこの ref を `git archive HEAD | tar -x` で展開したサンドボックス複製に対する実測（uid=502 の一般ユーザー、macOS `/bin/sh`）。
> 関連: issue #1278（再現手順・最小修正案）/ 先例 [`1104-bash-lane-noop-patch-applicable.md`](./1104-bash-lane-noop-patch-applicable.md)（本書は同じ marker 規則・同じ §構成）/ `tests/extras/ta-79-eh3-bash-lane.sh`（サンドボックス複製 + patch 適用 + rc 実測の書き方）
> 位置づけ: **既存ギャップの是正**（PR #1271 の退行ではない。#1278 本文のとおり）。`scripts/hooks/*.sh` は Hardening Override 対象のため AI は patch 文書提示まで。**適用は Human-owned**。
> 本書で AI が作成したのは本ファイル 1 本のみ。`scripts/` / `tests/` / `.claude/` / `bin/` / `schemas/` / `.github/` は **1 バイトも変更していない**。
> **未検証: 実 Claude Code セッション 1 周**（PreToolUse 経由で exit 2 が実際に block として扱われる経路は fixture では測れない。§6）。

---

## 0. 結論先行

| 項目 | 結論 |
|---|---|
| **何が起きているか** | `log_event` は `set -eu` 下で `mkdir -p` / `printf >>` が失敗すると **rc=1 で即死**し、その直後の `exit 2`（HO 9 カテゴリ / no-task `plan.md` block）に到達しない。Claude Code の PreToolUse は **exit 2 のみ block** なので、監査ログが書けない環境では **防御が丸ごと fail-open** |
| **再現 3 ケース（before）** | `hook-events.log` が 444 / `_audit` がファイル / いずれも HO `CLAUDE.md` と no-task `plan.md` が **rc=1**（期待 2）。§1 |
| **採った方針** | `log_event` の `mkdir` と `printf >>` を `\|\| { WARN を stderr; return 0; }` で保護し、**block 判定をログ可否から独立**させる（issue の最小修正案どおり）。after は同 3 ケースで **rc=2**、正常系は不変。§2 |
| **`skip-decision-log.jsonl` への直接 `>>`（3 箇所）** | **本 patch では据え置き**。到達先が `exit 0` の SKIP 経路であり rc=1 も rc=0 も Claude Code 上は「続行」で **block の fail-open は生じない**。fail-closed 化（記録できなければ SKIP しない）は新しい block クラスを増やす Human 判断事項として §7 に送る。§3 |
| **patch 対象** | `scripts/hooks/check-plan-hash.sh` のみ（**+11 / -2**、`log_event` 本体 + 説明コメント 7 行） |
| **検出力** | 保護句を外した変異版で再現 3 ケースが **rc=1 に戻る**ことを実測（§4 表 / §6 変異 TC） |
| **併記 Low（`PLANGATE_HOOK_STRICT=1` + Bash NOOP = rc=0）** | 本 patch では扱わない。契約文言の更新案のみ §7 |

---

## 1. 実測（before = `f23d31d` の hook をそのまま実行）

hook は `$0` 由来で `REPO_ROOT` を決めるため、サンドボックス複製で実 repo を汚さずに測れる（`tests/extras/README.md` 規約 3）。すべて `PLANGATE_HOOK_TASK` 未設定（no-task）、stdin は `</dev/null`（Bash NOOP 行のみ `{"tool_name":"Bash",...}` を stdin 投入）。

| # | 前提（`docs/working/_audit`） | 対象 | rc | 出力 1 行目 |
|---|---|---|---|---|
| ctl-1 | 書込可（正常系） | HO `CLAUDE.md` | **2** | `[Hook EH-3] HARDENING_OVERRIDE: CLAUDE.md は maintenance 窓内でも常時 block` |
| ctl-2 | 書込可 | no-task `docs/working/TASK-9999/plan.md` | **2** | `[Hook EH-3] BLOCK: plan.md edited without TASK context.` |
| ctl-3 | 書込可 | 非 HO `docs/foo.md` | 0 | `[Hook EH-3 DOC_LIGHT_SKIP] ...` |
| ctl-4 | 書込可 | 非 md `README.txt` + `PLANGATE_SKIP_REASON=probe` | 0 | `[Hook EH-3 SKIP] ...` |
| ctl-5 | 書込可 | Bash payload（対象パスなし） | 0 | `[Hook EH-3 BASH_LANE_NOOP] ...` |
| **c1-1** | `hook-events.log` を `chmod 444` | HO `CLAUDE.md` | **1** | `...hook-events.log: Permission denied`（shell の生エラー） |
| **c1-2** | 同上 | no-task `plan.md` | **1** | 同上 |
| c1-3 | 同上 | 非 HO `docs/foo.md` | 1 | 同上（DOC_LIGHT_SKIP に到達せず） |
| c1-4 | 同上 | Bash NOOP | 1 | 同上（NOOP に到達せず） |
| **c2-1** | `_audit` を通常ファイルにする | HO `CLAUDE.md` | **1** | `mkdir: ...: Not a directory` |
| **c2-2** | 同上 | no-task `plan.md` | **1** | 同上 |
| c2-3 | 同上 | 非 HO `docs/foo.md` | 1 | 同上 |
| c3-1 | `_audit` を `chmod 555`（`hook-events.log` は既存・書込可、`skip-decision-log.jsonl` は不在） | HO `CLAUDE.md` | 2 | HARDENING_OVERRIDE（`log_event` は成功するので正常） |
| c3-2 | 同上 | 非 HO `docs/foo.md` | 1 | `...skip-decision-log.jsonl: Permission denied`（直接 `>>` で死ぬ） |
| c3-3 | 同上 | `README.txt` + SKIP_REASON | 1 | 同上 |
| c3-4 | 同上 | Bash NOOP | 0 | BASH_LANE_NOOP（issue 本文の「`_audit` が 555 でもファイルが書ければ rc=0」と一致） |

### 何が壊れているか

`check-plan-hash.sh:20` の `set -eu` と `:26-32` の `log_event` の組合せ:

```sh
log_event() {
  level=$1
  msg=$2
  mkdir -p "$(dirname "$AUDIT_LOG")"          # _audit がファイル → rc=1 で即死
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  printf '...' ... >>"$AUDIT_LOG"             # log が 444 / FS が RO → rc=1 で即死
}
```

HO block（`:357` / `:381`）も plan.md block（`:400`）も **`log_event` → `exit 2` の順**で書かれているため、`log_event` が死ねば `exit 2` は実行されない。Claude Code の PreToolUse hook の契約は「exit 2 = block、それ以外の非 0 = non-blocking error（stderr をユーザーに見せて続行）」なので、**rc=1 は「エラー表示つきの許可」**である。監査ログを書けなくする条件（read-only checkout / `_audit` の誤ファイル化 / ディスク満杯 / 権限の取り違え）は攻撃でなくとも運用で普通に起きる。

---

## 2. 方針: ログ可否と判定を分離する

**`log_event` の失敗は stderr 警告に留め、呼び出し元の判定（`exit 0` / `exit 2`）をそのまま進める。**

| 設計判断 | 理由 |
|---|---|
| `mkdir -p` と `printf >>` を **別々に** `\|\| { ...; return 0; }` で保護 | 失敗点が 2 つ（ディレクトリ作成 / ファイル追記）あり、どちらで死んでも判定に届かない。片方だけ守ると c2 か c1 のどちらかが残る |
| `2>/dev/null` を **`>>` より前**に置く | リダイレクトは左から右に処理される。`>>"$AUDIT_LOG" 2>/dev/null` の順だと `>>` の失敗メッセージが `2>/dev/null` の適用前に元の stderr へ出る（実測: 初版 patch で shell の `Permission denied` が WARN と二重に出た）。前に置けば生エラーは消え、WARN 1 行に統一される |
| WARN は **stderr** に、event 名つきで | Claude Code は exit 2 のとき stderr をモデルに、それ以外はユーザーに見せる。いずれの経路でも「監査が欠落した」事実が届く。イベント名（`HARDENING_OVERRIDE` 等）を含めるので、log が無くても何が起きたかは残る |
| `return 0`（`exit` しない） | `log_event` は判定の前後どちらでも呼ばれる。ここで exit すると判定の主体が関数側に移り、今回と同型の「到達しない」を作る |
| `log_event` の呼び出し元は **一切変更しない** | 差分を `log_event` 1 関数に閉じる。判定ロジック（HO 9 カテゴリ / plan.md / STRICT / maintenance / doc-light / NOOP）は不変 |

### 何が変わり、何が変わらないか（after 実測 / patch 適用サンドボックス）

| # | 前提 | 対象 | before | **after** | 出力 1 行目（after） |
|---|---|---|---|---|---|
| ctl-1..5 | 書込可 | 正常系 5 種 | 2 / 2 / 0 / 0 / 0 | **2 / 2 / 0 / 0 / 0**（不変） | before と同一文言 |
| c1-1 | log 444 | HO `CLAUDE.md` | 1 | **2** | `[Hook EH-3] WARN: audit log unavailable (...hook-events.log) -- event HARDENING_OVERRIDE not recorded` → 次行に HARDENING_OVERRIDE |
| c1-2 | log 444 | no-task `plan.md` | 1 | **2** | WARN → `[Hook EH-3] BLOCK: plan.md edited without TASK context.` |
| c1-3 | log 444 | 非 HO `docs/foo.md` | 1 | **0** | WARN → DOC_LIGHT_SKIP |
| c1-4 | log 444 | Bash NOOP | 1 | **0** | WARN → BASH_LANE_NOOP |
| c2-1 | `_audit` がファイル | HO `CLAUDE.md` | 1 | **2** | WARN（`mkdir` 側） → HARDENING_OVERRIDE |
| c2-2 | `_audit` がファイル | no-task `plan.md` | 1 | **2** | WARN → BLOCK |
| c2-3 | `_audit` がファイル | 非 HO `docs/foo.md` | 1 | 1 | `mkdir: ...: Not a directory`（§3 の据え置き箇所。到達先は exit 0 の SKIP） |
| c3-1 | `_audit` 555 | HO `CLAUDE.md` | 2 | 2 | 不変 |
| c3-2 / c3-3 | `_audit` 555 | doc-light / SKIP_REASON | 1 | 1 | §3 の据え置き箇所 |
| c3-4 | `_audit` 555 | Bash NOOP | 0 | 0 | 不変 |

`sh -n` は before / after / 変異版すべて通過。

---

## 3. `skip-decision-log.jsonl` への直接 `>>` は据え置く（判断と根拠）

同型の「`set -eu` 下の保護なし `>>`」は `skip-decision-log.jsonl` へ **3 箇所**ある（issue 本文は「SKIP 経路」と総称。実数は 3）:

| 行 | event | 到達先 |
|---|---|---|
| `:451` | `EH-3_C3_CONVERSATION_SKIP` | `exit 0` |
| `:472` | `EH-3_DOC_LIGHT_SKIP` | `exit 0` |
| `:574` | `EH-3_SKIP`（no-task + `PLANGATE_SKIP_REASON`） | `exit 0` |

**判断: 本 patch では触らない。** 根拠:

1. **block の fail-open は生じない。** 3 箇所とも到達先は `exit 0`（許可）である。書込失敗で rc=1 になっても、Claude Code 上は rc=0 と同じく「続行」。つまり **判定の結果（許可）は変わらず、失われるのは記録だけ**。#1278 の主題（exit 2 に到達しない）とはクラスが違う。
2. **選択肢は 2 つあり、どちらも「同型で保護」ではない。**
   - (a) `\|\| { WARN; }` で保護して `exit 0` を続ける = 記録なしで SKIP を通す。**現状（rc=1 で続行）と実効挙動は同じ**で、shell の生エラーが WARN に変わるだけ。CI（`scripts/check-skip-acknowledged.sh`）が未追認エントリで落ちる補償統制は、エントリ自体が無ければどのみち働かない。
   - (b) 記録できなければ `exit 2` = **「記録付き自動 SKIP」の前提を fail-closed に倒す**。ガバナンス上はこちらが筋（記録が SKIP の条件）だが、**新しい block クラス**（`_audit` が書けないと非 HO `.md` すら編集不可）を導入する。read-only checkout や `_audit` 権限事故で docs 作業が止まるため、可用性側の影響を Human が引き受ける判断が要る。
   (a) は「直した」ように見えて監査欠落を隠す方向（生エラーの方が目立つ）、(b) は本 issue のスコープ外の挙動変更。どちらも AI が patch に紛れ込ませる種類のものではない。
3. **rc=1 の生エラーは、現状では監査欠落の最も強い可視化になっている。** stderr にパスと `Permission denied` / `Not a directory` が出るので、ユーザーは `_audit` の異常に気づける。(a) にすると WARN 1 行になり弱まる。

したがって (b) を §7 の Human 判断事項として提示し、本 patch は `log_event` に閉じる。

---

## 4. 残存脅威モデル（完全性を主張しない）

### 守るもの（本 patch 後）

- `hook-events.log` が **書けない**（RO / 444 / `_audit` がファイル / `_audit` 不在で mkdir 不可 / ENOSPC）とき、HO 9 カテゴリと no-task `plan.md` の **exit 2 が維持される**（c1 / c2 実測）。
- 正常系の rc と出力は不変（ctl-1..5 実測）。
- 監査欠落は stderr の `[Hook EH-3] WARN: audit log unavailable (<path>) -- event <LEVEL> not recorded` で可視化される。

### 守らないもの

| 残存 | 内容 | 保証の主体 |
|---|---|---|
| **`skip-decision-log.jsonl` の書込失敗** | §3 のとおり SKIP 3 経路は rc=1（続行・記録なし）のまま | Human 判断（§7 (b)）/ 現状は stderr 生エラーの目視 |
| **`log_event` 以外の `set -e` 死** | `date` / `sha256sum` / `python3` の失敗など、`log_event` 以前に rc≠2 で終わる経路は本 patch の対象外（今回の 3 ケースでは観測されず） | 別 issue（本書は監査ログ書込のみを扱う） |
| **監査ログの改ざん・削除** | 書けない環境を「作る」こと自体（`chmod 444` / `_audit` のファイル化）は AI にも可能。本 patch は「作られても block は残る」までで、作ったこと自体は検出しない | `git status` / C-4 Human レビュー（`_audit` は tracked） |
| **rc=1 を block と誤認する運用** | 「エラーが出た＝止まった」と読む人間の誤認は残る | 本書 §1 の契約説明 / hook 冒頭コメント |
| **exit 2 が実際に block になること** | fixture は rc を測るだけ。Claude Code が exit 2 を block として扱う経路は **実セッション 1 周でしか確認できない**（未検証） | §6 |
| **Bash レーンの write-intent 未解析** | #1104 open のまま（本 patch と直交） | #1104 |

本検査は多層防御の 1 層（hook 層）の、さらに「監査ログ書込」という 1 側面のみを扱う。

### 変異注入（検出力の実証）

patch 適用後の複製から `\|\| { printf '[Hook EH-3] WARN: ...' >&2; return 0; }` を **2 箇所とも除去**した変異版（`2>/dev/null` は残す）に §1 と同じケースを流した:

| # | 前提 | 対象 | patch 後 | **変異版** | 判定 |
|---|---|---|---|---|---|
| c1-1 | log 444 | HO `CLAUDE.md` | 2 | **1** | 検出（`return 0` が無いと再び到達しない） |
| c1-2 | log 444 | no-task `plan.md` | 2 | **1** | 検出 |
| c1-3 / c1-4 | log 444 | doc-light / NOOP | 0 | 1 | 検出 |
| c2-1 | `_audit` がファイル | HO `CLAUDE.md` | 2 | **1** | 検出（`mkdir` 側） |
| c2-2 | `_audit` がファイル | no-task `plan.md` | 2 | **1** | 検出 |
| ctl-1..5 | 書込可 | 正常系 | 2/2/0/0/0 | 2/2/0/0/0 | 変異は正常系に影響しない（= 正常系だけ見ても検出できない） |

変異版は `2>/dev/null` が残るため **出力 1 行目が空**になる（生エラーすら出ずに rc=1）。「`2>/dev/null` を足しただけで保護句を忘れる」変異は、before よりさらに静かな fail-open になることを示している。

---

## 5. patch（`git apply` 可能）

patch 本体は下の **`<!-- PG-PATCH-BEGIN -->` / `<!-- PG-PATCH-END -->` に挟まれた fenced block**。
抽出は marker 基準で行う（fence ラベルで探すと、本節の説明文中の fence 自身に誤ヒットする）。

````sh
# repo root で実行（Human-owned: HO パスへの書き込み）
sed -n '/^<!-- PG-PATCH-BEGIN -->$/,/^<!-- PG-PATCH-END -->$/p' \
  docs/working/_reports/1278-log-event-fail-closed-patch-applicable.md \
  | sed -e '1d' -e '$d' | sed -e '1d' -e '$d' > /tmp/1278-log-event.patch
git apply --check /tmp/1278-log-event.patch && git apply /tmp/1278-log-event.patch
sh -n scripts/hooks/check-plan-hash.sh
````

（`sed` を 2 回通すのは marker 行と fence 行を外側から 1 組ずつ落とすため。先例 1104 と同じ規則。）

`git apply --check` は **`f23d31d` の `scripts/hooks/check-plan-hash.sh` に対して rc=0**、適用結果はサンドボックスで直接編集した版と **`cmp` で一致**（§6）。diffstat: `scripts/hooks/check-plan-hash.sh | 13 +++++++++++--`（11 insertions, 2 deletions）。

<!-- PG-PATCH-BEGIN -->
```diff
diff --git a/scripts/hooks/check-plan-hash.sh b/scripts/hooks/check-plan-hash.sh
--- a/scripts/hooks/check-plan-hash.sh
+++ b/scripts/hooks/check-plan-hash.sh
@@ -23,12 +23,21 @@ REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
 WORKING_DIR="$REPO_ROOT/docs/working"
 AUDIT_LOG="$WORKING_DIR/_audit/hook-events.log"
 
+# #1278: 監査ログの書込可否と block 判定を分離する（fail-open 防止）。
+# set -eu 下で mkdir / >> が失敗すると log_event の時点で rc=1 となり、後続の
+# exit 2（HO / plan.md block）に到達しない。Claude Code の PreToolUse は exit 2
+# 以外を block と扱わないため、監査ログが書けない環境（read-only FS / _audit の
+# ファイル化 / ディスク満杯）では防御が丸ごと外れていた。ログ失敗は stderr 警告
+# に留め、呼び出し元の判定（exit 0 / exit 2）をそのまま進める。
+# 監査欠落の可視化は stderr の "[Hook EH-3] WARN: audit log unavailable" が担う。
 log_event() {
   level=$1
   msg=$2
-  mkdir -p "$(dirname "$AUDIT_LOG")"
+  mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null \
+    || { printf '[Hook EH-3] WARN: audit log unavailable (%s) -- event %s not recorded\n' "$AUDIT_LOG" "$level" >&2; return 0; }
   ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
-  printf '%s\t%s\tcheck-plan-hash\t%s\t%s\n' "$ts" "$level" "${task_id:-${PLANGATE_HOOK_TASK:--}}" "$msg" >>"$AUDIT_LOG"
+  printf '%s\t%s\tcheck-plan-hash\t%s\t%s\n' "$ts" "$level" "${task_id:-${PLANGATE_HOOK_TASK:--}}" "$msg" 2>/dev/null >>"$AUDIT_LOG" \
+    || { printf '[Hook EH-3] WARN: audit log unavailable (%s) -- event %s not recorded\n' "$AUDIT_LOG" "$level" >&2; return 0; }
 }
 
 sha256_of() {
```
<!-- PG-PATCH-END -->

### 適用後にやること

1. `sh -n scripts/hooks/check-plan-hash.sh` が通ることを確認する
2. `tests/extras/ta-65-eh3-ho-task-context.sh` / `ta-79-eh3-bash-lane.sh` を standalone 実行して既存 TC が全 PASS（本 patch は判定ロジックを変えないので退行があれば patch 側の誤り）
3. §6 の回帰 TC を `ta-79` へ追加し、**patch 適用前の hook で FAIL すること**（変異 TC）を 1 度実走して確認する
4. `plugin/plangate/` へのミラーは対象外（`scripts/hooks/` は plugin 配布物に含まれない。CLAUDE.md v8.21.0 節）

---

## 6. 検証済みであること / 未検証であること

| 項目 | 状態 |
|---|---|
| before: 再現 3 ケース（log 444 / `_audit` ファイル / no-task `plan.md`）が rc=1 | ✅ 実測（§1。`plan.md` は c1-2 / c2-2） |
| `git apply --check` が `f23d31d` の hook に対して rc=0 | ✅ 実測 |
| `git apply` 結果がサンドボックス直接編集版と `cmp` 一致 | ✅ 実測（`index` 行を落とした最終形でも一致） |
| after: 同 3 ケースが rc=2、正常系 5 種が不変 | ✅ 実測（§2 表） |
| `sh -n` 通過（before / after / 変異版） | ✅ 実測 |
| 変異注入（保護句除去）で再現ケースが rc=1 に戻る | ✅ 実測（§4 表） |
| **実 Claude Code セッション 1 周**（PreToolUse 経由で exit 2 が block として扱われ、stderr WARN がモデル/ユーザーに届く） | ❌ **未検証**。fixture は rc しか測れない。Human 適用後に `chmod 444 docs/working/_audit/hook-events.log` 状態で HO ファイルへの Write を 1 回試し、block されることを見てから戻す |
| `tests/run-tests.sh` / `ta-61` 全体走行 | ❌ 未実施（本ワーカーの実行制約）。patch は判定ロジック非接触のため既存 TC への影響は理論上ゼロだが、実測はしていない |
| Linux（dash / GNU coreutils）での再現 | ❌ 未実測。`>>` 失敗と `mkdir` 失敗が非 0 を返す挙動は POSIX で共通だが、エラー文言は異なる（TC は rc のみで判定すること） |

### 回帰 TC 仕様（`ta-79` へ追加。`.sh` は本ワーカーが書けないため仕様のみ）

`ta-79` は既に「patch 文書 → marker 抽出 → サンドボックス複製へ `git apply` → rc 実測」の seam（TC-00c）を持つ。同じ骨組みで、本書の marker から patch を取る第 2 の抽出（`_T79_PATCH_1278`）を足し、以下を追加する。判定は **rc のみ**（stderr 文言は OS 依存）。

| TC | 前提（サンドボックス複製） | 入力 | 期待 rc | 備考 |
|---|---|---|---|---|
| TC-10a | patch 適用後 / `_audit/hook-events.log` を `chmod 444` | `PLANGATE_HOOK_FILE=CLAUDE.md`、stdin `</dev/null` | **2** | c1-1 |
| TC-10b | 同上 | `PLANGATE_HOOK_FILE=docs/working/TASK-9999/plan.md`、no-task | **2** | c1-2 |
| TC-10c | 同上 | `PLANGATE_HOOK_FILE=docs/foo.md` | 0 | 正常系が退行しない（doc-light） |
| TC-10d | 同上 | Bash payload（対象パスなし） | 0 | NOOP が退行しない |
| TC-11a | patch 適用後 / `_audit` を `rm -rf` して同名の**通常ファイル**を置く | `PLANGATE_HOOK_FILE=CLAUDE.md` | **2** | c2-1（`mkdir` 側の保護） |
| TC-11b | 同上 | no-task `plan.md` | **2** | c2-2 |
| TC-12（変異） | **patch 未適用**（`f23d31d` そのまま）の複製で TC-10a / TC-10b / TC-11a | 同上 | **1**（= FAIL することの実証） | 「修正前の hook で FAIL する」を機械化。`PG_T79_EXPECT=gap` 相当の既知ギャップ opt-in 運用は先例に倣う |
| TC-13（変異） | patch 適用後の複製から `\|\| { ...; return 0; }` を **`sed` で 2 箇所除去** | TC-10a / TC-11a | **1** | 保護句が実際に効いていることの検出力。片方だけ除去する 2 変異（`mkdir` 側のみ / `printf` 側のみ）も加え、それぞれ TC-11a / TC-10a だけが 1 に戻ることを確認する |
| TC-14 | 各 TC の末尾 | — | — | `chmod 644` / 通常ディレクトリへ復元してから `mktemp -d` を削除（README 規約 9。444 のまま消すと `rm -rf` が権限で失敗する環境がある） |

実装上の注意: サンドボックスは **repo の外**（`mktemp -d`）に置くこと。repo 内サブディレクトリで `git apply` すると、patch のパスが cwd の外を指すため **何も適用せず rc=0 で成功したように見える**（本ワーカーが実測で踏んだ。`git init` した複製か repo 外で適用する）。

---

## 7. 契約文言の更新案 / Human 判断事項（本 patch では扱わない）

### 7.1 `PLANGATE_HOOK_STRICT=1` と `BASH_LANE_NOOP`（issue の Low 併記）

実測（`f23d31d`）: `PLANGATE_HOOK_STRICT=1` + Bash payload（対象パスなし・no-task）→ **rc=0**（`BASH_LANE_NOOP`）。hook 内コメント `:391` の「`PLANGATE_HOOK_STRICT=1` は従来どおり no-task を一律 block（後方互換）」と不一致。NOOP 分岐（`:315-323`）が STRICT 判定（`:407`）より前にあるため。

| 案 | 内容 | 影響 |
|---|---|---|
| **A（文言更新・推奨）** | `:391` と冒頭 `:13` の STRICT 説明を「**Edit/Write（対象パスあり）の no-task を一律 block。Bash レーンで対象パスが無い payload は #1104 が open の間 NOOP（STRICT でも exit 0）**」へ改める | 挙動不変。#1104 の残存を STRICT 契約にも明記するだけ |
| B（挙動変更） | NOOP 条件に `[ "${PLANGATE_HOOK_STRICT:-0}" != "1" ]` を足す | STRICT 利用者は全 Bash が exit 2 になる（1104 文書 §1 #1 の「全 Bash が止まる」状態に STRICT 下だけ戻る）。STRICT を「意図的に厳しくしている」利用者にはそれが期待どおりとも言えるが、Human 判断 |

本書は A の文言案を提示するに留める（`.claude/settings.example.json` の `_comment_` は STRICT に触れていないため対象外）。

### 7.2 `skip-decision-log.jsonl` の fail-closed 化（§3 (b)）

「記録できなければ SKIP しない」に倒す場合は、3 箇所を `printf ... >>"$_dlog" 2>/dev/null || { log_event "SKIP_BLOCKED" "skip-decision-log unwritable"; printf '...' >&2; exit 2; }` の形にする。導入するなら別 issue で、可用性（RO checkout で docs 作業が止まる）と `docs/working/_audit/` の tracked 運用（誰が 444 にできるか）を併せて判断する。

---

## 付録: 本書作成時の手順（再現用）

```sh
# 測定基点の展開（repo 内 .pgtmp/ でも可。ただし git apply は git init した複製か repo 外で行う）
git archive f23d31d | tar -x -C "$SB/base"
# before: 3 ケース → rc=1 / after: patch 適用複製 → rc=2 / 変異: 保護句除去 → rc=1
# 各ケースの前提は chmod 444 <log> / mv _audit _audit.bak && touch _audit / chmod 555 _audit
# 実行は env PLANGATE_HOOK_FILE=<path> sh scripts/hooks/check-plan-hash.sh </dev/null
```

サンドボックス（`.pgtmp/1278/`）は本書コミット後に削除済み。repo の `scripts/` / `tests/` / `.claude/` に変更なし（`git status` で確認）。
