# #937 patch — `check-branch-not-merged.sh` が誰にも呼ばれていない（**Human 適用**）／ #942 は**前提の再検討が必要**

> 対象: `scripts/templates/pre-push.sample`
> **AI は `.sh` / hook テンプレートを編集できない**（EH-3 の no-task 経路が `SKIP_REASON` を要求）ため、差分と適用手順を文書として提示する。
> 測定基点: `origin/main` = `1e33b57` / 2026-08-18

---

# 第 1 部: #937 — 未配線ガード

## 問題

`scripts/check-branch-not-merged.sh` は**実在します**が、**誰も呼んでいません**。

```
$ grep -rln 'check-branch-not-merged' --include='*.sh' --include='*.yml' --include='*.md' .
AGENT_LEARNINGS.md                      ← 言及のみ
scripts/check-branch-not-merged.sh      ← 自分自身
```

**呼び出し元ゼロ**です。これは #1092 の Phase 2 が「**検査は書いたが誰も呼んでいない**」と分類した典型例です。

## このガードが防ぐもの

```sh
# check-branch-not-merged.sh の宣言
# 「マージ削除済ブランチを push で誤再作成」を防ぐ。
# 現ブランチ名に対応する PR が既に MERGED かつ remote ブランチが削除済みの場合に
# 警告して非ゼロ終了する。push 直前に実行（pre-push hook or 手動）。
```

**「push 直前に実行（pre-push hook or 手動）」と自分で宣言しているのに、pre-push hook に配線されていません。**

`scripts/templates/pre-push.sample`（95 行）は protected branch への直接 push を block しますが、**マージ済みブランチの再作成は素通り**します。

## 差分

`scripts/templates/pre-push.sample` の **stdin ループより前**に呼び出しを追加します。

```diff
 set -eu
 
 # 既定 protected list (AC-1 と AC-3 で統一)
 DEFAULT_PROTECTED="main master release/*"
 PROTECTED_BRANCHES="${PLANGATE_PROTECTED_BRANCHES:-$DEFAULT_PROTECTED}"
 
+# マージ削除済ブランチの誤再作成ガード（#937 / 振り返り #2 2026-06-16）。
+# scripts/check-branch-not-merged.sh は「push 直前に実行」を前提に書かれているが
+# 配線されていなかった。gh 未導入や remote 存在時は同スクリプト側で skip される。
+#
+# 注: リポジトリルートの解決は hook の実行位置に依存しないよう git に問い合わせる。
+#     スクリプト不在（導入先が PlanGate 本体でない等）は skip し、hook 自体は壊さない。
+_pg_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
+_pg_bng="${_pg_root:+$_pg_root/scripts/check-branch-not-merged.sh}"
+if [ -n "$_pg_bng" ] && [ -f "$_pg_bng" ]; then
+  if ! sh "$_pg_bng"; then
+    printf '[pre-push] BLOCK: マージ削除済ブランチの再作成が疑われます（#937）。\n' >&2
+    printf '           意図した push なら --no-verify で bypass できます。\n' >&2
+    exit 1
+  fi
+fi
+
 # noglob 適用 (Gemini bot R-001: ...)
 set -f
```

### 設計判断 3 点（**適用前にご確認ください**）

**1. stdin ループより前に置く**

`check-branch-not-merged.sh` は **stdin を読みません**が、pre-push の stdin は 1 回しか読めません。**ループの外（前）**に置けば相互作用がありません。

**2. スクリプト不在なら skip する**

`pre-push.sample` は**導入先へ配布される**テンプレートです。導入先に `scripts/check-branch-not-merged.sh` が無い場合に **hook 全体が壊れてはいけない**ため、`[ -f ]` で存在確認してから呼びます。

**3. `set -f`（noglob）より前に置く**

`set -f` は既存コードのグロブ暴発対策です。**その前に呼ぶ**ことで、追加分が既存の設計意図に干渉しません。

> ⚠️ **`set -eu` 下では `if ! sh ...` の形が必要**です。`sh "$_pg_bng"` を裸で書くと非ゼロ終了で即 abort し、**メッセージが出ないまま push が失敗**します。

## 適用手順

```sh
# 1. 上記 diff を適用

# 2. 構文チェック
sh -n scripts/templates/pre-push.sample && echo "syntax OK"
bash -n scripts/templates/pre-push.sample && echo "bash syntax OK"

# 3. 正常系（既存挙動が壊れていないこと）
#    a) 通常の feature ブランチから push → 通ること
#    b) main へ直接 push → 従来どおり block されること

# 4. 追加ガードの検出力（**必須**）
#    マージ済みで remote 削除済みのブランチ名を再作成して push を試みる
#    期待: [pre-push] BLOCK: マージ削除済ブランチの再作成が疑われます

# 5. skip 経路
#    gh 未導入環境 → スクリプト側が skip（hook は通る）
#    scripts/check-branch-not-merged.sh 不在 → 追加分を skip（hook は通る）

# 6. 実際に install して確認（opt-in）
sh scripts/install-pre-push.sh --dry-run
```

### ⚠️ 手順 4 を省略しないでください

**「配線した」ことと「発火する」ことは別**です。本セッションでは **`--dry-run` が該当経路を通らないために気づかれなかった欠陥**（#990 の `bin/plangate gate` クラッシュ）を実測しています。**配線したら発火を実測**してください。

---

# 第 2 部: #942 — **前提の再検討を提案します**

## issue の記載

> `test.yml:23` の checkout に `fetch-depth` 指定なし

**実測でも `fetch-depth` は指定されていません**（`.github/workflows/test.yml:23-25` は `persist-credentials: false` のみ）。

## しかし「必要である」根拠が見つかりませんでした

`test.yml` 内に **git 履歴を必要とする処理がありません**:

```
$ grep -nE 'git (log|rev-list|merge-base|describe|diff .*\.\.)' .github/workflows/test.yml
（0 件）
```

テストスイート側で履歴に触れるのは以下ですが、**いずれも shallow clone を前提として設計されています**:

| 箇所 | 扱い |
|---|---|
| `ta-28-plugin-version.sh:77` | 「tag 不在環境（**shallow clone 等**）では検証不能のため**スキップ**」 |
| `ta-28-plugin-version.sh:108` | **TC-09: tag 不在（shallow clone 相当）で WARN + exit 0**（#476 / 運用の穴を固定） |
| `ta-58` / `ta-25` の `git log` | **hook のプローブ用文字列**（実際に履歴を辿らない） |

**`ta-28` は shallow clone を明示的に許容する TC を持っています。** つまり **現状の設計は「浅い clone でも通る」ことを意図しています**。

## 提案

**patch を書く前に、#942 の目的を確認してください。**

| 想定される目的 | 妥当性 |
|---|---|
| (a) 現在落ちているテストを直す | ❌ **該当なし**（CI は緑） |
| (b) 将来 `git log` 等を使うテストに備える | △ **投機的**。必要になった時点で追加すれば足りる |
| (c) `ta-28` の TC-09（shallow 相当で WARN）が**本来は tag を見て検証すべき** | ⭕ **これなら意味がある**。ただし**修正対象は `test.yml` ではなく `ta-28` の設計判断** |

**(c) が意図なら、`fetch-depth: 0` の追加だけでは不十分**です。`ta-28` TC-09 が「tag 不在で WARN + exit 0」を**意図的に固定している**ため、fetch-depth を足しても **TC-09 は依然 skip 側を通ります**。

## 追加の注意

`.github/workflows/*` は **Hardening Override 対象パス**です。**`fetch-depth` の追加自体が Human 適用**を要します。**目的が (b) の投機的追加なら、HO 適用コストに見合いません。**

→ **#942 は「前提の再確認」を先に行い、目的が (c) なら scope を `ta-28` 側へ移す**ことを提案します。

---

## 責務

| 作業 | 担当 |
|---|---|
| #937 patch の作成・未配線の実測・検証手順 | **AI-owned**（本書） |
| **`scripts/templates/pre-push.sample` への適用** | **Human-owned** |
| **手順 4（発火の実測）** | 適用者・**省略不可** |
| **#942 の目的確認と scope 判断** | **Human** |

Refs #937 / #942 / #1092
