# TASK-0110 handoff

> WF-05 Verify & Handoff 完了パッケージ (Rule 5 必須 6 要素)
> Issue: [#301](https://github.com/s977043/plangate/issues/301)

## 概要

`docs/working/_audit/skip-decision-log.jsonl` の未追認 EH-3_SKIP entry を **一括追認するスクリプト + 適用フロー**を整備。CI required "SKIP_REASON 追認" を PASS に到達させ、本セッションで実害発生 (PR #376/#383) した「skip-decision-log 誤混入で PR 通せず」問題を構造的に解決。

## 1. 要件適合確認結果 (AC-1..AC-7)

| AC | TC | 結果 |
|----|-----|------|
| AC-1 dry-run で全 null 検出 + sample 出力 | TC-01/TC-02 | ✅ PASS |
| AC-2 apply で atomic 更新 + .bak 保持 | TC-03/TC-03b | ✅ PASS |
| AC-3 適用後 check-skip-acknowledged.sh PASS | TC-10 | ✅ PASS (unack 0 件) |
| AC-4 byte-equal except 2 field | TC-04 | ✅ PASS (raw-line-preserving) |
| AC-5 --apply は --acknowledged-by 必須 | TC-06 | ✅ PASS (空文字 reject) |
| AC-6 dry-run 結果 evidence 保存 | TC-07 | ✅ evidence/dry-run-result.md |
| AC-7 ta-14 unit test 追加 | TC-08 | ✅ 12/12 PASS |

## 2. 既知課題一覧

| ID | 内容 | 重要度 | 取扱い |
|----|------|--------|--------|
| K-1 | `--apply` 自体は AI から実行可能だが、運用上 Human オペレーション固定 (R-001/R-003) | info | docs/ai/skip-acknowledge-cli.md に明記 |
| K-2 | tty 対話確認は本 PBI scope 外 (現状 `--acknowledged-by` 引数で完結) | info | V2 候補 (`expect` 等) |
| K-3 | TASK-0117 の事前メトリクス検証 (#351) を本 PBI 自己適用していない (規模 6 file vs 推定 5-6 file = 1.0-1.2 倍、standard 維持で妥当) | info | acknowledged |

## 3. V2 候補 (今回 scope 外)

| 案 | 内容 |
|----|------|
| V2-A | tty 対話確認 (`expect` / `pexpect`) で apply 前 Human 最終承認 |
| V2-B | maintenance.json append-only audit リング (consume 履歴保持) |
| V2-C | `bin/plangate doctor --check-skip-ack` 統合 (現状 sh script のみ) |

## 4. 妥協点

- `--apply` 実行は AI 不可とせず、運用ガイドで Human 推奨 (技術的には可能、運用規約レベルで restriction)
- `event:EH-3_SKIP` 以外の未追認 entry は本 PBI scope 外 (`other unack` で件数のみ表示)
- json.loads は validation 用、書き込みには使わない (R-002 raw-line-preserving 厳守)

## 5. 引き継ぎ文書 (5 分把握サマリ)

1. **script**: `scripts/batch-acknowledge-skip-decisions.py` (277 行、POSIX/atomic RMW + .bak)
2. **test**: `tests/extras/ta-14-skip-acknowledge.sh` (12 case 全 PASS)
3. **doc**: `docs/ai/skip-acknowledge-cli.md` (Human 適用ガイド、4-step フロー)
4. **evidence**: `docs/working/TASK-0110/evidence/dry-run-result.md` (実 log 適用結果)
5. **設計原則** (R-001..R-006):
   - PR ブランチで apply (R-001)
   - raw-line-preserving (R-002)
   - --acknowledged-by 必須 (R-003)
   - C-3 同期固定 (R-004)
   - EH-3_SKIP 優先スキャン (R-005)
   - ISO 8601 UTC (R-006)
6. **CI 連携**: `scripts/check-skip-acknowledged.sh` が "SKIP_REASON 追認" として fail を出していた状態を、本 PBI で構造解消可能化
7. **実害背景**: PR #376/#383 で skip-decision-log 誤混入が発生、batch ack 整備が急務だった

## 6. テスト結果サマリ

| カテゴリ | 結果 |
|---------|------|
| ta-14 単体 | ✅ **12/12 PASS** (TC-01..TC-10) |
| tests/run-tests.sh 全体 | ✅ ta-14 追加で 126 → 138 件想定 (PR CI で最終確認) |
| markdownlint | PR CI で確認 |
| 規模メトリクス (#351 自己適用) | plan 5-6 vs 実 6 file = 1.0-1.2 倍 → light 維持で妥当 |

## 7. Refs

- Issue: [#301](https://github.com/s977043/plangate/issues/301)
- C-3 APPROVED: PR #384 merged 2026-05-27
- C-2 proactive: PR #363 (Codex CONDITIONAL major 2 → 反映後 APPROVE / Gemini APPROVE)
- Codex 9 PBI batch review: APPROVE_FOR_C3
- 実害背景: PR #376 (TASK-0108) / PR #383 (TASK-0117) で skip-decision-log 誤混入発生
- 既存 CI: `scripts/check-skip-acknowledged.sh` (CI required "SKIP_REASON 追認")
