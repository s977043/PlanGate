# #997 + #947(c) patch — `git status --porcelain` の絶対空チェックが誤 FAIL する（**Human 適用**）

> 対象: `scripts/ai-loop/test_run_evidence.py`（**2 箇所にコピー**）/ `tests/extras/ta-54-ai-loop-link-selfcontained.sh`
> **AI は `.py` / `.sh` を編集できない**（EH-3 の no-task 経路が `SKIP_REASON` を要求）ため、差分と適用手順を文書として提示する。
> 測定基点: `origin/main` = `1e33b57` / 2026-08-18

## なぜ 2 つの issue を 1 本にまとめるか

**#997 と #947(c) は同一原因**です。どちらも「**操作が何かを変えたか**」を測るべき場所で「**作業ツリーが完全に clean か**」を測っています。

| issue | 箇所 | 対象パス |
|---|---|---|
| **#997** | `test_run_evidence.py` TC-45 | `docs/working/ai-loop-runs/` |
| **#947(c)** | `ta-54` TC-05 | `docs/workflows/ai-loop` / `docs/ai/ai-loop` |

**片方だけ直すと同じ欠陥が残ります。**

## 問題

### #997: `test_run_evidence.py` TC-45

```python
def test_tc45_existing_arbiter_records_are_untouched(self):
    # TC-45: RunEvidence は arbiter record の後継ではなく上位 artifact。
    # 分類・生成を実行しても既存 record を 1 バイトも変更しない（件数に依存しない検査）。
    self._classify(self.RUNS)
    cp = subprocess.run(["git", "status", "--porcelain", "--",
                         "docs/working/ai-loop-runs/"],
                        cwd=str(REPO), capture_output=True, text=True)
    self.assertEqual(cp.returncode, 0, cp.stderr)
    self.assertEqual(cp.stdout.strip(), "",
                     f"ai-loop-runs/ に差分が出ている: {cp.stdout}")
```

**コメントは「分類・生成を実行しても既存 record を変更しない」と宣言していますが、実装は「`ai-loop-runs/` に差分が一切ない」ことを要求しています。**

`docs/working/ai-loop-runs/` は **ai-loop 実走の成果物出力先**です。したがって **ai-loop を回した開発者の手元では必ず落ちます**。

#### 実害（本セッションで実際に踏みました）

```
AssertionError: '?? docs/working/ai-loop-runs/20260813T051[133 chars]json' != ''
- ?? docs/working/ai-loop-runs/20260813T051733Z-c553a58.json
- ?? docs/working/ai-loop-runs/20260814T001114Z-f76155e.json
- ?? docs/working/ai-loop-runs/20260814T004007Z-3ccea39.json
```

**テスト自身が作った差分ではなく、環境に既存の差分を拾っています。** clean clone では通ります（実測確認済み）。

**baseline 測定が実行環境に依存して揺れる**ため、`#1092` の台帳再実測では**この失敗を一度「LIVE な不具合」と誤って分類しかけました**。

### #947(c): `ta-54` TC-05

```sh
# TC-05: 正本 docs/workflows/ai-loop/*.md・docs/ai/ai-loop/*.md は変更されない
# （リンク変換は plugin コピーにのみ適用。sync 実行によるワークツリー差分が
#  正本側に出ていないことを git status で確認）
_t54_src_dirty=$(git -C "$PG_T54_ROOT" status --porcelain -- docs/workflows/ai-loop docs/ai/ai-loop 2>/dev/null || true)
if [ -z "$_t54_src_dirty" ]; then
  t54_pass "TC-05 正本 docs/workflows/ai-loop・docs/ai/ai-loop は無変更"
```

**完全に同じ構造**です。対象パスが狭い分だけ発火頻度が低いだけで、**その 2 ディレクトリを編集中の開発者は必ず落ちます**。

## 正しい実装は**同一コードベース内に既にあります**

`scripts/ai-loop/test_discovery.py` の `TestReadOnlyInvariant`:

```python
class TestReadOnlyInvariant(unittest.TestCase):
    def test_running_discovery_leaves_git_status_clean(self):
        before = subprocess.check_output(
            ["git", "status", "--porcelain"], cwd=REPO_ROOT, text=True
        )
        # ... 操作 ...
        after = subprocess.check_output(
            ["git", "status", "--porcelain"], cwd=REPO_ROOT, text=True
        )
        self.assertEqual(before, after)
```

**「操作の前後で差分集合が変わらない」を測っています。** これが本来の意図（read-only invariant）であり、**環境の既存差分に影響されません**。

---

## 差分

### 1. `scripts/ai-loop/test_run_evidence.py`（#997）

```diff
     def test_tc45_existing_arbiter_records_are_untouched(self):
         # TC-45: RunEvidence は arbiter record の後継ではなく上位 artifact。
         # 分類・生成を実行しても既存 record を 1 バイトも変更しない（件数に依存しない検査）。
+        # 注: ai-loop-runs/ は ai-loop 実走の成果物出力先なので、作業ツリーの
+        # 既存差分（未追跡の run record 等）を絶対空チェックで拾ってはならない。
+        # 「操作の前後で差分集合が変わらないこと」を測る（#997）。
+        # 正しい形の先例: test_discovery.py の TestReadOnlyInvariant。
+        before = subprocess.run(["git", "status", "--porcelain", "--",
+                                 "docs/working/ai-loop-runs/"],
+                                cwd=str(REPO), capture_output=True, text=True)
+        self.assertEqual(before.returncode, 0, before.stderr)
+
         self._classify(self.RUNS)
-        cp = subprocess.run(["git", "status", "--porcelain", "--",
-                             "docs/working/ai-loop-runs/"],
-                            cwd=str(REPO), capture_output=True, text=True)
-        self.assertEqual(cp.returncode, 0, cp.stderr)
-        self.assertEqual(cp.stdout.strip(), "",
-                         f"ai-loop-runs/ に差分が出ている: {cp.stdout}")
+
+        after = subprocess.run(["git", "status", "--porcelain", "--",
+                                "docs/working/ai-loop-runs/"],
+                               cwd=str(REPO), capture_output=True, text=True)
+        self.assertEqual(after.returncode, 0, after.stderr)
+        self.assertEqual(
+            after.stdout, before.stdout,
+            "分類・生成が ai-loop-runs/ の状態を変更した:\n"
+            f"before:\n{before.stdout}\nafter:\n{after.stdout}",
+        )
```

> ⚠️ **同一ファイルが 2 箇所に存在します**（`shasum` で**バイト同一**を確認済み）:
>
> ```
> scripts/ai-loop/test_run_evidence.py                                bc85a9e7803c
> plugin/plangate/skills/ai-loop-cycle/scripts/test_run_evidence.py   bc85a9e7803c
> ```
>
> **両方に同じ差分を当ててください。** 片方だけだと **plugin 配布側に穴が残ります**。

### 2. `tests/extras/ta-54-ai-loop-link-selfcontained.sh`（#947(c)）

TC-05 の直前（sync 実行より前）で before を取得し、比較します。

```diff
+# TC-05 の before: sync 実行より前に取得する（環境の既存差分を除外するため）。
+# 絶対空チェックだと、当該 2 ディレクトリを編集中の開発者の手元で必ず落ちる（#947(c)）。
+# 正しい形の先例: scripts/ai-loop/test_discovery.py の TestReadOnlyInvariant。
+_t54_src_before=$(git -C "$PG_T54_ROOT" status --porcelain -- docs/workflows/ai-loop docs/ai/ai-loop 2>/dev/null || true)
+
 （… sync 実行 …）
 
-_t54_src_dirty=$(git -C "$PG_T54_ROOT" status --porcelain -- docs/workflows/ai-loop docs/ai/ai-loop 2>/dev/null || true)
-if [ -z "$_t54_src_dirty" ]; then
+_t54_src_after=$(git -C "$PG_T54_ROOT" status --porcelain -- docs/workflows/ai-loop docs/ai/ai-loop 2>/dev/null || true)
+if [ "$_t54_src_before" = "$_t54_src_after" ]; then
   t54_pass "TC-05 正本 docs/workflows/ai-loop・docs/ai/ai-loop は無変更"
 else
-  t54_fail "TC-05 正本 docs に意図しない差分: $_t54_src_dirty"
+  t54_fail "TC-05 正本 docs に意図しない差分が発生: before=[$_t54_src_before] after=[$_t54_src_after]"
 fi
```

> **`_t54_src_before` の取得位置**は、**sync を実行するより前**である必要があります。適用時に TC-05 より上流で sync が走っていないか確認してください。

---

## 適用手順

```sh
# 1. 上記 3 ファイルを編集（test_run_evidence.py は 2 箇所）

# 2. 2 コピーがバイト同一のままであることを確認
diff scripts/ai-loop/test_run_evidence.py \
     plugin/plangate/skills/ai-loop-cycle/scripts/test_run_evidence.py && echo "同一 OK"

# 3. dirty tree で TC-45 が通ることを確認（本 patch の主目的）
touch docs/working/ai-loop-runs/_probe.json
python3 scripts/ai-loop/test_run_evidence.py \
  LegacyClassificationTests.test_tc45_existing_arbiter_records_are_untouched
rm -f docs/working/ai-loop-runs/_probe.json
#    期待: OK（従来は AssertionError で FAILED）

# 4. 検出力が失われていないことを確認（**必須**）
#    「本当に record を書き換える」変異を入れて FAIL することを見る
#    例: _classify の後に既存 record を 1 バイト書き換えるコードを一時的に挿入
#    期待: TC-45 が FAIL する

# 5. ta-54 単体
sh tests/extras/ta-54-ai-loop-link-selfcontained.sh

# 6. 全体
sh tests/run-tests.sh   # 単独で実行すること（並行実行は ta-42 / ta-61 で壊れます）
```

## ⚠️ 手順 4 を省略しないでください

**絶対空 → before/after へ変えると、検出力が落ちる方向の変更にもなりえます。**

- 変更前: 「差分が一切ない」（**厳しすぎる**が、record 変更は必ず捕まる）
- 変更後: 「操作の前後で変わらない」（**正しい**が、実装を誤ると常に PASS しうる）

**「本当に record を書き換える変異で FAIL すること」を実測しない限り、この patch は空振りテストを作っただけかもしれません。** 本リポジトリの既存教訓（空振り fixture / 変異注入で検出力を実証）に従ってください。

## 関連する残課題（本 patch の対象外）

**`ta-42` も同クラスですが、原因が異なります。**

```
tests/extras/ta-42-cli-subcommands.sh
  _t42_root="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
  _t42_work="$_t42_root/docs/working/TASK-T420"     ← 実リポジトリに書き込む
```

`ta-42` は **sandbox（`mktemp`）ではなく実リポジトリの `docs/working/` に書き込み、終了時に削除**します。**同一 worktree での並行実行が構造的に flaky** です（本セッションで実際に踏み、単独実行では `740 passed, 0 failed` でした）。

→ **#947 の scope 内**ですが、修正方針が別（sandbox 化）なので本 patch には含めていません。

## 責務

| 作業 | 担当 |
|---|---|
| patch の作成・再現手順・検証手順の提示 | **AI-owned**（本書） |
| **`.py` / `.sh` への適用** | **Human-owned**（EH-3 が AI の編集を block） |
| **手順 4（検出力の実測）** | 適用者（**省略不可**） |

Refs #997 / #947 / #1092
