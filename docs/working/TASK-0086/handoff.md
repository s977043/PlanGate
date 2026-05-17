---
task_id: TASK-0086
artifact_type: handoff
schema_version: 1
status: done
---
# HANDOFF — TASK-0086 (#231 Dogfooding Eval v1)
## 1. 要件適合確認結果
| AC | 判定 | 根拠 |
|----|------|------|
| AC-1 eval --dogfood 動作 | PASS | 5項目 PASS/PARTIAL/FAIL 判定 |
| AC-2 markdown+rationale | PASS | eval-dogfood.md（判定表+rationale+release blocker）|
| AC-3 3件以上サンプル | PASS | TASK-0080/0083/0085 生成 |
| AC-4 外部 fixture 意識 | PASS | 汎用 TASK ディレクトリ走査・author-repo specific path なし |
| AC-5 #228 整合 | PASS | dogfooding-eval.md judge-prompt が #228 5項目整合 |
| AC-6 #229/#230 接続 | PASS | events.ndjson 読込 / #230 gate-event-normalization 参照（依存明記）|
| AC-7 既存eval非破壊 | PASS | --dogfood 独立 mode・8-aspect 不変・CLI 64/0・hook 78/0 |
## 1-bis. V-3 fix-loop（Codex major2/minor2 / Gemini なし）
Codex critical0。初回探索逸れ＋ツール自己実走(blocker0 確認)→verdict 再取得。
fix-loop: MJ-1(has_c4 括弧明示)/MJ-2(item5 claim 頑健化・不明瞭=PARTIAL)/
mn-1(item3 片方=PARTIAL)。V-4 全PASS・CLI64/hook78・8-aspect 非破壊。

## 2. 既知課題一覧
- v1 judge=決定論構造判定（C-3 D-1）。LLM judge は judge-prompt を外部基盤で
- item5 repo-global skip は advisory(PARTIAL)＝当該TASK blocker化しない
- #230(PR #261) 未マージ＝gate-event-normalization 参照は依存（#261 マージで解決）
## 3. V2 候補
LLM judge 実呼出 / skip-ack TASK 紐付け精緻化
## 4. 妥協点
v1 決定論主・LLM 揺らぎ持ち込まない（再現性優先）。#230 未マージ→自己完結+依存明記
## 5. 引き継ぎ文書（5分サマリ）
#231。eval-runner.py --dogfood 独立 mode（#228 5項目決定論判定+rationale→
eval-dogfood.md）+ dogfooding-eval.md judge-prompt 正本。8-aspect 非破壊。
## 6. テスト結果サマリ
AC-1〜7 PASS / CLI 64/0 / hook 78/0 / 既存 eval 非破壊 / サンプル3件
