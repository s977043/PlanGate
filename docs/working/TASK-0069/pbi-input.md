---
task_id: TASK-0069
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-0069

## Context / Why

PlanGate は plugin 方式で agents/skills/commands/rules を配布できているが、強制力の核である hook 配線（`.claude/settings.example.json` が正本: 現状 SessionStart 1 + PreToolUse 4 = command 5 種）を導入先の `.claude/settings.json` に適用する工程が手動であり、リポジトリは `.claude/settings.example.json` を配るだけ。`scripts/hooks/` 配下には他にもスクリプトが存在するが、example 未配線のものは本 PBI の検査対象外（正本は example）。さらに `bin/plangate doctor` は metrics/schema は検査するが hook 配線状態を検査も修復もしていない。

結果として「hook が効いていない PlanGate」（ゲート強制が無効な状態）に導入者が気付けない。cowork の `/setup-cowork` 相当として、この「導入先で PlanGate が強制力込みで動く状態に到達する最終 1 マイル」を、PlanGate の思想（強制力は決定論的に）に沿って既存 `doctor` CLI の拡張で埋める。

## What — Scope

### In scope

- `doctor` に新検査セクション `=== Hook Enforcement Wiring ===`（`.claude/settings.json` の hook 配線状態を `settings.example.json` と照合、未配線で FAIL）
- `plangate doctor --fix`（決定論的・確認付き修復）: settings.json への hooks merge-only 適用 / EH-8 chmod +x / .gitignore 追記 / docs/working mkdir
- `--dry-run`（変更計画表示のみ）/ `--yes`（CI 用確認スキップ）フラグ
- `scripts/doctor_fix.py`（新規）: settings.json への安全マージ（merge-only / backup / 冪等）
- `scripts/doctor_check.py` の `--json` 出力に hook-wiring 検査追加
- `README.md` / `TROUBLESHOOTING.md` に `plangate doctor --fix` 導入手順追記
- `scripts/doctor_fix.py` 単体テスト

### Out of scope

- gh / codex の自動インストール（OS 依存・破壊的）
- 対話的オンボーディング UX（案 D。`/setup-plangate` skill）
- plugin 登録自体の自動化（Claude Code 本体仕様依存）
- plugin 側 `plugin/plangate/hooks/` への hook 実体配置（配布戦略は別 PBI）
- EH-8 を将来 `settings.example.json` の正本（配線対象）へ含めるかの設計判断（本 PBI では example が hook 配線の正本である現状を踏襲。EH-8 のファイル存在/実行ビット検査は既存 v8.6.0 セクションの責務に委ねる）

## Acceptance Criteria

- [ ] AC-1: `bin/plangate doctor` に `=== Hook Enforcement Wiring ===` セクションが追加され、hook 未配線環境で `[FAIL] PlanGate hooks not wired` を出力する
- [ ] AC-2: `plangate doctor --fix --dry-run` が変更計画を表示するのみで一切ファイルを書き換えない
- [ ] AC-3: `plangate doctor --fix --yes` 実行後、`.claude/settings.json` が `settings.example.json` の hooks ブロック配線済みになる。既存 `.claude/settings.json` が存在した場合のみ書込前に `.claude/settings.json.bak` を生成する（新規作成時は `.bak` 不要）。既存 `.bak` がある場合は上書きせず `.claude/settings.json.bak.<epoch>` にローテート退避してから新規 `.bak` を作成する
- [ ] AC-4: 既存キー入りの独自 `.claude/settings.json` に対し `--fix` が既存キーを温存（merge-only、上書きなし）する
- [ ] AC-5: `--fix` を 2 回連続実行しても 2 回目が no-op（冪等）である
- [ ] AC-6: gh / codex 未インストール時、`--fix` は自動インストールせず案内のみ出す
- [ ] AC-7: `bin/plangate doctor --json --scope hooks`（新設 scope）で hook-wiring 検査結果（name/ok/level）が JSON 出力される。既存 `--json`（`--scope v8.6.0` default）の出力構造は無改変
- [ ] AC-8: `scripts/doctor_fix.py` の単体テストが PASS し、既存 `tests/hooks/run-tests.sh` が回帰しない

## Notes from Refinement

- 案 A（`doctor --fix` 拡張）を採用。案 B（対話 skill）は強制力を LLM 判断に委ねるため PlanGate 思想と不整合と判断し却下
- 強制力の核は決定論的 CLI に置く方針（hybrid-architecture: Hook はハード強制）
- 将来 UX が必要なら案 D（skill が `doctor --fix` を案内する薄いラッパ）へ拡張、本 PBI の成果は無駄にならない

## Estimation Evidence

**Risks**: `.claude/settings.json` の破壊的書き換え（既存ユーザー設定の損失）→ backup 退避 / merge-only / 確認ゲート / dry-run で緩和。high-risk モード相当
**Unknowns**: 既存 `tests/` の CLI テスト構成（`tests/hooks/run-tests.sh` 形式に倣う想定、plan フェーズで確認）
**Assumptions**: settings.json マージは Python（jq 非依存）が確実。`settings.example.json` が hook 配線の正本であり続ける
