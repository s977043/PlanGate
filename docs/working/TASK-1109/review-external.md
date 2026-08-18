# REVIEW (V-3 相当 / 外部レビュー) — TASK-1109 (#1109)

> 対象ブランチ: `origin/fix/1109-skill-spec-presence-check` / head `c0df5b0`
> 差分: `git diff origin/main..c0df5b0` = 38 files / +1353 / -36
> レビュー worktree: `/Users/user/Documents/GitHub/plangate/.claude/worktrees/agent-a8e1bceac41980776`
> 判定枠: [`.claude/rules/review-principles.md`](../../../.claude/rules/review-principles.md) §2〜4（5 観点 / 4 段階）
> レビューは**読み取り + 一時変異のみ**。実装ファイルは変更していない（変異はすべて復元済み・`git status` clean）。

## VERDICT

**REJECT**（critical=0 / **major=3** / minor=2 / info=2）

`--warn-only` の rc 契約回復・presence の同値照合・traceback 除去・変異注入の記録は
いずれも妥当で、#1109 の主目的（「見ていないのに緑」の除去）は**明示 target 経路では達成**
されている。ただし **CI が実際に通る「既定 target 経路」の検出力が 1 件もテストされておらず**、
`#1086` が `.codex/skills` を untrack した瞬間に検査範囲が半減しても全経路が緑のまま通る。
これは本 issue が潰そうとしているクラスの再生産であるため major とする（R-001 / R-003）。
加えて TC-10 が絶対件数 `ignored=1` を契約値にしており、skills root に非ディレクトリを
1 つ足すだけで**無関係 PR の Test CI が赤になる**（R-002）。

## 指摘一覧

### R-001 — 既定 target の片方不在が violation にならず、TC も存在しない（major / 保守性・拡張性）

`inspect()` は既定 target の不在を violation にせず `SKIPPED` を print するだけで、
`inspected_targets` も増やさない。もう片方が生きていれば `inspected_targets>=1` なので
「1 つも検査できなければ violation」ガードにも掛からない。結果、**#1086 が
`.codex/skills` を untrack した後、検査母数が 78 → 39 に半減しても rc=0・ta-68 も 12/12 PASS**
になる。`plan.md` §Risks は「既定 target の不在は violation にしない」と意図的な設計だと
述べ、`test-cases.md` エッジケース表は「TC 化は #1086 側」と先送りしているが、
**この PR 側にも #1086 側にも「既定 root が消えたことを気づく仕組み」が無い**。
`ta-68` TC-09 は `plugin/plangate/skills` の出現しか見ておらず、`.codex/skills` が
既定から消えても PASS する。

実測（変異 M-A: 既定 root の片方を不在パスに差し替え＝#1086 後の状態を再現）:

```
$ sh scripts/check-codex-skill-spec.sh
[spec-check] SKIPPED default target: .../.codex/skills-MUTANT-ABSENT — reason: directory absent (0 skills inspected)
[spec-check] .../plugin/plangate/skills: SKILL.md dirs=39 openai.yaml dirs=39 ... ignored=1
[spec-check] Checked 39 skills across 1 target(s)
[spec-check] All skills PASS spec check
rc=0

$ sh tests/extras/ta-68-skill-spec-presence.sh
TA-68 standalone: 12 passed, 0 failed   ← 検査範囲が半減しても誰も気づかない
```

推奨対応（いずれか）:

1. 既定 root の一覧を **宣言として固定**し、「宣言された既定 root のうち検査できたもの」の
   集合が宣言集合と一致しない場合は violation にする（不在にするなら宣言側の 1 行削除＝
   意識的なコード変更を強制する）。
2. 最低限、`ta-68` に **「既定出力に `.codex/skills` と `plugin/plangate/skills` の
   両方が現れる」TC** を足す（`ignored=1` のような絶対件数は使わず、root 名の出現で照合）。
   これなら #1086 で root を落とす人が必ずこの TC を通り、意識的に更新する。

### R-002 — TC-10 が絶対件数 `ignored=1` を契約値にしており、無関係 PR の CI を落とす（major / 保守性）

`ta-68` TC-10 は実リポジトリ既定出力に対し `ignored=1` と
`ignored: README.md — reason:` の**両方**を要求する。`ignored` は
`plugin/plangate/skills` 直下の非ディレクトリ数であり、運用で増減する。
`.github/workflows/test.yml` は `pull_request` で `sh tests/run-tests.sh` を回すため、
**skills root に doc を 1 枚足しただけの無関係 PR が赤になる**。
`plan.md` §Constraints は「**絶対件数（39/35/8）を契約値にしない**」を自ら制約に挙げており、
TC-10 はその制約に対する自己矛盾。

実測:

```
$ printf 'tmp\n' > plugin/plangate/skills/ZZZ-tmp-note.txt
$ sh tests/extras/ta-68-skill-spec-presence.sh
  [FAIL] TC-10 skip の件数・理由が出力されていない: ... ignored=2 ...
TA-68 standalone: 11 passed, 1 failed
```

出力自体は正しい（`README.md` と `ZZZ-tmp-note.txt` を両方 reason 付きで列挙している）。
落ちているのは**テストの契約値だけ**＝典型的な時限爆弾。

推奨対応: `ignored=1` の照合を外し、`ignored: README.md — reason:` の行が出ること
（＝理由付き出力が機能していること）だけを見る。件数を見たいなら
`ignored=<N>` の N を出力から取り、`ignored:` 行の件数と**同値照合**する。

### R-003 — 既定経路（CI が実際に通る経路）の検出力が 1 件もテストされていない（major / テスト品質）

負側 TC（TC-03 欠落 / TC-04 orphan / TC-07 不在 / TC-11 field）はすべて `--target` 経由で、
`explicit=True` の分岐しか通らない。既定経路（`explicit=False`）を通る TC は
TC-02（rc=0）/ TC-09（出力に文字列を含む）/ TC-10（ignored 出力）だけで、
**いずれも「検出できること」を確認していない**。よって既定経路の検出ロジックだけを
壊す変異が生き残る。

実測（変異 M-B: presence 判定を `explicit` のときだけ有効にする）:

```python
-    for name in missing:
+    for name in (missing if explicit else []):
```

```
$ sh tests/extras/ta-68-skill-spec-presence.sh
TA-68 standalone: 12 passed, 0 failed   ← 既定経路の presence 検査を殺しても生存
```

ワーカーが報告した M-1/M-2/M-3 はいずれも kill を確認できているが、
**M-1（silent skip 復活）は TC-03＝`--target` 経路で kill されている**ため、
この穴は既存の変異セットでは露出しない。

推奨対応: 既定経路を通る負側 TC を 1 本追加する。実リポジトリを汚さずに行うには、
既定 root を差し替える seam（例: `PLANGATE_SPEC_DEFAULT_ROOTS` のようなテスト専用 env、
または fixture repo を `REPO_ROOT` に見せる呼び出し）を用意し、
そこで「欠落を検出して rc=1」を確認する。R-001 の対応 1 とセットで実装すると seam を共有できる。

### R-004 — 既定 2 root の basename が両方 `skills` で、violation 行から root を特定できない（minor / 可読性）

`label = os.path.basename(target.rstrip('/'))` は `.codex/skills` も
`plugin/plangate/skills` も `skills` になる。summary 行はフルパスを出すが、
violation 行は `skills/<name>` 形式のため**どちらの root の違反か区別できない**。
検出器の主目的が「何を見て何が駄目だったか」を確定させることなので、影響は小さくない。

実測（同名 basename の 2 root を明示指定して再現）:

```
$ sh scripts/check-codex-skill-spec.sh --target <tmp>/a/skills --target <tmp>/b/skills
[spec-check] VIOLATIONS (2):
  - skills/foo: agents/openai.yaml missing (SKILL.md exists)
  - skills/foo: agents/openai.yaml missing (SKILL.md exists)
```

推奨対応: `label` を `REPO_ROOT` からの相対パス（`.codex/skills` /
`plugin/plangate/skills`）にする。衝突が消え、grep 可能な識別子になる。

### R-005 — field 検査が部分文字列一致のみで、新たに既定 target にした配布物 root では icon が実在しない（minor / 保守性）

`check_fields` の icon 検査は `'icon_small' not in content` の部分文字列判定で、
値もパス実在も見ない。本 PR で既定 target に加えた `plugin/plangate/skills` は
**`assets/` を 1 つも持たない**（実測: `find plugin/plangate/skills -maxdepth 2 -name assets -type d | wc -l` → `0`、
`find plugin/plangate/skills -name plangate-small.svg | wc -l` → `0`）が、
39 件すべてが `icon_small: "./assets/plangate-small.svg"` を宣言し、検査は PASS する。

**この指摘は部分的に反証済み**: `plugin/plangate/scripts/install-plangate-skills.sh:227-233` が
install 時に `plugin/plangate/assets/plangate-small.svg` を各 skill の `assets/` へコピーするため、
install 経路では実在する。したがって「壊れている」とは断定しない。
一方 `plugin/plangate/.codex-plugin/plugin.json` は `"skills": "./skills/"` を宣言しており、
**この root をそのまま読む marketplace 経路で icon が解決するかは本レビューでは判定不能**。
スクリプト冒頭コメントが `plugin/plangate/skills` を
「配布物（marketplace 経路がそのまま読む実体）」と定義している以上、
「All skills PASS」の意味範囲を明確にすべき。

推奨対応（follow-up issue で可・本 PR のブロッカーにしない）: icon 値のパス実在検査を足すか、
既定 target の説明に「icon は install 時に materialize される前提で値の存在のみ検査する」と明記する。

### R-006 — 呼び出し元は本 PR 後 3 経路（`ta-68` が PR ブロック経路として増える）。plan F-7 の記述が古くなる（info）

独立実行した `grep -rn "check-codex-skill-spec"` の非 docs ヒットは、
`plan.md` F-7 の主張どおり main 時点では
`.github/workflows/sync-plugin-plangate.yml:73` と `tests/extras/ta-30-install-skills.sh` の
2 経路のみで**正しい**。ただし本 PR で `tests/extras/ta-68-*.sh` が 3 経路目になり、
`.github/workflows/test.yml`（`on: pull_request` → `sh tests/run-tests.sh`）経由で
**PR 段階のブロック経路**になる。これは実質的な強化であり歓迎すべきだが、
`plan.md` / `status.md` の「呼び出し元 2 経路」記述は本 PR 後の実態と食い違う。

推奨対応: F-7 に「本 PR 後は ta-68 を含む 3 経路。PR ブロックは test.yml 経由の ta-68 が担う」と追記。

### R-007 — patch 適用後も sync workflow の spec check は PR では走らない（info）

`0001-drop-warn-only-from-sync-workflow.patch` が触る step は
`sync` job（`if: github.event_name != 'pull_request'`）の中にあり、
かつ workflow の `paths` filter 配下に限られる。したがって patch 適用後も
**この経路の強制力は post-merge のみ**。R-006 の ta-68 経路が PR 側を担保しているため
実害は小さいが、「`--warn-only` を外せば PR で止まる」と読める記述があれば是正すべき。

## 重点レビュー項目 1〜7 の判定

| 項目 | 判定 | 該当指摘 |
|------|------|---------|
| 1. 既定 target 2 root 化の帰結（#1086 後） | **指摘あり** | **R-001（major）** / R-003（major） |
| 2. 生成物の情報損失 | **問題なし**（棄却根拠は下記） | — |
| 3. `ta-68` の検出力 / `ta-61` 契約準拠 | **指摘あり**（契約準拠は問題なし） | **R-002 / R-003（major）** |
| 4. 非機能（実行時間・ハング） | **問題なし** | — |
| 5. 呼び出し元の全数 | **問題なし**（doc の鮮度のみ） | R-006（info） |
| 6. Human 適用待ち patch の妥当性 | **問題なし** | R-007（info） |
| 7. 一般的な落とし穴 | **指摘あり** | **R-002（major）** / R-004 / R-005 |

## 独自変異と結果

| 変異 | 内容（call site） | 期待 | 実測 |
|------|-----------------|------|------|
| **M-A**（本レビュー） | 既定 `TARGETS` の 1 行目を不在パスへ差し替え（#1086 後の状態を再現） | `ta-68` のいずれかが FAIL | **12 passed, 0 failed（生存）** → R-001 |
| **M-B**（本レビュー） | `for name in missing:` → `for name in (missing if explicit else []):`（既定経路の presence 検査だけ無効化） | `ta-68` のいずれかが FAIL | **12 passed, 0 failed（生存）** → R-003 |
| **M-C**（本レビュー・非注入） | TC-10 を壊さずに skills root へファイル 1 枚追加 | TC-10 は本来 PASS すべき | **TC-10 FAIL（11 passed, 1 failed）** → R-002 |

いずれも実施後に `cp <backup> scripts/check-codex-skill-spec.sh` で復元し、
`git status --short` が clean であることを確認済み。

## 実行時間の実測（修正前後）

| 対象 | 検査母数 | real（3 回計測） |
|------|---------|----------------|
| `origin/main` の `check-codex-skill-spec.sh --warn-only` | 39 skills / 1 root | 0.10 / 0.06 / 0.05 s |
| 本 PR の `check-codex-skill-spec.sh`（引数なし） | **78 skills / 2 root** | **0.08 / 0.03 / 0.03 s** |
| `ta-68` standalone（12 TC・script を 7 回起動） | — | 0.43 s |
| `ta-30` + `ta-68` harness 相当（21 TC） | — | < 1 s |

**母数 2 倍でも実行時間は改善**（`open()`→`os.path.isfile()` 化とループ構造の整理による）。
`test.yml` / `sync-plugin-plangate.yml` の `timeout-minutes: 10` に対して十分な余裕があり、
ネットワーク I/O・無限ループ・外部コマンドの追加は無い。**ハング・時間の穴は無し**。

## 反証を試みて棄却した指摘候補

| 候補 | 棄却根拠（実測） |
|------|----------------|
| `.codex` 8 件の `--force` 再生成で手書き description が失われた | 旧値も `install-plangate-skills-to-codex.sh` による**機械切り詰め**（`…「De` / `…dispatch す` のように語中で切れている）。手書き資産ではない。差分は `short_description` の 1 行のみで、`display_name` / `icon_*` / `default_prompt` / `brand_color` は不変（`git diff origin/main..HEAD -- .codex/skills`） |
| 2 root 間で `openai.yaml` が乖離した | `diff -rq .codex/skills plugin/plangate/skills` は **main 時点で全 39 件が既に差分あり**（`.codex` は生成物・`plugin` は手書き）。本 PR 由来ではない |
| 配布物の icon パスが dangling で実害 | `install-plangate-skills.sh:227-233` が install 時に assets を materialize する。marketplace 直読み経路のみ**判定不能**として R-005（minor）へ降格 |
| 新規 4 件が既存 34 件と粒度不揃い | 既存の手書き英語 description（例: `Audit a change diff across review phases before PR`）と同形式・25–64 文字レンジ内。`brand_color` を含め 6 field 揃い。**問題なし** |
| 新規 openai.yaml が `sync-plugin-plangate.sh` に上書きされ drift-check が落ちる | `.agents/skills` に `openai.yaml` は **0 件**（同期対象外）。`sh scripts/sync-plugin-plangate.sh --dry-run` → `Sync complete — no changes` / rc=0。**問題なし** |
| `ta-68` が `ta-61` の extras 契約に非準拠で `run-tests.sh` を落とす | marker 1 個（2 行目）/ `pg_extra_contract_init ta-68-skill-spec-presence standalone-capable` 一致 / 末尾 `pg_extra_contract_finalize` / 7 env unset / `register_cleanup` + 明示 `rm -rf`。`PG_T61_NO_RECURSE=1 sh tests/extras/ta-61-extra-contract.sh` → **82 passed, 0 failed / rc=0**。standalone・harness 相当の両方で 12/12 PASS。**問題なし** |
| 実行時間・ハングの劣化 | 上表のとおり改善。**棄却** |
| `orphan-yaml` の扱いが未定義 | `inspect()` で `yaml_dirs - skill_dirs` を violation にし、TC-04 が rc=1 と文言を照合。**定義済み・TC あり** |
| `ignored`（`README.md` 等）の除外が恣意的で検査を狭める | 除外条件は「dotfile」「非ディレクトリ」「SKILL.md も openai.yaml も無い」の 3 つのみで、いずれも**件数と理由を必ず print** する。片側だけ持つものは除外されず violation になる。**問題なし**（ただし件数の契約化は R-002） |
| 行番号アンカーの使用 | `test-cases.md` 冒頭が「行番号ではなく関数名 `inspect` / `check_fields` で参照する」と明記し、実際に本文へ行番号アンカーは無い。**問題なし** |

## 検証コマンドと exit code

| コマンド | rc |
|---------|---:|
| `sh scripts/check-codex-skill-spec.sh` | 0 |
| `sh tests/extras/ta-68-skill-spec-presence.sh`（standalone） | 0（12 passed, 0 failed） |
| harness 相当（`ta-30` + `ta-68` を source） | 0（21 passed, 0 failed） |
| `PG_T61_NO_RECURSE=1 sh tests/extras/ta-61-extra-contract.sh` | 0（82 passed, 0 failed） |
| `git apply --check docs/working/TASK-1109/patches/0001-*.patch` | 0 |
| `sh scripts/sync-plugin-plangate.sh --dry-run` | 0（no changes） |
| M-A 適用後 `sh scripts/check-codex-skill-spec.sh` | **0**（想定外の緑 → R-001） |
| M-A 適用後 `sh tests/extras/ta-68-*.sh` | **0**（12 passed → R-001） |
| M-B 適用後 `sh tests/extras/ta-68-*.sh` | **0**（12 passed → R-003） |
| skills root にファイル 1 枚追加後 `sh tests/extras/ta-68-*.sh` | **1**（TC-10 FAIL → R-002） |

`sh tests/run-tests.sh`（フルスイート）は指示により**実行していない**（`ta-61` の入れ子再実行で並走が壊れるため）。

## 監査表

> **反映は 1 回確定**（`Refs: R-001 R-002 R-003 R-004 R-005 R-006 R-007`）。
> `reflected_in` は確定反映コミットで変更した実体を記す（SHA は同コミットの
> `Refs:` 行から辿る。squash/rebase 耐性のため SHA を本表の一次キーにしない）。

| R-NNN | status | reflected_in | notes |
|-------|--------|--------------|-------|
| R-001 | **accepted / fixed** | `scripts/check-codex-skill-spec.sh`（`DEFAULT_TARGETS` 宣言 + `inspect()` の不在判定）/ `ta-68` TC-15・TC-16 / `plan.md` §4 | 指摘どおり。**既定 root の不在も violation** に変更（fail-closed）。#1086 で `.codex/skills` を外すときは宣言から 1 行削除＝意識的なコード変更を強制。**M-A 再注入で TC-02/13/16 が FAIL（kill）を実測** |
| R-002 | **accepted / fixed** | `ta-68` TC-10 | 指摘どおり自己矛盾。`ignored=1` の照合を撤去し、**reason 行の存在 + summary `ignored=<N>` 合計と `ignored:` 行数の同値照合**に置換。**skills root にファイル 1 枚追加しても 17/17 PASS（summary=2 rows=2）を実測** |
| R-003 | **accepted / fixed** | `ta-68` TC-13・TC-14（fixture repo seam）/ `plan.md` §4-bis | 指摘どおり負側 TC が全て `--target` 経由だった。テスト専用 env は増やさず、**script を fixture repo へ複製して `REPO_ROOT` を移す**ことで既定経路をそのまま実行（新 API 面ゼロ）。**M-B 再注入で TC-14 が FAIL（kill）を実測** |
| R-004 | **accepted / fixed** | `scripts/check-codex-skill-spec.sh` の `root_label()` / `ta-68` TC-17 | `label` を REPO_ROOT 相対パス化（repo 外は絶対パス）。同名 basename の 2 root で violation 行が一意になることを TC-17 が照合 |
| R-005 | **accepted (partial) / documented** | `scripts/check-codex-skill-spec.sh` 冒頭コメント / `plan.md` F-10・Q-4 | レビューア自身が「install 経路では materialize されるため断定しない」と部分反証済。**コード変更はせず**、検査が「値の宣言のみを見る」ことを明記し、marketplace 直読み経路の解決可否は**判定不能**として Q-4（follow-up）へ。本 PR のブロッカーにしないという推奨に従う |
| R-006 | **accepted / fixed** | `plan.md` F-7 / `status.md` | 「main 時点で 2 経路」は正しく、本 PR 後に `ta-68` が 3 経路目（`test.yml` 経由の PR ブロック）になる旨を追記 |
| R-007 | **accepted / fixed** | `plan.md` F-9 / `patches/0001-*.patch` ヘッダ | `sync` job は `github.event_name != 'pull_request'` 配下のため patch 適用後も **post-merge のみ**。PR 側の強制は `ta-68` × `test.yml` が担うことを明記 |

### 棄却 0 件

本レビューの 7 指摘はいずれも実測が添えられており、**反証に成功したものは無い**。
R-005 のみ「コード修正ではなく仕様の明文化」で応じた（レビューア推奨と一致）。
