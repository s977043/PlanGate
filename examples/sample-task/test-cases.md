---
task_id: sample-task
artifact_type: test-cases
schema_version: 1
---

# TEST CASES — Add User Registration Endpoint

## AC → TC マッピング

| Acceptance Criteria | Test Cases |
|--------------------|-----------|
| AC-1: 有効body → 201 + { id, email, created_at } | TC-01 |
| AC-2: 重複メール → 409 | TC-02 |
| AC-3: 不正メールフォーマット → 400 | TC-03, TC-E3 |
| AC-4: パスワード7文字以下 → 400 | TC-04, TC-E4 |
| AC-5: bcryptハッシュでDB保存 | TC-05 |
| AC-6: メールlowercase正規化 | TC-06 |
| AC-7: unit tests + integration tests PASS | TC-07, TC-08 |
| エッジケース | TC-E1〜TC-E5 |

## テストケース一覧

### 正常系

**TC-01: 有効なリクエスト → 201 Created**

- 前提: DBに同一メールが存在しない
- 入力: `POST /api/users` body = `{ "email": "user@example.com", "password": "password123" }`
- 期待: HTTP 201, body = `{ "id": <number>, "email": "user@example.com", "created_at": <timestamp> }`
- 種別: integration

**TC-02: 重複メール → 409 Conflict**

- 前提: `user@example.com` が既にDBに存在する
- 入力: `POST /api/users` body = `{ "email": "user@example.com", "password": "anotherpass" }`
- 期待: HTTP 409, body = `{ "error": "Email already registered" }`
- 種別: integration

### 異常系

**TC-03: 不正メールフォーマット → 400 Bad Request**

- 入力: `{ "email": "not-an-email", "password": "password123" }`
- 期待: HTTP 400, body = `{ "error": "Invalid email format" }`
- 種別: integration

**TC-04: パスワード7文字 → 400 Bad Request**

- 入力: `{ "email": "user@example.com", "password": "short1!" }`
- 期待: HTTP 400, body = `{ "error": "Password must be at least 8 characters" }`
- 種別: integration

**TC-05: bcryptハッシュ保存確認**

- 入力: 正常登録リクエスト
- 期待: DBの `password_hash` カラムが `$2b$` で始まるbcrypt形式。平文パスワードと一致しない
- 種別: integration

**TC-06: メールlowercase正規化**

- 入力: `{ "email": "USER@EXAMPLE.COM", "password": "password123" }`
- 期待: HTTP 201, DBに `"user@example.com"` として保存
- 種別: integration

### unit テスト確認

**TC-07: `isValidEmail` unit tests PASS**

- 入力パターン: `"user@example.com"` (valid), `"not-an-email"` (invalid), `""` (invalid), `"a@b.c"` (valid)
- 期待: 各パターンで `true` / `false` が正しく返る
- 種別: unit

**TC-08: `isValidPassword` unit tests PASS**

- 入力パターン: `"password123"` (valid, 8+), `"short1!"` (invalid, 7), `""` (invalid)
- 期待: 各パターンで `true` / `false` が正しく返る
- 種別: unit

### エッジケース

**TC-E1: bodyなし → 400**

- 入力: `POST /api/users` body = `{}`
- 期待: HTTP 400
- 種別: integration

**TC-E2: emailのみ（passwordなし）→ 400**

- 入力: `{ "email": "user@example.com" }`
- 期待: HTTP 400
- 種別: integration

**TC-E3: 最大長メール（254文字）→ 201**

- 入力: 254文字の有効メールアドレス
- 期待: HTTP 201（RFC 5321の上限内）
- 種別: integration

**TC-E4: 空文字パスワード → 400**

- 入力: `{ "email": "user@example.com", "password": "" }`
- 期待: HTTP 400
- 種別: integration

**TC-E5: SQL injectionパターンのメール → 400または安全に処理**

- 入力: `{ "email": "'; DROP TABLE users; --", "password": "password123" }`
- 期待: HTTP 400（メールバリデーションで弾く）またはパラメタライズドクエリで安全に処理
- 種別: integration
