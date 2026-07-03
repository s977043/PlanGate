# 用語・ラベル改称 移行 grep チェックリスト（正本）

> Issue: [#690](https://github.com/s977043/plangate/issues/690)
> 関連: [#499](https://github.com/s977043/plangate/issues/499)（L-0 カスタム静的解析 false-positive canary）/
> [#684](https://github.com/s977043/plangate/issues/684)（repo guard 標準提供、ドリフト系事故の再発防止という同系統の摩擦）/
> [`versioning-stability-policy.md`](./versioning-stability-policy.md) §5 移行ガイド

## 1. 目的

用語・ラベル改称（例: mode ラベル `full` → `high-risk`）を含むリリースで、
**旧表記の残存**が下流リポジトリで検出されず、PR レビュー bot の指摘 →
修正 という同型ループが反復している摩擦を、移行手順の定型化で解消する。

実例: 8.11.0 の L-9（`full` → `high-risk` 改称）を下流（PocketEitan）に
同期した際、正規表現で拾いにくい **短縮系の旧表記**（bare `high`:
「最低 high」「モード: high」等）が rules / docs の 6 ファイルに残存し、
PR レビュー bot に 4 件指摘された（PocketEitan #479）。

本 doc は [`versioning-stability-policy.md`](./versioning-stability-policy.md) §5
移行ガイド（`[BREAKING]` / `[MIGRATION REQUIRED]` の手順必須化）を**補完**する。
バージョニングポリシー側は「移行手順を書くこと」を要求し、本 doc は
「用語・ラベル改称の移行手順に何を書くか」の定型フォーマットを提供する。

## 2. 改称時の必須チェックリスト

用語・ラベル改称を含むリリースでは、以下を CHANGELOG エントリまたは
`docs/migration/<version>.md`（[`versioning-stability-policy.md`](./versioning-stability-policy.md) §5
の配置基準に従う）に同梱する。

- [ ] **完全形**の grep パターン（例: `full`）
- [ ] **短縮系**の grep パターン（例: bare `high` — 「最低 high」「モード: high」等、
      改称後語の一部が旧語と衝突しない形での拾い方）
- [ ] **活用形**の grep パターン（例: 日本語の場合「〜化」「〜済み」等の接尾辞付き、
      英語の場合の複数形・動詞化）
- [ ] **日本語文中埋め込み**の grep パターン（助詞・句読点に挟まれた旧語。
      単語境界 `\b` が日本語では機能しないため、前後文脈込みでパターン化する）
- [ ] 正本ファイル（例: `mode-classification.md`）に新旧表記の混在がないことの確認
      （正本の混在はモード判定・ルール解釈のゆらぎに直結するため最優先で確認する）
- [ ] 上記パターンをまとめた **1 コマンドで流せる grep コマンド**を CHANGELOG /
      migration note に明記する

## 3. 正規表現テンプレート

### 3.1 単語境界の扱い

英語表記は `\b<旧語>\b` で単語境界を使えるが、**短縮系・複合語には効かない**。
例えば `full` → `high-risk` 改称では `\bfull\b` は `full` を検出できても
`high-risk` の短縮形として書かれた bare `high`（`high` 単体で `full` 相当の
意味を持つ旧慣習表記）は別パターンとして拾う必要がある。改称対象語と
「意味が重なるが表記が異なる同義語・略語」を洗い出す作業を grep パターン
設計の前段に必ず入れる。

```sh
# 完全形（英語、単語境界あり）
rg -n '\bfull\b' --type md

# 短縮系（例: bare "high" が旧 "full" の意味で使われている箇所）
rg -n '(最低|モード)[：:]?\s*high\b' --type md
```

### 3.2 日本語文中での拾い方の注意

日本語は分かち書きされないため `\b` が機能しない。旧語が名詞・形容動詞・
接尾辞付きでどう現れるかを列挙し、**前後の助詞・記号を含めたパターン**で
拾う。誤検出を避けるため、コードブロック内の identifier（意図的な旧語
言及）は後述 §4 の false-positive ガードで除外する。

```sh
# 日本語文中埋め込み（例: 「〜full〜」のような形で埋め込まれる場合）
rg -n 'full(化|済み|モード|表記)' --type md
```

## 4. 下流での使い方

下流リポジトリ（consumer）は、上流の CHANGELOG / migration note に
記載された grep パターンをそのまま実行するだけで残存検出できる。

```sh
# migration note に記載されたコマンドをコピーして実行するだけ
rg -n '\bfull\b|(最低|モード)[：:]?\s*high\b|full(化|済み|モード|表記)' \
  --type md -- . ':(exclude)CHANGELOG.md'
```

ヒットした行を目視確認し、意図的な旧語言及（CHANGELOG の履歴、
このチェックリスト自体のような説明目的の言及）を除外した上で、
実質的な残存箇所のみを修正する。

## 5. false-positive ガード

[#499](https://github.com/s977043/plangate/issues/499)（L-0 カスタム静的解析の
false-positive canary 必須化）の考え方に準拠し、以下を検出対象から除外する:

- glob 表記・ファイルパス内の一致（例: `docs/ai/*.md` のような glob 文字列内の語）
- CHANGELOG / 移行ガイド内の意図的な旧語言及（履歴として残す記述）
- 「除外注記」内での旧語言及（例: `arbiter/除く` のような、正規化済みだが
  説明のため旧語を含む注記。§6 の実例参照）
- コードコメント内で明示的に「旧名称」と注記された箇所

除外判定に迷う場合は **誤検出として除外せず、いったん人間確認に回す**
（安全側。見逃しの方が「同型ループの再発」という実害に直結するため）。

## 6. 今セッションの実例

`arbiter` → `ai-loop` 改称（#673）の移行作業で、`docs/ai/*.md（arbiter/除く）`
のような**除外注記自体に含まれる旧語**が 2 箇所取り残され、後続 PR で
検出・修正した。この種の取りこぼしは「本文中の旧語」だけを狙う grep では
拾えず、「除外条件を記述した注記文」まで対象に含める必要があることを示す
実例である。機械 grep パターンに §3 のテンプレートを適用していれば
初回反映時点で検出できたはずのケース。

## 7. doctor への将来拡張（follow-up 候補）

issue #690 の要望 2（`plangate doctor` への改称済みラベル残存検出の追加、
直近リリースで改称された語のみを対象にした軽量チェック）は、
**本 doc のスコープ外**として follow-up 候補に留める。`bin/plangate` は
Hardening Override 対象（[`mode-classification.md`](../../.claude/rules/mode-classification.md)
の HO 対象パス）であり、機械チェック実装には別 PBI（Standard・同期 C-3）を
要するため、ここでは提案の記録のみ行う。CHANGELOG 側は、用語・ラベル改称を
含むリリースで本 doc を参照する運用とする（例: `[MIGRATION REQUIRED]` タグの
エントリから `docs/ai/migration-grep-checklist.md` へのリンクを張る）。

## 8. 参照

- [`versioning-stability-policy.md`](./versioning-stability-policy.md) — Breaking Change 定義・CHANGELOG 影響度タグ・移行ガイド配置基準
- [`mode-classification.md`](../../.claude/rules/mode-classification.md) — 改称実例（`full` → `high-risk`）が生じた判定基準の正本
- [#499](https://github.com/s977043/plangate/issues/499) — L-0 false-positive canary（本 doc §5 の除外判断の準拠先）
- [#684](https://github.com/s977043/plangate/issues/684) — repo guard 標準提供（宣言と実装の乖離という同系統の再発防止課題）
