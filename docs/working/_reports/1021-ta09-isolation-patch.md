# #1021 patch — `ta-09-metrics.sh` が実監査ログを汚染し、standalone で root を誤解決（**Human 適用**）

> 対象: `tests/extras/ta-09-metrics.sh`
> **AI は `.sh` を編集できない**（EH-3 の no-task 経路が `SKIP_REASON` を要求）ため、差分と適用手順を文書として提示する。
> 測定基点: `origin/main` = `1e33b57` / 2026-08-18

## 欠陥 2 件（**どちらも実測で確認**）

### 欠陥 1: **実監査ログに偽レコードが残置される**（実害あり）

```sh
# fixture 作成側
if [ -f "$METRICS_AUDIT_LOG" ]; then
  METRICS_AUDIT_BACKUP="$METRICS_AUDIT_LOG.bak.$$"
  mv "$METRICS_AUDIT_LOG" "$METRICS_AUDIT_BACKUP"
fi
mkdir -p "$(dirname "$METRICS_AUDIT_LOG")"
cat > "$METRICS_AUDIT_LOG" <<HOOKLOG     ← 偽レコードを書き込む
...

# cleanup 側
if [ -n "$METRICS_AUDIT_BACKUP" ] && [ -f "$METRICS_AUDIT_BACKUP" ]; then
  mv "$METRICS_AUDIT_BACKUP" "$METRICS_AUDIT_LOG"     ← backup があるときだけ復元
fi
```

**既存ログが無かった場合、`METRICS_AUDIT_BACKUP` は空のままなので、テストが作った偽ログが削除されません。**

#### 実害（現 main で実測）

```
$ wc -l docs/working/_audit/hook-events.log
29037

$ grep -c 'TASK-9991' docs/working/_audit/hook-events.log
4                      ← テストが注入した偽レコードが残置されている
```

`TASK-9991` は **`ta-09` の fixture 専用の TASK 名**です。**実在しない TASK の VIOLATION / WARNING 記録が、append-only の監査証跡に紛れ込んでいます。**

> `.gitignore:21` で ignore されているため **git 汚染には至りません**が、**`docs/working/_audit/` は「append-only 監査証跡」**（`working-context.md` の管理ディレクトリ定義）であり、**偽レコードは監査の信頼性を損ないます**。

### 欠陥 2: standalone 実行で repo root を誤解決

```sh
METRICS_REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
```

`$0` は**実行方法によって変わります**（実測）:

| 実行方法 | `$0` | 解決される root | 判定 |
|---|---|---|---|
| harness から source | `tests/run-tests.sh` | `<repo>` | ✅ **偶然正しい** |
| `sh tests/extras/ta-09-metrics.sh` | `tests/extras/ta-09-metrics.sh` | **`<repo>/tests`** | ❌ **誤り** |

**harness 経由では偶然正しく解決されるため、この欠陥は普段見えません。** standalone 実行時のみ `<repo>/tests/docs/working/...` を対象にしてしまいます。

> **#1044 / #921 の「extras bootstrap の helper 欠落経路」と同クラス**です。本セッションでは `ta-42` が **standalone で `rc=127`** になる同型の欠陥も実測しています。

---

## 差分

### (1) root 解決を `git` へ委ねる

```diff
 METRICS_TASK_NAME="TASK-9991"
-METRICS_REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
+# $0 は実行方法で変わる（harness から source: tests/run-tests.sh / standalone:
+# tests/extras/ta-09-metrics.sh）。後者では <repo>/tests に誤解決するため、
+# harness が与える環境変数 → git → $0 の順に fallback する（#1021）。
+if [ -n "${PG_REPO_ROOT:-}" ]; then
+  METRICS_REPO_ROOT="$PG_REPO_ROOT"
+elif METRICS_REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" && [ -n "$METRICS_REPO_ROOT" ]; then
+  :
+else
+  METRICS_REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
+fi
```

> **`PG_REPO_ROOT` を最優先にするのは、harness が既に root を確定しているためです。** 変数名は既存の harness 実装に合わせてください（`tests/run-tests.sh` / `_extra-contract.sh` が公開している変数を確認すること）。**存在しなければこの分岐を落とし、`git` → `$0` の 2 段で構いません。**

### (2) fixture を作った場合は必ず消す

```diff
 METRICS_AUDIT_BACKUP=""
+# fixture を新規作成したか（既存ログが無かったか）を記録する。
+# backup の有無だけで判定すると、新規作成した偽ログが残置される（#1021）。
+METRICS_AUDIT_CREATED=""
 
 cleanup_metrics() {
   # TA-09 完了後（復元済み）に EXIT trap から再実行された場合は no-op
   [ -n "${METRICS_CLEANUP_DONE:-}" ] && return 0
   rm -rf "$METRICS_TASK_DIR"
   rm -f "$METRICS_LOG"
   if [ -n "$METRICS_AUDIT_BACKUP" ] && [ -f "$METRICS_AUDIT_BACKUP" ]; then
     mv "$METRICS_AUDIT_BACKUP" "$METRICS_AUDIT_LOG"
+  elif [ -n "$METRICS_AUDIT_CREATED" ]; then
+    # 既存ログが無かった＝本テストが作った fixture なので削除する
+    rm -f "$METRICS_AUDIT_LOG"
   fi
 }
```

```diff
 if [ -f "$METRICS_AUDIT_LOG" ]; then
   METRICS_AUDIT_BACKUP="$METRICS_AUDIT_LOG.bak.$$"
   mv "$METRICS_AUDIT_LOG" "$METRICS_AUDIT_BACKUP"
+else
+  METRICS_AUDIT_CREATED=1
 fi
```

---

## 適用手順

```sh
# 0. 既存の汚染を掃除する（**patch 適用と別に必要**）
grep -c 'TASK-9991' docs/working/_audit/hook-events.log     # 適用前の件数を記録
#    → 偽レコードの除去は「append-only 監査ログの編集」にあたるため、
#      **削除するか残すかは Human の判断**。本 patch は再発防止のみを扱う。

# 1. 上記 diff を適用

# 2. 構文チェック
sh -n tests/extras/ta-09-metrics.sh && echo "syntax OK"

# 3. root 解決の実測（**両方の実行経路**）
sh tests/extras/ta-09-metrics.sh                # standalone
#    期待: <repo>/tests ではなく <repo> を root として動く

# 4. 汚染しないことの実測（**本 patch の主目的**）
mv docs/working/_audit/hook-events.log /tmp/_audit.bak 2>/dev/null || true
sh tests/extras/ta-09-metrics.sh >/dev/null 2>&1
ls docs/working/_audit/hook-events.log 2>/dev/null && echo "❌ 残置している" || echo "✅ 削除されている"
mv /tmp/_audit.bak docs/working/_audit/hook-events.log 2>/dev/null || true

# 5. 既存ログがある場合の復元（回帰確認）
#    hook-events.log を用意 → テスト実行 → 内容が元どおりであること

# 6. 全体
sh tests/run-tests.sh   # 単独で実行すること（並行実行は ta-42 / ta-61 で壊れます）
```

### ⚠️ 手順 4 と 5 は**両方**必要です

- **手順 4**: 既存ログ**なし**の経路（今回の欠陥）
- **手順 5**: 既存ログ**あり**の経路（既存の正常系を壊していないこと）

**片方だけだと、もう一方を壊した可能性が残ります。**

## 既存の汚染について（**Human 判断**）

現 main の `docs/working/_audit/hook-events.log` には **`TASK-9991` の偽レコードが 4 件**あります。

**削除するか残すかは Human の判断**としました。理由:

- `docs/working/_audit/` は **append-only の監査証跡**であり、**AI が過去の記録を消すべきではありません**
- 偽レコードであることは `TASK-9991` という fixture 専用名から識別可能なので、**残しても実害は限定的**です
- ただし **今後 metrics 集計（`bin/plangate metrics --report`）に混入する可能性**があるため、判断は必要です

## 関連: 同クラスの残課題

| issue | 症状 |
|---|---|
| **#947** の `ta-42` | **sandbox でなく実リポジトリの `docs/working/` に書き込む** → 並行実行で構造的に flaky（本セッションで実測） |
| **#1044 / #921** | extras bootstrap の helper 欠落経路が実行方法で挙動を変える |

**「テストが実リポジトリの状態に触れる」という共通構造**です。**個別に直すより、extras の隔離契約として一度に決める**ほうが筋が良いかもしれません（#921 の `_extra-contract.sh` 移行がその器になりえます）。

## 責務

| 作業 | 担当 |
|---|---|
| patch の作成・実害の実測・検証手順 | **AI-owned**（本書） |
| **`tests/extras/ta-09-metrics.sh` への適用** | **Human-owned**（EH-3 が AI の `.sh` 編集を block） |
| **既存の偽レコード 4 件の扱い** | **Human**（append-only 監査証跡の編集判断） |
| 手順 4 / 5 の実測 | 適用者・**両方必須** |

Refs #1021 / #947 / #921 / #1092
