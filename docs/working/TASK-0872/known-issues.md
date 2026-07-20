# Known Issues / V2 候補 — TASK-0872

> WF-05 handoff 発行時にこの内容を handoff.md §V2 候補へ統合する。

## V2 候補

### KI-1: 受理検証ロジックの HO 機械強制（R2-07・Human 決定 B / 2026-07-20）

- **内容**: 受理検証ロジック（`scripts/ai-loop/c3prime_verify.py`）は HO 9 カテゴリ（`check-plan-hash.sh` L124-134 正本）の対象外。将来の非 HO PR 単独で承認ゲートを弱められる構造的余地がある。
- **Human 決定（AskUserQuestion 2026-07-20 verbatim: "B: 現状維持 + V2 明記"）**: 現状維持。HO 化は将来判断。現状は `mode-classification.md`「セキュリティ関連 → 最低『中』」の判断依存保護でカバー。
- **将来の是正案（A・不採用）**: `scripts/ai-loop/*_verify.py` を HO 9 カテゴリへ追加（`check-plan-hash.sh` + `mode-classification.md` を Human patch 適用）→ 機械強制を回復。以後 verifier 編集も HO ceremony。

### KI-2: 脅威モデル境界 — record + tree 双方書換への防御（R2-01 の残余 / #889 Codex）

- **内容**: 現行受理器はローカル作業ツリーの改竄検出（承認後 drift・evidence 改竄）を対象とする。record と作業ツリーの**双方**を任意書換できる攻撃者（同一整合な偽造一式の構築）は、`source_sha` の Git tree 照合または署名済み provenance でのみ防げる。
- **Phase 1 の扱い**: scope 外（eligible run 限定・boundary=clean・信頼済みローカル repo）。契約 §4「脅威モデルの境界」に明記済み。
- **V2 案**: git-tree 束縛（artifact が `source_sha` の committed tree と一致することを照合）または署名済み provenance。

### KI-3: TOCTOU 残余窓（#889 R1 high）

- exec preflight 検証成功〜`session_started` 記録までの 1 shell 文の窓。flock ベースの単一 snapshot 検証を V2 候補（契約 §4 記載）。

### KI-4: ho-apply の切り戻し手順（R2-09 minor）

- `ho-apply-approval.md` に適用失敗時の切り戻し（`git apply -R docs/working/TASK-0872/patches/bin-plangate.patch`）を追記する（次コミット or handoff 時）。
