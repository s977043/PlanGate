# #1144 root 解決 是正設計（patch 設計書）

> **本書は patch 設計書であり、`scripts/hooks/*.sh` は本 PR で編集していない**（Hardening Override 対象 / 適用は Human-owned）。差分は本書内に提示する。
>
> - 起点: `origin/main` = `387ea21d771ba9b7afb39acf8a3897fe05748cdc`
> - ブランチ: `docs/1144-root-resolution`
> - 対象 issue: #1144（enforcement 層が 3 導入経路すべてで配布されていない）
> - 変更ファイル: 本ファイル 1 件のみ

---

## 0. 要約（結論先行）

| 論点 | 結論 |
|---|---|
| 17 hook の root 依存 | **判定入力 9 / git コンテキスト 3 / ファイル実体 1（判定入力と重複あり）/ 監査ログのみ 2 / 兄弟スクリプト解決のみ 1** |
| 「root を取っているが実質使っていない」hook | **3 本**（`check-auth-preflight.sh` / `check-delegation-commit-boundary.sh` = 監査ログ専用、`cursor-adapter.sh` = 兄弟解決のみで project root 不要） |
| root 解決の失敗は現状 fail-open か | **YES。実測で確認済み（§2）。中核ゲート EH-3 の Hardening Override が root 誤解決だけで rc=0 素通りする** |
| ヘルパーの形 | **`scripts/hooks/_plangate-root.sh` を新設し、各 hook が `$0` 相対で `.` source する**（インライン 17 複製は棄却。根拠 §4） |
| 導入順 | **6 段階**（Stage 0 ヘルパー単体 → 中核 5 本 → git 系 → 残り判定系 → 監査/兄弟系 → 配布有効化） |
| 前提との食い違い | **2 件あり**（§7）。特に「`.codex/hooks.json` が既に正解に近い形」は**半分しか正しくない** |

---

## 1. 17 hook の root 依存 全数分類（実測）

分類方法: `git grep -n 'REPO_ROOT\|WORKING_DIR\|PROJECT_DIR\|show-toplevel' scripts/hooks/*.sh` の全ヒットを 1 件ずつ用途判定。

| # | hook | root の用途 | 誤解決時の影響 | 分類 |
|---|---|---|---|---|
| 1 | `check-plan-hash.sh` | plan.md / c3.json / `.plangate.yml` / `_maintenance/maintenance.json` の探索 **＋ HO 判定のための絶対パス正規化基準**（L90） | **HO ゲート全面素通り（§2 実測）** | 判定入力 + **正規化基準** |
| 2 | `check-c3-approval.sh` | `docs/working/$TASK/approvals/c3.json` 探索 + 監査 | c3.json 不在扱い → warning のみ、STRICT でも「未承認」と誤断 | 判定入力 |
| 3 | `check-plan-exists.sh` | `docs/working/$TASK/plan.md` 探索 + 監査 | plan.md 不在扱い → 偽陽性（誤 block）側 | 判定入力 |
| 4 | `check-forbidden-files.sh` | `docs/working` 配下の子 PBI YAML 探索 + 監査 | forbidden_files 定義に到達できず SKIP → **偽陰性** | 判定入力 |
| 5 | `check-fix-loop.sh` | `docs/working/$TASK/.fix-loop-count` の**読み書き** + 監査 | カウンタが別ディレクトリに作られ回数制限が効かない | 判定入力 + 状態書込 |
| 6 | `check-handoff-elements.sh` | `docs/working/$target/handoff.md` + 監査 | handoff 不在扱い | 判定入力 |
| 7 | `check-merge-approvals.sh` | `approvals/c3.json` / `c4-approval.json` / `c4.json` + 監査 | 承認記録に到達できない | 判定入力 |
| 8 | `check-test-cases.sh` | `docs/working/$TASK/test-cases.md` + 監査 | test-cases 不在扱い | 判定入力 |
| 9 | `check-v3-review.sh` | `review-external.md` / `evidence/v3-review/` + 監査 | V-3 証跡に到達できない | 判定入力 |
| 10 | `check-verification-evidence.sh` | `docs/working/$TASK/evidence/` + 監査 | 証跡に到達できない | 判定入力 |
| 11 | `check-ai-memory-pollution.sh` | `$REPO_ROOT/.plangate-pollution-patterns.yaml`（設定）+ `$REPO_ROOT/$file` の実体読み（size / binary 判定, L107-114） | 設定既定値へフォールバック + 対象ファイルを見つけられず検査スキップ | 設定 + ファイル実体 |
| 12 | `check-metrics-privacy.sh` | `git -C $REPO_ROOT diff --cached`（L62）+ `$REPO_ROOT/.git` 存在判定（L61）+ `$REPO_ROOT/$f` 実体（L92）+ 監査 | staged 集合が空 → **検査対象ゼロで PASS** | git コンテキスト + 実体 |
| 13 | `check-post-edit-diff.sh` | `git -C $REPO_ROOT rev-parse/ls-files/diff`（L58-99）+ 対象パス正規化（L88）+ 監査 | 非 git 判定で no-op | git コンテキスト |
| 14 | `check-stop-diff-status.sh` | `git -C $REPO_ROOT rev-parse/status/diff`（L58-63）+ 監査 | 非 git 判定で no-op（Stop hook は元々 non-blocking 固定） | git コンテキスト |
| 15 | `check-auth-preflight.sh` | **監査ログのパスのみ**（判定は `gh auth status` / `git config user.email` / `git remote` = **cwd 依存**） | 監査ログが別ディレクトリに出るだけ。**判定は不変** | **監査ログのみ** |
| 16 | `check-delegation-commit-boundary.sh` | **監査ログのパスのみ**（判定は `PLANGATE_DELEGATION_NOCOMMIT` env + stdin の command 文字列） | 監査ログが別ディレクトリに出るだけ。**判定は不変** | **監査ログのみ** |
| 17 | `cursor-adapter.sh` | `$REPO_ROOT/scripts/hooks/$HOOK_NAME` = **兄弟スクリプトの探索のみ** | plugin 配置（`<plugin>/hooks/`）では**必ず不在 → 全 hook が deny(rc=2) で誤 block** | **兄弟解決（project root 不要）** |

### 1-a. 「root を取っているが使っていない」hook（段階導入の後回し候補）

| hook | 理由 |
|---|---|
| `check-auth-preflight.sh` | root は `AUDIT_LOG` にしか流れない。判定 3 点（gh / user.email / origin）は cwd 依存で root と無関係 |
| `check-delegation-commit-boundary.sh` | 同上。判定は env + stdin のみ |
| `cursor-adapter.sh` | root を取っているが欲しいのは**兄弟ファイルの場所**。project root を経由するのが構造的に誤り（`$0` 相対に置換すべき） |

→ この 3 本は **Stage 4（最終段）** に回してよい。ただし `cursor-adapter.sh` は「plugin 配布時に必ず壊れる」ため、**配布有効化（Stage 5）より前に必ず直す**。

### 1-b. `scripts/` 直下の配線対象（`scripts/hooks/` 外・参考）

`settings.example.json` は `scripts/hooks/` 外の 3 本も配線している。root 依存の実測結果:

| script | root 導出 |
|---|---|
| `scripts/check-approval-token-write.sh` | **root を導出していない（変更不要）** |
| `scripts/gh-pin-account.sh` | **root を導出していない（変更不要）** |
| `scripts/check-git-destructive.sh` | `SCRIPT_DIR/..`（L53-55）。用途は**監査ログのみ**（コメントに明記あり） |

---

## 2. 現行実装は fail-open である（実測証明）

### 2-1. 機序

`check-plan-hash.sh` の HO 判定（L85-105）は、`target_file` から `$REPO_ROOT/` プレフィックスを剥がして得た `_norm_target` を**リポジトリ相対パターン**（`scripts/hooks/*.sh` 等）と照合する。

```sh
case "$_norm_target" in
  "$REPO_ROOT"/*) _norm_target="${_norm_target#$REPO_ROOT/}" ;;
esac
...
case "$_norm_target" in
  scripts/hooks/*.sh) _override=1 ;;
  AGENTS.md|CLAUDE.md) _override=1 ;;
  ...
esac
```

Claude Code の `tool_input.file_path` は**絶対パス**である。`REPO_ROOT` が誤解決すると剥がしが起きず、`_norm_target` は絶対パスのまま残り、**HO 9 カテゴリのどれにもマッチしない** → `_override=0` → 下流の doc-light / SKIP_REASON 経路に落ちて **rc=0**。

### 2-2. 実測

`scripts/hooks/check-plan-hash.sh` を plugin 相当レイアウト（`<root>/hooks/`）へコピーし、同一入力で比較した。

| # | 配置 | `PLANGATE_HOOK_FILE` | 追加 env | 出力 | rc |
|---|---|---|---|---|---|
| B1 | 正規（`scripts/hooks/`） | `<repo>/scripts/hooks/check-fix-loop.sh` | なし | `HARDENING_OVERRIDE ...` | **2** |
| B2 | 正規 | `<repo>/CLAUDE.md` | なし | `HARDENING_OVERRIDE: CLAUDE.md ...` | **2** |
| F1 | plugin 相当 | `<repo>/scripts/hooks/check-fix-loop.sh` | なし | `SKIP 拒否: SKIP_REASON 未設定` | 2（**理由が HO でない＝HO 分岐は素通り**） |
| F2 | plugin 相当 | `<repo>/scripts/hooks/check-fix-loop.sh` | `PLANGATE_SKIP_REASON=demo` | `[Hook EH-3 SKIP] ... skipped` | **0** ← **HO 全面素通り** |
| F3 | plugin 相当 | `<repo>/CLAUDE.md` | なし | `[Hook EH-3 DOC_LIGHT_SKIP] non-HO .md target ...` | **0** ← **HO 全面素通り** |

**F3 が最も明快**: HO 第 9 カテゴリの `CLAUDE.md` が「non-HO .md」と判定され、`doc-light` で自動 SKIP される。**root 誤解決だけで承認境界が消える。**

> AC-3（偽陰性なし）は「`docs/working/` が無い状態で誤って通さない」だが、実際の穴はより深く、**`docs/working/` の有無以前に HO 判定そのものが無効化される**。是正設計は root 未解決を **fail-closed（rc=2）** にすることを必須要件とする。

### 2-3. 補足: 誤解決しても block する経路があるが、それは偶然である

F1 が rc=2 で止まったのは `PLANGATE_SKIP_REASON` 未設定という別ガードのおかげであり、HO ゲートの働きではない。`PLANGATE_SKIP_REASON` は AI が設定できる env なので、防御として数えてはならない。

---

## 3. root 解決ヘルパー設計（確定案）

### 3-1. 実装

新規ファイル **`scripts/hooks/_plangate-root.sh`**（配布時は `<plugin>/hooks/_plangate-root.sh`）。

```sh
#!/bin/sh
# _plangate-root.sh — PlanGate hook 共通 root 解決（#1144）
#
# 各 hook は自身の隣（$0 相対）から本ファイルを source する。
# $0 相対の「兄弟解決」は上流レイアウト / plugin レイアウトの双方で常に正しい
# （$0 が信頼できる唯一の用途）。project root の推定には $0 を第一候補にしない。
#
# 解決優先順:
#   (1) $CLAUDE_PROJECT_DIR              利用者のプロジェクトルート（plugin 実行時の正）
#   (2) git rev-parse --show-toplevel    利用者のリポジトリルート（.codex/hooks.json と同じ発想）
#   (3) $0 ベース dirname/../..          上流リポジトリ / 既存テストの後方互換
# いずれも marker 検証を通ったものだけ採用する。全滅時は rc=1 を返し、
# 呼び出し側が fail-closed で停止する（PASS にしない）。

# marker: PlanGate プロジェクトルートらしさ。1 つでも該当すれば採用。
plangate_root_is_valid() {
  _c=${1:-}
  [ -n "$_c" ] || return 1
  [ -d "$_c" ] || return 1
  [ -d "$_c/docs/working" ] && return 0
  [ -f "$_c/.plangate.yml" ] && return 0
  [ -d "$_c/.claude" ] && return 0
  { [ -d "$_c/.git" ] || [ -f "$_c/.git" ]; } && return 0
  return 1
}

plangate_abs() { ( CDPATH= cd -- "${1:-}" 2>/dev/null && pwd ) || return 1; }

# usage: REPO_ROOT=$(plangate_resolve_root "$0") || fail-closed
plangate_resolve_root() {
  _self=${1:-}

  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
    _cand=$(plangate_abs "$CLAUDE_PROJECT_DIR") || _cand=""
    if plangate_root_is_valid "$_cand"; then printf '%s\n' "$_cand"; return 0; fi
  fi

  if command -v git >/dev/null 2>&1; then
    _cand=$(git rev-parse --show-toplevel 2>/dev/null) || _cand=""
    if [ -n "$_cand" ]; then
      _cand=$(plangate_abs "$_cand") || _cand=""
      if plangate_root_is_valid "$_cand"; then printf '%s\n' "$_cand"; return 0; fi
    fi
  fi

  if [ -n "$_self" ]; then
    _cand=$(plangate_abs "$(dirname -- "$_self")/../..") || _cand=""
    if plangate_root_is_valid "$_cand"; then printf '%s\n' "$_cand"; return 0; fi
  fi

  return 1
}
```

**marker 検証を入れる理由**: 優先順 (3) は plugin 配置では「plugins キャッシュディレクトリの親」という**存在はするが無関係なディレクトリ**を返す。存在チェックだけでは偽の root を掴んで静かに誤動作するため、marker で棄却して fail-closed に落とす。

### 3-2. 各 hook 側の呼び出し形（fail-closed）

**PreToolUse 系（EH-1/2/3/6/9/13 など、block できる hook）** — 共通置換:

```diff
-REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
+. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/_plangate-root.sh" || {
+  printf '[PlanGate hook] BLOCK: root helper (_plangate-root.sh) not found next to %s\n' "$0" >&2
+  exit 2
+}
+REPO_ROOT=$(plangate_resolve_root "$0") || {
+  printf '[PlanGate hook] BLOCK: PlanGate project root unresolved.\n' >&2
+  printf '  set CLAUDE_PROJECT_DIR, or run inside the target git repository.\n' >&2
+  exit 2
+}
 WORKING_DIR="$REPO_ROOT/docs/working"
```

- **root 未解決は STRICT/warning モードに関係なく常に rc=2**。これはポリシー判定ではなく**構造的失敗**であり、warning に落とすと §2 の穴がそのまま残る。
- JSON judgment を返す hook（`check-plan-exists.sh` / `check-c3-approval.sh` / `cursor-adapter.sh`）は、rc=2 の直前に `{"continue":false,"stopReason":"..."}`（cursor は `{"permission":"deny",...}`）も出力する。

**非 blocking 契約の hook（`check-stop-diff-status.sh` / `check-post-edit-diff.sh` の既定モード）** — 契約を変えない:

```diff
+REPO_ROOT=$(plangate_resolve_root "$0") || {
+  printf '[PlanGate hook] WARN: project root unresolved — skipping (non-blocking hook)\n' >&2
+  exit 0
+}
```

Stop hook の block は会話継続ループのリスクがあるため既存契約（常時 exit 0）を維持する。**この 2 本だけは fail-closed の例外であり、その旨をコメントに明記する**（例外を無記載にすると次の担当者が「fail-open が残っている」と誤読する）。

**`cursor-adapter.sh` は別扱い** — 欲しいのは project root ではなく兄弟ファイル:

```diff
-REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
-HOOK_SCRIPT="$REPO_ROOT/scripts/hooks/$HOOK_NAME"
+SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
+HOOK_SCRIPT="$SELF_DIR/$HOOK_NAME"
```

これで上流（`scripts/hooks/`）でも plugin（`<plugin>/hooks/`）でも同一に解決する。

### 3-3. 別ファイル切り出し vs 各 hook インライン — 判断と根拠

**採用: 別ファイル `_plangate-root.sh` を `$0` 相対で source する。**

| 観点 | 別ファイル source | 17 本インライン複製 |
|---|---|---|
| **配布時に source できるか（最重要）** | **できる。** `$0` の兄弟ファイルは、上流 `scripts/hooks/` でも plugin `<plugin>/hooks/` でも常に同じ相対位置にある。`${CLAUDE_PLUGIN_ROOT}` が hook プロセスに export されるかは**未確認事項**（issue の未確認リストに含まれる）だが、`$0` 相対はその確認結果に依存しない | 該当なし |
| **AC-5（変異注入で各分岐が FAIL する）** | 分岐が 1 箇所に集約されるので (1)(2)(3)+marker の各分岐に対する変異が一意に定義でき、検出力を実証できる | 同じ分岐が 17 本に散り、「どの複製の変異を注入したか」で結果が変わる。**call site ではなく root 解決関数内の分岐を壊せ**という AC-5 の要求を満たしにくい |
| **ドリフト** | 1 実装 | **17 箇所の drift 面**。過去に「4 root で skill frontmatter が同時破損」(#1084) の実績があり、複製戦略はこのリポジトリで再発している失敗パターン |
| **HO 適用コスト** | 新規 1 ファイル + 各 hook 3〜7 行の定型置換（Human patch の目視レビューが容易） | 各 hook に 30 行前後を貼る。HO patch の diff が巨大化しレビュー品質が落ちる |
| **単一障害点** | 配布漏れで全 hook 停止 | なし |

**単一障害点への対処（採用条件）**:

1. source 失敗は **fail-closed（rc=2）** にする（§3-2 の 1 段目）。「helper が無い＝黙って素通り」を作らない。
2. `scripts/check-settings-wiring.sh` に「配線が参照する各 hook と `_plangate-root.sh` が**実際に配布物に存在する**」検査を **経路ごとに 1 行**（#984 の形）で追加し、AC-6 の機械検出とする。
3. `scripts/sync-plugin-plangate.sh` の hook コピー集合を、`scripts/hooks/*.sh` の**全数と同値照合**する（絶対件数は書かない — 成長するディレクトリに件数を焼き込むと無関係 PR の CI を落とす）。

---

## 4. root 解決ヘルパーの実測検証

`plangate_resolve_root` を上記のまま `sh` で実装し、probe スクリプトから 5 経路を実走した。

| ケース | script 配置 | `CLAUDE_PROJECT_DIR` | cwd | 期待 | 実測 rc | 実測 root |
|---|---|---|---|---|---|---|
| A | `<x>/scripts/hooks/probe.sh` | 未設定 | git repo 内 | (2) git toplevel | **0** | `<worktree>` ✅ |
| B | `<x>/plugroot/hooks/probe.sh` | `<x>/fakeproj`（非 git・`docs/working` あり） | git repo 内 | (1) が (2) に優先 | **0** | `<x>/fakeproj` ✅ |
| C | `<x>/plugroot/hooks/probe.sh` | 未設定 | git repo 内 | (2) git toplevel | **0** | `<worktree>` ✅ |
| D | `<x>/plugroot/hooks/probe.sh` | 未設定 | **非 git ディレクトリ** | **fail-closed** | **2** | `ROOT_UNRESOLVED`（stderr）✅ |
| E | mktemp サンドボックス（`git init` 済）内の複製 | 未設定 | **実リポジトリ** | — | 0 | **`<worktree>`（サンドボックスではない）** ⚠ |
| E' | 同上 | サンドボックス | 実リポジトリ | (1) が勝つ | 0 | サンドボックス ✅ |

- 検証コマンドは §8 に掲載。`| head` / `| tail` をパイプ末尾に置かず、rc は `echo "rc=$?"` または python の `returncode` で直接判定した。
- 使用した probe は `plangate_resolve_root "$0"` を呼び、成功時 `ROOT=<path>` を stdout・失敗時 `ROOT_UNRESOLVED` を stderr に出し rc=2 で終了する 8 行の sh。

### 4-1. ケース E は後方互換の**必須付帯作業**である（重大）

`tests/hooks/run-tests.sh` は `mktemp -d` でサンドボックスを作り hook を複製して実行するが、

- **`cd` していない**（cwd は実リポジトリのまま）
- **`CLAUDE_PROJECT_DIR` を設定していない**
- 隔離は「hook が `$0` から root を導く」ことに**全面依存**している（L20-27 のコメントに明記）

したがって優先順 (2) を導入すると、**サンドボックス内の hook が実リポジトリを root と解決し、PR #511 で作った監査ログ隔離が退行する**（実測 E）。

**必須の同時変更**（HO 外・AI-owned）:

```diff
 HOOKS_DIR="$SANDBOX_ROOT/scripts/hooks"
 TEST_ROOT="$SANDBOX_ROOT"
+# #1144: hook の root 解決に $CLAUDE_PROJECT_DIR 優先が入ったため、サンドボックス
+# 隔離を「$0 依存」から「明示指定」へ格上げする（cwd は実リポジトリのままのため
+# git rev-parse --show-toplevel は実リポジトリを指す = 隔離が壊れる）。
+CLAUDE_PROJECT_DIR="$SANDBOX_ROOT"
+export CLAUDE_PROJECT_DIR
```

実測 E' でこの 1 行がサンドボックスへ正しく戻すことを確認済み。**この変更は Stage 0 で入れ、Stage 1 の前に置くこと**（順序を逆にすると 79 件のテストが実リポジトリを汚染する）。

---

## 5. 段階導入案（6 Stage）

各 Stage は独立して merge 可能で、**前の Stage が緑でなければ次に進まない**。`scripts/hooks/*.sh` に触る Stage 1-4 は **HO 適用（Human-owned）** を伴う。

### Stage 0 — ヘルパー新設 + テスト側の隔離格上げ（hook 挙動は不変）

| 変更 | 責務 |
|---|---|
| `scripts/hooks/_plangate-root.sh` 新設 | HO（`scripts/hooks/*.sh` に一致）→ **Human 適用** |
| `tests/hooks/root-resolution-test.sh` 新設（3 経路 + fail-closed + marker 棄却） | AI-owned |
| `tests/hooks/run-tests.sh` に `CLAUDE_PROJECT_DIR="$SANDBOX_ROOT"` を追加（§4-1） | AI-owned |

**検証**:
1. `sh tests/hooks/run-tests.sh` → 新規 FAIL なし（着手時 baseline は §8 参照）。
2. 新テストが 5 ケース（A/B/C/D + marker 棄却）で PASS。
3. **変異注入（AC-5）**: `_plangate-root.sh` の (1)(2)(3) 各分岐と `plangate_root_is_valid` の各 marker を 1 つずつ壊し、対応する TC が FAIL することを確認。call site ではなく**関数内の分岐**を壊す。

### Stage 1 — 中核ゲート 5 本

`check-plan-hash.sh` / `check-c3-approval.sh` / `check-plan-exists.sh` / `check-forbidden-files.sh` + `cursor-adapter.sh`。

> issue が挙げる 5 本目の `scripts/check-approval-token-write.sh` は **root を導出していないため変更不要**（§1-b 実測）。代わりに、plugin 配布時に必ず壊れる `cursor-adapter.sh`（§3-2）を中核に繰り上げる。

**検証**:
1. §2 の F1/F2/F3 を**再実行し、すべて `HARDENING_OVERRIDE` で rc=2 になる**こと（fail-open の直接再現テストを回帰テスト化する）。
2. `sh tests/hooks/run-tests.sh` 新規 FAIL なし。
3. B1/B2（正規配置での HO block）が rc=2 のまま不変。
4. `PLANGATE_HOOK_STRICT` / `PLANGATE_BYPASS_HOOK` の既存挙動が不変。
5. `sh scripts/check-settings-wiring.sh --target example` が PASS。

### Stage 2 — git コンテキスト系 3 本

`check-post-edit-diff.sh` / `check-stop-diff-status.sh` / `check-metrics-privacy.sh`。

**検証**: 非 git ディレクトリでの no-op が維持されること／Stop hook が **exit 0 固定**のまま（fail-closed 例外）であること／`check-metrics-privacy.sh` が誤 root で「staged 0 件だから PASS」を出さないこと。

### Stage 3 — 残る判定入力系 7 本

`check-fix-loop.sh` / `check-handoff-elements.sh` / `check-merge-approvals.sh` / `check-test-cases.sh` / `check-v3-review.sh` / `check-verification-evidence.sh` / `check-ai-memory-pollution.sh`。

**検証**: 各 hook の既存テストが不変／`check-fix-loop.sh` はカウンタファイルの**書き込み先**が root に追随することを別途確認（状態を持つ唯一の hook）。

### Stage 4 — 監査ログのみの 2 本

`check-auth-preflight.sh` / `check-delegation-commit-boundary.sh`。判定に影響しないため最後。

### Stage 5 — 配布の有効化（ここで初めて 3 経路に載せる）

| 変更 | 責務 |
|---|---|
| `plugin/plangate/hooks/hooks.json` 新設（§6） | AI-owned |
| `plugin/plangate/.claude-plugin/plugin.json` に `"hooks": "./hooks/hooks.json"` を宣言（AC-8） | AI-owned |
| `scripts/sync-plugin-plangate.sh` に hook `.sh` の同期を追加（全数同値照合・件数は焼かない） | AI-owned |
| `install.sh` L105 の `for dir in agents skills commands rules` に `hooks` を追加（AC-10 の 3 経路整合） | AI-owned |
| `plugin/plangate/README.md` の「reserved（未実装）」を実態へ更新 + 未配布 hook 一覧を明示（AC-7）+ `../../docs/...` 相対参照の是正（#954 クラス C） | AI-owned |
| `scripts/check-settings-wiring.sh` に「参照パス ↔ 配布物」検査を経路ごとに 1 行追加（AC-6） | AI-owned |
| `.claude/settings.example.json` に `timeout` 宣言を追加（AC-9・§6-2） | **HO（`.claude/settings*.json`）→ Human 適用** |

**検証（AC-1 / AC-2）**: クリーンな別リポジトリへ導入し、
1. HO パス（例: 導入先の `CLAUDE.md`）への Write が **rc=2 で block** される（「配置されている」ではなく「block した」を証跡にする）。
2. `docs/working/TASK-XXXX/` が**存在しない**導入先で、HO パスへの書き込みが**通らない**（AC-3）。
3. hook 未同梱時（helper 配布漏れの疑似）に **fail-closed で止まる**ことを 1 ケース確認する。

---

## 6. `hooks/hooks.json` と `plugin.json` の宣言案

### 6-1. `plugin/plangate/hooks/hooks.json`

`.codex/hooks.json` の形（root を「利用者のリポジトリ」で解決する + `timeout` 必須）を踏襲する。ただし Claude 経路では `${CLAUDE_PLUGIN_ROOT}` で**スクリプト本体の場所**を、hook 内部の `plangate_resolve_root` で**利用者の project root** を、それぞれ解決する（2 つの root を混同しない）。

```json
{
  "$schema_note": "Claude Code plugin hooks. ${CLAUDE_PLUGIN_ROOT} = plugin install dir. Project root is resolved inside each hook via _plangate-root.sh (CLAUDE_PROJECT_DIR > git toplevel > $0).",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/check-plan-exists.sh\"",
            "timeout": 10,
            "statusMessage": "PlanGate EH-1 plan-exists"
          },
          {
            "type": "command",
            "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/check-c3-approval.sh\"",
            "timeout": 10,
            "statusMessage": "PlanGate EH-2 c3-approval"
          },
          {
            "type": "command",
            "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/check-plan-hash.sh\"",
            "timeout": 15,
            "statusMessage": "PlanGate EH-3 plan_hash"
          },
          {
            "type": "command",
            "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/check-forbidden-files.sh\"",
            "timeout": 10,
            "statusMessage": "PlanGate EH-6 forbidden_files"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/check-delegation-commit-boundary.sh\"",
            "timeout": 10,
            "statusMessage": "PlanGate EH-9 delegation-commit-boundary"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/check-post-edit-diff.sh\"",
            "timeout": 10,
            "statusMessage": "PlanGate post-edit diff check"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/check-stop-diff-status.sh\"",
            "timeout": 10,
            "statusMessage": "PlanGate stop diff/status check"
          }
        ]
      }
    ]
  }
}
```

**注意（`.codex/hooks.json` から意図的に変えた点）**: Codex 側は `sh "$(git rev-parse --show-toplevel)/.codex/hooks/eh-bridge.sh"` でスクリプト位置を解決するが、**plugin 配布ではスクリプトは利用者リポジトリに無い**。したがって「スクリプト位置＝`${CLAUDE_PLUGIN_ROOT}`」「project root＝hook 内部で解決」に分離する。

`timeout` はハングを block に変える（#1101）。`check-plan-hash.sh` は python3 + `flock` + `maintenance.json` 消費があるため 15、他は 10（`.codex/hooks.json` と同値）。

### 6-2. `plugin/plangate/.claude-plugin/plugin.json`（AC-8）

```diff
   "skills": "./skills/",
+  "hooks": "./hooks/hooks.json",
   "repository": "https://github.com/s977043/plangate",
```

`skills` と同じく**明示宣言が必須**であり、`hooks/hooks.json` を置くだけでは読み込まれない。`.codex-plugin/plugin.json` との parity は `scripts/check-plugin-manifest-parity.sh`（#1085 で `release-prep.sh --check` に配線済み）が対象にするため、**Codex 側は hook を plugin 経由で配らない方針であることを parity 検査の除外として明記する**（無記載だと parity 検査が落ちる）。

### 6-3. `.claude/settings.example.json` の timeout 宣言（AC-9・HO / Human 適用）

現状 **11 配線すべてで `timeout` が 0 件**（実測: `grep -c timeout` = 0）。各 `{"type":"command","command":...}` に以下を付す:

| hook | timeout |
|---|---|
| `check-plan-hash.sh` | 15 |
| 他の PreToolUse / PostToolUse / Stop / SessionStart | 10 |

---

## 7. 前提として渡された事実との食い違い

| # | 渡された前提 | 実測 | 影響 |
|---|---|---|---|
| 1 | 「`.codex/hooks.json` が既に正解に近い形を持つ」 | **半分しか正しくない。** `git rev-parse --show-toplevel` が解決しているのは **bridge スクリプト（`.codex/hooks/eh-bridge.sh`）の位置**だけで、`eh-bridge.sh` は内部で `REPO_ROOT=$(dirname $0)/../..` を再導出し `$REPO_ROOT/scripts/hooks/$HOOK_NAME` を実行する。つまり**利用者リポジトリに `scripts/hooks/` が実在することを前提にしており、plugin 配布問題は解いていない** | §6-1 で「スクリプト位置」と「project root」を分離した理由。Codex の形をそのまま Claude に移すと配布は直らない |
| 2 | 「`scripts/hooks/*.sh` は 17 本、全て `$0` ベース」 | **17 本・全て `$0` ベースで一致**。ただし `settings.example.json` が配線する `scripts/` 直下の 3 本のうち **2 本（`check-approval-token-write.sh` / `gh-pin-account.sh`）は root を一切導出しない**。issue の「10/10 未配布」表と「17 本の root 解決」は**対象集合が異なる** | 中核ゲート 5 本の 1 つとして挙がっていた `check-approval-token-write.sh` は root 修正不要。Stage 1 の構成を差し替えた（§5 Stage 1） |
| 3 | （前提外の追加発見） | `tests/hooks/run-tests.sh` のサンドボックス隔離が **`$0` 依存に全面依存**しており、優先順 (2) の導入だけで**隔離が退行する** | §4-1。Stage 0 での同時変更が必須 |
| 4 | （前提外の追加発見） | `.claude/settings.json` は **リポジトリに存在しない**（ローカル専用・未追跡）。timeout 実測は `settings.example.json` = 0 件で確認 | AC-9 の対象は example（配布雛形）。issue の表と矛盾はしない |

---

## 8. 実行した検証コマンドと exit code

すべて worktree `/Users/user/Documents/GitHub/plangate/.claude/worktrees/agent-aa5336c660b8606d0` 内で実行。パイプ末尾に `| head` / `| tail` を置いて rc 判定していない。

| # | コマンド | rc | 結果 |
|---|---|---|---|
| V1 | `git grep -n 'REPO_ROOT\|PROJECT_DIR\|show-toplevel' scripts/hooks/*.sh`（相当） | 0 | 17/17 が `$0` ベース、`CLAUDE_PROJECT_DIR` 参照 0 本 |
| V2 | `grep -c 'WORKING_DIR' scripts/hooks/*.sh` | 0 | 監査ログのみ利用の hook を特定（§1-a） |
| V3 | `PLANGATE_HOOK_FILE="$PWD/scripts/hooks/check-fix-loop.sh" sh scripts/hooks/check-plan-hash.sh </dev/null` | **2** | B1: `HARDENING_OVERRIDE` |
| V4 | `PLANGATE_HOOK_FILE="$PWD/CLAUDE.md" sh scripts/hooks/check-plan-hash.sh </dev/null` | **2** | B2: `HARDENING_OVERRIDE: CLAUDE.md` |
| V5 | `PLANGATE_HOOK_FILE="$PWD/scripts/hooks/check-fix-loop.sh" sh <plugin-layout>/check-plan-hash.sh </dev/null` | 2 | F1: 理由が `SKIP 拒否`（HO 分岐は素通り） |
| V6 | `PLANGATE_SKIP_REASON="demo" PLANGATE_HOOK_FILE="$PWD/scripts/hooks/check-fix-loop.sh" sh <plugin-layout>/check-plan-hash.sh </dev/null` | **0** | F2: **HO 全面素通り（fail-open 証明）** |
| V7 | `PLANGATE_HOOK_FILE="$PWD/CLAUDE.md" sh <plugin-layout>/check-plan-hash.sh </dev/null` | **0** | F3: `DOC_LIGHT_SKIP: non-HO .md`（**HO 全面素通り**） |
| V8 | `env -u CLAUDE_PROJECT_DIR PLANGATE_ROOT_HELPER=... sh <x>/scripts/hooks/probe.sh` | 0 | ケース A: (2) が worktree を返す |
| V9 | `CLAUDE_PROJECT_DIR=<x>/fakeproj PLANGATE_ROOT_HELPER=... sh <x>/plugroot/hooks/probe.sh` | 0 | ケース B: (1) が (2) に優先 |
| V10 | `env -u CLAUDE_PROJECT_DIR ... sh <x>/plugroot/hooks/probe.sh` | 0 | ケース C: plugin 配置でも (2) で正解 |
| V11 | 同上を **非 git ディレクトリ** を cwd に python `subprocess.run` で実行 | **2** | ケース D: `ROOT_UNRESOLVED` = **fail-closed** |
| V12 | mktemp サンドボックス複製 + cwd=実リポジトリ | 0 | ケース E: **実リポジトリに解決（隔離退行の実証）** |
| V13 | 同上 + `CLAUDE_PROJECT_DIR=<sandbox>` | 0 | ケース E': サンドボックスに正しく解決 |
| V14 | `sh tests/hooks/run-tests.sh` | **0** | **baseline: 79 passed, 0 failed**（測定環境: 本 worktree / `387ea21`。AC-4 の比較はこの測定環境とセットで扱い、絶対件数を契約値にしない） |

検証用の probe / helper / plugin 相当レイアウトは worktree 内の一時ディレクトリに作成し、**検証後に削除済み**（`git status --short` = 空）。

---

## 9. スコープ外だが発見した問題（本 PR では手を出していない・報告のみ）

| # | 内容 | 位置 |
|---|---|---|
| S1 | `.codex/hooks/eh-bridge.sh` は hook の **rc=1 を deny** に変換するが、Claude Code は rc=1 を non-blocking として扱う。**同じ hook が Codex では block、Claude では素通り**という強制力の非対称がある（`check-plan-hash.sh` の plan_hash mismatch は STRICT 時 **exit 1**） | `.codex/hooks/eh-bridge.sh` の `case "$rc" in 2\|1)` / `scripts/hooks/check-plan-hash.sh` L374 |
| S2 | `eh-bridge.sh` が `/tmp/eh-bridge-out.$$` に固定パスで書く（共有 `/tmp` での symlink 競合面） | `.codex/hooks/eh-bridge.sh` |
| S3 | `plugin/plangate/README.md` の `../../docs/ai/settings-wiring-contract.md` は導入先で解決しない（#954 クラス C の残存。issue にも記載あり） | `plugin/plangate/README.md:306` |
| S4 | `plugin/plangate/skills/ai-loop-cycle/scripts/__pycache__` が配布されている（配布物の衛生） | issue Notes 3 と同一 |
| S5 | `check-plan-hash.sh` の HO 判定は `_norm_target` の**小文字化を行わない**（no-task 分岐の plan.md 判定は小文字化する）。macOS の大小非区別 FS では `Claude.md` が HO をすり抜けうる。#1101 の正規化議論と同じ帯 | `scripts/hooks/check-plan-hash.sh` L95-105 vs L123 |
| S6 | `install.sh` は `hooks` も `scripts` も配らないため、Stage 5 で `hooks` を足しても **`bin/plangate` は依然未配布**（#1057） | `install.sh:105` |

---

## 10. 責務まとめ

| 作業 | 責務 |
|---|---|
| 本設計書の作成 / 検証 / patch 提示 | **AI-owned**（完了） |
| `scripts/hooks/*.sh`（helper 新設含む）への適用 | **Human-owned**（HO 9 カテゴリ） |
| `.claude/settings.example.json` の timeout 追加 | **Human-owned**（HO） |
| `tests/` / `install.sh` / `scripts/sync-plugin-plangate.sh` / `plugin/plangate/**` / `scripts/check-settings-wiring.sh` | AI-owned（ただし `.sh` 新規作成には `PLANGATE_HOOK_TASK` セッションが必要） |
| Mode 判定 | **critical**（配布構成の変更 + HO 対象への patch。`lite_eligible=false`・同期 C-3 固定） |
