# TASK-0809 Implementation Plan

> Issue: #809 / 前提: PR #808 マージ済みであること（同一ファイル群に触れるため）

## Goal

ai-loop Phase 1 の安全前提（fail-closed・allowed_paths）を規範層から**機械層（arbiter.py）へ配線**し、
導入先リポジトリで HO 境界未確定・scope 逸脱の変更が AUTO_APPROVED に到達する経路を閉じる。

## 前提の実測検証（#786）

| 前提 | 検証コマンド | 実測結果 | 判定 |
|------|-------------|---------|------|
| arbiter に ho-paths 実行時 parse が無い | `grep -n "read_text" scripts/ai-loop/arbiter.py` | ヒット 0（コメント参照のみ） | ✅ |
| 入力スキーマに allowed_paths が無い | `grep -n "allowed_paths" scripts/ai-loop/arbiter.py` | docstring のみ・ロジック 0 | ✅ |
| 既存テストは 64 件 PASS | `python3 -m unittest discover -s scripts/ai-loop` | 64/64 OK（2026-07-11） | ✅ |
| LoopSpec は allowed_paths を既に必須と定義 | `grep -n "allowed_paths" docs/workflows/ai-loop/loopspec.md` | 必須フィールド記載あり | ✅ |
| PR #808 マージ済み | `gh pr view 808 --json state` | **OPEN（未マージ）** | ❌ → exec 開始を #808 マージまでブロック（Replan Trigger 参照） |

## Questions / Unknowns

- .codex 3 配置の cmp 同一性を強制するテストの有無（実装 Step 5 冒頭で実測。強制ありなら sync スクリプト側で分岐）

## Approach Comparison

| 案 | 内容 | メリット | デメリット | 判定 |
|---|------|---------|-----------|------|
| A | HO_PATTERNS を**実行時 parse のみ**に置換 + 解決不能→全件 escalate | 導入先で正しい境界・fail-closed が構造保証 | 既存テストの書き換えが必要 | **採用** |
| B | ハードコードを fallback として残す | テスト変更最小 | 解決失敗時に plangate 固有パターンで**誤った clean 判定**（fail-open の温存）| 不採用 |
| C | 文言注記のみ（機械化しない） | 工数ゼロ | #809 の目的未達 | 不採用 |

## Files / Interfaces

- `scripts/ai-loop/arbiter.py`（parse 層 + fail-closed ガード + allowed_paths 検証 + POLICY_REF @v1）
- `scripts/ai-loop/test_arbiter.py`（TC 追加・既存更新）
- `docs/workflows/ai-loop/00_concept.md` / `execution-runbook.md`（「未実装 #809」注記の解消 + size_ok 順序制約 1 文）
- `docs/workflows/ai-loop/decision-table.md`（record スキーマの policy_ref 記述）
- `.codex/skills/ai-loop-cycle/SKILL.md`（resources 非同梱注記 — Unknown の実測結果に従う）
- `plugin/plangate/skills/ai-loop-cycle/`（sync 伝播）

## Work Breakdown

1. **ho-paths 実行時解決**: 解決順 = `--ho-paths` 引数 > CWD の `docs/ai/ai-loop/ho-paths.md` > スクリプト隣接 `../references/ho-paths.md`（bundled）。表の「HO パス一覧」をパースし (pattern, 分類) を構築
2. **fail-closed ガード**: 解決不能・パース 0 件 → 全 changed_files を `HUMAN_ESCALATED`（reason=`ho-paths unresolved (fail-closed)`）
3. **allowed_paths 検証**: 入力 JSON の必須フィールドに昇格（LoopSpec 必須と整合）。changed_files ⊄ allowed_paths glob → `HUMAN_ESCALATED`。**HO 接触の escalate は allowed_paths に HO を書いても免れない**（I-1 不変）
4. **POLICY_REF bump**: `auto-approve-lite-clean@v0` → `@v1`（本 C-3 承認 + C-4 マージが Human-owned 改版手続きの記録）
5. **.codex 整合 + docs 文言解消**（#808 で入れた「未実装 #809」注記を実装済み表現へ）
6. plugin sync + 全テスト + レビューレーン（高リスクにつき adversarial 含む多レーン）

rollback: 全変更 1 PR・`git revert` 一発（DB/外部状態なし）

## Testing Strategy

test-cases.md の TC-1〜10（解決成功/不能/空・逸脱/適合/欠落・HO 免除不可・@v1 pin・bundled 自立 PASS・drift 追従）。TDD（テスト先行）。

## Replan Triggers / Stop Condition

- #808 が REJECT/大幅変更 → 本 plan の前提崩壊、差分改訂
- 実装中に既存 21 record の互換破壊が判明 → 停止して人間判断（record は追記資産・遡及変更しない方針の確認)
- HO 対象パス（.claude/ 配下等）への変更が必要と判明 → 即停止・apply スクリプト方式へ

## Human Approval Boundary

- 本 plan の C-3（mode=high-risk のため人間必須）/ PR マージ / POLICY_REF 改版の最終確定

## Mode判定

**モード**: high-risk

- 変更ファイル数: 6-8 → high / 変更種別: 安全機構ロジック（セキュリティ関連 → 最低「中」、安全側で high）/ HO 対象: 含まない（scripts/ai-loop・docs/workflows/ai-loop・.codex/skills はいずれも 9 カテゴリ外）
- high-risk → C-2 必須・**人間 C-3 必須**（autonomous APPROVE 不可）
