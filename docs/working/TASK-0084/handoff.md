---
task_id: TASK-0084
artifact_type: handoff
schema_version: 1
status: done
---
# HANDOFF — TASK-0084 (#229 Trace Timeline v1 / experimental)

## 1. 要件適合確認結果
| AC | 判定 | 根拠 |
|----|------|------|
| AC-1 schema 1.1 additive | PASS | schema_version enum["1.0","1.1"]・gate_id/parent_event_id 追加・phase enum に WF-01..06/handoff additive |
| AC-2 1.0 後方互換 | PASS | 1.0 event（TASK-0061 サンプル）が 1.1 schema で valid・main schema と同挙動（回帰なし） |
| AC-3 --timeline --json | PASS | `metrics <TASK> --timeline --json` が phase/gate/ts 正規化 JSON 出力（scripts/metrics_timeline.py） |
| AC-4 additionalProperties/Privacy | PASS | additionalProperties:false 維持・forbidden field 不混入 |
| AC-5 experimental 表記 | PASS | metrics.md「Trace Timeline v1（experimental / #229）」節 + CLI ヘルプ「[experimental #229]」 |
| AC-6 README/quickstart 非掲載 | PASS | 本変更で README/quickstart へ追加なし（既存のロードマップ行 L74 は Experimental 明記済・別件 / 既存 `timeline` サブコマンドは別機能）。使用手順は metrics.md(audit/debug)限定 |
| AC-7 回帰なし | PASS | hook 78/0・CLI 64/0・schema-self valid・metrics_reporter 非破壊 |

## 1-bis. V-3 fix-loop（Codex major2 / Gemini 出力なし）

Codex=critical0/major2/minor3。critical なし（後方互換 OK 確認）。fix-loop:
- MJ-1: gate_id/parent_event_id に pattern+maxLength（Privacy#202 を schema で
  物理阻止＝slash/空白/自由文 reject）
- MJ-2: sort を #229 AC-3 契約どおり phase→gate→ts に修正・docstring 整合
- minor: 空shape統一 / help 修正 / --timeline 非対応flag併用 exit2
再 V-1 PASS、hook 78/0・CLI 64/0・schema-self valid。

## 2. 既知課題一覧
- gate_id 語彙は最小（命名規則正規化は #230 Gate Event Normalization v8.8.0）
- metrics_collector は schema_version 1.0 のまま（1.1 は experimental・additive。
  collector の 1.1 emit は #230/#231 で判断）

## 3. V2 候補
- #230 gate_id 正規化 / #231 Dogfooding Eval が timeline を judge 入力に
- trace_id / artifact_refs（v8.8.0 判断・本 PBI Out）

## 4. 妥協点
- 3 fields のうち phase は既存＝実追加は gate_id/parent_event_id + phase enum
  additive。experimental＝quickstart 非掲載で OSS 利用者へ「未確定」明示

## 5. 引き継ぎ文書（5分サマリ）
#229 PBI-HI-013。events schema を 1.1 へ additive 拡張（schema_version enum・
gate_id/parent_event_id・phase WF/handoff）+ `metrics --timeline --json`
（experimental・scripts/metrics_timeline.py）+ metrics.md experimental 節。
1.0 完全後方互換・破壊なし・hook78/CLI64 不変。

## 6. テスト結果サマリ
- AC-1〜7 PASS（schema valid / 1.0 後方互換 / --timeline 動作 / 回帰なし）
- hook 78/0・CLI 64/0・schema-self valid
