# ShelfStack Security Overview

High-level security model. Phase-specific permission keys and workflows live in phase specs and [AGENTS.md](../AGENTS.md).

---

## Authentication

* Interactive users authenticate with username/password (`has_secure_password`, bcrypt).
* **System user** cannot log in interactively; used for background/system actions only.
* Failed login attempts are tracked; accounts may lock per Phase 1 rules.
* Self-service password and PIN changes require confirmation fields.

---

## Authorization

* Permissions are seed-managed capabilities (`permission_key`).
* Roles bundle permissions; users receive **global** or **store-scoped** role assignments.
* Store-scoped assignments apply only when `Current.store` matches.
* Controllers and services call `Authorization.allowed?` — do not inspect roles directly in views.
* At least one active interactive global super administrator path must remain.

See `app/services/authorization.rb` and phase test plans for permission coverage.

---

## Sessions and workstation context

* **User sessions** are persisted with statuses: `active`, `locked`, `ended`, `expired`, `force_ended`.
* Inactivity **locks** the session; it does not force password change or full re-login.
* Terminal sessions cannot return to `active`.
* **Workstation assignment:** browser stores raw token; database stores digest only.
* Server resolves store/workstation from assignment — never trust client-supplied store or workstation IDs for authorization.

See [operations/foundation-runbook.md](operations/foundation-runbook.md) for operational procedures.

---

## PIN and onboarding

* Interactive users must set a PIN after login; navigation is gated until `pin_digest` is present.
* First-login flows: workstation assignment → login → password change (when required) → PIN setup.

---

## POS authorization

* Register operations require `pos.*` permissions (access, line add, settlement, void, discounts, tax exceptions, stored value tenders, etc.).
* **Supervisor authorization** (`pos_authorizations`) gates sensitive actions (inactive sell, no-receipt return complete, overrides).
* POS completion validates tenders, stored value balances, and readiness before posting.

---

## Audit

* Important security, setup, catalog, inventory, POS, and stored-value changes create **append-only audit events**.
* Events include actor, event name, auditable/source records, store/workstation/session context, and JSONB details.
* Use dot-separated event names (for example `user.login`, `pos.transaction.completed`).

See `app/services/audit_events.rb`.

---

## Data integrity

* Inventory and stored-value ledgers are append-only in normal operation; voids reverse via linked entries.
* Posted POS transactions and inventory postings are immutable; void workflows create reversal records.

---

## Related documents

```text
docs/specifications/phase-1-foundation-spec.md
docs/specifications/phase-1-test-plan.md
docs/specifications/phase-6-pos-foundation-spec.md
docs/operations/foundation-runbook.md
AGENTS.md  (Phase 1 and POS rules)
```
