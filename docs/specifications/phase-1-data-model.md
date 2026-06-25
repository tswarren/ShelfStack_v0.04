# Phase 1 Data Model

## Purpose

This document defines the Phase 1 ShelfStack data model, including tables, fields, indexes, constraints, controlled values, and seed data.

Phase 1 establishes the operational foundation for ShelfStack:

* Users
* Roles
* Permissions
* Stores
* Workstations
* Browser workstation assignments
* User sessions
* Audit events

This document should be treated as the source of truth for Phase 1 migrations.

---

# 1. Phase 1 Scope

Phase 1 introduces the foundation required for later ShelfStack workflows.

## Included

Phase 1 includes:

* Authentication-ready user records
* Role-based permissions
* Global and store-scoped role assignments
* Store records
* Workstation records
* Browser-to-workstation assignments
* Persisted user sessions
* Session lock/unlock support
* Forced session termination support
* Audit event logging
* Seed data for a usable development/demo instance

## Not Included

Phase 1 does not include:

* Departments
* Categories
* Tax categories
* Store tax rates
* Catalog items
* Products
* Product variants
* Inventory
* Purchasing
* Receiving
* POS sales
* Reporting beyond basic audit/event review

---

# 2. Naming Conventions

## 2.1 Tables

Phase 1 introduces the following tables:

```text
audit_events
permissions
roles
role_permissions
stores
users
user_role_assignments
workstations
user_sessions
workstation_assignments
```

---

## 2.2 Booleans

Use Rails-style boolean names without `is_`.

Use:

```text
active
system_role
interactive_login_enabled
force_password_change
```

Avoid:

```text
is_active
is_system_role
```

---

## 2.3 Stable Keys

Use `_key` for stable internal identifiers.

Examples:

```text
permission_key
role_key
```

Use `name` for human-readable display labels.

---

## 2.4 Datetime Fields

Use `_at` for datetime fields.

Examples:

```text
last_login_at
previous_login_at
locked_at
ended_at
assigned_at
revoked_at
```

---

## 2.5 Avoid Rails STI Conflicts

Do not use a column named `type` unless intentionally using Rails single-table inheritance.

Use explicit names:

```text
user_type
workstation_type
scope_type
source_type
auditable_type
```

---

# 3. Data Model Summary

| Table                     | Purpose                                                         |
| ------------------------- | --------------------------------------------------------------- |
| `audit_events`            | Append-only log of security, setup, session, and system events. |
| `permissions`             | Seed-managed catalog of application permissions.                |
| `roles`                   | Named bundles of permissions.                                   |
| `role_permissions`        | Join table linking roles to permissions.                        |
| `stores`                  | Store/location records.                                         |
| `users`                   | Application users and system actors.                            |
| `user_role_assignments`   | Assigns roles to users globally or within stores.               |
| `workstations`            | Store-level workstation/register/service desk records.          |
| `user_sessions`           | Persisted login/session lifecycle records.                      |
| `workstation_assignments` | Durable browser-to-workstation assignments.                     |

---

# 4. Schema

## 4.1 `audit_events`

Audit events record important application activity.

Audit events should be treated as append-only through normal application behavior.

| Table          | Field             |     Type | Constraints                    | Notes                                                                                       |
| -------------- | ----------------- | -------: | ------------------------------ | ------------------------------------------------------------------------------------------- |
| `audit_events` | `id`              |   bigint | auto increment                 |                                                                                             |
| `audit_events` | `actor_user_id`   |   bigint | references `users`, null false | User/system actor that performed the action. Use system user for background actions.        |
| `audit_events` | `event_name`      |   string | null false                     | Dot-separated event name. Example: `user.login`, `session.locked`, `role.permission_added`. |
| `audit_events` | `auditable_type`  |   string |                                | Polymorphic affected record type.                                                           |
| `audit_events` | `auditable_id`    |   bigint |                                | Polymorphic affected record ID.                                                             |
| `audit_events` | `source_type`     |   string |                                | Optional source object/event type.                                                          |
| `audit_events` | `source_id`       |   bigint |                                | Optional source object/event ID.                                                            |
| `audit_events` | `store_id`        |   bigint | references `stores`            | Nullable store context.                                                                     |
| `audit_events` | `workstation_id`  |   bigint | references `workstations`      | Nullable workstation context.                                                               |
| `audit_events` | `user_session_id` |   bigint | references `user_sessions`     | Nullable session context.                                                                   |
| `audit_events` | `occurred_at`     | datetime | null false                     | Store in UTC.                                                                               |
| `audit_events` | `event_details`   |    jsonb | null false, default `{}`       | Structured event metadata. Use `jsonb` in PostgreSQL.                                       |
| `audit_events` | `created_at`      | datetime | null false                     |                                                                                             |
| `audit_events` | `updated_at`      | datetime | null false                     | Rails standard timestamp; audit rows usually should not change.                             |

---

## 4.2 `permissions`

Permissions are seed-managed application capabilities.

Permissions should generally be viewable through setup screens but not freely created, renamed, or deleted through normal UI.

| Table         | Field              |     Type | Constraints              | Notes                                                                  |
| ------------- | ------------------ | -------: | ------------------------ | ---------------------------------------------------------------------- |
| `permissions` | `id`               |   bigint | auto increment           |                                                                        |
| `permissions` | `permission_key`   |   string | null false, unique       | Stable permission key. Example: `setup.users.create`.                  |
| `permissions` | `permission_group` |   string | null false               | Group for setup display. Example: `setup`, `sessions`, `workstations`. |
| `permissions` | `name`             |   string | null false               | Human-readable name.                                                   |
| `permissions` | `description`      |     text |                          | Optional description.                                                  |
| `permissions` | `active`           |  boolean | null false, default true | Retired permissions remain for history but should not grant access.    |
| `permissions` | `created_at`       | datetime | null false               |                                                                        |
| `permissions` | `updated_at`       | datetime | null false               |                                                                        |

---

## 4.3 `roles`

Roles are named bundles of permissions.

Roles may be assigned to users globally or within a store through `user_role_assignments`.

| Table   | Field         |     Type | Constraints               | Notes                                                                |
| ------- | ------------- | -------: | ------------------------- | -------------------------------------------------------------------- |
| `roles` | `id`          |   bigint | auto increment            |                                                                      |
| `roles` | `role_key`    |   string | null false, unique        | Stable internal key. Example: `super_administrator`.                 |
| `roles` | `name`        |   string | null false                | Display name.                                                        |
| `roles` | `description` |     text |                           | Optional description.                                                |
| `roles` | `system_role` |  boolean | null false, default false | Protects seed/system roles from accidental deletion.                 |
| `roles` | `active`      |  boolean | null false, default true  | Inactive roles cannot be newly assigned and should not grant access. |
| `roles` | `created_at`  | datetime | null false                |                                                                      |
| `roles` | `updated_at`  | datetime | null false                |                                                                      |

---

## 4.4 `role_permissions`

`role_permissions` links roles to permissions.

| Table              | Field           |     Type | Constraints                          | Notes                           |
| ------------------ | --------------- | -------: | ------------------------------------ | ------------------------------- |
| `role_permissions` | `id`            |   bigint | auto increment                       |                                 |
| `role_permissions` | `role_id`       |   bigint | references `roles`, null false       | Role receiving the permission.  |
| `role_permissions` | `permission_id` |   bigint | references `permissions`, null false | Permission granted to the role. |
| `role_permissions` | `created_at`    | datetime | null false                           |                                 |
| `role_permissions` | `updated_at`    | datetime | null false                           |                                 |

---

## 4.5 `stores`

Stores represent physical or operational store locations.

Store context affects time zone, workstations, store-scoped permissions, store-specific tax behavior in later phases, and future inventory/POS behavior.

| Table    | Field             |     Type | Constraints                            | Notes                                                       |
| -------- | ----------------- | -------: | -------------------------------------- | ----------------------------------------------------------- |
| `stores` | `id`              |   bigint | auto increment                         |                                                             |
| `stores` | `store_number`    |   string | null false, unique, limit 4            | Store as string to preserve leading zeroes. Example: `001`. |
| `stores` | `store_group`     |   string | limit 5                                | Free-form reporting group for Phase 1.                      |
| `stores` | `name`            |   string | null false, limit 80                   | Store display name.                                         |
| `stores` | `shopping_center` |   string |                                        | Optional.                                                   |
| `stores` | `address_line1`   |   string |                                        |                                                             |
| `stores` | `address_line2`   |   string |                                        |                                                             |
| `stores` | `city`            |   string |                                        |                                                             |
| `stores` | `country_code`    |   string | null false, limit 2, default `US`      | ISO country code.                                           |
| `stores` | `region_code`     |   string | limit 2                                | State/province code.                                        |
| `stores` | `postal_code`     |   string | limit 20                               | Postal/ZIP code.                                            |
| `stores` | `phone`           |   string | limit 20                               |                                                             |
| `stores` | `fax`             |   string | limit 20                               |                                                             |
| `stores` | `email`           |   string |                                        | Normalize lowercase.                                        |
| `stores` | `website_url`     |   string |                                        | Store full URL, including protocol.                         |
| `stores` | `time_zone`       |   string | null false, default `America/New_York` | Use IANA time zone names.                                   |
| `stores` | `active`          |  boolean | null false, default true               | Inactive stores cannot be selected for new activity.        |
| `stores` | `created_at`      | datetime | null false                             |                                                             |
| `stores` | `updated_at`      | datetime | null false                             |                                                             |

---

## 4.6 `users`

Users represent application users and system actors.

The seeded `system` user is used for automated/background activity and cannot log in interactively.

| Table   | Field                       |     Type | Constraints                  | Notes                                                                 |
| ------- | --------------------------- | -------: | ---------------------------- | --------------------------------------------------------------------- |
| `users` | `id`                        |   bigint | auto increment               |                                                                       |
| `users` | `user_type`                 |   string | null false, default `user`   | Controlled value: `user`, `admin`, `system`.                          |
| `users` | `default_store_id`          |   bigint | references `stores`          | Optional default store.                                               |
| `users` | `username`                  |   string | null false, unique, limit 50 | Normalize consistently, preferably lowercase.                         |
| `users` | `first_name`                |   string | null false, limit 50         |                                                                       |
| `users` | `last_name`                 |   string | null false, limit 50         |                                                                       |
| `users` | `display_name`              |   string | null false, limit 80         | Display name shown in UI.                                             |
| `users` | `clerk_number`              |   string | unique, limit 10             | Nullable for system user. Store as string to preserve leading zeroes. |
| `users` | `password_digest`           |   string |                              | Required for interactive users.                                       |
| `users` | `pin_digest`                |   string |                              | Nullable. Used only for locked-session unlock.                        |
| `users` | `password_changed_at`       | datetime |                              |                                                                       |
| `users` | `pin_changed_at`            | datetime |                              |                                                                       |
| `users` | `invalid_login_attempts`    |  integer | null false, default 0        | Reset after successful login.                                         |
| `users` | `locked_at`                 | datetime |                              | Used for failed-login/security lockout.                               |
| `users` | `previous_login_at`         | datetime |                              | Previous successful login timestamp.                                  |
| `users` | `last_login_at`             | datetime |                              | Most recent successful login timestamp.                               |
| `users` | `force_password_change`     |  boolean | null false, default false    | Useful for seeded/admin-reset users.                                  |
| `users` | `interactive_login_enabled` |  boolean | null false, default true     | False for system user.                                                |
| `users` | `active`                    |  boolean | null false, default true     | Inactive users cannot log in.                                         |
| `users` | `deactivated_at`            | datetime |                              | Optional lifecycle history.                                           |
| `users` | `created_at`                | datetime | null false                   |                                                                       |
| `users` | `updated_at`                | datetime | null false                   |                                                                       |

---

## 4.7 `user_role_assignments`

User role assignments link users to roles.

Assignments may be global or store-scoped.

The assignment is scoped, not the role itself.

| Table                   | Field                 |     Type | Constraints                    | Notes                                         |
| ----------------------- | --------------------- | -------: | ------------------------------ | --------------------------------------------- |
| `user_role_assignments` | `id`                  |   bigint | auto increment                 |                                               |
| `user_role_assignments` | `user_id`             |   bigint | references `users`, null false | User receiving the role assignment.           |
| `user_role_assignments` | `role_id`             |   bigint | references `roles`, null false | Assigned role.                                |
| `user_role_assignments` | `scope_type`          |   string | null false, default `store`    | Controlled value: `global` or `store`.        |
| `user_role_assignments` | `store_id`            |   bigint | references `stores`            | Null when global; required when store-scoped. |
| `user_role_assignments` | `active`              |  boolean | null false, default true       | Inactive assignments do not grant access.     |
| `user_role_assignments` | `assigned_by_user_id` |   bigint | references `users`             | Optional user who assigned role.              |
| `user_role_assignments` | `assigned_at`         | datetime |                                | Optional assignment timestamp.                |
| `user_role_assignments` | `created_at`          | datetime | null false                     |                                               |
| `user_role_assignments` | `updated_at`          | datetime | null false                     |                                               |

---

## 4.8 `workstations`

Workstations represent store-level computers, registers, service desks, receiving stations, and back-office stations.

| Table          | Field                |     Type | Constraints                     | Notes                                                                     |
| -------------- | -------------------- | -------: | ------------------------------- | ------------------------------------------------------------------------- |
| `workstations` | `id`                 |   bigint | auto increment                  |                                                                           |
| `workstations` | `store_id`           |   bigint | references `stores`, null false | Store that owns the workstation.                                          |
| `workstations` | `workstation_type`   |   string | null false                      | Controlled value: `register`, `service_desk`, `back_office`, `receiving`. |
| `workstations` | `workstation_number` |   string | null false, limit 3             | Zero-padded store-level workstation number.                               |
| `workstations` | `workstation_code`   |   string | null false                      | Example: `001-REG001`.                                                    |
| `workstations` | `name`               |   string | null false                      | Friendly display name. Example: `Front Register`.                         |
| `workstations` | `active`             |  boolean | null false, default true        | Inactive workstations cannot be assigned to browsers or new sessions.     |
| `workstations` | `created_at`         | datetime | null false                      |                                                                           |
| `workstations` | `updated_at`         | datetime | null false                      |                                                                           |

---

## 4.9 `user_sessions`

User sessions persist login/session lifecycle state.

Sessions may be active, locked, ended, expired, or force-ended.

| Table           | Field                  |     Type | Constraints                    | Notes                                                                    |
| --------------- | ---------------------- | -------: | ------------------------------ | ------------------------------------------------------------------------ |
| `user_sessions` | `id`                   |   bigint | auto increment                 |                                                                          |
| `user_sessions` | `user_id`              |   bigint | references `users`, null false | Logged-in user.                                                          |
| `user_sessions` | `store_id`             |   bigint | references `stores`            | Active store context.                                                    |
| `user_sessions` | `workstation_id`       |   bigint | references `workstations`      | Active workstation context.                                              |
| `user_sessions` | `session_token_digest` |   string | null false, unique             | Store digest only, never raw token.                                      |
| `user_sessions` | `status`               |   string | null false, default `active`   | Controlled value: `active`, `locked`, `ended`, `expired`, `force_ended`. |
| `user_sessions` | `last_activity_at`     | datetime | null false                     | Used for inactivity tracking.                                            |
| `user_sessions` | `locked_at`            | datetime |                                | Set when session is locked.                                              |
| `user_sessions` | `locked_return_path`   |   string | limit 2048                     | Internal path to restore after unlock; cleared on unlock.                |
| `user_sessions` | `unlocked_at`          | datetime |                                | Optional last successful unlock timestamp.                               |
| `user_sessions` | `ended_at`             | datetime |                                | Set when session ends, expires, or is force-ended.                       |
| `user_sessions` | `ended_by_user_id`     |   bigint | references `users`             | Used for forced session termination.                                     |
| `user_sessions` | `ip_address`           |   string |                                | Optional.                                                                |
| `user_sessions` | `user_agent`           |     text |                                | Optional.                                                                |
| `user_sessions` | `created_at`           | datetime | null false                     |                                                                          |
| `user_sessions` | `updated_at`           | datetime | null false                     |                                                                          |

---

## 4.10 `workstation_assignments`

Workstation assignments link a browser to a workstation using a durable token.

The browser stores the raw token. The database stores only the digest.

| Table                     | Field                     |     Type | Constraints                           | Notes                                                 |
| ------------------------- | ------------------------- | -------: | ------------------------------------- | ----------------------------------------------------- |
| `workstation_assignments` | `id`                      |   bigint | auto increment                        |                                                       |
| `workstation_assignments` | `workstation_id`          |   bigint | references `workstations`, null false | Assigned workstation.                                 |
| `workstation_assignments` | `assignment_token_digest` |   string | null false, unique                    | Cookie stores raw token; database stores digest only. |
| `workstation_assignments` | `assigned_by_user_id`     |   bigint | references `users`                    | User/admin who assigned this browser.                 |
| `workstation_assignments` | `assigned_at`             | datetime | null false                            | Assignment timestamp.                                 |
| `workstation_assignments` | `last_seen_at`            | datetime |                                       | Updated when assignment is used.                      |
| `workstation_assignments` | `revoked_at`              | datetime |                                       | Set when assignment is revoked/replaced.              |
| `workstation_assignments` | `created_at`              | datetime | null false                            |                                                       |
| `workstation_assignments` | `updated_at`              | datetime | null false                            |                                                       |

---

# 5. Recommended Indexes

## 5.1 Index Table

| Table                     | Index                                                     | Type                     | Notes                                                              |
| ------------------------- | --------------------------------------------------------- | ------------------------ | ------------------------------------------------------------------ |
| `audit_events`            | `actor_user_id`                                           | normal                   | Supports user activity review.                                     |
| `audit_events`            | `event_name`                                              | normal                   | Supports filtering by event type.                                  |
| `audit_events`            | `occurred_at`                                             | normal                   | Supports chronological audit review.                               |
| `audit_events`            | `auditable_type, auditable_id`                            | composite                | Supports record-level audit timelines.                             |
| `audit_events`            | `source_type, source_id`                                  | composite                | Supports source event/object lookup.                               |
| `audit_events`            | `store_id`                                                | normal                   | Supports store-specific audit review.                              |
| `audit_events`            | `workstation_id`                                          | normal                   | Supports workstation-specific audit review.                        |
| `audit_events`            | `user_session_id`                                         | normal                   | Supports session event review.                                     |
| `audit_events`            | `store_id, occurred_at`                                   | composite                | Useful for store audit timelines.                                  |
| `permissions`             | `permission_key`                                          | unique                   | Stable permission lookup.                                          |
| `permissions`             | `permission_group`                                        | normal                   | Supports grouped setup screens.                                    |
| `permissions`             | `active`                                                  | normal                   | Supports hiding retired permissions.                               |
| `roles`                   | `role_key`                                                | unique                   | Stable role lookup.                                                |
| `roles`                   | `name`                                                    | normal                   | Supports setup search/listing.                                     |
| `roles`                   | `active`                                                  | normal                   | Supports active/inactive filtering.                                |
| `roles`                   | `system_role`                                             | normal                   | Supports protected-role behavior.                                  |
| `role_permissions`        | `role_id`                                                 | normal                   | Supports role permission lookup.                                   |
| `role_permissions`        | `permission_id`                                           | normal                   | Supports reverse permission lookup.                                |
| `role_permissions`        | `role_id, permission_id`                                  | unique composite         | Prevents duplicate permission assignment.                          |
| `stores`                  | `store_number`                                            | unique                   | Primary store lookup/display identifier.                           |
| `stores`                  | `store_group`                                             | normal                   | Supports group filtering/reporting.                                |
| `stores`                  | `name`                                                    | normal                   | Supports setup search/listing.                                     |
| `stores`                  | `active`                                                  | normal                   | Supports active/inactive filtering.                                |
| `stores`                  | `country_code, region_code`                               | composite                | Supports location filtering.                                       |
| `users`                   | `username`                                                | unique                   | Login lookup.                                                      |
| `users`                   | `clerk_number`                                            | unique partial           | Allow multiple nulls if system user has none.                      |
| `users`                   | `default_store_id`                                        | normal                   | Supports store-based user lists.                                   |
| `users`                   | `user_type`                                               | normal                   | Supports admin/system/user filtering.                              |
| `users`                   | `active`                                                  | normal                   | Supports active/inactive filtering.                                |
| `users`                   | `locked_at`                                               | normal                   | Supports locked-account review.                                    |
| `user_role_assignments`   | `user_id`                                                 | normal                   | Supports permission lookup.                                        |
| `user_role_assignments`   | `role_id`                                                 | normal                   | Supports role assignment review.                                   |
| `user_role_assignments`   | `store_id`                                                | normal                   | Supports store-scoped user lists.                                  |
| `user_role_assignments`   | `assigned_by_user_id`                                     | normal                   | Supports admin/audit review.                                       |
| `user_role_assignments`   | `scope_type`                                              | normal                   | Supports global/store filtering.                                   |
| `user_role_assignments`   | `active`                                                  | normal                   | Supports active/inactive filtering.                                |
| `user_role_assignments`   | `user_id, role_id` where `scope_type = 'global'`          | partial unique           | Prevents duplicate global assignments.                             |
| `user_role_assignments`   | `user_id, role_id, store_id` where `scope_type = 'store'` | partial unique           | Prevents duplicate store-scoped assignments.                       |
| `workstations`            | `store_id`                                                | normal                   | Supports store workstation lists.                                  |
| `workstations`            | `workstation_type`                                        | normal                   | Supports filtering by workstation type.                            |
| `workstations`            | `active`                                                  | normal                   | Supports active/inactive filtering.                                |
| `workstations`            | `store_id, workstation_number`                            | unique composite         | Allows each store to have workstation `001`.                       |
| `workstations`            | `store_id, workstation_code`                              | unique composite         | Prevents duplicate generated codes within a store.                 |
| `user_sessions`           | `user_id`                                                 | normal                   | Supports user session review.                                      |
| `user_sessions`           | `store_id`                                                | normal                   | Supports store-level session review.                               |
| `user_sessions`           | `workstation_id`                                          | normal                   | Supports workstation session review.                               |
| `user_sessions`           | `session_token_digest`                                    | unique                   | Resolves current session securely.                                 |
| `user_sessions`           | `status`                                                  | normal                   | Supports active/locked session lists.                              |
| `user_sessions`           | `last_activity_at`                                        | normal                   | Supports inactivity cleanup/expiration.                            |
| `user_sessions`           | `locked_at`                                               | normal                   | Supports locked-session review.                                    |
| `user_sessions`           | `ended_at`                                                | normal                   | Supports cleanup/history review.                                   |
| `user_sessions`           | `ended_by_user_id`                                        | normal                   | Supports forced logout review.                                     |
| `workstation_assignments` | `workstation_id`                                          | normal                   | Supports workstation assignment review.                            |
| `workstation_assignments` | `assignment_token_digest`                                 | unique                   | Resolves browser cookie securely.                                  |
| `workstation_assignments` | `assigned_by_user_id`                                     | normal                   | Supports admin/audit review.                                       |
| `workstation_assignments` | `revoked_at`                                              | normal                   | Supports active/revoked filtering.                                 |
| `workstation_assignments` | `last_seen_at`                                            | normal                   | Supports stale assignment cleanup/review.                          |
| `workstation_assignments` | `workstation_id` where `revoked_at IS NULL`               | partial unique, optional | Enforces one active browser assignment per workstation if desired. |

---

# 6. Recommended Constraints

## 6.1 Constraint Table

| Table                     | Constraint                                                          | Notes                                                                   |
| ------------------------- | ------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| `audit_events`            | `actor_user_id` must reference an existing user                     | Use system user for automated/background events.                        |
| `audit_events`            | `event_name` must be present                                        | Prefer dot-separated event names.                                       |
| `audit_events`            | `occurred_at` must be present                                       | Store in UTC.                                                           |
| `audit_events`            | `event_details` defaults to `{}`                                    | Prefer `jsonb` in PostgreSQL.                                           |
| `audit_events`            | audit rows should be append-only                                    | Prevent normal UI edits/deletes.                                        |
| `permissions`             | `permission_key` must be present and unique                         | Stable seed-managed identifier.                                         |
| `permissions`             | `permission_key` should be dot-separated                            | Example: `setup.users.create`.                                          |
| `permissions`             | `permission_group` must be present                                  | Used for grouped setup screens.                                         |
| `permissions`             | inactive permissions should not grant access                        | Existing role links may remain for history.                             |
| `roles`                   | `role_key` must be present and unique                               | Stable seed-managed or admin-managed identifier.                        |
| `roles`                   | `name` must be present                                              | Human-readable display name.                                            |
| `roles`                   | system roles should not be deleted through normal UI                | Protect `super_administrator`.                                          |
| `roles`                   | inactive roles should not be newly assigned                         | Existing assignments may remain for history.                            |
| `roles`                   | inactive roles should not grant permissions                         | Enforce in authorization service.                                       |
| `role_permissions`        | `role_id` must reference an existing role                           | Required.                                                               |
| `role_permissions`        | `permission_id` must reference an existing permission               | Required.                                                               |
| `role_permissions`        | `role_id, permission_id` must be unique                             | Prevents duplicate permission assignment.                               |
| `stores`                  | `store_number` must be present and unique                           | Store as string for leading zeroes.                                     |
| `stores`                  | `store_number` should be numeric-only                               | If retained as business rule.                                           |
| `stores`                  | `country_code` should be uppercase two-character code               | Example: `US`, `CA`.                                                    |
| `stores`                  | `region_code` should be uppercase where present                     | Example: `MI`, `CA`, `ON`.                                              |
| `stores`                  | `email` should be normalized lowercase                              | Validate format at application/model layer.                             |
| `stores`                  | `website_url` should include protocol                               | Example: `https://www.shelfstack.demo`.                                 |
| `stores`                  | `time_zone` should be valid IANA time zone                          | Example: `America/New_York`.                                            |
| `stores`                  | inactive stores cannot be selected for new sessions/workstations    | Existing history may remain.                                            |
| `users`                   | `username` must be present and unique after normalization           | Choose uppercase or lowercase consistently.                             |
| `users`                   | `user_type` must be controlled                                      | Allowed values: `user`, `admin`, `system`.                              |
| `users`                   | `invalid_login_attempts >= 0`                                       | Default `0`.                                                            |
| `users`                   | interactive users require `password_digest`                         | System user is non-interactive.                                         |
| `users`                   | system user must have `interactive_login_enabled = false`           | Enforce in model/service logic.                                         |
| `users`                   | inactive users cannot log in                                        | Enforce in authentication service.                                      |
| `users`                   | PIN unlock is only for existing locked sessions                     | PIN cannot be used for initial login or permission escalation.          |
| `users`                   | last active interactive global administrator path must be protected | Prevent administrative lockout.                                         |
| `user_role_assignments`   | `user_id` must reference an existing user                           | Required.                                                               |
| `user_role_assignments`   | `role_id` must reference an existing role                           | Required.                                                               |
| `user_role_assignments`   | `scope_type` must be controlled                                     | Allowed values: `global`, `store`.                                      |
| `user_role_assignments`   | if `scope_type = 'global'`, `store_id` must be null                 | Scope rule.                                                             |
| `user_role_assignments`   | if `scope_type = 'store'`, `store_id` must be present               | Scope rule.                                                             |
| `user_role_assignments`   | duplicate active assignments should not be allowed                  | Use partial unique indexes if using PostgreSQL.                         |
| `user_role_assignments`   | inactive assignments should not grant permissions                   | Enforce in authorization service.                                       |
| `workstations`            | `store_id` must reference an existing store                         | Required.                                                               |
| `workstations`            | `workstation_type` must be controlled                               | Allowed values: `register`, `service_desk`, `back_office`, `receiving`. |
| `workstations`            | `workstation_number` should be numeric-only                         | Display as zero-padded string.                                          |
| `workstations`            | `workstation_number` must be unique within store                    | Unique on `store_id, workstation_number`.                               |
| `workstations`            | `workstation_code` must be unique within store                      | Unique on `store_id, workstation_code`.                                 |
| `workstations`            | inactive workstations cannot be assigned to browsers/sessions       | Enforce in service/model logic.                                         |
| `user_sessions`           | `user_id` must reference an existing user                           | Required.                                                               |
| `user_sessions`           | `session_token_digest` must be present and unique                   | Never store raw token.                                                  |
| `user_sessions`           | `status` must be controlled                                         | Allowed values: `active`, `locked`, `ended`, `expired`, `force_ended`.  |
| `user_sessions`           | `last_activity_at` must be present                                  | Used for inactivity tracking.                                           |
| `user_sessions`           | `locked_at` should be present when status is `locked`               | Enforce in lifecycle service.                                           |
| `user_sessions`           | `ended_at` should be present when status is terminal                | Terminal statuses: `ended`, `expired`, `force_ended`.                   |
| `user_sessions`           | `ended_by_user_id` should be present when status is `force_ended`   | Tracks authorized force logout.                                         |
| `user_sessions`           | terminal sessions should not return to active                       | Terminal statuses should be final.                                      |
| `workstation_assignments` | `workstation_id` must reference an existing workstation             | Required.                                                               |
| `workstation_assignments` | `assignment_token_digest` must be present and unique                | Never store raw cookie token.                                           |
| `workstation_assignments` | `assigned_at` must be present                                       | Required lifecycle timestamp.                                           |
| `workstation_assignments` | revoked assignments cannot be used for new sessions                 | `revoked_at` must be null for active assignment.                        |
| `workstation_assignments` | assigned workstation must be active when creating assignment        | Enforce in service/model logic.                                         |
| `workstation_assignments` | browser cookie should store only raw token                          | Server resolves token to assignment/workstation/store.                  |

---

# 7. Controlled Values

## 7.1 `users.user_type`

Allowed values:

```text
user
admin
system
```

## 7.2 `user_role_assignments.scope_type`

Allowed values:

```text
global
store
```

## 7.3 `workstations.workstation_type`

Allowed values:

```text
register
service_desk
back_office
receiving
```

## 7.4 `user_sessions.status`

Allowed values:

```text
active
locked
ended
expired
force_ended
```

---

# 8. Suggested PostgreSQL Constraints

## 8.1 User Role Assignment Scope Rule

```sql
ALTER TABLE user_role_assignments
ADD CONSTRAINT chk_user_role_assignments_scope_store
CHECK (
  (scope_type = 'global' AND store_id IS NULL)
  OR
  (scope_type = 'store' AND store_id IS NOT NULL)
);
```

---

## 8.2 User Session Status

```sql
ALTER TABLE user_sessions
ADD CONSTRAINT chk_user_sessions_status
CHECK (
  status IN ('active', 'locked', 'ended', 'expired', 'force_ended')
);
```

---

## 8.3 User Type

```sql
ALTER TABLE users
ADD CONSTRAINT chk_users_user_type
CHECK (
  user_type IN ('user', 'admin', 'system')
);
```

---

## 8.4 Workstation Type

```sql
ALTER TABLE workstations
ADD CONSTRAINT chk_workstations_workstation_type
CHECK (
  workstation_type IN ('register', 'service_desk', 'back_office', 'receiving')
);
```

---

## 8.5 Scope Type

```sql
ALTER TABLE user_role_assignments
ADD CONSTRAINT chk_user_role_assignments_scope_type
CHECK (
  scope_type IN ('global', 'store')
);
```

---

## 8.6 Invalid Login Attempts

```sql
ALTER TABLE users
ADD CONSTRAINT chk_users_invalid_login_attempts
CHECK (
  invalid_login_attempts >= 0
);
```

---

# 9. Seed Data

## 9.1 Seed Requirements

Seeds must be idempotent.

Running Phase 1 seeds multiple times should update existing records by stable keys rather than creating duplicates.

Stable keys:

| Entity      | Stable Key                                            |
| ----------- | ----------------------------------------------------- |
| User        | `username`                                            |
| Role        | `role_key`                                            |
| Permission  | `permission_key`                                      |
| Store       | `store_number`                                        |
| Workstation | `store_id + workstation_number` or `workstation_code` |

---

## 9.2 System User

| Field                       | Value                        |
| --------------------------- | ---------------------------- |
| `user_type`                 | `system`                     |
| `username`                  | `system`                     |
| `first_name`                | `ShelfStack`                 |
| `last_name`                 | `System Account`             |
| `display_name`              | `ShelfStack System`          |
| `clerk_number`              | null                         |
| `password_digest`           | Random/unusable secure value |
| `pin_digest`                | null                         |
| `interactive_login_enabled` | false                        |
| `active`                    | true                         |

Rules:

* System user cannot log in interactively.
* System user cannot be removed or inactivated through normal UI.
* System user is used for automated/background audit events.

---

## 9.3 Administrator User

| Field                       | Value                                        |
| --------------------------- | -------------------------------------------- |
| `user_type`                 | `admin`                                      |
| `username`                  | `admin`                                      |
| `first_name`                | `ShelfStack`                                 |
| `last_name`                 | `Administrator`                              |
| `display_name`              | `Administrator`                              |
| `clerk_number`              | `00001`                                      |
| `password`                  | `ChangeMe` + random three-digit number + `!` |
| `pin_digest`                | null                                         |
| `force_password_change`     | true                                         |
| `interactive_login_enabled` | true                                         |
| `active`                    | true                                         |

Generated admin password should be displayed once during seeding in development/demo environments.

---

## 9.4 Seed Stores

| Field             | Store 1                       | Store 2                       |
| ----------------- | ----------------------------- | ----------------------------- |
| `store_number`    | `001`                         | `002`                         |
| `store_group`     | `00001`                       | `00001`                       |
| `name`            | `ShelfStack Books - Main`     | `ShelfStack Books - Branch`   |
| `shopping_center` | `Downtown Shopping District`  | null                          |
| `address_line1`   | `123 Main St`                 | `999 First Ave`               |
| `city`            | `Bloomfield Hills`            | `Los Angeles`                 |
| `country_code`    | `US`                          | `US`                          |
| `region_code`     | `MI`                          | `CA`                          |
| `postal_code`     | `48302`                       | `90210`                       |
| `phone`           | `947-555-2665`                | `310-555-2665`                |
| `fax`             | `947-555-2660`                | `310-555-2660`                |
| `email`           | `store001@shelfstack.demo`    | `store002@shelfstack.demo`    |
| `website_url`     | `https://www.shelfstack.demo` | `https://www.shelfstack.demo` |
| `time_zone`       | `America/New_York`            | `America/Los_Angeles`         |
| `active`          | true                          | true                          |

---

## 9.5 Seed Workstations

Each seeded store receives:

| Workstation Type | Number | Code Pattern            | Name             |
| ---------------- | ------ | ----------------------- | ---------------- |
| `register`       | `001`  | `[store_number]-REG001` | `Front Register` |
| `service_desk`   | `001`  | `[store_number]-SVC001` | `Service Desk`   |

Examples:

```text
001-REG001
001-SVC001
002-REG001
002-SVC001
```

---

## 9.6 Seed Role

| Role Key              | Name                  | Notes                             |
| --------------------- | --------------------- | --------------------------------- |
| `super_administrator` | `Super Administrator` | System role with all permissions. |

The seeded admin user receives a global assignment to `super_administrator`.

---

## 9.7 Permission Groups

Minimum Phase 1 permission groups:

```text
setup
sessions
workstations
audit_events
```

---

## 9.8 Minimum Phase 1 Permissions

### Setup

```text
setup.access
setup.permissions.view
setup.roles.view
setup.roles.create
setup.roles.update
setup.roles.inactivate
setup.roles.reactivate
setup.roles.delete
setup.role_permissions.manage
setup.users.view
setup.users.create
setup.users.update
setup.users.inactivate
setup.users.reactivate
setup.users.delete
setup.user_roles.manage
setup.stores.view
setup.stores.create
setup.stores.update
setup.stores.inactivate
setup.stores.reactivate
setup.stores.delete
setup.workstations.view
setup.workstations.create
setup.workstations.update
setup.workstations.inactivate
setup.workstations.reactivate
setup.workstations.delete
```

### Sessions

```text
sessions.lock
sessions.unlock
sessions.force_end
```

### Workstations

```text
workstations.assign_browser
workstations.reassign_browser
```

### Audit Events

```text
audit_events.view
```

The `super_administrator` role receives all permissions.

---

# 10. Required Audit Events

## 10.1 Authentication and Password/PIN

```text
user.login
user.login_failed
user.logout
user.password_changed
user.password_reset
user.pin_changed
user.pin_reset
user.pin_cleared
```

## 10.2 Sessions

```text
session.locked
session.unlocked
session.expired
session.force_ended
```

## 10.3 Workstation Assignments

```text
workstation_assignment.created
workstation_assignment.revoked
workstation_assignment.reassigned
```

## 10.4 Roles and Permissions

```text
role.created
role.updated
role.inactivated
role.reactivated
role.deleted
role.permission_added
role.permission_removed
```

## 10.5 Users

```text
user.created
user.updated
user.inactivated
user.reactivated
user.deleted
user.role_added
user.role_removed
```

## 10.6 Stores

```text
store.created
store.updated
store.inactivated
store.reactivated
store.deleted
```

## 10.7 Workstations

```text
workstation.created
workstation.updated
workstation.inactivated
workstation.reactivated
workstation.deleted
```

---

# 11. Migration Notes

## 11.1 JSONB

Use `jsonb` for `audit_events.event_details` in PostgreSQL.

---

## 11.2 Token Digest Fields

Raw tokens must never be stored.

Digest fields:

```text
user_sessions.session_token_digest
workstation_assignments.assignment_token_digest
```

Rules:

* Required
* Unique
* Generated from secure random raw token
* Raw token stored only in client cookie/session
* Database stores digest only

---

## 11.3 Partial Unique Indexes

Use partial unique indexes for:

* Global role assignment uniqueness
* Store-scoped role assignment uniqueness
* Optional one-active-workstation-assignment-per-workstation rule
* Clerk number uniqueness where null is allowed

---

## 11.4 Foreign Keys

Add foreign keys for all explicit references.

Consider restrictive deletes for foundational records.

Preferred behavior:

* Prevent deleting users referenced by audit events.
* Prevent deleting stores referenced by workstations.
* Prevent deleting workstations referenced by sessions or assignments.
* Prefer inactivation over deletion.

---

## 11.5 Audit Rows

Although Rails timestamps include `updated_at`, audit rows should not be modified by normal application flows.

Application services should treat audit events as append-only.

---

# 12. Deferred Tables

The following tables are intentionally deferred to later phases:

```text
tax_categories
store_tax_rates
store_tax_category_rates
departments
categories
formats
catalog_items
catalog_item_identifiers
products
product_conditions
product_variants
inventory_ledger_entries
stock_balances
purchase_orders
sales
```

---

# 13. Phase 1 Data Model Definition of Done

The Phase 1 data model is complete when:

1. All Phase 1 migrations run cleanly.
2. All tables have appropriate primary keys.
3. All explicit references have foreign keys.
4. Required fields have null constraints.
5. Controlled values have model validations.
6. Practical database check constraints are added.
7. Recommended indexes are added.
8. Seed data is idempotent.
9. The system user is non-interactive.
10. The seeded admin user has global super administrator access.
11. User sessions store token digests, not raw tokens.
12. Workstation assignments store token digests, not raw tokens.
13. Audit events can store actor, event name, auditable record, context, timestamp, and JSONB details.
14. Authorization can resolve global and store-scoped role assignments.
15. Deletion/inactivation rules are documented and enforced where practical.
