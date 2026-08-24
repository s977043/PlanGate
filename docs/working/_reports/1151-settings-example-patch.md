# #1151 `settings.example.json` の上流固有配線 是正設計（patch 設計書）

> **本書は patch 設計書であり、`.claude/settings.example.json` は本 PR で編集していない**（Hardening Override 対象 / 適用は Human-owned）。差分は本書内に提示する。
>
> - 起点: `origin/main` = `4bb3989`（`chore(deps): bump the github-actions group with 4 updates (#1201)`）
> - ブランチ: `docs/1151-settings-example-patch`
> - 対象 issue: #1151
> - 変更ファイル: 本ファイル 1 件のみ

---

## 0. 要約（結論先行）

| 論点 | 結論 |
|---|---|
| issue の症状は再現するか | **する**（§1 実測） |
| issue が推す **案 A**（example から SessionStart 配線を削除）は単独で適用できるか | **できない。** テスト 1 件が FAIL し、doc / コメント **11 箇所**が虚偽化する（§3。当初 6 箇所としていたが、列挙述語の不足を敵対レビュー M-1 が検出し是正） |
| 上流メンテナの現行環境は壊れるか | **壊れない。** `.claude/settings.json` は **gitignore 済み**（tracked は example のみ）で、merge は削除しない（§2-1） |
| 上流の **新規 clone** は壊れるか | **壊れる。** `settings.json` 不在時は example を丸ごと `cp` する分岐があり、account pin が二度と配線されない（§2-1） |
| CI は落ちるか | **落ちる。** `settings-drift`（`ci.yml`）は SessionStart を見ていないので通るが、**`test.yml` が `sh tests/run-tests.sh` を走らせ、そこで `ta-10` が落ちる**（§2-3 / §2-4） |
| AC-3（横展開）の結果 | **上流固有値を持つ配線は `gh-pin-account.sh` の 1 本のみ。** 残り 9 本は clean（§4） |
| **#975 との競合** | **競合する。** #975 AC-3（全 event merge の `--all-events` opt-in 化）は同じ症状に別経路で効く。**ただし #975 単独では #1151 を閉じない**（§5） |
| 推奨 | **案 A + 付随 11 箇所を 1 つの変更として同時適用**。#975 は独立に進めてよい（§6）。**ただしコストでは案 B が明確に安い**ことは §6-1 に明記した |
| Human 裁定 | **Q-1 = (a)**（新規 clone の自動配線は復活させず、doc の手動 opt-in 手順で代替）— 2026-08-24 取得（§6-2） |

**本書の範囲外**: `scripts/gh-pin-account.sh` 自体の削除（issue の Out of scope）。承認境界・HO 9 カテゴリ・merge の扱い。

---

## 1. 症状の実測（AC-1 の前段）

`scripts/gh-pin-account.sh:21` は既定値に上流メンテナのアカウントを埋めている。

```sh
DESIRED_USER=${PLANGATE_GH_USER:-s977043}
```

導入先（`s977043` が logged-in に居ない環境）を、既定値を差し替えて等価に再現した:

```console
$ sh scripts/gh-pin-account.sh                                   # 上流環境（既定値）
gh-pin-account: already pinned to s977043
rc=0

$ PLANGATE_GH_USER=not-a-real-user-xyz sh scripts/gh-pin-account.sh   # 導入先シミュレーション
gh-pin-account: not-a-real-user-xyz is not in `gh auth status` (run: gh auth login -u not-a-real-user-xyz)
rc=1
```

導入先では `DESIRED_USER` が `s977043` のままなので、**毎セッション `run: gh auth login -u s977043` — すなわち上流メンテナのアカウントでログインせよ、というメッセージが stderr へ出る**。issue の記述どおりで、過大評価も過小評価もない

> **未確定**: ここで測ったのは**スクリプトの stderr** であり、**harness が SessionStart hook の stderr を利用者に表示するか**は測っていない。AC-1 は「メッセージが出ない」で書かれているため、この 1 段は推論である（結論は変わらないと見込むが、実測ではない）（**ただし限定つき**: `s977043` が導入先の `gh auth status` に**存在しない場合に限り** `:43-46` で止まる。もし同名アカウントが logged-in なら `:47` の `gh auth switch` が実走し、**マシン全体の gh CLI active account が切り替わる**。`docs/ai/settings-wiring-contract.md:41` が警告しているのはこの経路であり、本書はその危険を打ち消すものではない）。

**配布経路の限定**（issue に無い補足）: `settings.example.json` は **plugin の配布対象ではない**。

```console
$ git ls-tree -r origin/main --name-only -- plugin/ | grep -i 'settings\|gh-pin'
(0 件)
# 陽性コントロール: plugin 配下の tracked 総数 = 173
```

したがって本症状に当たるのは **repo clone / `install.sh` / `staged-adoption-guide` 経由の導入先**であり、marketplace plugin 経由の導入先には届かない。

---

## 2. 案 A を当てたとき何が起きるか（全数）

### 2-1. `scripts/apply-claude-settings.sh` — **一部壊れる**

同スクリプトは自前の hook ブロックを持たず、**100% `settings.example.json` 駆動**である。

```sh
scripts/apply-claude-settings.sh:50   EX="$ROOT/.claude/settings.example.json"
scripts/apply-claude-settings.sh:64   if [ ! -f "$SJ" ]; then
scripts/apply-claude-settings.sh:65     printf '[apply] .claude/settings.json 不在 → settings.example.json をコピー\n'
scripts/apply-claude-settings.sh:66     [ "$DRY" -eq 1 ] || cp "$EX" "$SJ"
```

| 状況 | 案 A 適用後 |
|---|---|
| **既存 `settings.json` を持つ環境**（上流メンテナの現行環境） | **壊れない。** merge は「不足のみ取り込む・削除しない」。既に配線済みの SessionStart はそのまま残る |
| **`settings.json` 不在**（新規 clone / 新規導入者） | **壊れる。** L66 の丸ごと `cp` が SessionStart 抜きの example をコピーし、**account pin が配線されない** |

`bin/plangate doctor --fix`（`scripts/doctor_fix.py`）も同じく example を正本にしているため、結果は同じ。

**前提の確認**（tracked 状況を実測）:

```console
$ git ls-tree -r origin/main --name-only -- .claude/ | grep settings
.claude/settings.example.json
# 陽性コントロール: .claude/ 配下の tracked 総数 = 72

$ git show origin/main:.gitignore | grep -n settings
13:.claude/settings.local.json
14:.claude/settings.json
```

→ **上流メンテナの実配線は git の外**にあるため、案 A で即座に失われるものはない。失われるのは**将来の新規 clone における自動配線**である。

### 2-2. `bin/plangate doctor` — **壊れない**

T-7 は example を期待値の正本にして差集合を取る（`bin/plangate:559` `missing = expected - present`）。example から 1 ブロック減れば `expected` が減るだけで、FAIL 方向へは倒れない。表示が `11/11` → `10/10` に変わる。

**この数値を assert するテストは無い**:

```console
$ git grep -n 'hooks wired\|hook block' origin/main -- tests/
(0 件 / rc=1 ＝ 起動して 0 件)
# 陽性コントロール: 同じ述語が bin/plangate:567 等をヒットすることを確認済み
```

### 2-3. CI（`settings-drift`）— **落ちない**

```yaml
.github/workflows/ci.yml:17   settings-drift:
.github/workflows/ci.yml:27     run: sh scripts/check-settings-wiring.sh --target example
```

`scripts/check-settings-wiring.sh:60-67` の `checks` リストは **PreToolUse 6 項目のみ**で、SessionStart を 1 件も見ていない。

```python
checks = [
    ("check-plan-exists.sh", "Edit|Write", "EH-1 plan-exists"),
    ("check-c3-approval.sh", "Edit|Write", "EH-2 c3-approval"),
    ("check-forbidden-files.sh", "Edit|Write", "EH-6 forbidden-files"),
    ("check-plan-hash.sh", "Edit|Write", "EH-3 plan-hash"),
    ("${PLANGATE_HOOK_FILE:-}", "Edit|Write", "EH-3 の PLANGATE_HOOK_FILE 引数(P4(d)/AC-8)"),
    ("check-delegation-commit-boundary.sh", "Bash", "EH-9 delegation-commit-boundary(TASK-0073)"),
]
```

`.github/workflows/` は全 10 本を列挙して確認した。settings 関連ジョブは `ci.yml` の `settings-drift` のみ。

> **注意**: これは「CI が緑だから安全」を意味しない。**CI は SessionStart を測っていないので、この drift クラスに対して無力である**という事実の記録である。

### 2-4. テスト — **1 件 FAIL**

```python
tests/extras/ta-10-doctor-fix.sh:119
assert any("gh-pin-account.sh" in c for c in flat), "example SessionStart hook not merged"
```

同ファイルは実リポの example をそのまま sandbox へコピーして使う（`:12` / `:19`）ため、案 A が直撃する。**このテストは必ず落ちる。**

`tests/extras/ta-23-gh-account-pin.sh` は **落ちない**（example を一切参照せず、参照先は `scripts/gh-s977043.sh` と `docs/ai/github-account-pinning.md`）。ただし §3 の doc 修正で `gh-pin-account` の**語そのもの**を消すと `ta-23:43` の TC-04 が落ちる — **語は残したまま意味を書き換える**こと。

### 2-5. 導入先向け導線 — **修正不要**

`README.md:200` / `docs/staged-adoption-guide.md:99` はいずれも `settings.example.json` を merge 元として言及するのみで、**SessionStart / gh-pin-account を名指ししていない**。`TROUBLESHOOTING.md` も同様。

---

## 3. 案 A に必須で随伴する変更（これを欠くと虚偽記述が残る）

> **⚠️ 列挙述語について（敵対レビュー M-1 で是正）**: 当初この節は `git grep 'SessionStart'` **1 本だけ**で母集団を作っていた。しかし **`gh-pin-account` を参照しているが `SessionStart` の語を含まない**記述が存在し、構造的に取りこぼしていた。**2 述語の和集合で数え直した結果が下表**である。

```console
$ git grep -l 'SessionStart' origin/main | wc -l
71
$ git grep -l 'SessionStart' origin/main | grep -v 'docs/working/' | wc -l
11
# SessionStart 側に入らない gh-pin-account 参照（差集合）
$ comm -23 <(git grep -l 'gh-pin-account' origin/main | sed 's|^origin/main:||' | grep -v '^docs/working/' | sort) \
           <(git grep -l 'SessionStart'   origin/main | sed 's|^origin/main:||' | grep -v '^docs/working/' | sort)
scripts/apply-eh-git-destructive-guard.sh
scripts/check-git-destructive.sh
scripts/gh-pin-account.sh
```

→ 生きた成果物は **`SessionStart` 側 11 + `gh-pin-account` 固有 3 = 13 ファイル**（`gh-pin-account.sh` 自体は Out of scope なので是正対象は 12）。

```console
$ git grep -l 'SessionStart' origin/main | wc -l
71
$ git grep -l 'SessionStart' origin/main | grep -v 'docs/working/' | wc -l
11
```

**うち 3 ファイルは是正対象外**: `CHANGELOG.md` / `docs/changelog.md` は**過去リリースの記録**であり、後から書き換えない。`tests/extras/ta-23-gh-account-pin.sh` は §2-4 のとおり落ちない。

| # | 対象 | 層 | 案 A 適用時の扱い |
|---|---|---|---|
| 0 | `.claude/settings.example.json:5-15` | **L3 / HO** | **削除**（§4 の diff） |
| 1 | `tests/extras/ta-10-doctor-fix.sh:119` | **L2**（`.sh`） | assert を削除、または PreToolUse hook の assert へ差し替え。`:109` の「既存 SessionStart hook を温存する」fixture は**残す**（温存検証としては有効） |
| 2 | `docs/ai/hook-enforcement.md:110, 433` | L1 | hook 一覧表の SessionStart 行 / 「SessionStart（gh-pin-account）が有効化される」の記述を是正 |
| 3 | `docs/ai/settings-wiring-contract.md:37-46, 329` | L1 | parity 表 #9 の行（`:329`）、および「契約外 hook の代表例」として `gh-pin-account` を挙げる ⚠️ 注記（`:37-46`）。**例が消えると注記全体の根拠が消える**ため、注記の書き換えまで含めること。**`:381` は是正対象外** — 「なぜ達成済のまま気づかれなかったか」の**過去の構造原因の記述**であり、案 A 後も事実として正しい |
| 4 | `docs/ai/github-account-pinning.md:21, 24, 59` | L1 | 責務整理表の左列が成立しなくなる。**`gh-pin-account` の語と `## 責務整理` の見出しの両方を残し**（`ta-23:42-43` は `grep -qE '^## 責務整理'` と `grep -q 'gh-pin-account'` の **AND 条件**）、「SessionStart への example 登録は廃止。手動 opt-in」へ書き換え |
| 5 | `scripts/apply-claude-settings.sh:20, 27-32` | **L2** | 「全 hook event が対象」「例: SessionStart の gh-pin-account」のコメントが stale 化 |
| 6 | `scripts/gh-s977043.sh:9, 13` | **L2** | 「SessionStart hook が session 開始時に…」という責務分担の説明が宙に浮く |
| 7 | `docs/ai/repo-guard.md:19` | L1 | SessionStart 時の pin という記述 |
| **8** | **`docs/ai/hook-enforcement.md:94-96`** | L1 | **M-1 で追加。** 「`.claude/settings.json` に配線済みの hook は **11 件**」+「tracked な `settings.example.json` も**同一の matcher 集合**（実測一致）」。案 A 後、**(a) 件数 11 が誤りになり (b) 上流の `settings.json` は SessionStart を保持する（merge は削除しない＝§2-1）のに example は失うので「同一の matcher 集合」が literally false になる**。**本表で最も重い** |
| **9** | **`docs/ai/hook-enforcement.md:306`** | L1 | **M-1 で追加。** 「`scripts/` 直下から settings が直参照する方式」の現在形の例として `gh-pin-account.sh` を挙げている |
| **10** | **`scripts/apply-eh-git-destructive-guard.sh:14`** | **L2** | **M-1 で追加。** 「同方式の先例」として現在形で参照。`SessionStart` の語を含まないため当初表から漏れていた |
| **11** | **`scripts/check-git-destructive.sh:40`** | **L2** | **M-1 で追加。** 同上 |

**層の定義**: L1 = `.md` のみ（`PLANGATE_HOOK_TASK` 不要）/ L2 = `.py` / `.sh`（`PLANGATE_HOOK_TASK` セッションが要る）/ L3 = HO 対象パス（AI は patch 提示まで・適用は Human）。

> **順序の制約**: docs（L1）を先に単独で入れてはならない。example が現状のままなのに doc が「配線されていない」と述べる、**逆向きの虚偽**が生まれる。**0〜11 は 1 つの変更として同時に入れる。**

---

## 4. 差分（案 A・L3 部分）

```diff
--- a/.claude/settings.example.json
+++ b/.claude/settings.example.json
@@ -2,15 +2,4 @@
   "_comment_": "PlanGate hooks 設定例 — opt-in",
   "_usage_": "本ファイルは example。実 .claude/settings.json にコピーして適用する。",
   "hooks": {
-    "SessionStart": [
-      {
-        "_comment_": "Issue #171: gh CLI active account を s977043 に固定（plangate 用）。PLANGATE_GH_USER で他 user に override 可能。失敗しても session は継続（exit code は無視される）。",
-        "hooks": [
-          {
-            "type": "command",
-            "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/gh-pin-account.sh"
-          }
-        ]
-      }
-    ],
     "PreToolUse": [
```

適用後の `hooks` の event は `PreToolUse` / `PostToolUse` / `Stop` の 3 つ、ブロック数は 11 → **10**。

> **hunk header の検算**: 旧 15 行（context 3 + 削除 11 + context 1）/ 新 4 行。`git apply --check` が通ることを確認してから適用すること（当初 `@@ -2,17 +2,6 @@` と書いており `corrupt patch` で止まった。敵対レビュー M-3 で検出・是正済み）。

### AC-3（横展開）: 残り 9 配線の全数確認

`settings.example.json` が配線する **10 スクリプト全数**を、上流固有値の有無で走査した。

| 走査 | 結果 |
|---|---|
| 10 本の存在確認（`git cat-file -e origin/main:<path>`） | **10/10 OK** |
| `s977043｜masatake｜kominem｜proni` のヒット | **`scripts/gh-pin-account.sh` の 3 行のみ**（`:2` コメント / `:9` Usage / `:21` 既定値） |
| 陽性コントロール（同じ述語で `PLANGATE` を数える） | 10 本すべてに 2〜17 件ヒット ＝ **grep は 10 本すべてで起動している** |

→ **雛形の性質としては、上流固有の前提を持つのは `gh-pin-account.sh` の 1 本だけ**である。他 9 本には上流アカウント名が 1 件も無い。**「`PLANGATE_*` と `${CLAUDE_PROJECT_DIR}` のみに依存する」とまでは本走査から言えない**（走らせたのは上流名 grep と `PLANGATE` の陽性コントロールの 2 述語のみで、依存集合の排他性は測っていない）。主張は「**上流アカウント名を持つのは 1/10**」に留める。

---

## 5. #975 との関係（**issue には書かれていない競合**）

`scripts/apply-claude-settings.sh:24-32` と `docs/ai/settings-wiring-contract.md:44-45` は、**同じ問題に対する別案を既に follow-up として宣言している**。

```sh
scripts/apply-claude-settings.sh:24-32
# ⚠️ 適用範囲と副作用（敵対レビュー F3 / 契約範囲外の自動配線）:
#   本スクリプトは example の **全 hook event** を取り込む。一方
#   `check-settings-wiring.sh` が検証するのは **PreToolUse の 6 項目のみ**で
#   あり、それ以外（SessionStart / PostToolUse / Stop）は**契約外**である。
#   ...（`--all-events` opt-in 化は follow-up）
```

これは **#975 AC-3**（「全 event 取り込みが opt-in になり、既定では契約対象 event のみが merge される」）である。

### 判定: **#975 は #1151 を閉じない**

| 経路 | #975 AC-3 で塞がるか |
|---|---|
| `apply-claude-settings.sh` の **merge** 経路 | **塞がる**（既定が PreToolUse 6 項目に限定されるため） |
| `apply-claude-settings.sh:66` の **丸ごと `cp`** 経路（`settings.json` 不在時） | **塞がらない**。cp は event を選ばない |
| `_usage_` が案内する **手動コピー** 経路（「実 .claude/settings.json にコピーして適用する」） | **塞がらない**。ツールを経由しない |

→ **雛形そのものに上流固有値が載っている限り、ツール側の opt-in 化では 3 経路のうち 2 経路が残る。** #1151 と #975 は排他ではなく、**#1151 が雛形の性質を直し、#975 がツールの責務過剰を直す**という分担になる。

---

## 6. 推奨と、判断が要る点

### 6-1. 推奨: **案 A + §3 の 1〜6 を 1 変更として同時適用**

案 B（`DESIRED_USER` 既定を空にして未設定なら no-op）を採らない理由:

- 導入先には「配線されているが何もしないスクリプト」が残る。これは **#1078 が実測で問題化した「登録 ≠ 強制力 / 置いてあるのに効かない」と同型**である
- **#1144 の packaging 設計は既に `gh-pin-account.sh` を「配布不可」と確定済み**（`docs/working/_reports/1144-plugin-packaging-patch.md` §1-2 の #11）。案 A はこの前例と一貫する
- （**撤回**）当初「案 B も `PLANGATE_HOOK_TASK` セッションが要るので層のコストは案 A と大差ない」と書いたが、**これは誤り**。`scripts/gh-pin-account.sh` は **HO 9 カテゴリ外**（`check-plan-hash.sh` の `case` ブロックにあるのは `scripts/hooks/*.sh` で、`scripts/*.sh` は無い）であり、**案 B は非 HO の 1 ファイルで済む**。対して案 A は **HO 1（L3・Human 適用必須）+ `.sh` 3 + `.md` 4〜5**。しかも案 B なら `ta-10` も落ちず §3 の doc 是正も発生しない。**コストでは案 B が明確に安い。** 案 A を推すのは上 2 つの根拠（「置いてあるのに効かない」を作らない / #1144 の前例）のみに拠る

案 C（コメントで「上流専用」と明記）は issue 本文の指摘どおり**強制力を持たない**ため採らない。

### 6-2. Human 裁定（2026-08-24 取得済み）

| # | 問い | **裁定** |
|---|---|---|
| **Q-1** | 上流の新規 clone で account pin をどう配線するか（§2-1 で失われる自動配線の代替） | **(a) `docs/ai/github-account-pinning.md` に手動 opt-in 手順を書くだけにする。** 追加コードなし。§3 の #4 の書き換えに手順を含める |

→ **AC-2 の解釈は Q-1 の裁定で確定した**: 自動配線の喪失は受容し、doc の手動手順で代替する。したがって **AC-2 は「上流メンテナの手元環境が壊れない」で判定してよい**（§7）。

### 6-3. 適用手順（Human-owned）

1. **Q-1 / Q-2 を確定**する
2. `PLANGATE_HOOK_TASK=TASK-1151` を設定した**新規セッション**を起動する（L2 の `.sh` 3 本を書くために必要。実行中の `export` では効かない）
3. §4 の diff を `.claude/settings.example.json` へ**人間が適用**する（HO のため AI は不可）
4. §3 の 1〜11 を同一 commit / 同一 PR に含める（**#8 の `hook-enforcement.md:94-96` を落とさないこと** — 件数「11 件」と「同一の matcher 集合」の両方が false になる）
5. 検証:
   ```sh
   git apply --check <§4 の diff>          # corrupt patch で止まらないこと（M-3）
   sh scripts/check-settings-wiring.sh --target example ; echo "rc=$?"   # 期待 0
   sh tests/run-tests.sh                                                 # baseline 差分で新規 FAIL 0 を確認
   ```

   **`ci.yml` の `settings-drift` が緑でも足りない。** `test.yml` の `sh tests/run-tests.sh` が本変更の実質的な CI ゲートである（§2-3 / M-2）。
   **`tests/run-tests.sh` の FAIL 件数を `grep -c '\[FAIL\]'` で数えないこと** — PASS メッセージ本文にブラケット付き `[FAIL]` を含む行が実在するため過大カウントになる。行頭アンカーで数える。

   > 一次証跡（敵対レビューがこの注意書きを「根拠が再現しない」と指摘したため確定させた）:
   > ```console
   > $ git show origin/main:tests/extras/ta-61-extra-contract.sh | sed -n '322p'
   >         t61_pass "TC-12(a)/TC-13: $_t61_id clean standalone run rc=0 with no [FAIL]"
   > ```
   > **PASS は `t61_pass` ヘルパ経由で出力されるため、`grep '\[PASS\].*FAIL'` のようなソース走査では見えない。** 実行時出力では `[PASS] ... with no [FAIL]` の 1 行として現れ、`grep -c '\[FAIL\]'` に数えられる。指摘は棄却する
6. **baseline は着手時の `origin/main` で再測定する。絶対件数を契約値にしない**

---

## 7. 受入基準との対応

| AC | 状態 | 根拠 |
|---|---|---|
| **AC-1**（クリーンな別リポジトリで gh-pin-account 由来のメッセージが出ない） | **未達（適用待ち）** | §1 で症状の再現までは完了。適用は Human-owned |
| **AC-2**（上流の account pin 運用が従来どおり動く） | **達成見込み（解釈確定済み）** | 既存環境は §2-1 で不変。**新規 clone の自動配線は失われるが、Human 裁定 Q-1 = (a) によりこれは受容され、doc の手動 opt-in 手順で代替する**（§6-2） |
| **AC-3**（雛形の他の配線にも上流固有の前提が無いか全数確認） | **達成** | §4 の全数走査（10/10 に対し陽性コントロールつき）。上流アカウント名を持つのは **1/10** のみ |
| **AC-4**（`sh tests/run-tests.sh` に新規 FAIL がない） | **未達（適用待ち）** | §2-4 のとおり `ta-10:119` が必ず落ちるため、§3 の #1 を同時に入れることが AC-4 の前提。**この経路が `test.yml` の CI ゲートでもある**（M-2） |

---

## 9. 敵対レビューの disposition

本書は PR 作成前に独立の敵対レビューを 1 本通した。指摘とその扱いは以下。

| 指摘 | 重大度 | 扱い | 反映先 |
|---|---|---|---|
| M-1 列挙述語が `SessionStart` 1 本で、`gh-pin-account` 固有の 4 箇所を取りこぼし | major | **採用**（オーガナイザーが差集合で再現） | §3 表 #8〜#11 / §0 |
| M-2 §0「CI は落ちない」が `test.yml` 経路を落としている | major | **採用**（`test.yml:28` を照合） | §0 / §6-3 |
| M-3 §4 の diff が corrupt patch（hunk header 不整合） | major | **採用**（行数を検算） | §4 |
| M-4 「案 B も層のコストは案 A と大差ない」が誤り（`scripts/*.sh` は HO 外） | major | **採用**（HO `case` ブロックを再読） | §6-1 |
| m-1 §8 の「79 ファイル」が §3 の 71 と矛盾 | minor | 採用 | §8 |
| m-2 `apply-claude-settings.sh` の行アンカーが 26 起点（実際は 24） | minor | 採用 | §5 |
| m-3 `ta-23` TC-04 は `## 責務整理` 見出しとの AND 条件 | minor | 採用 | §3 #4 |
| m-5 「乗っ取りは起きない」が無条件断定 | minor | 採用 | §1 |
| m-6 「他 9 本は PLANGATE_* と CLAUDE_PROJECT_DIR のみに依存」は走らせた述語から出ない | minor | 採用 | §4 |
| i-1 stderr が利用者に表示されるかは未測定 | info | 採用 | §1 |
| **m-4** `grep -c '[FAIL]'` の注意書きの根拠が再現しない | minor | **棄却** | §6-3 に一次証跡を追記。`ta-61:322` が `t61_pass "... rc=0 with no [FAIL]"` を出力する。レビュアーの述語がソース上の `[PASS]` リテラルを探したためヘルパ経由の出力を見落としたもの |

---

## 8. 検証コマンドと exit code（本書作成時に実行したもの）

| コマンド | rc | 用途 |
|---|---|---|
| `sh scripts/gh-pin-account.sh` | 0 | 上流環境の挙動 |
| `PLANGATE_GH_USER=not-a-real-user-xyz sh scripts/gh-pin-account.sh` | 1 | 導入先の症状再現 |
| `git ls-tree -r origin/main --name-only -- plugin/ \| grep -i 'settings\|gh-pin'` | 1（0 件） | plugin 非配布の確認（陽性コントロール: plugin 配下 173 件） |
| `git ls-tree -r origin/main --name-only -- .claude/ \| grep settings` | 0 | tracked は example のみ（陽性コントロール: `.claude/` 配下 72 件） |
| `git grep -n 'SessionStart' origin/main` | 0（165 行 / 71 ファイル） | 依存の列挙（**単独では不十分** — §3 の注記参照） |
| `git grep -n 'gh-pin-account' origin/main` | 0 | **同上。`SessionStart` の語を含まない参照を拾うために必須** |
| `git grep -n 'hooks wired\|hook block' origin/main -- tests/` | 1（0 件） | ブロック数を assert するテストが無いことの確認 |
| 10 本の存在確認 + 上流固有値走査 + `PLANGATE` 陽性コントロール | 0 | AC-3 |

**測定はすべて `git show origin/main:` / `git ls-tree -r origin/main` / `git grep <pat> origin/main` で ref を明示した**（共有 checkout の作業ツリーは他セッションが別ブランチに置くため、`ls` / `grep -r` は実測として使っていない）。
