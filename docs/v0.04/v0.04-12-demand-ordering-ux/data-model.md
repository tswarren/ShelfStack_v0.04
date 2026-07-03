# v0.04-12 Demand Ordering UX — Data Model

## Status

**Planned** — UX milestone; no core schema redesign.

---

## Schema policy

**No new core tables** for v0.04-12.

### Permitted small additions (only if needed during implementation)

| Addition | Reason |
| -------- | ------ |
| Audit event `event_details` keys for demand↔PO linkage | Traceability when PO created from demand (`demand_line_ids`, `coverage_plan`) |
| Optional JSON on PO line audit source | Display planned customer vs stock qty without new tables |

### Do not add

```text
purchase_requests
special_orders
inventory_reservations
receipt_line_allocations
purchase_order_line_allocations
purchase_demand
```

---

## Staff supply states (display model)

| Internal | Staff label | Persistence |
| -------- | ----------- | ----------- |
| No active allocation | Unallocated | Computed from `DemandAllocation` |
| Draft PO line for variant (no inbound alloc) | Planned on order | Derived from draft `PurchaseOrderLine` + audit |
| `allocation_kind: inbound_purchase_order` active | On order | `demand_allocations` |
| `allocation_kind: on_hand` active | On hand | `demand_allocations` |
| `allocation_kind: vendor_backorder` active | Vendor backorder | `demand_allocations` |

**Planned on order** is not an allocation row; it must not affect `InboundAvailability` or inventory.

---

## Service boundaries (Slice E)

| Service | Writes |
| ------- | ------ |
| `Purchasing::DemandCoveragePlanner` | Read-only plan struct |
| `Purchasing::BuildPurchaseOrderFromDemand` | Draft PO + lines + audit |
| `Purchasing::AddDemandToPurchaseOrder` | Draft PO lines + audit |
| `DemandAllocations::AllocateInboundPurchaseOrder` | Active inbound allocation (only when eligible) |
