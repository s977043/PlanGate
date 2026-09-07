# #1257 — `.github/workflows/test.yml` への `fetch-depth: 0` patch は **保留（適用しない）**

> 結論: **A-2' 採用により本 patch は不要**。適用待ちではなく **保留**である。
> 対象は `.github/workflows/test.yml`（Hardening Override 対象パスのため AI は編集不可。
> AI は patch 提示まで、適用は Human-owned = `.claude/rules/responsibility-classes.md`）だが、
> **今回は Human に適用を依頼しない**。
>
> 本ファイルは「なぜ当初 patch が要ると判断し、なぜ要らなくなったか」の記録であり、
> 適用待ちタスクではない。`tests/extras/ta-81-version-bump-gate.sh` は本ファイルの
> 存在／不在を判定材料に**使わない**（当初の pending-flag 方式は撤去した）。

## 当初の判断（A-2 = マージ時ゲート前提）

`#1257` の受入基準 1 を「`plugin/plangate/**` に差分がある PR で version 未 bump なら
**CI が FAIL する**」と読むと、ゲートは PR CI で `--bump` を走らせる必要がある。
`actions/checkout` の既定は `fetch-depth: 1` で PR の base（`origin/main`）が
checkout に存在しないため、`check-version-bump.sh --bump` は
`VERSION_BASE_UNRESOLVED` で **rc=3（＝検査していない）** を返す。rc=0 で成功を
装わない設計なので誤検出はしないが、**ゲートは働かない**。よって当初は
`fetch-depth: 0` の 1 行を Human 適用の残タスクとして提示していた。

## 判断が変わった理由（A-2' / 2026-09-07 Human 決定）

`--bump` を PR CI に置くと、**通常の開発 PR がほぼ全部赤になる**ことが実測で判明した。

| 測定 | 値 |
|---|---|
| 測定時点 | `b3565b2` |
| 対象 | 2026-07-07 以降の first-parent commit のうち `plugin/plangate` に差分があるもの |
| 母数 | 98 件 |
| そのうち version 据え置き（= PR CI なら赤） | **91 件** |

赤になるのは `sync-plugin-plangate` の自動同期 PR だけでなく、`.claude/` を触る通常の
feature PR のほぼ全部である。さらに自動同期 PR は version を CHANGELOG 先頭から取るため、
人が手で編集しない限り**恒久的に赤**になる。

→ **ユーザー決定 = A-2'**: ゲートを **マージ時からリリース時へ移す**。

- **PR CI** = `--parity` のみ（version 宣言箇所の同値 + 宣言漏れ検出）
- **リリース時** = `--bump --since-latest-tag`（`scripts/release-prep.sh --check` に配線）

## `fetch-depth: 0` が不要になることの実測

| 経路 | shallow clone（`fetch-depth: 1` 相当）での挙動 | 実測 |
|---|---|---|
| PR CI が走らせる `--parity` | **rc=0 / `VERSION_PARITY_OK`**。git 履歴を一切参照せず、作業ツリーの JSON だけを読む | `git clone --depth 1` した clone に対し `sh scripts/check-version-bump.sh --parity --root <shallow>` → `VERSION_SITES_COMPLETE 4` / `VERSION_PARITY_OK 8.21.0` / rc=0 |
| リリース時の `--bump --since-latest-tag` | shallow clone には **tag が 1 つも fetch されない**（実測: `git tag \| wc -l` = 0、`git describe --tags --abbrev=0` は `fatal: No names found`）。この経路は **rc=3（= 検査していない）** を返して黙って PASS しない | 同上の shallow clone で確認 |

したがって:

- **PR CI に `fetch-depth: 0` は要らない**。`--parity` は shallow でそのまま動く。
- **リリース時ゲートは shallow を要求しない**。`release-prep --check` は上流リポジトリの
  完全な clone をローカル（または release 用ジョブ）で実行する運用であり、
  tag が引ける。万一 shallow で実行された場合は rc=3 → `release-prep` が
  **NG（未検査）** として NOT READY にする（0 で装わない）。

「tag が 1 つも無い」の 2 通りは実装側で区別している:

- shallow clone → `VERSION_BASE_UNRESOLVED` / rc=3（検査できていない）
- 非 shallow で tag 0 件（初回リリース）→ `VERSION_NO_TAG` / rc=0（比較対象が無い）

## 保留した patch（記録。適用しない）

将来 A-2 相当（マージ時ゲート）へ方針を戻すか、別 workflow で `--bump` を走らせる
必要が出た場合にのみ、次の 1 行が要る:

```diff
--- a/.github/workflows/test.yml
+++ b/.github/workflows/test.yml
@@
       - name: Checkout
         uses: actions/checkout@... # pinned
         with:
           persist-credentials: false
+          # version bump ゲート（--bump）が PR の base を解決するために全履歴が要る。
+          # fetch-depth: 1 のままでは VERSION_BASE_UNRESOLVED（rc=3）になる。
+          fetch-depth: 0
```

適用する場合は、その時点の `test.yml` に合わせて patch を作り直すこと
（上記は形を示すだけで、そのまま `git apply` できる patch としては保守しない —
`uses:` の pin は更新されるため、古い patch は黙って当たらなくなる）。

## 残存脅威モデル（A-2' で守らないもの）

- **マージ時点では未 bump を止めない**。配布物を変えた PR は version 据え置きのまま
  main に入る。届かない状態が是正されるのは**次のリリース準備時**であり、
  それまでの間 `main` の配布物と consumer が持つ payload は乖離する。
  これは A-2' が意図して受け入れたトレードオフである（代わりに 98 件中 91 件が
  赤になる運用不能を避けた）。
- ゲートが見るのは `plugin/plangate/**` の差分のみ（issue #1257 In scope）。
  `.claude-plugin/marketplace.json` だけを変える差分は bump を要求されない。
- `--parity` は「宣言箇所が同値か」であって「その値が実際に配布された payload と
  対応するか」ではない。同一 version で payload が分岐する事象そのものの検出は
  実インストール E2E（#1257 Out of scope）が担う。
- `release-prep --check` を**実行せずに**リリースした場合、本ゲートは一切働かない。
  リリース手順（`docs/release-process.md`）と C-4 Human レビューとの多層で担保する。
  **#1292 マージ直後の実測ではこの「手順側の担保」が存在しなかった**: `--check` は
  「ゲートを掛ける位置」の分界表にしか書かれておらず、`### 必須検証手順` の 4 ステップ
  （tag push → parity → `gh release create` → run 確認）にも `.github/workflows/` にも
  現れていなかった（`release-prep` の出現は doc 全体で 2 行、いずれも表と散文）。
  後追い是正で **必須検証手順の手順 1**（tag push の前）に追加し、
  `tests/extras/ta-81-version-bump-gate.sh` TC-12 が
  **節を限定して**（ファイル全体 grep は分界表にヒットして恒真になる）その存在を検査する。
- 準備経路 `release-prep.sh vX.Y.Z` は `run_checks || true` で **NOT READY でも rc=0** を
  返していた（fail-closed を売りにするゲートを fail-open のラッパに置いていた）。
  後追い是正で `run_checks` の rc を保持し、案内（`次: …`）を出したうえでその rc で
  終了する。`--check` 側の rc 意味は変えていない。`ta-81` TC-13 が rc≠0 と、
  対照（全検査 OK で rc=0 / READY）の両方を実測する。
