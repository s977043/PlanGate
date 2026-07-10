# plugin / repo-local 間のスキル名多重定義の検出と優先順位ガイダンス

> Issue [#692](https://github.com/s977043/plangate/issues/692) 実装。
> 関連: [#566](https://github.com/s977043/plangate/issues/566)（skill-policy-router）/
> [#514](https://github.com/s977043/plangate/issues/514)（skills SSoT 整理）/
> [#691](https://github.com/s977043/plangate/issues/691)（stale パス参照検出・姉妹ツール）

## 目的

複数 plugin（plangate / growth-core / river-review 等）と repo-local
`.claude/skills/` を併用する環境では、同名・同目的の skill / command /
agent が多重定義されうる。エージェントのスキル選択が曖昧になり、どの定義が
実際に起動したか利用者にも追跡できない。skill-policy-router（#566）は
ルーティング（Intent/Mode → 必要 Skill の解決）を担うが、多重定義そのものの
**検出・可視化**の仕組みはこれまで無かった。

### 実例（interactive-ocean の資産棚卸し・2026-07-03）

- `self-review`: repo-local（12 フェーズ版）/ growth-core / plangate の
  **3 重定義**（plangate 版は diff-audit への改名で解消。repo-local /
  growth-core 側は本 PBI の対象外・実例としての記録は保持する）
- `setup-team`: repo-local / growth-core / plangate / river-review の
  **4 重定義**（さらに repo-local には command ラッパーも存在。plangate 版は
  内容乖離 53%（170/318 行）で「同名で中身が別物」に該当したため
  `subagent-team-design` への改名で解消 — #800。repo-local / growth-core /
  river-review 側は本 PBI の対象外・実例としての記録は保持する）
- `iterative-quality-review`（repo-local）と plangate の review-gate 系も
  目的が重複

利用者が「/self-review」と言うだけでは、どの実装が起動するかはスキル一覧の
掲載順や `description` のマッチ次第になっている。PocketEitan での「3 層
乖離」問題（本体 / plugin / repo コピーのバージョンずれ）と同根で、plugin
配布化後の二重管理が名前空間衝突として顕在化した形。

## 使い方

```sh
# デフォルト（.claude/{skills,commands,agents} + plugin/*/{skills,commands,agents}）を検査
python3 scripts/check-skill-name-collisions.py

# 追加のベースディレクトリ（.claude/ と plugin/ を配下に持つパス）を含めて検査
python3 scripts/check-skill-name-collisions.py --extra-root /path/to/another-checkout

# 内蔵の自己テスト
python3 scripts/check-skill-name-collisions.py --selftest
```

### 出力例

```text
合計 41 件の name 多重定義を検出

| kind | name | 定義元 | description 差分 |
|------|------|--------|------------------|
| skill | self-review | repo-local(.claude/skills/self-review/SKILL.md), plugin:plangate(plugin/plangate/skills/self-review/SKILL.md) | なし |
    - repo-local: 変更内容に対して詳細なセルフレビューを実施し、構造化されたレポートを出力する。...
    - plugin:plangate: 変更内容に対して詳細なセルフレビューを実施し、構造化されたレポートを出力する。...
| skill | intent-classifier | repo-local(...), plugin:plangate(...) | あり |
    - repo-local: ユーザーの依頼文から開発 Intent を 8 分類し、structured JSON で返す。...
    - plugin:plangate: ユーザーの依頼文から開発 Intent を 7 分類し、structured JSON で返す。...
```

### exit code

| code | 意味 |
|------|------|
| 0 | 衝突なし |
| 1 | 衝突あり（表を標準出力に出力） |
| 2 | 引数エラー・実行時エラー |

## 検出方法

以下のルートを走査し、`(kind, name)` の組が **異なる定義元ラベル**
（`repo-local` / `plugin:<plugin-name>`）に複数存在する場合を衝突とする:

| kind | 対象パス | name の取得元 |
|------|---------|--------------|
| skill | `<root>/<skill-name>/SKILL.md` | frontmatter `name:`（無ければディレクトリ名） |
| command | `<root>/*.md` | frontmatter `name:`（無ければファイル名） |
| agent | `<root>/*.md` | frontmatter `name:`（無ければファイル名） |

走査ルート: `.claude/skills` / `.claude/commands` / `.claude/agents`
（repo-local）と `plugin/*/skills` / `plugin/*/commands` / `plugin/*/agents`
（各 plugin）。`--extra-root` で他リポジトリのチェックアウトを追加走査
できる。

## false-positive 配慮: description 差分の有無

**本リポジトリ自身が plangate plugin の配布元**であるため、
`.claude/skills/*` と `plugin/plangate/skills/*` の多くは意図的な export
ミラー（同一内容）である。これを「解消すべき衝突」として同列に警告すると
ノイズになるため、各衝突に **description 差分の有無** を付記する:

| description 差分 | 意味 | 対応の目安 |
|------------------|------|-----------|
| **なし** | 意図的なミラー（plugin export と repo-local 正本が同一）の可能性が高い | 通常は Reuse（そのままでよい）。ドリフト防止のため sync フローの正本性のみ確認 |
| **あり** | 実体が乖離している、または独立した別実装である可能性 | Extend/Skip の棚卸しが必要（下記チェックリスト） |

実走した結果（2026-07-03 時点、参考値・本 PBI では解消しない）:
41 件の多重定義のうち 37 件は description 差分なし（意図的な export
ミラー）、4 件（`context-load` / `intent-classifier` /
`codex-multi-agent` 等）に description 差分ありを検出した。

## 優先順位規約（衝突時の解決指針）

1. **repo-local を正本とする**。plugin 版が repo-local と異なる場合、
   repo-local の内容が最新の意図を反映している前提で棚卸しを行う
   （本リポジトリでは repo-local が plugin export の正本ソースである
   ため。他リポジトリで repo-local が薄いラッパーのみの場合はこの限り
   でない — その場合は個別に判断する）。
2. **同名でも目的が異なる場合は namespace 明示を検討する**。
   skill-policy-router（#566）のルーティング表で明示的にどの定義を使うか
   固定できる場合はそちらを優先し、命名衝突自体は許容してよい。
3. **判断不能な場合は Standard 扱い**（mode-classification.md の
   AC-8 安全側原則と一貫）: 自動解消せず、棚卸しチェックリストで人間判断
   を仰ぐ。

### Reuse / Extend / Skip 棚卸しチェックリスト

衝突が検出されたら、各 `(kind, name)` について以下を確認する:

- [ ] **Reuse**: description が実質同一 → plugin 側をそのまま使い、
      repo-local を維持する（現状維持）
- [ ] **Extend**: repo-local にだけ必要な案件固有差分がある
      → 差分を明示コメントで残し、plugin 版との乖離理由を記録する
- [ ] **Skip（統合）**: repo-local の存在意義が薄い（plugin 版で十分）
      → repo-local 側を削除し plugin 版に一本化する
- [ ] いずれの場合も、**「どの定義が実際に呼ばれるか」** を
      skill-policy-router のルーティング表または個別ドキュメントに明示する

## doctor / L-0 / CI への配線について

本スクリプトはスタンドアロンの静的解析ツールとして提供する。
`bin/plangate doctor` への組み込みは Hardening Override 対象パス
（`bin/plangate`）に触れるため、承認境界周辺の変更として **別 PBI の
follow-up** とする（[`.claude/rules/mode-classification.md`](../../.claude/rules/mode-classification.md)
の Hardening Override 対象パス、[`.claude/rules/responsibility-classes.md`](../../.claude/rules/responsibility-classes.md)
の責務 4 分類を参照）。姉妹ツール `scripts/check-stale-skill-refs.py`
（#691）と同様、本 PBI はスタンドアロン検出スクリプトの提供までとする。

## 関連

- Issue [#692](https://github.com/s977043/plangate/issues/692)（本ドキュメントの実装元）
- Issue [#566](https://github.com/s977043/plangate/issues/566)（skill-policy-router — Intent/Mode → 必要 Skill 解決のルーティング正本）
- Issue [#514](https://github.com/s977043/plangate/issues/514)（skills SSoT 整理 — 配置ゆらぎの解消）
- Issue [#691](https://github.com/s977043/plangate/issues/691)（stale パス参照検出。同じ `scripts/` 直下・frontmatter 解析・selftest 付きの実装スタイルを踏襲）
- [`docs/ai/stale-ref-detection.md`](./stale-ref-detection.md)（姉妹ツールのドキュメント構成の手本）
