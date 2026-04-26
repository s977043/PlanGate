# Handoff Package — Add User Registration Endpoint

> WF-05 Verify & Handoff の必須出力。
> 配置先: `examples/sample-task/handoff.md`

## メタ情報

```yaml
task: sample-task
related_issue: N/A (example)
author: qa-reviewer
issued_at: 2026-04-26
v1_release: N/A (example artifact)
```

---

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| AC-1: 有効body → 201 + { id, email, created_at } | PASS | TC-01: integration test PASS。id・email・created_atの全フィールド存在確認 |
| AC-2: 重複メール → 409 | PASS | TC-02: DB UNIQUE制約違反をcatchして409を返すことを確認 |
| AC-3: 不正メールフォーマット → 400 | PASS | TC-03: `isValidEmail`がfalseを返し400レスポンス確認 |
| AC-4: パスワード7文字以下 → 400 | PASS | TC-04: `isValidPassword`がfalseを返し400レスポンス確認 |
| AC-5: bcryptハッシュでDB保存 | PASS | TC-05: DBの`password_hash`が`$2b$12$`形式、bcrypt.compareで照合成功 |
| AC-6: メールlowercase正規化 | PASS | TC-06: `USER@EXAMPLE.COM`入力→DB保存値が`user@example.com`であることを確認 |
| AC-7: unit + integration tests PASS | PASS | TC-07/TC-08: unit 12/12 PASS。TC-01〜TC-08+TC-E1〜E5: integration 13/13 PASS |

**総合**: `7/7 基準 PASS`

---

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2候補か |
|------|---------|------|---------|
| なし | — | — | — |

今回のスコープ内で Critical / Major の課題は発見されなかった。

---

## 3. V2 候補

| V2候補 | 理由 | 推定優先度 | 関連Issue |
|--------|------|----------|---------|
| パスワード強度チェック（Zxcvbn等） | 現状は長さのみ。辞書攻撃耐性を高めるためスコアベース検証を追加 | Medium | — |
| Rate limiting（登録エンドポイント） | 大量リクエストによるDB負荷・アカウント列挙攻撃への対策 | High | — |
| メール確認フロー（Email verification） | 登録後にメールアドレスの所有権を確認。スパム登録防止 | Medium | — |
| メールの前後スペーストリミング | 現状はバリデーションで弾く設計。trim後に再検証する方が UX が良い | Low | — |

---

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| bcrypt cost=12（固定値） | 環境変数で設定可能にする | 今回はシンプルさを優先。設定外部化はV2で対応 |
| DB UNIQUE制約で409を制御 | アプリ側で事前SELECT→INSERT | TOCTOU問題を避けるためDB側で最終制御。パフォーマンスは問題なし |
| email lowercase正規化のみ | 前後スペーストリム | スペース付きメールはバリデーションで弾く設計を選択。将来trimに変更可能 |
| OAuth・メール確認は対象外 | 登録と同時にOAuth連携 | PBIスコープを最小化し、確実にAC-1〜AC-7を満たすことを優先 |

---

## 5. 引き継ぎ文書

### 概要

`POST /api/users` エンドポイントの実装が完了した。
bcrypt cost=12 でのパスワードハッシュ化、メールのlowercase正規化、DB UNIQUE制約を使った重複検出がすべて実装済み。
unit tests（validators）・integration tests（エンドポイント）ともに全件PASSを確認。

### 触れないでほしいファイル

- `src/services/userService.js`: bcryptのasync/await パターンを変更すると平文保存のリスクがある
- `src/validators/user.js`: TC-07/TC-08のunit testsが壊れる変更は要注意

### 次に手を入れるなら

- パスワード強度チェック（V2候補）: `src/validators/user.js` の `isValidPassword` を拡張
- Rate limiting: Expressミドルウェア（express-rate-limit等）を `src/app.js` に追加
- メール確認フロー: 登録後にJWTトークン付きメールを送信する別PBIとして作成

### 参照リンク

- PBI: `examples/sample-task/pbi-input.md`
- Plan: `examples/sample-task/plan.md`
- Test cases: `examples/sample-task/test-cases.md`
- Templates: `docs/working/templates/`

---

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| Unit (validators) | 12 | 12 | 0 | isValidEmail: 100%, isValidPassword: 100% |
| Integration (endpoint) | 13 | 13 | 0 | AC-1〜AC-7 + TC-E1〜E5 全件 |
| **合計** | **25** | **25** | **0** | — |

lint: エラー0件（`npm run lint` PASS）
