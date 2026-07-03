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

これに加えて、空白を含む文字列（自然文の一部と誤認しうる）や、拡張子も
スラッシュも持たない単語はそもそもパス候補として扱わない
（`looks_like_repo_path` 関数）。

### 既知の限界（本 PR のスコープ外・将来課題）

実行時にリポジトリへ実走した結果、以下の非 stale なパターンが誤検出され
うることを確認した（本 PR では既存の stale 参照を修正しないため、これらは
スコープ外の参考情報として記録するのみ）:

- `.gitignore` 対象ファイル（例: `.claude/settings.json`）は「テンプレート
  上は実在すべきだがローカル checkout には無い」ケースがあり、単純な
  ファイルシステム実在確認では stale と区別できない
- 地の文（説明文）中の例示パス（例: 「`app/admin` 配下で〜」のような自然な
  日本語文中のバッククォート引用）は、プレースホルダキーワードを含まない
  限りパス候補として拾われる

これらは doctor / L-0 配線時に精度を高める余地として次項に記録する。

## doctor / L-0 / CI への配線について

本スクリプトはスタンドアロンの静的解析ツールとして提供する。
`bin/plangate doctor` への組み込みや CI ワークフローでの定期実行は
Hardening Override 対象パス（`bin/plangate` / `.github/workflows/*.yml`）
に触れるため、承認境界周辺の変更として **別 PBI の follow-up** とする
（[`.claude/rules/mode-classification.md`](../../.claude/rules/mode-classification.md)
の Hardening Override 対象パス、[`.claude/rules/responsibility-classes.md`](../../.claude/rules/responsibility-classes.md)
の責務 4 分類を参照）。

## 関連

- Issue [#691](https://github.com/s977043/plangate/issues/691)
- Issue [#499](https://github.com/s977043/plangate/issues/499)（L-0 カスタム静的解析の canary 必須化）
- Issue [#684](https://github.com/s977043/plangate/issues/684)（doctor の repo guard 標準提供）
