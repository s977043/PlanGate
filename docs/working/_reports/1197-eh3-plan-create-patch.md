# #1197 案 B — EH-3 no-task 分岐で未承認 TASK の plan.md 初回作成を許可する（機械適用可能な patch）

> 対象: `scripts/hooks/check-plan-hash.sh`（Hardening Override。**Human 適用**）
> base: `origin/main` = `9445df17`
> 適用スクリプト: [`scripts/apply-eh3-plan-create-1197.sh`](../../../scripts/apply-eh3-plan-create-1197.sh)
> 回帰網: [`tests/extras/ta-119-eh3-plan-create.sh`](../../../tests/extras/ta-119-eh3-plan-create.sh)
> 計画: `docs/working/TASK-1197/plan.md`（C-3 CONDITIONAL）

## 適用状態: **未適用**

`tests/fixtures/eh3-plan-create-pending-1197.flag` が存在する間、ta-119 は gap（未適用）を期待値にする。
Human が適用したら同じ commit で flag を削除する（flag が残っているのに適用済みだと ta-119 TC-00b が FAIL する）。

## 0. 結論

- no-task セッションで、**一度も承認されていない TASK の plan.md を `Write` で初回作成する**ときだけ rc=0（`PLAN_CREATE_ALLOW`）にする。
- 既存 plan.md の改変、Edit / MultiEdit、承認トークンや履歴がある TASK は**従来どおり rc=2**。
- 判定できないとき・エラーが起きたときは、すべて従来の block へ落ちる（fail-closed）。

## 1. 許可条件（すべて満たすときだけ rc=0）

| # | 条件 | 実装 |
|---|---|---|
| 1 | `PLANGATE_HOOK_STRICT != 1`、かつ maintenance.json が無い | shell |
| 2 | 対象は stdin payload を jq で読んだものに限る。`tool_name` は文字列の `"Write"` であること | shell（`_tf_src` / jq） |
| 2b | python で payload を再解析し、file_path が文字列であること。改行・CR・NUL を含まず、shell 側の値と一致すること | python |
| 3 | 絶対パスであり、`..` を含まない。`git worktree list` の worktree root より下に symlink が無い。root からの相対パスが `docs/working/TASK-<id>/plan.md` に厳密一致する | python |
| 5 | 対象が `lexists` で不在 | python |
| 6 | 全 worktree に `docs/working/TASK-<id>/approvals/` が無い。prunable な worktree は件数を記録して skip する。注記の無いまま到達できない worktree（locked で移動したもの等）は block | python |
| 7 | shallow でない。`rev-list -1 --all --reflog --full-history -- ':(top,icase)…plan.md' ':(top,icase)…approvals'` が空（git 呼び出しごとに timeout 10 秒、`GIT_*` env は除去） | python |
| 8 | hook-events.log と skip-decision-log.jsonl の**両方**に `PLAN_CREATE_ALLOW` を記録できること。どちらかが失敗したら rc=2 | shell |

計画にあった条件 4（common dir）は置いていない。worktree root を `git worktree list` との照合で特定する時点で、別 repo のパスは拒否されるため。

## 2. 残存脅威モデル（完全性を主張しない）

守るもの: 承認トークンが見える TASK、履歴のある plan.md、既存 plan.md への Edit / Write。

守らないもの:

- Bash 経路（#1104 open）、TOCTOU（hook の判定から Write までの間に別プロセスが書く）
- untracked な approvals の発見は**ベストエフォート**。prune 後の worktree、`.git/worktrees` を消した worktree、別 clone にあるトークンは見えない
- 兄弟 worktree にある untracked の plan.md（approvals と履歴しか見ない）
- reflog 失効後・gc 後の履歴、未 fetch の remote、トークンを repo 外へ退避して戻す行為
- env / 引数で対象を渡す経路（Codex の eh-bridge 等）はこの許可分岐に入らない（従来どおり block。機能差）
- file_path に孤立サロゲートを含む payload。jq 1.8.1 は parse error で拒否し、grep の fallback により **origin/main の hook でも OUTSIDE_REPO_SKIP（rc=0）**になる。本 patch 以前からの既存挙動。書き込み主体が実際にどこへ書くかは未検証（follow-up issue 候補）

保証の主体: exec 段階の plan_hash 拒否。前提は、exec を行う checkout に、Human が plan_hash 付きで発行した c3.json があること。plan_hash 層が検出するのは承認後の改変で、承認の不在は検出しない。EH-3 の task レーンは c3.json が無いと STRICT でも plan.md の編集を通す（ta-119 TC-P5 で固定）。bin/plangate 側の既存 fail-open（legacy c3.json の plan_hash 欠落・接頭辞不正・plan.md 不在の受理、c3.json が task_id に束縛されていないこと）は範囲外。

## 3. 検証済みであること / 未検証であること

- 検証済み（mktemp sandbox。実 repo には書いていない）: ta-119 の全 TC。変異注入（`PG_T119_MUTATION=1` の opt-in レーン）は killed=25 / survived=0 / 等価変異 5（各変異の分類理由は ta-119 の fixture 参照）
- 未検証: 実 Claude Code の Write payload（H-02 の適用後、T-02 で実 Write を 1 回行い `PLAN_CREATE_ALLOW` を確認する）、Codex / Cursor 経路

## 4. patch（`git apply` 可能）

patch 本体は下の `<!-- PG-PATCH-BEGIN -->` / `<!-- PG-PATCH-END -->` に挟まれた fenced block。
適用は `sh scripts/apply-eh3-plan-create-1197.sh` で行う（直接 `git apply` しない）。

<!-- PG-PATCH-BEGIN -->
```diff
diff --git a/scripts/hooks/check-plan-hash.sh b/scripts/hooks/check-plan-hash.sh
index dcdc88d0..87cbe74b 100755
--- a/scripts/hooks/check-plan-hash.sh
+++ b/scripts/hooks/check-plan-hash.sh
@@ -277,6 +277,7 @@ fi
 # codebase 慣行（check-forbidden-files.sh）に合わせ env → 位置引数の順。
 task_id=${PLANGATE_HOOK_TASK:-${1:-}}
 target_file=${PLANGATE_HOOK_FILE:-${2:-}}
+_tf_src=""
 
 # PreToolUse hook では Claude Code が stdin に JSON（tool_input.file_path）を
 # 渡す。env / 引数で未指定なら stdin JSON から対象パスを補完する（最終手段）。
@@ -292,6 +293,9 @@ if [ -z "$target_file" ] && [ ! -t 0 ]; then
         | jq -r '.tool_input.file_path // .file_path // empty' 2>/dev/null \
         | head -1)
     fi
+    if [ -n "$target_file" ]; then
+      _tf_src=stdin_jq
+    fi
     if [ -z "$target_file" ]; then
       target_file=$(printf '%s' "$_stdin" \
         | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
@@ -546,6 +550,141 @@ fi
 #     check-forbidden-files.sh と同じ「no task→skip」慣行。Case 2）
 #   - PLANGATE_HOOK_STRICT=1 は従来どおり no-task を一律 block（後方互換）
 if [ -z "$task_id" ]; then
+  # ===== #1197: 未承認 TASK の plan.md 初回作成の許可（案 B）=====
+  # 条件をすべて満たすときだけ rc=0。判定不能・エラーは下の block へ落ちる。
+  # 残存脅威（Bash 経路 #1104 / TOCTOU / トークンの repo 外退避 / reflog 失効後）と
+  # 次の 2 点も残存脅威・機能差として扱う:
+  #   - 兄弟 worktree にある untracked の plan.md は検査しない（approvals と履歴のみ見る）。
+  #     承認トークンが無い限り承認済み plan の改変にはならない
+  #   - untracked な approvals の発見はベストエフォートである。prunable な worktree は
+  #     件数を記録して skip する。prune 後の worktree、.git/worktrees を消した worktree、
+  #     別 clone にあるトークンは見えない
+  #   - 対象を env / 引数で渡す経路（Codex の eh-bridge 等）は本分岐に入らず従来どおり block
+  # 保証の主体: exec 段階の plan_hash 拒否。前提は、exec を行う checkout に
+  #   Human が plan_hash 付きで発行した c3.json が存在すること。plan_hash 層が検出するのは
+  #   承認後の改変であり、承認の不在は検出しない。C-3 / C-4 がこれを補う。
+  # EH-3 の task レーンは c3.json が無いと、STRICT でも plan.md の編集を通す。
+  #   したがって編集時点の防御は無く、残る防御は exec 層の 1 層だけである。
+  # 守らないもの（bin/plangate 側の既存欠陥。本 patch の範囲外、follow-up issue 候補）:
+  #   legacy c3.json の plan_hash 欠落・接頭辞不正・plan.md 不在を exec が受理する
+  #   fail-open、および c3.json が task_id に束縛されていないこと。
+  # 詳細は docs/ai/hook-enforcement.md の EH-3 節。本分岐は多層防御の 1 層である。
+  # 入口の字句判定（fork なし）。plan.md 以外は従来と同じ経路・fork 数のまま下へ進む。
+  _pc_lex=0
+  case "${target_file}" in
+    */plan.md) _pc_lex=1 ;;
+  esac
+  if [ "$_pc_lex" = "1" ] \
+    && [ "${_tf_src:-}" = "stdin_jq" ] \
+    && [ "${PLANGATE_HOOK_STRICT:-0}" != "1" ] \
+    && [ ! -e "$REPO_ROOT/docs/working/_maintenance/maintenance.json" ] \
+    && [ "$(printf '%s' "${_stdin:-}" | jq -r 'if (.tool_name|type)=="string" then .tool_name else "" end' 2>/dev/null || true)" = "Write" ] \
+    && command -v python3 >/dev/null 2>&1; then
+    # payload は pipe で渡す（env 渡しは約 1MB 超で E2BIG になり正当な Write が block される）
+    _pc_res=$(printf '%s' "$_stdin" | PG_ROOT="$REPO_ROOT" PG_TARGET="$target_file" python3 /dev/fd/3 3<<'PYPC' 2>/dev/null || true
+import json, os, re, subprocess, sys
+TIMEOUT = 10
+def out(s):
+    print(s); sys.exit(0)
+try:
+    root = os.environ["PG_ROOT"]
+    t = os.environ["PG_TARGET"]
+    raw = json.loads(sys.stdin.read()).get("tool_input", {}).get("file_path")
+    if not isinstance(raw, str) or any(c in raw for c in "\n\r\0") or raw != t:
+        out("BLOCK|control character or mismatch in file_path")
+    if not os.path.isabs(t):
+        out("BLOCK|relative file_path")
+    segs = t.split("/")
+    if any(s == ".." for s in segs):
+        out("BLOCK|dotdot")
+    req = os.path.normpath(t)
+    env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
+    def git(args, cwd):
+        return subprocess.run(["git"] + args, cwd=cwd, env=env, capture_output=True, timeout=TIMEOUT)
+    r = git(["worktree", "list", "--porcelain", "-z"], root)
+    if r.returncode != 0:
+        out("BLOCK|worktree list failed")
+    wts = []
+    skipped = 0
+    for rec in r.stdout.decode("utf-8", "surrogateescape").split("\0\0"):
+        f = [x for x in rec.split("\0") if x]
+        if not f:
+            continue
+        path = None; prunable = False
+        for x in f:
+            if x.startswith("worktree "):
+                path = x[len("worktree "):]
+            elif x == "prunable" or x.startswith("prunable "):
+                prunable = True
+        if path is None:
+            out("BLOCK|unparsable worktree record")
+        if prunable:
+            skipped += 1
+            continue
+        if not os.path.isdir(path):
+            out("BLOCK|unreachable worktree " + path)
+        wts.append(os.path.realpath(path))
+    # 要求パスの祖先のうち実体が worktree root のもの（root より上の symlink は許容）
+    parts = req.split("/")
+    matches = []
+    for i in range(1, len(parts)):
+        pre = "/".join(parts[:i]) or "/"
+        if os.path.isdir(pre) and os.path.realpath(pre) in wts:
+            matches.append(i)
+    if not matches:
+        out("BLOCK|not under a worktree of this repo")
+    outer, inner = matches[0], matches[-1]
+    for j in range(outer + 1, len(parts) + 1):
+        p = "/".join(parts[:j])
+        if os.path.lexists(p) and os.path.islink(p):
+            out("BLOCK|symlink below worktree root: " + p)
+    wroot = "/".join(parts[:inner]) or "/"
+    rel = "/".join(parts[inner:])
+    m = re.fullmatch(r"docs/working/(TASK-[A-Za-z0-9][A-Za-z0-9-]*)/plan\.md", rel)
+    if not m:
+        out("BLOCK|not docs/working/TASK-<id>/plan.md")
+    tid = m.group(1)
+    if os.path.lexists(req):
+        out("BLOCK|plan.md exists")
+    for w in wts:
+        if os.path.lexists(os.path.join(w, "docs", "working", tid, "approvals")):
+            out("BLOCK|approvals exist in " + w)
+    r = git(["rev-parse", "--is-shallow-repository"], wroot)
+    if r.returncode != 0 or r.stdout.strip() != b"false":
+        out("BLOCK|shallow or rev-parse failed")
+    r = git(["rev-list", "-1", "--all", "--reflog", "--full-history", "--",
+             ":(top,icase)docs/working/%s/plan.md" % tid,
+             ":(top,icase)docs/working/%s/approvals" % tid], wroot)
+    if r.returncode != 0:
+        out("BLOCK|rev-list failed")
+    if r.stdout.strip():
+        out("BLOCK|history exists")
+    out("ALLOW|%s|%d" % (tid, skipped))
+except subprocess.TimeoutExpired:
+    out("BLOCK|git timeout")
+except Exception as e:
+    out("BLOCK|error %s" % type(e).__name__)
+PYPC
+)
+    case "$_pc_res" in
+      ALLOW\|*)
+        _pc_rest=${_pc_res#ALLOW|}
+        _pc_tid=${_pc_rest%%|*}
+        _pc_skip=${_pc_rest#*|}
+        _pc_ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
+        _pc_esc=$(printf '%s' "$target_file" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n\r\t')
+        _pc_dlog="$WORKING_DIR/_audit/skip-decision-log.jsonl"
+        if ! mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null \
+          || ! printf '%s\tPLAN_CREATE_ALLOW\tcheck-plan-hash\t%s\tnew plan.md for unapproved task: %s (prunable_skipped=%s)\n' "$_pc_ts" "$_pc_tid" "$target_file" "$_pc_skip" 2>/dev/null >>"$AUDIT_LOG" \
+          || ! printf '{"ts":"%s","event":"PLAN_CREATE_ALLOW","target":"%s","prunable_skipped":%s,"acknowledged_by":null,"acknowledged_at":null}\n' "$_pc_ts" "$_pc_esc" "$_pc_skip" 2>/dev/null >>"$_pc_dlog"; then
+          printf '[Hook EH-3] BLOCK: PLAN_CREATE_ALLOW could not be recorded (fail-closed).\n' >&2
+          exit 2
+        fi
+        printf '[Hook EH-3 PLAN_CREATE_ALLOW] new plan.md for unapproved %s: %s\n' "$_pc_tid" "$target_file"
+        exit 0
+        ;;
+    esac
+  fi
   # 正規化（V-3/Gemini 指摘）: 末尾空白除去 + 小文字化で plan.md 判定回避を防ぐ
   #   - macOS は既定で大文字小文字非区別 → PLAN.md で OS 上は plan.md 改変可能
   #   - "plan.md "（末尾空白）等の表記揺れも plan.md として扱う
```
<!-- PG-PATCH-END -->
