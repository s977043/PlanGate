# /ai-loop-workflow

ai-loop-workflow（human-on-the-loop 裁定ループ）を明示起動する。
`/ai-dev-workflow`（PlanGate 本番フロー WF-00〜07）と**対をなす入口**であり、
本番フローの置き換えではない。恒久定義（責務・terminal state・C-3'/Human C-3 経路）の
正本は `00_concept.md`、適用制限（Phase 1 rollout eligibility）の正本は
`rollout-policy.md`（eligible run 限定。PlanGate 本番フローの C-3 は常に Human・不変）。

実行手順の正本: skill `ai-loop-cycle`（1 サイクル = LoopSpec → W チェック →
arbiter 裁定 → exec → rubric grader）。本コマンドは前提確認と起動のみを担う。

> **docs の参照先**: plugin 導入先では ai-loop ドキュメントは skill 内の
> `references/` 配下（`skills/ai-loop-cycle/references/`）に同梱される。
> 本リポジトリ（正本側）では `docs/workflows/ai-loop/` 配下。以下の参照は
> 環境に応じてどちらかで解決すること。

## 引数

$ARGUMENTS に以下の形式で渡される:

- `run <対象の説明>` — 新しい run を開始（LoopSpec 作成から）
- `status` — 直近 run の状態・decision record・摩擦台帳の要約を表示
- （引数なし） — 前提チェックのみ実施して結果を報告

## 実行前チェック（必須・満たさない場合は開始せず報告）

1. **HO 境界の解決**: ho-paths（導入先確定済み）が arbiter から解決できるか
   — `python3 <arbiter.py の実パス> --input /dev/null` 相当の疎通でなく、
   ho-paths 解決元の stderr 表示を確認する。未確定なら「全件 human escalate になる」旨を伝え、確定を促す
2. **保存先の定義**: run 記録（LoopSpec・decision record）と摩擦台帳の置き場が
   プロジェクトで定義済みか（未定義なら既定案を提示して合意を取る）
3. **適用制限（Phase 1 rollout eligibility）**: 対象変更が `rollout-policy.md` の
   eligible 条件を満たしうるか（boundary=clean、かつ `lite-criteria.md` §2 の
   4 軸〔変更規模・新規設計の有無・既存パターン踏襲・可逆性〕。docs に限らず
   実機能も含む — Human 決定 #807）。承認境界・本番承認フローに触れる場合は
   本コマンドを使わず通常フローへ

## 実行

前提 3 点を満たしたら、skill `ai-loop-cycle` の手順に従って 1 サイクルを実行する。
停止規則（round 上限・escalate 条件・touches-HO 無条件 escalate）は skill と
同梱 docs（decision-table / execution-runbook / loop-safety-gates）が正本。

## Iron Law（ai-loop 版・違反したら即停止）

| ルール | 意味 |
|-------|------|
| `NO LOOP WITHOUT STOPPING RULE` | 停止できないループを回すな |
| `NO AUTO-APPROVE ON HO CONTACT` | HO 接触は無条件で人間へ |
| `NO OPTIMIZE WITHOUT RECORD` | 記録なき最適化をするな |
| `NO MERGE BY AI` | マージは常に Human |

## 関連

- skill: `ai-loop-cycle`（実行単位の正本）
- docs: 同梱 ai-loop ドキュメント（design-philosophy / decision-table / execution-runbook —
  plugin 導入先は skill 内 `references/`、本リポジトリは `docs/workflows/ai-loop/` 配下）
- 対: `/ai-dev-workflow`（PlanGate 本番フロー入口）
