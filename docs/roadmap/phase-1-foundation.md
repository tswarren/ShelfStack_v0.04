# Phase 1: Foundation

## Purpose

Phase 1 establishes ShelfStack’s operational foundation: who the user is, where they are working, what store and workstation context applies, what they are allowed to do, how their session is secured, and how critical actions are audited.

This phase does not implement catalog, inventory, purchasing, receiving, POS sales, or customer/vendor workflows. Instead, it creates the identity, authorization, session, workstation, audit, and setup foundation that later ShelfStack workflows depend on.

---

## Goals

Phase 1 should provide a secure, reliable base for future application modules.

The primary goals are:

1. Establish user authentication.
2. Establish role-based authorization.
3. Support global and store-scoped role assignments.
4. Establish store and workstation context.
5. Persist user session state.
6. Support session locking, unlocking, expiration, logout, and forced termination.
7. Record audit events for security and setup changes.
8. Provide a basic application shell.
9. Provide setup screens for foundational records.
10. Provide seed data for a working development/demo instance.
11. Establish test coverage for foundational security flows.

---

## Non-Goals

Phase 1 does not include:

- Catalog records
- Works, editions, products, or product variants
- Inventory ledger
- Purchase orders
- Receiving
- POS sales
- Cash drawer management
- Customers
- Vendors
- Special orders
- Returns
- Reporting beyond basic audit/event visibility
- Full business-date/register-closeout logic
- Offline POS behavior
- Email-based password reset

---

## Major Capabilities

Phase 1 includes the following capabilities:

| Capability | Description |
|---|---|
| Authentication | Users can log in, log out, change password, and be blocked if inactive or non-interactive. |
| Authorization | Users receive role assignments that grant permissions globally or within a store. |
| Store context | Active store is resolved from the workstation/session context. |
| Workstation context | Browser is assigned to a workstation using a secure token. |
| Session management | User sessions are persisted and can be active, locked, ended, expired, or force-ended. |
| Session locking | Users can lock and unlock their sessions. |
| Forced session termination | Authorized users can force-end another user’s locked session. |
| Audit logging | Security and setup changes create audit events. |
| Setup administration | Authorized users can manage users, roles, stores, workstations, and role assignments. |
| Application shell | Header, footer, dashboard, setup area, and environment display are implemented. |
| Seed data | System user, admin user, stores, workstations, permissions, and super administrator role are seeded. |
| Test coverage | Authentication, authorization, session, workstation, audit, and setup behavior are tested. |

---

## Internal Phase Breakdown

Phase 1 may be implemented as three internal workstreams.

---

## Phase 1A: Identity and Access Foundation

### Purpose

Build the identity and authorization foundation.

### Includes

- Users
- Roles
- Permissions
- Role permissions
- User role assignments
- Login
- Logout
- Password change
- Admin password reset
- PIN setup/change
- Super administrator protection
- Authorization service
- Basic audit events for identity/security actions

### Primary question answered

> Who is the user, and what are they allowed to do?

### Exit Criteria

Phase 1A is complete when:

1. Seeded admin user can log in.
2. System user cannot log in interactively.
3. Inactive users cannot log in.
4. Users with `interactive_login_enabled = false` cannot log in.
5. Failed login attempts are tracked.
6. User can change their own password.
7. Admin can reset another user’s password.
8. User can set/change PIN.
9. Admin can clear/reset another user’s PIN.
10. Permissions are seeded and readable.
11. Roles can be created, updated, inactivated, reactivated, and deleted where allowed.
12. Permissions can be assigned and unassigned from roles.
13. Users can be assigned roles globally or within stores.
14. Authorization service correctly resolves permissions.
15. Super administrator lockout protections are enforced.
16. Audit events are created for login, failed login, password changes, PIN changes, and role/permission changes.

---

## Phase 1B: Store, Workstation, and Session Context

### Purpose

Build the context layer that identifies where and how the user is working.

### Includes

- Stores
- Workstations
- Workstation assignments
- User sessions
- Current request context
- Store time zone handling
- Session lock/unlock
- Session expiration
- Forced session termination

### Primary question answered

> Where is the user working, from what workstation, under what session, and in what store context?

### Exit Criteria

Phase 1B is complete when:

1. Stores can be created, updated, inactivated, reactivated, and deleted where allowed.
2. Workstations can be created, updated, inactivated, reactivated, and deleted where allowed.
3. Browser can be assigned to a workstation using a secure assignment token.
4. Browser token resolves server-side to a workstation.
5. Workstation resolves server-side to store and time zone.
6. Invalid or revoked workstation assignments are rejected.
7. Successful login creates a `user_sessions` record.
8. Active session context includes user, store, workstation, and session.
9. User can lock their own session.
10. User can unlock their own session.
11. Locked sessions show the unlock screen across active tabs/windows.
12. Authorized user can force-end another user’s locked session.
13. Ended, expired, and force-ended sessions cannot return to active.
14. Session lifecycle changes create audit events.
15. Store-local time displays correctly while persisted timestamps remain UTC.

---

## Phase 1C: Application Shell, Setup UI, Audit, and Testing

### Purpose

Build the basic administrative interface and verify the foundation.

### Includes

- Header
- Footer
- Dashboard/home page
- Setup landing page
- Setup screens
- Audit event viewer
- Record-level audit timelines
- Seed data
- System/security tests

### Primary question answered

> Can an administrator safely configure and verify the foundation?

### Exit Criteria

Phase 1C is complete when:

1. Header displays ShelfStack logo, active store, active workstation, menu, search placeholder, user display name, and logout action.
2. Footer displays application name, version, copyright, and lock-session action.
3. Dashboard displays environment/session details.
4. Setup landing page links to users, roles, permissions, stores, workstations, sessions, and audit events.
5. Authorized users can manage foundational records.
6. Unauthorized users are blocked from setup screens.
7. Audit events can be viewed by authorized users.
8. Record detail pages display relevant audit events.
9. Seed data is idempotent.
10. Tests cover authentication, authorization, session, workstation, setup, seed, and audit behavior.

---

## Models Introduced

Phase 1 introduces the following tables:

| Table | Purpose |
|---|---|
| `audit_events` | Append-only log of security, setup, and system events. |
| `permissions` | Seed-managed catalog of application permissions. |
| `roles` | Named bundles of permissions. |
| `role_permissions` | Join table linking roles to permissions. |
| `stores` | Store/location records. |
| `users` | Application users and system actors. |
| `user_role_assignments` | Assigns roles to users globally or within stores. |
| `workstations` | Store-level workstation/register/service desk records. |
| `user_sessions` | Persisted login/session lifecycle records. |
| `workstation_assignments` | Durable browser-to-workstation assignments. |

Optional/deferred tables:

| Table | Status | Notes |
|---|---|---|
| `password_reset_tokens` | Deferred | Only needed for self-service email reset. |
| `system_settings` | Deferred/optional | Useful if timeouts and policies should be database-configurable. |

---

## Key Design Decisions

### Product name

Use **ShelfStack** consistently.

Avoid legacy or alternate names such as ShelfSense or BookSense.

---

### Store terminology

Use **Store** for the business/location entity.

Avoid mixing store, branch, outlet, location, and site unless these become distinct concepts later.

---

### Workstation terminology

Use **Workstation** for a known store-level computer/register/service desk terminal.

Use:

- `workstation_type`
- `workstation_number`
- `workstation_code`
- `name`

---

### Role assignment terminology

Use **Role Assignment** for the relationship between a user and a role.

The assignment is scoped, not the role itself.

Correct wording:

> A user has a store-scoped role assignment.

Avoid:

> A role is store-scoped.

---

### Audit terminology

Use:

| Term | Meaning |
|---|---|
| Actor | User/system that performed the action. |
| Event name | What happened. |
| Auditable | Record affected by the event. |
| Source | Optional object that caused or generated the event. |

---

### Browser workstation assignment

The browser stores only a raw workstation assignment token.

The database stores only the digest of that token.

The server resolves:

```text
browser token → workstation_assignment → workstation → store → time_zone
```
The browser must not be trusted as the source of store, workstation, or permission data.

---

### Time zone handling

All timestamps are stored in UTC.

User-facing timestamps are displayed in the active store’s `time_zone`.

---

### Password reset approach

Phase 1 supports admin-driven password reset.

Self-service email reset is deferred.

---

### PIN usage

PIN unlock is only valid for restoring an existing locked session.

PIN cannot be used for:

* Initial login  
* Setup access  
* Permission escalation  
* Password changes  
* Forced logout authorization

---

### Deletion policy

Hard deletion is restricted.

Records referenced by sessions, audit events, or other foundation records should usually be inactivated rather than deleted.

---

## Deferred Items

The following are intentionally deferred:

| Item | Reason |
| :---- | :---- |
| Email-based password reset | Admin reset is sufficient for Phase 1. |
| Full session management dashboard | Useful later, not required for foundation. |
| Business date/register closeout | Important for POS, but not required yet. |
| Offline POS | Requires later POS-specific architecture. |
| Store groups as a real table | Free-form `store_group` is enough for Phase 1. |
| WebSocket session updates | Polling is simpler and adequate for Phase 1. |
| Full reporting | Audit/event visibility is enough for Phase 1. |
| System settings table | Can be added later if configuration needs to become admin-editable. |

---

## Final Phase 1 Exit Criteria

Phase 1 is complete when all of the following are true.

### Authentication

1. User can log in.  
2. User can log out.  
3. Failed login attempts are tracked.  
4. Successful login updates `previous_login_at` and `last_login_at`.  
5. User can change password.  
6. Admin can reset password.  
7. Forced password change is enforced.  
8. User can set/change PIN.  
9. Admin can reset/clear PIN.  
10. System user cannot log in.  
11. Inactive users cannot log in.  
12. Non-interactive users cannot log in.

### Authorization

1. Permissions are seeded.  
2. Permissions are grouped by `permission_group`.  
3. Roles can contain permissions.  
4. Users can receive global or store-scoped role assignments.  
5. Authorization service resolves effective permissions.  
6. Store-scoped role assignments apply only in matching store context.  
7. Inactive roles, inactive permissions, inactive users, and inactive role assignments do not grant access.  
8. Last super administrator protections are enforced.

### Store and Workstation Context

1. Stores can be managed by authorized users.  
2. Workstations can be managed by authorized users.  
3. Browser can be assigned to a workstation.  
4. Workstation assignment is token-based.  
5. Raw tokens are never stored in the database.  
6. Invalid/revoked workstation assignments are rejected.  
7. Active store is resolved from active workstation/session context.  
8. Store time zone is used for display.

### Sessions

1. Login creates a `user_sessions` record.  
2. Sessions can be active, locked, ended, expired, or force-ended.  
3. User can lock own session.  
4. User can unlock own locked session.  
5. Authorized user can force-end another user’s locked session.  
6. Terminal sessions cannot return to active.  
7. Cross-tab lock behavior works through request checks or polling.

### Auditability

1. Login, failed login, logout, lock, unlock, expiration, force logout, workstation assignment, and setup changes create audit events.  
2. Audit events include actor, event name, timestamp, auditable record when applicable, and session/store/workstation context when available.  
3. Authorized users can view audit events.  
4. Audit events are not editable through normal UI.

### Setup UI

1. Setup landing page exists.  
2. Users can be managed by authorized users.  
3. Roles can be managed by authorized users.  
4. Role permissions can be managed by authorized users.  
5. User role assignments can be managed by authorized users.  
6. Stores can be managed by authorized users.  
7. Workstations can be managed by authorized users.  
8. Permissions can be viewed but not arbitrarily created through normal UI.  
9. Record-level audit timelines are available for foundational records.

### Testing

1. Authentication tests pass.  
2. Authorization tests pass.  
3. Session lifecycle tests pass.  
4. Workstation assignment tests pass.  
5. Setup UI tests pass.  
6. Audit event tests pass.  
7. Seed idempotency tests pass.  
8. Super administrator protection tests pass.