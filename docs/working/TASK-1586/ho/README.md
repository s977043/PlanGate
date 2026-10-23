# #1586 HO 適用スクリプト（Human 実行用）

> スクリプト本体（`apply-ci-cost.sh` / `apply-claude-agents-md.sh`）は、`PLANGATE_SKIP_REASON` を付けて起動したセッションで、このディレクトリに追加する（handoff.md §1）。本書は手順と検証の正本。

## 目的

#1586（保守コスト調査）で見つけた改善のうち、Hardening Override（HO）対象パスに当たる 2 件を Human が適用するためのスクリプト。

| スクリプト | 対象 | 変更内容 |
| --- | --- | --- |
| `apply-ci-cost.sh` | `.github/workflows/ci.yml` / `.github/workflows/codeql.yml` | ci.yml に `changes` job を追加し、`shell-lint` / `workflow-lint` / `interactive-feedback-tests` / `interactive-browser-e2e` の 4 job を「`.md` 以外の変更がある」ときだけ実行する。codeql.yml は `pull_request` に `paths-ignore: '**/*.md'` を追加する |
| `apply-claude-agents-md.sh` | `CLAUDE.md` / `AGENTS.md` | CLAUDE.md: 16 行目（約 2900 文字ある 1 行）を要約 1 行に縮め、18-27 行目の前に「## 機能索引（v8.6〜v8.9 初出）」を置き、24 行目の「物理配線 6/12」を `docs/ai/hook-enforcement.md:28` に合わせて 11/12 に直し、連続する空行を詰める。AGENTS.md: 45-49 行目の「Codex CLI 固有参照」節を 36 行目の後ろ（Codex 固有参照節の直後）へ移し、元の位置からは削除する |

変えないもの:

- `test.yml`: `.md` だけの変更でも落ちうる検査（ta-77 など）を含むため、skip すると偽の緑になる
- ci.yml のトリガー
- `settings-drift` / `skip-ack` / `markdown` の 3 job
- Codex CLI 節の文面: 「EH-1/2/3/6/9 物理発火」の記述が矛盾している疑いは、2026-10-19 のユーザー判断 a に従い、事実を照合したうえで別 issue で扱う
- CLAUDE.md の `<law>` と「承認境界の適用順」節: `--verify` で BASE と完全一致することを確認する

## 前提

- `BASE_SHA=5fcdb2e3279aed1cf8a02416d5e48bab5a3b191f` のコミットがローカルにあること。無ければ `git fetch origin` で取得する
- 対象 4 ファイルの内容が、BASE と同じ（未適用）か生成後と同じ（適用済み）であること。どちらでもなければ、何も書かずに止まる
- `main` 以外の作業ブランチで実行すること。`main` 上では書き込みを拒否する
- 対象ファイル以外に、tracked で未コミットの変更が無いこと（例外: `docs/working/_audit/skip-decision-log.jsonl`）
- `python3` と `shasum` が使えること。`--verify` は PyYAML も使う。`actionlint` は入っていれば使い、無ければ skip する

## 実行コマンド

repo のルートで、2 本を**1 本ずつ**適用する。1 本適用したら commit してから次に進む。続けて実行すると、2 本目の dirty ガードで止まる。

```sh
sh docs/working/TASK-1586/ho/apply-ci-cost.sh --dry-run      # 差分を表示するだけ
sh docs/working/TASK-1586/ho/apply-ci-cost.sh --apply        # 書き込んだあと --verify も実行する
git add .github/workflows/ci.yml .github/workflows/codeql.yml && git commit
sh docs/working/TASK-1586/ho/apply-claude-agents-md.sh --dry-run
sh docs/working/TASK-1586/ho/apply-claude-agents-md.sh --apply
git add CLAUDE.md AGENTS.md && git commit
```

スクリプトは commit も push もしない。

## `--verify` の期待出力

`apply-ci-cost.sh --verify`（rc=0）:

```text
  state  .github/workflows/ci.yml = applied
  state  .github/workflows/codeql.yml = applied
  ok  .github/workflows/ci.yml = 生成後内容（sha256 一致）
  ok  .github/workflows/codeql.yml = 生成後内容（sha256 一致）
  ok  YAML parse / job 条件 / required check 名 / codeql trigger
  ok  ta-71 TC-13b 前提（'  shell-lint:' 行）
  ok  actionlint
VERIFY: PASS
```

`apply-claude-agents-md.sh --verify`（rc=0）:

```text
  state  CLAUDE.md = applied
  state  AGENTS.md = applied
  ok  CLAUDE.md = 生成後内容（sha256 一致）
  ok  AGENTS.md = 生成後内容（sha256 一致）
  ok  <law> / 承認境界の適用順 = BASE 完全一致・最新リリース節 1 個・機能索引・11/12・Codex CLI 節
  info CLAUDE.md 66 行 / AGENTS.md 46 行
VERIFY: PASS
```

未適用の状態で実行すると `VERIFY: FAIL (n)` を出し、rc=1 で終わる。

## ロールバック

```sh
sh docs/working/TASK-1586/ho/apply-ci-cost.sh --rollback
sh docs/working/TASK-1586/ho/apply-claude-agents-md.sh --rollback
```

`--rollback` は、内容が生成後と同じファイルだけを BASE の内容へ戻す。

- `--apply` も `--rollback` も、まず全ファイルを一時ファイルへ書き、そのあと mv で置き換える。途中で失敗したら、置き換え済みのファイルを元に戻す
- 復元そのものが失敗した場合は、失敗したパスを表示して非ゼロで止まる
- 同名の一時ファイル（`*.pg1586.tmp`）が既にあれば、書き込まずに止まる
- 退避コピーは一時ディレクトリに置くため、SIGKILL や電源断で途中終了すると残らない。その場合は `git checkout -- <対象ファイル>` で戻す（BASE が HEAD にある前提）
- dirty ガードは、porcelain 出力のパス部分（4 文字目以降）を除外リストと完全一致で比べる
- BASE とも生成後とも違うファイルが 1 つでもあれば、何も書かずに止まる
- commit した後なら `git revert <commit>` でも戻せる

## 生成方式（決定的変換を選んだ理由）

生成後の内容は、`git show BASE_SHA:<path>` を入力とする決定的な変換（python）で作る。生成結果の sha256 はスクリプトに固定してあり、一致しなければ止まる。

- heredoc で全文を持たせると、CLAUDE.md の `<law>` と承認境界の節を**写し直す**ことになり、写し間違いがあっても気づきにくい。変換方式なら、これらの節は BASE の内容のまま一切触らずに通る
- `<law>`（閉じタグ `</law>` まで含む）と承認境界の節が BASE と一致することは、**生成結果の sha256 を固定することで担保**している。`--verify` が節ごとに比べる処理は二重化であり、sha256 が一致している限り、独立した検出力は持たない。sha256 ごと書き換えるような改変に対する二段目の防御という位置づけ
- 入力は SHA で固定されているので、出力は毎回同じになる。sha256 も固定しているので、変換コードが壊れれば検出できる
- 変換の前に、アンカー（行の内容と件数）が想定どおりかを確かめる。想定と違えば止まる

## 影響範囲

- **plugin への影響はなく、version bump も不要**: 対象 4 ファイルはどれも `plugin/` の配布物ではない
- **ai-loop の `corpus_hash` が変わる**: CLAUDE.md / AGENTS.md の内容が変わるため。以後の ai-loop run は新しいハッシュになるので、前後の run を比べるときは注意する
- **required check の `Markdown lint` は止まらない**:
  - required check は ruleset 14939019 の `Markdown lint` 1 件だけ（strict）
  - `markdown` job は `needs` も `if` も持たない（`--verify` で確認する）。ci.yml のトリガーにも paths 条件を付けていない
  - そのため `.md` だけの PR でも毎回実行され、pending のまま残って merge できなくなることはない
  - skip する 4 job は required ではない。CodeQL の `paths-ignore` も、required ではない check にしか効かない
- **迷ったら実行側に倒す（job を skip しない）**:
  - `changes` job は、push イベントのとき・差分を取れなかったとき・差分が空のときに `code=true` を返す
  - 4 job の条件は `${{ !cancelled() && (needs.changes.result != 'success' || needs.changes.outputs.code != 'false') }}`。`changes` job 自体が失敗・skip しても 4 job は実行される。skip されるのは、`changes` が成功して `code=false` を返したときだけ
  - `always()` ではなく `!cancelled()` にしたのは、concurrency の cancel-in-progress で取り消された run で 4 job が走り続けないようにするため
  - rename は `--no-renames` で旧パスも数えるので、`x.sh → x.md` のような rename では skip されない
  - パスは `core.quotePath=false` で出力するので、非 ASCII のファイル名でも `.md` の判定が正しく効く
- **`HEAD^1` の前提は検証済み**: depth 2 で clone した PR の merge commit では `HEAD^1` が base になり、`HEAD^1..HEAD` は topic 側の差分になる（敵対レビューで実走して確認した）
- **`tests/fixtures/apply-baseline/workflows/ci.yml` は追従させない**: 凍結したスナップショットだから。ta-71 TC-13b は ci.yml に `  shell-lint:` の行が残っていれば緑になり、この変更でも行は残る（`--verify` で確認する）
- CLAUDE.md / AGENTS.md は、ta-77 の承認面台帳の対象外

## Scorecard（判断材料のみ。本スクリプトでは変えない）

- 観測（2026-10-08〜10-17）: Scorecard は push で 42 run 走っているうえ、週次の cron もある。push での実行は冗長かもしれない
- push トリガーを外した場合: run 数と Actions の使用時間が減る。一方で結果の更新は週 1 回になり、branch protection などの設定変更が反映されるまで最大 1 週間かかる
- そのまま残した場合: main へ merge するたびにスコアが更新される。1 run は短いので、コストは小さい
- 未確認: Scorecard の 1 run の所要時間と、OpenSSF の公開スコアが push トリガーに依存しているかどうか
