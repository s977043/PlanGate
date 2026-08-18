# repo-owned skill/command/agent の stale パス参照検出

> Issue [#691](https://github.com/s977043/plangate/issues/691) 実装。
> false-positive canary ガイドライン: [`docs/plangate.md`](../plangate.md) #499 節。
> 関連: [#684](https://github.com/s977043/plangate/issues/684)（doctor の repo guard 標準提供）

## 目的

repo-owned の `.claude/skills/` / `.claude/commands/` / `.claude/agents/` は
特定のファイルパスやシンボルを参照して書かれるが、コードベースのリファクタ
リング後に誰も更新せず陳腐化することがある。参照先が barrel 化・分割・改名
されても skill/command/agent 自体は「動く」ため、静かにレビュー精度が落ち
続け、棚卸しするまで発覚しない。

### 実例（interactive-ocean リポジトリ）

2026-07-03 に資産棚卸しを実施したところ、2026-04-09 作成のレビューコマンド
7 件が、Phase 1-3 再設計（2026-06-27 の PR #185-#194）で barrel 化・分割済み
の旧パス（`JellyfishSwarm.tsx` / `simulation.ts` 直参照）を約 2 ヶ月間指した
ままだった。うち 1 件（dev-lead-review）は「JellyfishSwarm.tsx の肥大化」と
いうレビューの中心課題自体が解消済みで、前提ごと崩れていた。発見は
improvement-architect による手動棚卸しで、機械的検出があれば即日気付けた
（修正: interactive-ocean PR #200）。

## 使い方

```sh
# デフォルト（.claude/skills, .claude/commands, .claude/agents 配下の *.md）を検査
python3 scripts/check-stale-skill-refs.py

# 対象を明示指定する場合
python3 scripts/check-stale-skill-refs.py ".claude/skills/**/*.md"

# 内蔵の false-positive ガード自己テスト
python3 scripts/check-stale-skill-refs.py --selftest
```

### 出力例

```text
WARN .claude/skills/hypothesis-logger/SKILL.md:9 → 非実在パス: ../../docs/workflows/07_exploratory_debug.md
合計 1 件の stale パス参照を検出
```

### exit code

| code | 意味 |
|------|------|
| 0 | stale パス参照なし |
| 1 | stale パス参照あり（WARN を標準出力に列挙） |
| 2 | 引数エラー・実行時エラー |

## 検出方法

対象 Markdown を 1 行ずつ走査し、以下 2 パターンからパス候補を抽出する:

- Markdown リンク `](path)` の `path` 部分
- インラインコード `` `path` `` の中身

候補が `src/` / `docs/` / `scripts/` / `.claude/` / `schemas/` / `bin/` /
`app/` / `lib/` / `tests/` / `test/` のいずれかで始まる、または `./` /
`../` の相対パス表記であればリポジトリ内パス参照とみなし、リポジトリルート
基準（相対パスは参照元ファイル基準）で実在確認する。実在しなければ WARN。

## false-positive ガード（#499 準拠）

以下は非実在でも WARN 対象から除外する。理由をコメントで明示している
（`scripts/check-stale-skill-refs.py` の `is_excluded` 関数）:

| 除外種別 | 例 | 理由 |
|---------|----|------|
| glob 表記 | `config/*.ts`, `docs/**/*.md` | ワイルドカードは実在確認の対象外（`*`/`?` を含む） |
| プレースホルダ・例示 | `<repo-root>/src/index.ts`, `path/to/file.ts`, `{{TASK_ID}}/plan.md` | 説明用の仮パスであり実パスではない（`<` `>` `{` `}` `...` や `path/to` / `example` / `foo` / `bar` / `xxxx` を含む文字列） |
| URL | `https://github.com/...` | ファイルシステムパスではない |
| アンカーのみ | `#section` | ファイルパスを伴わない見出しアンカー |
| **gitignore 対象パス** | `.claude/settings.json` | **リポジトリに存在しないことが正常**（各利用者がローカル生成する）。`git check-ignore` のバッチ結果で判定する（#1087。`is_excluded` ではなく `gitignored_paths` + `run_scan` 側で除外し、件数を `INFO:` として印字する） |

これに加えて、空白を含む文字列（自然文の一部と誤認しうる）や、拡張子も
スラッシュも持たない単語はそもそもパス候補として扱わない
（`looks_like_repo_path` 関数）。

また **インラインコードスパンの中に書かれた Markdown リンク記法**は
リンクとして抽出しない（#1087。`extract_candidates` がコードスパンを
マスクしてから `MD_LINK_RE` を適用する）。

### 既知の限界（#691 起票時点・**#1087 で解消済み**）

> **本節は履歴。ここに挙げた 2 件はいずれも
> [判定の是正（#1087）](#判定の是正1087)で解消した。**
> 現行の挙動は #1087 の節を正とする。

#691 起票時、以下の非 stale なパターンが誤検出されうることを確認していた:

- ~~`.gitignore` 対象ファイル（例: `.claude/settings.json`）は「テンプレート
  上は実在すべきだがローカル checkout には無い」ケースがあり、単純な
  ファイルシステム実在確認では stale と区別できない~~
  → **#1087 で `git check-ignore` による除外を導入して解消**。
  同時に、判定が実行環境（settings.json の有無）に依存していた問題も解消した
- ~~地の文（説明文）中の例示パス（例: 「`app/admin` 配下で〜」）は、
  プレースホルダキーワードを含まない限りパス候補として拾われる~~
  → **#1087 で解消。ただし検査側に除外条件を足すのではなく、
  ドキュメント側をプレースホルダ表記に直した**（検出力を削らないため。
  理由は「判定の是正（#1087）」節の
  「3 つ目の除外条件を足さず、ドキュメント側を直した」を参照）

## doctor / L-0 / CI への配線について

本スクリプトはスタンドアロンの静的解析ツールとして提供する。
`bin/plangate doctor` への組み込みや CI ワークフローでの定期実行は
Hardening Override 対象パス（`bin/plangate` / `.github/workflows/*.yml`）
に触れるため、承認境界周辺の変更として **別 PBI の follow-up** とする
（[`.claude/rules/mode-classification.md`](../../.claude/rules/mode-classification.md)
の Hardening Override 対象パス、[`.claude/rules/responsibility-classes.md`](../../.claude/rules/responsibility-classes.md)
の責務 4 分類を参照）。

## 判定の是正（#1087）

> issue [#1087](https://github.com/s977043/plangate/issues/1087) で、上記
> 「既知の限界」に挙げた 2 点のうち検出器側の欠陥に当たるものを是正した。

### B-1: markdown リンク抽出の前にコードスパンをマスクする

従来は `MD_LINK_RE` を行の生テキストに適用していたため、**インライン
コードスパンの内側**に書かれたリンク（例: diff-audit スキルの
「`` `[file.md](./file.md)` `` 形式でリンク化し」）を実リンクとして拾って
いた。これは*記法の説明*であって参照ではない。是正後はコードスパンを先に
マスクしてからリンクを抽出する。コードスパンの**中身**を候補として収集する
挙動は従来どおり変更しない。

- 見逃しクラス **S-1**: コードスパンの内側にリンク記法として書かれた
  stale パス。レンダリング結果はリンクではなく単なる文字列であるため、
  検出しないことが意図された挙動である。

### B-2: gitignore 対象パスを除外する

`.claude/settings.json` は `.gitignore` で無視され、各利用者がローカルで
生成するファイルであるため、存在しないことが正常である。旧実装は
`Path.exists()` のみを見ていたため、判定が**環境依存**になっていた
（CI / クリーンな clone では警告 7 件、settings wiring を適用済みの端末では
2 件）。開発者がローカルで再現できない CI failure を生む挙動であり、検出器
としての要件を満たさない。是正後は候補パスをまとめて 1 回の
`git check-ignore --stdin` に通して判定する。

- **デグレード時の挙動**: git が利用不可、または想定外の exit code を返した
  場合は**何も除外しない**（＝従来の挙動に戻る）。安全側であり、チェックを
  緩める方向には決して倒れない。
- 見逃しクラス **S-2**: gitignore パターンに一致し、**かつ**実際に誤って
  いる参照。本リポジトリの `.gitignore` はほぼ明示的なパス列挙であるため
  範囲は狭い（例: `.claude/settingz.json` のような typo はどの ignore
  パターンにも一致せず、引き続き検出される）。
- 除外した件数は黙って捨てず、`INFO:` 行として件数と本ドキュメントへの
  参照を出力する。

### 3 つ目の除外条件を足さず、ドキュメント側を直した

検出された 1 件は `.claude/skills/codex-multi-agent/SKILL.md` の
`app/admin` で、派遣プロンプトの例文の中で**例示**として使われていた。
ここで「引用文の中は見ない」という除外条件を足すと、検出力を恒久的に下げた
うえに新しい見逃しクラスを作ることになる。そこでドキュメント側を
プレースホルダ（`<対象ディレクトリ>`）に変更した。これは既存の
プレースホルダガードが既に除外する形式であり、**チェッカーには新たな除外
条件を一切追加していない**。同じ修正を `.agents/skills/`（plugin export の
供給元）にも適用し、`sh scripts/sync-plugin-plangate.sh` で配布側へ伝播した。

### 実測スナップショット（2026-08-18 時点・base `387ea21`）

契約値ではなく、その時点の計測値として記録する:

- 検出 7 件は**すべて**チェッカー側またはドキュメント側の欠陥に分類され、
  真の stale 参照は 0 件だった
- 是正後は rc=0 を返す

## 関連

- Issue [#691](https://github.com/s977043/plangate/issues/691)
- Issue [#499](https://github.com/s977043/plangate/issues/499)（L-0 カスタム静的解析の canary 必須化）
- Issue [#684](https://github.com/s977043/plangate/issues/684)（doctor の repo guard 標準提供）
