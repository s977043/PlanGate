# PBI INPUT PACKAGE — TASK-0139 (#550)

## Context / Why

`plangate approve` の Human-presence 検証（L1-L4）は best-effort であり、#546 Codex レビューで以下の残存リスクが指摘された:
1. `read` なしの `-r` 漏れ → バックスラッシュエスケープ注入の余地
2. `PLANGATE_FAKE_PPID_COMM` env が本番経路でも機能 → L3 をテスト注入 env でバイパス可能
3. 既存 c3.json を `--force` なしで上書き可能 → 承認記録の不可逆性を破る
4. nonce 表示型の限界 → 疑似 TTY 自動化がスクリーンリードで回避可能

本 issue は #527 EPIC（Enforcement Integrity）の子課題として、上記 4 点を修正・設計する。

## What（Scope）

**In scope**:
- `bin/plangate` の `cmd_approve` / `_plangate_presence_gate` / `cmd_maintenance_start` の read -r 化（3行）
- `PLANGATE_FAKE_PPID_COMM` を `PLANGATE_TEST_MODE=1` ガードに変更（2箇所）
- c3.json 上書きポリシー: `--force` なし overwrite をデフォルト **block**（note → abort）
- out-of-band 承認設計 ADR（`docs/decisions/adr-001-approve-out-of-band.md`）— 実装は次フェーズ
- planning artifact（TASK-0128 plan.md 等）への「best-effort」追補注釈は docs コメントのみ

**Out of scope**:
- out-of-band の実装（HMAC / OS keychain / 外部署名 — 設計 ADR まで）
- #420（EH-3 provenance hardening）との統合実装
- L1-L4 以外の presence gate 変更

## 受入基準

- AC-01: `cmd_approve` の `read _ap_reason` / `read _ap_conditions` が `read -r` に修正される
- AC-02: `maintenance_start` 内の `read _ack` が `read -r` に修正される（L4 nonce）
- AC-03: `PLANGATE_FAKE_PPID_COMM` が `PLANGATE_TEST_MODE=1` 時のみ有効（本番経路では L3 に影響しない）
- AC-04: 既存 c3.json がある場合、`--force` なしは abort（`printf 'error: existing c3.json...'`）
- AC-05: `docs/decisions/adr-001-approve-out-of-band.md` が生成され out-of-band 設計の選択肢を記述
- AC-06: テスト `ta-40-approve-hardening.sh` が全 TC PASS かつ run-tests で認識
- AC-07: 既存 approve テスト（ta-15 相当）が回帰 PASS

## Notes from Refinement

- `--force` は既にフラグとして存在するため、動作変更は note→abort のみ
- テストで `PLANGATE_FAKE_PPID_COMM` を使っている箇所は `PLANGATE_TEST_MODE=1` も同時に設定する
- ADR の選択肢: A) OS keychain, B) HMAC signed token, C) OTP/hardware key — 本 PBI は選択肢提示まで
- `bin/plangate` は HO → apply-script 経由の人間適用
