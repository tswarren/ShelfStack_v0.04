# ShelfStack Architecture

## Purpose

This document explains the intended technical architecture for ShelfStack at a high level.

It describes the major application layers, services, conventions, and architectural principles that should guide implementation.

---

# 1. Architectural Goals

ShelfStack should be built as a maintainable Rails application with clear separation between:

* Data models
* Business rules
* Authorization
* Audit logging
* Request/session context
* Setup workflows
* Product/catalog logic
* Future inventory/POS services

The application should avoid placing complex business rules directly in controllers.

---

# 2. Major Layers

## 2.1 Models

Models define database-backed records and basic validation.

Examples:

* `User`
* `Role`
* `Store`
* `Department`
* `Category`
* `CatalogItem`
* `Product`
* `ProductVariant`

Models may include simple validations and associations, but complex workflows should be handled by services.

---

## 2.2 Services

Services encapsulate business workflows.

Recommended service areas:

| Service Area           | Responsibility                                                   |
| ---------------------- | ---------------------------------------------------------------- |
| Authorization          | Permission resolution and store scope checks.                    |
| Audit Events           | Creating consistent audit events with actor/context.             |
| Current Context        | Managing user/store/workstation/session context.                 |
| Session Lifecycle      | Login, logout, lock, unlock, expiration, force-end.              |
| Workstation Assignment | Browser-to-workstation token assignment and resolution.          |
| Tax Lookup             | Resolving effective store tax rates.                             |
| Catalog Identifiers    | Normalization, validation, local generation, ISBN-10 conversion. |
| Metadata Parsing       | Creator and subject parsing into JSONB.                          |
| Product Naming         | Product and variant name generation.                             |
| SKU Generation         | Product and variant SKU generation.                              |

### Phase 1 implemented services (2025-06-10)

These services exist in `app/services/` and are used by the Phase 1 application:

| Service | File | Responsibility |
| ------- | ---- | -------------- |
| Authorization | `authorization.rb` | Permission resolution and store scope |
| AuditEvents | `audit_events.rb` | Audit event creation with context |
| AuthenticationService | `authentication_service.rb` | Login validation and lockout |
| SessionLifecycle | `session_lifecycle.rb` | Login, logout, lock, unlock, expiration |
| WorkstationAssignmentService | `workstation_assignment_service.rb` | Browser workstation assignment |
| UserRoleAssignmentService | `user_role_assignment_service.rb` | User role assign/remove |
| SuperAdministratorProtection | `super_administrator_protection.rb` | Admin lockout prevention and recovery |
| TokenDigest | `token_digest.rb` | Secure token digest helpers |

Request context: `app/models/current.rb` (`CurrentAttributes`).

Future phases will add Tax Lookup, Catalog Identifiers, Metadata Parsing, Product Naming, and SKU Generation services per the table above.

---

# 3. Current Context

ShelfStack should use a shared request context.

In Rails, this can be implemented with `CurrentAttributes`.

Expected context:

```ruby
Current.user
Current.store
Current.workstation
Current.user_session
Current.workstation_assignment
Current.time_zone
```

This context should be set once per request and used by:

* Controllers
* Services
* Audit event creation
* Authorization checks
* Time zone display
* Setup workflows

---

# 4. Authorization Architecture

Authorization should be resolved through a shared service.

Conceptual interface:

```ruby
Authorization.allowed?(
  user: user,
  permission_key: "setup.users.update",
  store: store
)
```

Rules:

1. User must be active.
2. Permission must be active.
3. Role assignment must be active.
4. Role must be active.
5. Global role assignments apply across all stores.
6. Store role assignments apply only in matching store context.
7. System user is not valid for interactive UI authorization.

Controllers should ask the authorization service rather than inspecting roles directly.

---

# 5. Audit Event Architecture

Audit event creation should be centralized.

A typical audit event should include:

* Actor user
* Event name
* Auditable record
* Optional source record
* Store context
* Workstation context
* User session context
* Timestamp
* JSONB event details

Conceptual interface:

```ruby
AuditEvents.record!(
  actor: Current.user,
  event_name: "product_variant.created",
  auditable: product_variant,
  details: {}
)
```

Audit events should be append-only in normal application behavior.

---

# 6. Session and Workstation Architecture

ShelfStack uses persisted user sessions and durable workstation assignments.

## Workstation assignment

Browser stores raw assignment token.

Database stores token digest.

Server resolves:

```text
browser token → workstation_assignment → workstation → store → time_zone
```

The browser must not be trusted to supply store, workstation, or permission data.

## User session

Login creates a persisted `user_sessions` record.

Session statuses:

```text
active
locked
ended
expired
force_ended
```

Session lock state should be checked on authenticated requests and through a lightweight polling endpoint.

---

# 7. Tax Architecture

Tax setup is separated into three concepts:

| Concept                 | Meaning                                                            |
| ----------------------- | ------------------------------------------------------------------ |
| Tax Category            | What kind of item this is for tax purposes.                        |
| Store Tax Rate          | A tax rate available at a store.                                   |
| Store Tax Category Rate | Effective-dated mapping of store + tax category to store tax rate. |

Tax lookup is implemented in `app/services/tax_rate_lookup.rb`.

Conceptual interface:

```ruby
TaxRateLookup.call(
  store: store,
  tax_category: tax_category,
  date: date
)
```

Returns the applicable `StoreTaxRate`. Raises `TaxRateLookup::MissingRateError` or `TaxRateLookup::AmbiguousRateError` when setup is incomplete or ambiguous.

---

# 8. Catalog Identifier Architecture

Catalog identifier behavior should be centralized.

Responsibilities:

* Normalize standard identifiers.
* Validate check digits.
* Warn on invalid values.
* Convert ISBN-10 to ISBN-13.
* Generate local identifiers.
* Enforce one active primary identifier.
* Preserve publisher number display values.
* Store normalized publisher number index values.

Conceptual interface:

```ruby
CatalogIdentifierService.add_identifier!(
  catalog_item: catalog_item,
  identifier_type: "isbn10",
  value: "0-123456-78-9"
)
```

---

# 9. Product and Variant Architecture

Products and variants should be generated and maintained through services rather than ad hoc controller logic.

## Product naming

Catalog-linked product names default from catalog item titles.

Non-catalog product names are user-entered.

Name overrides are supported.

## Variant naming

Variant names are generated from:

* Product name
* Condition short name
* Attribute values

Name overrides are supported.

## SKU generation

Product SKU is the base SKU.

Variant SKU is derived from:

* Product SKU
* Condition SKU component
* Attribute SKU components

Conceptual services:

```ruby
ProductNameRenderer.product_name(product)
ProductNameRenderer.variant_name(product_variant)

SkuGenerator.product_sku(product)
SkuGenerator.variant_sku(product_variant)
```

---

# 10. Metadata Parsing Architecture

ShelfStack allows practical metadata entry through semicolon-separated strings.

Creator example:

```text
Smith, John [author]; Doe, Jane [actor; director]
```

Subject example:

```text
HISTORY > General [BISAC/HIS000000]; Comedy [local]
```

The application should preserve the display string and parse structured JSONB.

Parsing should be conservative. It should not over-infer complicated personal names or subject schemes.

---

# 11. Time Zone Architecture

All persisted timestamps should be stored in UTC.

User-facing timestamps should display using the active store’s time zone.

If no active store context exists, use the application default time zone.

Future POS and inventory workflows may also require store-local business dates, but that is deferred.

---

# 12. Deletion and Inactivation

ShelfStack should generally prefer inactivation over deletion once records are referenced.

Examples:

| Record          | Preferred Lifecycle            |
| --------------- | ------------------------------ |
| User            | Inactivate                     |
| Store           | Inactivate                     |
| Department      | Inactivate                     |
| Category        | Inactivate                     |
| Catalog Item    | Inactivate                     |
| Product         | Inactivate                     |
| Product Variant | Inactivate                     |
| Tax Rate        | Inactivate or end-date mapping |
| Audit Event     | Append-only, no normal delete  |

Hard deletion should be limited to unused setup records.

---

# 13. Testing Principles

Security and setup behavior should be tested heavily.

Core test areas:

* Authentication
* Authorization
* Store-scoped permissions
* Session lifecycle
* Workstation assignment
* Audit event creation
* Tax lookup
* Catalog identifier normalization
* SKU generation
* Name rendering
* Seed idempotency

---

# 14. Future Architecture Considerations

Future phases should add:

* Inventory ledger
* Stock balances
* Vendor sourcing
* Purchase orders
* Receiving
* POS transactions
* Returns
* Stock transfers
* Inventory valuation
* Reporting
* GL/accounting export

These future domains should build on the product variant as the sellable/stock-tracked unit.
