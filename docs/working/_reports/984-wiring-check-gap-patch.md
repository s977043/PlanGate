# #984 patch — `check-settings-wiring.sh` が配線済み hook の **半分しか検査していない**（**Human 適用**）

> 対象: `scripts/check-settings-wiring.sh`
> **AI は `.sh` を編集できない**（EH-3 の no-task 経路が `SKIP_REASON` を要求）ため、差分と適用手順を文書として提示する。
> 測定基点: `origin/main` = `1e33b57` / 2026-08-18

## ⚠️ issue 記載より広い — **2 件ではなく 5 件が未検査**

#984 は「`check-metrics-privacy` / `check-approval-token-write` の 2 hook が checks に無い」として起票されていますが、**現 main で測り直すと 5 件**です（`check-metrics-privacy` は `settings.example.json` に配線されていないため対象外）。

### 実測

`settings.example.json` に配線されている hook（正解集合）と、`check-settings-wiring.sh` が検査している集合の差:

| hook | event / matcher | 検査 |
|---|---|---|
| `check-plan-exists.sh` | PreToolUse / `Edit\|Write` | ✅ EH-1 |
| `check-c3-approval.sh` | PreToolUse / `Edit\|Write` | ✅ EH-2 |
| `check-forbidden-files.sh` | PreToolUse / `Edit\|Write` | ✅ EH-6 |
| `check-plan-hash.sh` | PreToolUse / `Edit\|Write` | ✅ EH-3 |
| `check-delegation-commit-boundary.sh` | PreToolUse / `Bash` | ✅ EH-9 |
| **`check-approval-token-write.sh`** | **PreToolUse / `Edit\|Write` + `Bash`** | ❌ **未検査** |
| **`check-git-destructive.sh`** | **PreToolUse / `Bash`** | ❌ **未検査** |
| **`check-post-edit-diff.sh`** | **PostToolUse / `Edit\|Write\|MultiEdit`** | ❌ **未検査** |
| **`check-stop-diff-status.sh`** | **Stop** | ❌ **未検査** |
| **`gh-pin-account.sh`** | **SessionStart** | ❌ **未検査** |

**5/10 が未検査です。**

## 何が起きるか

`check-settings-wiring.sh` は **`settings-drift` CI ジョブの実体**で、「配線が消えていないか」を守る唯一の機構です。

**未検査の 5 本は、`settings.json` から削除されても CI が緑のままです。**

これは本リポジトリで**実害が出た経路**です（memory / `project_settings_json_self_mod_guard.md`）:

> 適用済み配線も silent に退行する（**2026-08-02 に EH-1/2/3/6 が消え 3 日間無検出**）

**EH-1/2/3/6 は現在検査対象なので同じ事故は防げますが、EH-12 / EH-13 と PostToolUse / Stop / SessionStart は無防備のままです。**

とくに **`check-approval-token-write.sh`（EH-13）は承認トークンの書き込みガード**で、**#1104 で判明したとおり「Bash 経路を持つ唯一の書き込みガード」**です。これが消えても誰も気づきません。

## 構造上の制約 — **2 層に分かれます**

`check-settings-wiring.sh` は **`PreToolUse` しかスキャンしていません**:

```python
pre = ((doc or {}).get("hooks", {}) or {}).get("PreToolUse", [])
```

したがって:

| 層 | 対象 | 必要な変更 |
|---|---|---|
| **Tier 1** | `check-approval-token-write.sh` / `check-git-destructive.sh` | **`checks` リストへの追加のみ**（既存構造で足りる） |
| **Tier 2** | `check-post-edit-diff.sh` / `check-stop-diff-status.sh` / `gh-pin-account.sh` | **スキャン対象を他 event へ拡張**（構造変更） |

**本 patch は Tier 1 のみを扱います。** Tier 2 は設計判断（どの event をどこまで契約とするか）を含むため分離します。

---

## 差分（Tier 1）

`scripts/check-settings-wiring.sh` の `checks` リストに 2 行追加します。

```diff
 checks = [
     ("check-plan-exists.sh", "Edit|Write", "EH-1 plan-exists"),
     ("check-c3-approval.sh", "Edit|Write", "EH-2 c3-approval"),
     ("check-forbidden-files.sh", "Edit|Write", "EH-6 forbidden-files"),
     ("check-plan-hash.sh", "Edit|Write", "EH-3 plan-hash"),
     ("check-delegation-commit-boundary.sh", "Bash", "EH-9 delegation-commit-boundary(TASK-0073)"),
+    # EH-13 は Edit|Write と Bash の **両方**に配線される（#1104 で判明したとおり
+    # 書き込みガードのうち Bash 経路を持つ唯一の hook）。両方を独立に検査する。
+    ("check-approval-token-write.sh", "Edit|Write", "EH-13 approval-token-write(Edit|Write)"),
+    ("check-approval-token-write.sh", "Bash", "EH-13 approval-token-write(Bash)"),
+    ("check-git-destructive.sh", "Bash", "EH-12 git-destructive"),
 ]
```

> **EH-13 を 2 行に分けている**のが重要です。1 行にすると、**どちらか片方の配線が消えても `has()` が True を返して素通り**します。**#1104 の中核は「経路ごとの非対称」**なので、経路ごとに検査すべきです。

## 適用手順

```sh
# 1. 上記 diff を適用

# 2. 現状で PASS すること（配線は揃っているため挙動不変）
sh scripts/check-settings-wiring.sh                    # PASS / rc=0
sh scripts/check-settings-wiring.sh --target example   # PASS / rc=0

# 3. 検出力の実測（**必須**）— 各行が実際に効くことを 1 つずつ確認
cp .claude/settings.json /tmp/_settings.bak
#   (a) EH-13 の Bash 側だけを削除 → FAIL することを確認
#   (b) EH-13 の Edit|Write 側だけを削除 → FAIL することを確認
#   (c) EH-12 を削除 → FAIL することを確認
cp /tmp/_settings.bak .claude/settings.json            # 必ず復元

# 4. 全体
sh tests/run-tests.sh   # 単独で実行すること（並行実行は ta-42 / ta-61 で壊れます）
```

### ⚠️ 手順 3 の (a)(b) を省略しないでください

**EH-13 を 2 行に分けた意味は、片側だけ消えたときに検出できることです。** 1 行だけ試して「FAIL した」で終えると、**分割の効果を検証していません**。

> `.claude/settings.json` は **HO 対象パス**です。手順 3 は **Human が実行**してください（AI は編集できません）。

## Tier 2（**本 patch の対象外・別途判断が必要**）

`check-post-edit-diff.sh` / `check-stop-diff-status.sh` / `gh-pin-account.sh` を検査するには、スキャナを `PreToolUse` 以外へ拡張する必要があります。

**設計判断が要ります**:

1. **どの event を契約に含めるか** — `PostToolUse` / `Stop` / `SessionStart` はいずれも「消えても即座に破綻しない」性質で、`PreToolUse` のガードとは重みが違います
2. **`matcher` の扱い** — `Stop` / `SessionStart` は matcher を持たないため、`has()` の matcher 判定をそのまま使えません

→ **#984 の残スコープ**として追跡するか、別 issue に切るかをご判断ください。

## 関連: この patch が守る対象

**#1104（Bash 経路にガードが無い）の是正が入ると、EH-13 以外にも Bash 配線が増える見込み**です。そのとき **`checks` に追加し忘れると、増えた配線が最初から無検査になります**。

本 patch で「**経路ごとに 1 行**」という形を確立しておくと、その追加が自然に行われます。

## 責務

| 作業 | 担当 |
|---|---|
| patch の作成・ギャップの実測・検証手順 | **AI-owned**（本書） |
| **`scripts/check-settings-wiring.sh` への適用** | **Human-owned**（EH-3 が AI の `.sh` 編集を block） |
| **手順 3（検出力の実測）** | **Human**（`.claude/settings.json` は HO 対象パス） |
| Tier 2 の要否判断 | **Human** |

Refs #984 / #1092 / #1104
