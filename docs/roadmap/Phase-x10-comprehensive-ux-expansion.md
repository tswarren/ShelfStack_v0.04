# Phase 10 — Comprehensive UI/UX Expansion

## Purpose

This phase implements the broader ShelfStack UI/UX vision that was intentionally deferred from Phase 9a.

Phase 9a establishes the report-facing UX and semantic foundation. Phase 9b implements operational reports (**complete**). Phase 9c (GL-shaped financial postings) is **deferred**; this phase is the next active roadmap priority after Phase 9b. It returns to the larger application experience: POS workflow modernization, item cockpit redesign, app-wide modal and drawer patterns, keyboard-first interaction standards, command shortcuts, progressive disclosure, and consistency across operational pages.

The goal is to make ShelfStack feel like a cohesive, fast, operational bookstore system rather than a collection of Rails CRUD screens.

## Relationship to Phase 9

Parent roadmap: [phase-9-reporting-and-accounting.md](phase-9-reporting-and-accounting.md).

### Phase 9a — UX Foundation for Reporting

Phase 9a standardizes the report-facing subset of the UX direction:

* Report view contract
* Report filters, tables, metric cards, and print/export patterns
* Message taxonomy for report screens
* Money/percentage/quantity/date formatting
* Reporting semantics and operational-vs-financial rules

Phase 9a does not implement modal, drawer, POS workspace, or item cockpit systems.

### Phase 9b — Operational Reports

Phase 9b uses those standards to build and consolidate operational reports.

### Phase 9c — GL-Shaped Financial Posting Layer

**Deferred.** Phase 9c would generate balanced financial postings from operational events and produce export-ready journal summaries for external accounting systems. Export and financial admin screens would use Phase 9a report patterns. See [phase-9c-gl-shaped-financial-layer.md](phase-9c-gl-shaped-financial-layer.md).

### Phase 10 — Comprehensive UI/UX Expansion

**Next** after Phase 9b. This phase completes the larger interaction vision:

* POS transaction-first workspace
* Full POS command and shortcut behavior
* Improved POS line editing
* Modal and drawer system
* Item cockpit and operations drawer
* Item setup modals
* Customer request and purchasing workflow UX cleanup
* App-wide keyboard/focus conventions
* Progressive disclosure across complex records
* Broader interaction consistency for Turbo/Stimulus workflows

This phase should not block reports.

---

## Sub-Phases

Phase 10 ships incrementally. **Phase 10 is complete when 10-A through 10-E are all done** (separate PRs; not one merge).

| Sub-phase | Document | Job | Depends on | Status |
| --------- | -------- | --- | ---------- | ------ |
| **10-A** | [phase-10a-interaction-infrastructure.md](phase-10a-interaction-infrastructure.md) | Modal, drawer, toast, expanded row, focus/keyboard, Turbo targets | — | **Complete** |
| **10-B** | [phase-10b-item-cockpit-completion.md](phase-10b-item-cockpit-completion.md) | Item cockpit gaps on 8.5-4; setup modals; operations drawer | 10-A | **Complete** |
| **10-C** | [phase-10c-pos-keyboard-workspace.md](phase-10c-pos-keyboard-workspace.md) | Keyboard-first POS workspace, landing, commands, settlement | 10-A | **Planned** (current) |
| **10-D** | This document (Workstreams 4–6) | Customer requests, purchasing/receiving line UX, buyback header metrics | 10-A | Planned |
| **10-E** | This document (below) | Consistency sweep, accessibility, report regression | All | Planned |

**Delivery order (confirmed):** 10-A → 10-B → 10-C → 10-D → 10-E. **Current implementation priority:** 10-C.

**Note:** Early drafts labeled 10-B as POS and 10-C as items. Sub-phase letters now match delivery order (10-B = items, 10-C = POS).

### Visual Mockups

Static HTML mockups in [docs/samples/phase-10-mockups/](../samples/phase-10-mockups/) are **draft inspiration only** — map patterns to `ss-*` in `shelfstack.css`, do not copy mockup CSS. See [README](../samples/phase-10-mockups/README.md).

| Mockup | Sub-phase |
| ------ | --------- |
| [shelfstack_ux_direction_visual.html](../samples/phase-10-mockups/shelfstack_ux_direction_visual.html) | Parent, 10-A (view contracts) |
| [shelfstack_items_mockups.html](../samples/phase-10-mockups/shelfstack_items_mockups.html) | 10-B |
| [shelfstack_pos_mockups.html](../samples/phase-10-mockups/shelfstack_pos_mockups.html) | 10-C |

---

# Problem Statement

ShelfStack has strong domain coverage, but the interface currently feels uneven because related workflows use different layout, action, field, message, and interaction patterns.

Recurring issues:

* Similar fields look different across screens.
* Select lists sometimes feel like raw browser controls.
* Buttons are overused and often carry too much visual weight.
* Some pages are visually dense without clear hierarchy.
* POS scan entry feels strong, but line modification feels more like admin form editing.
* Customer request pages contain useful information but are hard to navigate.
* `/items` exposes many correct relationships, but the overview can feel like a data dump.
* Buyback and POS pages use different dashboard/header patterns.
* Turbo/Stimulus interactions exist, but they are workflow-specific rather than standardized.
* Modals and drawers are useful but not yet a shared system.
* Keyboard/focus behavior is present in some places, but not consistently defined.

This phase should turn the existing visual direction into a coherent application interaction system.

---

# Target UX Feel

ShelfStack should feel:

```text
Operational, not decorative.
Fast, not flashy.
Dense enough for bookstore work, but not cramped.
Keyboard-friendly by default.
Predictable from screen to screen.
Calm even when records are interconnected.
Clear about the next action.
Summary-first, with detail available on demand.
Brand-aware, but not visually noisy.
```

## Practical Meaning

| Principle              | Meaning                                                                                               |
| ---------------------- | ----------------------------------------------------------------------------------------------------- |
| Operational            | Screens answer staff questions and support real work.                                                 |
| Fast                   | Search, scan, add, edit, save, and complete flows minimize clicks and page changes.                   |
| Predictable            | Similar actions, fields, messages, and focus behavior work the same way everywhere.                   |
| Calm                   | Typography, spacing, cards, and hierarchy reduce overwhelm.                                           |
| Keyboard-first         | POS and workflow screens support keyboard/scan-driven operation.                                      |
| Progressive disclosure | Summary appears first; advanced detail is available through tabs, drawers, modals, and expanded rows. |
| Context-preserving     | Bounded edits happen without forcing users to leave the current workflow.                             |

---

# Goals

This phase should:

1. Implement the broader ShelfStack UI/UX vision beyond reporting.
2. Make POS a keyboard-first transaction workspace.
3. Complete `/items` cockpit gaps (operations drawer, setup modals) on Phase 8.5-4 foundation.
4. Standardize modals, drawers, expanded rows, and inline editors.
5. Extend keyboard/focus rules across operational workflows.
6. Reduce button-heavy screens by distinguishing actions, filters, tabs, badges, and utilities.
7. Make complex record relationships easier to understand through summaries and progressive disclosure.
8. Improve customer requests, purchasing, receiving, buybacks, POS, and item workflows.
9. Continue using the Phase 9a design system rather than inventing new page-specific UI.
10. Keep reporting screens compatible with the broader interface direction.

---

# Non-Goals

This phase does not include:

* Rebuilding the entire application frontend from scratch
* Replacing Rails/Turbo/Stimulus with a SPA framework
* Full RubyUI/DaisyUI migration unless separately approved
* Offline POS
* New reporting engine
* Data warehouse
* Advanced analytics/report builder
* Accounting/GL export
* Mobile-native app
* Complete redesign of every setup/admin page
* Redesigning Phase 9 report screens except for shared component upgrades, accessibility improvements, or compatibility updates
* Changing core business rules without separate domain approval

---

# Major Workstreams

## Workstream 1 — Interaction System (Phase 10-A)

Extend Phase 9a into shared modal, drawer, toast, expanded-row, focus, and Turbo conventions.

**Full spec:** [phase-10a-interaction-infrastructure.md](phase-10a-interaction-infrastructure.md)

Summary taxonomy:

* **Modal** — bounded tasks (`ss-modal*`)
* **Drawer** — detail without losing page context (`ss-drawer*`)
* **Toast** — minor confirmations only (`ss-toast*`)
* **Expanded row** — inline line edits (`ss-expand-row*`, `ss-row-detail*`)

Pilot migration: item customer demand drawer → shared drawer shell.

---

## Workstream 2 — Item Cockpit Completion (Phase 10-B)

Complete `/items` on Phase 8.5-4 foundation — not a greenfield redesign.

**Full spec:** [phase-10b-item-cockpit-completion.md](phase-10b-item-cockpit-completion.md)

Core gaps: setup modals (identifier, price, vendor source, tax), operations summary table + demand drawer, behavior-aware warnings. Preserve [drill-down contract](../handoff/phase-9-item-drill-down-contract.md). Item commands deferred.

---

## Workstream 3 — POS Keyboard-First Workspace (Phase 10-C)

Refine existing POS into a transaction-first register workspace.

**Full spec:** [phase-10c-pos-keyboard-workspace.md](phase-10c-pos-keyboard-workspace.md)

Guiding model:

```text
Command field is home base.
Idle workspace does not create a draft.
Transaction-starting input creates or resumes the active draft.
Transactionless commands do not create drafts.
Cart is the working surface once a transaction exists.
Line edits happen inline.
Related detail opens in drawers.
Bounded decisions happen in modals.
Readiness appears where completion happens.
Command aliases make common actions fast.
```

Key decisions: idle workspace when no active draft; active draft always wins on landing; two-lane parser (slash commands vs scan lookup only); no implicit workflow guessing; one active draft per register session + workstation + cashier; return/pickup drawer workflows; `/reports` confirms when active draft exists; **function keys out of scope for 10-C completion**.

---

## Workstream 4 — Customer Request UX Rework (Phase 10-D)

**Priority within 10-D:** Customer requests first.

### Problems to Solve

* Index filters feel like too many equal-weight buttons.
* Detail page has useful information but unclear hierarchy.
* Actions, status, metadata, request lines, customer contact, and audit information compete visually.
* Row actions and next actions can be redundant.

### Scope

### 4.1 Customer Request Index

Recommended layout:

```text
Page header
  Title
  Description
  Primary action: New request

Filter/search area
  Search
  Status filter
  Request type filter
  Ready/not ready
  Assigned user if available

Results table
  Request
  Customer
  Item
  Status
  Age
  Next action
  Availability
  Assigned user
```

Rules:

* Inactive filters should be quiet.
* Active filters should be visible but not primary-button-heavy.
* New request should be the clear primary action.
* Each row should have one clear primary row action.

### 4.2 Customer Request Detail

Recommended layout:

```text
Record header
  Request number
  Status
  Customer
  Source
  Primary next action

Status strip
  Lines
  Unmatched
  Ready
  Completed
  Waiting

Main content
  Request lines
  Current action
  Availability/demand state

Sidebar
  Customer contact
  Request facts
  Related records

Audit/activity
  Collapsed or secondary
```

Rules:

* The page should distinguish record summary, current workflow state, line action, customer contact, and supporting facts.
* Request lines should not mix too many nested tasks in one card.
* Routine updates should not become large page alerts.

---

## Workstream 5 — Purchasing and Receiving Line UX (Phase 10-D)

**Scope limit (initial 10-D):** Line-entry UX patterns reusing 10-A expanded row. **No** full TBO wizard redesign.

### Initial scope

* Lookup, quantity, cost/price, and discount percent fields use standard controls
* Money inputs use decimal dollars; discounts use decimal percentages
* Accepted/rejected/received quantities visually grouped
* Warnings inline or section-level, not random alerts
* After adding a line, focus moves to the next expected input
* Expanded-row pattern where useful for PO/receiving line edits

---

## Workstream 6 — Buyback Index Alignment (Phase 10-D)

**Scope limit (initial 10-D):** Header, metric strip, and table layout alignment only. Buyback session workflow was refined in Phase 7C-1 — **do not re-refine**.

### Initial scope

* Buybacks index: page header, metric strip, recent sessions table, needs-review queue, primary **New buyback** action
* Shared metric-card and table patterns consistent with other operational indexes

---

## Future 10-D+ / deferred workflow ideas

The following are **not** in initial 10-D scope. Preserve as design direction for a later sub-phase or dedicated doc (`phase-10d-workflow-polish.md` when 10-D starts).

### Build Purchase Order from TBO (full wizard)

```text
Step 1 — Choose grouping (vendor-first / suggested vendor)
Step 2 — Filter demand (department, format, vendor, store, request type)
Step 3 — Review TBO lines (item, variant, qty, vendor, stock, on order, demand, action)
Step 4 — Build PO (confirm vendor, selected lines, create draft PO)
```

### Buyback session workflow refinements

Stepper, proposal/decision/payout panels, line entry polish beyond index alignment — deferred because 7C-1 already refined the session workflow.

---

## Workstream 7 — Global Keyboard, Focus, and Turbo Standards (Phase 10-A)

Keyboard/focus rules and Turbo target conventions are specified in [phase-10a-interaction-infrastructure.md](phase-10a-interaction-infrastructure.md) and [keyboard-and-focus.md](../specifications/keyboard-and-focus.md).

---

## Workstream 8 — (merged into 10-A)

Turbo/Stimulus interaction standards are part of Phase 10-A. Server remains source of truth; Stimulus handles focus, keyboard, and UI state only.

---

# Delivery Order

```text
10-A  Interaction infrastructure     → phase-10a-interaction-infrastructure.md
10-B  Item cockpit completion       → phase-10b-item-cockpit-completion.md
10-C  POS keyboard workspace        → phase-10c-pos-keyboard-workspace.md
10-D  Workflow polish               → Workstreams 4–6 (customer requests first)
10-E  Consistency sweep             → below
```

## Phase 10-E — Polish and Consistency Sweep

```text
1. Remove one-off button/filter/table styles
2. Replace raw selects/inputs
3. Normalize empty states
4. Normalize status badges
5. Normalize row actions
6. Verify keyboard/focus behavior
7. Verify responsive behavior
8. Verify print/report compatibility (Phase 9b regression)
9. Accessibility: focus rings, contrast, screen-reader labels
10. Touch targets ~44px on POS expanded row and settlement actions
```

### Phase 9b report regression checklist

After shared CSS or layout component changes, verify:

* `/reports` hub index renders and permission-union nav works
* Register summary report renders and prints
* Tax collected report renders (summary, rate, adjustment sections)
* Customer request queue report renders with status badges
* No report filter, button, or table layout regressions from shared component changes

Future: dedicated [phase-10e-consistency-sweep.md](phase-10e-consistency-sweep.md) when 10-E starts.

---

# Acceptance Criteria

Phase 10 is complete when all sub-phases meet their criteria.

## Phase 10-A

* Shared modal, drawer, toast, expanded-row components documented and reusable
* Focus trap and focus restoration implemented
* Turbo target conventions documented
* Pilot: item demand drawer on shared shell
* View contracts documented

## Phase 10-B

* Setup modals for bounded item edits
* Operations summary table + demand drawer
* Drill-down contract preserved
* No inappropriate vendor warnings on used/buyback variants

## Phase 10-C

* POS landing: **idle workspace** when register open and no active draft (**no silent auto-create**); command field is home base
* Active draft always wins on `/pos` (including empty); one active draft per register session + workstation + cashier; cross-cashier conflict UI when needed
* Two-lane parser: slash → command registry; non-slash → scan/catalog lookup only (no implicit open-ring, receipt, or amount guessing)
* Separate line vs transaction discount commands; `/gc` modal-first; `/cashdrop` planned/disabled; return/pickup drawer workflows
* Command field primary focus (idle and active); **required** keyboard/focus criteria met
* Expanded-row line edits; settlement on shared modal; readiness blockers actionable near completion
* `Pos::CommandRegistry` with permissions and state checks; `/reports` confirms before navigate when draft exists
* `/close` blocked while active draft exists; return blocked when tender rows present
* Command aliases and visible controls required; function keys **out of scope** for 10-C completion

## Phase 10-D

* Customer request index no longer button-heavy
* Customer request detail separates summary, action, lines, contact, audit
* PO/receiving line fields use standard money/percent/quantity controls
* Buyback index uses consistent header, metric, and table layout

## Phase 10-E

* Keyboard/focus intentional across major workflows
* Routine confirmations not disruptive full-page alerts
* No new page-specific UI without shared component standard
* Phase 9b report regression checklist passes (see Phase 10-E section above)
* Accessibility improvements where shared components touch reports

---

# Deferred After This Phase

Possible later work:

* Advanced analytics dashboards
* Saved report views
* Full report builder
* Full command language outside POS/items
* Offline POS
* Mobile-specific workflows
* Touchscreen-specific POS mode
* Full framework migration
* User-customizable keyboard shortcuts
* Role-specific dashboard personalization
* Cross-store comparative analytics
* Automated workflow suggestions

---

# Risks

## Scope Creep

This phase is intentionally broad. It should be broken into sub-phases or PRs. POS, items, and global interaction infrastructure should not all be implemented in one large change.

## Keyboard Shortcut Reliability

Function keys may conflict with browsers or operating systems. Phase 10-C does not require F-key bindings; command aliases and visible controls are the completion path.

## Too Many Modals

Modals should remain limited to bounded tasks. Full workflows should stay full-page or use drawers for supporting detail.

## Command Discoverability

Commands are powerful but hidden. Provide visible controls, shortcut strips, `/help`, and command suggestions.

## Accessibility

Modal focus traps, drawer close behavior, keyboard shortcuts, focus rings, contrast, and screen-reader labels must be implemented carefully.

## Regression Risk

Changing shared components can affect many screens. Migrate incrementally and keep aliases for existing classes during transition.

## User Training

A keyboard-first interface is faster but may require visible hints and gradual adoption. Mouse-friendly controls should remain available.

## Sub-Phase Renumbering

Early drafts labeled 10-B as POS and 10-C as items. Sub-phase letters now match delivery order.

## POS Landing Policy

ShelfStack POS **does not auto-create draft sales** when no draft exists. With an open register session and no active draft, landing shows an **idle workspace** with the command field focused as home base. **New sale** / **Start sale** remains a visible mouse path for explicit draft creation but is not the conceptual center. When an active draft exists (register session + workstation + cashier), `/pos` always returns to it — including empty drafts — until complete, cancel, hold, or void. Multiple draft candidates show a conflict picker; held/suspended sales never auto-resume. See [phase-10c-pos-keyboard-workspace.md](phase-10c-pos-keyboard-workspace.md).

## Items Before POS

10-B proves 10-A modals/drawers on lower-risk surfaces before POS modal-heavy work in 10-C.

---

# Developer Notes

Recommended implementation approach:

* Keep using Rails, Turbo, and Stimulus.
* Continue standardizing the `ss-*` design system.
* Avoid introducing a full framework migration during this phase unless separately approved.
* Prefer shared partials and helpers over one-off markup.
* Keep server-side business logic authoritative.
* Use Stimulus for focus, keyboard behavior, formatting, previews, and UI state.
* Use Turbo Streams for targeted panel updates.
* Document each reusable component as it is introduced.
* Preserve old class aliases temporarily where needed to reduce migration risk.

## Documentation

```text
docs/roadmap/phase-10a-interaction-infrastructure.md
docs/roadmap/phase-10b-item-cockpit-completion.md
docs/roadmap/phase-10c-pos-keyboard-workspace.md
docs/specifications/phase-10a-interaction-infrastructure-spec.md
docs/specifications/phase-10b-item-cockpit-spec.md
docs/specifications/phase-10c-pos-keyboard-workspace-spec.md
docs/specifications/phase-10c-test-plan.md
docs/specifications/ui-components.md
docs/specifications/view-contracts.md
docs/specifications/keyboard-and-focus.md
docs/specifications/modal-and-drawer-patterns.md
docs/specifications/pos-keyboard-workspace.md
docs/samples/phase-10-mockups/README.md
```
