# Evidence: stale パス参照 7 件の全件分類（TASK-1087 / AC-2）

> 測定日: 2026-08-18 / base: `origin/main` = `387ea21`
> 実行: `python3 scripts/check-stale-skill-refs.py`（引数なし = 既定経路）

## issue 記載値との差（重要）

issue #1087 は **2 件**と記載しているが、実測は **7 件**だった。

```
WARN .claude/skills/codex-multi-agent/SKILL.md:62  → 非実在パス: app/admin
WARN .claude/skills/diff-audit/SKILL.md:260        → 非実在パス: ./file.md
WARN .claude/skills/intent-classifier/SKILL.md:71  → 非実在パス: .claude/settings.json
WARN .claude/skills/plangate-setup/SKILL.md:44     → 非実在パス: .claude/settings.json
WARN .claude/skills/plangate-setup/SKILL.md:62     → 非実在パス: .claude/settings.json
WARN .claude/skills/plangate-setup/SKILL.md:65     → 非実在パス: .claude/settings.json
WARN .claude/skills/plangate-setup/SKILL.md:131    → 非実在パス: .claude/settings.json
合計 7 件の stale パス参照を検出
```

**差分 5 件はすべて `.claude/settings.json`。** このファイルは
`.gitignore:14` で ignore されており、リポジトリには存在しない
（各利用者が `sh scripts/apply-claude-settings.sh` でローカル生成する）。

```
$ git check-ignore -v .claude/settings.json
.gitignore:14:.claude/settings.json    .claude/settings.json
```

**つまり本検査の結果は実行環境に依存していた**:

| 環境 | `.claude/settings.json` | 検出件数 |
|------|------------------------|---------|
| CI / fresh clone | 無い | **7** |
| wiring 済みの開発機 | 有る | **2** |

issue 起票時（2026-08-13）は settings.json を持つ環境で測られたと推定される。
**「開発者がローカルで再現できない CI 失敗」を生む状態**であり、
検知器としての適格性そのものの問題。本 PBI で解消した。

## 全件分類

| # | 参照元 | 参照文字列 | 実体 | 判定 | 対応 |
|---|--------|-----------|------|------|------|
| 1 | `.claude/skills/codex-multi-agent/SKILL.md:62` | `app/admin` | 派遣プロンプトの**例示**: 「\`app/admin\` 配下でこの UI に関係する既存パターンを 3 点探して報告する」 | **引用・例示**（参照ではない） | **ドキュメント側を修正**（検査は弱めない）→ `<対象ディレクトリ>` に置換。既存の placeholder ガードが効く |
| 2 | `.claude/skills/diff-audit/SKILL.md:260` | `./file.md` | **記法の説明**: 「\`\`\`[file.md](./file.md)\`\`\` 形式でリンク化し」 | **検査側のバグ**（コードスパン内のリンク記法をリンクとして抽出していた） | **検査を修正** → コードスパンをマスクしてから `MD_LINK_RE` を適用 |
| 3 | `.claude/skills/intent-classifier/SKILL.md:71` | `.claude/settings.json` | gitignore 対象。存在しないことが正常 | **検査側のバグ**（存在しないことが正常なパスを stale 扱い） | **検査を修正** → `git check-ignore` で除外 |
| 4 | `.claude/skills/plangate-setup/SKILL.md:44` | `.claude/settings.json` | 同上 | 同上 | 同上 |
| 5 | `.claude/skills/plangate-setup/SKILL.md:62` | `.claude/settings.json` | 同上 | 同上 | 同上 |
| 6 | `.claude/skills/plangate-setup/SKILL.md:65` | `.claude/settings.json` | 同上 | 同上 | 同上 |
| 7 | `.claude/skills/plangate-setup/SKILL.md:131` | `.claude/settings.json` | 同上 | 同上 | 同上 |

**真の stale 参照: 0 件。**

## `app/admin` を検査側で除外しなかった理由

「引用（「…」）の中は見ない」という除外条件を検査に足せば #1 は消せる。
しかしそれは **検出力を恒久的に削る**判断であり、見逃しクラス
（引用内にだけ現れる真の stale 参照）を新設する。

一方 #1 の本質は「**参照と例示が機械的に区別できない書き方をしている**」という
ドキュメント側の欠陥である。プレースホルダ表記に直せば意図が機械可読になり、
**検査の除外条件を 1 つも増やさずに解決する**。

`.claude/skills/` は Hardening Override 対象外
（`mode-classification.md` の注記に明記）であり AI が修正可能。
`.agents/skills/`（plugin export の正本）側も同時に修正し
`sh scripts/sync-plugin-plangate.sh` で `plugin/plangate/` へ反映した。

## 是正後

```
$ python3 scripts/check-stale-skill-refs.py
INFO: 5 件は gitignore 対象パスのため除外（存在しないことが正常。docs/ai/stale-ref-detection.md 参照）
OK: 65 ファイルを検査し stale パス参照なし
rc=0
```

除外した 5 件は **INFO として印字される**（黙って消さない）。
何を見なくなったかが出力から読めない状態は #1109 と同型の false green を生むため。
