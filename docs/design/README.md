# Design Documents

Authoritative design for ShelfStack’s **core domain model** and **application design system**. Delivery milestones and per-milestone specs live under [../v0.04/](../v0.04/) and [../roadmap/v0.04-delivery-roadmap.md](../roadmap/v0.04-delivery-roadmap.md).

---

## Start here — design system spine

Use these documents first when reviewing UI work, adding new screens, or migrating legacy views.

| Document | Purpose |
| -------- | ------- |
| [ux-guide.md](ux-guide.md) | Product-specific UX principles for ShelfStack’s operational, scanner/keyboard-heavy workflows |
| [app-shell-and-pos-shell.md](app-shell-and-pos-shell.md) | Global app shell contract, POS workspace shell rules, body/view-mode contract |
| [layout-width-model.md](layout-width-model.md) | Page canvas width model and when to use readable, standard, wide, item, and POS widths |
| [ux-review-checklist.md](ux-review-checklist.md) | Review checklist for shell, POS, feedback, accessibility, responsive behavior, and workflow pages |

---

## Component library and implementation guidance

| Document | Role |
| -------- | ---- |
| [components.md](components.md) | Component catalog, implementation status, and migration roadmap |
| [../../app/assets/stylesheets/README.md](../../app/assets/stylesheets/README.md) | CSS import order, file responsibilities, naming conventions, and migration rules |
| [../specifications/ui-components.md](../specifications/ui-components.md) | Phase 10 interaction-shell implementation detail: modal, drawer, toast, expanded row, shortcut strip |

Recommended reading order for contributors:

1. [ux-guide.md](ux-guide.md)
2. [app-shell-and-pos-shell.md](app-shell-and-pos-shell.md)
3. [layout-width-model.md](layout-width-model.md)
4. [components.md](components.md)
5. [ux-review-checklist.md](ux-review-checklist.md)

---

## Active — ShelfStack v0.04 core

| Document | Purpose |
| -------- | ------- |
| [VERSION_0.04.md](VERSION_0.04.md) | **Core domain model:** products, identifiers, variants, demand, sourcing, receiving |
| [../roadmap/v0.04-delivery-roadmap.md](../roadmap/v0.04-delivery-roadmap.md) | Ordered implementation milestones (v0.04-0 … v0.04-11) |
| [../v0.04/README.md](../v0.04/README.md) | Milestone spec bundle index |

---

## How to classify design docs

| Category | Documents | Meaning |
| -------- | --------- | ------- |
| Design-system spine | `ux-guide.md`, `app-shell-and-pos-shell.md`, `layout-width-model.md`, `ux-review-checklist.md` | Current guidance for app-wide UI/UX decisions |
| Component inventory | `components.md` | Roadmap and status tracker for reusable CSS/ERB components |
| Implementation detail | `../specifications/ui-components.md` and interaction specs | Shipped Phase 10 behavior and technical interaction patterns |
| Domain design | `VERSION_0.04.md`, v0.04 specs, roadmap docs | Product/domain decisions and milestone delivery scope |

---

## Phase 10-E (consistency sweep)

Phase 10-E maps to the component migration roadmap in [components.md](components.md#phase-10-e-alignment): straggler markup, POS CSS extraction from legacy, Priority 1 thin partials, and checklist-driven review. See [Phase-x10-comprehensive-ux-expansion.md](../roadmap/Phase-x10-comprehensive-ux-expansion.md).

---

## Historical — v0.03 phased delivery

Functional specs under [../specifications/](../specifications/) describe the **v0.03 codebase** (Phases 1–10). Use them to understand shipped behavior until each area is migrated to the v0.04 core.

Superseded by v0.04 (do not extend): catalog item model, customer requests, special orders, TBO.

Still authoritative until migrated: foundation, classification, inventory posting, POS core, buybacks, stored value, reporting shell.
