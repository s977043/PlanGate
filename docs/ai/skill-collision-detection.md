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

真の衝突がある場合（`rc=1`）。repo-local ⇄ plugin のミラーは衝突ではなく
`INFO:` 節に回る（[配布ミラーの扱い（#1087）](#配布ミラーの扱い1087)）:

```text
合計 1 件の name 多重定義を検出

| kind | name | 定義元 | description 差分 |
|------|------|--------|------------------|
| skill | self-review | repo-local(.claude/skills/self-review/SKILL.md), plugin:growth-core(...), plugin:plangate(...) | あり |
    - repo-local: 変更内容に対して詳細なセルフレビューを実施し、...
    - plugin:growth-core: commit 単位の手順チェックリスト。...
    - plugin:plangate: 変更内容に対して詳細なセルフレビューを実施し、...

INFO: 46 件は repo-local ⇄ plugin export のミラー（正常。判定は docs/ai/skill-collision-detection.md を参照）
      対の内容一致: agent/command は sync-plugin-plangate.yml の drift-check job が担保。skill は .agents/skills が plugin の正本のため .claude/skills との parity は未担保（既知ギャップ）
    - agent acceptance-tester: repo-local(.claude/agents/acceptance-tester.md), plugin:plangate(plugin/plangate/agents/acceptance-tester.md)
    - ...
```

衝突が無い場合は 1 行目が `OK: 衝突なし` になり、`INFO:` 節はそのまま続く。

### exit code

| code | 意味 |
|------|------|
| 0 | 衝突なし |
| 1 | 衝突あり（表を標準出力に出力） |
| 2 | 引数エラー・実行時エラー |

## 検出方法

以下のルートを走査し、`(kind, name)` の組に **定義が 2 つ以上** 存在する
グループを多重定義候補として抽出する。そのうち
[配布ミラー](#配布ミラーの扱い1087)と判定されたものを除いた残りが衝突（`rc=1`）:

> **#1087 以前は「異なる定義元ラベルに複数存在する場合」を条件としていた。**
> この条件には 2 つの問題があった:
> (a) repo-local ⇄ plugin の**正常な配布ミラー**をすべて衝突として報告する、
> (b) **同一ルート内の重複**（`.claude/skills/a/` と `.claude/skills/b/` が
> 両方 `name: x` を宣言する等）は distinct なラベルが 1 つしかないため
> **原理的に検出できない**。条件を「2 つ以上」に変えたことで (b) を新たに
> 検出できるようになり、(a) はミラー分類で解消した。

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

> **#1087 で位置づけが変わった。** 本節は当初「ミラーも衝突として報告しつつ
> description 差分を付記して読み手に判断を委ねる」という設計だったが、
> #1087 でその付記を **実際の分類**（rc に反映される accepted mirror）へ
> 昇格させた。以下の表は **ミラー内の drift を人が読むときの目安**として
> 引き続き有効だが、**rc の判定条件ではない**
> （判定条件は [配布ミラーの扱い（#1087）](#配布ミラーの扱い1087)）。

**本リポジトリ自身が plangate plugin の配布元**であるため、
`.claude/skills/*` と `plugin/plangate/skills/*` の多くは意図的な export
ミラー（同一内容）である。各ミラーには **description 差分の有無** を付記する:

| description 差分 | 意味 | 対応の目安 |
|------------------|------|-----------|
| **なし** | 意図的なミラー（plugin export と repo-local 正本が同一）の可能性が高い | 通常は Reuse（そのままでよい）。ドリフト防止のため sync フローの正本性のみ確認 |
| **あり** | 実体が乖離している、または独立した別実装である可能性 | Extend/Skip の棚卸しが必要（下記チェックリスト） |

実走した結果（**2026-07-03 時点の参考値。契約値ではなく、以降の実測で更新される**）:
41 件の多重定義のうち 37 件は description 差分なし（意図的な export
ミラー）、4 件（`context-load` / `intent-classifier` /
`codex-multi-agent` 等）に description 差分ありを検出した。

> **最新の実測は本ページ末尾の「実測スナップショット（2026-08-18 時点）」
> を参照**（46 件すべてがミラー / description 差分は 3 件で、
> `intent-classifier` は解消し `ai-loop-cycle` が新たに該当）。
> 上記 2026-07-03 の値は履歴として残す。

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

## 同名スキルの取り込み・改名ポリシー（#800）

> issue [#800](https://github.com/s977043/plangate/issues/800) の Human 判断
> （2026-07-10）を正本化。growth-core と残存する同名スキル 4 件
> （brainstorming / systematic-debugging / setup-team / codex-multi-agent）
> の扱いを決定した際の一般化ポリシー。

1. **新規取り込みは別名必須**。上流（growth-core 等）から新規にスキルを
   取り込む場合は、衝突を未然に防ぐため元のスキル名をそのまま使わず
   別名を付ける。**Use when トリガも上流と意図的に差別化**し、どちらが
   起動するか曖昧にしない（`ref-integrity-scan` / `diff-audit` 取り込み
   時に適用済みのパターン）。
2. **既存衝突は改名を基本**とするが、**内容乖離が小さく名前が適切であれば
   現状維持可**。無理に改名しない。判断は**乖離実測**（行数差分・
   description 差分・トリガ差分）を根拠に個別に行う。
3. **維持と判定した分も、上流乖離が拡大すれば改名へ再判定**する
   （fork 再棚卸しトリガ — 四半期 or 上流 minor 版更新時 — と連動）。

### #800 個別裁定（実例）

| skill | 乖離実測 | 裁定 | 根拠 |
|---|---|---|---|
| `systematic-debugging` | 2%（6/260 行） | 現状維持 | 実質同一コピー。改名は参照更新コストのみで益なし |
| `brainstorming` | 20%（81/401 行・description 同一） | 現状維持 | 目的同一（PBI INPUT PACKAGE 昇華）。乖離分は PlanGate WF 接続の差 |
| `codex-multi-agent` | 12%（69/581 行・description ほぼ同一） | 現状維持 | 共通運用スキルとして同一起源、環境言及の差のみ |
| `setup-team`（plangate 版） | **53%**（170/318 行・116 行 vs 202 行・トリガも相違） | **改名**（→ `subagent-team-design`） | 同名で中身が別物＝#692 の本来の問題（起動先により挙動が変わる）に該当 |

維持 3 件は本表を記録として保持し、上流乖離が拡大したら再判定する
（上記トリガ条件参照）。

## doctor / L-0 / CI への配線について

本スクリプトはスタンドアロンの静的解析ツールとして提供する。
`bin/plangate doctor` への組み込みは Hardening Override 対象パス
（`bin/plangate`）に触れるため、承認境界周辺の変更として **別 PBI の
follow-up** とする（[`.claude/rules/mode-classification.md`](../../.claude/rules/mode-classification.md)
の Hardening Override 対象パス、[`.claude/rules/responsibility-classes.md`](../../.claude/rules/responsibility-classes.md)
の責務 4 分類を参照）。姉妹ツール `scripts/check-stale-skill-refs.py`
（#691）と同様、本 PBI はスタンドアロン検出スクリプトの提供までとする。

## 配布ミラーの扱い（#1087）

> issue [#1087](https://github.com/s977043/plangate/issues/1087) で判定条件を
> 是正。**本リポジトリ自身が plangate plugin の配布元**であるという前提を、
> 注記ではなく判定ロジックへ落とし込んだ。

### なぜミラーを衝突としないか

`plugin/<p>/` は手書きの第 2 定義ではなく、
`scripts/sync-plugin-plangate.sh` が生成する**配布コピー**である。したがって
repo-local ⇄ plugin の同名ペアは「名前を奪い合う 2 つの独立定義」ではなく
「1 つの定義とその配布コピー」であり、[`.claude/rules/hybrid-architecture.md`](../../.claude/rules/hybrid-architecture.md)
（補足: 本リポジトリにおける Rule 3 / Rule 4 の適用範囲）でも正常な状態と
宣言済みである。

本ドキュメント冒頭の実例（interactive-ocean の `self-review` が repo-local +
growth-core + plangate の**供給元 3 者**で定義されていたケース）は、
これとは**別クラス**であり、引き続き検出対象とする。

### ミラー判定条件

以下を**すべて**満たすときのみ、通常のミラーとして扱う:

- 定義数がちょうど 2 件
- 一方の定義元ラベルが `repo-local`
- 他方が単一の `plugin:<p>`
- 走査ルート内の相対パスが一致する（例: 双方とも `foo/SKILL.md`）

### 引き続き検出するクラス（rc=1）

| クラス | 例 |
|--------|----|
| 定義が 3 件以上 | repo-local + plugin-a + plugin-b（#692 の元となった動機ケース） |
| plugin 同士の同名 | repo-local を伴わない plugin-a / plugin-b の同名定義 |
| ミラー関係にないパスでの同名 | `.claude/skills/foo/` と `plugin/p/skills/bar/` が双方 `name: foo` を宣言 |
| **同一 root 内の重複** | 同じ走査ルートの中で同名が 2 件以上（**#1087 で新たに検出可能**） |

同一 root 内の重複は、従来の `find_collisions` が「**異なる**定義元ラベルが
複数あること」を要求していたため、構造的に検出できなかった。#1087 で条件を
「定義が 2 件以上」に変更したことで検出対象に入った。

### 見逃しクラス（本是正で検出しなくなるもの）

- **M-1: ミラーペア両側の内容ドリフト**。カバレッジは**非対称**である。
  - **agent / command**: `.claude/` → `plugin/plangate/` の内容一致は
    [`.github/workflows/sync-plugin-plangate.yml`](../../.github/workflows/sync-plugin-plangate.yml)
    の `drift-check` ジョブが保証する（警告ではなく `exit 1`）。
    `.claude/**` / `.agents/skills/**` / `plugin/plangate/**` に触れる
    全 PR で発火する。
  - **skill: 保証されていない**。plugin の skill 供給元は `.claude/skills/`
    ではなく **`.agents/skills/`** であり（sync スクリプトの skills ループが
    `.agents/skills` を読む）、`.claude/skills/` と `.agents/skills/` の
    内容 parity を検査する仕組みは存在しない。
    `scripts/check-skill-frontmatter.py` は 4 root を走査するが frontmatter の
    妥当性のみを見ており parity は見ない。現存する description 差分は
    すべてこの**未保証レーン**にある。**別 PBI で扱う既知の残存ギャップ**
    として記録する。
- **M-2: ミラーそのものが持つリポジトリ内の曖昧さ**。本リポジトリ内の
  エージェントからは `diff-audit` と `plangate:diff-audit` の双方が見える。
  これは `hybrid-architecture.md` が設計上の正常状態と宣言しているため、
  本チェッカーの守備範囲外とする。

### ミラーは黙って捨てず INFO として出力する

ミラー判定された組は、レポートの `INFO:` セクションに一覧として残す。
チェックが「落とさなくなった対象」を読み手が確認できるようにするためで、
**沈黙したチェックは合格したチェックと区別できない**（#1109 の教訓）。

### 実測スナップショット（2026-08-18 時点・base `387ea21`）

契約値ではなく、その時点の計測値として記録する:

- 多重定義グループはすべてミラーと分類され、真の衝突は 0 件
- うち 3 件に export 時の意図的な適応による description 差分がある
  （`ai-loop-cycle` は `references/` パスの同梱、`codex-multi-agent` は
  語順、`context-load` は CLAUDE.md → AGENTS.md の読み替え）
- グループ総数はこの計測時点で 46 件（運用で増減する計測値であり、
  契約値ではない）

## 関連

- Issue [#692](https://github.com/s977043/plangate/issues/692)（本ドキュメントの実装元）
- Issue [#566](https://github.com/s977043/plangate/issues/566)（skill-policy-router — Intent/Mode → 必要 Skill 解決のルーティング正本）
- Issue [#514](https://github.com/s977043/plangate/issues/514)（skills SSoT 整理 — 配置ゆらぎの解消）
- Issue [#691](https://github.com/s977043/plangate/issues/691)（stale パス参照検出。同じ `scripts/` 直下・frontmatter 解析・selftest 付きの実装スタイルを踏襲）
- [`docs/ai/stale-ref-detection.md`](./stale-ref-detection.md)（姉妹ツールのドキュメント構成の手本）
