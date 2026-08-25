# #1104 Bash 経路ガード — 機械適用可能な patch（`1104-bash-route-guard-patch.md` の適用可能化）

> 元設計書: [`1104-bash-route-guard-patch.md`](./1104-bash-route-guard-patch.md)（測定基点 `origin/main` = `74e158c` / 2026-08-18）
> 本書の測定基点: **`origin/main` = `8cb9e82`** / 2026-08-25。以下の数値・行の主張はすべてこの ref に対する実測。
> 位置づけ: [`backlog-triage-2026-08-24.md`](./backlog-triage-2026-08-24.md) **Phase -1a**。元設計書は unified diff のファイルヘッダを持たず `git apply` できなかった。本書はそれを機械適用可能な形へ変換する。
> **設計は作り直していない。** 元設計書の Step 1 / Step 2 / Step 3 をそのまま踏襲し、**Human 判断が未確定の部分は patch 化せず「未確定」として明示**する（§7）。

---

## 0. 結論先行

| 項目 | 結論 |
|---|---|
| **採った形式** | **冪等 apply スクリプト設計**（`scripts/apply-1104-bash-route-wiring.sh`）。**参照値として検証済み unified diff も併載**（§5） |
| **patch 化できた範囲** | **Step 3（配線）のみ** — `.claude/settings.example.json` + `scripts/check-settings-wiring.sh` |
| **patch 化しなかった範囲** | **Step 1（検出器の切り出し）/ Step 2（HO ガードの Bash 分岐）** — 元設計書の「設計判断 3 点」のうち **判断 1・判断 2 が未確定**で、確定内容によって出力コードが変わるため |
| **#1101 との順序** | **順序依存あり。`#1101` → `#1104`**（§6。元設計書と同じ結論だが、**根拠は性能ではなく正確性**。元設計書の性能根拠は本書では再現できなかった） |
| **本タスクで編集したファイル** | 本書 1 ファイルのみ。`.claude/` / `scripts/` / `bin/` / `schemas/` / `.github/` は **1 バイトも変更していない** |

### なぜ unified diff 単独ではなく apply スクリプトか

| 要求 | unified diff | apply スクリプト |
|---|---|---|
| **適用順序の前提を強制する**（Step 1-2 未了で配線だけ入れると「配線検査は緑・ガードは無効」になる） | 不可 | **可**（`check-plan-hash.sh` に marker が無ければ何も書かずに `exit 1`） |
| **適用後が valid JSON であることの検査** | 不可 | **可**（`json.loads` + 構造 assert に通らなければ書かずに中止） |
| **実 HO パスへの書き込みに明示確認を要求** | 不可 | **可**（`PLANGATE_APPLY_CONFIRM=1`。先行例 `scripts/apply-ci-lint-wiring.sh` と同型） |
| **冪等**（2 回目は no-op） | 不可（2 回目は reject） | **可**（構造判定で既適用を検出） |
| **2 ファイルを 1 トランザクションで**（配線と配線検査は同時に入らないと片方が嘘になる） | 弱い（部分適用しうる） | **可**（前段検査を全部通してから書き込む） |

いずれも #1104 の性質（**「ガードはあるが迂回できる」構造の是正**）に直結する。とくに 1 行目 —— 配線だけ先に入ると `check-settings-wiring.sh` が PASS を返すのに Bash 経路は素通りのままになり、**#1104 が塞ごうとしている「観測できない穴」を、観測系そのものに作る**。diff にはこれを止める手段がない。

なお `.claude/settings.json`（利用者の実ファイル）は **`.gitignore` 対象で tracked ではない**（実測: `git ls-files .claude/settings.json` が空 / `.gitignore` に `settings.json` 3 件）。`scripts/apply-claude-settings.sh` が `.claude/settings.example.json` を正本として `(event, matcher, script path)` キーで**冪等 merge** するため、**example を直せば実 settings.json へは既存の適用経路で伝播する**。本 patch が example のみを対象にするのはこのため。

---

## 1. 元設計書の前提を現 main で再測定

測定コマンドは各行に併記する（ref 明示。作業ツリーの `ls` / `grep -r` は使っていない）。

| # | 元設計書の主張 | 現 main（`8cb9e82`）での実測 | 判定 |
|---|---|---|---|
| 1 | 配線済み hook **11 件** | 11 件（`SessionStart` 1 / `PreToolUse` 8 / `PostToolUse` 1 / `Stop` 1） | **成立** |
| 2 | 書き込みガード **5 本**のうち 4 本が `Edit\|Write` 限定、`check-approval-token-write.sh` のみ両配線 | 同左（下表） | **成立** |
| 3 | `.claude/settings.example.json` も同一 matcher 集合 | `git diff 74e158c origin/main -- .claude/settings.example.json` が**空**（74e158c 以降 無変更） | **成立** |
| 4 | HO 判定を持つ配線済み hook は `check-plan-hash.sh` の 1 本のみ | 同左。HO `case` は **9 カテゴリ**（`_override=0` 直後の `case`〜`esac`） | **成立** |
| 5 | Step 1 の切り出し対象は **`_strip_nonwrite_redirects` / `_has_write_intent` の 2 関数** | **不成立（閉包が不足）**。§2 参照 | **不成立** |
| 6 | 判断 3 の前提「現行の小文字化実装は 4,000 文字で 59 秒」 | **再現できず**。§6 参照 | **未確定** |
| 7 | AC-8「`check-settings-wiring.sh` の `checks` へ追加」 | `checks` は現在 **6 件**。追加すると 7 件 | **成立** |

### 1-1. matcher 構成（`.claude/settings.example.json` を JSON パースして列挙）

測定: `git show origin/main:.claude/settings.example.json | python3 -c "import json,sys; ..."`

| event | matcher | hook |
|---|---|---|
| SessionStart | （省略） | `scripts/gh-pin-account.sh` |
| PreToolUse | `Edit\|Write` | `scripts/hooks/check-plan-exists.sh` |
| PreToolUse | `Edit\|Write` | `scripts/hooks/check-c3-approval.sh` |
| PreToolUse | `Edit\|Write` | **`scripts/hooks/check-plan-hash.sh`**（HO 判定を持つ唯一の hook） |
| PreToolUse | `Edit\|Write` | `scripts/hooks/check-forbidden-files.sh` |
| PreToolUse | `Bash` | `scripts/hooks/check-delegation-commit-boundary.sh` |
| PreToolUse | `Edit\|Write` | `scripts/check-approval-token-write.sh` |
| PreToolUse | **`Bash`** | `scripts/check-approval-token-write.sh` |
| PreToolUse | `Bash` | `scripts/check-git-destructive.sh` |
| PostToolUse | `Edit\|Write\|MultiEdit` | `scripts/hooks/check-post-edit-diff.sh` |
| Stop | （省略） | `scripts/hooks/check-stop-diff-status.sh` |

**`PreToolUse` の 8 エントリの内訳: `Edit|Write` = 5 / `Bash` = 3。スクリプト単位では `Edit|Write` のみ 4 本 / `Bash` のみ 2 本 / 両方に配線 1 本（EH-13 のみ）**。元設計書の穴の記述はそのまま成立する。

**陽性コントロール**: `matcher == "Bash"` かつ command に `check-plan-hash.sh` を含むブロックを構造検索 → **0 件**（穴が存在することの実測）。同じ検索を §5 の patch 適用後に実行すると **1 件**（§4 TC-05）。

---

## 2. Step 1（検出器の切り出し）— **元設計書の「2 関数」は現 main では閉包として不足**

元設計書は `scripts/check-approval-token-write.sh` から次の 2 関数を `scripts/lib/write-intent.sh`（新規）へ切り出す設計だった。

- `_strip_nonwrite_redirects()` — リダイレクト正規化
- `_has_write_intent()` — 書き込み意図の判定（6 ルール）

現 main を実測すると、**`_has_write_intent` は単独では閉じていない**。

```text
_has_write_intent
  └─ _strip_nonwrite_redirects        （path 非依存 / そのまま移せる）
  └─ _redirect_writes_token           （#1110。元設計書の 2 関数に含まれていない）
        └─ _is_token_path             （**承認トークン path 専用**の述語）
```

さらに **`_has_write_intent` の呼出側**にも path 依存の外側ゲートがある:

```sh
if _cmd_may_target_token "$_cmd" && _has_write_intent "$_cmd"; then   # t1115-glob-gate
```

`_cmd_may_target_token` は **`74e158c` には存在せず**、`01c8946`（#1115 / PR #1148、`74e158c..origin/main` の +177/-2）で追加された。つまり元設計書の測定基点以降に **path 依存の層が 1 枚増えている**。

測定:

- `git show 74e158c:scripts/check-approval-token-write.sh | grep -c _cmd_may_target_token` → **0**
- `git show origin/main:scripts/check-approval-token-write.sh | grep -n _cmd_may_target_token` → **2 行**（198 = 定義 / 424 = 参照 `# t1115-glob-gate`）
- `git log --oneline 74e158c..origin/main -- scripts/check-approval-token-write.sh` → `01c8946`

### 帰結（元設計書の設計方針は維持される）

元設計書は既に「**切り出す際は『リダイレクト先パスを引数で受け取る』形へ一般化する必要がある**／他 5 ルールは path 非依存なのでそのまま再利用できる」と書いており、**方針は正しい**。現 main で更新が必要なのは**一般化の対象範囲**だけ:

| 関数 | 元設計書 | 現 main で必要な扱い |
|---|---|---|
| `_strip_nonwrite_redirects` | 移す | 移す（無変更） |
| `_redirect_writes_token` | （言及なし） | **移す。`_is_token_path` を「path 述語」として注入可能にする**（EH-13 は承認トークン述語、#1104 は HO / plan.md 述語を渡す） |
| `_has_write_intent` | 移す | 移す（`_redirect_writes_token` の述語注入に追随） |
| `_is_token_path` | （言及なし） | **移さない**（EH-13 固有。呼出側に残す） |
| `_cmd_may_target_token` | （言及なし） | **移さない**（EH-13 固有の外側ゲート。#1104 は HO / plan.md 版の外側ゲートを別途持つ） |

元設計書の制約「`cat > /tmp/x` は `_has_write_intent` 単体では非検出（`file-redirect` は path 結合型）」は**現 main でも成立**し、上記の述語注入がその一般化にあたる。

> **元の挙動を変えないこと**（元設計書 Step 1）は不変の制約。EH-13 は v8.19.0 で fail-closed 化されており（#1079）、切り出しで新たな依存・失敗経路を増やしてはならない。

### なぜ patch 化しないか

述語注入の**シグネチャ**（コールバック関数名を渡すか / 環境変数で切り替えるか / ライブラリを 2 度 source するか）は、**元設計書に書かれていない**。ここを本書で決めると「設計を作り直す」ことになる。**未確定として §7 に残す**。

---

## 3. Step 2（HO ガードの Bash 分岐）— **判断 1・判断 2 が未確定のため patch 化しない**

元設計書 Step 2 の骨子（そのまま踏襲）:

```text
tool_name == "Bash" のとき:
  1. tool_input.command から書き込み意図を判定（Step 1 のライブラリ）
  2. 書き込み意図があれば、対象パス候補を抽出
  3. 抽出したパスに対して 既存の HO 判定 / plan.md 判定をそのまま適用
  4. 抽出できない場合の扱い → 判断 1
```

現 main の `scripts/hooks/check-plan-hash.sh` は **`tool_input.file_path` しか読まない**（`jq -r '.tool_input.file_path // .file_path // empty'`。`tool_name` を参照する箇所は**ゼロ**）。したがって Step 2 は**新規分岐の追加**であり、既存の `Edit|Write` 経路の挙動は変えない。

**HO 判定ロジック自体は変更しない**（`_override=0` 直後の `case`〜`esac` = 9 カテゴリを再利用）。

### patch 化しない理由（元設計書の未確定事項をそのまま継承）

| 未確定 | 出力コードへの影響 |
|---|---|
| **判断 1**: パス抽出不能なコマンド（`eval` / `sh -c "$(...)"` / `python3 script.py`）を fail-open にするか fail-closed にするか | 分岐の終端が `exit 0 + 記録` か `exit 2` かで**別のコードになる**。元設計書の推奨は **fail-open + 記録**（`skip-decision-log.jsonl`）だが、これは推奨であって確定ではない |
| **判断 2**: 正規経路（`bin/plangate plan` / `init` / `sh scripts/apply-*.sh --apply` / `sync-plugin-plangate.sh`）の許可方式 | allowlist / 呼び出し元判定 / 専用 env のどれを採るかで**分岐の位置も条件式も変わる**。元設計書は「`PLANGATE_BYPASS_HOOK` の流用は避けるべき」とだけ述べる |

**この 2 点は Human 判断**（元設計書「責務」表）。確定前に patch を書くと、確定後に**丸ごと書き直しになる**か、より悪く「patch があるから確定済みだ」という誤読を生む。

### Step 2 が満たすべき契約（確定に依存しない部分だけを固定）

元設計書の受入基準から、**判断 1・2 の帰結に依らず必ず成立する**ものだけを抜き出す。実装時にこの表がテストの骨格になる。

| ID | 契約 | 元 AC |
|---|---|---|
| S2-C1 | `python3` heredoc 内の `.write()`（2026-08-18 に実際に踏まれた迂回）が HO パス宛のとき block される | AC-1 |
| S2-C2 | #833 の 3 件と同型のコマンドが block される | AC-2 |
| S2-C3 | 読み取り専用コマンド（`grep` / `ls` / `cat` 単体 / `git log`）は block されない | AC-4 |
| S2-C4 | `tool_name != "Bash"` の入力に対する挙動が**現行と byte 一致**（既存 `Edit\|Write` 経路の非回帰） | — |
| S2-C5 | 分岐が **`t1104-bash-route`** マーカーを持つ（§4 の apply スクリプトが前提検査に使う） | — |
| S2-C6 | block・抽出不能のいずれも `docs/working/_audit/skip-decision-log.jsonl` に残る | AC-6 |

> **S2-C5 はガード同士の結合点**。marker が無いと apply スクリプトが `exit 1` するので、「Step 2 を入れ忘れたまま配線だけ入る」経路が物理的に閉じる。

---

## 4. Step 3（配線）— 採用形式: 冪等 apply スクリプト

### 4-1. 何を変えるか

| 対象 | 変更 | HO |
|---|---|---|
| `.claude/settings.example.json` | `PreToolUse` に `matcher: "Bash"` の `check-plan-hash.sh` ブロックを 1 つ追加 | **HO 対象** |
| `scripts/check-settings-wiring.sh` | `checks[]` に `("check-plan-hash.sh", "Bash", ...)` を 1 行追加（AC-8） | 非 HO |

**この 2 つは同時に入らなければならない。** 配線だけ入れると検査が無く、検査だけ入れると CI が赤になる。よって 1 スクリプト・1 トランザクションで扱う。

### 4-2. スクリプト本体

新規作成する案の名称は `scripts/apply-1104-bash-route-wiring.sh`。先行例 `scripts/apply-ci-lint-wiring.sh` と同じ構造（`--dry-run` 既定 / `--apply` は実 HO パスで `PLANGATE_APPLY_CONFIRM=1` 要求 / atomic write / anchor 一意性検査 / 適用後の妥当性検査）。**本タスクではこのスクリプトを repo へ作成していない**（`scripts/` は patch 提示のみ）。

#### シェルラッパの契約（先行例との差分のみ）

| 項目 | 先行例 `apply-ci-lint-wiring.sh` | 本スクリプト |
|---|---|---|
| 対象 | `.github/workflows/ci.yml` 1 本 | `.claude/settings.example.json` + `scripts/check-settings-wiring.sh` の **2 本を 1 トランザクション** |
| sandbox seam | `--target FILE` | `--target-root DIR`（**絶対パスのみ受理**。相対指定を正規化するために任意ディレクトリへ移動する手順を持たせない） |
| HO 確認ゲート | 適用先が `<repo>/.github/workflows/` 配下なら `PLANGATE_APPLY_CONFIRM=1` 必須 | 適用先が `<repo>/.claude/` 配下なら `PLANGATE_APPLY_CONFIRM=1` 必須 |
| **前提検査** | なし | **あり**: `scripts/hooks/check-plan-hash.sh` に marker `t1104-bash-route` が無ければ何も書かずに `exit 1`（Step 1-2 未了で配線だけ入るのを止める） |
| 既定モード | `--dry-run`（書き込みなし） | 同じ |
| 書き込み | `atomic_write`（tmp → `os.replace`、mode 保持） | 同じ |
| exit code | 0 = 成功 / 1 = 何も書かずに失敗 | 同じ |

`--dry-run` / `--apply` / `--target-root` 以外の引数は `exit 1`（strict）。`set -eu`。

#### 変換コア（python 部・逐語）

アンカーと置換文字列、冪等判定、適用後検査。**ここが正確さの本体**なので逐語で載せる。

````python
HOOK_CMD = "scripts/hooks/check-plan-hash.sh"

def has_bash_planhash(doc):
    """構造判定: PreToolUse に matcher=Bash かつ check-plan-hash.sh の hook があるか。
    文字列 marker ではなく JSON 構造で見るため、コメント文の揺れで冪等性が壊れない。"""
    pre = ((doc or {}).get("hooks", {}) or {}).get("PreToolUse", []) or []
    for blk in pre:
        if not isinstance(blk, dict):
            continue
        if (blk.get("matcher") or "").strip() != "Bash":
            continue
        for h in blk.get("hooks", []) or []:
            if isinstance(h, dict) and HOOK_CMD in (h.get("command") or ""):
                return True
    return False

# アンカー: EH-3 ブロックの末尾（command 行 + 閉じ括弧）。JSON 内で一意（実測 count == 1）。
S_ANCHOR = (
    '            "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/hooks/check-plan-hash.sh '
    '${PLANGATE_HOOK_TASK:-} ${PLANGATE_HOOK_FILE:-}"\n'
    '          }\n'
    '        ]\n'
    '      },\n'
)
S_NEW = (
    '      {\n'
    '        "_comment_": "Hook EH-3b (#1104): Bash route HO / plan.md guard. '
    'Applies the same HO decision as EH-3 to write-intent Bash commands.",\n'
    '        "matcher": "Bash",\n'
    '        "hooks": [\n'
    '          {\n'
    '            "type": "command",\n'
    '            "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/hooks/check-plan-hash.sh '
    '${PLANGATE_HOOK_TASK:-} ${PLANGATE_HOOK_FILE:-}"\n'
    '          }\n'
    '        ]\n'
    '      },\n'
)

W_ANCHOR = '    ("check-plan-hash.sh", "Edit|Write", "EH-3 plan-hash"),\n'
W_NEW = '    ("check-plan-hash.sh", "Bash", "EH-3b Bash route plan-hash(#1104)"),\n'
````

適用手順（python 部）:

1. `settings.example.json` を `json.loads`。**この時点で無効 JSON なら `exit 1`**（何も書かない）
2. `has_bash_planhash(doc)` が真 → **既適用**として置換をスキップ（冪等）
3. 偽 → `S_ANCHOR` の出現回数を数え、**ちょうど 1 でなければ `exit 1`**（未検出も多重も止める。全体を止めるので片方だけ適用されない）
4. 置換後の文字列を **`json.loads` で再パース**。失敗すれば `exit 1`（**適用後が valid JSON であることの検査**）
5. 再パース結果に `has_bash_planhash` が真であることを assert。偽なら `exit 1`（**「置換したのに構造が意図どおりでない」を捕捉**）
6. `json.dumps(before, sort_keys=True) == json.dumps(after, sort_keys=True)` なら `exit 1`（**「何も変わっていないのに成功を返す」を捕捉**）
7. `check-settings-wiring.sh` も同様に `W_NEW` 在否で冪等判定 → `W_ANCHOR` 一意性検査 → 置換
8. 両方すでに適用済みなら `already applied` で `exit 0`
9. `--dry-run` なら**両ファイルの unified diff を stdout に出して終了**（書き込みゼロ）
10. `--apply` のときのみ `atomic_write` を 2 回

> **4〜6 が「JSON パースして適用後に valid であることを検証する手段」の実体**。3 と合わせて「アンカー未検出で全体 exit 1」も満たす。

### 4-3. TC 契約と実測

**実測の範囲**: `origin/main` の 3 ファイル（`.claude/settings.example.json` / `scripts/check-settings-wiring.sh` / `scripts/hooks/check-plan-hash.sh`）を **worktree 外の sandbox へ複製**し、**§4-2 の変換コアを実走**した結果。**シェルラッパは repo へ作成していないため、ラッパ側 TC（前提検査 / HO 確認ゲート / 引数 strict）は「実装時に満たすべき契約」であり未実走**。区別して読むこと。

| TC | 何を検出するか | 判定方法 | 実測 |
|---|---|---|---|
| **TC-01** | アンカーが一意でない（未検出 / 多重）まま置換して**別の場所を壊す** | `before.count(S_ANCHOR)` / `before.count(W_ANCHOR)` が 1 であること | **1 / 1**（PASS） |
| **TC-02** | 置換で **JSON が壊れる**（末尾カンマ・括弧不整合） | 置換後文字列を `json.loads`。例外なら全体 `exit 1` | **valid JSON**（PASS） |
| **TC-03** | 置換したが**構造が意図どおりでない**（matcher が違う / 別ブロックに入った） | 置換後 doc に `matcher=="Bash"` かつ command に `check-plan-hash.sh` を含む hook が存在 | 適用前 **False** → 適用後 **True**（**陽性コントロールつき**） |
| **TC-04** | **dry-run で書き込みが起きる** | 変換前後で対象ファイルの **sha256 が不変**であること | **不変**（PASS） |
| **TC-05** | **冪等でない**（2 回目で重複ブロックが増える） | 既適用文字列に対し `has_bash_planhash` / `W_NEW in text` が真 → 置換をスキップし `exit 0` | **真**（PASS） |
| **TC-06** | **配線検査が新配線を見ていない**（AC-8。追加行を消しても CI が緑のまま） | 追加行入り `check-settings-wiring.sh` を **未適用の** settings に対して実行 | **rc=1** / `不足: EH-3b Bash route plan-hash(#1104)`（**陽性コントロール**） |
| **TC-07** | 追加行が**適用済み settings を誤って落とす**（偽陽性） | 追加行入り checker を **適用済み** settings に対して実行 | **rc=0 / PASS** |
| **TC-08** | 新配線が**既存 6 件の検査を壊す**（非回帰） | **無改変**の checker を適用済み settings に対して実行 | **rc=0 / PASS** |
| **TC-09**（ラッパ・未実走） | Step 1-2 未了のまま**配線だけ入る** | `check-plan-hash.sh` に marker `t1104-bash-route` が無ければ **書き込みゼロで `exit 1`** | 契約 |
| **TC-10**（ラッパ・未実走） | AI が実 HO パスへ `--apply` する | 適用先が `<repo>/.claude/` 配下かつ `PLANGATE_APPLY_CONFIRM != 1` なら **書き込みゼロで `exit 1`** | 契約 |
| **TC-11**（ラッパ・未実走） | 未知引数を**黙って無視**して既定動作で走る | `--dry-run` / `--apply` / `--target-root` 以外は `exit 1` | 契約 |
| **TC-12**（ラッパ・未実走） | 対象ファイル不在で**部分適用**する | 3 ファイルの存在確認を**全部**通してから書き込む | 契約 |

TC-06 の判定は `check-settings-wiring.sh` の `has()` に依存する。`has()` は `re.search(matcher_re, m)` なので、既存行 `("check-plan-hash.sh", "Edit|Write", ...)` は `re.search("Edit|Write", "Bash")` に一致せず、**新旧 2 行は互いに独立に成立する**（片方の配線が消えたら片方だけ FAIL する）。

---

## 5. 参照値: 検証済み unified diff

**適用は §4 の apply スクリプトが行う。** 以下は「スクリプトが生成すべき差分」の参照値であり、**`git apply --check` rc=0 を実測済み**。スクリプト実装後は `--dry-run` の出力がこの diff と一致することを回帰テストにできる。

> ⚠️ **単独適用しないこと**。この diff は Step 1-2（`check-plan-hash.sh` の Bash 分岐）が入った後にのみ意味を持つ。先に当てると「配線検査は緑・ガードは無効」になる。スクリプト経由なら前提検査（TC-09）がこれを止める。

````diff
diff --git a/.claude/settings.example.json b/.claude/settings.example.json
--- a/.claude/settings.example.json
+++ b/.claude/settings.example.json
@@ -45,6 +45,16 @@
         ]
       },
       {
+        "_comment_": "Hook EH-3b (#1104): Bash route HO / plan.md guard. Applies the same HO decision as EH-3 to write-intent Bash commands.",
+        "matcher": "Bash",
+        "hooks": [
+          {
+            "type": "command",
+            "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/hooks/check-plan-hash.sh ${PLANGATE_HOOK_TASK:-} ${PLANGATE_HOOK_FILE:-}"
+          }
+        ]
+      },
+      {
         "_comment_": "Hook EH-6 (Issue #169 セッション B): scope 外ファイル編集検知。子 PBI YAML の forbidden_files glob と編集対象 path を突合。PLANGATE_HOOK_FILE 環境変数で編集対象 path を明示する必要あり。default は warning、strict 時 block。未明示時は SKIP。",
         "matcher": "Edit|Write",
         "hooks": [
diff --git a/scripts/check-settings-wiring.sh b/scripts/check-settings-wiring.sh
--- a/scripts/check-settings-wiring.sh
+++ b/scripts/check-settings-wiring.sh
@@ -62,6 +62,7 @@
     ("check-c3-approval.sh", "Edit|Write", "EH-2 c3-approval"),
     ("check-forbidden-files.sh", "Edit|Write", "EH-6 forbidden-files"),
     ("check-plan-hash.sh", "Edit|Write", "EH-3 plan-hash"),
+    ("check-plan-hash.sh", "Bash", "EH-3b Bash route plan-hash(#1104)"),
     ("${PLANGATE_HOOK_FILE:-}", "Edit|Write", "EH-3 の PLANGATE_HOOK_FILE 引数(P4(d)/AC-8)"),
     ("check-delegation-commit-boundary.sh", "Bash", "EH-9 delegation-commit-boundary(TASK-0073)"),
 ]
````

### 5-1. 検証（rc 記録）

測定対象は本ブランチ `docs/1104-applicable-patch`（head = `origin/main` = `8cb9e82` からの分岐、対象ファイルは未変更）。

| 検証 | コマンド | rc | 意味 |
|---|---|---|---|
| 適用可能性 | `git apply --check 1104.patch` | **0** | 現 main に**そのまま当たる** |
| 逆当て | `git apply --check --reverse 1104.patch` | **1** | **まだ適用されていない**（既適用の diff を「当たる」と誤認していない） |
| **変異注入** | hunk header の旧行数を `@@ -45,6 +45,16 @@` → `@@ -45,7 +45,16 @@` に 1 ずらして `--check` | **128**（`error: corrupt patch at line 21`） | 検証が**実際に効いている**（rc=0 が恒真でない） |
| **round-trip** | 本書の ```` ```diff ```` ブロックから抽出 → 元 patch と byte 比較 → `--check` | byte 一致 **True**（1634 B）／ `--check` **0** ／ `--reverse` **1** | **文書に載っている diff がそのまま適用可能**（転記で壊れていない） |

**陰性コントロール**: `--reverse` が 1 を返す（= 適用済みではない）ことで、「もう入っているものを diff にしただけ」ではないことを示す。
**陽性コントロール**: 変異注入で 128 になることで、`--check` の 0 が意味を持つことを示す。

---

## 6. #1101 との関係と適用順序

### 6-1. 結論: **順序依存あり。`#1101` → `#1104`**

元設計書と同じ結論だが、**根拠が違う**。元設計書は性能（判断 3）を理由にしていたが、本書ではその測定を再現できなかった（§6-3）。代わりに**正確性**の依存を実測した。

### 6-2. 正確性の依存（本書で実測）

`scripts/hooks/check-plan-hash.sh` の HO 判定は `_norm_target` に対する `case` 照合で、**小文字化していない**。

- `_norm_target` は `./` 除去と `$REPO_ROOT/` 除去だけを行う（`_override=0` の直前）
- ファイル内で `tr 'A-Z' 'a-z'` を使う箇所は **1 か所のみ**で、それは `if [ -z "$task_id" ]` ブロック内の **plan.md 判定用**（`_tf_lc`）。**HO の `case` はこれを使っていない**
- 測定: `grep -n "tr " scripts/hooks/check-plan-hash.sh`（`origin/main`）→ 小文字化は 1 行のみ、位置は HO `case` より **後**

つまり **HO 判定は表記に敏感**で、これが #1101 の「表記の穴」にあたる。

本 issue（#1104）は **この同じ `case` ブロックに新しい入力（Bash コマンドから抽出したパス候補）を流し込む**設計である（元設計書 Step 2「HO 判定ロジック自体は変更しません」）。したがって:

| 順序 | 帰結 |
|---|---|
| **#1104 が先** | Bash 経路が**表記の穴を継承したまま出荷**される。しかも Edit/Write の `file_path`（ツールが与える 1 つのパス文字列）と違い、Bash コマンド文字列は表記の自由度が桁違いに大きい（引用・`./`・`//`・`$PWD/`・大小混在）。**「塞いだつもりで迂回可能なガード」を増やす**ことになり、#1104 の目的（観測できない穴の解消）に反する |
| **#1101 が先** | 正規化が**単一の合流点**（`_norm_target` 確定〜HO `case`）で直る。#1104 は追加作業なしにその恩恵を受ける |

**#1101 と #1104 は相補**（表記の穴 / 経路の穴）で片方では塞がらない、という元設計書の整理はそのまま成立する。**塞がる順序は #1101 → #1104 の一方向のみ。**

### 6-3. 性能（元設計書 判断 3）— 再現できず・未確定

元設計書は「現行の小文字化実装は 4,000 文字で 59 秒（案 A で 94ms へ改善見込み）」とし、これを順序の根拠にしていた。

本書の実測（現 main の該当実装 = `printf | sed 's/[[:space:]]*$//' | tr 'A-Z' 'a-z'`、入力 4,000 文字）:

```text
sh -c   0.01s user 0.01s system 55% cpu 0.030 total
```

**0.03 秒**。59 秒とは 3 桁違う。現 main のこのコードは外部プロセス 2 個で入力長にほぼ依存しないため、**59 秒は現 main の当該行を指していない**。#1101 で提案された別実装（純シェルの文字ループ等）の測定と推測されるが、**本書ではその実装を特定できていない → 未確定**（§7-U4）。

ただし**設計制約としては生きている**: #1104 は正規化の入力を「短いパス」から「任意長の Bash コマンド文字列」へ変える。よって

> **#1101 が入れる正規化は O(n) で安価であること。#1104 は Bash コマンド文字列**全体**を正規化に通さず、抽出した**パス候補だけ**を通すこと。**

を Step 2 の設計制約として明記する（元設計書 AC-7 の実装可能な形）。

### 6-4. 対象ファイルの重複 — **本タスクの前提を 1 点訂正**

本タスクの指示は「対象ファイルが重複しないことは確認済み（#1101 = `scripts/hooks/check-plan-hash.sh` / #1104 = `.claude/settings.example.json` ほか）」としていたが、**#1104 の Step 2 も `scripts/hooks/check-plan-hash.sh` を編集する**（元設計書 Step 2「`check-plan-hash.sh` に Bash 入力の分岐を追加します」）。

| 範囲 | `check-plan-hash.sh` の重複 |
|---|---|
| #1104 **Step 3（配線）のみ** = 本書が patch 化した範囲 | **重複しない**（読むだけ / marker 検査） |
| #1104 **Step 1-2 を含む全体** | **重複する** |

したがって §5 の diff は #1101 と衝突しないが、**Step 2 の実装は #1101 と同一ファイルを触る**。これも「#1101 を先に入れる」を支持する（後入れ側が rebase する側になる）。

---

## 7. 未確定として残したもの

**設計は作り直していない。** 以下は元設計書に記述が無い / Human 判断待ちのため、本書では確定させず patch にも含めなかった。

| ID | 未確定事項 | なぜ確定できないか | 誰が決めるか |
|---|---|---|---|
| **U1** | **判断 1**: パス抽出不能なコマンド（`eval` / `sh -c "$(...)"` / `python3 script.py`）を fail-open にするか fail-closed にするか | 元設計書は fail-open + 記録を**推奨**しているが確定していない。前例として EH-13 の fail-closed 化（#1079）が Edit/Write と Bash を全部止めた実害がある | **Human** |
| **U2** | **判断 2**: 正規経路（`bin/plangate plan` / `init` / `apply-*.sh --apply` / `sync-plugin-plangate.sh`）の許可方式（allowlist / 呼び出し元判定 / 専用 env） | 元設計書は「`PLANGATE_BYPASS_HOOK` の流用は避けるべき」とだけ述べ、方式を決めていない | **Human** |
| **U3** | Step 1 の**述語注入のシグネチャ**（コールバック関数名を引数で渡す / env で切替 / ライブラリを 2 度 source する） | 元設計書は `_redirect_writes_token` / `_is_token_path` に言及しておらず、一般化の形が書かれていない（§2） | 実装者（U1/U2 確定後） |
| **U4** | 元設計書の性能値「4,000 文字で 59 秒」がどの実装を指すか | 現 main の該当実装では 0.03 秒しか出ず、対応するコードを特定できなかった（§6-3） | #1101 の担当 |
| **U5** | `matcher: "Bash"` ブロックを `PreToolUse` 配列の**どの位置**に置くか | 元設計書に指定なし。本書は EH-3 の直後（読みやすさ優先）に置いたが、hook の**実行順序に意味がある**なら別位置が正しい可能性がある。JSON 構造上は位置非依存 | 実装者 |
| **U6** | EH-13（`check-approval-token-write.sh`）が `check-settings-wiring.sh` の `checks` に**そもそも登録されていない**（現状 6 件に含まれない） | #1104 の scope 外。ただし「配線検査の網羅性」という同じ問題系 | 別 issue 起票候補 |

---

## 8. 責務

| 作業 | 担当 | 本書での状態 |
|---|---|---|
| 設計・実測・patch 化 | **AI-owned** | 本書（Step 3 まで完了 / Step 1-2 は未確定を明示） |
| **判断 1・判断 2 の確定**（U1 / U2） | **Human** | **未着手 — これが Step 1-2 の blocker** |
| Step 1-2 の実装（判断確定後） | `PLANGATE_HOOK_TASK` セッションの AI が patch 作成 | 未着手 |
| `scripts/apply-1104-bash-route-wiring.sh` の作成 | AI-owned | **未作成**（本タスクは `scripts/` を編集しない） |
| `--apply` の実行（実 HO パスへの書き込み） | **Human-owned** | — |
| `sh scripts/apply-claude-settings.sh` による実 settings.json への伝播 | **Human-owned** | — |

### 次の 1 手

1. **Human が U1 / U2 を確定**する（これが無いと Step 1-2 は書けない）
2. #1101 をマージする（§6-1）
3. Step 1-2 を実装（marker `t1104-bash-route` を含めること = TC-09 の前提）
4. `scripts/apply-1104-bash-route-wiring.sh` を作成し `--dry-run` の出力が §5 の diff と一致することを確認
5. Human が `PLANGATE_APPLY_CONFIRM=1 ... --apply` → `sh scripts/apply-claude-settings.sh`

---

## 関連

- 元設計書: [`1104-bash-route-guard-patch.md`](./1104-bash-route-guard-patch.md)
- 実行計画: [`backlog-triage-2026-08-24.md`](./backlog-triage-2026-08-24.md)（Phase -1 / §1-7 の 2 択）
- 先行例（冪等 apply スクリプト）: `scripts/apply-ci-lint-wiring.sh`
- **#1101**（表記の穴。**先に入れる**）/ **#1104**（本 issue・経路の穴）/ **#1135**（AI-owned レーン。境界を固めてから）
- **#833**（Bash 迂回 3 件）/ **#1115**（EH-13 の glob 迂回。`_cmd_may_target_token` を追加した PR #1148）/ **#1110**（リダイレクト相関）/ **#1079**（EH-13 fail-closed 化の副作用 = 判断 1 の前例）/ **#1131**（配線検査）

Refs #1104 / #1092
