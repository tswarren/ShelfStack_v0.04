# Phase 1 Test Coverage Matrix

## Purpose

This document maps Phase 1 test plan areas to implemented automated tests. It supports the [Phase 1 completion record](phase-1-completion.md) and identifies regression gaps.

Normative test requirements: [../specifications/phase-1-test-plan.md](../specifications/phase-1-test-plan.md).

**Current suite:** 37 tests, 103 assertions (Minitest).

---

## Coverage Summary

| Area | Coverage |
| ---- | -------- |
| Authentication (login/logout) | Partial |
| Authorization (global/store scope) | Partial |
| Super administrator protection | Partial |
| Session lifecycle | Partial |
| Workstation assignment | Partial |
| Setup authorization | Partial |
| User role assignments | Partial |
| Workstation form validation | Partial |
| Audit events (model) | Partial |
| Seed idempotency | Partial |
| System / browser flows | Not covered |
| Force-end session UI | Not covered |
| Time zone multi-store display | Not covered |
| Full setup CRUD per test plan | Not covered |

---

## Test Files

| File | Focus |
| ---- | ----- |
| `test/models/user_test.rb` | System user rules |
| `test/models/audit_event_test.rb` | Audit event model |
| `test/models/seed_test.rb` | Seed idempotency |
| `test/services/authentication_service_test.rb` | Login validation, lockout |
| `test/services/authorization_test.rb` | Global/store scope, inactive user, system user |
| `test/services/session_lifecycle_test.rb` | Login, lock, unlock, logout |
| `test/services/workstation_assignment_service_test.rb` | Assign, cookie, resolution |
| `test/services/user_role_assignment_service_test.rb` | Assign, remove, super admin protection |
| `test/services/super_administrator_protection_test.rb` | Restore, protection rules, setup integration |
| `test/controllers/sessions_controller_test.rb` | Login flow, logout, header user menu, PIN/password onboarding |
| `test/controllers/passwords_controller_test.rb` | Password change confirmation and forced reset |
| `test/controllers/pins_controller_test.rb` | PIN change confirmation |
| `test/controllers/session_inactivity_test.rb` | Inactivity locks session |
| `test/integration/setup_authorization_test.rb` | Setup access control |
| `test/integration/setup_user_role_assignments_test.rb` | Role assignment UI and audit |
| `test/integration/setup_workstations_controller_test.rb` | Validation error display |

---

## Phase 1 Test Plan Mapping

### Section 1–2: Authentication

| Test plan topic | Status | Notes |
| --------------- | ------ | ----- |
| Valid login | Covered | `sessions_controller_test`, `session_lifecycle_test` |
| Failed login | Covered | `authentication_service_test` |
| Logout | Covered | `sessions_controller_test`, `session_lifecycle_test` |
| Password change | Covered | `passwords_controller_test` |
| Admin password reset | Not covered | No UI tests |
| PIN change | Covered | `pins_controller_test` |
| Forced password change redirect | Covered | `sessions_controller_test`, `passwords_controller_test` |

### Section 3–4: Authorization

| Test plan topic | Status | Notes |
| --------------- | ------ | ----- |
| Global permission | Covered | `authorization_test` |
| Store-scoped permission | Covered | `authorization_test` |
| Inactive user denied | Covered | `authorization_test` |
| Setup access | Covered | `setup_authorization_test` |

### Section 5: Super administrator protection

| Test plan topic | Status | Notes |
| --------------- | ------ | ----- |
| Cannot remove last super admin assignment | Covered | `user_role_assignment_service_test`, `super_administrator_protection_test` |
| Super admin role permission protection | Covered | `super_administrator_protection_test` |
| System user read-only | Covered | `super_administrator_protection_test` |
| Cannot inactivate last admin user | Not covered | Service-level only |

### Section 6: Store and workstation

| Test plan topic | Status | Notes |
| --------------- | ------ | ----- |
| Workstation assignment | Covered | `workstation_assignment_service_test` |
| Store/workstation CRUD | Partial | Validation errors only for workstations |
| Duplicate workstation number | Not covered | Model validation untested |

### Section 7–8: Sessions

| Test plan topic | Status | Notes |
| --------------- | ------ | ----- |
| Lock / unlock | Covered | `session_lifecycle_test`, `session_inactivity_test` |
| Force-end | Not covered | Service exists, no test |
| Expiration | Partial | Inactivity now locks per spec; `session_lifecycle_test`, `session_inactivity_test` |
| Password unlock when no PIN | Covered | `session_lifecycle_test` |
| Cross-tab polling | Not covered | |

### Section 9–11: Setup UI

| Test plan topic | Status | Notes |
| --------------- | ------ | ----- |
| User role assignments | Covered | `setup_user_role_assignments_test` |
| Role/permission management | Not covered | |
| Store/user CRUD | Not covered | |

### Section 12–14: Audit, seeds, time zone

| Test plan topic | Status | Notes |
| --------------- | ------ | ----- |
| Audit event creation | Partial | Model test only |
| Seed idempotency | Covered | `seed_test` |
| Multi-store time zone display | Not covered | |

---

## Recommended Future Tests

Priority items if hardening Phase 1 before Phase 2:

1. ~~Password and PIN controller/request tests.~~ Done.
2. `SessionLifecycle.force_end!` tests.
3. Store model normalization validations.
4. Setup roles permission checkbox protection.
5. Capybara system test: login → dashboard → setup user → assign role.
