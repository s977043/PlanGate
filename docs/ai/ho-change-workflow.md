# HO パス変更の標準フロー（仕様 + apply 分割）

> 非HO 正本。責務4分類（[`responsibility-classes.md`](../../.claude/rules/responsibility-classes.md)
> 「HO 実適用は Human」）の **how** を定義する。出自: #505 ギャップ3
> （PR #501-504 セッションの振り返りで確立した実務パターンの手順化）。

## 背景

AI は Hardening Override (HO) パスを**直接編集できない**（HO 常時 block）。対象は
`.claude/rules/` / `.claude/agents/` / `.claude/commands/` / `CLAUDE.md` / `AGENTS.md` /
`bin/plangate` / `scripts/hooks/` / `schemas/*.schema.json` / `.github/workflows/`。

一方、これらの変更も**設計・検証・PR 準備は AI が担える**（責務4分類: AI-owned =
実装・検証・PR 準備 / Human-owned = HO 実適用）。本書はその分割フローを定める。

> 注: `.claude/skills/` と `scripts/_*.py` は HO 対象**外**（AI 直接編集可）。
> `docs/` 配下も原則 HO 対象外。

## 標準フロー

HO パスの変更を伴う PBI は以下に分割する:

1. **AI: 非HO の仕様 docs** に変更の意図・仕様を正本化（必要な場合）
2. **AI: apply スクリプト**（`scripts/apply-*.sh`、非HO）を作成
   - **冪等**: 既適用ならスキップ
   - **`--dry-run`**: unified diff プレビュー（書き込みなし）
   - **引数 strict 検証**: `--dry-run` 以外の引数は exit 1（誤適用防止）
   - **アンカー検証**: 挿入位置が見つからなければ exit 1
3. **AI: PR 作成**（apply スクリプト + 仕様 docs のみ。HO 実ファイルは含めない）
4. **Human: C-3 判断 → `--dry-run` で差分確認 → apply 実行**（HO 適用）

## 適用例

| PBI | 非HO 成果物 | HO 適用先 |
|-----|-----------|----------|
| #496 doc-light | `apply-mode-classification-doc-light.sh` | `.claude/rules/mode-classification.md` |
| #505 gap1 | `apply-responsibility-classes-branch-base.sh` | `.claude/rules/responsibility-classes.md` |
| #500 wiring | `settings-wiring-contract.md` 仕様 + 4 段階 PBI | `scripts/hooks/` / `bin/plangate` 等 |

## 禁止事項

- AI が apply スクリプトを **`--dry-run` なしで実行してはならない**。self-mod guard
  違反となり HO を誤変更する（実害例: `apply-ho-followups.sh` を AI が誤実行し
  `ci.yml` を破損。`git checkout` で revert）。apply スクリプトの実行は **Human、
  または計画段階で明示的に y 承認された AI 実行**に限る。
- 仕様 docs と apply スクリプトを**同一 PR**に置き、HO 実ファイルは PR に含めない
  （PR 段階では HO は未変更のまま＝混入・誤適用を構造的に防ぐ）。

## 関連

- 責務4分類正本: [`responsibility-classes.md`](../../.claude/rules/responsibility-classes.md)
- HO パターン定義: `check-plan-hash.sh` の **`_override=0` 直後の `case` ブロック**（`esac` まで。9 カテゴリ正本）。
  **行番号で参照しない** — 行番号アンカーは実装の移動で黙って別ブロックを指す（#1089 / 記号アンカー化）。
  機械抽出: `awk '/_override=0/{g=1;next} g&&/^[[:space:]]*esac/{exit} g' scripts/hooks/check-plan-hash.sh`
- WF-04 Build & Refine / WF-05 Verify & Handoff
