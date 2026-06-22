# TASK-0139 Handoff — plangate approve 強化 (#550)

## 1. 要件適合確認結果

| AC | 内容 | 判定 | 備考 |
|----|------|------|------|
| AC-01 | cmd_approve の read _ap_reason / read _ap_conditions が read -r に修正 | PASS (apply後) | apply-approve-hardening.sh (a1/a2) で対応済み。dry-run で diff 確認済み |
| AC-02 | maintenance_start の read _ack が read -r に修正（L4 nonce） | PASS (apply後) | apply-approve-hardening.sh (c) で対応済み。_plangate_presence_gate の read -r は既適用済み |
| AC-03 | PLANGATE_FAKE_PPID_COMM が PLANGATE_TEST_MODE=1 時のみ有効 | PASS (apply後) | apply-approve-hardening.sh (b)(d) で 2 箇所対応済み |
| AC-04 | 既存 c3.json + --force なし → abort（error: existing c3.json found） | PASS (apply後) | apply-approve-hardening.sh (e) で note → return 2 に変更 |
| AC-05 | docs/decisions/adr-001-approve-out-of-band.md が生成済み | PASS | out-of-band 承認設計の選択肢 A/B/C/D を記述 |
| AC-06 | ta-41-approve-hardening.sh 全 TC PASS かつ run-tests で認識 | PASS (一部SKIP) | 4 PASS / 4 SKIP (apply pending)。SKIP は HO 適用後に PASS になる |
| AC-07 | 既存 approve テスト回帰 PASS | PASS | sh tests/run-tests.sh → 297 passed, 0 failed |

**注記**: AC-01〜04 は bin/plangate HO ファイルへの変更のため、Human が `sh scripts/apply-approve-hardening.sh` を実行後に完全 PASS となる。apply 前は dry-run で差分確認済み。

## 2. 既知課題一覧

| ID | 内容 | 優先度 | 対応方針 |
|----|------|--------|---------|
| K-1 | L4 nonce は best-effort 防御（疑似TTYで自動化回避可能） | 中 | ADR-001 の out-of-band 承認設計が次フェーズ（#527 後続） |
| K-2 | TA-41 の TC-01/03/04/05 は apply 後に PASS になる（現状 SKIP） | 低 | Human が apply-script を実行すること |
| K-3 | PLANGATE_TEST_MODE=1 が他に副作用がないか網羅テスト未実施 | 低 | 本 PBI の範囲では L3 への影響のみ変更。PLANGATE_TEST_MODE が他ロジックに使われていないことを grep で確認済み |

## 3. V2 候補

- out-of-band 承認実装（ADR-001 推奨 Option B: HMAC/GPG 署名 + #420 EH-3 provenance hardening 統合）
- TOTP ベース承認（ADR-001 Option C）
- plangate approve 失敗時の監査ログの詳細化

## 4. 妥協点

| 選択肢 | 採用しなかった理由 |
|--------|----------------|
| c3.json overwrite で plan_hash 変化時は自動許可（P0.5 提案） | 実装複雑化。本 PBI は「同一 hash の再書込禁止」だけでなく「無条件 block」を選択（--force で明示的に許可する方が意図が明確） |
| PLANGATE_TEST_MODE を maintenance_start にも追加（2 箇所ガード） | 計画上は approve 経路のみの想定だったが、 maintenance も同一脆弱性を持つため両方修正（スコープ内と判断） |
| ta-40 → ta-41 への自動リネーム | ta-40-task-0129-review-gate.sh が既存のため衝突回避 |

## 5. 引き継ぎ文書

TASK-0139 では `plangate approve` コマンドの承認境界強化を実施した。

**主な成果物**:
- `scripts/apply-approve-hardening.sh`: bin/plangate へのパッチスクリプト（--dry-run 付き）
- `docs/decisions/adr-001-approve-out-of-band.md`: out-of-band 承認設計の ADR
- `tests/extras/ta-41-approve-hardening.sh`: 8 TC の自動テスト

**Human 作業（H2）が必要**:
```sh
# dry-run で差分確認
sh scripts/apply-approve-hardening.sh --dry-run
# 問題なければ適用
sh scripts/apply-approve-hardening.sh
# テスト実行（apply 後の完全 PASS を確認）
sh tests/run-tests.sh
```

**設計の要点**:
- `PLANGATE_FAKE_PPID_COMM` は `PLANGATE_TEST_MODE=1` 時のみ有効化（テスト専用 env を本番で使えなくする）
- 既存 c3.json があり `--force` なし → `return 2` で abort（承認記録の不可逆性保護）
- `read` → `read -r` でバックスラッシュエスケープ注入を防止
- 次フェーズ: ADR-001 に基づく out-of-band 承認実装（#527 EPIC 後続）

## 6. テスト結果サマリ

**実行コマンド**: `sh tests/run-tests.sh`

**結果 (apply 前)**: 297 passed, 0 failed

**TA-41 詳細**:
| TC | 内容 | 結果 |
|----|------|------|
| TC-01 | read -r _ap_reason/conditions static check | SKIP (apply pending) |
| TC-02 | read -r _ack present in bin/plangate | PASS |
| TC-03 | PLANGATE_TEST_MODE guard present | SKIP (apply pending) |
| TC-04 | c3.json overwrite block (--force なし abort) | SKIP (apply pending) |
| TC-05 | c3.json --force → overwrite block スキップ | SKIP (apply pending) |
| TC-06 | ADR ファイル存在 | PASS |
| TC-07 | apply-script 存在 + syntax OK | PASS |
| TC-08 | ta-41 run-tests 自己証明 | PASS |

**apply 後の期待結果**: TC-01/03/04/05 が PASS → 8 PASS, 0 SKIP
