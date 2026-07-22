# Handoff — TASK-0896（検証ロジック共通契約層化）

> Issue: [#896](https://github.com/s977043/plangate/issues/896) / Mode: high-risk / branch: `feat/task-0896-c3-contract`
> 発行: 2026-07-22（WF-05）

## 1. 要件適合確認結果（AC ごと）

| AC | 判定 | 根拠 |
|----|------|------|
| AC-1 契約定数の単一モジュール定義（REQUIRED_KEYS 系含む） | **PASS** | c3_contract.py に 7 定数群 + TRIO_KEYS。3 消費者は import 参照（is 同一を ConsumerAliasTests で固定・タプルリテラル重複 grep 0 件） |
| AC-2 sha256 / canonical hash 単一実装 | **PASS** | sha256_of_file / canonical_hash に統合。ローカル hashlib 実装 0 件（TC-4 grep）。producer 出力は新旧 byte 同一（敵対レビュー実測） |
| AC-3 三つ組照合の I/O なし共通純関数・両経路同一実装 | **PASS** | check_snapshot_trio（理由リスト・順序契約・I/O 封じテスト）。arbiter=strict_keys=False / c3prime=True の両経路が同一実装 |
| AC-4 既存テスト全 green（振る舞い不変） | **PASS** | test_arbiter 247 / test_plan_package 30 / test_c3prime_verify 12 / run-tests 412（既存 411 + ta-55 追記 1・既存期待値変更ゼロ）。evidence/test-runs/ |
| AC-5 sync 列挙 + 2 回目 no-op + ta-30 自立 PASS | **PASS** | copy + delete 保護の対列挙。sync 2 回目「no changes」実測・ta-30 scripts=10 / TC-08 bundled 自立 PASS・cmp 10 ファイル byte 一致 |
| AC-6 arbiter が I/O あり関数を import / call しない | **PASS** | AST 回帰検査（test_arbiter_does_not_touch_io_layer）で属性・名前参照 0 を固定 |
| AC-7 偽造 record 群の reject 不変 | **PASS** | 敵対レビューで新旧 37 パターン exit code 全一致 + test_c3prime_verify 12 不変 |
| AC-8 敵対レビュー 1 ラウンド以上の disposition 記録 | **PASS** | 2 レーン（Codex + 独立 behavior-diff）実施。evidence/adversarial-review-disposition.md |

## 2. 既知課題一覧

- **KI-1（AF-1・minor）**: 複合異常入力での先頭 stderr 診断の優先順が変化（verdict 異常より trio 不一致が先）。判定結果・exit code は全一致・機械消費者 0 件を rg 全数確認済み。R-004 順序契約の設計帰結
- **KI-2（AF-2・minor）**: arbiter.py は sys.path 挿入なしで `import c3_contract` する（R-008 の確定設計）。CLI 直実行・test 経由・bundled は全て解決済みだが、`spec_from_file_location` 等の埋め込み import は非サポート経路
- **KI-3（AF-3・info）**: c3_contract.py の部分配布（sync 漏れ）時は c3prime_verify が traceback exit 1（fail-closed）— legacy record も exit 10 でなく 1 になる。sync 対列挙 + ta-30 で構造的に防止済み

## 3. V2 候補

- 理由コード enum + 呼び出し側文言マッピング（KI-1 の受理器レベル順序固定を含む）
- `derived_loopspec_hash` の値検証（AF-4・既存挙動。#874 RunEvidence 契約側で検討）
- arbiter `plan_package_check` の構造検査（PLAN_PACKAGE_REQUIRED_KEYS）と record 検査の関係整理は issue Non-goals どおり非統合を維持

## 4. 妥協点（採用しなかった選択肢と理由）

- 三つ組照合の strict 統一（案 B）: arbiter 側挙動変更になるため不採用 — strict_keys 引数で #889 R2 非対称を保存
- plan_package.py への集約（案 B）: arbiter が producer を import する形になり I/O 層分離が module 境界で保証されないため不採用
- AF-1 対応のテスト追加: plan Files to Touch 外（test_c3prime_verify.py）への変更となるため見送り、記録対応に留めた

## 5. 引き継ぎ文書

c3-prime 契約の検証規則（定数 / hash / snapshot 三つ組照合）が `scripts/ai-loop/c3_contract.py` に単一定義された。**#873 delivery.py / #874 run_evidence.py は本モジュールを import して実装すること**（sys.path.insert の既存パターン: c3prime_verify.py L25 参照）。新スクリプトを追加したら sync-plugin-plangate.sh の copy 列挙 + delete 保護 case の**両方**へ対で追記（漏れると bundled 側 import エラー = ta-30 が検出）。共通層の改版は test_c3_contract.py の契約固定テスト（値 byte 同一・順序契約・純粋性・AC-6 AST 検査）が drift を検出する。4 コミット構成（a=定数 / b=hash / c=trio / d=sync）で各コミット単独 revert 可能。

## 6. テスト結果サマリ

- ベースライン（main b632a91）: 247 / 30 / 12 / 411 全 green（evidence/test-runs/step0-baseline.log。※scripts/ai-loop cwd での test_arbiter 実行は ho-paths 相対解決で FAIL する既知事象 — repo root 実行が正）
- 最終形（99816f8）: test_c3_contract 22 / test_arbiter 247 / test_plan_package 30 / test_c3prime_verify 12 / **run-tests 412 passed 0 failed**（evidence/test-runs/final-verification.log）
- 敵対レビュー: 新旧 behavior diff 37+37 パターン全一致・bundled 自立 4 系 OK（evidence/adversarial-review-disposition.md）
- settings タスクロック: `doctor --check-settings` PASS（handoff 前提充足）
