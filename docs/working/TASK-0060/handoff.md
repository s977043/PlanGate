# Handoff: TASK-0060 (PBI-HI-008 / Issue #202)

## 1. 要件適合確認結果

| AC | 検証 | 判定 |
|----|------|------|
| AC-01 metrics-privacy.md 存在 | docs/ai/metrics-privacy.md | ✅ PASS |
| AC-02 保存可能 metrics 一覧 | §3 (12 カテゴリ) | ✅ PASS |
| AC-03 保存禁止 metrics 一覧 | §4 (9 カテゴリ) | ✅ PASS |
| AC-04 file path / stack trace / command output 扱い | §5.1〜§5.4 | ✅ PASS |
| AC-05 redact / sanitize 方針 | §6.1〜§6.3 | ✅ PASS |
| AC-06 retention policy | §7 (90日 / 30日 / 永続の使い分け) | ✅ PASS |
| AC-07 public/private repo 運用差分 | §8 (5 観点比較表) | ✅ PASS |
| AC-08 PBI-HI-001 event schema と矛盾なし | §9 (schema 準拠ルール、矛盾時 doc 優先を明記) | ✅ PASS |

**全 8/8 PASS**

## 2. 既知課題

なし。

## 3. V2 候補

- `bin/plangate metrics` 実装時の自動 redaction 機構 (PBI-HI-001 / #195)
- pre-commit hook で metrics log の staging 防止 (v8.7 候補)
- CI baseline snapshot の Forbidden カテゴリ自動検出 (v8.7 候補)
- 完全 DLP / 外部監査連携（明示的に Non-goal）

## 4. 妥協点

- redaction の **アルゴリズム詳細**（hash 関数選定、salt 戦略）は schema 実装フェーズ (#195) で確定する
- retention の自動削除実装は #195 の scope（本 doc は policy のみ）
- 違反検出 hook は v8.7+ 候補として §10 にメモ、本 PBI 範囲外

## 5. 引き継ぎ文書

新規 1 ファイル:
- `docs/ai/metrics-privacy.md` — Metrics v1 実装前の privacy / public data policy 正本

PBI-HI-001 (#195) 着手時の必読文書として §9 を参照。schema 設計が本 doc §3 / §4 から逸脱した場合は **本 doc が優先**、schema 側を改訂する旨を明記。

## 6. テスト結果サマリ

- L-0 markdown lint: CI で確認
- V-1 受入基準照合: 全 8 AC PASS（自己検証）
- 影響範囲: docs only、runtime 変更なし
