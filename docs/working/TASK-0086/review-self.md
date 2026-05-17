---
task_id: TASK-0086
artifact_type: review-self
schema_version: 1
status: draft
---
# C-1 — TASK-0086（Plan7/ToDo5/TC3 全 PASS）
判定: CONDITIONAL（C-3 で 1 点確認）
### D-1（C-3・major）: v1 judge の実体
候補 (i) 決定論構造判定のみ（artifact 充足を機械チェック・rationale 生成）
(ii) 構造判定 + 外部 LLM(codex/gemini) 呼び出し。**推奨 (i)**＝v1 は決定論
構造判定 + judge-prompt テンプレ同梱（LLM 判定は将来/外部基盤で呼べる形）。
LLM 揺らぎを v1 に持ち込まず再現性確保（#231「最小基盤」と整合）。C-3 確認。
留意: 既存 eval 非破壊（独立 mode）最優先・#230 未マージは依存明記。
high-risk→V-3+V-4。
