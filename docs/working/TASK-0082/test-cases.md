---
task_id: TASK-0082
artifact_type: test-cases
schema_version: 1
status: draft
---

# テストケース定義 — TASK-0082

| AC | TC |
|----|----|
| AC-1 | TC-1 |
| AC-2 | TC-2 |
| AC-3 | TC-3 |
| AC-4 | TC-4,TC-5 |
| AC-5 | TC-6 |
| AC-6 | TC-7,TC-8 |
| AC-7 | TC-9 |
| AC-8 | TC-10 |
| AC-9 | TC-11 |

## テストケース
- **TC-1**: 有効 maintenance.json（until>now・構造妥当）下で非 plan.md 編集 → SKIP exit0
- **TC-2**: 有効メンテ下でも `*/plan.md`/`plan.md` → 必ず BLOCK exit2（E1）
- **TC-3**: BYPASS=1 + メンテ + plan.md → exit0（BYPASS>メンテ。優先順 E2）/ メンテ無 + 通常は従来
- **TC-4**: until < now（期限切れ）→ メンテ無効（従来動作）
- **TC-5**: maintenance.json 不正JSON/until非数/欠落 → fail-closed（メンテ無効）
- **TC-6**: env のみ（PLANGATE_MAINTENANCE 等）でファイル無 → メンテ無効（承認ファイルのみ）
- **TC-7**: SKIP 場面で SKIP_REASON 空 → SKIP せず停止（非0）
- **TC-8**: SKIP_REASON 設定 → SKIP + decision-log.jsonl に reason append
- **TC-9**: SKIP_REASON 未追認 PR を CI required check が fail させる
- **TC-10**: メンテ突入/失効/SKIP が _audit に machine-readable 記録
- **TC-11**: maintenance.json 不在 & SKIP_REASON 設定で既存 P4(d) 挙動不変・hook 78/0

## エッジケース
- E1: plan.md 常時 BLOCK（メンテ・大文字/末尾空白/decoy でも・P4d 正規化と整合）
- E2: until 既定+30分・最大30分（超過値は30分にクランプ or fail-closed）
- E3: 承認ファイル approvals/ 配置（C-3 ゲート領域＝改竄は plan_hash 系と別途監査）
