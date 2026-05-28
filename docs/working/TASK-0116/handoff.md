# TASK-0116 handoff

> WF-05 Verify & Handoff 完了パッケージ (Rule 5)
> Issue: [#354](https://github.com/s977043/plangate/issues/354)

## 概要

release tag と origin/main の不一致を防ぐ **NO RELEASE WITHOUT TAG-MAIN PARITY** Iron Law を整備。`scripts/check-tag-main-parity.sh` で機械検証、`docs/release-process.md` で運用フロー、`.claude/rules/responsibility-classes.md` §publish に link 追記。

## 1. 要件適合確認結果 (AC-1..AC-6)

| AC | TC | 結果 |
|----|-----|------|
| AC-1 Iron Law doc 追加 | TC-06 | ✅ PASS |
| AC-2 機械検証 script (tag != main exit 1) | TC-01..05 | ✅ PASS |
| AC-3 rule §publish に link | TC-09 | ✅ PASS |
| AC-4 失敗時 --force-with-lease 手順 doc | TC-07 | ✅ PASS |
| AC-5 ta-18 fixture (annotated/lightweight peel 含む) | TC-02/03 | ✅ PASS |
| AC-6 regression + markdownlint | PR CI で確認 | — |
| ~~AC-7 doctor 統合 (stretch)~~ | — | 削除済 (V2 降格 / R-003) |

## 2. 既知課題一覧

| ID | 内容 | 重要度 |
|----|------|--------|
| K-1 | full release flow integration test は実 tag/main 操作要 → ta-18 は fixture + script ロジック検証 | info |
| K-2 | Gemini reviewer は C-2 当時 quota 切れで未取得 → V-3 で再試行可 | info |
| K-3 | CI 化 (bin/plangate doctor 統合) は V2 候補 (stretch AC-7 削除済) | info |

## 3. V2 候補

- V2-A: bin/plangate doctor --scope release で tag-main parity 事後確認
- V2-B: GitHub Actions release workflow に check-tag-main-parity.sh 組込み
- V2-C: Gemini V-3 review (C-2 で quota 切れ分)

## 4. 妥協点

- AC-7 (doctor 統合) を本 PBI から削除、V2 降格 (R-003、bin/plangate HO 改修コスト高)
- Human オペレーション主体 (tag push / force-with-lease / GitHub Release は Human-owned / responsibility-classes.md §publish)
- TASK-0115 と同 file 編集だが編集箇所が異なる (TASK-0115: 新 section / 本 PBI: §publish link) → conflict なし

## 5. 引き継ぎ文書 (5 分把握サマリ)

1. **Iron Law**: NO RELEASE WITHOUT TAG-MAIN PARITY
2. **script**: `scripts/check-tag-main-parity.sh` (git fetch + ^{commit} peel + exit 0/1)
3. **doc**: `docs/release-process.md` (検証フロー + 失敗時 --force-with-lease 貼り替え)
4. **rule link**: `.claude/rules/responsibility-classes.md` §publish に追記
5. **test**: `tests/extras/ta-18-tag-main-parity.sh` (10 case 全 PASS、annotated/lightweight peel 検証)
6. **承認境界**: tag push / force-with-lease / GitHub Release は Human-owned
7. **設計原則** (R-001..R-004):
   - R-001: git fetch origin main (stale 防止)
   - R-002: --force-with-lease + ref 明示
   - R-003: doctor 統合 V2 降格、rule owner 明確化
   - R-004: annotated/lightweight tag ^{commit} peel

## 6. テスト結果サマリ

| カテゴリ | 結果 |
|---------|------|
| ta-18 単体 | ✅ **10/10 PASS** |
| tests/run-tests.sh 全体 | PR CI で確認 (ta-18 追加で +10) |
| syntax check (sh -n) | ✅ PASS |
| 機能テスト (tag 不在 / 引数なし) | ✅ exit 1 + メッセージ |
| 規模メトリクス (#351 自己適用) | plan 5 file vs 実 4 file = 0.8 倍 → standard 維持 |

## 7. Refs

- Issue: [#354](https://github.com/s977043/plangate/issues/354)
- C-3 APPROVED: PR #396 merged 2026-05-28
- C-2 individual: PR #381 (Codex CONDITIONAL major 3 → R-001..R-004 全反映 / Gemini bot PR #381 で 2 件 medium)
- 並列構造: TASK-0115 (#361、merged) と同 file (responsibility-classes.md) 編集、編集箇所異なり conflict なし
- 参考: PocketEitan `.claude/commands/release.md` Phase 5 / memory `feedback_release_tag_collision_verify.md`
