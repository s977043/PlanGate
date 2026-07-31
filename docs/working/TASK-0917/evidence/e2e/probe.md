# TASK-0917 E2E probe（AC-4 / TC-11 の実走対象）

このファイルは AC-4 / TC-11（実 PR 1 周の手動実走）で **Executor が実際に
repair push した対象**です。Collector / Executor / Reconciler を実 PR に対して
1 周させ、fixture では検出できない実 REST レスポンス形状・push の終了コード・
pre-check の実挙動を確認する目的で作成しました。

## 経緯（実測・記述の訂正）

- 検証用 PR **#940**（`chore/task-0917-e2e-probe` → `main`・draft・title に
  `[DO NOT MERGE]`）で実走した
- **当初は「マージしない」前提**だったが、**2026-07-31T07:33:27Z に #940 が
  main へマージされた**（merge commit `bd7a251`）。本ファイルはその結果 main
  に取り込まれている
- 内容は無害な 12 行で、置き場所（`evidence/e2e/`）は本 PBI の E2E 証跡
  ディレクトリそのものであり、**Executor が push した実物**として証跡価値が
  ある。したがって revert せず、**記述を実態に合わせて訂正**した
  （旧版は「この PR はマージしません」と書いており、マージ後は事実と矛盾していた）

## 実走時の外部作用（`gh pr view 940` で実物照合済み）

- PR コメント **1 件**（`#issuecomment-5140067809` / author `s977043`）
- branch push **1 回**（`fe0abc6..7b22922` fast-forward）
- merge / review / close / reopen / ready / edit / branch 削除 / force push /
  非 GET api / `main` への push は**いずれもゼロ**（`reviews: 0` で実証）

## 参照

- 実走記録: `docs/working/TASK-0917/evidence/e2e/`（`run-log.md` / `findings.md`）
- repair push probe: T-35 実走で Executor が push した無害な 1 行（2026-07-31T06:35:23Z）
