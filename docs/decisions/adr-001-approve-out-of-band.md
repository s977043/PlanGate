# ADR-001: plangate approve の out-of-band 承認設計

**Status**: Proposed  
**Date**: 2026-06-22  
**PBI**: TASK-0139 (#550) — approve 強化（#527 EPIC Enforcement Integrity 子課題）  
**Decision Makers**: mine_take

---

## Context

`plangate approve` は Human-presence 検証（L1-L4）により AI 自己承認を防止するが、
以下の残存リスクが #546 Codex レビューで指摘された:

1. `read` なしの `-r` 漏れ → バックスラッシュエスケープ注入の余地
2. `PLANGATE_FAKE_PPID_COMM` env が本番経路でも機能 → L3 テスト注入 env でバイパス可能
3. 既存 c3.json を `--force` なしで上書き可能 → 承認記録の不可逆性を破る
4. **nonce 表示型の限界** → 疑似 TTY 自動化がスクリーンリードで回避可能（本 ADR の主題）

TASK-0139 P0 で 1-3 を修正した。本 ADR は 4 番（out-of-band 承認設計）の
選択肢と推奨案を記述し、**実装は次フェーズ**とする。

## Problem Statement

現行の L4 nonce チャレンジは「疑似 TTY 上で動作する AI Agent がスクリーンリードで
nonce を読み取り、stdin に入力する」シナリオを防げない。L1-L3 は TTY / env /
プロセス系統で検出するが、L4 は入力値のマッチングのみであり、
「自動化プロセスがターミナルを制御している場合」には機能しない。

真の Human 物理存在証明には、計算機の外に確認手段が必要となる（out-of-band 検証）。

## Decision Drivers

- **セキュリティ**: AI Agent による承認偽装を防ぐ
- **UX**: 人間の承認作業の手間を最小化する（承認は判断であり事務作業ではない）
- **実装コスト**: 依存ライブラリ・外部サービスが不要なほど望ましい
- **監査可能性**: 承認の根拠が記録に残ること

## Considered Options

### Option A: OS Keychain / Touch ID / Face ID

macOS Keychain や Touch ID を利用し、承認時にバイオメトリック認証を要求する。

**Pros**:
- 物理的な人間の存在を強制できる（デバイス所持 + 生体認証）
- 自動化による回避が困難

**Cons**:
- macOS 依存（Linux / CI 環境で動作しない）
- `security` CLI や `LocalAuthentication` framework の呼び出しが必要（複雑）
- ポータビリティが低い

**Verdict**: 将来の macOS 専用強化オプションとして保留。

### Option B: HMAC Signed Token（外部署名 / ハードウェアキー）

承認時に GPG 署名または FIDO2 / HMAC トークンを要求する。
署名は `git -C "$plangate_root" -c user.signingkey=... tag -s` パターン等。

**Pros**:
- 暗号学的な人間検証が可能
- 既存の GPG / SSH キーを流用できる
- 監査ログに署名が残る

**Cons**:
- GPG / SSH エージェントの設定が必要（環境依存）
- 鍵管理コスト（revocation / rotation）
- 現行 `git-config` 由来 `approved_by` との整合が必要（#420 EH-3 provenance hardening）

**Verdict**: #420 EH-3 provenance hardening との統合で実装を検討する（後続フェーズ）。

### Option C: OTP / ハードウェアキー（TOTP / HOTP）

TOTP（RFC 6238）ベースの時刻同期型 OTP を approval チャレンジに組み込む。
人間のスマートフォンアプリ（Google Authenticator / 1Password 等）で生成したコードを入力する。

**Pros**:
- 物理デバイス（スマートフォン）の所持を要求できる
- ソフトウェアのみで実装可能（pyotp 等）
- クロスプラットフォーム

**Cons**:
- TOTP シークレットの初期設定・管理が必要
- `pyotp` 等の追加依存が必要
- 30 秒ウィンドウの制約（タイムスキューリスク）

**Verdict**: シンプルな out-of-band として有力。後続フェーズで評価。

### Option D: plangate approve --oob-token（外部チャネル通知）

承認リクエスト時に Slack / Email 等の外部チャネルにワンタイムトークンを送信し、
そのトークンを CLI に入力する。

**Pros**:
- out-of-band 通信チャネルにより、AI Agent が同一プロセスで完結できない
- 通知チャネルに監査証跡が残る

**Cons**:
- 外部サービス依存（Slack / Email サーバー等）
- CI 環境でのセットアップが複雑
- 通知失敗時の fallback が必要

**Verdict**: チームワークフロー統合の場合に有用だが、ローカル単体では依存過多。

## Decision

**現時点の決定**: TASK-0139 は選択肢の定義・記録まで（ADR Proposed 状態）。

実装フェーズの推奨順序:
1. **短期（#527 後続）**: Option B（HMAC/GPG 署名）+ #420 EH-3 provenance hardening の統合
2. **中期**: Option C（TOTP）を追加選択肢として提供
3. **長期**: Option A（Touch ID）を macOS opt-in として追加

現行 L4 nonce は「best-effort 防御」として TASK-0139 P0 修正後も存続する。
out-of-band 実装完了まではこの制約を docs/c3-approval-command.md に注釈する。

## Consequences

### Positive
- 設計の選択肢が明文化され、後続フェーズで実装判断の根拠として参照できる
- best-effort 制約が正式に記録される

### Negative / Risks
- 本 ADR の期間中、L4 は引き続き best-effort 防御にとどまる
- Option B 実装時に既存 c3.json の `plan_hash` / `approved_by` フィールドの変更が生じる可能性

## Related

- Issue: #550 (plangate approve 強化)
- EPIC: #527 (Enforcement Integrity)
- #420: EH-3 provenance hardening（発行元検証ギャップ）
- `docs/c3-approval-command.md`: plangate approve コマンド設計正本
- `TASK-0128`: plangate approve コマンド実装
- `.claude/rules/responsibility-classes.md`: 承認責務 4 分類
