# ShelfStack UI Components

**Status:** Planned (Phase 10-A)

Shared interaction components for operational UI. Expand as Phase 10-A lands.

## Mockup reference

Drawer, modal, expanded row, and shortcut strip patterns in:

* [shelfstack_ux_direction_visual.html](../samples/phase-10-mockups/shelfstack_ux_direction_visual.html)
* [shelfstack_items_mockups.html](../samples/phase-10-mockups/shelfstack_items_mockups.html)
* [shelfstack_pos_mockups.html](../samples/phase-10-mockups/shelfstack_pos_mockups.html)

Implementation uses `ss-*` classes in `app/assets/stylesheets/shelfstack.css`.

## Components (10-A)

### Modal (`ss-modal*`)

Bounded tasks: setup edits, customer lookup, supervisor auth, settlement, confirmations.

See [modal-and-drawer-patterns.md](modal-and-drawer-patterns.md).

### Drawer (`ss-drawer*`)

Detail without losing page context: variant demand, session summary, item detail.

### Toast (`ss-toast*`)

Minor non-blocking confirmations only.

### Expanded row (`ss-expand-row*`, `ss-row-detail*`)

Inline line edits: POS cart, PO lines, inventory adjustments.

### Shortcut strip

Visible F-key legend and command hints (POS, optional elsewhere).

## Report components (Phase 9a)

Report-specific patterns remain in [phase-9a-ux-foundation-for-reporting-spec.md](phase-9a-ux-foundation-for-reporting-spec.md). Shared 10-A components may upgrade report shells in 10-E only where compatible.

## Roadmap

[phase-10a-interaction-infrastructure.md](../roadmap/phase-10a-interaction-infrastructure.md)
