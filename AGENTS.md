# AGENTS.md

## Purpose

This file provides guidance for AI coding agents and developer assistants working on ShelfStack.

Agents should follow the project documentation, preserve the domain model, and avoid making broad architectural changes without clear justification.

ShelfStack is a bookstore-focused catalog, inventory, stock, and point-of-sale management system. It is being developed in phases, beginning with foundation, classification/tax setup, and catalog/product/variant modeling.

---

# Project Overview

ShelfStack is designed for independent bookstores and similar retailers that sell both metadata-heavy items and ordinary retail products.

Examples of metadata-heavy items:

* Books
* Periodicals
* Recorded music
* Videorecordings
* Audiobooks
* eBooks
* Calendars
* Maps
* Games

Examples of simpler/non-catalog items:

* Sidelines
* Gifts
* Food and beverage items
* Services
* Donations
* Gift cards
* Event tickets

ShelfStack separates descriptive catalog metadata from store-facing products and sellable SKUs.

Core model:

```text
Catalog Item → Product → Product Variant/SKU → Inventory/POS Activity
```

---

# Primary Documentation

Before implementing or changing major behavior, review the relevant documents.

## General Documents

```text
docs/overview.md
docs/domain-model.md
docs/architecture.md
docs/roadmap.md
docs/implementation-guide.md
docs/glossary.md
docs/schema-reference.md
```

## Phase 1 Documents

```text
docs/roadmap/phase-1-foundation.md
docs/specifications/phase-1-foundation-spec.md
docs/specifications/phase-1-data-model.md
docs/specifications/phase-1-test-plan.md
```

## Phase 2 Documents

```text
docs/roadmap/phase-2-departments-categories-taxes.md
docs/specifications/phase-2-classification-and-tax-spec.md
docs/specifications/phase-2-data-model.md
docs/specifications/phase-2-test-plan.md
```

## Phase 3 Documents

```text
docs/roadmap/phase-3-catalog-products-variants.md
docs/specifications/phase-3-catalog-products-variants-spec.md
docs/specifications/phase-3-data-model.md
docs/specifications/phase-3-test-plan.md
```

If documentation and implementation disagree, flag the discrepancy rather than silently changing the domain model.

---

# Current Development Priority

Development follows the phase roadmap.

## Phase 1: Foundation — **Complete**

Phase 1 was completed on 2025-06-10. See [docs/implementation/phase-1-completion.md](docs/implementation/phase-1-completion.md) for deliverables, verification steps, and known gaps.

Do not remove or bypass Phase 1 protections (super administrator, system user, audit events) when extending the application.

## Phase 2: Departments, Categories, and Taxes — **Active**

Focus:

* Departments
* Categories
* Tax categories
* Store tax rates
* Store tax category rates
* Effective-dated tax lookup

## Phase 3: Catalog, Products, and Product Variants

Focus:

* Formats
* Catalog items
* Catalog item identifiers
* Products
* Product conditions
* Product variants
* Display locations
* Store display locations
* Vendors
* SKU generation
* Name rendering

Do not jump ahead to inventory, purchasing, receiving, POS, or reporting tables unless the user explicitly asks to design that phase.

---

# Architectural Principles

## Keep controllers thin

Controllers should coordinate requests and responses. They should not contain complex business rules.

Use services for:

* Authorization
* Audit logging
* Session lifecycle
* Workstation assignment
* Tax lookup
* Identifier normalization
* ISBN conversion
* Local identifier generation
* SKU generation
* Product/variant name rendering
* Metadata parsing

## Centralize business rules

Do not duplicate domain rules across controllers, models, views, and jobs.

Examples of expected service areas:

```text
Authorization
AuditEvents
SessionLifecycle
WorkstationAssignment
TaxRateLookup
CatalogIdentifierService
SkuGenerator
ProductNameRenderer
MetadataParser
```

## Preserve auditability

Important setup, security, catalog, product, SKU, identifier, and lifecycle changes should create audit events.

Do not implement silent destructive changes.

## Prefer inactivation over deletion

Once records are referenced, prefer:

```text
active = false
```

over hard deletion.

Examples:

* Users
* Stores
* Roles
* Departments
* Categories
* Tax categories
* Catalog items
* Products
* Product variants
* Vendors

Hard delete should only be allowed for unused records where no history would be affected.

---

# Naming Conventions

## Product name

Use:

```text
ShelfStack
```

Do not use old or alternate names such as ShelfSense or BookSense.

## Booleans

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

## Stable keys

Use `_key` for stable internal identifiers.

Examples:

```text
permission_key
role_key
format_key
condition_key
```

## Dates and times

Use `_at` for datetimes:

```text
created_at
updated_at
last_login_at
locked_at
ended_at
```

Use `_on` for dates:

```text
effective_on
ends_on
```

## Controlled type fields

Avoid a plain `type` column unless intentionally using Rails single-table inheritance.

Use explicit names:

```text
user_type
scope_type
workstation_type
catalog_item_type
product_type
variation_type
identifier_type
```

---

# Database Conventions

## Money

Store prices as integer cents.

Examples:

```text
products.list_price_cents
product_variants.selling_price_cents
```

## Percentages

Store percentages as integer basis points.

Examples:

```text
tax_rate_bps
default_margin_target_bps
default_supplier_discount_bps
default_list_price_factor_bps
```

Reference:

| Percent | Basis Points |
| ------: | -----------: |
|   0.00% |            0 |
|   6.00% |          600 |
|  40.00% |         4000 |
| 100.00% |        10000 |

## JSONB

Use JSONB for flexible metadata where full normalization is intentionally deferred.

Examples:

```text
event_details
creator_details
publisher_details
series_data
bisac_subject_data
genre_data
theme_data
target_audience_data
access_restriction_data
```

Do not use JSONB for clear business relationships that should be modeled relationally.

## Foreign keys

Use foreign keys for explicit references.

Examples:

```text
users.default_store_id → stores.id
categories.department_id → departments.id
catalog_items.format_id → formats.id
products.catalog_item_id → catalog_items.id
product_variants.product_id → products.id
```

---

# Domain Rules to Preserve

## Phase 1 Rules

* System user cannot log in interactively.
* Role assignments may be global or store-scoped.
* Store-scoped role assignments apply only in the matching store context.
* Workstation context is resolved server-side from a secure token.
* Browser stores raw workstation token; database stores digest.
* User sessions are persisted.
* Session statuses are controlled: `active`, `locked`, `ended`, `expired`, `force_ended`.
* Terminal sessions cannot return to active.
* Audit events are append-only in normal behavior.
* At least one active interactive global super administrator path must remain.

## Phase 2 Rules

* Departments are global.
* Categories are global and belong to departments.
* Department numbers are strings, three digits, numeric-only, and zero-padded.
* Categories provide defaults for future sellable items.
* Tax categories describe item taxability.
* Store tax rates belong to stores.
* Store tax category rates are effective-dated mappings.
* For a store, tax category, and date, tax lookup must return exactly one applicable active rate.
* Overlapping active tax mappings for the same store/tax category/date are not allowed.

## Phase 3 Rules

* Catalog items are metadata records, not sellable SKUs.
* Products are store-facing product groupings.
* Product variants are actual sellable SKUs.
* Every catalog item must have at least one active identifier.
* Every catalog item must have exactly one active primary identifier.
* ISBN-10 identifiers are saved as non-primary and converted to ISBN-13 primary identifiers.
* Invalid standard identifiers may be saved, but the user must be warned.
* Publisher numbers preserve display value and store normalized searchable value.
* Product SKU is required and unique.
* Catalog-linked product SKU defaults from catalog primary identifier.
* Variant SKU is required and unique.
* New condition has no SKU suffix.
* Condition variants append condition SKU component.
* Variable variants append attribute 1 SKU component.
* Matrix variants append attribute 1 and attribute 2 SKU components.
* Product and variant names are generated conservatively and may be overridden.
* Product is not sellable until it has at least one active variant.

---

# Testing Expectations

Every meaningful change should include or update tests.

## Test categories

Use tests for:

* Models
* Validations
* Services
* Authorization
* Request/controller behavior
* System flows where useful
* Audit events
* Seeds

## Always test

* Permission checks
* Store-scoped access
* Audit event creation
* Seed idempotency
* Controlled value validation
* Deletion/inactivation rules
* Security-sensitive workflows

## Phase-specific test focus

### Phase 1

* Login/logout
* Failed login attempts
* Session locking/unlocking
* Forced session termination
* Workstation assignment
* Super administrator protection

### Phase 2

* Department number normalization
* Tax rate basis points
* Effective-dated tax lookup
* Tax mapping overlap prevention
* Category defaults

### Phase 3

* Identifier normalization
* Check digit validation
* ISBN-10 to ISBN-13 conversion
* Local identifier generation
* SKU generation
* Variant name rendering
* Creator/subject metadata parsing

---

# Seed Data Rules

Seeds must be idempotent.

Running seeds multiple times should not duplicate records.

Use stable keys:

| Entity            | Stable Key          |
| ----------------- | ------------------- |
| User              | `username`          |
| Role              | `role_key`          |
| Permission        | `permission_key`    |
| Store             | `store_number`      |
| Department        | `department_number` |
| Format            | `format_key`        |
| Product Condition | `condition_key`     |

When updating seed files, prefer upsert-style behavior based on stable keys.

---

# Audit Event Guidelines

Use dot-separated event names.

Examples:

```text
user.login
session.locked
department.created
catalog_item_identifier.isbn10_converted
product_variant.sku_generated
product_variant.name_regenerated
```

Audit events should include:

* Actor
* Event name
* Auditable record where applicable
* Source record where applicable
* Store context where applicable
* Workstation context where applicable
* User session context where applicable
* JSONB event details
* UTC timestamp

---

# UI Guidelines

## Setup screens

Setup screens should generally include:

* List
* Search/filter
* Detail
* Create
* Edit
* Inactivate
* Reactivate
* Delete only when allowed
* Audit timeline

## Dynamic forms

Use dynamic forms where the domain calls for it.

Examples:

* `catalog_item_type` controls catalog metadata fields shown.
* `variation_type` controls variant attribute fields.
* `inventory_behavior` controls future POS/inventory behavior.
* Tax mapping screens should preview applicable date ranges.
* SKU screens should preview generated SKUs.

## Real-time previews

Where practical, show previews for:

* Department number normalization
* Tax rate percentage from basis points
* Product SKU
* Variant SKU
* Product name
* Variant name
* Used condition price factor

---

# Do Not Do Without Confirmation

Do not introduce these unless explicitly requested:

* Inventory ledger tables
* Stock balance tables
* POS transaction tables
* Purchase order tables
* Receiving tables
* Vendor-product sourcing tables
* Product price history tables
* Fully normalized contributor tables
* Fully normalized subject tables
* External bibliographic API integration
* Offline POS implementation
* Major authentication library changes
* Major database engine changes
* New framework/language choices

Flag these as future-phase work instead.

---

# Preferred Development Sequence for a Feature

1. Read relevant roadmap/spec/data-model/test-plan.
2. Confirm the phase and scope.
3. Add or update migration.
4. Add or update model and validations.
5. Add or update service objects.
6. Add or update authorization checks.
7. Add or update audit events.
8. Add or update setup UI.
9. Add or update seeds.
10. Add or update tests.
11. Update documentation.

---

# Definition of Done

A feature is not done until:

1. It matches the relevant specification.
2. Migrations run cleanly.
3. Models and services are implemented.
4. Authorization is enforced.
5. Audit events are created where required.
6. Seeds are idempotent where applicable.
7. Tests pass.
8. Documentation is updated.
9. Deferred behavior is explicitly noted.

---

# Agent Behavior

When working on ShelfStack:

* Preserve the domain model.
* Make small, explainable changes.
* Prefer explicit service objects for business rules.
* Avoid unrequested scope expansion.
* Do not silently rename established concepts.
* Do not bypass authorization or audit requirements.
* Do not remove historical data paths.
* Ask for clarification when a change affects phase scope or core architecture.
* If a requested change conflicts with existing documentation, identify the conflict clearly.
