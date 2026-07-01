# v0.04-5 Used Variant Rules — Test Plan

## Status

**Draft** — executable when implementation begins.

---

## Prerequisites

- v0.04-4 merged (product-first wire-through)
- v0.04-2 merged (211 variant SKUs, product identifier ownership)
- Phase 8.5-3a ordering readiness in codebase (`OrderEligibilityResolver`, TBO single-line create)

---

## Verification commands

```bash
./dev/rails-docker bin/rails test
./dev/rails-docker bin/rails shelfstack:seeds:validate
./dev/rails-docker bin/rails shelfstack:v0042:verify_product_identifiers
./dev/rails-docker bin/rails shelfstack:v0044:verify_wire_through
./dev/rails-docker bin/rake shelfstack:v0045_verify_used_variant_rules
STRICT=1 ./dev/rails-docker env STRICT=1 bin/rake shelfstack:v0045_verify_used_variant_rules
```

---

## Rake verification (new)

### `shelfstack:v0045:verify_used_variant_rules`

| Check | Pass condition |
| ----- | -------------- |
| Active `new` condition | Exists with `new_condition: true`, `active: true` |
| Buyback default | `used_good` (or configured default) exists, `buyback_eligible: true`, `buyback_default: true` |
| Used conditions not new | All `buyback_eligible` conditions have `new_condition: false` |
| Used variants orderable | Report count of active used-like variants with `orderable: true` (warn or fail in strict) |
| Policy centralization | No new ad hoc `!condition.new_condition?` in PO/TBO controllers outside policy/resolver (lint/grep check optional) |
| Buyback intake SKUs | Sample buyback-created variants match `\A211[0-9]{10}\z` when created after v0.04-5 |

Report-only by default; `STRICT=1` fails on policy violations listed in [spec.md](spec.md).

---

## Unit tests — `ProductVariants::OperationalPolicy`

| Test | Assert |
| ---- | ------ |
| New condition variant | `new?` true, `used_like?` false, `vendor_orderable?` true when orderable and product active |
| Used condition variant | `used_like?` true, `vendor_orderable?` false |
| Used + orderable true | `vendor_orderable?` still false (used-like always blocks vendor path) |
| Remainder condition | `new?` true, `used_like?` false; orderability follows `orderable` flag |
| Service/financial product | `vendor_orderable?` false |
| Inactive variant/product | `vendor_orderable?` false |
| Buyback eligible | true only when condition.buyback_eligible and subdepartment allows (buyback context) |
| `purchasing_block_reason` | Present and human-readable for used-like |

---

## Unit tests — `ProductVariants::OrderabilityDefaults`

| Test | Assert |
| ---- | ------ |
| Used condition on create | Defaults `orderable` to false |
| New condition on create | Defaults `orderable` to true (non-service product) |
| Delegates used detection | Uses policy or shared condition helper (no divergent logic) |

---

## Service tests — `Purchasing::OrderEligibilityResolver`

| Test | Assert |
| ---- | ------ |
| Used variant + `:purchase_order` | Blocking; reason `:used_variant` |
| Used variant + `:purchase_order_submit` | Blocking |
| Used variant + `:tbo` | **Blocking** (update from pre–v0.04-5 “allows tbo” test) |
| Used variant + `:item_page` | Warning/info `:used_variant`; no `:missing_preferred_vendor` / `:missing_vendor_source` / `:missing_cost` |
| New variant + `:item_page` + missing vendor | Vendor sourcing warnings present as today |
| New variant + `:purchase_order` | Eligible when otherwise configured |

---

## Service tests — `PurchaseRequests::CreateSingleLine`

| Test | Assert |
| ---- | ------ |
| New orderable variant | Creates TBO line |
| Used variant | Raises with used-variant message; no line created |

---

## Service tests — `Purchasing::TboQueueRowBuilder`

| Test | Assert |
| ---- | ------ |
| Queue with used variant TBO line | Row excluded or `po_eligibility` blocking with `:used_variant` |
| Queue with new variant line | Buildable when otherwise eligible |

---

## Service tests — buyback variant create

| Test | Assert |
| ---- | ------ |
| `FindOrCreateGradedUsedVariant` creates new | SKU matches 211 pattern; `orderable: false`; buyback-eligible condition |
| `FindOrCreateGradedUsedVariant` finds existing | Reuses variant; eligibility validated |
| New condition via buyback | Rejected |
| Non-buyback-eligible condition | Rejected |
| Audit event | `buyback.intake.product_variant_created` when new |

---

## Service tests — customer requests

| Test | Assert |
| ---- | ------ |
| `StartFromItem` hold + used variant | Succeeds |
| `StartFromItem` notify + used variant | Succeeds (if supported by current workflow) |
| `StartFromItem` special_order + used variant | Raises; no special order created |
| `StartFromItem` special_order + new variant | Succeeds (regression) |

---

## Presenter / warning tests

| Test | Assert |
| ---- | ------ |
| `Items::OperationalWarningBuilder` used variant | Includes used/not-vendor-orderable info; excludes vendor-source warnings |
| `Items::OperationalWarningBuilder` new variant | Vendor-source warnings when applicable |
| Item overview variant status | Displays new/used/orderable/buyback labels (system or request test) |

---

## Integration / request tests

| Test | Assert |
| ---- | ------ |
| Add used variant to draft PO | Blocked with clear message |
| Add new variant to draft PO | Allowed when eligible |
| Item variant create with used condition | `orderable` false by default |
| Buyback proposal line pricing | Creates/links used variant with correct defaults |

---

## Regression gates (must not change)

| Area | Assert |
| ---- | ------ |
| POS `LineLookup` / scan order | Unchanged from v0.04-2 |
| Product identifier resolution | ISBN on product, variant SKU on variant |
| Buyback completion / inventory post | Still posts at session complete |
| Inventory eligibility | `Inventory::Eligibility` unchanged for used variants |
| v0.04-4 wire-through | `shelfstack:v0044:verify_wire_through` still passes |

---

## Seed tests

| Test | Assert |
| ---- | ------ |
| `shelfstack:seeds:validate` | Passes |
| Condition matrix | `new` active; used keys non-new; `used_good` buyback default |
| Idempotent re-seed | Condition flags unchanged on second run |

---

## Manual smoke checklist

From [spec.md](spec.md):

1. Product with new + used variants
2. New → PO add works
3. Used → PO add blocked
4. Used → TBO blocked or queue shows blocked
5. Used → no missing vendor warnings on item page
6. Used → POS sell works
7. Item operations shows variant status
8. Buyback match existing used variant
9. Buyback create new used variant (211 SKU)
10. Buyback-created not vendor-orderable
11. Hold allowed; special order blocked for used
12. Scan regression (product identifier + variant SKU)
13. No new `catalog_items` dependency

---

## Test file placement (suggested)

```text
test/services/product_variants/operational_policy_test.rb
test/services/purchasing/order_eligibility_resolver_test.rb  # extend
test/services/purchase_requests/create_single_line_test.rb   # extend
test/services/buybacks/find_or_create_graded_used_variant_test.rb
test/services/customer_requests/start_from_item_test.rb      # extend
test/services/items/operational_warning_builder_test.rb      # extend
test/lib/shelfstack/v0045_verify_test.rb                   # if verify class extracted
```

---

## Definition of done (testing)

- All new unit/service tests green
- Updated tests reflect TBO blocking behavior change
- Verification rake implemented and documented
- Full suite + seed validate + v0.04-2/v0.04-4 verify tasks pass
- Manual smoke checklist recorded in completion note
