# ShelfStack UI Components

**Status:** Phase 10-A implemented

Shared interaction components for operational UI.

## Mockup reference

Drawer, modal, expanded row, and shortcut strip patterns in:

* [shelfstack_ux_direction_visual.html](../samples/phase-10-mockups/shelfstack_ux_direction_visual.html)
* [shelfstack_items_mockups.html](../samples/phase-10-mockups/shelfstack_items_mockups.html)
* [shelfstack_pos_mockups.html](../samples/phase-10-mockups/shelfstack_pos_mockups.html)

Implementation uses `ss-*` classes in `app/assets/stylesheets/shelfstack.css` and shared partials under `app/views/shared/interaction/`.

## Components

### Modal (`ss-modal*`)

Bounded tasks: setup edits, customer lookup, supervisor auth, settlement, confirmations.

**Partial:** `shared/interaction/modal`

**Controller:** `modal_controller.js`

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

**Pilot:** item customer demand drawer (`id="item-demand-drawer"`) on Items operations tab.

### Toast (`ss-toast*`)

Minor non-blocking confirmations only. Server/Turbo append `_toast.html.erb` to `#toast_region`; `toast_controller.js` handles dismiss and auto-dismiss lifecycle only.

**Region:** `shared/interaction/toast_region` in application and POS layouts.

### Expanded row (`ss-expand-row*`, `ss-row-detail*`)

Inline line edits: POS cart, PO lines, inventory adjustments.

**Partial:** `shared/interaction/expanded_row` (optional helper; POS cart migration in 10-C).

### Shortcut strip

Visible F-key legend and command hints (POS, optional elsewhere).

**Partial:** `shared/interaction/shortcut_strip`

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

[phase-10a-test-plan.md](phase-10a-test-plan.md)
