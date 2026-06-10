
# Phase 1 Test Plan

## Purpose

This document defines the test coverage required for ShelfStack Phase 1.

Phase 1 is security- and foundation-heavy. The tests should verify not only happy paths, but also lockout prevention, scoped permissions, session lifecycle behavior, workstation context, audit event creation, and seed idempotency.

---

# 1. Test Categories

Phase 1 should include tests in the following categories:

| Category | Purpose |
|---|---|
| Model tests | Validate fields, relationships, normalization, constraints, and controlled values. |
| Service tests | Validate authorization, session lifecycle, audit logging, token handling, and context resolution. |
| Request/controller tests | Validate access control and response behavior. |
| System tests | Validate browser-level flows such as login, setup screens, lock/unlock, and workstation assignment. |
| Seed tests | Validate idempotent seed behavior. |
| Security regression tests | Prevent accidental admin lockout or privilege bypass. |

---

# 2. Authentication Tests

## 2.1 Successful Login

### Scenario

Active interactive user enters valid username/password.

### Expected

- Login succeeds.
- `user_sessions` record is created.
- Session status is `active`.
- `last_login_at` is updated.
- Previous `last_login_at` is copied to `previous_login_at`.
- `invalid_login_attempts` resets to `0`.
- `user.login` audit event is created.
- User is redirected to dashboard.

---

## 2.2 Failed Login

### Scenario

User enters invalid password.

### Expected

- Login fails.
- Generic error is displayed.
- `invalid_login_attempts` increments.
- No active session is created.
- `user.login_failed` audit event is created where appropriate.

---

## 2.3 Failed Login Does Not Reveal User Existence

### Scenario

Unknown username attempts login.

### Expected

- Generic error is displayed.
- Response does not reveal whether username exists.
- No session is created.

---

## 2.4 Login Lockout

### Scenario

User exceeds allowed failed login attempts.

### Expected

- `locked_at` is set.
- User cannot log in until unlocked/reset.
- Audit event is created.

---

## 2.5 Inactive User Cannot Log In

### Scenario

User has `active = false`.

### Expected

- Login fails.
- No session is created.
- Generic or appropriate inactive-account message is shown, depending on desired UX.
- Audit event is created where appropriate.

---

## 2.6 System User Cannot Log In

### Scenario

User `system` attempts interactive login.

### Expected

- Login fails.
- No session is created.
- System user remains non-interactive.

---

## 2.7 Non-Interactive User Cannot Log In

### Scenario

User has `interactive_login_enabled = false`.

### Expected

- Login fails.
- No session is created.

---

## 2.8 Forced Password Change

### Scenario

User has `force_password_change = true`.

### Expected

- Login succeeds.
- User is redirected to password change screen.
- User cannot access normal app areas until password is changed.
- Successful password change clears `force_password_change`.

---

# 3. Password and PIN Tests

## 3.1 User Can Change Own Password

### Expected

- Current password is required.
- New password confirmation must match.
- Password policy is enforced.
- `password_digest` changes.
- `password_changed_at` updates.
- `user.password_changed` audit event is created.

---

## 3.2 User Cannot Change Password With Wrong Current Password

### Expected

- Change is rejected.
- Password digest does not change.
- Error is shown.
- Optional audit/security event is created.

---

## 3.3 Admin Can Reset User Password

### Expected

- Authorized admin can reset password.
- Target user has `force_password_change = true`.
- `password_changed_at` updates.
- `user.password_reset` audit event is created.

---

## 3.4 Unauthorized User Cannot Reset Password

### Expected

- Request is denied.
- No password fields change.
- No reset audit event is created, or denied-action audit is created if supported.

---

## 3.5 User Can Set or Change PIN

### Expected

- `pin_digest` changes.
- `pin_changed_at` updates.
- `user.pin_changed` audit event is created.

---

## 3.6 Admin Can Clear PIN

### Expected

- `pin_digest` becomes null.
- `pin_changed_at` updates.
- `user.pin_cleared` audit event is created.

---

## 3.7 PIN Cannot Be Used for Login

### Expected

- PIN authentication is rejected on login.
- PIN only unlocks existing locked session.

---

# 4. Authorization Tests

## 4.1 Global Role Grants Permission Across Stores

### Setup

User has global role assignment with permission `setup.users.view`.

### Expected

- User can access user setup from Store 1.
- User can access user setup from Store 2.

---

## 4.2 Store-Scoped Role Grants Permission Only In Matching Store

### Setup

User has store-scoped role assignment for Store 1.

### Expected

- User can access permitted action in Store 1.
- User cannot access same action in Store 2.

---

## 4.3 Inactive Role Assignment Does Not Grant Permission

### Expected

- Authorization service returns false.
- User cannot access protected action.

---

## 4.4 Inactive Role Does Not Grant Permission

### Expected

- Authorization service returns false.

---

## 4.5 Inactive Permission Does Not Grant Access

### Expected

- Authorization service returns false.

---

## 4.6 User Without Permission Cannot Access Setup

### Expected

- Setup route is denied.
- User sees safe redirect or 403.

---

## 4.7 System User Does Not Satisfy Interactive Authorization

### Expected

- System user cannot be used for interactive access checks.
- System user can be used as actor for background audit events only.

---

# 5. Super Administrator Protection Tests

## 5.1 Cannot Delete Super Administrator Role

### Expected

- Delete is blocked.
- Error message explains protected role.
- Audit event may record denied action if supported.

---

## 5.2 Cannot Inactivate Last Admin Path

### Expected

- Attempt is blocked.
- At least one active interactive global super administrator remains.

---

## 5.3 Cannot Remove Last Global Super Administrator Assignment

### Expected

- Attempt is blocked.
- Admin recovery path remains.

---

## 5.4 Cannot Inactivate Last Global Super Administrator User

### Expected

- Attempt is blocked.

---

## 5.5 System User Does Not Count As Last Admin

### Expected

- Protections require an active interactive user.
- System user cannot satisfy rule.

---

# 6. Store and Workstation Tests

## 6.1 Store Creation

### Expected

- Store can be created with valid fields.
- `store_number` is unique.
- `country_code` normalizes uppercase.
- `region_code` normalizes uppercase.
- `email` normalizes lowercase.
- `time_zone` must be valid.
- `store.created` audit event is created.

---

## 6.2 Duplicate Store Number Rejected

### Expected

- Validation fails.
- Duplicate record is not created.

---

## 6.3 Workstation Creation

### Expected

- Workstation can be created for active store.
- `workstation_number` is normalized/zero-padded.
- `workstation_code` is generated consistently.
- `workstation.created` audit event is created.

---

## 6.4 Duplicate Workstation Number Within Store Rejected

### Expected

- Store cannot have duplicate `workstation_number`.

---

## 6.5 Same Workstation Number Allowed Across Stores

### Expected

- Store 1 can have workstation `001`.
- Store 2 can also have workstation `001`.

---

## 6.6 Invalid Workstation Type Rejected

### Expected

- Only allowed values are accepted:
  - `register`
  - `service_desk`
  - `back_office`
  - `receiving`

---

## 6.7 Inactive Workstation Cannot Be Assigned

### Expected

- Workstation assignment creation fails.
- Error is shown.

---

# 7. Workstation Assignment Tests

## 7.1 Browser Can Be Assigned to Workstation

### Expected

- Assignment record is created.
- Cookie receives raw assignment token.
- Database stores only digest.
- `assigned_at` is set.
- `workstation_assignment.created` audit event is created.

---

## 7.2 Raw Token Is Not Stored

### Expected

- Raw cookie token does not appear in database.
- Digest lookup resolves assignment.

---

## 7.3 Valid Assignment Resolves Context

### Expected

Token resolves:

```text
assignment → workstation → store → time_zone
```

## 7.4 Invalid Token Is Rejected
### Expected

- Cookie is cleared.
- User is returned to unassigned workstation flow.


## 7.5 Revoked Assignment Is Rejected

### Expected

- Revoked assignment cannot create new session.
- Cookie is cleared or ignored.


## 7.6 Reassignment Revokes Prior Assignment
### Expected
- Prior assignment revoked_at is set.
- New assignment is created.
- New cookie token is issued.
- workstation_assignment.reassigned audit event is created.


## 7.7 Optional One Active Assignment Per Workstation
If enforced:
### Expected
- Second active assignment for same workstation is rejected unless prior is revoked.


# 8. Session Lifecycle Tests
## 8.1 Login Creates Active Session
### Expected
- user_sessions.status = active.
- last_activity_at is set.
- user_id, store_id, and workstation_id are set.


## 8.2 Manual Lock
### Expected
- Status becomes locked.
- `locked_at` is set.
- `session.locked` audit event is created.
- Requests redirect/render unlock screen.


## 8.3 Unlock With PIN
### Expected
- Correct PIN unlocks session.
- Status becomes active.
- `unlocked_at` updates.
- `last_activity_at` updates.
- `session.unlocked` audit event is created.


## 8.4 Unlock With Wrong PIN
### Expected
- Session remains locked.
- Error is displayed.
- Optional failed unlock audit event is created.


## 8.5 Unlock Requires Same User
### Expected
- Another user cannot unlock the locked session with their own PIN.


## 8.6 Password Unlock When No PIN Exists
### Expected
- If user has no PIN, password unlock is accepted if valid.
- Session returns to active.

## 8.7 Logout Ends Session
### Expected
- Status becomes ended.
- `ended_at` is set.
- Session cannot be resumed.
- `user.logout` audit event is created.


## 8.8 Inactivity Expiration
### Expected
- Session becomes expired.
- `ended_at` is set.
- User is returned to login.
- `session.expired` audit event is created.


## 8.9 Force-End Locked Session
### Expected
- Authorized user authenticates with username/password.
- Locked session becomes `force_ended`.
- `ended_at` is set.
- `ended_by_user_id` is set.
- `session.force_ended` audit event is created.
- Locked browser returns to login.


## 8.10 Unauthorized Force-End Attempt
### Expected
- Attempt fails.
- Session remains locked.
- User returns to unlock screen.


## 8.11 Terminal Sessions Cannot Return Active
### Expected
- The following statuses cannot transition to active:

  - `ended`
  - `expired`
  - `force_ended`


# 9. Current Context Tests
## 9.1 Current Context Is Set Per Request
### Expected
For authenticated request:

- `Current.user`
- `Current.store`
- `Current.workstation`
- `Current.user_session`
- `Current.time_zone`

are populated correctly.


## 9.2 Current Context Clears Between Requests/Tests
### Expected
- No context leakage occurs between users/sessions/tests.


## 9.3 Audit Events Use Current Context
### Expected
Audit events automatically include:

- `actor user`
- `store`
- `workstation`
- `user session`

when available.


# 10. Audit Event Tests
## 10.1 Required Events Are Created
Test creation for:

- `user.login`
- `user.login_failed`
- `user.logout`
- `user.password_changed`
- `user.password_reset`
- `user.pin_changed`
- `user.pin_reset`
- `user.pin_cleared`
- `session.locked`
- `session.unlocked`
- `session.expired`
- `session.force_ended`
- `workstation_assignment.created`
- `workstation_assignment.revoked`
- `workstation_assignment.reassigned`
- `role.created`
- `role.updated`
- `role.inactivated`
- `role.reactivated`
- `role.deleted`
- `role.permission_added`
- `role.permission_removed`
- `user.created`
- `user.updated`
- `user.inactivated`
- `user.reactivated`
- `user.deleted`
- `user.role_added`
- `user.role_removed`
- `store.created`
- `store.updated`
- `store.inactivated`
- `store.reactivated`
- `store.deleted`
- `workstation.created`
- `workstation.updated`
- `workstation.inactivated`
- `workstation.reactivated`
- `workstation.deleted`


## 10.2 Audit Event Includes Required Context
### Expected
Audit event includes:

- `actor_user_id`
- `event_name`
- `occurred_at`
- `event_details`
- `auditable reference when applicable`
- `store/workstation/session context when available`


## 10.3 Audit Events Are Append-Only
### Expected
- Normal UI cannot edit audit events.
- Normal UI cannot delete audit events.


## 10.4 Record-Level Audit Timeline
### Expected

- User detail page shows user-related audit events.
- Role detail page shows role-related audit events.
- Store detail page shows store-related audit events.
- Workstation detail page shows workstation-related audit events.


# 11. Setup UI Tests

## 11.1 Setup Landing Page
### Expected
Authorized user sees setup links/cards for:

- Users
- Roles
- Permissions
- Stores
- Workstations
- Audit Events


## 11.2 Unauthorized User Cannot Access Setup
### Expected
- Access denied.
- No setup data is exposed.


## 11.3 Permissions Are Read-Only
### Expected
Authorized user can:

- View permissions
- Filter by group
- See related roles

User cannot normally:

- Create permission
- Rename permission key
- Delete permission


## 11.4 Role Management
### Expected
- Authorized user can:

  - Create role
  - Edit role
  - Inactivate role
  - Reactivate role
  - Delete unused non-system role
  - Add/remove permissions
- Audit events are created.


## 11.5 User Management
### Expected

- Authorized user can:

  - Create user
  - Edit user
  - Inactivate user
  - Reactivate user
  - Delete unused non-protected user
  - Reset password
  - Reset/clear PIN
  - Add/remove role assignments

- Audit events are created.


## 11.6 Store Management
### Expected
- Authorized user can:

  - Create store
  - Edit store
  - Inactivate store
  - Reactivate store
  - Delete unused store

- Audit events are created.


## 11.7 Workstation Management
## Expected
- Authorized user can:

  - Create workstation
  - Edit workstation
  - Inactivate workstation
  - Reactivate workstation
  - Delete unused workstation

- Audit events are created.


# 12. Deletion/Inactivation Tests

## 12.1 Referenced User Cannot Be Hard Deleted
## Expected
- User with sessions/audit events cannot be deleted.
- User can be inactivated.


## 12.2 Referenced Store Cannot Be Hard Deleted
### Expected

- Store with workstations/sessions/users/audit events cannot be deleted.
- Store can be inactivated.


## 12.3 Referenced Workstation Cannot Be Hard Deleted
### Expected

- Workstation with sessions/assignments/audit events cannot be deleted.
- Workstation can be inactivated.


## 12.4 Audit Events Cannot Be Deleted Through UI
### Expected
- Delete action unavailable or denied.


# 13. Seed Tests

## 13.1 Seeds Create Required Records
## Expected
- Seeds create:

  - System user
  - Admin user
  - Super administrator role
  - Phase 1 permissions
  - Role permissions
  - Global admin role assignment
  - Two stores
  - Two workstations per store


## 13.2 Seeds Are Idempotent
### Expected

Running seeds multiple times does not duplicate:

- Users
- Roles
- Permissions
- Stores
- Workstations
- Role assignments
- Role permissions


## 13.3 Seeded Admin Has Full Access
### Expected

Admin user has global super administrator role assignment.


## 13.4 Seeded System User Is Non-Interactive
## Expected
System user:

- Exists
- Is active
- Cannot log in
- Has interactive_login_enabled = false


# 14. Time Zone Tests

## 14.1 Store Time Zone Displays Correctly
### Expected
- Store 1 displays times in `America/New_York`.
- Store 2 displays times in `America/Los_Angeles`.


## 14.2 Timestamps Persist In UTC
### Expected
- Database timestamps are UTC.
- Display converts to active store time zone.


# 15. Regression Risks
These areas require regression coverage throughout future phases:

- Permission resolution.
- Store-scoped role assignments.
- Super administrator protections.
- Session terminal statuses.
- Workstation assignment token handling.
- Audit event context.
- Inactive record behavior.
- Time zone display.
- Seed idempotency.
- Deletion/inactivation rules.


# 16. Minimum Definition of Done

Phase 1 is done only when:

1. All migrations run cleanly.
2. Seeds run idempotently.
3. Admin can log in from seeded data.
4. Workstation context resolves correctly.
5. User/session/store/workstation context appears on dashboard.
6. Setup screens enforce permissions.
7. Authentication/security flows are tested.
8. Authorization service tests pass.
9. Session lifecycle tests pass.
10. Audit event tests pass.
11. Super administrator lockout protections pass.
12. No known path allows unauthorized setup access.
