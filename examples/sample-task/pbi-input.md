---
task_id: sample-task
artifact_type: pbi-input
schema_version: 1
---

# PBI INPUT PACKAGE — Add User Registration Endpoint

## Context / Why

The application currently has no user registration endpoint.
New users must be inserted into the database directly by administrators,
which is not scalable and introduces operational risk.
This PBI adds a `POST /api/users` endpoint to automate registration
with proper input validation and secure password storage.

## What — Scope

### In scope

- `POST /api/users` endpoint accepting `{ email, password }` in request body
- Email format validation (RFC 5322 basic check, lowercase normalization)
- Password minimum length validation (8 characters)
- bcrypt password hashing (cost factor: 12)
- PostgreSQL INSERT into existing `users` table
- 201 Created response with `{ id, email, created_at }` on success
- 409 Conflict response when email already exists
- 400 Bad Request for invalid email format or insufficient password length

### Out of scope

- Email verification flow (separate PBI)
- Password reset / forgot password
- OAuth / social login
- Rate limiting (infrastructure concern)
- `users` table migration (table already exists)

## Acceptance Criteria

- [ ] AC-1: `POST /api/users` with valid body → 201 Created + `{ id, email, created_at }`
- [ ] AC-2: Duplicate email → 409 Conflict + `{ error: "Email already registered" }`
- [ ] AC-3: Invalid email format → 400 Bad Request + `{ error: "Invalid email format" }`
- [ ] AC-4: Password shorter than 8 characters → 400 Bad Request + `{ error: "Password must be at least 8 characters" }`
- [ ] AC-5: Password is stored as bcrypt hash (not plaintext) in the database
- [ ] AC-6: Email is normalized to lowercase before storage
- [ ] AC-7: Unit tests for validation functions pass; integration tests for the endpoint pass

## Notes from Refinement

- bcrypt cost factor agreed as 12 (security/performance balance)
- Email normalization: lowercase only; leading/trailing spaces trigger validation rejection
- Existing `users` table has a UNIQUE constraint on `email` column — use this for 409 detection

## Estimation Evidence

**Risks**

- bcrypt is async; missing `await` could silently store unhashed passwords
- Race condition on duplicate email: DB UNIQUE constraint is the authoritative guard

**Unknowns**

- Need to verify that existing auth middleware does not intercept `POST /api/users` before registration

**Assumptions**

- PostgreSQL `users` table exists with columns:
  `id SERIAL PRIMARY KEY, email TEXT UNIQUE NOT NULL, password_hash TEXT NOT NULL, created_at TIMESTAMPTZ DEFAULT NOW()`
- Project uses async/await throughout (no callback-style)
- Jest is the test runner
