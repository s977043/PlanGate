---
task_id: TASK-0070
artifact_type: direction-review
schema_version: 1
status: done
---

# 今後の方針 — Codex 提案 × Gemini 検証 統合（2026-05-17）

EH-3/P4(d)・AC-8 self-mod ガード・merge sockpuppet 禁止の構造的摩擦に対する方針。
Codex がドラフト、Gemini が監査検証。両者合意点と Gemini の上書き修正を反映。

## 合意（両者一致・確定方針）

| # | 方針 | 根拠 |
|---|------|------|
| C1 | **AC-8 を Manual Gate 化**。`.claude/settings*.json` を AI 編集前提から外し、AI は「設定パッチ + 検証用テストコード」をセット出力、適用は人間 | self-mod 突破はセキュリティポリシー違反（Gemini critical 同意 + 修正） |
| C2 | **merge は Release Gate 固定**。AI は merge-ready report 責務、Human が C-4 merge decision。sockpuppet 禁止は非交渉 | 監査証跡・責任所在（Gemini critical 同意） |
| C3 | **settings drift check を CI に追加**（必須 check failure）。差分は settings + model-profile.schema との不整合も対象 | 手動適用依存下では設定乖離＝脆弱性（Gemini major 同意 + 拡張） |
| C4 | 責務 4 分類を正式化: AI-owned / Human-owned / CI-owned / Workflow-owned | governance 基盤としての責務分界 |

## Gemini による上書き・格上げ（採用）

| # | 項目 | 内容 | Severity |
|---|------|------|----------|
| G1 | **Shadow Configuration 防止** | settings 手動適用待ちの間、AI が「適用済み」と誤認して行動するリスク。**適用完了までタスクをロック**する仕組みを追加（doctor 検証 PASS まで V-1/handoff を完了扱いにしない） | critical |
| G2 | **heredoc 回避は監査だけでは不十分** | バイパスは「悪意」でなく「UX 欠陥」。SKIP 理由可視化だけでは AI は正当に見える理由を生成し回避継続。**バイパスを不要にする設計**（有効期限付きメンテモード / ハッシュ除外タグ）へ倒す | major |
| G3 | **doctor --check-settings の C-4 必須添付化** | AI が settings 適用状態を検証しその成功ログを C-4 必須添付資料に | major |
| G4 | **EH-3 SKIP 理由監査化は「不十分」** → ガバナンス例外申請プロトコルへ格上げ。SKIP 選択時 `SKIP_REASON` を commit message / todo.md に強制記述、人間が C-3/C-4 で明示追認 | major |
| G5 | jq なし fallback の優先度は低い（`python -m json.tool` 等で代替十分。可読性優先） | minor |

## 確定: 最優先アクション（順序付き）

1. **AC-8 Manual Gate 化 + Shadow Configuration ロック（C1 + G1）**
   - 設定パッチ正本を `docs/ai/` or `templates/` に、適用 script + `bin/plangate doctor --check-settings` を整備
   - doctor 検証 PASS まで該当タスクの handoff/V-1 を完了扱いにしない（タスクロック）
2. **settings drift check を CI required に追加（C3）**
   - `${PLANGATE_HOOK_FILE:-}` wiring 未適用 + schema 不整合を機械検出 → required failure
3. **EH-3 バイパス不要化 + 例外申請プロトコル（G2 + G4）**
   - 有効期限付きメンテモード or ハッシュ除外タグで heredoc を不要に
   - SKIP 選択時 SKIP_REASON 強制記述 → C-3/C-4 で人間追認

## 不一致・留意

- Codex「SKIP 理由を machine-readable 監査」→ Gemini「監査のみは否、例外申請プロトコル必須」。
  → Gemini を採用（監査は必要条件だが十分条件でない）。
- これらは TASK-0070 scope 外。新規 PBI（roadmap）として起票推奨。

## 出典

- Codex: /tmp/t0070-codex-direction.md（reasoning effort: low）
- Gemini 検証: /tmp/t0070-gemini-verify-out.md
