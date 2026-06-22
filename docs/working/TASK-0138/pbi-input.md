# PBI INPUT PACKAGE — TASK-0138 (#528)

## Context / Why

docs 修正のたびに EH-3（plan-hash hook）を `Bash + PLANGATE_SKIP_REASON` で回避する運用が常態化している。問題:
1. **監査非対称**: Edit/Write 経由ならば skip-decision-log に記録されるが、Bash 経由の編集は hook が発火せず記録が残らない
2. **往復コスト**: doc-only 変更にも SKIP_REASON を毎回設定する必要がある

mode-classification.md §変更種別軸（#496 HO 適用済み / CLOSED）で `doc-light` 判定が定義済み。EH-3 にその経路を追加し、**記録付き自動 SKIP** で摩擦を解消する。

## What（Scope）

**In scope**:
- `scripts/hooks/check-plan-hash.sh` に doc-light 経路を追加
  - 判定対象: `task_id` 空 + 非 HO + 非 `plan.md` + 拡張子 `.md`
  - 動作: `SKIP_REASON` なしで通す + `skip-decision-log.jsonl` に `EH-3_DOC_LIGHT_SKIP` エントリを記録
  - HO パス（.claude/rules, .claude/agents, CLAUDE.md 等）は従来どおり BLOCK を維持
- `tests/extras/ta-39-eh3-doc-light.sh` — doc-light 経路の TC 追加
- `tests/run-tests.sh` に ta-39 を登録

**Out of scope**:
- TASK 文脈あり経路の変更
- maintenance.json / SKIP_REASON 経路の変更
- doc-light mode 判定ロジック本体（mode-classification.md は変更しない）

## 受入基準

- AC-01: docs 配下・非 HO の `.md` ファイルへの Edit/Write が TASK 文脈なしに通る（EH-3_DOC_LIGHT_SKIP ログ記録付き）
- AC-02: HO パス（.claude/rules/*.md, CLAUDE.md 等）は TASK 文脈なしの場合も従来どおり BLOCK
- AC-03: `plan.md` は従来どおり BLOCK（既存動作不変）
- AC-04: doc-light SKIP 時、`skip-decision-log.jsonl` に `EH-3_DOC_LIGHT_SKIP` イベントが追記される
- AC-05: ta-39 テストが全 TC PASS かつ `tests/run-tests.sh` で認識される
- AC-06: 既存 EH-3 テスト（ta-14）の全 TC が引き続き PASS（回帰なし）

## Notes from Refinement

- 判定順序: HO override check の直後・maintenance check の前に doc-light check を挿入
- `acknowledged_by` は null のまま追記（AC-06 に合わせ要追認チェックは外さない — 将来 CI の監査目的）
- `.md` 拡張子はケース非感応（`.MD` も対象）
- docs 以外のパスにある `.md`（例: `.claude/skills/*.md`）も非 HO なら doc-light 対象とする
- `plan.md` は上流の BLOCK（既存実装）で処理済みのため doc-light 経路に入らない

## Estimation Evidence

- Risks: HO 判定ロジックを誤ると承認境界が崩壊 → 既存 ta-14 回帰テストが保護
- Unknowns: なし（check-plan-hash.sh の構造を確認済み）
- Assumptions: #496 HO 適用済みであること（確認: CLOSED）
