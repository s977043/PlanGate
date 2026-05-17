---
task_id: TASK-0085
artifact_type: review-external
schema_version: 1
status: done
phase: V-3
---
# V-3 外部レビュー — TASK-0085（#230 Gate Event Normalization）
Codex + Gemini 実行。
## 判定: Codex=critical0/major3/minor1 / Gemini=PASS → fix-loop（全反映）
| # | Sev | 指摘 | 対応 |
|---|-----|------|------|
| MJ-1 | major | external_review_completed/fix_loop_incremented は status optional→#231 前処理で signal 落ち | verdict 無→conditional / fix_loop→skipped+count メタ保持 を明記 |
| MJ-2 | major | 「gate_id↔phase 一致」が hook gate(EH-x・phase外)と矛盾(fixture WF-04/EH-3) | workflow/承認 gate は一致・hook gate は別軸(phase=発火WF)と明記し矛盾解消 |
| MJ-3 | major | BLOCK/INCREMENT 未明示・MAINTENANCE_INVALID が bypassed行で fail 記述＝機械実装不可 | status 表に BLOCK→fail/INCREMENT→skipped 追加・MAINTENANCE_INVALID→fail 行・決定論注記 |
| mn-1 | minor | SKIP_BLOCKED が skipped/fail 衝突 | SKIP_BLOCKED=fail(release blocker) 一意固定 |
Codex 確認: schema enum 非変更・fixture 全6行 valid・#202 forbidden 不在。
Gemini=PASS: 5正規status 包括的・fail-closed 整合・PII なし。
## 確認
再 V-1: MJ-1〜3/mn-1 PASS・hook 78/0・CLI 64/0・schema-self valid・fixture valid
## 出典
Codex: /tmp/t0085-codex-v3.md / Gemini: /tmp/t0085-gemini-v3.md
