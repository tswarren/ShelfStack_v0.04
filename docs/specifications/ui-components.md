# ShelfStack UI Components

**Status:** Phase 10-A implemented

Shared interaction components for operational UI.

This document is an **implementation detail** for the Phase 10 interaction shell: modal, drawer, toast, expanded row, shortcut strip, and shared JavaScript overlay utilities. For the broader design system and component inventory, start with:

- [../design/README.md](../design/README.md)
- [../design/ux-guide.md](../design/ux-guide.md)
- [../design/components.md](../design/components.md)
- [../design/app-shell-and-pos-shell.md](../design/app-shell-and-pos-shell.md)

## Mockup reference

Drawer, modal, expanded row, and shortcut strip patterns in:

* [shelfstack_ux_direction_visual.html](../samples/phase-10-mockups/shelfstack_ux_direction_visual.html)
* [shelfstack_items_mockups.html](../samples/phase-10-mockups/shelfstack_items_mockups.html)
* [shelfstack_pos_mockups.html](../samples/phase-10-mockups/shelfstack_pos_mockups.html)

Implementation uses shared partials under `app/views/shared/interaction/`, Stimulus controllers under `app/javascript/controllers/`, shared overlay utilities under `app/javascript/shelfstack/`, and modular CSS files:

| Concern | Current CSS home |
| ------- | ---------------- |
| Dialog/modal/drawer/dropdown/popover shells | `app/assets/stylesheets/shelfstack.components.overlays.css` |
| Flash/toast/empty/progress/skeleton feedback | `app/assets/stylesheets/shelfstack.components.feedback.css` |
| Tabs/disclosure/expanded/collapsible patterns | `app/assets/stylesheets/shelfstack.components.disclosure.css` and `shelfstack.components.navigation.css` |
| POS-specific workspace interaction styling | `app/assets/stylesheets/shelfstack.domain.pos.css` |
| Item-specific drawer/detail styling | `app/assets/stylesheets/shelfstack.domain.items.css` |
| Temporary legacy compatibility | `app/assets/stylesheets/shelfstack.legacy.css` importing the old monolithic `shelfstack.css` |
| Temporary cascade fixes while legacy remains | `app/assets/stylesheets/shelfstack.migration-overrides.css` |

Do not add new interaction styles to the monolithic `shelfstack.css`. Move durable interaction styles into the component/domain files above.

## Components

### Modal (`ss-modal*` / target `ss-dialog*`)

Bounded tasks: setup edits, customer lookup, supervisor auth, settlement, confirmations.

**Partial:** `shared/interaction/modal`

**Controller:** `modal_controller.js`

**CSS:** `shelfstack.components.overlays.css`; legacy `.ss-modal*` remains during migration.

**Open by id:**

```erb
<button type="button"
        data-action="modal#open"
        data-modal-target-id-param="my-modal">
  Open
</button>

<%= render "shared/interaction/modal", id: "my-modal", title: "Title", size: :md do %>
  ...
<% end %>
```

See [modal-and-drawer-patterns.md](modal-and-drawer-patterns.md).

### Drawer (`ss-drawer*`)

Detail without losing page context: variant demand, session summary, item detail.

**Partial:** `shared/interaction/drawer`

**Controller:** `drawer_controller.js`

**CSS:** `shelfstack.components.overlays.css`; domain refinements belong in the relevant `shelfstack.domain.*.css` file.

**Pilot:** item customer demand drawer (`id="item-demand-drawer"`) on Items operations tab.

### Toast (`ss-toast*`)

Minor non-blocking confirmations only. Server/Turbo append `_toast.html.erb` to `#toast_region`; `toast_controller.js` handles dismiss and auto-dismiss lifecycle only.

**Region:** `shared/interaction/toast_region` in application and POS layouts.

**CSS:** `shelfstack.components.feedback.css`.

### Expanded row (`ss-expand-row*`, `ss-row-detail*`)

Inline line edits: POS cart, PO lines, inventory adjustments.

**Partial:** `shared/interaction/expanded_row` (optional helper; POS cart migration in 10-C).

**CSS:** Generic disclosure/table structure belongs in `shelfstack.components.disclosure.css` or `shelfstack.components.tables.css`; POS-specific row styling belongs in `shelfstack.domain.pos.css`.

### Shortcut strip

Visible command hints and alias legend (POS, optional elsewhere). Function-key bindings are **out of scope** for Phase 10-C completion; do not block POS delivery on F-key reliability.

**Partial:** `shared/interaction/shortcut_strip`

**CSS:** `shelfstack.components.navigation.css`; POS-specific command hints belong in `shelfstack.domain.pos.css`.

## Shared JavaScript utilities

```text
app/javascript/shelfstack/focus_trap.js
app/javascript/shelfstack/focus_restore.js
app/javascript/shelfstack/overlay_lock.js
app/javascript/shelfstack/overlay_shell.js
```

**Overlay stack:** When modals and drawers nest, `overlay_shell.js` routes Escape, backdrop close, and focus trap to the topmost open overlay only. Body scroll lock remains reference-counted in `overlay_lock.js`. See [modal-and-drawer-patterns.md](modal-and-drawer-patterns.md#nested-overlay-stack).

**Test helpers:** `resetOverlayStackForTests()` / `overlayStackDepthForTests()` (`overlay_shell.js`); `resetOverlayLocksForTests()` (`overlay_lock.js`).

## Report components (Phase 9a)

Report-specific patterns remain in [phase-9a-ux-foundation-for-reporting-spec.md](phase-9a-ux-foundation-for-reporting-spec.md). Shared 10-A components may upgrade report shells in 10-E only where compatible.

## Roadmap

[phase-10a-interaction-infrastructure.md](../roadmap/phase-10a-interaction-infrastructure.md)

## Test plan

[phase-10a-test-plan.md](phase-10a-test-plan.md) · POS keyboard workspace: [phase-10c-test-plan.md](phase-10c-test-plan.md)
