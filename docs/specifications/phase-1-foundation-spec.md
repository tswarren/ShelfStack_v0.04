# Phase 1 Foundation Functional Specification

## Purpose

This specification defines the functional behavior for ShelfStack Phase 1.

It covers authentication, authorization, session lifecycle, workstation assignment, store context, setup workflows, audit events, password/PIN behavior, deletion/inactivation rules, and security protections.

For schema details, see:

```text
docs/specifications/phase-1-data-model.md
````

For test coverage, see:

```
docs/specifications/phase-1-test-plan.md
```

---

# 1. Core Concepts

## 1.1 User

A user is an application actor.

Users may be:

| User Type | Meaning |
| :---- | :---- |
| `user` | Normal interactive user. |
| `admin` | Interactive administrative user. |
| `system` | Non-interactive system actor used for automated/background events. |

A user may log in only if:

1. `active = true`  
2. `interactive_login_enabled = true`  
3. `locked_at` is null or lockout has been cleared  
4. Password is valid  
5. User is not the system user

---

## 1.2 Permission

A permission is a seed-managed application capability.

Example:

```
setup.users.create
sessions.force_end
workstations.assign_browser
```

Permissions are assigned to roles.

Permissions should not generally be created or renamed through normal UI.

---

## 1.3 Role

A role is a named bundle of permissions.

Example:

```
super_administrator
store_manager
bookseller
receiver
```

Roles may be active or inactive.

Inactive roles cannot be newly assigned and should not grant permissions unless explicitly allowed by application rules. For Phase 1, inactive roles should not grant permissions.

---

## 1.4 Role Assignment

A role assignment links a user to a role.

Role assignments may be:

| Scope | Meaning |
| :---- | :---- |
| `global` | Applies across all stores. |
| `store` | Applies only when active store context matches the assignment’s store. |

The assignment is scoped, not the role itself.

---

## 1.5 Store

A store represents a business location.

Stores provide:

* Store number  
* Store name  
* Address/contact information  
* Store group  
* Time zone  
* Active/inactive status

---

## 1.6 Workstation

A workstation represents a store-level computer/register/service desk/back-office station.

Supported workstation types in Phase 1:

```
register
service_desk
back_office
receiving
```

Workstations are assigned to stores.

---

## 1.7 Workstation Assignment

A workstation assignment links a browser to a workstation using a durable token.

The browser stores the raw token.

The database stores only the token digest.

The server resolves:

```
browser token → workstation_assignment → workstation → store → time_zone
```

The browser must not be trusted to provide store, workstation, or permission context.

---

## 1.8 User Session

A user session represents a persisted login session.

Valid statuses:

```
active
locked
ended
expired
force_ended
```

Sessions are linked to:

* User  
* Store  
* Workstation  
* Token digest  
* Last activity timestamp  
* Lock/end metadata

---

## 1.9 Audit Event

An audit event records security, session, setup, and system events.

Audit events include:

* Actor  
* Event name  
* Affected record, when applicable  
* Source record, when applicable  
* Store context  
* Workstation context  
* Session context  
* Timestamp  
* JSON details

Audit events are append-only through normal application behavior.

---

# 2. Authentication

## 2.1 Login

Users log in using username and password.

### Login rules

A login succeeds only if:

1. Username exists after normalization.  
2. User is active.  
3. User has `interactive_login_enabled = true`.  
4. User is not the system user.  
5. User is not locked out.  
6. Password is valid.  
7. The workstation/session context is valid, if workstation assignment is required.

### Successful login behavior

On successful login:

1. Capture current `invalid_login_attempts` value for flash message.  
2. Copy current `last_login_at` to `previous_login_at`.  
3. Set `last_login_at` to current UTC timestamp.  
4. Reset `invalid_login_attempts` to `0`.  
5. Create `user_sessions` record with status `active`.  
6. Set `last_activity_at`.  
7. Associate session with resolved store/workstation context.  
8. Create `user.login` audit event.  
9. Redirect user to dashboard/home page.  
10. If `force_password_change = true`, redirect user to change password screen before allowing normal navigation.

### Failed login behavior

On failed login:

1. Increment `invalid_login_attempts` if username maps to a valid interactive user.  
2. If configured failed-attempt threshold is reached, set `locked_at`.  
3. Create `user.login_failed` audit event when a user record can be safely identified.  
4. Show generic login error.

The UI should not reveal whether the username exists.

### Login flash messages

If there were no failed login attempts since previous login:

```
Welcome, [display_name]. You last logged in at [previous_login_at].
```

If failed attempts occurred:

```
Welcome, [display_name]. There were [failed_login_count] failed login attempts since you last logged in at [previous_login_at].
```

The failed login count must be captured before resetting `invalid_login_attempts`.

---

## 2.2 Logout

When a user logs out:

1. Current `user_sessions.status` becomes `ended`.  
2. `ended_at` is set.  
3. A `user.logout` audit event is created.  
4. Browser is returned to login screen.  
5. Session token is invalidated.

An ended session cannot return to active.

---

## 2.3 Password Change

Users may change their own password.

### Rules

A user changing their password must:

1. Enter current password.  
2. Enter new password.  
3. Confirm new password.  
4. Satisfy password policy.

On successful password change:

1. `password_digest` is updated.  
2. `password_changed_at` is updated.  
3. `force_password_change` is set to false.  
4. `user.password_changed` audit event is created.

### Restrictions

* Existing password is never displayed.  
* Password is never stored in plain text.  
* System user password cannot be changed through normal UI.  
* PIN cannot be used to change password.

---

## 2.4 Admin Password Reset

Authorized admins may reset another user’s password.

### Behavior

On password reset:

1. Admin enters or generates temporary password.  
2. Target user’s `password_digest` is updated.  
3. Target user’s `password_changed_at` is updated.  
4. Target user’s `force_password_change` is set to true.  
5. Target user’s `invalid_login_attempts` may be reset to `0`.  
6. Target user’s `locked_at` may be cleared if admin selects unlock/reset behavior.  
7. `user.password_reset` audit event is created.

### Restrictions

* Admin cannot view existing password.  
* Admin cannot reset system user through normal UI.  
* Admin cannot use password reset to bypass last-super-admin protections.

---

## 2.5 PIN Setup and Change

PINs are used only to unlock existing locked sessions.

### User PIN change

A user may set or change their own PIN.

On success:

1. `pin_digest` is updated.  
2. `pin_changed_at` is updated.  
3. `user.pin_changed` audit event is created.

### Admin PIN reset/clear

Authorized admin may clear or reset a user’s PIN.

On reset/clear:

1. `pin_digest` is updated or cleared.  
2. `pin_changed_at` is updated.  
3. `user.pin_reset` or `user.pin_cleared` audit event is created.

### PIN restrictions

PIN cannot be used for:

* Initial login  
* Setup access  
* Password change  
* Password reset  
* Permission escalation  
* Forced logout authentication  
* Changing another user’s record

If a user has no PIN, unlocking a locked session should require password authentication.

---

# 3. Authorization

## 3.1 Permission Resolution

Authorization should be resolved through a shared service.

Example conceptual interface:

```
Authorization.allowed?(user:, permission_key:, store:)
```

or:

```
Current.user_can?("setup.users.update")
```

### Permission grant rules

A user has a permission if all are true:

1. User is active.  
     
2. User has interactive access, except for system-only service contexts.  
     
3. User has at least one active role assignment.  
     
4. Assigned role is active.  
     
5. Role includes active permission.  
     
6. Permission key matches requested permission.  
     
7. Assignment scope applies:  
     
   * Global assignment applies to all stores.  
   * Store assignment applies only when active store matches assignment store.

### Non-grant rules

Permission is not granted if:

* User is inactive.  
* User is locked out for login/security purposes.  
* Role assignment is inactive.  
* Role is inactive.  
* Permission is inactive.  
* Store-scoped assignment does not match active store.  
* No active store exists and the permission requires store context.  
* User is system user in an interactive UI context.

---

## 3.2 Super Administrator Protection

ShelfStack must prevent accidental administrative lockout.

### Protected rules

The application must prevent:

1. Deleting the `super_administrator` role.  
2. Inactivating the only active administrative role path.  
3. Removing the last global super administrator assignment.  
4. Inactivating the last active interactive global super administrator user.  
5. Disabling interactive login for the last active interactive global super administrator.  
6. Removing required setup permissions from the only remaining super administrator role path.  
7. Treating the system user as satisfying the “last admin” requirement.

### Minimum active admin rule

There must always be at least one active, interactive user with a global role assignment that grants full administrative recovery access.

---

# 4. Workstation Assignment

## 4.1 Assignment Token

A browser workstation assignment uses a durable token.

### Rules

* Browser stores raw token in secure cookie.  
* Database stores only `assignment_token_digest`.  
* Raw assignment token is never stored.  
* Token resolves to `workstation_assignments`.  
* Assignment is valid only if `revoked_at` is null.  
* Workstation must be active.  
* Store must be active.

---

## 4.2 Unassigned Browser

If a browser has no valid workstation assignment:

1. Login page is displayed.  
2. Only users with workstation assignment permission may continue assignment workflow.  
3. Authorized user selects store.  
4. Authorized user selects existing active workstation or creates one.  
5. Application creates workstation assignment.  
6. Browser receives assignment token cookie.  
7. Browser context resolves server-side on future requests.

---

## 4.3 Assigned Browser

If browser has valid workstation assignment:

1. Login page displays store name.  
2. Login page displays workstation name/code.  
3. Login page displays workstation type.  
4. User login occurs in that workstation/store context.  
5. Session records store/workstation context.

---

## 4.4 Reassignment

Authorized users may reassign a browser.

On reassignment:

1. Existing active assignment is revoked by setting `revoked_at`.  
2. New workstation assignment is created.  
3. Browser receives new assignment token.  
4. Audit event is created.

Audit event:

```
workstation_assignment.reassigned
```

---

## 4.5 Assignment Conflict Rules

Phase 1 should use the following default:

One active browser assignment per workstation unless explicitly overridden later.

If enforcing this in PostgreSQL:

```sql
CREATE UNIQUE INDEX index_workstation_assignments_one_active_per_workstation
ON workstation_assignments (workstation_id)
WHERE revoked_at IS NULL;
```

If this restriction proves too strict later, it can be relaxed.

---

# 5. User Sessions

## 5.1 Session Creation

A successful login creates a `user_sessions` record.

Initial values:

| Field | Value |
| :---- | :---- |
| `user_id` | Logged-in user |
| `store_id` | Resolved active store |
| `workstation_id` | Resolved active workstation |
| `session_token_digest` | Digest of raw session token |
| `status` | `active` |
| `last_activity_at` | Current UTC timestamp |

---

## 5.2 Session Statuses

| Status | Meaning |
| :---- | :---- |
| `active` | User is logged in and session is usable. |
| `locked` | Session is temporarily locked and requires unlock. |
| `ended` | User logged out. |
| `expired` | Session ended due to inactivity/timeout. |
| `force_ended` | Authorized user terminated the locked session. |

Terminal statuses:

```
ended
expired
force_ended
```

Terminal sessions cannot return to active.

---

## 5.3 Session Lock

A session may be locked manually or by inactivity.

On lock:

1. `status` becomes `locked`.  
2. `locked_at` is set.  
3. `session.locked` audit event is created.  
4. All active tabs/windows display unlock screen.

---

## 5.4 Session Unlock

Only the same active user may unlock a locked session.

Unlock may use:

* PIN, if user has PIN  
* Password, if user has no PIN or password unlock is enabled

On successful unlock:

1. `status` becomes `active`.  
2. `unlocked_at` is updated.  
3. `last_activity_at` is updated.  
4. `session.unlocked` audit event is created.  
5. Open pages return to prior state where practical.

---

## 5.5 Forced Session Termination

Authorized users may force-end another user’s locked session.

### Flow

1. User clicks force-end option from locked screen.  
     
2. Prompt asks for username and password.  
     
3. Application authenticates entered user.  
     
4. Application checks `sessions.force_end`.  
     
5. If authorized:  
     
   * Locked session becomes `force_ended`.  
   * `ended_at` is set.  
   * `ended_by_user_id` is set.  
   * Audit event is created.  
   * Browser returns to login screen.

   

6. If canceled or unauthorized:  
     
   * Session remains locked.  
   * Browser returns to unlock screen.

---

## 5.6 Cross-Tab Lock Behavior

Phase 1 should use a simple polling/request-check approach.

Required behavior:

1. Every authenticated request checks session status.  
2. Frontend periodically calls lightweight session status endpoint.  
3. If status is `locked`, tabs show unlock screen.  
4. If status is `force_ended`, `ended`, or `expired`, tabs return to login.

WebSockets are deferred.

---

# 6. Current Context

Phase 1 should define a shared request context object.

In Rails, this may be implemented with `CurrentAttributes`.

Expected context:

```
Current.user
Current.store
Current.workstation
Current.user_session
Current.workstation_assignment
Current.time_zone
```

This context should be set once per request and used by:

* Controllers  
* Authorization service  
* Audit event service  
* Session service  
* Workstation service  
* Setup services

---

# 7. Store and Time Zone Behavior

## 7.1 Timestamp Storage

All persisted timestamps are stored in UTC.

## 7.2 Timestamp Display

User-facing timestamps are displayed using the active store’s `time_zone`.

If no active store exists, use application default time zone.

## 7.3 Business Date

Phase 1 does not implement business date or register closeout.

However, later POS/inventory records should support store-local business dates.

Decision:

Phase 1 stores exact event timestamps only. Business date support is deferred.

---

# 8. Setup Area

## 8.1 Setup Landing Page

Setup should include links/cards for:

* Users  
* Roles  
* Permissions  
* Stores  
* Workstations  
* Active/locked sessions, optional  
* Audit events

---

## 8.2 Permissions UI

Permissions are seed-managed.

Authorized users may:

* View permissions  
* Filter permissions by group  
* See which roles include a permission

Authorized users should not normally:

* Create permission keys  
* Rename permission keys  
* Delete permissions

Permissions may be inactivated only through controlled seed/application maintenance workflows.

---

## 8.3 Roles UI

Authorized users may:

* View roles  
* Create roles  
* Edit role name/description  
* Inactivate roles  
* Reactivate roles  
* Delete roles only when unused and not protected  
* Assign permissions to roles  
* Remove permissions from roles

Protected system roles cannot be deleted through normal UI.

---

## 8.4 Users UI

Authorized users may:

* View users  
* Create users  
* Edit users  
* Inactivate users  
* Reactivate users  
* Delete users only when unused and not protected  
* Reset password  
* Reset/clear PIN  
* Force password change  
* Assign roles  
* Remove role assignments  
* View user audit timeline

---

## 8.5 Stores UI

Authorized users may:

* View stores  
* Create stores  
* Edit stores  
* Inactivate stores  
* Reactivate stores  
* Delete stores only when unused  
* View store audit timeline

Stores referenced by workstations, sessions, audit events, users, or future business records should be inactivated rather than deleted.

---

## 8.6 Workstations UI

Authorized users may:

* View workstations  
* Create workstations  
* Edit workstation name/type/number where allowed  
* Inactivate workstations  
* Reactivate workstations  
* Delete workstations only when unused  
* View workstation audit timeline

Inactive workstations cannot be assigned to new browser assignments or new sessions.

---

# 9. Deletion and Inactivation Rules

| Record | Hard Delete? | Preferred Action |
| :---- | ----: | :---- |
| Permission | No UI delete | Inactivate/retire through seed maintenance. |
| System role | No | Keep protected. |
| Role with assignments | No | Inactivate. |
| User with sessions/audit events | No | Inactivate. |
| Store with references | No | Inactivate. |
| Workstation with references | No | Inactivate. |
| User session | No | End/expire. |
| Workstation assignment | No | Revoke. |
| Audit event | No | Append-only. |

---

# 10. Normalization Rules

| Field | Normalization |
| :---- | :---- |
| `users.username` | Normalize consistently, preferably lowercase. |
| `stores.email` | Trim and lowercase. |
| `stores.country_code` | Trim and uppercase. |
| `stores.region_code` | Trim and uppercase. |
| `stores.website_url` | Trim and ensure protocol. |
| `stores.store_number` | Numeric-only if required; left-pad for display/storage convention. |
| `workstations.workstation_number` | Numeric-only; left-pad to 3 digits. |
| `permissions.permission_key` | Lowercase dot-separated. |
| `permissions.permission_group` | Lowercase. |
| `roles.role_key` | Lowercase snake\_case. |

---

# 11. Required Audit Events

## Authentication and password/PIN

```
user.login
user.login_failed
user.logout
user.password_changed
user.password_reset
user.pin_changed
user.pin_reset
user.pin_cleared
```

## Sessions

```
session.locked
session.unlocked
session.expired
session.force_ended
```

## Workstation assignments

```
workstation_assignment.created
workstation_assignment.revoked
workstation_assignment.reassigned
```

## Roles and permissions

```
role.created
role.updated
role.inactivated
role.reactivated
role.deleted
role.permission_added
role.permission_removed
```

## Users

```
user.created
user.updated
user.inactivated
user.reactivated
user.deleted
user.role_added
user.role_removed
```

## Stores

```
store.created
store.updated
store.inactivated
store.reactivated
store.deleted
```

## Workstations

```
workstation.created
workstation.updated
workstation.inactivated
workstation.reactivated
workstation.deleted
```

---

# 12. Application Shell

## Header

Header includes:

* ShelfStack logo/home link  
* Active store  
* Active workstation  
* Main menu  
* Search placeholder  
* User display name/avatar  
* Logout action

## Footer

Footer includes:

* ShelfStack name  
* Version  
* Copyright  
* Lock session action

## Dashboard

Dashboard displays:

* Store  
* Store time zone  
* Workstation  
* Workstation type  
* User  
* User type  
* Last login timestamp  
* Previous login timestamp  
* Session created timestamp  
* Session status  
* Inactivity duration  
* Lock duration, if locked

---

# 13. Error Handling

## Login errors

Use generic login error messages.

Do not reveal whether username exists.

## Authorization errors

Unauthorized users should receive:

* Redirect to safe page, or  
* 403 forbidden response for direct access

## Invalid workstation assignment

If assignment token is invalid/revoked:

1. Clear cookie.  
2. Return browser to unassigned workstation flow.

## Invalid session token

If session token is invalid:

1. Clear session cookie.  
2. Return to login.

## Terminal session

If session is ended, expired, or force-ended:

1. Clear active session.  
2. Return to login.

---

# 14. Functional Acceptance Criteria

Phase 1 behavior is accepted when:

1. Authentication works for valid users.  
2. Invalid/inactive/non-interactive users are blocked.  
3. Password change and admin reset work.  
4. PIN setup/change/reset works.  
5. Authorization service resolves global and store-scoped permissions.  
6. Setup access is permission-controlled.  
7. Super administrator protections prevent lockout.  
8. Browser workstation assignment works through secure token.  
9. Session lifecycle works.  
10. Cross-tab lock behavior works through polling or request checks.  
11. Store time zone controls display.  
12. Audit events are created for required actions.  
13. Setup screens enforce deletion/inactivation policy.  
14. Tests prove core security and setup flows.