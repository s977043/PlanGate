# Plan Normalization Gate

> Issue #1220 — レビュー済み Plan を Current Canonical State へ正規化する。

## 正本の所在（このページは概要）

**手順・契約・PASS 条件の正本は skill 側**（`.agents/skills/plan-normalization/SKILL.md`
= `.codex/skills/plan-normalization/` / `plugin/plangate/skills/plan-normalization/`
へ同内容で配布される）。

`docs/**` は `install.sh --claude` / plugin（Claude marketplace）/ Codex の
**3 配布経路すべてで配布対象外**であり、導入先では解決できない。したがって
運用手順を本ページに二重化すると、導入先では skill しか読まれず、上流だけが
両方を読む非対称な状態になり、両者が食い違ったときに気付けない
（`.claude/rules/hybrid-architecture.md` Rule 2 / Rule 4）。

本ページは **上流リポジトリ向けの概要と入口**に限定し、規範的な記述は置かない。
差分が生じた場合は skill 側を正とする。

## 何をする Gate か

C-1 / C-2 のレビューと修正を繰り返した `plan.md` から、途中案・破棄済み判断・
会話履歴への依存を除去し、後続の実装 Agent が現在の合意状態だけを読んで実行
できる **Canonical Plan** を作る。

PlanGate では新しい `canonical-plan.md` を作らない。**正規化後の `plan.md`
自体を Canonical Plan の正本**とする。

| Artifact | 責務 |
|---|---|
| `plan.md` | 今、何をどう実装するかという Current Canonical State |
| `decision-log.jsonl` | なぜその判断をしたか、何を却下したかという append-only の意思決定履歴 |
| `review-external.md` | C-2 のレビュー指摘と R-NNN の監査履歴 |

## Gate の位置

Normalization は **C-3 承認前**に行う。

```text
C-2 external review
  ↓
R-NNN 確定反映
  ↓
Plan Normalization
  ↓
Normalization invariant check
  ↓
簡易 C-1 再実行
  ↓
C-3 human approval / plan_hash 固定
  ↓
exec
```

C-3 は承認対象 `plan.md` の SHA-256 を承認記録の `plan_hash` に固定し、exec 時に
EH-3 がこの hash と現在の `plan.md` を突合する。C-3 後に正規化すると、正しい
意図の編集でも `plan_hash mismatch` になる。Normalization は必ず hash 固定前に
完了させる。

> 承認順序そのものの正本は `.claude/rules/working-context.md` の
> 「C-3ゲート（計画承認・三値）」節。本ページと skill はその順序を変更しない。

## 適用範囲

**これから normalization を通す Plan にだけ**適用する。既存の
`docs/working/TASK-XXXX/plan.md` を後から一括検査する repo-wide lint ではない
（過去 Plan は別テンプレートで書かれており構造が一致しない）。詳細な表は
skill の「適用範囲」節を参照。

## このリポジトリでの checker 実行

```bash
python3 scripts/check-plan-normalization.py \
  --before-ref HEAD \
  --after docs/working/TASK-XXXX/plan.md
```

- baseline は **git 由来（`--before-ref`）が既定**。正規化 Agent 自身が書いた
  snapshot を `--before` で渡す経路も残るが、その場合 checker は「未検証入力」
  として `[WARN]` を出す
- exit 0 = PASS / exit 1 = 契約違反 / exit 2 = 起動不正・入力不良
- 検査内容と機械検証の限界（履歴表現の検出が低再現率の denylist であること）は
  skill の「6. 機械チェック」節が正本
- 回帰テスト: `tests/extras/ta-75-plan-normalization.sh`
