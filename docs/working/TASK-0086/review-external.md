---
task_id: TASK-0086
artifact_type: review-external
schema_version: 1
status: done
phase: V-3
---
# V-3/V-4 外部レビュー — TASK-0086（#231 Dogfooding Eval v1）
high-risk。Codex 実行（初回探索逸れ＋ツール自己実走で Release blockers:0 経験的
確認→構造 verdict 再取得）。Gemini 出力なし→Codex 主体。
## 判定: Codex=critical0/major2/minor2 → fix-loop（全反映）
| # | Sev | 指摘 | 対応 |
|---|-----|------|------|
| MJ-1 | major | has_c4 三項式 動作するが可読性低・将来壊しやすい | 括弧明示・status_p 変数化 |
| MJ-2 | major | item5 claim_wo_evidence 粗く false negative | evidence/claim terms 頑健化・不明瞭=PARTIAL（silent PASS しない）|
| mn-1 | minor | item3 has_c4=True/c3st=None が FAIL（片方あり=PARTIAL のはず）| both=PASS/either=PARTIAL/neither=FAIL |
| mn-2 | minor | --dogfood --baseline で baseline 無視 | 独立 mode で許容（Codex 許容範囲明記）|
Codex: critical なし・既存 8-aspect/argparse 非破壊（--dogfood 早期 return）。
## V-4 リリース前（high-risk）: 全 PASS
既存 eval 8-aspect 非破壊・--dogfood 独立・欠落 artifact 例外なし・CLI 64/0・
hook 78/0・eval-runner syntax OK・完了済TASK blocker0。
## 出典
Codex: /tmp/t0086-codex-v3.md(初回) + /tmp/t0086-codex-v3b.md(verdict) /
Gemini: /tmp/t0086-gemini-v3.md（出力なし）
