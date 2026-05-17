---
task_id: TASK-0082
artifact_type: handoff
schema_version: 1
status: done
---

# HANDOFF — TASK-0082 (TASK-0071 S3: EH-3 メンテモード+SKIP_REASON)

## 1. 要件適合確認結果

| AC | 判定 | 根拠 |
|----|------|------|
| AC-1 メンテ有効→非plan SKIP | PASS | maintenance.json 有効時 SKIP exit0（マトリクス検証） |
| AC-2 plan.md 常時 BLOCK(E1) | PASS | メンテ中でも plan.md exit2（P4d BLOCK が先・覆らない） |
| AC-3 BYPASS>メンテ>通常(E2) | PASS | BYPASS=1 でメンテ/plan 無関係に exit0 |
| AC-4 until 検証/30分/fail-closed | PASS | 期限切れ・30分超・不正JSON → 無効（SKIP_REASON 経路へ） |
| AC-5 env でメンテ無効 | PASS | 承認ファイルのみ判定（env 変数読まない） |
| AC-6 SKIP_REASON 空→停止/append | PASS | 空→exit2、設定→exit0+skip-decision-log.jsonl append（acknowledged_by:null） |
| AC-7 CI required（未追認） | PASS | scripts/check-skip-acknowledged.sh + ci.yml `skip-ack` job（未追認→fail / 全追認→pass 検証） |
| AC-8 監査 machine-readable | PASS | MAINTENANCE_SKIP/MAINTENANCE_INVALID/SKIP_BLOCKED/SKIP を _audit に記録 |
| AC-9 既存挙動（条件）不変 | PASS（要説明） | maintenance不在&SKIP_REASON設定で P4d 不変・hook 78/0・CLI 64/0 |

## 1-bis. AC-9 の挙動変更点（仕様・要把握）

S3 は設計（s3a 案C）どおり **「no-task non-plan の bare SKIP（SKIP_REASON
無し）を拒否（exit2）」** に強制を強化。これにより従来 P4d で
`no-task non-plan → 無条件 SKIP exit0` だった挙動は **SKIP_REASON 必須**へ
変わる（意図した強制強化＝バイパス不要化の核心）。既存 P4d テスト TC-2/TC-6
は新契約（SKIP_REASON 設定で SKIP）へ更新済。plan.md BLOCK / BYPASS /
TASK 文脈ありの hash 検査は不変。

## 1-ter. V-3 fix-loop（Codex major4 / Gemini クラッシュ）

Codex=critical0/major4/minor2。critical なし。fix-loop 全反映:
- MJ-1: SKIP_REASON strip+空白のみ拒否 / MJ-2: 死に分岐除去・源=env 明記
- MJ-3: maintenance granted_at<=now 必須（承認前メンテ禁止）
- MJ-4: skip-ack acknowledged_by/at 両方必須
- minor: schema runtime=V2 / required化=ruleset(Human-owned) 明記
再 V-1+V-4 PASS、hook 78/0・CLI 64/0。

## 2. 既知課題一覧

- maintenance.json は人間生成（Human-owned。responsibility-classes.md）。
  AI 自己付与防止は env 無効化 + 承認ファイル方式 + CI 監視で構造担保
- `docs/working/_maintenance/` / `skip-decision-log.jsonl` の gitignore 方針は
  運用で確定（監査証跡として追跡 or ローカル）。本 PBI は機構実装まで

## 3. V2 候補

- maintenance.json の改竄検知（plan_hash 系と同様の sha 監査）
- skip-decision-log の #200 期間集計連携

## 4. 妥協点

- メンテは固定パス `docs/working/_maintenance/maintenance.json`（no-task 経路で
  TASK ディレクトリ非依存に検出する必要があるため）。s3a の approvals/ 配置案
  から変更（理由: no-task SKIP は TASK 文脈が無く per-TASK パス解決不可）
- SKIP_REASON 強制は no-task non-plan SKIP 経路のみ（TASK 文脈あり/plan.md/
  BYPASS は不変＝影響範囲を限定）

## 5. 引き継ぎ文書（5分サマリ）

TASK-0071 最終スライス S3 完了。EH-3 に承認ファイル方式メンテモード
（plan.md 常時BLOCK・BYPASS>メンテ>通常・最大30分・fail-closed・監査）+
SKIP_REASON 必須（空→停止・decision-log append・CI required で人間追認強制）
を実装。bare SKIP を拒否し「監査だけでなくバイパス不要化」を達成。
**これで TASK-0071 D-1 全スライス（S1+S2 #254 / S4 #256 / S3 本PBI）完了**。

## 6. テスト結果サマリ

- マトリクス検証: AC-1〜9 全 PASS（メンテ/E1/E2/期限/fail-closed/SKIP_REASON/CI）
- hook 回帰: 78 passed / 0 failed（S3 TC 追加・TC-2/6 を新契約へ更新）
- CLI tests: 64 passed / 0 failed
- dash -n: OK / ci.yml YAML valid（skip-ack required job 追加）
