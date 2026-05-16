---
task_id: TASK-0080
artifact_type: review-external
schema_version: 1
status: done
phase: V-3
---

# V-3/V-4 外部レビュー — TASK-0080（Governance Hardening S1+S2）

critical。Codex + Gemini 実行。

## 判定: Codex=critical2/major3/minor3 → fix-loop / Gemini=APPROVED(Governance mandated)

Codex critical をブロッカー採用（Shadow Config 恒久対処の核心に直結）。

| # | Sev | 指摘 | 対応 |
|---|-----|------|------|
| CR-1 | critical | apply script が EH-9 を実適用せず案内のみ→「適用済み誤認」再導入 | python JSON 構造マージで EH-3 PLANGATE_HOOK_FILE+EH-9 を実適用、backup&restore、適用後契約検証で未適用残は非0。一時コピーで before FAIL→after PASS・冪等・JSON valid 検証 |
| CR-2 | critical | check-settings が grep のみ→_comment_/別matcher/無効JSON で偽陰性 | python で .hooks.PreToolUse[] の matcher/command を構造検証。example exit0 / user exit1 |
| MJ-1 | major | タスクロックが doc DoD のみ・機械結線なし | contract doc に強制経路明文化（DoD + 通常 doctor FAIL（false-PASS是正済）+ Iron Law。完全機械化は V2） |
| MJ-2 | major | CI は example のみ・user 実体 drift 非検出 | 責務分離表を contract doc に明記（CI=reference健全性 / doctor=実体） |
| MJ-3 | major | doctor --check-settings が通常 doctor と非合成 | 通常 doctor hook-wiring も是正後 FAIL する旨を明文化（--check-settings は構造精密版） |
| mn | minor | apply JSON妥当性/sed脆弱/AC-6解釈 | 冒頭 json.load 検証・sed 廃止(python)・失敗時 restore・AC-6 を handoff §1-bis で説明 |

## Gemini: APPROVED（Governance mandated）
- self-mod ガードを逆手に取った DoD タスクロックを「決定打」と評価
- grep トークン検証（→ fix-loop で構造検証へ更に強化）/ DoD 昇格を高評価

## V-4 リリース前チェック（critical 必須）: 全 PASS
- hook 78/0・CLI 64/0・doctor --json 不変・scripts/bin/ci.yml 構文/YAML valid
- CR-1/CR-2 exit code 検証・スコープ是正（TASK-0059 混入除外）

## 出典
- Codex: /tmp/t0080-codex-v3.md（critical2/major3）
- Gemini: /tmp/t0080-gemini-v3.md（APPROVED）
