# PBI INPUT PACKAGE: 件数契約 3 箇所の時限爆弾除去と JSON 読込の単一定義化

> 対応 issue: [#1162](https://github.com/s977043/plangate/issues/1162)
> `refactor(tests,ai-loop): 件数契約 3 箇所の時限爆弾除去と JSON 読込の単一定義化`
> 本ファイルは棚卸（全数実測）の結果を PBI 形式へ落としたもの。受入基準は issue #1162 の
> AC-01〜AC-07 を **改変せず転記**している。

## Context / Why

リファクタリング候補の全数棚卸（`scripts/ai-loop/*.py` 実装 9,065 行 / `tests/extras/*.sh`
63 本 12,166 行 / `bin/plangate` 2,519 行）を実測した結果、**「大きいから割る」型の
リファクタリングはいずれも便益が小さいか設計意図を壊す**一方で、**リファクタリング自体を
妨げている構造が 2 つ実在する**ことが分かった。

### 実測 1: 成長する対象への絶対件数 assert が 3 箇所（時限爆弾）

| file:line | assert | 対象 | 実測値 |
|---|---|---|---|
| `tests/extras/ta-33-agent-model-tier.sh:25` | `[ "$_t33_count" -eq 17 ]` | `.claude/agents/*.md`（README 除く） | 現在ちょうど 17（`ls .claude/agents/*.md` = 18） |
| `tests/extras/ta-33-agent-model-tier.sh:54` | `[ "$_t33_toml_count" -eq 17 ]` | `.codex/agents/*.toml` | 現在ちょうど 17 |
| `tests/extras/ta-57-pr-convergence.sh:622` | `[ "$_t57_n" -eq 57 ]` | `test_delivery.py` の `Ran N tests` | 現在ちょうど 57 |

いずれも**等値**での固定。agent を 1 体足す PR、`delivery.py` にテストを 1 本足す PR が、
**変更と無関係に CI を RED にする**。とくに 3 つ目は `scripts/ai-loop/` のリファクタリングを
直接ブロックする（テスト追加＝即 CI 失敗）。

`.claude/rules` 系の既知教訓「成長するディレクトリに絶対件数を書かない」（無関係 PR の CI を
落とす時限爆弾）に該当する 3 箇所である。

### 実測 2: plugin 同期の allowlist が二重ハードコード（新規ファイルを作れない構造）

`plugin/plangate/skills/ai-loop-cycle/scripts/` には `scripts/ai-loop/` の**実装 14 本＋
テスト 14 本＝28 ファイル**が配布されている。同期対象は
`scripts/sync-plugin-plangate.sh:428`（コピー元の `for` 列挙）と `:440`（plugin 側の
`case` allowlist）に**ファイル名がベタ書きで二重**に存在する。

→ リファクタリングで**新規ファイルを 1 本でも追加すると、allowlist に載らず plugin 側だけ
import エラーになる**。`.github/workflows/sync-plugin-plangate.yml` は `scripts/ai-loop/**`
で発火するため自動 PR は出るが、**欠落したファイルは自動では追加されない**。

### 実測 3: 「割るべき」候補は実は少ない

- `arbiter.py:884 arbitrate()` 245 行 / `delivery.py:246 assess()` 189 行（AST 実測）は
  いずれも decision-table / state-machine を**意図的に 1 箇所へ集約**した設計で、深いネスト
  （4 段超）は全ファイルで **0 件**。分割すると判定順序の単一情報源が失われる
- `tests/extras/` の bootstrap ブロックは「helper を source する前に helper の所在を解決する」
  自己参照構造で**原理的に共通化不能**。`tests/extras/README.md` も共有ファイルを
  `_extra-contract.sh` 1 本に限定している
- 実害のある重複は **JSON 読込 `json.loads(X.read_text(...))` 10 箇所 / 5 ファイル**と
  **`sys.path.insert` の byte-identical 重複**の 2 点のみ

したがって本 PBI は「大規模分割」ではなく、**時限爆弾の除去（S-1）と、実害のある単一定義化
（S-2）**に絞る。

## What（Scope）

### In scope

#### S-1: 件数契約 3 箇所を、検出力を下げずに置換する（S-2 の前提）

- `ta-33` TC-01 / TC-03: 「17 体」ではなく**期待集合との照合**で測る
  （sonnet 集合 / low 集合 / medium 集合に対する**過不足**を検出する）
- `ta-57` TC-15: `Ran N tests` を **`-ge 57`（下限）＋ `OK` 出力＋ rc=0** の 3 条件に変える
  （テスト減少は検知しつつ、追加では落ちない）— **この方針は人間承認済み・変更しない**

S-1 を先に入れないと、S-2 で `test_delivery.py` に 1 本でもテストを足した瞬間に
`ta-57` TC-15 が FAIL するため、**S-1 は S-2 の前提**である。

#### S-2: JSON 読込の単一定義化

- `scripts/ai-loop/c3_contract.py` に `read_json(path)` を追加し、**10 箇所の JSON 読込を
  集約**する
- **新規ファイルを作らない**（実測 2 の二重 allowlist に載らず plugin 側だけ import
  エラーになるため）。既存の単一定義点である `c3_contract.py` に足す
- 各呼び出し側の例外処理（`ValueError` / `OSError` / `json.JSONDecodeError` の扱いと
  エラーメッセージ）が**箇所ごとに異なる**ため、**呼び出しごとに挙動不変を 1 箇所ずつ確認**する

#### S-3: `tests/hooks/run-tests.sh` の分割**要否判断**

- 754 行 / EH ブロック 13 個。分割の**要否判断と根拠の記録**のみ（実施する / しない いずれも可）

### Out of scope

- **`bin/plangate` の分割**（2,519 行）。Hardening Override 対象で適用が Human-owned、かつ
  `abort` / `plan-check` / `render` は個別テスト 0 件で分割後の退行を検出できない。別 PBI とする
- `scripts/hooks/*.sh`（HO 対象・AI 編集不可）
- `arbitrate()` / `assess()` 等の**長関数の分割**（上記実測 3 の理由）
- `_extra-contract.sh` への**未移行 45 本の一括移行**（運用上の途中段階でありバグではない）
- `scripts/apply-*.sh` **34 本の共通化**（Human 適用済みパッチの監査 trail を壊すため）
- 外部振る舞いの変更（CLI IF・exit code 契約・hook 挙動はすべて不変）
- 新しい抽象レイヤ・DI・プラグイン機構の導入
- テストの検出力を下げる方向の「共通化」（assert の緩和・失敗経路のスキップ）
- 件数 assert を**単に削除**すること（テスト消失を検知できなくなる）

## 受入基準

> issue #1162 の AC-01〜AC-07 をそのまま転記（増減・改変なし）。

- [ ] AC-01: `ta-33` TC-01 が `.claude/agents/*.md` を 1 体増やしても PASS し、**期待集合から
  外れた tier を持つ agent が 1 体でもあれば FAIL** する（変異注入で両方向を実証する）
- [ ] AC-02: `ta-33` TC-03 が `.codex/agents/*.toml` を 1 本増やしても PASS し、**期待 effort と
  異なる toml があれば FAIL** する
- [ ] AC-03: `ta-57` TC-15 が `test_delivery.py` のテストを 1 本追加しても PASS し、**57 本未満に
  減った場合は FAIL** する
- [ ] AC-04: `scripts/ai-loop/` の JSON 読込が `c3_contract.read_json()` へ集約され、各呼び出し
  箇所で**リファクタ前後の挙動が同一**であることをテストで確認済み
- [ ] AC-05: S-2 完了後も `plugin/plangate/skills/ai-loop-cycle/scripts/` の 28 ファイルが同期され、
  **plugin 側のコピー単体で全テストが PASS** する（新規ファイル追加時は
  `sync-plugin-plangate.sh:428/440` の両方を更新）
- [ ] AC-06: `sh tests/run-tests.sh` が変更前と同じ pass 件数以上で PASS（exit 0）
- [ ] AC-07: S-3 の分割要否判断が根拠付きで `handoff.md` に記録されている（実施する / しない の
  いずれでも可）

## Mode 判定

**モード**: `high-risk`（超高ではない）

**判定根拠**（[`.claude/rules/mode-classification.md`](../../../.claude/rules/mode-classification.md) 準拠）:

| 判定軸 | 実測 | モード |
|--------|------|--------|
| 変更ファイル数 | `ta-33` / `ta-57` / `c3_contract.py` + JSON 読込 5 ファイル（うち `c3_contract.py` は重複）＋ plugin 同期反映 → **6〜9 ファイル** | 高（6-15） |
| 受入基準数 | **7**（AC-01〜AC-07） | 高（6-10） |
| タスク数（見込み） | **18**（T-01〜T-18） | 高（11-20） |
| 変更種別 | リファクタリング（振る舞い不変）＋テスト契約の置換 | 高 |
| リスク | 検出力を下げると**テスト消失が無検出になる**（Non-goal に明記） | 高 |
| 影響範囲 | `scripts/ai-loop/` の 5 ファイル + plugin 配布物へ波及 | 高（複数レイヤ） |
| ロールバック | ファイル単位の `git checkout --` で戻せる（計画的に必要） | 高 |
| **最終判定** | 定量・定性ともに「高」 | **high-risk** |

**変更種別軸**: `code`（`.sh` / `.py` を含むため doc-light は不適用）。

**Hardening Override 該当性**: **非該当**。接触予定パスは
`tests/extras/*.sh` / `scripts/ai-loop/*.py` / `plugin/plangate/skills/ai-loop-cycle/scripts/*.py`
（同期生成物）/ `scripts/sync-plugin-plangate.sh` のみで、HO 9 カテゴリ
（`.claude/rules/*.md` / `.claude/settings*.json` / `.claude/commands/*.md` /
`.claude/agents/*.md` / `scripts/hooks/*.sh` / `bin/plangate` / `schemas/*.schema.json` /
`.github/workflows/*.yml|yaml` / `AGENTS.md` `CLAUDE.md`）のいずれにも該当しない。

> ただし `ta-33` は `.claude/agents/*.md` と `.codex/agents/*.toml` を**読み取り対象**に
> するだけで、これらを**編集しない**。変異注入は sandbox コピー上で行い、原本には触れない
> （後述 Assumptions A-03）。

**mode に伴う運用帰結**:

- high-risk のため **autonomous C-3 APPROVE は不可**。人間の C-3 が必須
  （[`working-context.md`](../../../.claude/rules/working-context.md) autonomous APPROVE 判定マトリクス）
- `lite_eligible` = **false**（新規設計はないが high-risk かつ AC が 7 件のため安全側）
- フェーズ適用: C-2 外部レビュー ○ / V-2 ○ / V-3 ○ / V-4 −

## Notes from Refinement

> 判断の正本は `decision-log.jsonl`。ここは要約に留める。

1. **`ta-57` TC-15 は `-ge 57`（下限）で確定**。等値 → 下限へ緩めることでテスト追加は通し、
   テスト**消失**（＝検出力の喪失）は引き続き FAIL にする。`OK` 出力と rc=0 を併せた
   3 条件にすることで「件数だけ満たすが失敗している」状態を除外する。**この方針は人間承認済み**。
2. **`ta-33` は下限ではなく期待集合との照合**にする。理由は下限にすると「未知の tier を持つ
   agent が増えた」ケースを取り逃すため。TC-01 は「全ファイルが期待 tier と一致」＋
   「期待集合の各名がファイルとして存在（＝削除検知）」の双方向、TC-03 は
   「期待 low/medium 集合の各 toml が存在し effort 一致」＋「集合外の toml が存在しない」の
   双方向で測る。
   - 実測補足: TC-03 の `_t33_expect_low`(6) + `_t33_expect_medium`(11) = **17** で、
     期待集合はすでにコード内に存在する。現状 `-eq 17` は「集合外 toml の混入」を間接的に
     検出しているだけであり、集合照合へ置き換えれば**検出力はむしろ上がる**。
   - 同様に TC-01 は全ファイルに `expect` を割り当てているため「tier 不一致」は既に検出済み。
     `-eq 17` が担っていたのは**削除の検知**のみ。
   - ⚠️ **ただし TC-01 は TC-03 と非対称**。TC-03 は期待集合（low 6 + medium 11 = 17）が
     **全 toml を列挙している**ため集合照合で完全に代替できるが、TC-01 の期待集合は
     `_t33_sonnet_set` の **6 体のみ**で、残り 11 体は「集合外＝ inherit 期待」という
     **補集合定義**である。したがって期待集合の存在確認だけでは
     **inherit 期待 11 体の削除を検知できない**。ここは S-1 で唯一検出力が下がる方向の箇所で、
     対処方針（inherit 側も明示列挙する / 相対一致で補う / 既知の限界として `handoff.md` に
     残す）を **plan 段階で決める**。`test-cases.md` T1162-TC-03 に限界として記録済み。
3. **`ta-33` TC-04 は変更しない**。TC-04 は md 件数と toml 件数の**相対一致**（drift 検出）で
   あり絶対件数を持たない。時限爆弾ではないため対象外。
4. **S-2 で新規ファイルを作らない**のは設計上の制約。`sync-plugin-plangate.sh:428/440` の
   二重 allowlist は本 PBI では**リファクタしない**（Out of scope の思想と一貫。allowlist の
   単一定義化自体は別 PBI 候補として V2 に送る）。
5. **S-1 → S-2 の順序は固定**。S-1 未完了で S-2 のテストを増やすと `ta-57` TC-15 が
   無関係に FAIL する。
6. **S-3 は判断のみ**。実施する場合でも本 PBI では着手せず、`handoff.md` に根拠を記録する。

## Estimation Evidence

### Risks

| ID | リスク | 影響 | 緩和 |
|----|--------|------|------|
| R-01 | 件数 assert の置換で**検出力が下がる**（テスト消失・agent 削除を取り逃す） | 高（Non-goal に明示された最悪ケース） | 各 AC に**正側（増やして PASS）と負側（壊して FAIL）の両方**の TC を置き、**変異注入**で kill を実証する |
| R-02 | 変異注入が**空振り**（変異を入れても PASS のまま）で「検出できたつもり」になる | 高 | 変異は**関数ではなく呼び出し箇所（call site）を壊す**形で設計。空振りなら TC の欠陥として正直に記録する |
| R-03 | `read_json()` 集約で**例外の型・メッセージが変わる**（`ValueError` を握っていた箇所が `OSError` を素通しする等） | 高（fail-closed の破壊） | 10 箇所を 1 箇所ずつ、集約前後の例外型・メッセージ・rc を対比表で確認。`discovery.py:182-188` は `OSError` と `JSONDecodeError` を**別メッセージ**で `ValueError` に包み直しており最も差異が大きい |
| R-04 | plugin 側コピー（28 ファイル）が同期されず **plugin 導入先だけ import エラー** | 高（実測 2 の再現） | AC-05 の TC で **plugin 側コピー単体でのテスト実行**を必須にする。`sync-plugin-plangate.sh --dry-run` で差分 0 を確認 |
| R-05 | `sh tests/run-tests.sh` フルスイートが他セッションと並走して不安定（ta-61 の入れ子等） | 中 | 個別スイート（`ta-33` / `ta-57`）を先に実行。フルスイートは並走がない時点で 1 回だけ実行し、pass 件数を**下限**で比較（AC-06 の「同じ pass 件数以上」） |
| R-06 | `-ge 57` の下限値自体が将来 stale になる（テストが増えた後に大量削除されても 57 以上なら通る） | 中 | 下限は「現時点の実測値」であり、増加時に引き上げる運用を `handoff.md` に明記。**測定環境とセットで baseline を記録**する |
| R-07 | high-risk のため人間 C-3 が必須で、承認待ちがボトルネックになる | 低 | plan / todo / test-cases を先に確定し、C-1 / C-2 を通してから 1 回で承認を取る |

### Unknowns

| ID | 不明点 | 解消方法 |
|----|--------|----------|
| U-01 | 10 箇所の JSON 読込のうち、**`read_json()` に寄せられない箇所**が何件あるか（`errors="replace"` 指定や schema 読込など前提が異なる可能性） | S-2 着手時に 10 箇所の呼び出し文脈（例外処理・encoding・後続の型検査）を一覧化して判定。寄せられない箇所は理由を記録して**据え置く**（無理に統一しない） |
| U-02 | `read_json()` の**シグネチャ**（例外を投げるか / デフォルト値を返すか / `ValueError` に包むか） | 呼び出し 10 箇所の要求の**最大公約数**を実測してから決める。fail-closed を壊さない形を優先 |
| U-03 | `tests/hooks/run-tests.sh` の EH ブロック 13 個が**独立実行可能**か（共有 fixture / 順序依存の有無） | S-3 の調査で `grep` により共有変数・順序依存を実測。依存があれば「分割しない」判断の根拠にする |
| U-04 | フルスイート（`sh tests/run-tests.sh`）の**変更前 pass 件数 baseline** | 並走がない時点で 1 回実行して記録（測定日時・ホストとセットで）。AC-06 の比較基準になる |
| U-05 | `test_delivery.py` に S-2 で追加するテストが**何本**になるか（`-ge 57` の下限を引き上げるべきか） | S-2 完了後に実測。下限は据え置き（57）で運用し、引き上げは別途判断 |

### Assumptions

| ID | 前提 |
|----|------|
| A-01 | issue #1162 の AC-01〜AC-07 は**確定**であり、本 PBI で増減・改変しない |
| A-02 | `ta-57` TC-15 の `-ge 57`（下限）方針は**人間承認済み**であり再検討しない |
| A-03 | 変異注入は **sandbox（`mktemp -d` 上の複製）**で行い、`.claude/agents/` / `.codex/agents/` / `scripts/ai-loop/` の**原本には一切書き込まない**。テスト終了時に明示削除する |
| A-04 | HO 対象パス（`.claude/**` / `scripts/hooks/**` / `bin/plangate` / `schemas/**` / `.github/workflows/**` / `CLAUDE.md` / `AGENTS.md`）は**読むだけで編集しない** |
| A-05 | `plugin/plangate/skills/ai-loop-cycle/scripts/` は `scripts/ai-loop/` からの**同期生成物**であり、直接編集せず `sync-plugin-plangate.sh` 経由で更新する |
| A-06 | 外部振る舞い（CLI IF・exit code 契約・hook 挙動）は**すべて不変**。振る舞いを変える必要が生じたら即停止して人間判断を仰ぐ |
| A-07 | `.claude/agents/*.md` は現在 18 ファイル（README.md を含む）、README を除くと 17。`.codex/agents/*.toml` は 17（本セッションで再実測） |
| A-08 | S-1 は S-2 の前提であり、着手順序を入れ替えない |

## 実測の再確認（本セッション）

| 項目 | 確認コマンド | 結果 |
|------|--------------|------|
| `sync-plugin-plangate.sh` の二重 allowlist 行番号 | `grep -n 'AI_LOOP_SCRIPTS_DIR/arbiter.py'` と `grep -n 'arbiter.py\|test_arbiter.py'` を `scripts/sync-plugin-plangate.sh` に対して実行 | **428** / **440**（issue 記載と一致） |
| plugin 配布ファイル数 | `ls plugin/plangate/skills/ai-loop-cycle/scripts/` の件数 | **28** |
| JSON 読込箇所 | `grep -n "json.loads("` を `scripts/ai-loop/` の実装 7 ファイルに対して実行 | 1 行形式 **9 箇所**（`c3prime_verify` 1 / `delivery` 2 / `run_evidence_verify` 3 / `run_evidence` 3）＋ `discovery.py:182,186` の **2 行形式 1 箇所** = **計 10 箇所 / 5 ファイル**（issue 記載と一致） |
| `tests/hooks/run-tests.sh` 行数 | `wc -l tests/hooks/run-tests.sh` | **754**（issue 記載と一致） |
| agent 件数 | `.claude/agents/*.md` と `.codex/agents/*.toml` の件数 | **18**（README 込み）/ **17** |

> 差異が 1 点あった: issue の「`sys.path.insert` の byte-identical 重複は 7 箇所」は、
> 本セッションの実測（`scripts/ai-loop/` 全体で `sys.path.insert` 行を集計）では
> **`sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))` が 13 箇所 /
> `sys.path.insert(0, str(HERE))` が 11 箇所**（＋文字列リテラル内 1）だった。
> `sys.path.insert` は本 PBI の In scope に含まれない（S-2 は JSON 読込のみ）ため
> AC には影響しないが、背景記述としての数値は上記実測を正とする。
