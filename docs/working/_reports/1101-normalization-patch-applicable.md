# #1101 HO パス正規化 patch — `git apply` 可能形（**Human 適用**）

> 対象: `scripts/hooks/check-plan-hash.sh`（**Hardening Override 対象パス**）
> 設計正本: [`1101-normalization-patch.md`](./1101-normalization-patch.md) **rev9**。**本書は設計を作り直していない**。
> 本書の役割: rev9 §3 の (A)(B)(C)(D) 4 hunk を、**ファイルヘッダ付き unified diff 1 本**に機械変換したもの。
> 責務: **設計・差分・検証設計は AI-owned / 適用は Human-owned**。**AI は本差分を適用しない**。
> 測定基点: `origin/main` = `8cb9e82` / 2026-08-25 / macOS 25.6.0 / `/bin/sh` = bash 3.2 / BSD sed・BSD tr

## 1. なぜ元設計書は機械適用できなかったか

元設計書 `1101-normalization-patch.md` の §3 は `diff` フェンスの中に `+` / `-` 行を持つが、
**unified diff のファイルヘッダ（`--- a/` / `+++ b/`）とハンクヘッダ（`@@ -l,s +l,s @@`）の行数が無い**。
`@@` は `@@` 単体（行番号なし）で書かれており、`git apply` はこれをパースできない。

実測（ref 明示 / 陽性コントロールつき）:

| 測定 | コマンド | 結果 |
|---|---|---|
| 元設計書のファイルヘッダ | `git grep -c -- '--- a/' origin/main -- docs/working/_reports/1101-normalization-patch.md` | **一致なし（rc=1）** |
| **陽性コントロール** | `git grep -c -- '--- a/' origin/main -- docs/working/_reports/863-4-ho-patch.md` | **一致あり**（同じコマンドが検出できることの確認） |

したがって元設計書は**人間が手で読んで適用する**ことしかできず、`docs/working/_reports/backlog-triage-2026-08-24.md` Phase -1 が
「適用可能性の契約がない 17 本」に数えたとおりの状態だった。本書はその契約だけを与える。

## 2. 現 main と元設計書の前提差

元設計書の測定基点は `6def020`、現 `origin/main` は `8cb9e82`（`git rev-list --count 6def020..origin/main` = **43**）。
差分の有無を実測した:

| ファイル | `git diff --stat 6def020 origin/main -- <path>` | 判定 |
|---|---|---|
| `scripts/hooks/check-plan-hash.sh` | **差分なし** | 前提は現 main でも成立 |
| `tests/extras/ta-65-eh3-ho-task-context.sh` | **差分なし** | §6 step 2/3 の前提も成立 |
| `scripts/apply-eh3-ho-always.sh` | **差分なし** | §6 step 7 の前提も成立 |
| `.claude/rules/mode-classification.md` | **差分なし** | HO 9 カテゴリ正本も不変 |

**現 main で成立しなかった前提は 1 件も見つからなかった。** 行番号は元設計書を信用せず現 main で再測定し、
本書の diff のハンクヘッダは `diff -u` が生成した実測値である（アンカーは以下、`git grep -n … origin/main` で再測定した値）:

| アンカー | 現 main の行 |
|---|---|
| `log_event() {` | 26 |
| `# (ii) Hardening Override 物理先頭判定` | 93 |
| `  AGENTS.md\|CLAUDE.md) _override=1 ;;` | 104 |
| `  _tf_lc=$(printf '%s' "$target_file" \| sed …` | 123 |
| `        _esc_c3=$(printf '%s' …` | 177 |
| `      _esc_dl=$(printf '%s' …` | 198 |

## 3. 取り込んだ設計（rev9 の確定事項のみ）

元設計書は「版の履歴（撤回した主張を明示する）」を持つ。**撤回された案は実装していない**:

| 論点 | rev9 の確定 | 本 diff での実装 |
|---|---|---|
| §2.1 `..` / `//` | **解決せず fail-closed（採用）**。`realpath` / `readlink -f` / `python3 normpath` / セグメント走査は却下 | `(i-c)` の `case` 3 アーム。FS に触れない |
| §2.2 大小文字 | **非対称**。block 側（HO）だけ小文字化、通す側（`_norm_target`）は不変 | `_ho_key` を新設し `_norm_target` は無改変。`case` は小文字リテラルと元表記の両方 |
| §2.3 適用順 | (1) trim+小文字化 → (2) traversal → (3) `./` / 末尾 `/` 除去 → (4) root 除去 | `(i-b)` → `(i-c)` → `(i-d)` の順で配置。**traversal は `_ho_key` と生 `target_file` の union**（rev7 MJ-A） |
| §2.4 性能ガード | 新規のパラメータ展開はすべて `case` で前置ガード。ガードは `if` ブロックで書く。**コメントにも展開記法を書かない** | 追加した除去 6 箇所すべてがガード下。構造検査 hits=0（下記 §5） |
| §2.9 infra 故障 | **fail-closed ではなく degrade-to-base**（案 C）。案 A（fail-open）/ 案 B（rev5 の fail-closed）は却下 | `_ho_key` / `_ho_root` / `_tf_lc` / `_esc_*` の縮退先はすべて `_norm_target` 相当 |
| §2.10–2.12 | `log_event` は失敗しない・1 レコード 1 行・切り詰めを `[truncated]` で明示・traversal marker は `EH3_PATH_REJECTED` | `_pg_oneline` を新設し `log_event` と `_esc_*` の縮退先が同じ規則を通る |

**撤回された rev1〜rev8 の書き方（無ガードの接尾除去 / `[ … ] ||` 前置 / `_ho_root` の既定を生 `REPO_ROOT` にする / traversal の `_ho_key` 単独判定 / 縮退先を生値のまま JSONL に流す）は 1 つも含めていない。**

## 4. 差分（`git apply` 可能）

生成手順（**手書きしていない**）: 現 main の `scripts/hooks/check-plan-hash.sh` を scratchpad へ複製し、
**複製側だけ**を行範囲スプライスで編集（各範囲の先頭・末尾行を編集前にアサート）、
`diff -u --label a/scripts/hooks/check-plan-hash.sh --label b/scripts/hooks/check-plan-hash.sh` で生成した。

````diff
--- a/scripts/hooks/check-plan-hash.sh
+++ b/scripts/hooks/check-plan-hash.sh
@@ -23,12 +23,50 @@
 WORKING_DIR="$REPO_ROOT/docs/working"
 AUDIT_LOG="$WORKING_DIR/_audit/hook-events.log"
 
+_PG_NL='
+'
+_PG_CR=$(printf '\r') || _PG_CR=''
+[ -n "$_PG_CR" ] || _PG_CR=$(printf '\015')
+_PG_TAB=$(printf '\t') || _PG_TAB=''
+[ -n "$_PG_TAB" ] || _PG_TAB=$(printf '\011')
+
+# _pg_oneline: 1 レコード 1 行・5 フィールドを保証する共通サニタイズ（#1101）。
+#   In : $1  Out: _PG_ONE
+#   改行 / CR / タブより後ろを捨てる。切り詰めたら [truncated] を付ける。
+#   接尾除去（パラメータ展開の %% 系）は必ず case で前置ガードする
+#   （無ガードは bash 3.2 で入力長に対して二次 / #1101 F1）。
+#   _PG_CR / _PG_TAB が空でも壊れないよう if で包む（#1101 MN-2）。
+#   `[ … ] ||` 前置ではなく if ブロックにするのは §6 step 4 の構造検査を
+#   誤検出させないため（#1101 MAJOR-1 / 挙動は同値）。
+_pg_oneline() {
+  _PG_ONE=$1
+  _pg_trunc=0
+  case "$_PG_ONE" in *"$_PG_NL"*) _PG_ONE=${_PG_ONE%%"$_PG_NL"*}; _pg_trunc=1 ;; esac
+  if [ -n "$_PG_CR" ]; then
+    case "$_PG_ONE" in *"$_PG_CR"*) _PG_ONE=${_PG_ONE%%"$_PG_CR"*}; _pg_trunc=1 ;; esac
+  fi
+  if [ -n "$_PG_TAB" ]; then
+    case "$_PG_ONE" in *"$_PG_TAB"*) _PG_ONE=${_PG_ONE%%"$_PG_TAB"*}; _pg_trunc=1 ;; esac
+  fi
+  if [ "$_pg_trunc" != "0" ]; then
+    _PG_ONE="$_PG_ONE [truncated]"
+  fi
+  return 0
+}
+
 log_event() {
   level=$1
-  msg=$2
-  mkdir -p "$(dirname "$AUDIT_LOG")"
-  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
-  printf '%s\t%s\tcheck-plan-hash\t%s\t%s\n' "$ts" "$level" "${task_id:-${PLANGATE_HOOK_TASK:--}}" "$msg" >>"$AUDIT_LOG"
+  _pg_oneline "$2"
+  msg=$_PG_ONE
+  # 監査ログが書けない環境でも block を成立させる（#1101 MJ-2）。
+  # set -eu 下では mkdir / date / >> の失敗がそのままシェルを rc=1 で落とし、
+  # PreToolUse は exit 2 のみ block なので fail-open に化ける。
+  # 書けなかったこと自体は in-band で警告する（黙って消さない / MN-1）。
+  mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null || true
+  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ') || ts='-'
+  printf '%s\t%s\tcheck-plan-hash\t%s\t%s\n' "$ts" "$level" "${task_id:-${PLANGATE_HOOK_TASK:--}}" "$msg" >>"$AUDIT_LOG" 2>/dev/null \
+    || printf '[Hook EH-3] WARN: audit log write failed (%s)\n' "$level" >&2
+  return 0
 }
 
 sha256_of() {
@@ -90,9 +128,77 @@
   "$REPO_ROOT"/*) _norm_target="${_norm_target#$REPO_ROOT/}" ;;
 esac
 
+# (i-b) HO 判定専用キー _ho_key の導出（#1101 / TASK-1101）
+#   前後空白の除去 + 小文字化を外部コマンド 1 パイプラインで行う（1 文字ループは
+#   O(n^2) で EH-3 に timeout が無く暴走がハングになる / 8b604fe の実測）。
+#   LC_ALL=C を内側固定する: BSD tr はロケールの照合順で範囲を解釈するため
+#   en_US.ISO8859-1 等では CLAUDE.md すら小文字化に失敗する（実測）。
+#   || _ho_key='' は必須: コマンド置換のみの代入は置換の終了ステータスが代入文の
+#   ステータスになるため、最終段 tr の失敗で set -eu が即死する（rc=127 は
+#   PreToolUse では block にならず eh-bridge は未知 rc を allow へ変換する）。
+#   **導出できなかったときは block ではなく _norm_target（= base 相当のキー）へ
+#   縮退する**: sed/tr の故障は攻撃者が誘発できず、block にすると全ファイルの
+#   編集が停止する一方、縮退なら検出力は常に base 以上（#1101 MJ-3 / 実測）。
+#   _norm_target 自体は書き換えない（doc-light / maintenance / c3 は通す側）。
+_ho_key=$(printf '%s' "${target_file:-}" | LC_ALL=C sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | LC_ALL=C tr 'A-Z' 'a-z') || _ho_key=''
+if [ -z "$_ho_key" ] && [ -n "${target_file:-}" ]; then
+  _ho_key=$_norm_target
+fi
+
+# (i-c) traversal fail-closed（#1101 / #1135 の _trav と同形）
+#   `..` / `//` / `/./` / 末尾 `/.` / `.` 単体 を含むパスは字句解決せず一律 block。
+#   これは policy による拒否なので縮退させない（攻撃者が誘発できる入力）。
+#   **先頭 `./` 除去より前**に判定する：先に `./` を取ると `.//CLAUDE.md` が
+#   `/CLAUDE.md`（絶対パス形）になり `//` 検知をすり抜ける（実測で検出）。
+#   marker は HARDENING_OVERRIDE と分ける（非 HO でも発火するため / MN-1）。
+#   **_ho_key と生 target_file の union で判定する**: _ho_key は (i-b) で
+#   _norm_target へ縮退しうるが、_norm_target は base 側で先頭 ./ を除去済みで
+#   `.//CLAUDE.md` -> `/CLAUDE.md` となり `//` の証拠が消える（#1101 MJ-A / 実測）。
+_ho_trav=0
+for _ho_cand in "$_ho_key" "${target_file:-}"; do
+case "$_ho_cand" in
+  ..|../*|*/..|*/../*) _ho_trav=1 ;;
+  *//*)                _ho_trav=1 ;;
+  .|*/.|*/./*)         _ho_trav=1 ;;
+esac
+done
+if [ "$_ho_trav" = "1" ]; then
+  reason="EH3_PATH_REJECTED: ${target_file:-} は正規化できないパス表記 (fail-closed: path traversal)"
+  log_event "EH3_PATH_REJECTED" "$reason"
+  printf '[Hook EH-3] %s\n' "$reason" >&2
+  exit 2
+fi
+
+# (i-d) 先頭 `./` 除去と末尾 `/` 除去
+#   **除去は必ず case で前置ガードする**: bash 3.2 / ksh の接尾・接頭除去は一致
+#   しないときの走査が入力長に対して二次で、100000 文字 x5 で 12 秒かかる（実測）。
+#   コメント中にも展開記法を書かないこと（§6 step 4 の検出器はコメントを除外しない）。
+case "$_ho_key" in
+  ./*) _ho_key="${_ho_key#./}" ;;
+esac
+case "$_ho_key" in
+  */) _ho_key="${_ho_key%/}" ;;
+esac
+#   root 側も同じ写像を通してから比較する（root 除去を大小文字非依存にする）。
+#   **失敗時は生の REPO_ROOT を使わない**: _ho_key は小文字化済みで prefix が
+#   一致せず root 除去が失敗し、絶対パスの HO 9 カテゴリがまるごと素通りする
+#   （#1101 NEW-4 / 実測）。_norm_target は base と同じ root 除去済みなので
+#   そちらへ縮退する。
+_ho_root=$(printf '%s' "$REPO_ROOT" | LC_ALL=C tr 'A-Z' 'a-z') || _ho_root=''
+if [ -z "$_ho_root" ]; then
+  _ho_key=$_norm_target
+else
+  case "$_ho_key" in
+    "$_ho_root"/*) _ho_key="${_ho_key#"$_ho_root"/}" ;;
+  esac
+fi
+
 # (ii) Hardening Override 物理先頭判定（R-003/R-015、maintenance より上）
+# 判定対象は _ho_key。通常時は小文字化済み、縮退時は _norm_target（元表記）なので
+# **case は小文字リテラルと元表記の両方を持つ**（9 カテゴリの集合は不変）。
+# 正本は .claude/rules/mode-classification.md。
 _override=0
-case "$_norm_target" in
+case "$_ho_key" in
   .claude/rules/*.md) _override=1 ;;
   .claude/settings.json|.claude/settings.local.json|.claude/settings.example.json) _override=1 ;;
   .claude/commands/*.md|.claude/commands/*/*.md) _override=1 ;;
@@ -101,10 +207,12 @@
   bin/plangate) _override=1 ;;
   schemas/*.schema.json) _override=1 ;;
   .github/workflows/*.yml|.github/workflows/*.yaml) _override=1 ;;
-  AGENTS.md|CLAUDE.md) _override=1 ;;
+  AGENTS.md|CLAUDE.md|agents.md|claude.md) _override=1 ;;
 esac
 if [ "$_override" = "1" ]; then
-  reason="HARDENING_OVERRIDE: ${_norm_target} は maintenance 窓内でも常時 block (R-003/R-015)"
+  # 監査ログ / reason には**生の要求パス**を残す（正規化後の値ではない）。
+  # 改行の切り詰めは log_event 側で行う（MJ-1）。
+  reason="HARDENING_OVERRIDE: ${target_file:-} は maintenance 窓内でも常時 block (R-003/R-015)"
   log_event "HARDENING_OVERRIDE" "$reason"
   printf '[Hook EH-3] %s\n' "$reason" >&2
   exit 2
@@ -120,7 +228,16 @@
   # 正規化（V-3/Gemini 指摘）: 末尾空白除去 + 小文字化で plan.md 判定回避を防ぐ
   #   - macOS は既定で大文字小文字非区別 → PLAN.md で OS 上は plan.md 改変可能
   #   - "plan.md "（末尾空白）等の表記揺れも plan.md として扱う
-  _tf_lc=$(printf '%s' "$target_file" | sed 's/[[:space:]]*$//' | tr 'A-Z' 'a-z')
+  # LC_ALL=C: 非 UTF-8 ロケールでは tr が ASCII を壊し、plan.md guard が丸ごと
+  #   無効になる（実測: LC_ALL=en_US.ISO8859-1 で base は plan.md すら
+  #   DOC_LIGHT_SKIP rc=0）。
+  # || + 縮退: HO 判定が tr を 2 回消費するため本行は 3 回目の呼び出しになり、
+  #   部分故障で set -e が即死して plan.md guard が消える（#1101 NEW-5 / 実測）。
+  #   縮退先は _norm_target（base 相当）。
+  _tf_lc=$(printf '%s' "$target_file" | LC_ALL=C sed 's/[[:space:]]*$//' | LC_ALL=C tr 'A-Z' 'a-z') || _tf_lc=''
+  if [ -z "$_tf_lc" ] && [ -n "$target_file" ]; then
+    _tf_lc=$_norm_target
+  fi
   case "$_tf_lc" in
     */plan.md|plan.md)
       reason="plan.md edited without TASK context (EH-3 bypass guard): $target_file"
@@ -174,7 +291,15 @@
         _dlog_c3="$WORKING_DIR/_audit/skip-decision-log.jsonl"
         mkdir -p "$(dirname "$_dlog_c3")"
         _ts_c3=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
-        _esc_c3=$(printf '%s' "${_norm_target:-unknown}" | tr -d $'\n\r\t')
+        # HO 判定が tr を 2 回消費するため本行は下流にずれる。|| + 空チェックが無いと
+        # 部分故障で set -e が即死し、記録どころか SKIP 判定ごと消える（#1101 MJ-B）。
+        # 縮退先も _pg_oneline を通す: 生値のままだと制御文字が JSONL を壊し、
+        # scripts/check-skip-acknowledged.sh（CI required）が全 PR を落とす（#1101 MINOR-1）。
+        _esc_c3=$(printf '%s' "${_norm_target:-unknown}" | LC_ALL=C tr -d '\n\r\t') || _esc_c3=''
+        if [ -z "$_esc_c3" ]; then
+          _pg_oneline "${_norm_target:-unknown}"
+          _esc_c3=$_PG_ONE
+        fi
         printf '{"ts":"%s","event":"EH-3_C3_CONVERSATION_SKIP","target":"%s","acknowledged_by":null,"acknowledged_at":null}\n' "$_ts_c3" "$_esc_c3" >>"$_dlog_c3"
         reason="C3_CONVERSATION_SKIP: c3.json target (${_norm_target:-unknown}) -- conversation mode, auto-allowed"
         log_event "C3_CONVERSATION_SKIP" "$reason"
@@ -195,7 +320,11 @@
       _dlog_dl="$WORKING_DIR/_audit/skip-decision-log.jsonl"
       mkdir -p "$(dirname "$_dlog_dl")"
       _ts_dl=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
-      _esc_dl=$(printf '%s' "${_norm_target:-unknown}" | tr -d '\n\r\t')
+      _esc_dl=$(printf '%s' "${_norm_target:-unknown}" | LC_ALL=C tr -d '\n\r\t') || _esc_dl=''
+      if [ -z "$_esc_dl" ]; then
+        _pg_oneline "${_norm_target:-unknown}"
+        _esc_dl=$_PG_ONE
+      fi
       printf '{"ts":"%s","event":"EH-3_DOC_LIGHT_SKIP","target":"%s","acknowledged_by":null,"acknowledged_at":null}\n' "$_ts_dl" "$_esc_dl" >>"$_dlog_dl"
       reason="DOC_LIGHT_SKIP: non-HO .md target (${_norm_target:-unknown}) -- auto-skipped"
       log_event "DOC_LIGHT_SKIP" "$reason"
````

## 5. 抽出手順（round-trip）

本書から patch を機械抽出するときは、**上の diff フェンス（4 バッククォート）の中身をそのまま取り出す**:

```sh
awk '/^````diff$/{f=1;next} /^````$/{f=0} f' \
  docs/working/_reports/1101-normalization-patch-applicable.md > /tmp/1101.patch
git apply --check /tmp/1101.patch   # rc=0 であること
```

**抽出結果は生成原本と byte 一致することを実測済み**（§6 round-trip）。

## 6. 検証（すべて実測 / rc を記録）

### 6.1 patch そのものの検査

| # | 検査 | コマンド | 期待 | **実測 rc** |
|---|---|---|---|---|
| V-1 | 陽性: 適用可能 | `git apply --check 1101.patch` | 0 | **0** |
| V-2 | 陰性: 未適用の確認 | `git apply --check --reverse 1101.patch` | 0 以外 | **1**（`patch does not apply`） |
| V-3 | 変異注入: ハンクヘッダの旧行数を 1 ずらす（`@@ -23,12` → `@@ -23,13`） | `git apply --check mutant.patch` | 0 以外 | **128**（`corrupt patch at line 58`） |
| V-4 | round-trip: 本書から `awk` 抽出 → 再検査 | `awk … > rt.patch && cmp rt.patch 1101.patch && git apply --check rt.patch` | 0 / byte 一致 | **0**（`cmp` 差分なし） |

### 6.2 §2.4 構造検査（未ガードのパラメータ展開の検出）

適用後ファイル（= 生成した複製）に対して元設計書 §6 step 4 の grep をそのまま実行:

| 対象 | hits |
|---|---:|
| base（現 main の `check-plan-hash.sh`） | **0** |
| **本 patch 適用後** | **0** |
| **陽性コントロール**: 適用後から `case` ガードを 1 つ外した変異 | **1**（検出器が生きていることの確認） |

### 6.3 挙動検証（**本 patch の本体**）

現 main の複製（`base`）と patch 適用後の複製（`pat`）を、**大文字セグメントを含む sandbox root**
（`…/UPPER_Root/{base,pat}`）に置き、同一入力で実行した。

```sh
env -u PLANGATE_SKIP_REASON -u PLANGATE_HOOK_STRICT -u PLANGATE_BYPASS_HOOK \
    LC_ALL=C LANG=C PLANGATE_HOOK_TASK=TASK-9999 PLANGATE_HOOK_FILE="<入力>" \
    sh "<複製>/scripts/hooks/check-plan-hash.sh" </dev/null
```

| 入力 | **patch 前（base）** | **patch 後（pat）** | 期待 | 判定 |
|---|---|---|---|---|
| `bin/plangate` | **rc=2** `HARDENING_OVERRIDE` | **rc=2** `HARDENING_OVERRIDE` | rc=2 / 退行なし | ✅ |
| `bin/../bin/plangate` | **rc=0** `SKIP` | **rc=2** `EH3_PATH_REJECTED` | rc=2 | ✅ |
| `docs/../CLAUDE.md` | **rc=0** `SKIP` | **rc=2** `EH3_PATH_REJECTED` | rc=2 | ✅ |
| `CLAUDE.MD` | **rc=0** `SKIP` | **rc=2** `HARDENING_OVERRIDE` | rc=2 | ✅ |
| `scripts/hooks/../hooks/check-plan-hash.sh` | **rc=2** `HARDENING_OVERRIDE` | **rc=2** `EH3_PATH_REJECTED` | rc=2 / 退行なし | ✅ |
| **非 HO**: `docs/working/_reports/x.md` | **rc=0** `SKIP` | **rc=0** `SKIP` | rc=0 / 誤 block しない | ✅ |

- **偽陽性（非 HO を誤って block）は 0 件**。
- `scripts/hooks/../hooks/check-plan-hash.sh` は **rc は 2 で不変、marker だけ `HARDENING_OVERRIDE` → `EH3_PATH_REJECTED` に変わる**。
  base では `scripts/hooks/*.sh` の `*` が `/` を跨ぐ偶然で HO に当たっていた（元設計書 §1.4）。patch 後は traversal 判定が先に効くため決定論的に止まる。**block する事実は同じ**。
- `TASK-9999` は plan.md を持たないため、非 block 経路の marker は `SKIP`（`plan.md not found`）になる。**rc で判定せず marker も併記**するのは元設計書 §1.1 の測定規約に従ったもの。

## 7. 本書で扱わないもの / 未確定

| # | 内容 | 扱い |
|---|---|---|
| U-1 | **`ta-65` の TC-07 反転と TC 入力 21 件の追加**（元設計書 §6 step 2/3） | 本書の diff に**含めない**。`tests/` は HO 対象外だが、TC の追加は patch 適用と同時に行うべきで、**適用者が決める順序に依存する**ため未確定として残す |
| U-2 | **`scripts/apply-eh3-ho-always.sh` の 9 カテゴリ第 2 コピー**（同 step 7） | 同期するか retire するかは元設計書が「Human 判断」としている。本書では判断しない |
| U-3 | **`.claude/rules/mode-classification.md` への 1 行追記**（同 step 8） | HO 対象パス。AI は編集しない |
| U-4 | **`docs/ai/hook-enforcement.md` の「既知の残存」更新**（同 step 9） | 適用後の作業。本書の scope 外 |
| U-5 | **Linux / GNU coreutils での実測** | 元設計書 R-8 のとおり未実施。本書の挙動検証も macOS 1 OS。**CI での初回実行が実質的な OS 検証** |
| U-6 | **故障注入（`notr` / `nosed` / `notr2` / `notr3` / `auditro` / `inject` / `tabinj`）下の挙動** | 元設計書 §5.3 が rev7/rev8 で実測済み。本書は**同一の diff を再現しただけ**なので再実測していない。**本書の挙動検証は Step 5 で指定された 6 入力 × healthy に限る** |

**本書は `scripts/hooks/check-plan-hash.sh` を編集していない。** 変更したのは
`docs/working/_reports/1101-normalization-patch-applicable.md` の 1 ファイルのみ。
sandbox の複製は worktree 外の scratchpad に置いた。

## 8. 適用手順

**元設計書 [`1101-normalization-patch.md`](./1101-normalization-patch.md) §6 をそのまま使う。**
step 1（4 hunk を 1 回で適用）は本書の diff 1 本で満たせる:

```sh
awk '/^````diff$/{f=1;next} /^````$/{f=0} f' \
  docs/working/_reports/1101-normalization-patch-applicable.md > /tmp/1101.patch
git apply --check /tmp/1101.patch && git apply /tmp/1101.patch
```

step 2 以降（`ta-65` の TC 反転・TC 入力追加・構造検査・監査記録の再測定・`sh tests/run-tests.sh` の
macOS + `ubuntu-latest` 両方での rc=0・第 2 コピーの処遇・正本への追記）は**元設計書 §6 が正本**。

## 9. 関連

- [`1101-normalization-patch.md`](./1101-normalization-patch.md)（設計正本 / rev9）
- [`backlog-triage-2026-08-24.md`](./backlog-triage-2026-08-24.md) Phase -1
- #1101 / #1089 / #1104 / #1135 / #1144
