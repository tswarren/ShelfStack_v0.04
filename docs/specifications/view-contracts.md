# View Contracts

**Status:** Phase 10-A (Turbo targets added)

Per-screen-type behavior contracts. Canonical visual source: [shelfstack_ux_direction_visual.html](../samples/phase-10-mockups/shelfstack_ux_direction_visual.html).

**See also:** page patterns and action hierarchy in [ux-guide.md](../design/ux-guide.md); shell layout in [app-shell-and-pos-shell.md](../design/app-shell-and-pos-shell.md).

## North-star rules

* One primary action should be visually obvious per screen/section.
* Preserve context: bounded edits via modals, drawers, Turbo updates — not full page hops.
* Summarize related records before exposing full detail tables.

## View types

| Type | Job | First focus | Primary action |
| ---- | --- | ----------- | -------------- |
| Index / Search | Find records, narrow queue | Search field | Search / Add |
| Detail / Overview | Explain record; what to do now | Usually none | Continue / Edit |
| Item Overview | Unify catalog, SKU, inventory, demand | Item search when invoked | Sell / Receive / Order |
| Form / Edit | Change one record or setup area | First invalid field on error | Save |
| Workflow | Multi-step operational task | Current step input | Continue / Complete |
| POS / Register | Scan speed, tender clarity, safe completion | Scan/command field | Settle / Complete |
| Report | Review, filter, print, export | Filter if needed | Run / Print / Export |
| Setup List | Maintain reference data | Search or Add | Add |

## Message placement

Workflow blockers and readiness checks appear **where the user can act** — not as global flash unless truly page-level.

Minor non-blocking confirmations may append to `#toast_region` via Turbo Streams; page-level notices continue to use flash.

## Turbo target conventions (10-A)

Standard DOM targets for Turbo updates:

```text
flash
toast_region
modal
drawer
workflow_status
workflow_lines
workflow_summary
lookup_results
item_attention
variant_table
pos_cart
pos_totals
pos_readiness
```

Pilot drawer id: `item-demand-drawer`.

## Item overview contract

Phase 9 drill-down surfaces: see [phase-9-item-drill-down-contract.md](../handoff/phase-9-item-drill-down-contract.md).

## POS contract

**Authoritative:** [phase-10c-pos-keyboard-workspace-spec.md](phase-10c-pos-keyboard-workspace-spec.md), [phase-10c-pos-keyboard-workspace.md](../roadmap/phase-10c-pos-keyboard-workspace.md).

| State | First focus | Primary action | Notes |
| ----- | ----------- | -------------- | ----- |
| Idle (register open, no active draft) | Command field | Scan/add or slash command | No silent draft creation; **New sale** is secondary mouse path |
| Active draft | Command field | Settle / Complete | Active draft always wins on `/pos` landing |
| Modal/drawer open | First meaningful control in overlay | Save / Continue / Close | Restore focus to opener on close |

**Parser:** slash-prefixed input → command registry; non-slash → scan/catalog lookup only. Failed lookup never creates a draft.

**Workflow surfaces:** cart is the working surface; line edits via expanded row; return/pickup via drawers; settlement and cash movement via modals. Readiness blockers appear near completion controls and inside settlement modal.

**Turbo targets:** `pos_cart`, `pos_totals`, `pos_readiness` (see table above).

## Report contract

Phase 9a report view contract remains authoritative for `/reports` screens.
