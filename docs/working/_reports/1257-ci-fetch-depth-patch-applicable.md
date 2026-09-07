# #1257 — CI で version bump ゲートを有効化する HO patch（Human 適用待ち）

> 対象: `.github/workflows/test.yml`（**Hardening Override 対象パスのため AI は編集不可**。
> AI は patch 提示まで、適用は Human-owned = `.claude/rules/responsibility-classes.md`）。

## なぜ必要か

`#1257` の受入基準 1 は「`plugin/plangate/**` に差分がある PR で version 未 bump なら
**CI が FAIL する**」。ゲート本体は次の 2 つで実装済みで、`tests/run-tests.sh` 経由で
CI（`.github/workflows/test.yml`）から既に走る:

- `scripts/check-version-bump.sh --bump --base <ref>`
- `tests/extras/ta-81-version-bump-gate.sh`（上記を呼ぶ）

**残っているのは CI 側の履歴不足だけ**である。`actions/checkout` の既定は
`fetch-depth: 1` で、PR の base（`origin/main`）が checkout に存在しない。この状態では
`check-version-bump.sh --bump` は `VERSION_BASE_UNRESOLVED` で **rc=3（＝検査していない）**
を返す。rc=0 で成功を装わない設計なので誤検出はしないが、**ゲートは働かない**。

つまり「ゲートの存在」は「ゲートが効いている証拠」ではない。下の 1 行が入るまで、
受入基準 1 は **CI 上では未達**である。

## patch（適用は Human）

<!-- PG-PATCH-BEGIN -->
```diff
--- a/.github/workflows/test.yml
+++ b/.github/workflows/test.yml
@@ -22,6 +22,9 @@ jobs:
       - name: Checkout
         uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
         with:
           persist-credentials: false
+          # #1257: version bump ゲート（ta-81）が PR の base を解決するために
+          # 全履歴が要る。fetch-depth: 1 のままでは VERSION_BASE_UNRESOLVED になる。
+          fetch-depth: 0
 
       - name: Run CLI tests
         run: sh tests/run-tests.sh
```
<!-- PG-PATCH-END -->

適用手順（Human）:

```sh
# patch block を抽出して適用する（ta-81 と同一の抽出式）
awk '/PG-PATCH-BEGIN/{f=1;next} /PG-PATCH-END/{f=0} f' \
  docs/working/_reports/1257-ci-fetch-depth-patch-applicable.md \
  | grep -v '^```' > /tmp/1257.patch
git apply --check /tmp/1257.patch && git apply /tmp/1257.patch
```

## 適用状態の宣言（ta-81 が機械検査する）

`tests/extras/ta-81-version-bump-gate.sh` は次を検査する:

| 状態 | ta-81 の挙動 |
|---|---|
| `test.yml` に `fetch-depth: 0` あり | 本ファイルは **stale 宣言** として FAIL（適用済みなのに pending の記述が残っている） |
| `test.yml` に `fetch-depth: 0` なし + 本ファイルあり | 明示 opt-in された既知 gap として PASS（patch が `git apply --check` を通ることも実測） |
| `test.yml` に `fetch-depth: 0` なし + 本ファイルなし | FAIL（gap が宣言されずに消えている） |

適用後は本ファイルを削除すること（削除しないと ta-81 が stale で赤くなる）。

## 適用前に決めておくこと（Human 判断 / 運用への影響）

patch を当てると `ta-81` TC-09 が**その PR の base..HEAD** を実際に検査する。したがって
**`plugin/plangate/**` を変更するのに version を bump しない PR は CI が赤くなる**。
これは #1257 の受入基準 1 そのものだが、次の運用に直接あたる:

- `sync-plugin-plangate` が作る `chore(plugin): .claude/ → plugin/plangate/ 自動同期`
  PR（例: #1253 / #1274）は **version を bump しない**。patch 適用後は毎回赤くなる。
- issue #1257 の「案 A の短所（連続 PR ごとに bump が要る）」がここで表面化する。

選択肢（本 PBI では決めない）:

| 案 | 内容 |
|---|---|
| A-1 | 同期 PR にも version bump（例: patch 版の繰上げ）を含める |
| A-2 | 配布物の変更は同期 PR に集約し、リリース準備 PR とセットでのみマージする |
| A-3 | 監視対象から自動同期の経路だけを除外する（**穴を開ける方向なので非推奨**） |

## 残存脅威モデル

- 本 patch は `test.yml` の 1 ジョブにしか効かない。別 workflow が `run-tests.sh` を
  浅い checkout で走らせるようになったら、その job では同じ穴が開く。
- ゲートが見るのは `plugin/plangate/**` の差分のみ（issue #1257 In scope）。
  `.claude-plugin/marketplace.json` だけを変える PR は bump を要求されない。
- `--parity` は「4 箇所が同値か」であって「その値が実際に配布された payload と
  対応するか」ではない。同一 version で payload が分岐する事象そのものの検出は
  実インストール E2E（#1257 Out of scope）が担う。
