---
task_id: TASK-0082
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-0082

> TASK-0071 S3 実装（最終スライス）: EH-3 メンテモード（承認ファイル方式）
> + SKIP_REASON 例外申請プロトコル
> 起源: TASK-0071 D-1 第2スライス / s3a-design-note.md（C-2 反映後・C-3 3点確定）

## Context / Why

EH-3（check-plan-hash.sh）の「TASK 文脈なしで全 Edit ブロック→heredoc 回避
常態化」は P4(d) で緩和したが、Gemini は「監査だけでは AI が正当に見える
理由を生成し回避継続＝バイパスを不要にする設計が必要」と指摘。s3a-design-note
で案A（メンテモード）+案C（SKIP_REASON 必須）併用を C-2 反映のうえ策定。
ユーザー C-3 で 3 点確定:
1. メンテ既定 30 分・最大 30 分・延長は別承認
2. **env 廃止・人間生成の検証可能な承認ファイル方式**・CI 自動付与禁止
3. SKIP_REASON 未追認 PR は CI required failure

TASK-0071 D-1 の最終スライス（S1+S2=#254 / S4=#256 完了済）。

## What — Scope

### In scope

- **メンテモード（承認ファイル方式）**: `docs/working/<TASK>/approvals/
  maintenance.json`（`{task_id, scope, until(epoch UTC), reason, approved_by}`）
  が有効（until>now・構造妥当）なら EH-3 が **plan.md 以外**を SKIP。
  - **plan.md は メンテ中でも必ず BLOCK**（E1 不変）
  - 優先順 **BYPASS > メンテ > 通常**（E2）
  - 既定 until = 付与時刻+30分・**最大 30 分**・延長は新規ファイル再付与
  - env では有効化しない（承認ファイルのみ＝検証可能・AI 自己付与不可）
  - 突入/失効/SKIP を `_audit` に machine-readable 記録
- **SKIP_REASON 例外申請**: EH-3 が SKIP する場面で `SKIP_REASON`
  （env or todo.md 記述）が空なら **SKIP せず停止**。reason を
  decision-log.jsonl に append。C-3/C-4 で人間追認の証跡を必須化
- **CI required failure**: SKIP_REASON 未追認（decision-log に reason はあるが
  人間追認マークが無い）PR を落とす CI チェック（required）
- maintenance.json schema 定義 + doctor/契約整合

### Out of scope

- 案B（ハッシュ除外タグ）= 不採用（自己付与回避経路化）
- S1+S2（#254）/ S4（#256）= 完了済
- check-plan-hash.sh の P4(d)/正規化ロジック改変（メンテ分岐を追加するのみ）

## Acceptance Criteria

- [ ] AC-1: maintenance.json（承認ファイル・schema 定義）有効時、EH-3 が plan.md 以外を SKIP する
- [ ] AC-2: メンテ中でも plan.md は必ず BLOCK（E1 不変・回帰）
- [ ] AC-3: 優先順 BYPASS > メンテ > 通常 が成立（E2）
- [ ] AC-4: until は epoch UTC・既定+30分・最大30分・期限切れ/不正値は fail-closed（メンテ無効）
- [ ] AC-5: env でメンテ有効化できない（承認ファイルのみ＝AI 自己付与不可）
- [ ] AC-6: SKIP 場面で SKIP_REASON 空なら SKIP せず停止。reason を decision-log.jsonl に append
- [ ] AC-7: SKIP_REASON 未追認を検出する CI required check が追加される
- [ ] AC-8: 突入/失効/SKIP/メンテSKIP が _audit に machine-readable 記録される
- [ ] AC-9: 既存挙動不変（maintenance.json 不在・SKIP_REASON 設定時は従来動作）。hook テスト回帰なし

## Notes from Refinement

- s3a-design-note.md（C-2 反映済）が設計正本。案A+C 併用
- 承認ファイルは Human-owned（responsibility-classes.md。AI は要求のみ）
- plan.md 常時 BLOCK と BYPASS>メンテ>通常 は不変条件（緩和不可）

## Estimation Evidence

**Risks**: EH-3 強制 Hook の挙動拡張。メンテが新バイパス経路化のリスク →
承認ファイル方式・plan.md常時BLOCK・最大30分・fail-closed・監査で抑制
**Unknowns**: SKIP_REASON 追認マークの形式（decision-log フィールド/別ファイル）
→ plan/C-3 で確定
**Assumptions**: 承認ファイルは人間生成（AI 不可）。Mode=critical（強制Hook
拡張・V-3+V-4 必須）
