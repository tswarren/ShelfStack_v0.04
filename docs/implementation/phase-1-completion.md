# Phase 1 Completion Record

## Status

**Phase 1 (Foundation) is complete** as of 2025-06-10.

Phase 1 delivered a working identity, authorization, session, workstation, audit, and setup foundation. Later phases built on this foundation; see completion records for Phases 2 and 3.

This document records what was implemented, how to verify it, known gaps relative to the Phase 1 specifications, and recovery procedures discovered during development.

Normative requirements remain in:

```text
docs/roadmap/phase-1-foundation.md
docs/specifications/phase-1-foundation-spec.md
docs/specifications/phase-1-data-model.md
docs/specifications/phase-1-test-plan.md
```

---

## Delivered Capabilities

### Database

Single migration: `db/migrate/20250610120000_create_phase1_foundation.rb`

| Table | Purpose |
| ----- | ------- |
| `audit_events` | Append-only security and setup activity log |
| `permissions` | Seed-managed application capabilities |
| `roles` | Named permission bundles |
| `role_permissions` | Role-to-permission join |
| `stores` | Store/location records |
| `users` | Interactive users and system actor |
| `user_role_assignments` | Global or store-scoped role grants |
| `workstations` | Store registers, service desks, and stations |
| `user_sessions` | Persisted session lifecycle |
| `workstation_assignments` | Browser-to-workstation token assignments |

Schema is reflected in `db/schema.rb`.

### Services

| Service | Responsibility |
| ------- | -------------- |
| `Authorization` | Permission resolution with global/store scope |
| `AuditEvents` | Centralized audit event creation |
| `AuthenticationService` | Login validation and lockout tracking |
| `SessionLifecycle` | Login, logout, lock, unlock, inactivity lock |
| `WorkstationAssignmentService` | Browser assignment, resolution, revoke, reassign |
| `UserRoleAssignmentService` | Assign and remove user role assignments |
| `SuperAdministratorProtection` | Prevent admin lockout; seed recovery helper |
| `TokenDigest` | Secure token generation and digesting |

Request context: `Current` (`CurrentAttributes`).

### Application routes

| Area | Routes |
| ---- | ------ |
| Auth | `/login`, `/logout`, `/password/edit`, `/pin/edit` |
| Workstation | `/workstation_assignment/new` (assign browser) |
| Session | `/session/lock`, `/session/unlock`, `/session/status` |
| Shell | `/` (dashboard) |
| Setup | `/setup/*` (users, roles, permissions, stores, workstations, audit events) |

### Setup UI

- Setup landing page with cards for users, roles, permissions, stores, workstations, and audit events
- CRUD-style management for users, roles, stores, and workstations (with inactivation)
- Permissions index (view-only)
- Role permission management (Super Administrator role is protected)
- User role assignments on user detail
- Record-level audit timelines on setup detail pages
- Setup access denied page with recovery instructions (`/setup/locked_out`)

### Application shell

- Header: logo, store/workstation context, search placeholder, user menu (password/PIN links), logout
- Nav: dashboard, disabled future modules, Setup
- Footer: version, copyright, lock session
- Dashboard: environment and session summary
- Light-theme styling in `app/assets/stylesheets/shelfstack.css`

### Seeds

Idempotent seeds in `db/seeds.rb` and `db/seeds/phase1_permissions.rb`:

- System user (`system`, non-interactive)
- Admin user (`admin`, global Super Administrator)
- Two demo stores with register and service desk workstations
- All Phase 1 permissions on Super Administrator role

Development seed output prints the admin password only when the admin user is newly created.

---

## Verification

### First-time or fresh database

```bash
docker compose up --build
./dev/rails-docker bin/rails db:create db:migrate db:seed
```

Open `http://localhost:3000`.

### Login flow

1. Assign the browser to a workstation (login redirect or `/workstation_assignment/new` with `workstations.assign_browser`).
2. Log in as `admin` (password from seed output on first seed).
3. Change password when prompted (`force_password_change`); new password and confirmation must match.
4. Set a PIN when prompted (required); PIN and confirmation must match.
5. Confirm dashboard shows store, workstation, user, and session details.
6. Open **Setup** and verify setup screens load.

### Automated tests

```bash
./dev/rails-docker bin/rails test
```

The suite includes Phase 1–3 coverage (280+ tests). See [phase-1-test-coverage.md](phase-1-test-coverage.md) for Phase 1 mapping.

---

## Exit Criteria Summary

Legend: **Met** | **Partial** | **Deferred**

### Authentication

| Criterion | Status | Notes |
| --------- | ------ | ----- |
| Login / logout | Met | |
| Failed login tracking | Met | Lockout after threshold |
| Login timestamps | Met | `previous_login_at`, `last_login_at` |
| User password change | Met | `/password/edit`; confirmation required |
| Admin password reset | Partial | Controller action exists; **no setup UI** |
| Forced password change | Met | Login redirect + navigation gate until changed |
| PIN set/change | Met | `/pin/edit`; required after login; confirmation required |
| Admin PIN clear | Partial | Controller action exists; **no setup UI** |
| System user cannot log in | Met | |
| Inactive / non-interactive blocked | Met | |

### Authorization

| Criterion | Status | Notes |
| --------- | ------ | ----- |
| Seeded permissions | Met | |
| Permission groups | Met | |
| Role permissions | Met | Super Admin protected |
| Global / store role assignments | Met | User show UI |
| Authorization service | Met | |
| Store-scoped enforcement | Met | Tested |
| Inactive records denied | Met | |
| Super administrator protection | Met | Role, assignments, system user |

### Store and workstation context

| Criterion | Status | Notes |
| --------- | ------ | ----- |
| Store / workstation setup CRUD | Met | Full forms with validation errors |
| Browser workstation assignment | Met | Token cookie + digest in DB |
| Invalid/revoked assignments rejected | Met | |
| Store/time zone from workstation | Met | Dashboard display |
| Browser reassign UI | Partial | Assign at `/workstation_assignment/new`; **no dedicated reassign/reset in shell** |

### Sessions

| Criterion | Status | Notes |
| --------- | ------ | ----- |
| Session record on login | Met | |
| Status lifecycle | Met | active, locked, ended, expired, force_ended |
| Lock / unlock own session | Met | Footer lock; unlock with PIN or password if no PIN |
| Inactivity timeout | Met | Locks session (does not expire to login or reset password) |
| Force-end another session | Partial | `SessionLifecycle.force_end!` exists; **no setup UI** |
| Terminal sessions stay terminal | Met | |
| Cross-tab lock behavior | Met | Request enforcement + `/session/status` polling |

### Auditability

| Criterion | Status | Notes |
| --------- | ------ | ----- |
| Security/setup audit events | Met | Core events implemented |
| Context on audit events | Met | Actor, store, workstation, session where available |
| Audit viewer | Met | Setup index and show |
| Record timelines | Met | Setup detail pages |
| Audit not editable | Met | No edit/delete UI |

### Setup UI

| Criterion | Status | Notes |
| --------- | ------ | ----- |
| Setup landing | Partial | No **active sessions** card (spec mentioned sessions) |
| Foundational record management | Met | |
| Permission-controlled setup | Met | |
| Permissions view-only | Met | |

### Testing

| Criterion | Status | Notes |
| --------- | ------ | ----- |
| Core auth/authz/session tests | Met | Includes password/PIN controller and inactivity tests |
| Setup integration tests | Partial | Not full test-plan breadth |
| Seed idempotency | Met | |
| System tests | Deferred | No Capybara system tests yet |

---

## Known Gaps and Deferred Work

These are acceptable for Phase 1 sign-off but should be tracked for hardening or early Phase 2:

1. **Admin password reset / PIN clear UI** on user detail (actions exist, no forms).
2. **Workstation reassign/reset** in application shell (see [foundation-runbook.md](../operations/foundation-runbook.md)).
3. **Force-end session UI** for authorized users.
4. **Setup active sessions** list/management screen.
5. **`WorkstationAssignmentService.reassign!`** not wired to a dedicated UI flow.
6. **Test coverage** — Phase 1 password/PIN/onboarding flows are covered; not every scenario in `phase-1-test-plan.md`.
7. **Email password reset** — intentionally deferred per roadmap.
8. **`password_reset_tokens` / `system_settings` tables** — deferred per Phase 1 roadmap.

Spec/implementation deltas are documented here rather than silently editing the normative specifications.

---

## Recovery Procedures

### Lost setup access (`setup.access`)

```bash
docker compose exec web bin/rails db:seed
```

Or in Rails console:

```ruby
SuperAdministratorProtection.restore!
```

Then log out and back in. See `/setup/locked_out` for in-app instructions.

### Admin password unknown

Re-seed does **not** rotate an existing admin password. Options:

- Reset password in Rails console, or
- Delete the admin user and re-run `db:seed` (development only).

### Browser stuck on wrong workstation

See [foundation-runbook.md](../operations/foundation-runbook.md).

---

## Related Documentation

| Document | Purpose |
| -------- | ------- |
| [phase-1-test-coverage.md](phase-1-test-coverage.md) | Test plan mapping |
| [../operations/foundation-runbook.md](../operations/foundation-runbook.md) | Workstation assignment, lock/unlock, admin recovery |
| [../roadmap/phase-1-foundation.md](../roadmap/phase-1-foundation.md) | Phase 1 roadmap and exit criteria |
| [../../DOCKER.md](../../DOCKER.md) | Development environment |
| [../../README.md](../../README.md) | Project entry point |
