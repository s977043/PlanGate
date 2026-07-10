---
name: ref-integrity-scan
description: "ファイル（スキル/ルール/フック/設定/ドキュメント）を削除・移動・改名する前後に、リポジトリ内の被参照（ダングリング参照）を全走査して修正候補を提示する。Use when: git rm / git mv の前後、スキル・ルールのパス変更時、『削除前にチェックして』『参照切れを探して』。出典: growth-core deletion-reference-scan 由来（#798）。"
---

# Ref Integrity Scan

ファイル・ディレクトリを削除・移動・改名する**前後**に、リポジトリ全体を対象に被参照（そのパスを指している箇所）を洗い出し、ダングリング参照を防ぐための手順スキル。

## #691（check-stale-skill-refs.py）との相補関係

| スキル/スクリプト | 走査方向 | 検出対象 |
|---|---|---|
| `scripts/check-stale-skill-refs.py`（#691） | **outbound**（発信） | スキル/コマンド/エージェントが参照している**先**が実在しない（stale） |
| **本スキル（ref-integrity-scan）** | **inbound**（被参照） | 削除・移動・改名する対象**への**参照が他のどこかに残っている |

`#691` は「自分が指している先が消えていないか」、本スキルは「自分を消したときに誰かが迷子にならないか」を確認する。両方向を揃えることで参照整合を守る。

## 実害事例（動機）

2026-07-10、`self-review` スキルを `diff-audit` へ改名した際（#796）、削除・改名前の被参照スキャンを行わなかったため、以下が**事後検出**になった:

- `acceptance-review` からのリンク切れ（RiverReview レビューで major 指摘として検出）
- `.cursor` 配下の壊れた symlink（旧パス `self-review` を指したまま。Codex 側レビューで検出）

いずれも事前に inbound スキャンを行っていれば着手前に判明していた。本スキルはこの再発防止策として新設する。

## When NOT to use

- コード内の import / require 参照の整合性チェック → 型チェッカー / linter を使う
- 外部サイトへのリンク切れ（http/https URL）のチェック → 対象外（本スキルはリポジトリ内参照のみ）

## 手順

### Step 1: 対象パスの確認

削除・移動・改名する対象パスを列挙する（複数可）。例:

```text
対象: .claude/skills/self-review/  (旧名)
対象: .claude/skills/self-review/SKILL.md
```

移動・改名の場合は「旧パス」と「新パス」の両方を把握しておく（新パスは対象外、旧パスのみスキャン対象）。

### Step 2: スキャン実行

**フルパス**と**ファイル名のみ**の 2 パターンで grep する。参照形式が `./` 省略・相対パス表記・単純なファイル名参照など様々なため、片方だけでは取りこぼす。

対象ディレクトリ・ファイル: `docs/ .claude/ .agents/ .codex/ .cursor/ plugin/ bin/ scripts/ CLAUDE.md AGENTS.md README*.md`
対象拡張子: `*.md *.json *.sh *.yaml *.yml`

```sh
TARGET_FULL="path/to/target"          # フルパス（削除・移動対象）
TARGET_NAME="$(basename "$TARGET_FULL")"  # ファイル名のみ

# パターン1: フルパスでの参照
grep -rn --include='*.md' --include='*.json' --include='*.sh' \
  --include='*.yaml' --include='*.yml' \
  -F -- "$TARGET_FULL" \
  docs/ .claude/ .agents/ .codex/ .cursor/ plugin/ bin/ scripts/ \
  CLAUDE.md AGENTS.md README.md 2>/dev/null

# パターン2: ファイル名のみでの参照（誤検出が出やすいので手動で絞り込む）
grep -rn --include='*.md' --include='*.json' --include='*.sh' \
  --include='*.yaml' --include='*.yml' \
  -F -- "$TARGET_NAME" \
  docs/ .claude/ .agents/ .codex/ .cursor/ plugin/ bin/ scripts/ \
  CLAUDE.md AGENTS.md README.md 2>/dev/null
```

**加えて symlink 走査**を行う。macOS の `xargs` は空入力（一致ゼロ件）で待機してハングすることがあるため、`find | xargs` ではなく **while-read 形式**を使う:

```sh
find . -type l 2>/dev/null | while IFS= read -r _link; do
  _resolved="$(readlink "$_link")"
  case "$_resolved" in
    *"$TARGET_NAME"*) printf 'SYMLINK: %s -> %s\n' "$_link" "$_resolved" ;;
  esac
done
```

### Step 3: ヒットの分類

grep / symlink 走査で出たヒットを 3 種に分類する:

| 分類 | 内容 | 扱い |
|---|---|---|
| (a) 追従更新すべき参照 | 現行の手順・設定・リンクが対象パスを指している | 修正候補として提示、原則反映 |
| (b) 履歴として不変にすべきもの | `CHANGELOG.md`、`docs/working/` 配下の過去記録、過去のレビューレポート等 | **機械置換しない**（当時の記録を保存する） |
| (c) 概念の同名異義 | 例: 「C-1 セルフレビュー」という**概念**への言及と、`self-review` という**スキル名**への言及が同じ文字列でヒットする場合 | 文脈で判定し、**機械置換しない** |

**(b) (c) を機械置換しないことを規約とする。** 2026-07-10 の `self-review → diff-audit` 改名（#796）で、Codex のレビューにより誤って書き換えられた箇所が 4 件検出された教訓による。

### Step 4: 修正候補の提示と再スキャン

- 分類 (a) について `file:line` + 具体的な置換案（before/after）を提示する
- 実際の置換後、**同じ Step 2 のスキャンを再実行**し、ヒット 0 件（または (b)(c) のみ残存）であることを確認する
- 削除・移動を伴う commit には、再スキャン結果（0 件確認 or 残存理由）を明記する

## 関連

- `scripts/check-stale-skill-refs.py`（#691・outbound: スキルが参照する先の stale 検出）
- `diff-audit`（Phase 5 残骸チェック。旧 `self-review`）
- [`docs/ai/skill-collision-detection.md`](../../../docs/ai/skill-collision-detection.md)（名前衝突検出。本スキルは被参照検出で観点が異なる）
