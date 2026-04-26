---
task_id: sample-task
artifact_type: plan
schema_version: 1
status: approved
---

# EXECUTION PLAN — Add User Registration Endpoint

## Goal

Implement `POST /api/users` endpoint and satisfy all 7 acceptance criteria (AC-1 through AC-7).

## Constraints / Non-goals

- OAuth, email verification, and password reset are out of scope
- Rate limiting is an infrastructure concern — not in this PBI
- `users` table migration is not required (table already exists)
- No changes to existing auth middleware

## Approach Overview

Implement in dependency order: validation functions → service layer → route handler → mount to app → tests.
bcrypt is used exclusively via async/await to prevent accidental plaintext storage.

## Work Breakdown

| Step | Content | Output | Owner | Risk | Checkpoint |
|------|---------|--------|-------|------|-----------|
| Step 1 | Explore existing auth middleware and confirm users table schema | Schema confirmed, no middleware conflict | agent | Low | 🚩 |
| Step 2 | Implement `src/validators/user.js` | `isValidEmail`, `isValidPassword` functions | agent | Low | 🚩 |
| Step 3 | Implement `src/services/userService.js` | `createUser` with bcrypt + DB INSERT + 409 detection | agent | Medium (async misuse) | 🚩 |
| Step 4 | Implement `src/routes/users.js` + mount in `src/app.js` | POST /api/users handler live | agent | Low | 🚩 |
| Step 5 | Implement unit + integration tests | All AC-7 test suites passing | agent | Low | 🚩 |

## Files / Components to Touch

| Type | File Path | Change |
|------|-----------|--------|
| New | `src/validators/user.js` | Email format check, password length check |
| New | `src/services/userService.js` | bcrypt hash, DB INSERT, duplicate detection |
| New | `src/routes/users.js` | POST /api/users handler |
| Modify | `src/app.js` | Mount users router |
| New | `tests/unit/validators/user.test.js` | Unit tests for validators |
| New | `tests/integration/routes/users.test.js` | Integration tests for endpoint |

## Testing Strategy

- **Unit**: `isValidEmail` and `isValidPassword` — normal, invalid, boundary inputs
- **Integration**: All 7 ACs + edge cases TC-E1 through TC-E5 against running test DB
- **Edge cases**: empty body, missing fields, max-length email, empty string password, SQL injection patterns

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| bcrypt async misuse (missing await) | Enforce async/await + try/catch; never use bcrypt.hashSync in production path |
| Duplicate email race condition | DB UNIQUE constraint is the final guard; catch constraint violation error for 409 |
| Auth middleware intercepting registration | Confirm in Step 1 exploration before writing any handler code |

## Questions / Unknowns

- None remaining after Step 1 exploration (schema and middleware confirmed)

## Mode判定

**モード**: `standard`

**判定根拠**:

- 変更ファイル数: 6 → standard
- 受入基準数: 7 → standard
- 変更種別: 新機能追加（単一エンドポイント） → standard
- リスク: 中（bcrypt非同期、重複制御） → standard
- **最終判定**: standard
