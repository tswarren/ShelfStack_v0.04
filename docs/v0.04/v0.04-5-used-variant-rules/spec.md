# v0.04-5 Used Variant Rules — Functional Specification

## Status

**In review** — see [v0.04-5-completion.md](../../implementation/v0.04-5-completion.md). *(Mark **Complete** after merge to `main`.)*

## Job

Make the behavior of **new vs used product variants** explicit, consistent, and enforceable across item setup, buybacks, POS, customer requests, purchasing/TBO, and inventory-facing UI.

v0.04-5 does **not** introduce the v0.04 demand model. It clarifies how current product variants behave when their condition represents used, damaged, collectible, remainder, or other non-new stock.

```text
Product
  → Product Variant
      → Condition
          → new / used-like / buyback-eligible / orderable behavior
```

## Purpose

ShelfStack already treats `product_variants` as the operational grain. v0.04-5 defines the rules that follow from a variant’s condition:

* Can this variant be sold?
* Can it be bought back?
* Can it be customer-reserved?
* Can it be vendor-ordered?
* Can it appear on purchase orders or TBO queues?
* Can it be replenished automatically?
* How should staff understand used availability?

The goal is to remove hidden assumptions such as “all variants can be ordered,” “used copies behave like new SKUs,” or “unavailable used demand should become a new-item order.”

---

## Source documents

```text
docs/design/VERSION_0.04.md
docs/roadmap/v0.04-delivery-roadmap.md
docs/v0.04/README.md
docs/v0.04/v0.04-4-variant-grain-wire-through/spec.md
docs/implementation/v0.04-4-completion.md
docs/specifications/phase-7a-customer-demand-spec.md
docs/specifications/phase-8.5-3a-order-handling-readiness-spec.md
AGENTS.md
```

---

## Baseline (pre–v0.04-5)

Partial rules already exist from Phase 8.5-3 and buyback work. v0.04-5 **consolidates and closes gaps** — it is not greenfield.

| Area | Current behavior | v0.04-5 target |
| ---- | ---------------- | -------------- |
| PO add/submit | Used variants blocked via `Purchasing::OrderEligibilityResolver` | Preserve; delegate to centralized policy |
| Item-page vendor warnings | Skipped for used via `vendor_sourcing_warnings_applicable?` | Preserve; improve used-specific messaging |
| Variant create default `orderable` | `ProductVariants::OrderabilityDefaults` → false for non-new | Preserve; enforce on edit/backfill |
| TBO create/queue | Used variants **allowed** at `:tbo` context; blocked only at PO build | **Tighten** — block or exclude at TBO create/queue |
| Customer special orders | No used-variant guard on `CustomerRequests::StartFromItem` | Block vendor-style special order for used variants |
| Buyback variant SKU | `FindOrCreateGradedUsedVariant` may still use legacy `SkuGenerator` suffix SKUs | Use `ProductVariants::SkuAllocator` (211 segment) per v0.04-2 |
| Policy layer | Logic duplicated across resolver, orderability defaults, buyback eligibility | Centralize in `ProductVariants::OperationalPolicy` (or equivalent) |

---

## Hard gates

1. **Product variant remains the operational grain.**

   * Do not move used behavior to `products`.
   * Do not introduce a separate “used item” table.

2. **Used variants are not vendor-orderable.**

   * Used stock may be bought back, received through intake, manually adjusted, sold, or reserved if on hand.
   * Used variants must not be added to normal vendor purchase orders or buildable TBO replenishment queues.

3. **Unavailable used demand does not auto-convert to new-item vendor demand.**

   * Staff may choose to sell/order a new variant separately.
   * The system must not silently substitute new for used.

4. **Do not implement the v0.04 demand foundation.**

   * `demand_lines`, `demand_allocations`, sourcing attempts, and allocation redesign remain v0.04-6+.

5. **Do not redesign buyback pricing.**

   * v0.04-5 may validate and normalize used variant behavior, but a full buyback valuation overhaul is out of scope.

6. **Do not redesign POS lookup.**

   * v0.04-2 lookup order remains authoritative.

7. **Do not introduce copy-level serial labels.**

   * Used variants are still variant-level SKUs, not individually serialized copies.

---

## Implementation path (schema)

**Default:** derive operational behavior from `ProductCondition` + `product_variants.orderable` (+ existing product type gates). Do **not** add `vendor_orderable`, `customer_reservable`, or `replenishment_strategy` columns unless a slice proves derivation is insufficient.

The delivery roadmap mentions those names as **design vocabulary**; v0.04-5 expresses them as policy methods, not new tables.

Optional narrowly scoped additions (only if needed):

* Condition-level behavior flag(s) when `new_condition` alone is insufficient (e.g. explicit remainder orderability).
* Data backfill migration to correct `orderable: true` on used-like variants.

No new inventory or demand tables in v0.04-5.

---

## Definitions

### New variant

A product variant whose condition has `new_condition: true`.

Examples in seeds: `new`, `signed_copy`, `special_edition`, `remainder`.

Expected behavior:

```text
vendor_orderable: yes, if product/variant setup allows
customer-reservable: yes
sellable: yes
buyback-eligible: no (unless condition explicitly configured otherwise)
normal PO eligible: yes, when orderable and otherwise eligible
```

### Used variant

A product variant whose condition has `new_condition: false` and represents a used copy.

Expected behavior:

```text
vendor_orderable: no
customer-reservable: yes, when stock is available or hold workflow applies
sellable: yes
buyback-eligible: yes, if condition.buyback_eligible
normal PO eligible: no
TBO replenishment eligible: no
```

### Used-like variant

A non-new condition that behaves like used for **vendor-ordering and replenishment** purposes.

Examples (seed keys today): `used_like_new`, `used_very_fine`, `used_fine`, `used_good`, `used_poor`, `used_ex_library`, `used_book_club`.

Future/setup examples (not assumed seed keys): Damaged, Reading Copy, Collectible, Ex-library variants under other names.

Used-like variants may be sellable and reservable, but they are not normal vendor-orderable variants.

### Remainder / bargain variant

A variant sold as discounted new stock, not necessarily used.

Seed today: `remainder` with `new_condition: true`.

Remainder behavior needs explicit setup — do **not** automatically inherit used behavior:

```text
vendor_orderable: usually yes unless orderable explicitly false
customer-reservable: yes
sellable: yes
buyback-eligible: usually no
normal PO eligible: only if orderable and otherwise eligible
```

---

## Current model (use first)

```text
Product
ProductVariant
ProductCondition
ProductVariant#orderable?
ProductVariant#active?
Product#active?
Product#publication_status
ProductIdentifier
InventoryBalance / InventoryLedgerEntry
BuybackLine
CustomerRequestLine
PurchaseRequestLine / TBO
PurchaseOrderLine
```

Condition-level fields in use:

```text
ProductCondition#new_condition?
ProductCondition#buyback_eligible?
ProductCondition#buyback_default?
ProductCondition#active?
```

---

## Behavioral rules

### 1. Variant condition is the source of new/used behavior

A product variant’s used/new behavior is determined by its **condition**, not by product title, product type, SKU pattern, or vendor source.

Required centralized API (model, service, or policy — one source of truth):

```ruby
policy.new_condition?          # or .new?
policy.used_condition?         # or .used?
policy.used_like?              # non-new for replenishment purposes
policy.vendor_orderable?
policy.customer_reservable?
policy.buyback_eligible?
policy.purchasing_block_reason # human-readable when not vendor-orderable
```

Callers must not duplicate `!condition.new_condition?` checks ad hoc after v0.04-5.

### 2. Used variants are sellable

A used variant may be sold at POS if:

```text
variant active
product active
variant has valid sale setup
variant has price or allowed open price behavior
```

Availability may be negative under existing inventory rules; UI should warn clearly if staff sell unavailable used stock. POS lookup unchanged from v0.04-2.

### 3. Used variants are customer-reservable only when appropriate

Before v0.04-6, current customer request/hold behavior may continue, but v0.04-5 must enforce:

```text
hold/reserve used variant on hand → allowed
notify/wanted request for used copy → allowed if current UI supports it without vendor-order assumption
special_order / vendor-style order for used variant → blocked
```

Full **used wanted** queue semantics defer to v0.04-6.

### 4. Used variants are not normal vendor-orderable

Used and used-like variants must be blocked from:

```text
PurchaseOrderLine normal add
PurchaseOrder submit (when line present)
TBO create (PurchaseRequests::CreateSingleLine)
TBO build-to-PO queue (exclude or show blocked)
PurchaseRequestLine vendor-order queue as buildable
automatic reorder suggestions for used-like variants
```

Blocking message (authoritative):

```text
Used variants cannot be added to normal vendor purchase orders.
```

**Behavior change from Phase 8.5-3:** TBO context previously allowed used variants (`:tbo` returned early without used check). v0.04-5 aligns TBO with PO policy.

### 5. Used variants may enter inventory through buyback/intake

Used stock enters through:

```text
buyback intake
manual inventory adjustment
inventory correction
future used receiving/intake workflow
```

Not through normal vendor receiving for used-like variants.

Buyback-created or buyback-linked variants must:

```text
use a used/buyback-eligible condition
be product-first (no catalog_item dependency)
receive a generated 211-segment variant SKU via ProductVariants::SkuAllocator when newly created
default orderable to false via ProductVariants::OrderabilityDefaults
remain sellable
```

### 6. Used variants should not trigger vendor sourcing warnings

For used and used-like variants, item page warnings must not say:

```text
No preferred vendor is configured.
No vendor sourcing record exists.
Expected unit cost could not be determined.
```

Those warnings remain useful for new orderable variants.

Used variants may instead show info such as:

```text
Used variant — not vendor-orderable.
Available only from current stock or future intake.
```

### 7. Used variants share product identifiers through the product

A used variant does not need its own ISBN/UPC. It belongs to a product that owns `product_identifiers`.

Rules:

```text
Product identifier scan resolves product.
If multiple variants exist, staff select the intended variant.
Used variant SKU scan resolves the exact used variant.
```

Do not create duplicate ISBN/GTIN identifiers at the variant level.

---

## UI requirements

### Item detail / operations

For each variant, display clear operational status:

```text
New / Used / Used-like / Remainder / Non-inventory
Orderable / Not vendor-orderable
Buyback eligible / Not buyback eligible
Reservable / Not reservable (when relevant)
```

Used variants must not be presented as missing vendor setup.

### Item setup

When creating or editing a variant:

* Condition choice should clearly affect orderability.
* Selecting a used/buyback-eligible condition should default `orderable` to false.
* Staff should be warned if they try to mark a used-like condition as vendor-orderable.
* Staff may still save a used variant for POS/inventory.
* Vendor-source controls for used variants: **hidden or disabled with “not applicable”** explanation (recommended default).

### Buyback workflow

Buyback matching should prefer used/buyback-eligible variants.

When no matching used variant exists, staff should create one from the product context.

Expected flow:

```text
Buyback line
  → resolve product
  → choose existing used variant or create used variant
  → assign condition
  → post/prepare inventory movement according to current buyback flow
```

### Purchasing / TBO

Used variants should be excluded from normal buildable PO/TBO queues or shown as blocked with explicit reason.

```text
New/orderable variants → normal purchasing workflow
Used/used-like variants → excluded from buildable PO/TBO queue
Used wanted/request workflows → deferred to v0.04-6 demand foundation
```

---

## Services / policy layer

Introduce or consolidate:

```ruby
ProductVariants::OperationalPolicy
```

Suggested API:

```ruby
ProductVariants::OperationalPolicy.for(variant).used?
ProductVariants::OperationalPolicy.for(variant).new?
ProductVariants::OperationalPolicy.for(variant).used_like?
ProductVariants::OperationalPolicy.for(variant).vendor_orderable?
ProductVariants::OperationalPolicy.for(variant).buyback_eligible?
ProductVariants::OperationalPolicy.for(variant).customer_reservable?
ProductVariants::OperationalPolicy.for(variant).purchasing_block_reason
```

Refactor obvious callers:

* `Purchasing::OrderEligibilityResolver`
* `ProductVariants::OrderabilityDefaults`
* Buyback variant create/find paths
* `Items::OperationalWarningBuilder` (ordering context)
* Customer request start-from-item guardrails

Exact class name is flexible; centralization is not.

---

## In-scope implementation areas

### 1. Condition behavior audit

Audit `ProductCondition` seed data and usage.

Confirm:

```text
one active new/default condition exists (condition_key: new)
used/buyback conditions are marked non-new
buyback-default condition is buyback-eligible (condition_key: used_good)
inactive conditions are not offered for new variants
remainder remains new_condition: true unless explicitly changed
```

Add validation or seed verification if needed.

### 2. Variant policy methods

Centralize rules for new vs used, buyback eligibility, vendor orderability, customer reservability, used-like behavior.

Refactor duplicated logic into the policy.

### 3. Item workspace warnings

Update item operation warnings so used variants do not receive vendor-sourcing warnings.

Add used-specific information where helpful.

### 4. Purchasing eligibility

Ensure `Purchasing::OrderEligibilityResolver` (delegating to policy) blocks used variants consistently including **TBO context**.

Expected result:

```text
used variant + purchase_order context → blocking
used variant + tbo context → blocking (behavior change)
used variant + item_page context → warning/info only, no vendor-source noise
new variant + missing vendor source → warning as before
```

### 5. TBO queue

Exclude used variants from normal buildable vendor-order queues, or show blocked with reason.

Existing TBO lines pointing at used variants: show non-buildable, do not silently treat as orderable.

### 6. Buyback matching and creation

Ensure buyback-created variants use buyback-eligible used conditions, 211 SKUs, and `orderable: false`.

Regression tests for link-existing and create-new paths.

### 7. Customer request bridge

Minimal safety before v0.04-6:

```text
hold used variant with available stock → allowed
vendor-style special order for used variant → blocked
notify/wanted intent → allowed only without vendor-order assumption
```

Do not redesign request statuses or allocation behavior.

### 8. Documentation and verification

Add completion note when done: `docs/implementation/v0.04-5-completion.md`.

Verification task:

```bash
bin/rails shelfstack:v0045:verify_used_variant_rules
STRICT=1 bin/rails shelfstack:v0045:verify_used_variant_rules
```

Report should flag:

```text
new condition missing or inactive
buyback default condition missing or not buyback-eligible
used/buyback conditions marked new_condition: true
used variants with orderable: true
used variants appearing buildable in PO/TBO eligibility samples
buyback-created variants without buyback-eligible used condition
buyback-created variants with non-211 SKU pattern (when detectable)
```

---

## Out of scope

```text
Product groups (v0.04-3 deferred)
Demand foundation tables (v0.04-6)
Demand allocation model (v0.04-7)
Full customer request redesign (v0.04-10)
Used wanted queue redesign (v0.04-6)
Vendor sourcing cascade (v0.04-8)
PO/receiving quantity model redesign (v0.04-9)
Consignment settlement
Copy-level serial numbers
Rare/collectible grading model
Automated used repricing
Full buyback valuation overhaul
Report/snapshot column rename sweep (v0.04-11)
POS lookup redesign (v0.04-2)
catalog_items drop (v0.04-11)
```

---

## Edge cases

### Used copy for a product with no new variant

Allowed. A product may have only used variants.

### New and used variants for the same product

Allowed and expected. Product owns ISBN/UPC; variants represent operational forms (New TP, Used TP - Good, etc.).

### Used variant with zero on hand

Allowed. May remain visible as future intake/matching target; not presented as currently available for sale without stock warning.

### Used variant accidentally marked orderable

```text
variant setup → warning on save
purchase order add/submit → block
TBO create/queue → block or exclude
```

Optional backfill: set `orderable: false` for used-like variants where safe.

### Remainder variant

Do not treat remainder as used unless condition configuration says so. Remainder orderability follows `new_condition: true` + `orderable` flag.

### Damaged / collectible (future conditions)

Treat as used-like for purchasing/orderability unless explicitly configured otherwise (recommended default).

### Signed / special edition

Remain `new_condition: true` in seeds — vendor-orderable when `orderable` and product type allow.

---

## Implementation slices

### Slice 1 — Audit and vocabulary

* Audit `ProductCondition` seeds and document condition matrix.
* Add seed validation if gaps found.
* Land spec bundle (this document, data-model, test-plan).

### Slice 2 — Central policy

* Add `ProductVariants::OperationalPolicy`.
* Implement new/used/used_like/vendor_orderable/buyback/reservable helpers.
* Refactor obvious callers.

### Slice 3 — Purchasing and TBO enforcement

* Block used variants at `:tbo` context (behavior change).
* Exclude or block in TBO queue UI.
* Ensure PO paths unchanged except policy delegation.

### Slice 4 — Item workspace messaging

* Variant operational status display.
* Used-specific warnings; suppress vendor-source noise.
* Item setup orderability warnings and vendor UI treatment.

### Slice 5 — Buyback matching rules

* `FindOrCreateGradedUsedVariant` → `SkuAllocator` for new variants.
* Enforce orderability defaults and buyback-eligible condition.
* Regression tests.

### Slice 6 — Customer request bridge guardrails

* Block `special_order` for used variants in `StartFromItem` (and related entry points).
* Preserve hold/notify where supported.

### Slice 7 — Verification and docs

* `shelfstack:v0045:verify_used_variant_rules`
* Update [v0.04 README](../README.md) status.
* Completion note and manual smoke checklist.

---

## Acceptance criteria

v0.04-5 is complete when:

1. Used/new behavior is centralized in a policy/helper layer.
2. Product conditions clearly determine used-like behavior.
3. Used variants are sellable at POS (lookup unchanged).
4. Used variants are not normal vendor-orderable.
5. Used variants do not appear as buildable normal PO/TBO lines.
6. Used variants do not show misleading missing-vendor-source warnings.
7. Buyback-created variants use buyback-eligible used conditions.
8. Buyback-created variants receive 211-segment SKUs and are not vendor-orderable by default.
9. Customer request bridge does not create vendor-style special orders for used variants.
10. v0.04-5 docs and tests are complete.
11. Verification task passes in strict mode.

---

## Manual smoke checklist

1. Create a product with a new variant and a used variant.
2. Confirm the new variant can be added to a normal PO when otherwise eligible.
3. Confirm the used variant cannot be added to a normal PO.
4. Confirm the used variant cannot be added to TBO (or appears blocked in queue).
5. Confirm the used variant does not show missing preferred vendor/source warnings.
6. Confirm the used variant can be sold at POS.
7. Confirm the used variant appears on item detail and operations tabs with clear status.
8. Confirm buyback can match an existing used variant.
9. Confirm buyback can create a new used variant with 211 SKU.
10. Confirm buyback-created variant is not vendor-orderable.
11. Confirm customer hold on used variant works; special order for used variant is blocked.
12. Confirm scans still resolve product identifiers and variant SKUs per v0.04-2.
13. Confirm no new schema dependency on `catalog_items`.

---

## Open decisions

1. Should “remainder” gain an explicit non-orderable default, or remain staff-controlled via `orderable` only?
2. Should staff be allowed to manually override `orderable` on a used-like condition, or should save always warn and PO/TBO always block?
3. Do we need distinct “used wanted” placeholder behavior before v0.04-6?
4. Should damaged variants (when added) be treated as used-like for all purchasing behavior?
5. Should consignment-used behavior be deferred entirely?
6. Hide vs disable vendor-source controls for used variants?

## Recommended default decisions

Unless explicitly changed during implementation:

1. Remainder is **not automatically used**; orderability is explicit via `orderable`.
2. Used-like conditions **cannot be normal vendor-orderable**; PO/TBO always block even if `orderable: true`.
3. Used wanted behavior is **deferred to v0.04-6**.
4. Damaged variants are **used-like for purchasing/orderability** unless configured otherwise later.
5. Consignment is **deferred**.
6. Vendor-source controls for used variants should be **hidden or clearly marked not applicable**.

---

## Next milestone

**v0.04-6 — Demand foundation** after v0.04-5 merge. **v0.04-3 — Product groups** remains deferred.
