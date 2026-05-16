---
task_id: TASK-0080
artifact_type: handoff
schema_version: 1
status: done
---

# HANDOFF — TASK-0080 (Governance Hardening S1+S2)

## 1. 要件適合確認結果

| AC | 判定 | 根拠 |
|----|------|------|
| AC-1 wiring 正本 | PASS | `docs/ai/settings-wiring-contract.md`（EH-1/2/3+FILE/6/9 必須トークン定義）|
| AC-2 適用 script | PASS | `scripts/apply-claude-settings.sh`（冪等・ユーザー実行・--dry-run）|
| AC-3 doctor --check-settings | PASS | `bin/plangate doctor --check-settings`→`check-settings-wiring.sh`（適用済PASS/未適用非0+列挙）|
| AC-4 タスクロック | PASS | 05_verify_and_handoff DoD + working-context に「doctor --check-settings PASS が V-1/handoff 完了の前提」明記（doctor連動+workflow DoD 併用・C-3確定）|
| AC-5 CI drift required | PASS | ci.yml `settings-drift` job（`--target example` で契約↔settings.example.json 整合・required）|
| AC-6 既存挙動不変 | PASS（要説明・下記）| hook 78/0・CLI tests 64/0・doctor --json 16checks 不変・既存 doctor hook-wiring check の**コード byte 不変** |
| AC-7 TASK-0071 更新 | PENDING | 本 PBI マージ後に TASK-0071 INDEX/handoff を S1+S2 完了・S3/S4 残へ更新（follow-up） |

## 1-bis. AC-6 の重要な補足（doctor hook-wiring が FAIL する理由＝仕様）

`bin/plangate doctor`（非 json）が本ブランチで `[FAIL] PlanGate hooks not wired
(2/6 ...)` を出すのは**回帰ではなく意図した Shadow Config 検出**:

- 既存 doctor hook-wiring check（TASK-0069）は **settings.example.json を
  期待正本**として `.claude/settings.json` と突合する（コードは byte 不変）。
- main では settings.example.json が EH-9 / EH-3 PLANGATE_HOOK_FILE を
  欠いていたため期待が不完全＝**false-PASS**（ギャップを検出できなかった）。
- 本 PBI が settings.example.json を wiring 契約に整合（EH-9 追加 / EH-3 に
  PLANGATE_HOOK_FILE）させた結果、既存 check が**正しく**「2/6 missing」を
  検出するようになった＝本 PBI の目的そのもの（AC-8/EH-9 の未適用を可視化）。
- CI への影響なし: CI は plain `bin/plangate doctor` を実行しない
  （schema-validate / CLI tests のみ）。`.claude/settings.json` は gitignore。
  新 `settings-drift` job は `--target example`＝PASS。
- `sh scripts/apply-claude-settings.sh`（ユーザー実行）適用後は doctor
  hook-wiring も PASS（dry-run で適用内容確認済）＝「適用済み環境で PASS」
  という AC-6 を満たす。

## 1-ter. V-3 fix-loop（Codex critical2/major3 / Gemini APPROVED）

Codex=REJECT級(critical2/major3/minor3)、Gemini=APPROVED。critical をブロッカー
採用し fix-loop:
- CR-1: apply-claude-settings.sh が EH-9 を実適用せず案内のみ→「適用済み誤認」
  再導入だった → **python JSON 構造マージで EH-3 PLANGATE_HOOK_FILE+EH-9 を
  実適用・backup&restore・適用後契約検証で未適用残は非0**（一時コピーで
  before FAIL→apply→after PASS・冪等・JSON valid 検証済）
- CR-2: check-settings-wiring.sh が grep のみ→誤検出 → **python で
  .hooks.PreToolUse[] の matcher/command を構造検証**（_comment_/別matcher/
  無効JSON 排除。example PASS / user FAIL を exit code で確認）
- MJ-1/2/3: 責務分離（CI=reference健全性 / doctor=実体 / 既存doctorも是正後
  FAIL）+ タスクロック強制経路（DoD+通常doctor FAIL+Iron Law）+ 完全機械化は
  V2 を contract doc に明文化
- minor: apply は冒頭で JSON 妥当性 load・sed 廃止(python)・失敗時 restore

## 2. 既知課題一覧

- `.claude/settings.json` への wiring 実適用は **ユーザー実行**
  （`sh scripts/apply-claude-settings.sh`。AI は self-mod ガードで不可）。
  これは TASK-0080 の前提（Shadow Config を「適用済みと誤認できない」構造に
  する）であり既知課題ではなく設計。
- EH-9 ブロックの JSON 構造マージは apply script では手動案内（自動 JSON
  マージの破壊回避）。doctor --check-settings で再検証可。

## 3. V2 / follow-up

- AC-7: 本 PBI マージ後に TASK-0071 INDEX/handoff を S1+S2 完了へ更新
- TASK-0071 S3（EH-3 メンテモード/SKIP_REASON・S3a の C-3 3点確定が前提）
- TASK-0071 S4（責務4分類 rules 正本化）
- apply script の EH-9 構造マージ自動化（現状 手動案内）

## 4. 妥協点

- タスクロック強制層 = doctor連動 + workflow DoD 併用（C-3確定）。新規 Hook を
  増やさず既存ゲート機構（V-1/handoff DoD）に乗せ決定論性を確保
- settings 実適用は AI 不可（self-mod ガード恒久受容）。script+検証+ロックで
  Shadow Config を構造解消

## 5. 引き継ぎ文書（5分サマリ）

本セッション通底の「.claude/settings.json は AI 編集不可 → AC-8 wiring 手動
依存・AI が適用済みと誤認する Shadow Config」を恒久対処。wiring 契約正本 +
冪等 apply script + `doctor --check-settings` + V-1/handoff DoD タスクロック +
CI drift(required) を実装。doctor が未適用を**機械検出**するようになり
（main の false-PASS を是正）、適用するまで完了扱いにできない。hook 78/0・
CLI 64/0・doctor --json 不変。残: V-3/V-4/C-4 + AC-7 follow-up。

## 6. テスト結果サマリ

- hook 回帰: 78 passed / 0 failed
- CLI tests: 64 passed / 0 failed
- doctor --json: 16 checks 不変（非破壊）
- doctor --check-settings: 未適用 .claude/settings.json を正しく FAIL（列挙）
- check-settings-wiring --target example: PASS（契約↔settings.example.json 整合）
- 変更スコープ: working-context / settings.example.json / ci.yml / bin/plangate /
  05_verify_and_handoff + 新規(contract doc/apply script/check script) + TASK-0080 docs
