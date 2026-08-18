# STATUS — TASK-1093 (#1093)

## 全体構成

| PR / ブランチ | 内容 | 状態 |
|---|---|---|
| [#1111](https://github.com/s977043/PlanGate/pull/1111) | Plan Package（v1 → C-2 REJECT → v2）初版 | **マージ済**（`origin/main`） |
| `docs/1093-split-scope` | **v3: C-3 裁定 2026-08-18（案 B: 2 分割）の反映** | 本セッション |

## モード判定結果

| 版 | Mode | 契機 |
|---|---|---|
| v1 | high-risk | 初版 |
| v2 | **critical** | C-2 REJECT 反映で契約適合が apply script 全数に及んだため引き上げ |
| **v3** | **high-risk（戻した）** | **C-3 2026-08-18 の案 B（2 分割）で移行が #1114 へ出たため** |

## フェーズ履歴

> 日時は **JST**。出典は commit の committer date / issue コメントの `createdAt` /
> ai-loop run record のファイル名（すべて実測。推定値は書かない）。

| 日時 | フェーズ | 内容 |
|------|---------|------|
| 2026-08-15 21:25 | B / C-1 | plan / todo / test-cases 生成、`review-self.md`（`de8d714`） |
| 2026-08-15 21:45 | C-2 | 外部レビュー **REJECT**（major 5 / minor 5 / info 3）→ `review-external.md` に `R-001`〜`R-013`（`5e42a51`） |
| 2026-08-15 21:56 | C-2 反映 + 簡易 C-1 | 方式を v2 へ変更（**判定を書き写さない**）、`review-self-2.md`（WARN）（`96b339f`） |
| 2026-08-15 22:09 | PR #1111 マージ | Plan Package v2 が `origin/main` へ（`acd0135`） |
| 2026-08-18 07:07 | **C-3 裁定（Human）** | **案 B: 2 分割 / defer 容認 / U-5 持ち越し / R-004 は本 PBI では塞げない** — [裁定コメント](https://github.com/s977043/PlanGate/issues/1093#issuecomment-5320820417) |
| 2026-08-18 07:07 | 分割先起票 | **[#1114](https://github.com/s977043/PlanGate/issues/1114)**（既存 apply script の契約適合移行） |
| 2026-08-18 09:49 | **裁定の確定反映（v3）+ 簡易 C-1** | 本ブランチ。`review-self-3.md`（WARN）（`9b24ba2`） |
| 2026-08-18 09:56 | **ai-loop C-3' 裁定（run-033）** | **`HUMAN_ESCALATED`（exit 2）**。`w_check` = model_a approve / model_b **reject（logic）**。Human 判断 = **指摘を反映して再提出**。record: `docs/working/ai-loop-runs/20260818T005603Z-9b24ba2.json` |
| 2026-08-18 09:58 | #1114 に AC-1〜AC-7 追記（Human） | 起票時に受入条件が欠落していた件の是正（`updatedAt` 実測）。本 PBI の引き継ぎ先が**受理済**になった |
| 2026-08-18 10:07 | **run-033 round 1 指摘の確定反映（v4）+ 簡易 C-1** | 本ブランチ。`review-self-4.md`。**fail-closed 一般則 / 凍結リスト / #1114 参照是正 / V-4 撤回 / 行番号アンカー除去** |
| 2026-08-18 10:30 | **ai-loop C-3 裁定（run-033 round 2）** | **`HUMAN_ESCALATED`** → **Human 裁定: U-6 不採用**（凍結リスト設計が chicken-and-egg で成立しない / 結果は不採用と同一でコストだけ増える） |
| 2026-08-18 10:45 | **U-6 不採用の確定反映（v5）+ 簡易 C-1** | 本ブランチ。`review-self-5.md`。**U-6 を設計から除去 / `n/a (local)` の実行時検査 / TC-33 格下げ / 半順序定義 / タスク数是正** |

## 計画からの変更点（v2 → v3 / **2 分割の反映**）

### 1. スコープの 2 分割

| 対象 | 移動先 |
|------|-------|
| **既存 apply script の exit code 契約への適合（移行）** | **#1114** |
| 個々の apply script の実質ロジック是正（逆方向差分 / 引数解析欠落 / rc≠0 の原因） | **#1114**（v2 では「別 issue 起票のみ」だったものを #1114 に集約） |

**本 PBI に残るもの**: **検出器（`check_pending_applies()`）+ `--dry-run` exit code 契約 + 台帳（マニフェスト）**。
**`scripts/apply-*.sh` は 1 本も変更しない**（台帳への登録のみ）。

### 2. Mode: critical → **high-risk**

引き下げの根拠は「着手を早めたい」ではなく、**critical の主因（多数 script への横断変更）が #1114 へ出たこと**。
6 軸すべてを v2 と対比した表を `plan.md` の「Mode 判定」に置いた。

**ただし正直に記録する**: **タスク数軸だけは 22 のままで critical 帯（21+）に残る**
（旧 T-06 の移設と T-08 の新設が相殺。実測 `grep -c "^| T-" todo.md` = **22**）。
したがって **素の判定ロジック（各軸の最大値）では critical**、
**最終 high-risk は C-3 の明示 override**（mode-classification 判定ロジック 4）である。
override により **V-4 が必須でなくなる**。
**v3 で書いた「V-4 相当の確認は TC-11 / TC-23 で代替」は v4 で撤回した** —
TC-11 は AC-6、TC-23 は R-006 の TC であり **override の有無に関わらず元から存在する**ため、
既存 TC の二重計上だった（run-033 指摘）。**V-4 の要否は U-7 として Human が決める**。
リリースプロセス保護に直結する点は変わらないため `standard` には落としていない。

### 3. #1114 へ移した AC / タスク / TC（**削除ではない**）

| 種別 | ID | 移設先での扱い |
|------|----|--------------|
| Work Breakdown | **旧 Step 5**（apply script を契約適合させる） | #1114 の本体作業 |
| ToDo | **旧 T-06**（同上） | 同上 |
| TC / MUT | **TC-16 / MUT-6**（実 script 全数の判定品質 kill） | #1114。本 PBI は **TC-16' / MUT-6'**（fixture 版）で機構を実証 |
| TC | **TC-06**（実 `apply-task-0146-ehs23-wiring.sh` での AC-3 実証） | #1114。本 PBI は **TC-06'**（fixture 版） |
| TC | **TC-17**（`scope=release` 全行が 3 値に確定） | #1114 完了時の条件。本 PBI は **TC-17'**（`adopted` 全行が 3 値 + `legacy` 全行が `unmigrated`） |
| Stop Condition | **旧 SC-5**（契約適合が `--apply` 挙動を変えた） | #1114。本 PBI の SC-5 は「**`scripts/apply-*.sh` を編集したくなった → 即停止**」に差し替え |

**AC-1〜AC-7 は増減なし。** AC-3 は本 PBI で fixture 実証、実 script 実証は #1114 の受入条件へ引き継ぐ。

### 4. defer の扱い（裁定どおり明記）

- `pending` + **Human 発行 `defer=<別 issue>`** → **WARN**（リリースをブロックしない）
- 名指し対象 = **`apply-ai-loop-workflow-command.sh`**（適用すると 2 週間分の退行）
- **AI は `defer` を増やさない**（SC-2 維持） / **`undecidable` に `defer` を効かせない**（TC-21 維持）
- 実際の `defer` 行投入は **#1114 で当該 script が `adopted` になった後**に Human が行う（todo H-2）

### 5. U-5（CI 未配線）を「意図的な状態」として明示

`grep -rn "release-prep" .github/` → **0 件**。検出器は現状どの workflow からも呼ばれない。
`.github/workflows/*` は **HO のため AI は配線できない**（実測 rc=2）。
本 PBI の機械強制は **`ta-67` 経由で `run-tests.sh` に乗る分のみ**。
plan の Non-goals + **専用節「既知の制約: 検出器は CI で一度も走らない」** + test-cases 末尾節の 3 箇所に明記。

### 6. R-004（`ack` / `defer` の hook 層保護）を follow-up として明記

HO 定義本体（`scripts/hooks/check-plan-hash.sh` の `_override=0` 直後の `case` ブロック）の変更が必要で、
それ自体が HO パス。**本 PBI では塞げない**ことを Non-goals・plan §4・todo T-21・Iron Law に記載。

### 7. 新規に生じた Human 判断: **U-6**

分割により契約非適合 script が残る期間が生まれる。放置すると `--check` が**恒久 NOT READY**。
台帳に **`contract` 列**（`adopted` / `legacy`）を置き、`legacy` を **`unmigrated(#1114)` → WARN** とする案を提示。
第 2 の fail-open にしないため **凍結集合 / 一方向 / #1114 OPEN 検査 / 毎回表示** の 4 拘束 + MUT-8 / MUT-9。
**採否は C-3 で Human が判断**（不採用なら T-08 / TC-25〜28 / MUT-8・MUT-9 を落とすだけで他の設計は不変）。

## 計画からの変更点（v3 → v4 / **ai-loop run-033 の指摘反映**）

run-033 は **`HUMAN_ESCALATED`（exit 2）**、`w_check` は model_a approve / **model_b reject（logic）**。
Human 判断は「**指摘を反映して再提出**」。以下 7 点を確定反映した。

### 1. 検査不能時の verdict を `undecidable`（fail-closed）と明記【最優先】

v3 は拘束を「凍結集合 + 一方向 + #1114 OPEN 検査 + 毎回表示」に置きながら、
**検査自身が実行できないときの挙動が未定義**だった。実装が「判定不能 → OPEN とみなす」に倒れれば
**`legacy` / `defer` が offline で恒久免除**になる ＝ **本 PBI が潰そうとしている fail-open クラスの再導入**。

plan §3-quater に**一般則**を新設: **免除の根拠となる検査が実行できない場合、免除を与えず `undecidable`（NG）に倒す。**
対象は issue state 取得（ネットワーク / `gh` / 認証 / rate limit / timeout）・凍結リスト読み取り・凍結ベースライン取得の 3 系統。
**TC-29〜TC-33 / MUT-10〜MUT-12** を新設。

**運用コストを隠さない**: offline・shallow clone では免除行がすべて NG になり `--check` は NOT READY。
これは意図した安全側の挙動で、**「検査を諦めて緑にする」経路は用意しない**。

### 2. 凍結集合の materialize を固定（同語反復と shallow clone の両方を潰す）

v3 は「凍結集合」と書いただけで**出所が未定義**だった。台帳の `legacy` 行から導けば**同語反復**
（`legacy` を 1 行足せば凍結集合が広がる ＝ **TC-27 が構造的に空振り**）。

plan §3-ter を新設し **`scripts/apply-contract-freeze.list`（台帳とは別ファイル）** を正本に:

- **F-1（非タウトロジー）**: `legacy` 行 ⊆ 凍結リスト。**台帳だけを編集しても `legacy` を増やせない**
- **F-2（shrink-only）**: 現在の凍結リスト ⊆ **ヘッダに記録した凍結コミットの blob**。
  比較対象は**固定した 1 点**（「直前のコミット」ではないので drift しない）。
  **`adopted → legacy` の差し戻しは凍結リストへの再追加＝集合の拡大**なので F-2 が FAIL させる
- **取得不能時は `undecidable`**（TC-31 / TC-32）
- **MUT-13** が「台帳の `legacy` 行から凍結集合を導く」逆戻り変異を kill

**残る限界を明記**: 凍結リスト・台帳・ヘッダ SHA を整合的に書き換えれば通せる。
これは **R-004 と同一の穴**で本 PBI では塞げない（follow-up）。保証するのは
**同語反復でない / 単一ファイルの編集では広がらない / 黙って広がらない**の 3 点であって**改竄不能ではない**。

### 3. AC-5 を「単調安全性」へ精密化

検査不能を NG に倒す以上 verdict は環境に依存して動くため、AC-5 と衝突する。
**環境差は verdict を NG 側にしか動かせない**（OK→NG は可 / **NG→OK が 1 件でもあれば FAIL**）と定義し直した。
`.claude/settings.json` の有無は従来どおり**完全同一**。**TC-34**（ネットワーク有無 × git 履歴 full/shallow の 4 組合せ）と **MUT-14** を新設。

### 4. #1114 への参照を「AC が引き受けている」形へ書き換え

**v3 の「起票時に確認すること（T-21）」は成立していなかった** — #1114 は既に起票済で、導線は永久に実行されない。
2026-08-18 09:58 に #1114 へ **AC-1〜AC-7 が追記された**ため、test-cases に**受理状況の対応表**を追加し、
**T-21b（既存 issue の AC と引き継ぎ内容の突合）**を新設した。**齟齬があれば #1114 側を是正**する。

### 5. V-4 の「代替」記述を撤回（上記モード判定節）

### 6. 行番号アンカーを除去

`test-cases.md` TC-04 の `_override=0`@94 / `@119` と `plan.md` の `bin/plangate:2248` を
**記号・出現順ベース + 測定日**へ差し替え。**`review-self-3` の C1-EX-05 は「行番号アンカーは使っていない」と
全称で PASS 宣言しながらこの 2 件を見逃していた**（本セッション 3 件目の同型 / [#1124](https://github.com/s977043/PlanGate/issues/1124)）。
`review-self-4` では**同じ制約で自分の成果物を grep してから**判定する。

### 7. U-6 不採用時の代替案を明記

plan §3-quinquies を新設。**§3-ter / §3-quater が実装できないなら U-6 は不採用**とし、
**#1114 完了まで恒久 NOT READY を受け入れる**。`--check` は CI 未配線（U-5）なので**自動フローは何も止まらない**。
「`--check` が使えると便利」は fail-open を 1 つ増やす理由にならない。

## 計画からの変更点（v4 → v5 / **U-6 不採用の確定反映**）

ai-loop run-033 **round 2** も `HUMAN_ESCALATED`。**Human 裁定 = U-6 不採用**。

### 1. 🔴 U-6（`contract=legacy` 機構）を**不採用**として plan 本体へ反映

**注記の追加ではなく、plan を不採用の姿に整えた**（§3-bis を本線に昇格）。

外したもの: `contract` 列 / `legacy` / `unmigrated(#1114)` / 凍結リスト
（`scripts/apply-contract-freeze.list`）/ F-1 / F-2。

**不採用の決め手（v4 設計は初日から成立しない）**:

- v4 は「凍結リストは台帳と同一コミットで作成」かつ「F-2 の比較対象は**ヘッダに記録した凍結コミットの blob**」と定めた
- しかし **自分自身を含むコミットの SHA を、そのコミットに含まれる自分のヘッダへは書けない**（chicken-and-egg）
- よって凍結 SHA は必ず**凍結リストが存在しないコミット**を指し、blob 取得は失敗 → fail-closed 則で**全 `legacy` 行が `undecidable`→NG**
- 「直前コミットを指す」設計でも、**本 repo は squash merge 運用**のため merge 後に SHA が reachable でなくなり同じ結末
- **結果が不採用と同一なのに実装コスト（Step 6/6b・TC-25〜28・TC-31〜34・MUT-8〜14）だけが上乗せされる**

**これは私（AI）の設計ミスである。** v4 で「凍結リストで同語反復を断つ」と書いた時点で、
**その凍結リストを検証する術が無い**ことに気づくべきだった。

### 2. `--check` が #1114 完了まで NOT READY を返すことを**仕様**として明記

「既知の制約」ではなく **仕様**として plan §3-bis に記載した。理由:

- 本 PBI の目的は「**緑が出たときに本当に適用待ちが無いと言える**」状態を作ること。
  契約非適合で判定できない script が残る間は**緑を出してはならない**
- 免除機構を置けば緑にできるが、それは**判定できないものを緑にする**行為＝ #1093 が是正しようとしている fail-open そのもの
- **`--check` は CI 未配線（U-5）**なので、NOT READY で止まるのは **Human が手で走らせたとき**のみ。**自動フローは何も止まらない**

**解消条件は #1114 の完了のみ**（SC-9 で「緑にするための免除列を足さない」を固定）。

### 3. `n/a (local)` の穴を塞いだ（U-6 とは独立の実在の穴）

v4 までは `n/a (local)` の根拠が **台帳 `scope` 列の自己申告のみ**で、
`targets` の tracked 検査は **E-05 の test-time だけ**だった。
結果、**非 git ディレクトリ / tarball 展開では `n/a (local)` が無傷で OK のまま通る**
（`legacy` は `undecidable` に倒れるのに、こちらは倒れない）。

**是正（plan §3-ter-2）**: `n/a` を与える前に**実行時に**評価する。

1. `targets` の tracked / untracked を判定
2. **1 つでも tracked なら `undecidable`→NG**（`scope` の誤申告を実行時に検出）
3. **判定自体ができない**（非 git / tarball / `git` 不在）なら **`undecidable`→NG**

**TC-35 / TC-36 / E-15 / MUT-15 / MUT-16** を新設。`TC-34` の軸を
**「full / shallow」→「git repo 有無」**へ差し替えた（凍結ベースラインが消えたため）。

### 4. `§3-quater`（fail-closed 一般則）は**存続**させた

**根拠**: `legacy` が消えても、**根拠検査を要する verdict が 2 つ残る**。

| verdict | 根拠検査 | 検査不能の例 |
|---|---|---|
| `pending(defer=#N)` | 参照 issue が OPEN | offline / `gh` 不在 / rate limit |
| `n/a (local)` | `targets` が全て untracked | 非 git / tarball / `git` 不在 |

どちらも「検査できないので免除する」に倒れれば fail-open になる。
対象を **凍結リスト系 2 つ → `n/a (local)` 1 つ**に差し替えて存続（§3-ter へ改番）。

### 5. TC-33 を「補助」へ格下げ

TC-33（fail-open 分岐が grep で 0 件）は、**本 PBI が R-002 で否定した
「実装本体でなく表現を測る」クラスそのもの**。fail-open は書き方の集合として
無限に表現でき grep では網羅できない。

→ **AC カバレッジに計上しない**。実質は動的な **TC-29 / TC-30 / TC-35 / TC-36** が担う。
SC-8 の確認手段としては残すが、**「TC-33 が通ったから fail-open が無い」とは主張しない**。

### 6. AC-5 単調安全性の**半順序を定義**（v4 は未定義だった）

環境を capability 集合（`network` / `git`）で表し、**集合包含の半順序**で比較する。

- **比較するのは比較可能な 5 ペアのみ**（基準→各劣化環境、および各劣化環境→最貧環境）
- **`{network}` と `{git}` は比較不能なので比較しない** — v4 の「4 組合せで NG→OK が 0 件」は
  「基準との比較」とも「隣接ペア総当たり」とも読め、**劣化側どうしの矛盾が測れなかった**
- 安全性順: OK 系（`applied` / `n/a (local)` / `pending(defer)`）＜ NG 系（`pending` / `undecidable`）
- **最貧環境では `defer` 行と `n/a (local)` 行がすべて `undecidable`**

### 7. タスク数の不整合を是正（承認レコード未発行のうちに）

**v3 / v4 の Mode 判定表は「タスク数 22」と書いていたが、実物は v4 時点で 25 だった**
（`review-self-4` のみ正しく 25 と書いていた）。

**U-6 不採用で T-08 / T-08b が落ち、`n/a` 実行時検査の T-08d が入って実測 24。**
Mode 表・本文・本ファイルを **24** へ統一した。**定量軸では依然 critical 帯（21+）**であり、
high-risk は **C-3 override** のままである。

### 削除ではなく「不要」として記録した項目

plan §3-bis に**欠番表**を置き、TC-25〜28 / TC-31 / TC-32 / E-11 / E-12 / E-14 /
MUT-8 / MUT-9 / MUT-11〜13 / 旧 Step 6 / 旧 T-08 / T-08b / 旧 SC-7 を
**「U-6 不採用により不要」**として追跡可能にした。**存続 ID は再採番していない**。

### v5 実測値（再カウント）

| 項目 | v4 | **v5（実測）** |
|------|----|--------------|
| Agent タスク | 25 | **24** |
| TC（live） | 34 | **30** |
| MUT（live） | 14 | **11** |
| Edge（live） | 14 | **12** |
| 成果物ファイル | 6 | **5**（凍結リストが消えた） |

## 変更していないもの（**重要**）

- **v2 の方式**: 判定を台帳へ書き写さない / script 自身の冪等判定を exit code 契約で読む / self-validating
- **AC-1〜AC-7**
- **穴 (a)(b)(c)(d) と対応 TC の構造**
- `review-self.md` / `review-self-2.md` / `review-external.md`（**追記も書き換えもしていない**）

## 残タスク

- [ ] **👤 H-1: 人間 C-3 APPROVE**（mode=high-risk / autonomous APPROVE 不可）— **残る判断は U-7（V-4 の要否）のみ**（U-6 は round 2 で不採用確定）
- [ ] **👤 H-1b: `c3.json` の発行** — **v3 / v4 / v5 と plan が変わっているため、本更新の後に発行すること**
      （working-context.md の順序規約: 確定反映 → 簡易 C-1 → `c3.json` 発行 → exec。
      **本セッションでは発行していない**）
- [ ] 🤖 exec（Agent タスク **24 本**）— C-3 APPROVE 後
- [ ] 👤 H-5: `--check` の CI 配線（`.github/workflows/*` = HO。**U-5 持ち越し・任意**）

### BLOCKED

| タスク | blocker | owner | unblock_condition |
|--------|---------|-------|------------------|
| exec 開始 | C-3 未承認（`c3.json` 未発行） | human | H-1 + H-1b |
| `defer` 行の投入（`apply-ai-loop-workflow-command.sh`） | 当該 script が未 `adopted` | #1114 | #1114 で当該 script が契約適合 |
| **#1114 の着手** | 本 PBI の exec 未完了（契約と台帳が無いと移行先が無い） | 本 PBI | 本 PBI の exec 完了 |

## V 系ステップ進捗

| ステップ | 状態 |
|---------|------|
| C-1（初回 / C-2 反映後 / v3 / v4 / **v5**）| ✅ `review-self.md` / `review-self-2.md` / `review-self-3.md` / `review-self-4.md` / **`review-self-5.md`** |
| C-2 | ✅ REJECT → v2 で反映（`review-external.md` `R-001`〜`R-013`）|
| **C-3'（ai-loop run-033 round 1）** | ⏸ **`HUMAN_ESCALATED`** → 「指摘を反映して再提出」→ **v4 で反映済** |
| **C-3'（ai-loop run-033 round 2）** | ⏸ **`HUMAN_ESCALATED`** → **Human 裁定「U-6 不採用」** → **v5 で反映済** |
| C-3 | ⏸ **裁定 2026-08-18 済（案 B）**。**`c3.json` は未発行** |
| exec 以降 | 未着手 |

## 参照ファイル一覧

- [`plan.md`](plan.md) / [`todo.md`](todo.md) / [`test-cases.md`](test-cases.md) / [`pbi-input.md`](pbi-input.md)
- [`review-self.md`](review-self.md) / [`review-self-2.md`](review-self-2.md) / [`review-self-3.md`](review-self-3.md) / [`review-self-4.md`](review-self-4.md) / [`review-self-5.md`](review-self-5.md) / [`review-external.md`](review-external.md)
- ai-loop run-033 record: `docs/working/ai-loop-runs/20260818T005603Z-9b24ba2.json`
- [`evidence/`](evidence/)
- issue [#1093](https://github.com/s977043/PlanGate/issues/1093) / 分割先 [#1114](https://github.com/s977043/PlanGate/issues/1114)
- [C-3 裁定コメント](https://github.com/s977043/PlanGate/issues/1093#issuecomment-5320820417)
