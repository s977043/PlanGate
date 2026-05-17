---
task_id: TASK-XXXX
artifact_type: run-outcome-review
schema_version: 1
status: draft
---

# Run Outcome Review — TASK-XXXX

> **これは何か / handoff との責務違い（必読）**
> `run-outcome-review.md` は **run の改善学習**（なぜ良かった/迷走したか、
> 次回再利用すべき判断）を残す任意の振り返り。一方 `handoff.md` は
> **次の担当者への引き継ぎ**（要件適合・既知課題・V2・テスト結果）。
> 役割が異なる: handoff=完了資産の引き継ぎ / outcome review=run の学習。
> 本ファイルは **任意（optional）**。WF-05 完了後に書いてよい（必須化しない）。
> WF-06 Retro（opt-in）が有効な run では本テンプレの 5 項目を入力に用いる
> （[`docs/workflows/06_retro.md`](../../workflows/06_retro.md) /
> [`docs/ai/retro-phase.md`](../../ai/retro-phase.md) と 5 項目一致）。

## 必須 5 項目

### 1. 目的達成可否

<run の目的を達成したか。未達なら何が残ったか。>

### 2. 失敗・手戻り

<失敗・迷走・手戻りは何か。発生箇所と原因。>

### 3. 次回再利用すべき判断

<次回同種 run で再利用したい判断・パターン・回避策。>

### 4. 効いた skill / gate / artifact

<どの skill / gate（C-1/C-2/C-3/V-x）/ artifact が品質に効いたか。>

### 5. 1 人運用で負荷が高かった箇所

<1 人運用上、認知・操作負荷が高かった箇所（改善ネタの源）。>

---

## 記入例（実 TASK ベース: TASK-0080 Governance Hardening S1+S2）

### 1. 目的達成可否
達成。settings 自己改変ガード下の Shadow Config を wiring 契約 + apply
script + doctor --check-settings + V-1/handoff タスクロック + CI drift で
構造解消。AC-1〜7 PASS（AC-7 は後続 follow-up）。

### 2. 失敗・手戻り
V-3 で apply script が EH-9 を実適用せず案内のみ＝「適用済み誤認」を
再導入していた critical を指摘され fix-loop（python JSON 構造マージへ刷新）。
check スクリプトも grep→JSON 構造検証へ書き直し。

### 3. 次回再利用すべき判断
「AI が物理的に不可能な操作（self-mod 対象適用）は AI-owned にしない。
script+検証+ロックを提供し適用は Human-owned」。責務4分類（#256）に昇格。

### 4. 効いた skill / gate / artifact
multi-agent V-3（Codex）が apply 実適用漏れ・grep 偽陰性を捕捉。V-4
リリース前チェックで非破壊（hook 78/0・既存 doctor byte 不変）を保証。

### 5. 1 人運用で負荷が高かった箇所
settings 適用が self-mod ガードで毎回ユーザー手動依存だった点 → 本 PBI
自体が 1 コマンド化（apply-claude-settings.sh）で恒久解消。
