# ShelfStack Implementation Guide

## Purpose

This document provides implementation guidance for ShelfStack developers.

It defines conventions for models, services, naming, authorization, audit logging, seed data, testing, and phase-based development.

This guide should be read alongside the roadmap, domain model, architecture document, and phase-specific specifications.

---

# 1. Development Principles

## 1.1 Build by phase

ShelfStack should be built in coherent phases.

Each phase should include:

* Migrations
* Models
* Validations
* Services
* Setup screens
* Permissions
* Audit events
* Seeds
* Tests
* Documentation updates

A phase is not complete when tables exist. A phase is complete when the behavior is implemented, permission-controlled, audited, seeded, and tested.

---

## 1.2 Keep controllers thin

Controllers should coordinate requests and responses.

Controllers should not contain complex business rules.

Use services for:

* Authorization, session lifecycle, workstation assignment, audit events
* Tax lookup, identifier normalization, SKU/name generation, metadata parsing
* Inventory posting, eligibility, tracking resolution, cost estimation
* Purchasing (receipt, RTV, order eligibility, vendor cost)
* POS (completion, void, tax/discount recalculation, tender validation, command registry)
* Stored value (issue, redeem, void, ledger post)
* Buyback (complete, void, pricing)
* Report query objects

See [architecture.md](architecture.md) and [AGENTS.md](../AGENTS.md) for the full service catalog.

---

## 1.3 Centralize business rules

Business rules that will be reused should live in services or domain objects.

Examples:

```text
Authorization.allowed?
TaxRateLookup.call
CatalogIdentifierService.add_identifier!
SkuGenerator.variant_sku
ProductNameRenderer.variant_name
AuditEvents.record!
```

Avoid duplicating the same rule across controllers, views, jobs, and models.

---

## 1.4 Prefer explicit lifecycle actions

Use explicit actions such as:

* inactivate
* reactivate
* lock
* unlock
* expire
* force_end
* revoke
* end_date

Do not silently mutate important state without a named workflow and audit event.

---

# 2. Naming Conventions

## 2.1 Product name

Use:

```text
ShelfStack
```

Do not use earlier alternate names in code, UI, or documentation unless referring to historical notes.

---

## 2.2 Booleans

Use Rails-style boolean names without `is_`.

Preferred:

```text
active
virtual
digital
large_print
new_condition
primary_identifier
system_role
```

Avoid:

```text
is_active
is_virtual
is_digital
is_large_print
is_new
```

---

## 2.3 Timestamps

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

Use `_on` for date-only fields.

Examples:

```text
effective_on
ends_on
```

---

## 2.4 Stable keys

Use `_key` for stable internal identifiers.

Examples:

```text
permission_key
role_key
format_key
condition_key
setting_key
```

Stable keys are useful for seeds, tests, and internal lookups.

---

## 2.5 Controlled type fields

Use explicit type fields rather than a column named `type`.

Examples:

```text
user_type
workstation_type
catalog_item_type
product_type
variation_type
identifier_type
scope_type
```

Avoid a plain `type` column unless intentionally using Rails STI.

---

# 3. Database Conventions

## 3.1 Use foreign keys

All explicit references should have foreign keys where practical.

Examples:

```text
users.default_store_id → stores.id
categories.department_id → departments.id
products.catalog_item_id → catalog_items.id
product_variants.product_id → products.id
```

---

## 3.2 Prefer inactivation over deletion

Most setup records should be inactivated once referenced.

Examples:

| Record          | Preferred Action Once Referenced |
| --------------- | -------------------------------- |
| User            | Inactivate                       |
| Store           | Inactivate                       |
| Department      | Inactivate                       |
| Category        | Inactivate                       |
| Tax Category    | Inactivate                       |
| Catalog Item    | Inactivate                       |
| Product         | Inactivate                       |
| Product Variant | Inactivate                       |
| Vendor          | Inactivate                       |

Hard deletion should be allowed only for unused records where no history would be affected.

---

## 3.3 Store money in cents

Prices should be stored in integer cents unless a later design explicitly requires higher-precision decimal costing.

Examples:

```text
products.list_price_cents
product_variants.selling_price_cents
```

---

## 3.4 Store percentage values in basis points

Percentages should be stored as integer basis points.

Examples:

```text
tax_rate_bps
default_margin_target_bps
default_supplier_discount_bps
default_list_price_factor_bps
```

Reference:

| Percent |   BPS |
| ------: | ----: |
|   0.00% |     0 |
|   6.00% |   600 |
|   9.50% |   950 |
|  40.00% |  4000 |
| 100.00% | 10000 |

---

## 3.5 Use JSONB intentionally

JSONB is acceptable for flexible metadata where full normalization is not yet justified.

Examples:

```text
creator_details
publisher_details
series_data
bisac_subject_data
genre_data
theme_data
target_audience_data
access_restriction_data
event_details
```

Do not use JSONB to avoid modeling clear business relationships such as users, roles, products, variants, inventory entries, or tax mappings.

---

# 4. Service Conventions

## 4.1 Authorization service

All permission checks should use a shared authorization service.

Conceptual interface:

```ruby
Authorization.allowed?(
  user: Current.user,
  permission_key: "setup.products.update",
  store: Current.store
)
```

Rules:

* User must be active.
* Permission must be active.
* Role assignment must be active.
* Role must be active.
* Global role assignments apply everywhere.
* Store role assignments apply only to matching store context.

---

## 4.2 Audit event service

Audit event creation should be centralized.

Conceptual interface:

```ruby
AuditEvents.record!(
  actor: Current.user,
  event_name: "product_variant.created",
  auditable: product_variant,
  source: nil,
  details: {}
)
```

Audit event service should automatically include:

* Actor user
* Store context
* Workstation context
* User session context
* Occurred timestamp

when available.

---

## 4.3 Current context

Use a request-scoped current context.

Expected attributes:

```ruby
Current.user
Current.store
Current.workstation
Current.user_session
Current.workstation_assignment
Current.time_zone
```

Clear current context between requests and tests.

---

## 4.4 Tax lookup service

Tax lookup should be centralized.

Conceptual interface:

```ruby
TaxRateLookup.call(
  store: store,
  tax_category: tax_category,
  date: date
)
```

Expected behavior:

* Return exactly one active applicable store tax rate.
* Raise/configuration-error if none exists.
* Raise/configuration-error if more than one applies.

---

## 4.5 Catalog identifier service

Catalog identifier behavior should be centralized.

Responsibilities:

* Normalize identifiers.
* Validate ISBN/UPC/EAN/GTIN check digits.
* Warn on invalid identifiers.
* Convert ISBN-10 to ISBN-13.
* Generate local identifiers.
* Enforce one active primary identifier.
* Normalize publisher number search values.

Conceptual interface:

```ruby
CatalogIdentifierService.add_identifier!(
  catalog_item: catalog_item,
  identifier_type: "isbn10",
  value: "0-123456-78-9"
)
```

---

## 4.6 SKU generator

SKU generation should be centralized.

Responsibilities:

* Generate product SKUs from catalog primary identifiers or local/manual values.
* Generate variant SKUs from product SKU plus condition/attribute components.
* Detect collisions.
* Normalize SKU components.
* Enforce unsuffixed variant rules.

Conceptual interface:

```ruby
SkuGenerator.product_sku(product)
SkuGenerator.variant_sku(product_variant)
```

---

## 4.7 Product name renderer

Product and variant name rendering should be centralized.

Responsibilities:

* Generate catalog-linked product names from catalog titles.
* Generate non-catalog product names from user input.
* Generate variant names from product name plus condition/attributes.
* Respect name overrides.
* Normalize whitespace.
* Avoid destructive title transformation.

Conceptual interface:

```ruby
ProductNameRenderer.product_name(product)
ProductNameRenderer.variant_name(product_variant)
```

---

## 4.8 Metadata parser

Metadata parsing should be centralized.

Responsibilities:

* Parse semicolon-separated creators.
* Parse creator roles in brackets.
* Parse `Surname, Forenames` where obvious.
* Parse subject headings with `[scheme/code]`.
* Default untagged subjects to local scheme.
* Preserve display strings.
* Store structured JSONB.

Conceptual interface:

```ruby
MetadataParser.parse_creators(input)
MetadataParser.parse_subjects(input)
```

---

# 5. Seed Data Conventions

## 5.1 Seeds must be idempotent

Running seeds multiple times must not duplicate records.

Use stable keys:

| Entity            | Stable Key                         |
| ----------------- | ---------------------------------- |
| User              | `username`                         |
| Role              | `role_key`                         |
| Permission        | `permission_key`                   |
| Store             | `store_number`                     |
| Department        | `department_number`                |
| Tax Category      | `name` or stable seed key if added |
| Category          | `department_id + name`             |
| Format            | `format_key`                       |
| Product Condition | `condition_key`                    |

---

## 5.2 Seeds should update known records

If a seed record already exists, update controlled fields as appropriate.

Avoid destructive changes in seeds unless intentionally documented.

---

## 5.3 Seeded admin password handling

Development/demo seeds may display a generated admin password once.

Production seeds should not expose credentials.

---

## 5.4 CSV classification reference data

Phase 2 and Phase 3B classification seeds load from `db/seeds/data/*.csv`. Validate files before seeding:

```bash
./dev/rails-docker rails shelfstack:seeds:validate
```

See [csv-seeds.md](implementation/csv-seeds.md) and [seed-data-spec.md](specifications/seed-data-spec.md).

---

# 6. Audit Conventions

## 6.1 Event naming

Use dot-separated event names.

Examples:

```text
user.login
session.locked
department.created
product_variant.sku_generated
catalog_item_identifier.isbn10_converted
```

## 6.2 Event details

Use JSONB event details for relevant metadata.

Examples:

```json
{
  "old_sku": "9780123456789",
  "new_sku": "9780123456789-SG"
}
```

## 6.3 Required context

Audit events should include:

* Actor
* Event name
* Auditable record where applicable
* Source record where applicable
* Store context where applicable
* Workstation context where applicable
* User session context where applicable
* Occurred timestamp

---

# 7. Testing Conventions

## 7.1 Each phase requires tests

Each phase should include:

* Model tests
* Service tests
* Authorization tests
* Request/controller tests
* System tests where useful
* Audit event tests
* Seed tests

---

## 7.2 Security workflows need regression tests

Always test:

* Login
* Failed login
* Inactive users
* System user login rejection
* Permission checks
* Store-scoped permissions
* Super administrator protection
* Session locking
* Forced session termination

---

## 7.3 Setup workflows need audit tests

For setup records, test:

* create
* update
* inactivate
* reactivate
* delete when allowed
* delete blocked when referenced
* audit event creation

---

## 7.4 Data generation services need service tests

Test:

* Tax lookup
* Identifier normalization
* Check digit validation
* ISBN-10 conversion
* Local identifier generation
* SKU generation
* Name rendering
* Metadata parsing

---

# 8. UI Implementation Guidance

## 8.1 Setup screens

Setup screens should generally support:

* list
* search/filter
* detail
* create
* edit
* inactivate
* reactivate
* delete when allowed
* audit timeline

---

## 8.2 Dynamic fields

Dynamic forms should show fields relevant to the selected record type without making the database overly rigid.

Examples:

* `catalog_item_type` controls catalog metadata field display.
* `variation_type` controls variant attribute fields.
* `inventory_behavior` controls future inventory/POS behavior.

---

## 8.3 Real-time calculation

Where practical, forms should preview derived values as the user enters data.

Examples:

* Department number normalization
* Tax rate percentage display from basis points
* Product SKU generation
* Variant SKU generation
* Variant name rendering
* Used condition price factor calculation

---

# 9. Phase Completion Checklist

A phase is complete only when:

1. Migrations run cleanly.
2. Models and validations are implemented.
3. Required services are implemented.
4. Setup screens are permission-controlled.
5. Seeds are idempotent.
6. Audit events are created.
7. Tests pass.
8. Documentation is updated.
9. Known deferred items are documented.

---

# 10. Current Service Conventions

Business rules live in `app/services/`. Prefer namespaced modules matching the domain (`Inventory::`, `Pos::`, `Purchasing::`, `StoredValue::`, `Buybacks::`).

## 10.1 Inventory

* Mutate inventory only through `Inventory::Post` and `Inventory::BalanceUpdater`.
* Gate eligibility with `Inventory::Eligibility` / `Inventory::TrackingResolver` — not raw `inventory_behavior` checks in controllers.
* Posted postings and ledger entries are immutable; void/adjustment workflows create reversing or offsetting entries.

## 10.2 POS

* Complete and void through `Pos::CompleteTransaction` / `Pos::VoidTransaction`.
* Recalculate tax and discounts via `Pos::TaxRecalculator` and `Pos::DiscountRecalculator`.
* Inventory posts only from completion/void services, not from controllers.
* **Command routing:** evolve `Pos::CommandBarRouter` into `Pos::CommandRegistry` (Phase 10-C). Registry holds permission checks, valid states, alias normalization, and handler targets. Stimulus submits input; **Ruby resolves intent**.

## 10.3 Stored value

* Append-only `stored_value_ledger_entries`; account row locked on post.
* Negative balances not allowed. POS redemption saves `min(amount, balance)`.

## 10.4 Interaction (Phase 10)

* Use shared modal/drawer partials and Turbo targets from [view-contracts.md](specifications/view-contracts.md).
* Stimulus: focus trap, restore, dirty guard, overlay stack — not business rules.
* Server-rendered modal/drawer bodies for authoritative form state.

---

# 11. Deferred Complexity Policy

ShelfStack should avoid overbuilding too early.

Still deferred or out of scope:

* Fully normalized contributors and subjects
* Product variant aliases and product price history tables
* Inventory location balances, transfers, cycle counts
* Offline POS
* GL export and financial postings (Phase 9c)
* Full command language outside POS/items workspaces

**No longer deferred** (implemented — do not treat as future work in new code):

* Vendor-product sourcing and PO/receiving
* Inventory ledger and balances
* POS transactions, snapshots, and business dates
* External bibliographic lookup (ISBNdb, Phase 6.5)
* Structured POS discounts and tax exceptions (Phase 8.5)

When deferring new work, document what is deferred, why, and which phase owns it.
