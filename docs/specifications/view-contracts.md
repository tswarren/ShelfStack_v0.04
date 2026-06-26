# View Contracts

**Status:** Planned (Phase 10-A)

Per-screen-type behavior contracts. Canonical visual source: [shelfstack_ux_direction_visual.html](../samples/phase-10-mockups/shelfstack_ux_direction_visual.html).

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

## Item overview contract

Phase 9 drill-down surfaces: see [phase-9-item-drill-down-contract.md](../handoff/phase-9-item-drill-down-contract.md).

## POS contract

First focus: command field. Primary: settlement. See [phase-10c-pos-keyboard-workspace.md](../roadmap/phase-10c-pos-keyboard-workspace.md).

## Report contract

Phase 9a report view contract remains authoritative for `/reports` screens.
