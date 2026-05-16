---
task_id: TASK-0071
artifact_type: review-external
schema_version: 1
status: done
phase: C-2
---

# C-2 外部レビュー — TASK-0071（plan + S3a 設計note）

critical モードのため C-2 必須。Codex（シニアアーキ/監査）と Gemini（監査）を
独立実行。**両者が独立に同一の critical 2 件を検出**＝設計欠陥の確度が高い。

## 総合判定: CONDITIONAL（C-3 前に S3a 設計修正が必須）

設計方向（案A+C採用 / 案B却下）は両者とも妥当と評価。ただし現案のままだと
「heredoc 回避」を「環境変数による正規バイパス」に置換するだけになる危険。

## Critical（両者一致・C-3 前修正必須）

| # | 指摘 | 出典 | 修正方針（S3a 改訂で反映） |
|---|------|------|----------------|
| CR-1 | `PLANGATE_MAINTENANCE_UNTIL` が env だと AI 自身が付与可能な新バイパス経路。hook 実行時に由来を判定できない | Codex+Gemini | env 廃止。**人間生成の検証可能な承認アーティファクト**（署名/手動生成ファイル、doctor/CI 検証）へ。AI が当該ファイルを生成・改変する行為自体を doctor/EH でブロック |
| CR-2 | 優先順 `bypass > メンテ > 通常` で bypass が最上位のまま → 「バイパス不要化」未達。SKIP_REASON も文字列で通過（理由≠権限） | Codex+Gemini | plan.md 保護では bypass を無効化 or required failure。SKIP は machine-readable event 記録のみ、**人間の署名追認まで CI を green にしない**外部承認ワークフロー強制 |

## Major

- 正規化（大小文字/末尾空白/`./`/JSON decoy: TASK-0070 で固めた hardening）を
  **メンテ判定の前**にも適用（順序誤りで P4(d) hardening を迂回可能）
- メンテ粒度が広すぎ。`task_id` / `scope` / `until` / `reason` / `approved_by`
  を構造化（EH-6 scope guard / drift 検知との責務境界明確化）
- 監査ログが AI append 可能だと証跡が弱い → CI が「SKIP event あり・追認なし」
  を検出して落とす
- メンテ失効デッドロック（実行中に BLOCK 復帰＝自爆）→ ソフトランディング
  （進行 turn は猶予・新規 turn 禁止、失効5分前警告）
- drift check は値だけでなく settings の権限(chmod)/所有者変更も対象（FS メタ監査）

## Minor

- 既定30分は可。ただし最大30分・延長は別承認・同一理由連続延長は警告/失敗
- 時刻は epoch UTC 固定、過去/非数/過大/桁あふれは fail-closed
- SKIP_REASON 疲弊対策: `doctor --report` に週次 SKIP 統計（構造的欠陥の可視化）
- S3 は単独 PR（S1/S2 の settings 正本化・drift check が先にないと S3 検証不能）

## C-3 で確定すべき回答（両者の収束見解）

1. 既定30分=可。**最大30分・延長は別承認**
2. メンテ付与は Human-owned 固定、**env ではなく検証可能な承認ファイル方式**、CI 自動付与禁止
3. **SKIP_REASON 未追認 PR は required failure（必須）**

## 出典

- Codex: /tmp/t0071-codex-c2.md
- Gemini: /tmp/t0071-gemini-c2.md
